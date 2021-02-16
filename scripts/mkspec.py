#!/usr/bin/env python
# Copyright (c) 2021 OpenStack Foundation
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.


import argparse
import yaml
import json
import sys

# NOTES:
#
#

ALLOWED_DAEMONS = ['host', 'mon', 'mgr', 'mds', 'nfs', 'osd', 'rgw', 'grafana', \
                   'prometheus', 'alertmanager', 'node-exporter']

ALLOWED_HOST_PATTERN = ['list', 'regex']

class CephHostSpec(object):
    def __init__(self, daemon_type: str,
                 daemon_addr: str,
                 daemon_hostname: str,
                 labels: list[str]):
        self.daemon_type = daemon_type
        self.daemon_addr = daemon_addr
        self.daemon_hostname = daemon_hostname
        assert isinstance(labels, list)
        self.labels = labels

    def make_daemon_spec(self):
        spec_template = {
            'service_type': self.daemon_type,
            'addr': self.daemon_addr,
            'hostname': self.daemon_hostname,
            'labels': self.labels
        }
        return (yaml.dump(spec_template, indent=2))

class CephDaemonSpec(object):
    def __init__(self, daemon_type: str,
                 daemon_id: str,
                 daemon_name: str,
                 placement: str,
                 spec: dict):

        self.daemon_name = daemon_name
        self.daemon_id = daemon_id
        self.daemon_type = daemon_type
        self.placement = placement

        assert isinstance(spec, dict)
        self.spec = spec

    def host_list(self) -> list:
        '''
        we're assuming here a comma separated list
        because those values are provided via cli
        '''

        hl = []
        for e in self.placement.split(','):
            hl.append(e)
        return hl

    def make_daemon_spec(self):
        spec_template = {
            # improve how the placement can be defined
            # 1. a dict where a pattern can be specified
            # 2. the host list that can be passed
            'placement': {
                'hosts': self.host_list()
            },
            'service_type': self.daemon_type,
            'service_name': self.daemon_name,
            'service_id': self.daemon_id
        }

        sp = {}
        if len(self.spec.keys()) > 0:
            sp = {'spec': self.spec}

        # build the resulting daemon template
        s = {**spec_template, **sp}
        return (yaml.dump(s, indent=2))

    def log(self, msg):
        print('[DEBUG] - %s' % msg)

    def whoami(self) -> str:
        return '%s.%s' % (self.daemon_type, self.daemon_id)


def export(content, preview):
    if preview:
        print(content)
    if len(content) > 0 and OPTS.output_file:
        fname = OPTS.output_file
        with open(fname, 'w') as f:
            f.write(content)


# -- MAIN --

def parse_opts(argv):
    parser = argparse.ArgumentParser(description='Parameters used to render the spec')
    parser.add_argument('-d', '--daemon', metavar='SERVICE_TYPE',
                        help=("What kind of service we're going to apply"),
                        default='none', choices=['host', 'mon', 'mgr', 'mds', 'nfs', \
                                                 'osd', 'rgw', 'grafana', 'prometheus', \
                                                 'alertmanager'])
    parser.add_argument('-i', '--service-id', metavar='SERVICE_ID',
                        help=("The service_id of the daemon we're going to apply"))
    parser.add_argument('-n', '--service-name', metavar='SERVICE_NAME',
                        help=("The service_name of the daemon we're going to apply"))
    parser.add_argument('-p', '--placement', metavar='PLACEMENT',
                        help="Host list where the service should be run",
                        default='*')
    parser.add_argument('-s', '--spec', metavar='SPEC',
                        help=("Json/Dict definition of the spec section"),
                        default='{}')
    parser.add_argument('-a', '--address', metavar='address',
                        help=("The address of the host we're going to apply"))
    parser.add_argument('-z', '--hostname', metavar='hostname',
                        help=("The hostname of the host we're going to apply"))
    parser.add_argument('-l', '--label', metavar='label',
                        help=("The labels of the host we're going to apply"),
                        default=[])
    parser.add_argument('-o', '--output-file', metavar='OUT_FILE',
                        help=("Path to the output file"
                              "(default: 'spec')"),
                        default='spec_out')
    opts = parser.parse_args(argv[1:])

    return opts


if __name__ == "__main__":

    OPTS = parse_opts(sys.argv)
    spec = {}

    if OPTS.daemon not in ALLOWED_DAEMONS:
        print('Error, unable to render the spec for an Unknown Ceph daemon!')
        sys.exit(-1)

    if OPTS.service_id is None:
        OPTS.service_id = OPTS.daemon

    if OPTS.service_name is None:
        OPTS.service_name = OPTS.daemon

    if len(OPTS.spec) > 0:
        spec = json.loads(OPTS.spec.replace("'", "\""))

    if OPTS.daemon == "host":
        d = CephHostSpec(OPTS.daemon, OPTS.address, OPTS.hostname, ['mon', 'mgr'])
    else:
        d = CephDaemonSpec(OPTS.daemon, OPTS.service_id, OPTS.service_name, OPTS.placement, spec)

    # Export the host I built in the specified output file
    export(d.make_daemon_spec(), True)


# e.g.
# mkspec.py -d rgw -p host1,host2,host3 -s "{'zone' : 'default'}" -o rgw_out
#placement:
#  hosts:
#  - host1
#  - host2
#  - host3
#service_id: rgw
#service_name: rgw
#service_type: rgw
#spec:
#  zone: default
# ----
# mkspec.py -d host -a standalone -z standalone
#addr: standalone
#hostname: standalone
#labels:
#- mon
#- mgr
#service_type: host