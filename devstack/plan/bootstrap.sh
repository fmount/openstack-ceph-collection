#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install python3 chrony lvm2 podman vim jq tmux curl git sudo

# devstack
useradd -s /bin/bash -d /opt/stack -m stack
chmod +x /opt/stack
echo "stack ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/stack

sudo -u stack git clone https://opendev.org/openstack/devstack /opt/stack/devstack

cat > /opt/stack/devstack/local.conf <<'LOCALCONF'
[[local|localrc]]
ADMIN_PASSWORD=secret
DATABASE_PASSWORD=$ADMIN_PASSWORD
RABBIT_PASSWORD=$ADMIN_PASSWORD
SERVICE_PASSWORD=$ADMIN_PASSWORD

########
# CEPH #
########
CEPH_GIT_URL=https://review.opendev.org/openstack/devstack-plugin-ceph
enable_plugin devstack-plugin-ceph $CEPH_GIT_URL

CEPHADM_DEPLOY=True
CEPHADM_DEV_OSD=True
CEPH_LOOPBACK_DISK_SIZE=10G
ENABLE_CEPH_RBD_MIRROR=True

LOGFILE=/opt/stack/logs/devstacklog.txt
LOCALCONF

chown stack:stack /opt/stack/devstack/local.conf
