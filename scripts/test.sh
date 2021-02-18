#!/bin/env bash

# HOST DECLARATION

declare -A hostlist

# controllers
hostlist['controller_hostname_1']='172.16.24.10'
hostlist['controller_hostname_2']='172.16.24.11'
hostlist['controller_hostname_3']='172.16.24.12'

# osds
hostlist['osd_hostname_1']='172.16.24.13'
hostlist['osd_hostname_2']='172.16.24.14'
hostlist['osd_hostname_3']='172.16.24.15'

declare -A ceph_cluster

ceph_cluster['mon1']='controller_hostname_1'
ceph_cluster['mon2']='controller_hostname_2'
ceph_cluster['mon3']='controller_hostname_3'
ceph_cluster['osd1']='osd_hostname_1'
ceph_cluster['osd2']='osd_hostname_2'
ceph_cluster['osd3']='osd_hostname_3'


# Building hosts
test_host_list() {
  for key in "${!ceph_cluster[@]}"; do
      host="$key"
      hostname=${ceph_cluster["$key"]}
      addr=${hostlist["${ceph_cluster["$key"]}"]}
      case "$host" in
        *mon*) label="mon" ;;
        *osd*) label="osd" ;;
      esac
      python mkspec.py -d 'host' -a $hostname -z $addr -l $label
  done

  # mons - Add the minimal amount of daemons
  python mkspec.py -d mon -g "${ceph_cluster['mon1']}","${ceph_cluster['mon2']}","${ceph_cluster['mon3']}"

  # osds - Add the minimal amount of daemons
  python mkspec.py -d osd -i default_drive_group -n osd.default_drive_group \
      -g ${ceph_cluster['osd1']},${ceph_cluster['osd2']},${ceph_cluster['osd3']} \
      -s "{'data_devices':{'paths': [ '/dev/ceph_vg/ceph_lv_data'] }}"

  # crash - Add the crash daemon everywhere
  python mkspec.py -d crash -p '*aaa*'
}

test_host_pattern() {

  # mds - Add the mds daemon on controllers
  python mkspec.py -d mds -p "*controller*" -o test_host_pattern

  # node-exporter - Add this service everywhere in the cluster
  python mkspec.py -d node-exporter -p "*" -o test_host_pattern

}

test_host_list
