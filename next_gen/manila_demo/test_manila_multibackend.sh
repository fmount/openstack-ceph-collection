#!/usr/bin/env bash

RED='\033[0;31m'
NC='\033[0m'
TIME=7
PREVIEW_TIME=25
NAPP=1
declare -A SHARES
SHARES=(["share_nfs"]="nfs" ["share_netapp"]="nfs" ["share_cephfs"]="cephfs")
SIZE=1


declare -A CLIENTS
CLIENTS=(["192.168.130.27"]="10.10.10.50" ["192.168.130.28"]="10.10.10.60")

function test_mshare {
    echo
    printf "=> ${RED}MANILA SHARE SERVICES${NC}\n"
    oc rsh openstackclient openstack share service list
    echo
    printf "=> ${RED}MANILA POOL LIST${NC}\n"
    oc rsh openstackclient openstack share pool list
    sleep $TIME
    echo
    printf "=> ${RED}CREATE SHARE TYPES${NC}\n"
    echo oc rsh openstackclient openstack share type create default False\
                  --extra-specs snapshot_support=True  \
                  create_share_from_snapshot_support=True vendor_name=Ceph
    if [ $NAPP -gt 0 ]; then
        echo oc rsh openstackclient openstack share type create bigboxtype False \
                  --extra-specs snapshot_support=True  \
                  revert_to_snapshot_support=True \
                  create_share_from_snapshot_support=True
    fi
    sleep $TIME
    echo
    printf "=> ${RED}MANILA SHARE TYPE LIST${NC}\n"
    oc rsh openstackclient openstack share type list
    echo 
    sleep $TIME
    printf "=> ${RED}CREATE SHARE${NC}\n"
    for p in "${!SHARES[@]}"; do
        echo "oc rsh openstackclient openstack share create --name $p "${SHARES["$p"]}" $SIZE"
    done
    echo
    sleep $TIME

    printf "=> ${RED}LIST THE RESULTING SHARES${NC}\n"
    oc rsh openstackclient openstack share list
    sleep $TIME
    echo 

    printf "=> ${RED}SHOW SHARES LOCATION${NC}\n"
    echo
    for p in "${!SHARES[@]}"; do
    echo "$p"
    echo "-----"
    oc rsh openstackclient openstack share export location list $p -c Path -f value
    echo "-----"
    echo
    done
    sleep $TIME
}

