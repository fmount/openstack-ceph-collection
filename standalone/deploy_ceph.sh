#!/bin/env bash

# GENERIC CEPHADM INTERNAL OPTIONS, DO NOT EDIT
TARGET_BIN=/usr/bin
ORIG_CONFIG="$HOME/bootstrap_ceph.conf"
CONFIG="/etc/ceph/ceph.conf"
KEYRING="/etc/ceph/ceph.client.admin.keyring"
CEPH_PUB_KEY="/etc/ceph/ceph.pub"
EXPORT="$HOME/ceph_export.yml"
REQUIREMENTS=("jq" "lvm" "python")

# DEFAULT OPTIONS
FSID="4b5c8c0a-ff60-454b-a1b4-9747aa737d19"
CONTAINER_IMAGE=${CONTAINER_IMAGE:-'quay.io/ceph/ceph:v16.2.6'}
IP=${IP:-'127.0.0.1'}
DEVICES=()
SERVICES=()
KEYS=("client.***REMOVED***") # at least the client.***REMOVED*** default key should be created
KEY_EXPORT_DIR="/etc/ceph"
# DEVICES=("/dev/ceph_vg/ceph_lv_data")
# SERVICES=("RGW" "MDS" "NFS") # monitoring is removed for now
SLEEP=5
ATTEMPTS=30
MIN_OSDS=1
DEBUG=0
# NFS OPTIONS
FSNAME=${FSNAME:-'cephfs'}
NFS_INGRESS=0
NFS_PORT=12345
NFS_INGRESS_FPORT=20049
NFS_INGRESS_MPORT=9000
INGRESS_SPEC="ingress.yml"

# POOLS
declare -A POOLS
# POOLS[test]='rbd'
DEFAULT_PG_NUM=8
DEFAULT_PGP_NUM=8

# RGW OPTIONS
RGW_PORT=8080

[ -z "$SUDO" ] && SUDO=sudo

# TODO:
#   - feature1 -> add pv/vg/lv for loopback
#   - install cephadm from centos storage sig


function ceph_repo() {
    echo "[centos-ceph-pacific]
    name=centos-ceph-pacific
    baseurl=http://mirror.centos.org/centos/8/storage/x86_64/ceph-pacific/
    gpgcheck=0
    enabled=1" > /etc/yum.repos.d/pacific.repo
}

function install_cephadm() {
    curl -O https://raw.githubusercontent.com/ceph/ceph/pacific/src/cephadm/cephadm
    $SUDO mv cephadm $TARGET_BIN
    $SUDO chmod +x $TARGET_BIN/cephadm
    echo "[INSTALL CEPHADM] cephadm is ready"
}

function rm_cluster() {
    if ! [ -x "$CEPHADM" ]; then
        install_cephadm
        CEPHADM=${TARGET_BIN}/cephadm
    fi
    cluster=$(sudo cephadm ls | jq '.[]' | jq 'select(.name | test("^mon*")).fsid')
    if [ -n "$cluster" ]; then
        sudo cephadm rm-cluster --zap-osds --fsid "$FSID" --force
        echo "[CEPHADM] Cluster deleted"
    fi
}

function build_osds_from_list() {
    for item in "${DEVICES[@]}"; do
        echo "Creating osd $item on node $HOSTNAME"
        $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
            --keyring $KEYRING -- ceph orch daemon add osd "$HOSTNAME:$item"
    done
}

function rgw() {
    # TODO: Add more logic here and process parameters
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph orch apply rgw default \
        '--placement="$HOSTNAME" count:1' --port "$RGW_PORT"
}

function mds() {
    # Two pools are generated by this action
    # - $FSNAME.FSNAME.data
    # - $FSNAME.FSNAME.meta
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph orch apply mds "$FSNAME" \
        --placement="$HOSTNAME"
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph fs volume create "$FSNAME" \
        --placement="$HOSTNAME"
}

function nfs() {
    echo "[CEPHADM] Deploy nfs.$FSNAME backend"
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph orch apply nfs \
        "$FSNAME" --placement="$HOSTNAME" --port $NFS_PORT

    if [ "$NFS_INGRESS" -eq 1 ]; then
      echo "[CEPHADM] Deploy nfs.$FSNAME Ingress Service"
      $SUDO "$CEPHADM" shell -m /tmp/"$INGRESS_SPEC" --fsid $FSID \
          --config $CONFIG --keyring $KEYRING -- ceph orch apply -i \
          /mnt/"$INGRESS_SPEC"
    fi
}

function process_services() {
    for item in "${SERVICES[@]}"; do
        case "$item" in
          mds|MDS)
          echo "Deploying MDS on node $HOSTNAME"
          mds
          ;;
          nfs|NFS)
          echo "Deploying NFS on node $HOSTNAME"
          nfs
          ;;
          rgw|RGW)
          echo "Deploying RGW on node $HOSTNAME"
          rgw
          ;;
        esac
    done
}

