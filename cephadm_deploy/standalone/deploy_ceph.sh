#!/bin/env bash

SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TARGET_BIN=/usr/bin
ORIG_CONFIG="$HOME/bootstrap_ceph.conf"
CONFIG="/etc/ceph/ceph.conf"
KEYRING="/etc/ceph/ceph.client.admin.keyring"
CEPH_PUB_KEY="/etc/ceph/ceph.pub"

FSID="4b5c8c0a-ff60-454b-a1b4-9747aa737d19"
IMAGE_PACIFIC=${IMAGE_PACIFIC:-'quay.io/ceph/ceph:v16.2.6'}
IP=192.168.121.205

[ -z "$SUDO" ] && SUDO=sudo

# TODO:
#   - feature1 -> add pv/vg/lv for loopback
#   - install cephadm from centos storage sig


ceph_repo() {
  echo "[centos-ceph-pacific]
  name=centos-ceph-pacific
  baseurl=http://mirror.centos.org/centos/8/storage/x86_64/ceph-pacific/
  gpgcheck=0
  enabled=1" > /etc/yum.repos.d/pacific.repo
}


install_cephadm() {
    curl -O https://raw.githubusercontent.com/ceph/ceph/pacific/src/cephadm/cephadm
    $SUDO mv cephadm $TARGET_BIN
    $SUDO chmod +x $TARGET_BIN/cephadm
    echo "[INSTALL CEPHADM] cephadm is ready"
}

rm_cluster() {
  $SUDO "$CEPHADM" rm-cluster --fsid "$FSID" --force
  echo "[CEPHDM] Cluster deleted"
}

install_cephadm

if [ -z "$CEPHADM" ]; then
     CEPHADM=${TARGET_BIN}/cephadm
fi

cat <<EOF > $ORIG_CONFIG
[global]
  log to file = true
  osd crush chooseleaf type = 0
EOF

$SUDO $CEPHADM --image $IMAGE_PACIFIC \
      bootstrap \
      --fsid $FSID \
      --config $ORIG_CONFIG \
      --output-config $CONFIG \
      --output-keyring $KEYRING \
      --output-pub-ssh-key $CEPH_PUB_KEY \
      --allow-overwrite \
      --allow-fqdn-hostname \
      --skip-monitoring-stack \
      --skip-dashboard \
      --skip-firewalld \
      --mon-ip $IP \
