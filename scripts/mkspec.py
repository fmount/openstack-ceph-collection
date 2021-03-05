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

# NOTES/TODO(s):
# 1. should we have a multilevel spec_keys validation

ALLOWED_DAEMONS = ['host', 'mon', 'mgr', 'mds', 'nfs', 'osd', 'rgw', 'grafana',
                   'crash', 'prometheus', 'alertmanager', 'node-exporter']

ALLOWED_HOST_PLACEMENT_MODE = ['hosts', 'host_pattern', 'label']

ALLOWED_EXTRA_KEYS = {
    'osd': [
        'data_devices',
        'db_devices',
        'wal_devices',
    ]
}

ALLOWED_SPEC_KEYS = {
    'rgw': [
        'rgw_frontend_port',
        'rgw_realm',
        'rgw_zone',
        'rgw_ip_address'
    ],
    'nfs': [
        'namespace',
        'pool'
    ],
    'osd': [
        'data_devices',
        'db_devices',
        'wal_devices',
    ],
}

class CephPlacementSpec(object):
    def __init__(self,
                 hosts: list,
                 host_pattern: str,
                 count: int,
                 labels: list[str]):

        if len(labels) > 0:
            self.labels = labels
        if count > 0:
            self.count = count
        if host_pattern is not None and len(host_pattern) > 0:
            self.host_pattern = host_pattern

        if hosts is not None and len(hosts) > 0:
            self.hosts = hosts

    def __setattr__(self, key, value):
        self.__dict__[key] = value

    def make_spec(self):
        # if the host list is passed, this should be
        # the preferred way
        if getattr(self, 'hosts', None):
            spec_template = {
                'placement': {
                    'hosts': self.hosts
                }
            }
        # if no list is passed or an empty list is provided
        # let's check if a "host pattern" is provided
        elif getattr(self, 'host_pattern', None):
            spec_template = {
                'placement': {
                    'host_pattern': self.host_pattern
                }
            }
        elif getattr(self, 'labels', None) is not None:
            spec_template = {
                'placement': {
                    'labels': self.labels
                }
            }
        else:
            spec_template = {}

        # TODO: Add count to the list of placement parameters
        return spec_template

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
        lb = {}

        spec_template = {
            'service_type': self.daemon_type,
            'addr': self.daemon_addr,
            'hostname': self.daemon_hostname,
        }

        if len(self.labels) > 0:
            lb = {'labels': self.labels}

        spec_template = {**spec_template, **lb}
        return (yaml.dump(spec_template, indent=2))

class CephDaemonSpec(object):
    def __init__(self, daemon_type: str,
                 daemon_id: str,
                 daemon_name: str,
                 hosts: list,
                 placement_pattern: str,
                 spec: dict,
                 labels: list[str],
                 **kwargs: dict):

        self.daemon_name = daemon_name
        self.daemon_id = daemon_id
        self.daemon_type = daemon_type
        self.hosts = hosts
        self.placement = placement_pattern
        self.labels = labels

        # extra keywords definition (e.g. data_devices for OSD(s)
        self.extra = {}
        for k, v in kwargs.items():
            self.extra[k] = v

        assert isinstance(spec, dict)
        self.spec = spec

    def __setattr__(self, key, value):
        self.__dict__[key] = value

    def make_daemon_spec(self):

        # the placement dictionary
        pl = {}
        # the spec dictionary
        sp = {}

        place = CephPlacementSpec(self.hosts, self.placement, 0, self.labels)
        pl = place.make_spec()

        # the spec daemon header
        spec_template = {
            'service_type': self.daemon_type,
            'service_name': self.daemon_name,
            'service_id': self.daemon_id,
        }

        # process extra parameters if present
        if not self.validate_keys(self.extra.keys(), ALLOWED_EXTRA_KEYS):
            raise Exception("Fatal: the spec should be composed by only allowed keywords")

        # append the spec if provided
        if len(self.spec.keys()) > 0:
            if(self.validate_keys(self.spec.keys(), ALLOWED_SPEC_KEYS)):
                sp = {'spec': self.spec}
            else:
                raise Exception("Fatal: the spec should be composed by only allowed keywords")

        # build the resulting daemon template
        spec_template = {**spec_template, **self.extra, **pl, **sp}
        return (yaml.dump(spec_template, indent=2))

    def validate_keys(self, spec, ALLOWED_KEYS):
        '''
        When the spec section is created, if constraints are
        defined for a given daemon, then this check is run
        to make sure only valid keys are provided.
        '''

        # an entry for the current daemon is not found
        # no checks are required (let ceph orch take care of
        # the validation
        if self.daemon_type not in ALLOWED_SPEC_KEYS.keys():
            return True

        # a basic check on the spec dict: if some constraints
        # are specified, the provided keys should be contained
        # in the ALLOWED keys
        for item in spec:
            if item not in ALLOWED_SPEC_KEYS.get(self.daemon_type):
                return False
        return True

    def log(self, msg):
        print('[DEBUG] - %s' % msg)

    def whoami(self) -> str:
        return '%s.%s' % (self.daemon_type, self.daemon_id)