# Pools are tied to their application, therefore the function
# iterates over the associative array that defines this relationship
# e.g. { 'volumes': 'rbd', 'manila_data': 'cephfs' }
function create_pools() {

    [ "${#POOLS[@]}" -eq 0 ] && return;

    for pool in "${!POOLS[@]}"; do
        $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
            --keyring $KEYRING -- ceph osd pool create "$pool" $DEFAULT_PG_NUM \
            $DEFAULT_PGP_NUM replicated --autoscale-mode on

        # set the application to the pool (which also means rbd init the pool)
        $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
            --keyring $KEYRING -- ceph osd pool application enable "$pool" "${POOLS[$pool]}"
    done
}

function build_caps() {
    local CAPS=""
    for pool in "${!POOLS[@]}"; do
      caps="allow rwx pool="$pool
      CAPS+=$caps,
    done
    echo "${CAPS::-1}"
}

function create_keys() {

    local name=$1
    local caps
    local osd_caps

    if [ "${#POOLS[@]}" -eq 0 ]; then
        osd_caps="allow *"
    else
        caps=$(build_caps)
        osd_caps="allow class-read object_prefix rbd_children, $caps"
    fi

    $SUDO "$CEPHADM" shell -v "$KEY_EXPORT_DIR:$KEY_EXPORT_DIR" --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph auth get-or-create "$name" mon "allow r" osd "$osd_caps" \
        -o "KEY_EXPORT_DIR/$name.keyring"
}

function cephadm_debug() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "[CEPHADM] Enabling Debug mode"
        $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
            --keyring $KEYRING -- ceph config set mgr mgr/cephadm/log_to_cluster_level debug
        echo "[CEPHADM] See debug logs running: ceph -W cephadm --watch-debug"
    fi
}

function check_cluster_status() {
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph -s -f json-pretty
}

function export_spec() {
    $SUDO "$CEPHADM" shell --fsid $FSID --config $CONFIG \
        --keyring $KEYRING -- ceph orch ls --export > "$EXPORT"
    echo "Ceph cluster config exported: $EXPORT"
}

function dump_log() {
    local daemon="$1"
    local num_lines=100

    echo "-------------------------"
    echo "dump daemon log: $daemon"
    echo "-------------------------"

    $SUDO $CEPHADM logs --fsid $FSID --name "$daemon" -- --no-pager -n $num_lines
}

function dump_all_logs() {
    local daemons
    daemons=$($SUDO $CEPHADM ls | jq -r '.[] | select(.fsid == "'$FSID'").name')

    echo "Dumping logs for daemons: $daemons"
    for d in $daemons; do
        dump_log "$d"
    done
}

function prereq() {
    for cmd in "${REQUIREMENTS[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Command $cmd not found"
            exit 1;
        fi
    done

}

function usage() {
    # Display Help
    # ./deploy_ceph.sh -c quay.io/ceph/ceph:v16.2.6 -i 192.168.121.205 \
    #    -p volumes:rbd -p images -s rgw -s nfs -s mds -d /dev/ceph_vg/ceph_lv_data
    echo "Deploy a standalone Ceph cluster."
    echo
    echo "Syntax: $0 [-i <ip>][-p <pool><application>][-s <service>][-d </dev/device/path>]" 1>&2;
    echo "Options:"
    echo "d     Device path that is used to build OSD(s)."
    echo "h     Print this menu."
    echo "i     IP address where the mon(s)/mgr(s) daemons are deployed."
    echo "p     Pool list that are created (this option can be passed in the form pool:application)"
    echo "s     Services/Daemons that are added to the cluster."
    echo "t     Tear down the Ceph cluster."
    echo
    echo "Examples"
    echo
    echo "1. Deploy a minimal Ceph cluster using the specified IP"
    echo "> $0 -i 192.168.121.205"
    echo
    echo "2. Build the OSD(s) according to the specified paths"
    echo "> $0 -i IP -d /dev/ceph_vg/ceph_lv_data -d /dev/ceph_vg/ceph_lv_data1"
    echo
    echo "3. Deploy the Ceph cluster and add the specified pools"
    echo "> $0 -i IP -p volumes -p images:rbd"
    echo
    echo "4. Deploy the Ceph cluster and add the specified keys"
    echo "> $0 -i IP -k client.***REMOVED*** -k client.manila -k client.glance"
    echo
    echo "5. Deploy the Ceph cluster and add the specified services"
    echo
    echo "> $0 -i IP -s rgw -s mds -s nfs"
    echo
    echo "6. Deploy the Ceph cluster using the given image:tag"
    echo "> $0 -i IP -c image:tag"
    echo
    echo "7. Tear Down the Ceph cluster"
    echo "> $0 -t"
    echo
    echo "A real use case Example"
    echo "$0 -c quay.io/ceph/ceph:v16.2.6 -i 192.168.121.205 -p volumes:rbd -s rgw -s nfs -s mds -d /dev/vdb"
}

