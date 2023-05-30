#!/bin/bash

WORKDIR=$HOME/composable_roles/network
TEMPLATES=$HOME/templates
if [[ ! -e $WORKDIR/baremetal_deployment.yaml ]]; then
    echo "baremetal_deployment.yaml is missing"
    exit 1
fi

openstack overcloud delete overcloud --yes

openstack overcloud node unprovision --all -y --stack overcloud $WORKDIR/baremetal_deployment.yaml

if [[ ! -e ~/composable_roles/network/baremetal_deployment.yaml ]]; then
    echo "baremetal_deployment.yaml is missing"
    exit 1
fi

openstack overcloud node provision --network-config --stack overcloud --output $TEMPLATES/overcloud-baremetal-deployed.yaml $WORKDIR/baremetal_deployment.yaml

ls -l $TEMPLATES/overcloud-baremetal-deployed.yaml

echo "Run the following script now"
echo "overcloud_deploy_ceph.sh and overcloud_deploy.sh"
