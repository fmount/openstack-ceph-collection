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


# A generic function to state that the test is not available
test_spec_not_available() {
    echo "The failure function is availble for a subset of daemon(s), where a spec \
        section can be specified"
    usage
}

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
      -e "{'encrypted':'true', 'data_devices':{'paths': [ '/dev/ceph_vg/ceph_lv_data'] }}"

    # crash - Add the crash daemon everywhere
    python mkspec.py -d crash -p '*'
  } >> "$1"
}

test_add_mon() {
    # mons - Add the minimal amount of daemons
    python mkspec.py -d mon -g "${ceph_cluster['mon1']}","${ceph_cluster['mon2']}","${ceph_cluster['mon3']}" \
        -o "$TARGET_OUT"/mon

    [ "$?" == 0 ] && echo "mon(s) spec exported in $TARGET_OUT"
}

test_add_mon_fail() {
    test_spec_not_available
}

test_add_osd() {
    # osds - Add the minimal amount of daemons
    python mkspec.py -d osd -i default_drive_group -n osd.default_drive_group \
      -g ${ceph_cluster['osd1']},${ceph_cluster['osd2']},${ceph_cluster['osd3']} \
      -e "{'encrypted':true,'data_devices':{'paths': [ '/dev/ceph_vg/ceph_lv_data'] }}" \
      -o "$TARGET_OUT"/osds

    [ "$?" == 0 ] && echo "OSD(s) spec exported in $TARGET_OUT"
}

test_add_osd_fail() {
    # osds - Add the minimal amount of daemons
    python mkspec.py -d osd -i default_drive_group -n osd.default_drive_group \
      -g ${ceph_cluster['osd1']},${ceph_cluster['osd2']},${ceph_cluster['osd3']} \
      -e "{'data':{'paths': [ '/dev/ceph_vg/ceph_lv_data'] }}" \
      -o "$TARGET_OUT"/osds
}

test_add_monitoring() {

  declare -A monitoring_stack=(["grafana"]=3100 ["alertmanager"]=9094 ["prometheus"]=9095 ["node-exporter"]=9100 )

  {
  # node-exporter - Add this service everywhere in the cluster
  python mkspec.py -d node-exporter -p "*" -k 1.2.3.0/24 -s "{'port': ${monitoring_stack['node-exporter']} }"

  for d in "${!monitoring_stack[@]}"; {
    python mkspec.py -d "$d" -l mon -k 1.2.3.0/24 -s "{'port': ${monitoring_stack[$d]} }"

  }
  } >> "$1"

  [ "$?" == 0 ] && echo "Monitoring Stack spec exported in $TARGET_OUT"

}

test_add_monitoring_fail() {
    test_spec_not_available
}

test_add_rgw() {

  {
  python mkspec.py -d rgw -i rgw.default -n rgw.default \
    -g ${ceph_cluster['mon1']},${ceph_cluster['mon2']},${ceph_cluster['mon3']} \
    -k 1.2.3.0/24,4.5.6.0/24 \
    -s "{'rgw_frontend_port': 8080, 'rgw_realm': 'default', 'rgw_zone': 'default', \
         'rgw_frontend_ssl_certificate': '***REMOVED***}" \
    #-o "$TARGET_OUT"/rgw
  } >> "$1"

}

