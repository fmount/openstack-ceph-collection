# OpenStack and Ceph roles, scripts and notes collection

The purpose of this repo is to collect scripts, notes, playbooks
for each OpenStack cycle

current OpenStack cycle: **Yoga**
current Ceph release: **Pacific**


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


## Directord / Task-core (hackfest and POC)

The purpose of this section is put the hands on the directord/task-core tools presented
at the TripleO Yoga PTG.
The first section/tutorial is about deploying a couple of nodes (Controller and Compute)
and run the OpenStack services on them, then, later in the document, there's an attempt
of deploying Ceph (triggering cephadm) using the new approach.

The work is described [here](https://github.com/fmount/tripleo-xena/tree/master/directord)