function test_all_shares {

    local client1="192.168.130.27"
    local share_nfs="192.168.130.21:/volumes/_nogroup/61139d4d-4f6b-4c6b-8966-a51c72ad8393/1d2562d5-1c5e-4fcf-92c0-e437032d74fc"
    local share_netapp="192.168.1.107:/share_4d8201d4_f667_4f7c_b004_8dd07f7d7a2e"
    local share_cephfs="192.168.130.26:6789:/volumes/_nogroup/733bb2e6-a704-4632-b347-4401582a6331/a7bbf8fa-ef8f-4242-a5b2-3905e5606054"

    echo
    printf "=> ${RED}CREATE ACCESS RULE${NC}\n"
    echo oc rsh openstackclient openstack share access create share_nfs ip $client1
    echo oc rsh openstackclient openstack share access create share_netapp ip $client1
    #oc rsh openstackclient openstack share access create share_cephfs ip $client1
    echo oc rsh openstackclient openstack share access create share_cephfs cephx alice
    echo
    sleep $TIME

    printf "=> ${RED}LIST ACCESS RULES${NC}\n"
    for p in "${!SHARES[@]}"; do
       oc rsh openstackclient openstack share access list $p
    done
    sleep $TIME
    echo

    echo "sudo -u root ssh root@10.10.10.50 mkdir -p /mnt/share_{nfs,netapp,cephfs}"
    #sudo -u root ssh root@10.10.10.50 mkdir -p /mnt/share_{nfs,netapp,cephfs}
    echo "sudo -u root ssh root@10.10.10.50 mount -t nfs 192.168.130.21:/volumes/_nogroup/61139d4d-4f6b-4c6b-8966-a51c72ad8393/1d2562d5-1c5e-4fcf-92c0-e437032d74fc /mnt/share_nfs"
    sudo -u root ssh root@10.10.10.50 mount -t nfs 192.168.130.21:/volumes/_nogroup/61139d4d-4f6b-4c6b-8966-a51c72ad8393/1d2562d5-1c5e-4fcf-92c0-e437032d74fc /mnt/share_nfs
    echo "sudo -u root ssh root@10.10.10.50 mount -t nfs 192.168.1.107:/share_4d8201d4_f667_4f7c_b004_8dd07f7d7a2e /mnt/share_netapp"
    sudo -u root ssh root@10.10.10.50 mount -t nfs 192.168.1.107:/share_4d8201d4_f667_4f7c_b004_8dd07f7d7a2e /mnt/share_netapp
    cephx_secret=$(oc rsh openstackclient openstack share access list share_cephfs -c "Access Key" -f value)
    echo "sudo -u root ssh root@10.10.10.50 mount -t ceph 192.168.130.26:6789:/volumes/_nogroup/733bb2e6-a704-4632-b347-4401582a6331/a7bbf8fa-ef8f-4242-a5b2-3905e5606054 /mnt/share_cephfs -o name=alice,secret=*******"
    sudo -u root ssh root@10.10.10.50 mount -t ceph 192.168.130.26:6789:/volumes/_nogroup/733bb2e6-a704-4632-b347-4401582a6331/a7bbf8fa-ef8f-4242-a5b2-3905e5606054 /mnt/share_cephfs -o name=alice,secret=$cephx_secret 2>/dev/null

    sleep $TIME
    echo
    printf "=> ${RED}RESULTING MOUNT(s)${NC}\n"
    echo 
    echo sudo -u root ssh root@10.10.10.50 mount | grep -E "mnt"
    sudo -u root ssh root@10.10.10.50 mount | grep -E "mnt"
    echo
    sleep $TIME

    echo
    printf "=> ${RED}CREATE FILES${NC}\n"
    for p in "${!SHARES[@]}"; do
    echo
        echo "sudo -u root ssh root@10.10.10.50 touch /mnt/$p/test_file1"
        sudo -u root ssh root@10.10.10.50 touch /mnt/$p/test_file1
        echo "sudo -u root ssh root@10.10.10.50 touch /mnt/$p/test_file2"
        sudo -u root ssh root@10.10.10.50 touch /mnt/$p/test_file2
        echo "sudo -u root ssh root@10.10.10.50 touch /mnt/$p/test_file3"
        sudo -u root ssh root@10.10.10.50 touch /mnt/$p/test_file3
    echo
    sleep 5
    done
    echo
    printf "=> ${RED}LIST FILES${NC}\n"
    echo 
    echo "sudo -u root ssh root@10.10.10.50 ls -l /mnt/share_*"
    echo 
    sudo -u root ssh root@10.10.10.50 ls -lAh /mnt/share_* | grep -vE "(^d|total)"
    echo
    sleep 10
    echo
    printf "=> ${RED}UNMOUNT!${NC}\n"
    echo 
    for p in "${!SHARES[@]}"; do
        echo "sudo -u root ssh root@10.10.10.50 umount /mnt/$p"
        sudo -u root ssh root@10.10.10.50 umount /mnt/$p
    done
}

function test_manila {
    declare -a share1=("/etc/ceph")
    declare -a share2=("/etc/ceph")
    declare -a share3=("/etc/manila/manila.conf.d/")

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
    for client in "${!CLIENTS[@]}"; do
        printf "  * Node: ${RED}$client${NC}\n"
        printf "    * Mgmt: ${RED}${CLIENTS[$client]}${NC}\n"
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

    pod=$(oc get pods | awk '/share2/ {print $1}')
    if [ -n "$pod" ]; then
    for m in "${share2[@]}"; do
        printf "Share2 instance: %s ${RED}$pod${NC}:${RED}$m${NC}\n"
        oc exec -it "$pod" -- ls "$m"
        echo "----------------------"
    done
    fi

    pod=$(oc get pods | awk '/share3/ {print $1}')
    if [ -n "$pod" ]; then
    for m in "${share3[@]}"; do
        printf "Share3 instance: %s ${RED}$pod${NC}:${RED}$m${NC}\n"
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
    SHARES+=(["share_netapp"]="nfs")
    fi
    sleep 10
}

# Intro - Show preview
test_manila
# Stage 1 - Show manila resources
test_mshare
# Stage 2 - Mount shares on a client
test_all_shares
