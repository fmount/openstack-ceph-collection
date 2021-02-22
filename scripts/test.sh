#!/bin/env bash

# HOST DECLARATION

declare -A hostlist
TARGET_OUT="spec_out"

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

  {
    # mons - Add the minimal amount of daemons
    python mkspec.py -d mon -g "${ceph_cluster['mon1']}","${ceph_cluster['mon2']}","${ceph_cluster['mon3']}"

    # mgrs - Add the minimal amount of daemons
    python mkspec.py -d mgr -g "${ceph_cluster['mon1']}","${ceph_cluster['mon2']}","${ceph_cluster['mon3']}"

    # osds - Add the minimal amount of daemons
    python mkspec.py -d osd -i default_drive_group -n osd.default_drive_group \
      -g ${ceph_cluster['osd1']},${ceph_cluster['osd2']},${ceph_cluster['osd3']} \
      -s "{'data_devices':{'paths': [ '/dev/ceph_vg/ceph_lv_data'] }}"

    # crash - Add the crash daemon everywhere
    python mkspec.py -d crash -p '*'
  } >> "$1"
}

test_add_monitoring() {

  monitoring_stack=("grafana" "prometheus" "alertmanager")

    {
    # node-exporter - Add this service everywhere in the cluster
    python mkspec.py -d node-exporter -p "*"

    for d in "${monitoring_stack[@]}"; {
      python mkspec.py -d "$d" -l mon

    }
  } >> "$1"
}

test_add_rgw() {
  python mkspec.py -d rgw -i rgw.default -n rgw.default \
    -g ${ceph_cluster['mon1']},${ceph_cluster['mon2']},${ceph_cluster['mon3']} \
    -s "{'rgw_frontend_port': 8080, 'rgw_realm': 'default', 'rgw_zone': 'default'}" \
    -o "$TARGET_OUT"/rgw
    # >> "$1"
}

test_add_ganesha() {
  # mds - Add the mds daemon on controllers

  {
      python mkspec.py -d mds -p "*controller*";
      # nfs - Add the nfs daemon on controllers
      python mkspec.py -d nfs -i standalone_nfs -n nfs.standalone_nfs -p "*controller*" \
      -s "{'namespace': 'ganesha', 'pool': 'manila_data'}"
  } >> "$1"
}

test_add_hosts() {
  for key in "${!hostlist[@]}"; {
    case "$key" in
      *controller*) label="mon,controller" ;;
      *osd*) label="osd,ceph_storage" ;;
    esac
    python mkspec.py -d host -a "$key" -z "${hostlist[$key]}" -l "$label" >> "$1"
  }
}

test_add_full() {
  for feature in "minimal" "rgw" "ganesha"; do
    printf " * Adding  %s\n" "$feature"
    test_add_$feature "$1"
  done

}

cleanup() {
    printf "Cleaning up %s\n" "$TARGET_OUT"
    rm -f "$TARGET_OUT"/*
}

usage() {
  # Display Help
  echo "This script is the helper to build several Ceph spec(s)."
  echo
  echo "Syntax: $0 [-a][-c][-u <use_case>]" 1>&2;
  echo "Options:"
  echo "a     Execute all the existing use cases."
  echo "c     Clean the target dir where the spec files are rendered."
  echo "u     use the -u <use case> to render a specific daemon spec."
  echo
  echo "Available use cases are: hosts, minimal, rgw, monitoring, ganesha, full";
  echo
  echo "Examples"
  echo
  echo "./test.sh -a  # build all the use cases in \$TARGET_DIR"
  echo "./test.sh -c  # Clean \$TARGET_DIR"
  echo "./test.sh -u rgw  # render the rgw use case in \$TARGET_DIR"
  echo "./test.sh -u full  # render the full ceph cluster use case in \$TARGET_DIR"
  exit 1
}

test_suite() {
  case "$1" in
    "all")
        for use_case in "hosts" "minimal" "monitoring" "rgw" \
            "ganesha" "full"; do
            echo "Building $use_case spec";
            test_add_$use_case "$TARGET_OUT/$use_case"
        done
        ;;
    "hosts")
        echo "Building host_list"
        test_add_hosts "$TARGET_OUT/host_list"
        echo "Host list exported in $TARGET_OUT"
        ;;
    "minimal")
        echo "Building minimal cluster spec"
        test_add_minimal "$TARGET_OUT/minimal_cluster_spec"
        echo "Minimal spec exported in $TARGET_OUT"
        ;;
    "ganesha")
        echo "Building Ganesha spec"
        test_add_ganesha "$TARGET_OUT/ganesha"
        echo "Ganesha spec exported in $TARGET_OUT"
        ;;
    "monitoring")
        echo "Building monitoring_stack"
        test_add_monitoring_stack "$TARGET_OUT/monitoring_stack"
        echo "Monitoring Stack spec exported in $TARGET_OUT"
        ;;
    "rgw")
        echo "Building RGW spec"
        test_add_rgw "$TARGET_OUT/rgw_spec"
        echo "RGW spec exported in $TARGET_OUT"
        ;;
    "full")
        echo "Building Full Ceph Cluster spec"
        test_build_spec_before_bootstrap "$TARGET_OUT/full_cluster"
        echo "Full cluster spec exported in $TARGET_OUT"
        ;;
  esac
}

if [[ ${#} -eq 0 ]]; then
  usage
fi

# processing options
while getopts "u:ach" o; do
    case "${o}" in
      a)
        u="all"
        ;;
      c)
        cleanup
        exit 0
        ;;
      u)
        u=${OPTARG}
        ;;
      h)
        usage
        ;;
      *)
        usage
        ;;
    esac
done

shift $((OPTIND-1))

if [ -z "${u}" ]; then
    usage
fi

# prereq - cleanup previous executions and build output dir
cleanup
mkdir -p "$TARGET_OUT"

# always use the last option provided since this is a "one shot"
# script
test_suite "${u}"
