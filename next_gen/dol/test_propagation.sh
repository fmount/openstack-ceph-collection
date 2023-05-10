#!/usr/bin/bash

function test_propagation {
    RED='\033[0;31m'
    NC='\033[0m'
    TIME=5
    PREVIEW_TIME=10

    echo "---------------------"
    echo "EXTRA VOLUMES PREVIEW"
    echo "---------------------"
    printf "* Secret:  ${RED}ceph-client-conf${NC}\n"
        printf "  * ceph.conf: ${RED}/etc/ceph${NC}\n"
        printf "  * ceph.client.openstack.keyring: ${RED}/etc/ceph${NC}\n"
    printf "* Services: ${RED}Glance${NC} ${RED}volume1${NC} ${RED}Compute${NC} ${RED}CinderBackup${NC}"
        printf "\n"
    echo "---------------------"
    printf "* Secret: %s" "${RED}ceph-client-conf2${NC}\n"
        printf "  * ceph.conf: ${RED}/etc/ceph2${NC}\n"
        printf "  * ceph.client.openstack.keyring: ${RED}/etc/ceph2${NC}\n"
    printf "* Services: ${RED}Compute${NC} ${RED}volume2${NC} ${RED}Glance${NC}\n"
    echo "---------------------"
    sleep $PREVIEW_TIME

    declare -a glance=("/etc/ceph" "/etc/ceph2")
    declare -a cinder_backup=("/etc/ceph")
    declare -a volume1=("/etc/ceph")
    declare -a volume2=("/etc/ceph2")

    # Glance pods
    pod=$(oc get pods | awk '/glance-internal/ {print $1}')
    if [ -n "$pod" ]; then
    for m in "${glance[@]}"; do
        echo "----------------------"
        printf "Glance instance: %s ${RED}$pod${NC}:${RED}$m${NC}\n"
        oc exec -it "$pod" -- ls "$m"
    done
    fi

    sleep $TIME
    # Glance pods
    pod=$(oc get pods | awk '/glance-external/ {print $1}')
    if [ -n "$pod" ]; then
    for m in "${glance[@]}"; do
        echo "----------------------"
        printf "Glance instance: %s ${RED}$pod${NC}:${RED}$m${NC}\n"
        oc exec -it "$pod" -- ls "$m"
    done
    fi

    sleep $TIME
    # Cinder pods
    pod=$(oc get pods | awk '/cinder-backup/ {print $1}')
    if [ -n "$pod" ]; then
    for m in "${cinder_backup[@]}"; do
        echo "----------------------"
        printf "CinderBackup instance: %s ${RED}$pod${NC}:${RED}$m${NC}\n"
        oc exec -it "$pod" -- ls "$m"
        echo "----------------------"
    done
    fi

    sleep $TIME
    pod=$(oc get pods | awk '/volume1/ {print $1}')
    if [ -n "$pod" ]; then
    for m in "${volume1[@]}"; do
        echo "----------------------"
        printf "CinderVolume1 instance: %s ${RED}$pod${NC}:${RED}$m${NC}\n"
        oc exec -it "$pod" -- ls "$m"
        echo "----------------------"
    done
    fi

    sleep $TIME
    pod=$(oc get pods | awk '/volume2/ {print $1}')
    if [ -n "$pod" ]; then
    for m in "${volume2[@]}"; do
        echo "----------------------"
        printf "CinderVolume2 instance: %s ${RED}$pod${NC}:${RED}$m${NC}\n"
        oc exec -it "$pod" -- ls "$m"
        echo "----------------------"
    done
    fi

    sleep $TIME
    # Compute pods - maybe this is different (oc describe better fits this scenario)
    pod=$(oc get pods | awk '/ansible/ {print $1}')
    if [ -n "$pod" ]; then
    echo "----------------------"
    echo "Ansible Job POD: $pod"
    oc describe pod "$pod" | grep Mounts -A 5
    echo "----------------------"
    fi
}

test_propagation
