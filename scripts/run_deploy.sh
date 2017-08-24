#!/usr/bin/env bash
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

set -e -u -x
set -o pipefail

. $(dirname $(readlink -f "$0"))/functions.sh

# The DEPLOY_SITE envvar is consumed from the Jenkins job
export ANSIBLE_INVENTORY="${PROJECT_PATH}/inventory"
DEPLOY_PLAYBOOK=${DEPLOY_PLAYBOOK:-"deploy.yml"}

bootstrap_system
bootstrap_roles
ensure_environment

# Deploy the test environment
pushd ${PROJECT_PATH}/playbooks
run_ansible "${DEPLOY_PLAYBOOK}"
popd
