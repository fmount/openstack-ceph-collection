#!/bin/bash

$WORKDIR=$HOME/composable_roles/network
if [[ ! -e $WORKDIR/baremetal_deployment.yaml ]]; then
    echo "baremetal_deployment.yaml is missing"
    exit 1
fi

openstack overcloud delete overcloud --yes

openstack overcloud node unprovision --all -y --stack overcloud $WORKDIR/baremetal_deployment.yaml

