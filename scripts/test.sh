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
test_minimal() {
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
  python mkspec.py -d crash -p '*'
}

test_monitoring_stack() {

  monitoring_stack=("grafana" "prometheus" "alertmanager")

  # node-exporter - Add this service everywhere in the cluster
  python mkspec.py -d node-exporter -p "*" -o monitoring_stack

  for d in "${monitoring_stack[@]}"; {
      python mkspec.py -d "$d" -l mon -o monitoring_stack
  }
}

test_rgw() {
    python mkspec.py -d rgw -i rgw.default -n rgw.default \
        -g ${ceph_cluster['mon1']},${ceph_cluster['mon2']},${ceph_cluster['mon3']} \
        -s "{'rgw_frontend_port': 8080, 'rgw_realm': 'default', 'rgw_zone': 'default' }" \
        -o rgw_spec
}

test_mds_nfs() {
  # mds - Add the mds daemon on controllers
  python mkspec.py -d mds -p "*controller*" -o ganesha

  # nfs - Add the nfs daemon on controllers
  python mkspec.py -d nfs -i standalone_nfs -n nfs.standalone_nfs -p "*controller*" \
      -s "{'namespace': 'ganesha', 'pool': 'manila_data'}" \
      -o ganesha

}

test_minimal
test_monitoring_stack
test_rgw
test_mds_nfs
