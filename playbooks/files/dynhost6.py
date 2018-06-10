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
stdout.write("OK\tDynhost v6 Backend\n")
stdout.flush()


def splitCount(s, count):
    return [''.join(x) for x in zip(*[list(s[z::count]) for z in range(count)])]

def ipv6ize(address):
    # Convert a string like fd64baa481f3b83a into
    # fd64:baa4:81f3:b83a:0000:0000:0000:0000

    # Zerofill to 32 characters to ensure full v6 address
    # Then split the string by 4 char chunks and join with ':'
    return ':'.join(splitCount('{:0<32s}'.format(address), 4))

def hex2ip6(hexip):
    # Return an IP address from a hex encoded decimal IP
    try:
        ip = socket.inet_ntop(socket.AF_INET6,
                              socket.inet_pton(socket.AF_INET6,
                                               ipv6ize(hexip)))
    except (ValueError, socket.error):
        ip = '::1'
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
        resp_ip = hex2ip6(qname.split('.')[0])
        r = "DATA\t{}\t{}\t{}\t{}\t{}\t{}\n".format(
          qname, qclass, 'AAAA', 86400, id, resp_ip
        )
    stdout.write(r)
    stdout.write("END\n")
    stdout.flush()
