# /usr/bin/zsh

WORKDIR=$HOME/devnull/osp-k8s-operators/dev_operator
SRC=$HOME/devnull/osp-k8s-operators/dev_operator/lib-common
GOROOT_DIR=/usr/lib/go/src/

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
    local OPERATOR_NAME=$1
    if [ -z "$OPERATOR_NAME" ]; then
        echo "crd $ACTION <operator_name>"
    else
        # stat operator_name path first ?
        for i in $WORKDIR/$OPERATOR_NAME/config/crd/bases/*; {
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
