#!/usr/bin/env bash

RED='\033[0;31m'
NC='\033[0m'
TIME=5
PREVIEW_TIME=30

function test_manila {
    declare -a share1=("/etc/ceph")
    declare -a share2=("/etc/ceph")
    declare -a share3= "/etc/manila")

    echo "---------------------"
    echo "MANILA PREVIEW"
    echo "---------------------"
    printf "* Secret:  ${RED}ceph-client-conf${NC}\n"
        printf "  * ceph.conf: ${RED}/etc/ceph${NC}\n"
        printf "  * ceph.client.openstack.keyring: ${RED}/etc/ceph${NC}\n"
    printf "* Services: ${RED}share1${NC} ${RED}share2${NC}\n"
        printf "\n"
    printf "* Secret:  ${RED}netapp${NC}\n"
        printf "  * 04-secret.conf: ${RED}/etc/manila/manila.conf.d/04-secret.conf${NC}\n"
    printf "* Services: ${RED}share3${NC}\n"
    echo "---------------------"
    sleep $PREVIEW_TIME

    pod=$(oc get pods | awk '/share1/ {print $1}')
    if [ -n "$pod" ]; then
    for m in "${share1[@]}"; do
        printf "Share1 instance: %s ${RED}$pod${NC}:${RED}$m${NC}\n"
        oc exec -it "$pod" -- ls "$m"
        echo "----------------------"
    done
    fi

    sleep $TIME
    pod=$(oc get pods | awk '/share2/ {print $1}')
    if [ -n "$pod" ]; then
    for m in "${share2[@]}"; do
        printf "Share2 instance: %s ${RED}$pod${NC}:${RED}$m${NC}\n"
        oc exec -it "$pod" -- ls "$m"
        echo "----------------------"
    done
    fi

    sleep $TIME
    sec=$(oc get secret | awk '/netapp/ {print $1}')
    if [ -n "$sec" ]; then
        oc describe secret $sec
        echo "----------------------"
    fi
}

test_manila
