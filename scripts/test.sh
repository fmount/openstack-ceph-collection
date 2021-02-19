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
test_add_minimal() {
  for key in "${!ceph_cluster[@]}"; do
    host="$key"
    hostname=${ceph_cluster["$key"]}
    addr=${hostlist["${ceph_cluster["$key"]}"]}
    case "$host" in
      *mon*) label="mon" ;;
      *osd*) label="osd" ;;
    esac
    python mkspec.py -d 'host' -a $hostname -z $addr -l $label >> "$1"
  done

  # mons - Add the minimal amount of daemons
  python mkspec.py -d mon -g "${ceph_cluster['mon1']}","${ceph_cluster['mon2']}","${ceph_cluster['mon3']}" >> "$1"

  # osds - Add the minimal amount of daemons
  python mkspec.py -d osd -i default_drive_group -n osd.default_drive_group \
    -g ${ceph_cluster['osd1']},${ceph_cluster['osd2']},${ceph_cluster['osd3']} \
    -s "{'data_devices':{'paths': [ '/dev/ceph_vg/ceph_lv_data'] }}" >> "$1"

  # crash - Add the crash daemon everywhere
  python mkspec.py -d crash -p '*' >> "$1"
}

test_add_monitoring_stack() {

  monitoring_stack=("grafana" "prometheus" "alertmanager")

  # node-exporter - Add this service everywhere in the cluster
  python mkspec.py -d node-exporter -p "*" -o monitoring_stack >> "$1"

  for d in "${monitoring_stack[@]}"; {
    python mkspec.py -d "$d" -l mon -o monitoring_stack >> "$1"
  }
}

test_add_rgw() {
  python mkspec.py -d rgw -i rgw.default -n rgw.default \
    -g ${ceph_cluster['mon1']},${ceph_cluster['mon2']},${ceph_cluster['mon3']} \
    -s "{'rgw_frontend_port': 8080, 'rgw_realm': 'default', 'rgw_zone': 'default' }" \
    >> "$1"
}

test_add_mds_nfs() {
  # mds - Add the mds daemon on controllers

  python mkspec.py -d mds -p "*controller*" >> "$1"

  # nfs - Add the nfs daemon on controllers
  python mkspec.py -d nfs -i standalone_nfs -n nfs.standalone_nfs -p "*controller*" \
    -s "{'namespace': 'ganesha', 'pool': 'manila_data'}" \
    >> "$1"
}

test_add_hosts() {
  for key in "${!hostlist[@]}"; {
    case "$key" in
      *controller*) label="mon,controller" ;;
      *osd*) label="osd,ceph_storage" ;;
    esac
    if [ -n "$1" ]; then
      python mkspec.py -d host -a "$key" -z "${hostlist[$key]}" -l "$label" >> "$1"
    else
      python mkspec.py -d host -a "$key" -z "${hostlist[$key]}" -l "$label"
    fi
  }
}

test_build_spec_before_bootstrap() {
  output=default_ceph_spec
  for feature in "hosts" "minimal" "rgw" "mds_nfs"; do
    printf " * Adding  %s\n" "$feature"
    test_add_$feature $output
  done

}

echo "Building host_list"
test_add_hosts "host_list"
echo "Building minimal cluster spec"
test_add_minimal "minimal_cluster_spec"
echo "Building monitoring_stack"
test_add_monitoring_stack "monitoring_stack"
echo "Building RGW spec"
test_add_rgw "rgw_spec"
echo "Building Ganesha spec"
test_add_mds_nfs "ganesha"
echo "Building Ganesha spec"
test_build_spec_before_bootstrap
