#!/bin/env bash

function test_glance {

    IMG="cirros-0.5.2-x86_64-disk.img"
    IMG_URL="http://download.cirros-cloud.net/0.5.2/cirros-0.5.2-x86_64-disk.img"

    echo "---------------------"
    echo "---TESTING GLANCE---"
    echo "---------------------"

    export OS_CLOUD=standalone
    openstack image list
    curl -L -o /tmp/cirros-0.5.2-x86_64-disk.img http://download.cirros-cloud.net/0.5.2/cirros-0.5.2-x86_64-disk.img
    qemu-img convert -O raw /tmp/cirros-0.5.2-x86_64-disk.img /tmp/cirros-0.5.2-x86_64-disk.img.raw
    openstack image create --container-format bare --disk-format raw --file /tmp/cirros-0.5.2-x86_64-disk.img.raw cirros
    openstack image list
}


function test_cinder {
    echo "---------------------"
    echo "---TESTING CINDER---"
    echo "---------------------"
        openstack volume type create ceph
        openstack volume type list
        openstack volume type set --property volume_backend_name=tripleo_ceph ceph
        openstack volume create --type ceph --image $(openstack image list -c ID -f value) --size 1 myvol
        sleep 5
        openstack volume list
}

test_glance
sleep 30
test_cinder
