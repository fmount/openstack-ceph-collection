#!/bin/bash

sudo lvremove --force /dev/ceph_vg/ceph_lv_data
sudo vgremove --force ceph_vg
sudo pvremove --force /dev/loop2
sudo losetup -d /dev/loop2
sudo rm -f /var/lib/ceph-osd.img
sudo partprobe

sudo dd if=/dev/zero of=/var/lib/ceph-osd.img bs=1 count=0 seek=7G
sudo losetup /dev/loop2 /var/lib/ceph-osd.img
sudo pvcreate  /dev/loop2
sudo vgcreate ceph_vg /dev/loop2
sudo lvcreate -n ceph_lv_data -l +100%FREE ceph_vg
