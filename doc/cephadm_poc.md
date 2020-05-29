Cephadm poc using TripleO-LAB
===

This POC is supposed to work with [TripleO-lab](https://github.com/cjeanner/tripleo-lab)
based deployments and shows how a Ceph octopus cluster can be deployed
using the new cephadm provided tool.

For the OSP Victoria cycle a new spec has been created to support this POC:
- [Victoria Spec](https://review.opendev.org/#/c/723108)
- [Cephadm Doc](https://docs.ceph.com/docs/master/cephadm)

Here the steps needed to build a POC based on cephadm/orchestrator.

1. Deploy the undercloud

>    $ ansible-playbook --become -i inventory.yaml builder.yaml -e @environments/overrides_victoria.yml

>    $ ansible-playbook builder.yaml -t domains -t baremetal -t vbmc

2. Provision nodes using metalsmith

```console
    export STACK=oc0
    ***REMOVED*** overcloud node provision \
      --stack $STACK \
      --output ~/overcloud-baremetal-deployed-0.yaml \
      ~/metalsmith-0.yaml
```
and double check the provisioned nodes running:

>   metalsmith -c "Node Name" -c "IP Addresses" list

Additional info can be found [here](https://github.com/fultonj/victoria/tree/master/metalsmith)

3. Overcloud deploy --stack-only

```console
    export DEPLOY_TEMPLATES=/usr/share/***REMOVED***-tripleo-heat-templates/
    export DEPLOY_STACK=oc0
    export DEPLOY_TIMEOUT_ARG=90
    export DEPLOY_LIBVIRT_TYPE=qemu
    export DEPLOY_NETWORKS_FILE=/home/stack/oc0-network-data.yaml
    source /home/stack/stackrc;
    ***REMOVED*** overcloud deploy --templates $DEPLOY_TEMPLATES --stack $DEPLOY_STACK --timeout $DEPLOY_TIMEOUT_ARG \
    --libvirt-type $DEPLOY_LIBVIRT_TYPE -e /usr/share/***REMOVED***-tripleo-heat-templates/environments/deployed-server-environment.yaml \
    -e /home/stack/overcloud-baremetal-deployed-0.yaml \
    -e /usr/share/***REMOVED***-tripleo-heat-templates/environments/net-multiple-nics.yaml \
    -e /usr/share/***REMOVED***-tripleo-heat-templates/environments/network-isolation.yaml \
    -e /usr/share/***REMOVED***-tripleo-heat-templates/environments/network-environment.yaml \
    -e /usr/share/***REMOVED***-tripleo-heat-templates/environments/disable-telemetry.yaml \
    -e /usr/share/***REMOVED***-tripleo-heat-templates/environments/low-memory-usage.yaml \
    -e /usr/share/***REMOVED***-tripleo-heat-templates/environments/enable-swap.yaml \
    -e /usr/share/***REMOVED***-tripleo-heat-templates/environments/ceph-ansible/ceph-ansible.yaml \
    -e /usr/share/***REMOVED***-tripleo-heat-templates/environments/podman.yaml \
    -e /home/stack/containers-prepare-parameter.yaml \
    -e /home/stack/generated-container-prepare.yaml \
    --environment-directory /home/stack/overcloud-0-yml \
    -n $DEPLOY_NETWORKS_FILE --disable-validations --stack-only
```

4. Generate config download

```console
     export STACK=oc0
     export DIR=/home/stack/oc0/config-download
     ***REMOVED*** overcloud config download \
              --name $STACK \
              --config-dir $DIR
```

5. Generate the static inventory

```console
    export STACK=oc0
    tripleo-ansible-inventory --static-yaml-inventory \
            tripleo-ansible-inventory.yaml \
            --stack $STACK
```

6. Double check the overcloud nodes are ready

```console
    ansible -m ping inventory.yaml all
```

7. Run the first overcloud deployment stage: this configure the Storage/StorageMgmt network

```console
    ansible-playbook -i tripleo-ansible-inventory.yaml deploy_steps_playbook.yaml \
        --skip-tags step2,step3,step4,step5,opendev-validation
```

8. Double check the storage network is properly configured and nodes are reacheable

```console
    ansible -m shell -b -a "ip -o -4 a | grep -E 'vlan1(1|2)'" -i tripleo-ansible-inventory.yaml mons,osds
```

9. Clone [this repo](https://github.com/fmount/tripleo-cephadm-victoria) into
`config-download/cephadm` and run the playbooks in the following order:
 - undercloud_prepare: this will link the ceph compatible inventory

>        $ ansible-playbook undercloud_prepare.yaml
 - bootstrap playbook: this will boot a minimal ceph cluster (using the first mon)

>        $ ansible-playbook -i tripleo-ansible-inventory.yaml cephadm_site_container.yaml

The purpose of `cephadm_site_container` playbook is to orchestrate the cephadm commands
to produce a minimal running cluster, generate the spec/host yaml that describe the Ceph
cluster and add all the remaining nodes on it. This playbook is built using the
tripleo-operator approach, so for each action there is a role associated with a few
configurable parameters.


At this point we have the minimal ceph cluster up && running and we should be able to add
resources on it.
Right now the [cephadm --spec [file] command](https://github.com/ceph/ceph/pull/34879) is
not available, so we need a few, more, playbooks to create additional resources, built the
spec and push it via `ceph orch` cli.


## NOTE

- [cephadm spec apply PR](https://github.com/ceph/ceph/pull/34879)
- [adopt ceph-ansible cluster](https://github.com/ceph/ceph-ansible/pull/5269/files)


## TODO

1. Design a playbook to reflect/generate the cephadm spec according to the [PR](https://github.com/ceph/ceph-ansible/pull/34879)
2. Playbook to scale{up,down} monitors
3. Playbook to scale{up,down} OSDs
