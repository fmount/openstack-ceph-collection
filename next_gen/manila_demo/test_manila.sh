#!/usr/bin/env bash

RED='\033[0;31m'
NC='\033[0m'
TIME=5
PREVIEW_TIME=30
NAPP=0
PROTO=("nfs" "cephfs")
SIZE=1
CLIENTS=("10.10.10.15" "10.10.10.16")

function test_mshare {
    echo "=> MANILA SHARE SERVICES"
    oc rsh openstackclient openstack share service list | grep -vi log
    echo "=> MANILA POOL LIST"
    oc rsh openstackclient openstack share pool list | grep -vi log
    echo "=> CREATE SHARE"
    for p in "${PROTO[@]}"; do
        echo "Creating share: share_$p"
        oc rsh openstackclient openstack share create --name share_$p $p $SIZE
    done
    echo "=> LIST THE RESULTING SHARES"
    oc rsh openstackclient openstack share list | grep -vi log
    echo "=> CREATE ACCESS RULE"
    for client in "${CLIENTS[@]}"; do
        for p in "${PROTO[@]}"; do
           share_id=$(oc rsh openstackclient openstack share list | grep -vi log | grep -E "share_$p" | awk '{print $2}')
           echo oc rsh openstackclient openstack share access create $share_id $client
        done
    done
    echo "=> SHOW PATH"
    echo "=> MOUNT SHARE TO CLIENT NODE [OK]"
    echo "=> MOUNT SHARE TO CLIENT NODE [KO]"
}

function test_manila {
    declare -a share1=("/etc/ceph")
    declare -a share2=("/etc/ceph")
    declare -a share3=("/etc/manila")

    echo "---------------------"
    echo "MANILA PREVIEW"
    echo "---------------------"
    printf "* Secret:  ${RED}ceph-client-conf${NC}\n"
    printf "  * ceph.conf: ${RED}/etc/ceph${NC}\n"
    printf "  * ceph.client.openstack.keyring: ${RED}/etc/ceph${NC}\n"
    printf "* Backends: ${RED}share1${NC} ${RED}share2${NC}\n"
    echo "---------------------"
    if [ $NAPP -gt 0 ]; then
        printf "* Secret:  ${RED}netapp${NC}\n"
        printf "  * 04-secret.conf: ${RED}/etc/manila/manila.conf.d/04-secret.conf${NC}\n"
        printf "* Services: ${RED}share3${NC}\n"
        echo "---------------------"
    fi
    printf "* Client nodes:\n"
    for client in "${CLIENTS[@]}"; do
        printf "  * Node: ${RED}$client${NC}\n"
    done
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

    if [ $NAPP -gt 0 ]; then
        sleep $TIME
        sec=$(oc get secret | awk '/netapp/ {print $1}')
        if [ -n "$sec" ]; then
            oc describe secret $sec
            echo "----------------------"
        fi
        PROTO+=("netapp")
    fi
}

test_manila
test_mshare
