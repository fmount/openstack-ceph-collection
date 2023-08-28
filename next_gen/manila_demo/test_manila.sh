#!/usr/bin/env bash

RED='\033[0;31m'
NC='\033[0m'
TIME=5
PREVIEW_TIME=20
NAPP=1
declare -A SHARES
#SHARES=(["share_nfs"]="nfs" ["share_cephfs"]="cephfs")
SHARES=(["share_nfs"]="nfs")
SIZE=1


declare -A CLIENTS
CLIENTS=(["192.168.130.27"]="10.10.10.50" ["192.168.130.28"]="10.10.10.60")

function test_mshare {
    echo
    echo "=> MANILA SHARE SERVICES"
    oc rsh openstackclient openstack share service list
    echo
    echo "=> MANILA POOL LIST"
    oc rsh openstackclient openstack share pool list
    sleep $TIME
    echo "=> CREATE SHARE TYPES"
    echo oc rsh openstackclient openstack share type create default False\
                  --extra-specs snapshot_support=True  \
                  create_share_from_snapshot_support=True vendor_name=Ceph
    if [ $NAPP -gt 0 ]; then
        echo oc rsh openstackclient openstack share type create bigboxtype False \
                  --extra-specs snapshot_support=True  \
                  revert_to_snapshot_support=True \
                  create_share_from_snapshot_support=True
    fi
    echo
    echo "=> MANILA SHARE TYPE LIST"
    oc rsh openstackclient openstack share type list
    echo 
    echo "=> CREATE SHARE"
    for p in "${!SHARES[@]}"; do
        echo "oc rsh openstackclient openstack share create --name $p "${SHARES["$p"]}" $SIZE"
    done
    echo

    echo "=> LIST THE RESULTING SHARES"
    oc rsh openstackclient openstack share list
    sleep $TIME
    echo 

    echo "=> SHOW SHARES LOCATION"
    echo
    for p in "${!SHARES[@]}"; do
	echo "$p"
	echo "-----"
	oc rsh openstackclient openstack share export location list $p -c Path -f value
	echo "-----"
	echo
    done

    exit 1
    # test_netapp_client
    # test_nfs_client
    # test_cephfs_client

}

function test_all_shares {
    local client1="192.168.130.27"
    local share_nfs="192.168.130.21:/volumes/_nogroup/61139d4d-4f6b-4c6b-8966-a51c72ad8393/1d2562d5-1c5e-4fcf-92c0-e437032d74fc"
    local share_netapp="192.168.1.107:/share_4d8201d4_f667_4f7c_b004_8dd07f7d7a2e"
    # local share_cephfs=""
    local share_cephfs="192.168.130.26:6789:/volumes/_nogroup/733bb2e6-a704-4632-b347-4401582a6331/a7bbf8fa-ef8f-4242-a5b2-3905e5606054"

    echo "=> CREATE ACCESS RULE"
    oc rsh openstackclient openstack share access create share_nfs ip $client1
    oc rsh openstackclient openstack share access create share_netapp ip $client1
    #oc rsh openstackclient openstack share access create share_cephfs ip $client1
    echo
    sleep 3

    echo "=> LIST ACCESS RULES"
    for p in "${!SHARES[@]}"; do
       oc rsh openstackclient openstack share access list $p
    done
    sleep $TIME
    echo

    sudo -u root ssh root@10.10.10.50 mkdir -p /mnt/share_{nfs,netapp,cephfs}
    sudo -u root ssh root@10.10.10.50 mount -t nfs 192.168.130.21:/volumes/_nogroup/61139d4d-4f6b-4c6b-8966-a51c72ad8393/1d2562d5-1c5e-4fcf-92c0-e437032d74fc /mnt/share_nfs
    sudo -u root ssh root@10.10.10.50 mount -t nfs 192.168.1.107:/share_4d8201d4_f667_4f7c_b004_8dd07f7d7a2e /mnt/share_netapp
    #sudo -u root ssh royt@10.10.10.50 mount -t cephfs ##
    sudo -u root ssh root@10.10.10.50 mount -t cephfs 192.168.130.26:6789:/volumes/_nogroup/733bb2e6-a704-4632-b347-4401582a6331/a7bbf8fa-ef8f-4242-a5b2-3905e5606054 /mnt/share_cephfs

    for p in "${!SHARES[@]}"; do
        sudo -u root ssh root@10.10.10.50 touch /mnt/$p/test_file1
        sudo -u root ssh root@10.10.10.50 touch /mnt/$p/test_file2
        sudo -u root ssh root@10.10.10.50 touch /mnt/$p/test_file3
	sleep 5
        sudo -u root ssh root@10.10.10.50 tree /mnt
	sleep 10
        sudo -u root ssh root@10.10.10.50 umount /mnt/$p
    done

}

