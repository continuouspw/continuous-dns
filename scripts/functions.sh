# Copyright 2017, Logan Vig <logan2211@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export SCRIPT_PATH=$(dirname $(readlink -f "$0"))
export PROJECT_PATH=$(dirname "$SCRIPT_PATH")
export FORKS=${FORKS:-$(grep -c ^processor /proc/cpuinfo)}
export ANSIBLE_PARAMETERS=${ANSIBLE_PARAMETERS:-""}
export ANSIBLE_FORCE_COLOR=${ANSIBLE_FORCE_COLOR:-true}
export ANSIBLE_VENV_PATH="$HOME/.ansible-venv"

function bootstrap_system {
  # Install pip
  if [ ! "$(which pip)" ]; then
    curl --silent --show-error --retry 5 \
      https://bootstrap.pypa.io/get-pip.py | sudo python2.7
  fi

  pip install virtualenv virtualenv-tools

  # Create the virtualenv and set the path
  virtualenv "${ANSIBLE_VENV_PATH}"

  # Install bindep
  ${ANSIBLE_VENV_PATH}/bin/pip install bindep

  # CentOS 7 requires two additional packages:
  #   redhat-lsb-core - for bindep profile support
  #   epel-release    - required to install python-ndg_httpsclient/python2-pyasn1
  if [ "$(which yum)" ]; then
      sudo yum -y install redhat-lsb-core epel-release
  fi

  # Install OS packages using bindep
  if apt-get -v >/dev/null 2>&1 ; then
      sudo apt-get update
      DEBIAN_FRONTEND=noninteractive \
        sudo apt-get -q --option "Dpkg::Options::=--force-confold" \
        --assume-yes install `${ANSIBLE_VENV_PATH}/bin/bindep -b -f ${PROJECT_PATH}/bindep.txt test`
  else
      sudo yum install -y `${ANSIBLE_VENV_PATH}/bin/bindep -b -f ${PROJECT_PATH}/bindep.txt test`
  fi

  # Install project requirements
  ${ANSIBLE_VENV_PATH}/bin/pip install -r${PROJECT_PATH}/requirements.txt

  mkdir -p "$HOME/.local/bin"
  for item in $ANSIBLE_VENV_PATH/bin/ansible*; do
    ln -s "${item}" "$HOME/.local/bin" || true
  done

  export ANSIBLE_CALLBACK_PLUGINS="${PROJECT_PATH}/playbooks/ephemeral_roles/plugins/callback"

  if [ ! -z "${JENKINS_HOME:-unset}" ]; then
    # The task is running inside a gate job. Install the ARA callback and
    # exit tasks
    export ANSIBLE_CALLBACK_PLUGINS="${ANSIBLE_CALLBACK_PLUGINS}:${ANSIBLE_VENV_PATH}/lib/python2.7/site-packages/ara/plugins/callbacks"
    install_exit_trap
  fi
}

function bootstrap_roles {
  ROLES_REQUIREMENTS_FILE="${PROJECT_PATH}/ansible-role-requirements.yml"
  ROLES_PATH="${PROJECT_PATH}/playbooks/ephemeral_roles"
  ${ANSIBLE_VENV_PATH}/bin/ansible-galaxy install -f -i \
    -p "${ROLES_PATH}" \
    -r "${ROLES_REQUIREMENTS_FILE}"
}

function ensure_environment {
  # Final checks to make sure the environment is configured fully for deployment
  for item in ANSIBLE_INVENTORY; do
    if [ -z "${!item}" ]; then
      echo "ERROR: Required variable ${item} is not defined!"
      exit 1
    fi
  done

  # Ensure the inventory points to a valid directory
  if [ ! -d "${ANSIBLE_INVENTORY}" ]; then
    echo "ERROR: ANSIBLE_INVENTORY must point to a valid path"
    exit 1
  fi
}

function run_ansible {
  ${ANSIBLE_VENV_PATH}/bin/ansible-playbook ${ANSIBLE_PARAMETERS} --forks ${FORKS} $@
}

function gate_job_exit_tasks {
  GATE_LOG_DIR="${PROJECT_PATH}/logs"
  ARA_DIR="${PROJECT_PATH}/ara"
  # Create the log archiving directories in the workspace
  mkdir -m 0777 "${GATE_LOG_DIR}" "${ARA_DIR}" || true
  # Collect the logs from the hosts and containers into the workspace
  rsync -av --safe-links --ignore-errors /var/log/ "${GATE_LOG_DIR}/host" || true
  for i in `cd /lxc; find . -mindepth 2 -maxdepth 2 -iname log -type d`; do
    rsync --archive --verbose --safe-links --ignore-errors --relative "/lxc/${i}" "${GATE_LOG_DIR}/lxc" || true
  done
  # Rename all files gathered to have a .txt suffix so that the compressed
  # files are viewable via a web browser in OpenStack-CI.
  find "${GATE_LOG_DIR}/" -type f -exec mv {} {}.txt \;
  # Compress the files gathered so that they do not take up too much space.
  # We use 'command' to ensure that we're not executing with some sort of alias.
  command gzip --best --recursive "${GATE_LOG_DIR}/"
  # Ensure that the files are readable by all users, including the non-root
  # jenkins user.
  chmod -R 0777 "${GATE_LOG_DIR}"
  # Generate the ARA report
  ${ANSIBLE_VENV_PATH}/bin/ara generate html "${PROJECT_PATH}/ara" || true
}

function install_exit_trap {
  trap gate_job_exit_tasks EXIT
}
