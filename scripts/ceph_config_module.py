# Copyright 2020, Red Hat, Inc.
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
# Included from: https://github.com/ceph/ceph-ansible/blob/master/library/ceph_fs.py

from __future__ import absolute_import, division, print_function
__metaclass__ = type

from ansible.module_utils.basic import AnsibleModule
try:
    from ansible.module_utils.ca_common import is_containerized, \
                                               exec_command, \
                                               generate_ceph_cmd, \
                                               exit_module
except ImportError:
    from tripleo_ansible.ansible_plugins.module_utils.ca_common import is_containerized, \
                                       exec_command, \
                                       generate_ceph_cmd, \
                                       exit_module

import datetime
import json
import yaml


ANSIBLE_METADATA = {
    'metadata_version': '1.1',
    'status': ['preview'],
    'supported_by': 'community'
}

DOCUMENTATION = """
---
module: ceph_config

short_description: Manage Ceph config(s)

version_added: "2.8"

description:
    - Manage Ceph configs
options:
  cluster:
    description:
      - The ceph cluster name.
    required: false
    default: ceph
  data:
    description:
      - the json map to be processed
    required: true

"""

EXAMPLES = '''
- name: Config Ceph keys
  ceph_config:
    cluster: ceph
    data: 
      mgr:
        'mgr/cephadm/autotune_memory_target_ratio': 0.5
      osd: 
        'osd_memory_target_autotune': True
        'osd_numa_node': 0

'''

RETURN = '''#  '''



def ceph_conf_set(module, section, key, value, container_image=None):

    cluster = module.params.get('cluster')
    args = ['set', section, key, str(value)]

    cmd = generate_ceph_cmd(sub_cmd=['config'], args=args, spec_path=None, cluster=cluster, container_image=container_image)
    return cmd

def run_module():

    module = AnsibleModule(
        argument_spec=yaml.safe_load(DOCUMENTATION)['options'],
        supports_check_mode=True,
        required_if=[['state', 'present', ['data']]],
    )

    # Gather module parameters in variables
    cluster = module.params.get('cluster')
    data = module.params.get('data')

    if module.check_mode:
        module.exit_json(
            changed=False,
            stdout='',
            stderr='',
            rc=0,
            start='',
            end='',
            delta='',
        )

    startd = datetime.datetime.now()
    changed = False

    # will return either the image name or None
    container_image = is_containerized()
    data_map = json.loads(data)

    for section, section_map in data_map.items():
       for key, value in section_map.items():
           cmd = ceph_conf_set(module, section, key, value, container_image=container_image)
           rc, cmd, out, err = exec_command(module, cmd)

    exit_module(module=module, out=out, rc=rc, cmd=cmd, err=err, startd=startd, changed=changed)


def main():
    run_module()


if __name__ == '__main__':
    main()
