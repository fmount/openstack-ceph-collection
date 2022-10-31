# /usr/bin/zsh

WORKDIR=$HOME/devnull/osp-k8s-operators/dev_operator
SRC=$HOME/devnull/osp-k8s-operators/dev_operator/lib-common
GOROOT_DIR=/usr/lib/go/src/

OPENSTACK=/usr/bin/***REMOVED***
SAMPLES=$WORKDIR/samples

# An old workaround to include lib-common for not pushed changes
function sync_lib_common {
  sudo cp -R $SRC $GOROOT_DIR
}

function link_operator {
    local OPERATOR_NAME=$1
    if [ -z "$OPERATOR_NAME" ]; then
        echo "link_operator <operator_name>"
    else
        ln -s $WORKDIR/$OPERATOR_NAME  $WORKDIR/***REMOVED***-operator/tmp/$OPERATOR_NAME
    fi
    pushd $WORKDIR/***REMOVED***-operator
    go mod edit -replace github.com/***REMOVED***-k8s-operators/$OPERATOR_NAME/api=./tmp/$OPERATOR_NAME/api
    popd
}

function crd_del {
    for i in $WORKDIR/$OPERATOR_NAME/config/crd/bases/*; {
       oc create -f $i;
    }
}

function crd {
    ACTION="$1"
    local OPERATOR_NAME=$2
    if [ -z "$OPERATOR_NAME" ]; then
        echo "crd $ACTION <operator_name>"
    else
        # stat operator_name path first ?
        for i in $WORKDIR/$OPERATOR_NAME-operator/config/crd/bases/*; {
            oc $ACTION -f $i;
        }
    fi
}

function delete_crd {
    OPERATOR_NAME="$1"
    ACTION="delete"
    # call the crd function with the delete parameters
    crd "delete" $1
}

function create_crd {
    OPERATOR_NAME="$1"
    ACTION="create"
    # call the crd function with the create parameters
    crd "create" $1
}

function clean_pv {
    NODE_NAME=$(oc get node -o name -l node-role.kubernetes.io/worker | head -n 1)

    for i in $(oc get pv | grep -E "(Failed|Released)" | awk {'print $1'}); do
        oc patch pv $i --type='json' -p='[{"op": "remove", "path": "/spec/claimRef"}]';
    done

    # now, it's time to run a real clanup of the crc directory

    if [ -z "$NODE_NAME" ]; then
      echo "Unable to determine node name with 'oc' command."
      exit 1
    fi
    oc debug $NODE_NAME -T -- chroot /host /usr/bin/bash -c "for i in {1..6}; do echo \"deleting dir content /mnt/***REMOVED***/pv00\$i\"; rm -rf /mnt/***REMOVED***/pv00\$i/*; done"

}

function endpoint_create {
    region="regionOne"
    local service=$1
    if [ -z "$service" ]; then
        echo "build_ep <service_name>"
        return
    fi
    if [[ $service == "cinder" ]]; then
        path="v3/%(project_id)s"
        svc="cinderv3"
    fi
    for ep in admin internal public; do
        $OPENSTACK endpoint create --region $region $svc $ep "http://$service-$ep-***REMOVED***.apps-crc.testing/$path";
    done
}

function scale_operators {
    for op in ***REMOVED*** cinder glance placement; do
        oc scale deployment $op-operator-controller-manager --replicas=0
    done
}

# TEST OPERATORS

function test_cinder {
    local type=$1
    if [ -z "$type" ]; then
        echo "test_cinder <cinder_type>"
        echo "  |-> e.g., test_cinder ceph"
        return
    fi
    cinder type-create $type
    cinder type-list
    cinder type-key $type set volume_backend_name=$type
    sleep 2
    cinder create 1 --volume-type $type --name "$type"_disk
}

function test_glance {
    IMAGE=$SAMPLES/cirros-0.5.2-x86_64-disk.img
    ***REMOVED*** image create --disk-format qcow2 --container-format bare --file $IMAGE cirros-test
    sleep 5
    ***REMOVED*** image list
}

# screencast rec0
function test_propagation {
    local mountpoint="$1"
    if [ -z "$mountpoint" ]; then
        echo "test_propagation <mountpoint>"
        echo "  |-> e.g., test_propagation /etc/ceph"
        return
    fi
    # ExtraVolumes summary
    extra_volumes_preview
    # Glance pods
    pod=$(oc get pods | awk '/glance-[[:digit:]]+/ {print $1}')
    oc exec -it $pod -- ls $mountpoint
    # Cinder pods
    pod=$(oc get pods | awk '/cinder-[[:digit:]]+/ {print $1}')
    oc exec -it $pod -- ls $mountpoint
    # Compute pods
    pod=$(oc get pods | awk '/ansible/ {print $1}')
    oc exec -it $pod -- ls $mountpoint

}
