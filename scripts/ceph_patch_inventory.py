# Copyright 2021, Red Hat, Inc.
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

from __future__ import absolute_import, division, print_function
from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.ca_common import is_containerized, \
    exec_command, generate_ceph_cmd, exit_module
from ansible.module_utils import ceph_spec
import datetime
import json
import os
import stat
import time
import yaml


__metaclass__ = type


ANSIBLE_METADATA = {
    'metadata_version': '1.1',
    'status': ['preview'],
    'supported_by': 'community'
}

DOCUMENTATION = """
---
module: ceph_patch_inventory

short_description: Patch the existing TripleO inventory file used for Ceph

version_added: "2.8"

description:
    - Patch an existing TripleO inventory file used during the FFU scenario against a Ceph cluster
    - Remove a group that is supposed to be skipped by ceph-ansible only when cephadm_adopt tag is provided
options:
    group:
        description:
          - The group name that should be removed
        required: true
        type: str
    inventory:
        description:
          - The inventory path that is supposed to be patched
        required: true
        type: str
    output_inventory:
        description:
          - The output inventory file (only needed to avoid the input file being replaced)
        required: false
        type: str
"""

EXAMPLES = '''
- name: Patch the existing inventory file removing the NFS group
  ceph_patch_inventory:
    group: nfss
    inventory: "{{ playbook_dir }}/ceph-ansible/inventory.yml"

- name: Patch the existing inventory file removing the NFS group
  ceph_patch_inventory:
    group: ceph_nfs
    inventory: "{{ playbook_dir }}/tripleo-ansible-inventory.yaml"
    output_inventory: "{{ playbook_dir }}/ceph-ansible/inventory.yml"
'''

RETURN = '''#  '''


def repr_str(dumper, data):
    if '\n' in data:
        return dumper.represent_scalar(u'tag:yaml.org,2002:str', data, style='|')
    return dumper.org_represent_str(data)


yaml.SafeDumper.org_represent_str = yaml.SafeDumper.represent_str
yaml.add_representer(str, repr_str, Dumper=yaml.SafeDumper)

def rm_group(group, inventory_path):
    with open(inventory_path, 'r') as file:
        inventory = yaml.load(file, yaml.SafeLoader)

        # patch the yaml inventory: remove the group if exists
        inventory.pop(group, None)

    # return the patched inventory
    return yaml.safe_dump(inventory, indent=2)

def write_inventory(output_inventory_path, patched_inventory):
    with open(output_inventory_path, 'w') as f:
        f.write(patched_inventory)

def run_module():

    module = AnsibleModule(
        argument_spec=yaml.safe_load(DOCUMENTATION)['options'],
        supports_check_mode=True,
        # required_if=[['apply', True, ['render_path']]],
    )

    # Gather module parameters in variables
    group = module.params.get('group')
    inventory = module.params.get('inventory')
    out_inventory = module.params.get('output_inventory')

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

    # PROCESSING PARAMETERS
    if inventory is None or not os.path.exists(inventory):
        module.exit_json(changed=True, result="ERROR, no valid inventory provided")

    # if no output inventory file is explicitly passed
    # the module replace the existing input inventory
    if out_inventory is None:
        out_inventory = inventory


    patched_inventory = rm_group(group, inventory)
    write_inventory(out_inventory, patched_inventory)

    module.exit_json(changed=True, result="Inventory patched")

def main():
    run_module()


if __name__ == '__main__':
    main()
