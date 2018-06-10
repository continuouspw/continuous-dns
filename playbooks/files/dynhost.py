#!/usr/bin/python
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

import socket
import struct
from sys import stdin, stdout
from time import time

data = stdin.readline()
stdout.write("OK\tDynhost Backend\n")
stdout.flush()


def hex2ip(hexip):
    # Return an IP address from a hex encoded decimal IP
    try:
        ip = socket.inet_ntoa(struct.pack('!L', int(hexip, 16)))
    except (ValueError, struct.error):
        ip = '127.0.0.1'
    return ip


while True:
    line = stdin.readline().strip()

    kind, qname, qclass, qtype, id, remoteip = line.split("\t")
    if qtype == 'SOA':
        r = "DATA\t{}\t{}\t{}\t{}\t{}\t{} {} {} {} {} {} {}\n".format(
            qname, qclass, qtype, 86400, id, 'ns.none', 'email.none',
            int(time()), 172800, 900, 1209600, 3600
        )
    elif qtype == "CAA":
        r = "DATA\t{}\t{}\t{}\t{}\t{}\t{}\n".format(
          qname, qclass, 'CAA', 0, id,
          'issue "letsencrypt.org"'
        )
    else:
        resp_ip = hex2ip(qname.split('.')[0])
        r = "DATA\t{}\t{}\t{}\t{}\t{}\t{}\n".format(
          qname, qclass, 'A', 86400, id, resp_ip
        )
    stdout.write(r)
    stdout.write("END\n")
    stdout.flush()