test_add_rgw_fail() {
  python mkspec.py -d rgw -i rgw.default -n rgw.default \
    -g ${ceph_cluster['mon1']},${ceph_cluster['mon2']},${ceph_cluster['mon3']} \
    -s "{'rgw_frontend': 8080, 'rgw_real': 'default', 'rg_zone': 'default', 'aaa':'bbb'}" \
    -o "$TARGET_OUT"/rgw
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

test_add_ganesha_fail() {
  # mds - Add the mds daemon on controllers

  {
      python mkspec.py -d mds -p "*controller*" -o "$TARGET_OUT"/ganesha;
      # nfs - Add the nfs daemon on controllers
      python mkspec.py -d nfs -i standalone_nfs -n nfs.standalone_nfs -p "*controller*" \
      -s "{'namespace': 'ganesha', 'pool': 'manila_data', 'foo': 'bar'}" -o "$TARGET_OUT"/ganesha
  }
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

test_add_hosts_fail() {
    test_spec_not_available
}

test_add_full() {
  for feature in "minimal" "rgw" "ganesha" "monitoring"; do
    printf " * Adding  %s\n" "$feature"
    test_add_$feature "$1"
  done

}

test_add_full_fail() {
    test_spec_not_available
}


cleanup() {
    printf "Cleaning up %s\n" "$TARGET_OUT"
    rm -f "$TARGET_OUT"/*
}

reset_out() {
   [ -n "$1" ] && echo > "$1"
}

usage() {
  # Display Help
  echo "This script is the helper to build several Ceph spec(s)."
  echo
  echo "Syntax: $0 [-a][-c][-u <use_case>][-f <use_case>]" 1>&2;
  echo "Options:"
  echo "a     Execute all the existing use cases."
  echo "c     Clean the target dir where the spec files are rendered."
  echo "u     use the -u <use case> to render a specific daemon spec."
  echo "f     use the -f <use case> to see the spec validation fail."
  echo
  echo "Available use cases are: hosts, minimal, mon, osd, rgw, monitoring, ganesha, full";
  echo
  echo "Examples"
  echo
  echo "./test.sh -a  # build all the use cases in \$TARGET_DIR"
  echo "./test.sh -c  # Clean \$TARGET_DIR"
  echo "./test.sh -u rgw  # render the rgw use case in \$TARGET_DIR"
  echo "./test.sh -u osd  # render the osd use case in \$TARGET_DIR"
  echo "./test.sh -u full # render the full ceph cluster use case in \$TARGET_DIR"
  echo "./test.sh -f rgw  # print the exception reported by the failed test"
  echo "./test.sh -f osd  # print the exception reported by the failed test"
  exit 1
}

test_suite() {
  [ -n "$2" ] && fail="$2" || fail=""
  case "$1" in
    "all")
        for use_case in "hosts" "minimal" "monitoring" "rgw" \
            "ganesha" "full"; do
            echo "Building $use_case spec";
            test_add_$use_case"$fail" "$TARGET_OUT/$use_case"
        done
        ;;
    "full")
        echo "Building Full Ceph Cluster spec"
        if test_add_full"$fail" "$TARGET_OUT/full_cluster"; then
            echo "Full cluster spec exported in $TARGET_OUT"
        fi
        ;;
    "ganesha")
        echo "Building Ganesha spec"
        if test_add_ganesha"$fail" "$TARGET_OUT/ganesha"; then
            echo "Ganesha spec exported in $TARGET_OUT"
        fi
        ;;
    "hosts")
        echo "Building host_list"
        if test_add_hosts"$fail" "$TARGET_OUT/host_list"; then
            echo "Host list exported in $TARGET_OUT"
        fi
        ;;
    "minimal")
        echo "Building minimal cluster spec"
        if test_add_minimal"$fail" "$TARGET_OUT/minimal_cluster_spec"; then
            echo "Minimal spec exported in $TARGET_OUT"
        fi
        ;;
    "mon")
        echo "Building mon(s) spec"
        test_add_mon"$fail" "$TARGET_OUT/mon"
        ;;
    "monitoring")
        echo "Building monitoring_stack"
        test_add_monitoring"$fail" "$TARGET_OUT/monitoring_stack"
        ;;
    "osd")
        echo "Building osd(s) spec"
        test_add_osd"$fail" "$TARGET_OUT/osds"
        ;;
    "rgw")
        echo "Building RGW spec"
        if test_add_rgw"$fail" "$TARGET_OUT/rgw_spec"; then
            echo "RGW spec exported in $TARGET_OUT"
        fi
        ;;
  esac
}

preview=0

if [[ ${#} -eq 0 ]]; then
  usage
fi

# processing options
while getopts "f:u:acph" o; do
    case "${o}" in
      a)
        u="all"
        ;;
      c)
        cleanup
        exit 0
        ;;
      f)
        f="_fail"
        u=${OPTARG}
        ;;
      u)
        u=${OPTARG}
        ;;
      h)
        usage
        ;;
      p)
        preview=1
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
test_suite "${u}" "${f}"
