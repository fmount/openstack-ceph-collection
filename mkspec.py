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
import configparser
import yaml
import json
import sys

# NOTES:
#
#

ALLOWED_DAEMONS = ['mon', 'mgr', 'mds', 'nfs', 'osd', 'rgw', 'grafana', \
                   'prometheus', 'alertmanager', 'node-exporter']

class CephDaemonSpec(object):
    def __init__(self, daemon_name: str,
                 daemon_id: str,
                 daemon_type: str,
                 placement: list,
                 spec: dict,
                 dry_run: bool):

        self.daemon_name = daemon_name
        self.daemon_id = daemon_id
        self.daemon_type = daemon_type
        self.placement = placement

        assert isinstance(spec, dict)
        self.spec = spec

        if dry_run is None:
            self.apply = True
        else:
            self.dry_run = dry_run

    def host_list(self):
        hl = []
        for e in self.placement.split(','):
            hl.append(e)
        return hl

    def make_daemon_spec(self):
        spec_template = {
            'placement': self.host_list(),
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


def export(content):
    if len(content) > 0 and OPTS.output_file:
        fname = OPTS.output_file
        with open(fname, 'w') as f:
            f.write(content)


# -- MAIN --

def parse_opts(argv):
    parser = argparse.ArgumentParser(description='Parameters used to render the spec')
    parser.add_argument('-d', '--daemon', metavar='DAEMON',
                        help=("What kind of service we're going to apply"),
                        default='none', choices=['mon', 'mgr', 'mds', 'nfs', 'osd', 'rgw'])
    parser.add_argument('-p', '--placement', metavar='PLACEMENT',
                        help="Host list where the service should be run",
                        default='*')
    parser.add_argument('-s', '--spec', metavar='SPEC',
                        help=("Json/Dict definition of the spec section"),
                        default='{}')
    parser.add_argument('-o', '--output-file', metavar='OUT_FILE',
                        help=("Path to the output file"
                              "(default: 'spec')"),
                        default='spec_out')
    opts = parser.parse_args(argv[1:])

    return opts


if __name__ == "__main__":

    OPTS = parse_opts(sys.argv)
    spec = {}

    # debug
    print(OPTS)

    if OPTS.daemon not in ALLOWED_DAEMONS:
        print('Error, unable to render the spec for an Unknown Ceph daemon!')
        sys.exit(-1)

    if len(OPTS.spec) > 0:
        spec = json.loads(OPTS.spec.replace("'", "\""))

    d = CephDaemonSpec(OPTS.daemon, OPTS.daemon, OPTS.daemon, OPTS.placement, spec, False)
    export(d.make_daemon_spec())

# mkspec.py -d rgw -p host1,host2,host3 -s "{'zone' : 'default'}" -o rgw_out