def export(content):
    if len(content) > 0:
        if OPTS.output_file is not None and len(OPTS.output_file) > 0:
            fname = OPTS.output_file
            with open(fname, 'a') as f:
                f.write('---\n')
                f.write(content)
        else:
            print('---')
            print(content.rstrip('\r\n'))
    else:
        print('Nothing to dump!')


# -- MAIN --

def parse_opts(argv):
    parser = argparse.ArgumentParser(description='Parameters used to render the spec')
    parser.add_argument('-d', '--daemon', metavar='SERVICE_TYPE',
                        help=("What kind of service we're going to apply"),
                        default='none', choices=['host', 'mon', 'mgr', 'mds', 'nfs', \
                                                 'osd', 'rgw', 'grafana', 'prometheus', \
                                                 'alertmanager', 'crash', 'node-exporter'])
    parser.add_argument('-i', '--service-id', metavar='SERVICE_ID',
                        help=("The service_id of the daemon we're going to apply"))
    parser.add_argument('-n', '--service-name', metavar='SERVICE_NAME',
                        help=("The service_name of the daemon we're going to apply"))
    parser.add_argument('-g', '--host-group', metavar='HOST_GROUP',
                        help="Host list where the service should be run")
    parser.add_argument('-p', '--host-pattern', metavar='HOST_PATTERN',
                        help="Host pattern to establish where the service should be applied")
    parser.add_argument('-s', '--spec', metavar='SPEC',
                        help=("Json/Dict definition of the spec section"),
                        default='{}')
    parser.add_argument('-e', '--extra', metavar='extra',
                        help=("Json/Dict definition of extra keys"),
                        default='{}')
    parser.add_argument('-a', '--address', metavar='address',
                        help=("The address of the host we're going to apply"))
    parser.add_argument('-z', '--hostname', metavar='hostname',
                        help=("The hostname of the host we're going to apply"))
    parser.add_argument('-l', '--labels', metavar='labels',
                        help=("The labels of the host we're going to apply"),
                        default=[])
    parser.add_argument('-o', '--output-file', metavar='OUT_FILE',
                        help=("Path to the output file"))
    opts = parser.parse_args(argv[1:])

    return opts


if __name__ == "__main__":

    OPTS = parse_opts(sys.argv)
    spec = {}
    labels = []
    hosts = []
    pattern = None

    if OPTS.daemon not in ALLOWED_DAEMONS:
        print('Error, unable to render the spec for an Unknown Ceph daemon!')
        sys.exit(-1)

    if OPTS.service_id is None:
        OPTS.service_id = OPTS.daemon

    if OPTS.service_name is None:
        OPTS.service_name = OPTS.daemon

    if len(OPTS.labels) > 0:
        labels = [x for x in OPTS.labels.split(',')]

    if len(OPTS.spec) > 0:
        spec = json.loads(OPTS.spec.replace("'", "\""))

    if OPTS.host_group is not None and len(OPTS.host_group) > 0:
        hosts = [x for x in OPTS.host_group.split(',')]

    if OPTS.host_pattern is not None and len(OPTS.host_pattern) > 0:
        pattern = OPTS.host_pattern

    if OPTS.extra is not None and len(OPTS.extra) > 0:
        extra = json.loads(OPTS.extra.replace("'", "\""))

    if OPTS.daemon == "host":
        d = CephHostSpec(OPTS.daemon, OPTS.address, OPTS.hostname, labels)
    else:
        d = CephDaemonSpec(OPTS.daemon, \
                OPTS.service_id, \
                OPTS.service_name, \
                hosts, \
                pattern, \
                spec, \
                labels, \
                **extra)

    # Export the host I built in the specified output file
    export(d.make_daemon_spec())


# ------------ EXAMPLE OF CREATING A NEW HOST ---------------- #

# mkspec.py -d host -a standalone -z standalone
#addr: standalone
#hostname: standalone
#labels:
#- mon
#- mgr
#service_type: host

# ------------ EXAMPLE OF DAEMON USING A HOST LIST ---------------- #

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

# ------------ EXAMPLE WITH LABELS ---------------- #

#> python mkspec.py -d rgw -p host1,host2,host3 -s "{'zone' : 'default'}" -l mon,rgw -o rgw_out
#placement:
#  labels:
#  - mon
#  - rgw
#service_id: rgw
#service_name: rgw
#service_type: rgw
#spec:
#  zone: default
