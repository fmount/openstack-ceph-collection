#!/usr/bin/env bash
echo "[centos-ceph-pacific]
name=centos-ceph-pacific
baseurl=http://mirror.centos.org/centos/8/storage/x86_64/ceph-pacific/
gpgcheck=0
enabled=1" > /etc/yum.repos.d/pacific.repo

yum install -y vim cephadm