function test_nfs_client {
    local export_name="share_nfs"
    local client1="192.168.130.27"
    local client2="192.168.130.28"
    local export_loc="192.168.130.21:/volumes/_nogroup/61139d4d-4f6b-4c6b-8966-a51c72ad8393/1d2562d5-1c5e-4fcf-92c0-e437032d74fc"

    echo "=> CREATE ACCESS RULE"
    oc rsh openstackclient openstack share access create $export_name ip $client1
    echo
    sleep 3

    echo "=> LIST ACCESS RULES"
    oc rsh openstackclient openstack share access list $export_name
    sleep $TIME
    echo

    echo "=> MOUNT SHARE TO CLIENT NODE [192.168.130.27]"
    echo
    echo "[10.10.10.50] mount $export_loc"
    sudo -u root ssh root@10.10.10.50 mount -t nfs 192.168.130.21:/volumes/_nogroup/61139d4d-4f6b-4c6b-8966-a51c72ad8393/1d2562d5-1c5e-4fcf-92c0-e437032d74fc /mnt
    #sudo -u root ssh root@10.10.10.50 "mount -t nfs $nfs_export /mnt"

    echo "ssh root@10.10.10.16 touch /mnt/test1 /mnt/test2 /mnt/test3"
    sudo -u root ssh root@10.10.10.50 touch /mnt/test1 /mnt/test2 /mnt/test3
    sleep 5
    echo "ssh root@10.10.10.50 echo $(date) > /mnt/test1"
    #sudo -u root ssh root@10.10.10.50 echo $(date) >> /mnt/test1
    sleep 5
    echo "ssh root@10.10.10.50 ls -l /mnt"
    sudo -u root ssh root@10.10.10.50 ls -l /mnt/
    sleep 5
    echo "ssh root@10.10.10.50 umount /mnt"
    sudo -u root ssh root@10.10.10.50 umount /mnt

    echo "=> [FAIL] - MOUNT SHARE TO THE SECOND CLIENT NODE [192.168.130.28]"
    echo
    echo "[10.10.10.60] mount $export_loc"
    sudo -u root ssh root@10.10.10.60 mount -vvv -t nfs 192.168.130.21:/volumes/_nogroup/61139d4d-4f6b-4c6b-8966-a51c72ad8393/1d2562d5-1c5e-4fcf-92c0-e437032d74fc /mnt

    #echo "=> CREATE ACCESS RULE ON THE SECOND NODE"
    #oc rsh openstackclient openstack share access create $export_name ip $client2
    #echo "=> MOUNT SHARE TO THE SECOND CLIENT NODE [192.168.130.28]"
    #echo
    #echo "[10.10.10.60] mount $export_loc"
    #sudo -u root ssh root@10.10.10.60 mount -t nfs 192.168.130.21:/volumes/_nogroup/61139d4d-4f6b-4c6b-8966-a51c72ad8393/1d2562d5-1c5e-4fcf-92c0-e437032d74fc /mnt
    #echo "ssh root@10.10.10.60 touch /mnt/test4"
    #sudo -u root ssh root@10.10.10.60 touch /mnt/test4
    #echo "ssh root@10.10.10.60 ls -l /mnt"
    #sudo -u root ssh root@10.10.10.60 ls -l /mnt/
    #sleep 5
    #echo "ssh root@10.10.10.60 umount /mnt"
    #sudo -u root ssh root@10.10.10.60 umount /mnt
    #exit 1
}

function test_netapp_clients {

    local export_name="share_netapp"
    local client1="192.168.130.27"
    local client2="192.168.130.28"
    local export_loc="192.168.1.107:/share_4d8201d4_f667_4f7c_b004_8dd07f7d7a2e"

    echo "=> CREATE ACCESS RULE"
    oc rsh openstackclient openstack share access create $export_name ip $client1
    echo
    sleep 3

    echo "=> LIST ACCESS RULES"
    oc rsh openstackclient openstack share access list $export_name
    sleep $TIME
    echo

    echo "=> MOUNT SHARE TO CLIENT NODE [192.168.130.27]"
    
    echo
    echo "[10.10.10.50] mount $export_loc"
    sudo -u root ssh root@10.10.10.50 mount -t nfs 192.168.1.107:/share_4d8201d4_f667_4f7c_b004_8dd07f7d7a2e /mnt
    #sudo -u root ssh root@10.10.10.50 "mount -t nfs $nfs_export /mnt"

    echo "ssh root@10.10.10.50 touch /mnt/test_napp1 /mnt/test_napp2 /mnt/test_napp3"
    sudo -u root ssh root@10.10.10.50 touch /mnt/test_napp1 /mnt/test_napp2 /mnt/test_napp3
    sleep 5
    echo "ssh root@10.10.10.50 ls -l /mnt"
    sudo -u root ssh root@10.10.10.50 ls -l /mnt/
    sleep 5
    echo "ssh root@10.10.10.50 umount /mnt"
    sudo -u root ssh root@10.10.10.50 umount /mnt
}

