#!/usr/bin/env python

import yaml
import sys
import os
import argparse

def repr_str(dumper, data):
    if '\n' in data:
        return dumper.represent_scalar(u'tag:yaml.org,2002:str', data, style='|')
    return dumper.org_represent_str(data)


yaml.SafeDumper.org_represent_str = yaml.SafeDumper.represent_str
yaml.add_representer(str, repr_str, Dumper=yaml.SafeDumper)


def rm_group(group: str, inventory_path: str):
    with open(inventory_path, 'r') as file:
        inventory = yaml.load(file, yaml.SafeLoader)

        # patch the yaml inventory: remove the group if exists
        inventory.pop(group, None)

    # return the patched inventory
    return yaml.safe_dump(inventory, indent=2)


def parse_opts(argv):
    parser = argparse.ArgumentParser(description='Parameters needed to patch the inventory')
    parser.add_argument('-i', '--inventory', metavar='INVENTORY',
                        help=("The inventory that we need to patch"))
    parser.add_argument('-g', '--host-group', metavar='HOST_GROUP',
                        help="Host list where the service should be run")
    parser.add_argument('-o', '--output-file', metavar='OUT_FILE',
                        help=("Path to the output file"))
    opts = parser.parse_args(argv[1:])

    return opts


if __name__ == "__main__":
    OPTS = parse_opts(sys.argv)

    if OPTS.inventory is None or not os.path.exists(OPTS.inventory):
        print('Error, no valid inventory provided')
        sys.exit(-1)

    if OPTS.host_group is None or len(OPTS.host_group) == 0:
        print('Error, no group to be removed')
        sys.exit(-1)

    print("INVENTORY %s" % OPTS.inventory)
    print("GROUP TO REMOVE %s" % OPTS.host_group)

    patched_inventory = rm_group(OPTS.host_group, OPTS.inventory)
    with open(OPTS.inventory, 'w') as f:
        f.write(patched_inventory)
