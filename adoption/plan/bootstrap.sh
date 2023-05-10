#!/usr/bin/env bash
echo "[centos-ceph-pacific]
name=centos-ceph-pacific
baseurl=http://mirror.centos.org/centos/8/storage/x86_64/ceph-pacific/
gpgcheck=0
enabled=1" > /etc/yum.repos.d/pacific.repo

sed -i "s/mirrorlist/#mirrorlist/g" /etc/yum.repos.d/CentOS-*
sed -i "s|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g" /etc/yum.repos.d/CentOS-*
yum -y install python3 chrony lvm2 podman vim jq tmux cephadm