function test_cephfs_clients {
    echo "=> CREATE ACCESS RULE"
    #share_id=$(oc rsh openstackclient openstack share list| grep -E "share_nfs" | awk '{print $2}')
    #[ ! -z "$share_id" ] && oc rsh openstackclient openstack share access create share_nfs ip 192.168.130.25
    echo oc rsh openstackclient openstack share access create share_nfs ip 192.168.130.25
    echo oc rsh openstackclient openstack share access create cephfsshare cephx alice
    echo

    echo "=> LIST ACCESS RULES"
    for share in "${!SHARES[@]}"; do
        oc rsh openstackclient openstack share access list $share
    done
    sleep $TIME
    echo

}


function test_clients {
    nfs_export="$1"
    proto=$2
    if [ "$proto" == "nfs" ]; then
        echo
        echo "=> MOUNT SHARE TO CLIENT NODE [192.168.130.25]"
        echo
        echo "[10.10.10.16] mount $nfs_export"
        ssh root@10.10.10.16 "mount -t nfs $nfs_export /mnt"
        # e.g. sudo -u root ssh root@10.10.10.16 mount -t nfs 192.168.130.21:/volumes/_nogroup/e80e2c45-3c79-4bf6-b2d7-5546e5e6bb95/6b56d473-c10a-4e40-8c1f-6665d0bb2421 /mnt

        echo "ssh root@10.10.10.16 touch /mnt/test1 /mnt/test2 /mnt/test3"
        sudo -u root ssh root@10.10.10.16 touch /mnt/test1 /mnt/test2 /mnt/test3
        sleep 5
        echo "ssh root@10.10.10.16 echo $(date) > /mnt/test1"
        sudo -u root ssh root@10.10.10.16 echo $(date) >> /mnt/test1
        sleep 5
        echo "ssh root@10.10.10.16 ls -l /mnt"
        sudo -u root ssh root@10.10.10.16 ls -l /mnt/
        sleep 5
        echo "ssh root@10.10.10.16 umount /mnt"
        sudo -u root ssh root@10.10.10.16 umount /mnt

        sleep 5
        echo
        echo "=> MOUNT SHARE TO CLIENT NODE [192.168.130.26]"
        echo
        echo "mount $nfs_export"
        sudo -u root ssh root@10.10.10.17 "mount -t nfs $nfs_export /mnt"
        #e.g., sudo -u root ssh root@10.10.10.17 mount -t nfs 192.168.130.21:/volumes/_nogroup/e80e2c45-3c79-4bf6-b2d7-5546e5e6bb95/6b56d473-c10a-4e40-8c1f-6665d0bb2421 /mnt
        echo "ssh root@10.10.10.17 echo $(date) > /mnt/test1"
        sudo -u root ssh root@10.10.10.17 "echo $(date) > /mnt/test1"
        # echo "-bash: /mnt/test1: Read-only file system"
        sleep 5
        echo
        echo "=> CREATE ACCESS RULE ON THE SECOND CLIENT"
        echo
            share_id=$(oc rsh openstackclient openstack share list | grep -vi log | grep -E "share_nfs" | awk '{print $2}')
            [ ! -z "$share_id" ] && oc rsh openstackclient openstack share access create share_nfs ip 192.168.130.26
        echo "=> LIST ACCESS RULES"
        oc rsh openstackclient openstack share access list share_nfs | grep -vi log
        echo

        echo
        echo "=> MOUNT SHARE TO CLIENT NODE [192.168.130.26]"
        echo
        echo "[10.10.10.17] mount $nfs_export"
        sudo -u root ssh root@10.10.10.17 "mount -t nfs $nfs_export /mnt"
        # e.g., sudo -u root ssh root@10.10.10.17 mount -t nfs 192.168.130.21:/volumes/_nogroup/e80e2c45-3c79-4bf6-b2d7-5546e5e6bb95/6b56d473-c10a-4e40-8c1f-6665d0bb2421 /mnt

        echo "ssh root@10.10.10.17 touch /mnt/test4"
        sudo -u root ssh root@10.10.10.17 touch /mnt/test4
        sleep 5
        echo "ssh root@10.10.10.17 ls -l /mnt"
        sudo -u root ssh root@10.10.10.17 ls -l /mnt/
        sleep 5
        echo "ssh root@10.10.10.17 umount /mnt"
        sudo -u root ssh root@10.10.10.17 umount /mnt
    else
        echo
        echo "=> MOUNT SHARE TO CLIENT NODE [192.168.130.26] using the cephx key"
        cephx=$(openstack share access list cephfsshare -c "Access Key" -f value)
        sudo -u root ssh root@10.10.10.17 "mount -t nfs $nfs_export /mnt"
        #e.g., sudo -u root ssh root@10.10.10.17 mount -t cephfs 192.168.130.20:6789:/volumes/_nogroup/c90f5359-fb61-45b3-8ad5-0dacd041e01b/60c9d920-21a4-44d6-9e0e-d96d32762ce2 /mnt
    fi
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
    sleep 3
}

# Intro - Show preview
#test_manila
# Stage 1 - Show manila resources
#test_mshare
# Stage 2 - Mount shares on a client
test_all_shares

