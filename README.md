# OpenStack and Ceph roles, scripts and notes collection

The purpose of this repo is to collect scripts, notes, playbooks
for each OpenStack and Ceph cycle.

| OpenStack    | Ceph           |
|--------------|-----------------
| Antelope     | Quincy/Reef    |
| Wallaby      | Octopus/Pacific|
| Xena         | Pacific        |
| Yoga         | Pacific        |
| Zed          | Quincy         |


## DevStack with Ceph (kcli plan)

A [kcli](https://github.com/karmab/kcli) plan that provisions a VM
and bootstraps [DevStack](https://docs.openstack.org/devstack/latest/) with
[devstack-plugin-ceph](https://opendev.org/openstack/devstack-plugin-ceph) (cephadm backend).

```bash
kcli create plan -f devstack/plan/devstack.yml
```

See [devstack/plan/](devstack/plan/) for details.


## Deploy a TripleO lab

- Use [tripleo-lab overrides](tripleo-lab) to deploy an OpenStack environment

## Cephadm/Ceph Orchestrator POC (Wallaby)

A collection of playbooks to deploy a Ceph Octopus cluster using cephadm and
manage resources with Ceph orchestrator tool.

- [cephadm POC](doc/cephadm_poc.md)


## Ceph Standalone Deploy

The purpose of this script is to handle a cephadm based deployment of a standalone Ceph cluster.
A few options are exposed to make sure it can be customized according to the use case you're trying
to cover.

This is convered and described in the [standalone/](https://github.com/fmount/tripleo-xena/tree/master/standalone)
section.


## Multinode Ceph Lab (no TripleO)

The purpose of this section is to create a POC where cephadm and its related tripleo-ansible
playbooks can be run without the complexity of the whole TripleO context.

Those playbooks can be executed via the [build_env.sh](https://github.com/fmount/tripleo-xena/tree/master/cephadm_deploy)
script and a multinode Ceph cluster can be deployed in minutes, without any TripleO interaction.
