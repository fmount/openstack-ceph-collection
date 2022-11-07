#!/usr/bin/env python3

import mkspec
import argparse
import yaml
import sys

def parse_opts(argv):
    parser = argparse.ArgumentParser(
            description='Create cephadm spec file from deployed-metal and roles files')
    parser.add_argument('-m', '--deployed-metal-file', metavar='METAL',
                        help=("Relative path to a file like 'deployed-metal.yaml' "
                              "which is genereated by running a command like "
                              "'openstack overcloud node provision ... "
                              "--output deployed-metal.yaml' "
                              ),
                        required=True)
    parser.add_argument('-r', '--tripleo-roles-file', metavar='ROLES',
                        help=("Relative path to tripleo roles data file. "
                              "Defaults to "
                              "/usr/share/openstack-tripleo-heat-templates/roles_data.yaml"
                              ),
                        default='/usr/share/openstack-tripleo-heat-templates/roles_data.yaml',
                        required=False)
    parser.add_argument('-o', '--ceph-spec-file', metavar='SPEC',
                        help=("Relative path to genereated ceph spec file. "
                              "Defaults to ceph_spec.yaml"
                              ),
                        default='ceph_spec.yml',
                        required=False)
    opts = parser.parse_args(argv[1:])
    return opts


def get_deployed_servers(metalsmith_data_file):
    hosts = {}
    with open(metalsmith_data_file, 'r') as stream:
        try:
            metal = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)
        try:
            port_map = metal['parameter_defaults']['DeployedServerPortMap']
            for host, host_map in port_map.items():
                try:
                    ip = host_map['fixed_ips'][0]['ip_address']
                except Exception:
                    raise RuntimeError(
                        'The DeployedServerPortMap is missing the first '
                        'fixed_ip in the data file: {metalsmith_data_file}'.format(
                            metalsmith_data_file=deployed_metal_file))
                hosts[host.replace('-ctlplane','')] = ip
        except Exception:
            raise RuntimeError(
                'The DeployedServerPortMap is not defined in '
                'data file: {metalsmith_data_file}'.format(
                metalsmith_data_file=metalsmith_data_file))
    return hosts


def get_deployed_roles(metalsmith_data_file):
    roles = []
    with open(metalsmith_data_file, 'r') as stream:
        try:
            metal = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)
        try:
            for item in metal['parameter_defaults']:
                if 'Count' in item:
                    roles.append(item.replace('Count', ''))
        except Exception:
            raise RuntimeError(
                'The parameter_defaults is not defined in '
                'data file: {metalsmith_data_file}'.format(
                metalsmith_data_file=metalsmith_data_file))
    return roles


def get_ceph_services(roles_file):
    roles_to_services = {}
    with open(roles_file, 'r') as stream:
        try:
            roles = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)
        try:
            for role in roles:
                svcs = []
                for svc in role['ServicesDefault']:
                    if 'Ceph' in svc:
                        svcs.append(svc.replace('OS::TripleO::Services::', ''))
                    roles_to_services[role['name']] = svcs
        except Exception:
            raise RuntimeError(
                'Unable to extract the name or ServicesDefault list from '
                'data file: {roles_file}'.format(roles_file=roles_file))
    return roles_to_services


def render(specs, output):
    open(output, 'w').close() # reset file
    for spec in specs:
        with open(output, 'a') as f:
            f.write('---\n')
            f.write(spec)


if __name__ == "__main__":
    specs = []
    OPTS = parse_opts(sys.argv)
    hosts = get_deployed_servers(OPTS.deployed_metal_file)
    #role_to_svc = get_ceph_services(OPTS.tripleo_roles_file)
    #roles = get_deployed_roles(OPTS.deployed_metal_file)
    # for role in roles:
    #     if 'CephMon' in role_to_svc[role]:
    #         print('All servers in ' + role + ' need mon label')
    #     if 'CephMgr' in role_to_svc[role]:
    #         print('All servers in ' + role + ' need mgr label')
    #     if 'CephOSD' in role_to_svc[role]:
    #         print('All servers in ' + role + ' need osd label')
    # Hard coding for now, but you can see how I'd build it above
    mons = ['oc0-controller-1', 'oc0-controller-2']
    osds = ['oc0-ceph-0', 'oc0-ceph-1', 'oc0-ceph-2']

    for host in mons:
        d = mkspec.CephHostSpec('host', hosts[host], host, ['mon'])
        specs.append(d.make_daemon_spec())

    for host in osds:
        d = mkspec.CephHostSpec('host', hosts[host], host, ['osd'])
        specs.append(d.make_daemon_spec())

    d = mkspec.CephDaemonSpec('mon', 'mon', 'mon', mons, '', {}, [])
    specs.append(d.make_daemon_spec())

    d = mkspec.CephDaemonSpec('osd', 'default_drive_group', 'osd.default_drive_group',
                              osds, '', {'data_devices': {'all': True}}, [])
    specs.append(d.make_daemon_spec())

    render(specs, OPTS.ceph_spec_file)