function preview() {
    echo "---------"
    echo "SERVICES"
    for daemon in "${SERVICES[@]}"; do
        echo "* $daemon"
    done

    echo "---------"
    echo "POOLS"
    for key in "${!POOLS[@]}"; do
        echo "* $key:${POOLS[$key]}";
    done

    echo "---------"
    echo "KEYS"
    for kname in "${KEYS[@]}"; do
        echo "* $kname";
    done

    echo "---------"
    echo "DEVICES"
    for dev in "${DEVICES[@]}"; do
        echo "* $dev"
    done
    [ -z "$DEVICES" ] && echo "Using ALL available devices"

    echo "---------"
    echo IP Address: "$IP"
    echo "---------"
    echo "Container Image: $CONTAINER_IMAGE"
    echo "---------"
}

if [[ ${#} -eq 0 ]]; then
  usage
  exit 1
fi

## Process input parameters
while getopts "c:s:i:p:d:k:t" opt; do
    case $opt in
        c) CONTAINER_IMAGE="$OPTARG";;
        d) DEVICES+=("$OPTARG");;
        k) KEYS+=("$OPTARG");;
        i) IP="$OPTARG";;
        p) curr_pool=(${OPTARG//:/ })
           [ -z "${curr_pool[1]}" ] && curr_pool[1]=rbd
           # POOLS input is provided in the form { POOL:APPLICATION }.
           # An associative array is built starting from this input.
           POOLS[${curr_pool[0]}]=${curr_pool[1]}
           ;;
        s) SERVICES+=("$OPTARG");;
        t) rm_cluster
           exit 0
           ;;
        *) usage
    esac
done
shift $((OPTIND -1))

prereq
preview
install_cephadm

if [ -z "$CEPHADM" ]; then
     CEPHADM=${TARGET_BIN}/cephadm
fi

cat <<EOF > "$ORIG_CONFIG"
[global]
  log to file = true
  osd crush chooseleaf type = 0
  osd_pool_default_pg_num = 8
  osd_pool_default_pgp_num = 8
  osd_pool_default_size = 1
[mon]
  mon_warn_on_insecure_global_id_reclaim_allowed = False
  mon_warn_on_pool_no_redundancy = False
EOF

cluster=$(sudo cephadm ls | jq '.[]' | jq 'select(.name | test("^mon*")).fsid')
if [ -z "$cluster" ]; then
$SUDO $CEPHADM --image "$CONTAINER_IMAGE" \
      bootstrap \
      --fsid $FSID \
      --config "$ORIG_CONFIG" \
      --output-config $CONFIG \
      --output-keyring $KEYRING \
      --output-pub-ssh-key $CEPH_PUB_KEY \
      --allow-overwrite \
      --allow-fqdn-hostname \
      --skip-monitoring-stack \
      --skip-dashboard \
      --skip-firewalld \
      --mon-ip $IP

# Wait cephadm backend to be operational
sleep "$SLEEP"
fi

cephadm_debug
# let's add some osds
if [ -z "$DEVICES" ]; then
    echo "Using ALL available devices"
    $SUDO $CEPHADM shell ceph orch apply osd --all-available-devices
else
    build_osds_from_list
fi


while [ "$ATTEMPTS" -ne 0 ]; do
    num_osds=$($SUDO $CEPHADM shell --fsid $FSID --config $CONFIG \
      --keyring $KEYRING -- ceph -s -f json | jq '.osdmap | .num_up_osds')
    if [ "$num_osds" -ge "$MIN_OSDS" ]; then break; fi
    ATTEMPTS=$(("$ATTEMPTS" - 1))
    sleep 1
done
echo "[CEPHADM] OSD(s) deployed: $num_osds"

[ "$num_osds" -lt "$MIN_OSDS" ] && exit 255


if [ "$NFS_INGRESS" -eq 1 ]; then
cat > /tmp/$INGRESS_SPEC <<-EOF
service_type: ingress
service_id: nfs.$FSNAME
placement:
  count: 1
spec:
  backend_service: nfs.$FSNAME
  frontend_port: $NFS_INGRESS_FPORT
  monitor_port: $NFS_INGRESS_MPORT
  virtual_ip: $IP/24" > /tmp/"$INGRESS_SPEC"
EOF
fi

# add the provided pools
create_pools
for key_name in "${KEYS[@]}"; do
    echo "Processing key $key_name"
    create_keys "$key_name"
done

# add more services
process_services
check_cluster_status
export_spec