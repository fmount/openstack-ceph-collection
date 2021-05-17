# Deploy a TripleO free LAB

The purpose of this section is to create a POC where cephadm and its related tripleo-ansible
playbooks can be run without the complexity of the whole TripleO context.

This means:

1. we have no heat creating the stack vars: within the **vars** directory, a yaml file which
   contains all the TripleO rendered variables is present. This file contains some placeholders
   in a j2 oriented way: the deployer is able to inject the retrieved IP addresses, customize
   the variables needed by the cephadm execution and run the ceph bootstrap command.

2. we have a pre-built inventory containing all the Ceph related (and relevant) groups; the
   deployer, as per step $1, is able to inject (using the same approach), the gathered IP addr,
   verify that all the nodes are reacheable, and finally run the cephadm playbook.


## KCLI and nodes deployment

KCLI is the tool used to deploy a given number of Ceph Nodes. This can be done using the Ceph
plan file (located in the nodes/ directory) that can be customized adding or removing options,
defining new parameters to reflect the status of your environment or making it able to execute
a specific script at bootstrap time.
This section is already automated in the build_env.sh script, but can also be executed before
the whole script execution:

    kcli create plan /path/to/your/plan/file ceph

At the end of this process, using the kcli cli we should be able to see the running nodes:

    kcli list vms

## Build Ceph env

The previous section is optional: here we're providing a script with the purpose of automating
the following steps:


1. Delete an environment
2. Build a new Ceph environment:
    a. Build nodes via kcli and its associated plan file
    b. Distribute the access key across the inventory nodes
    c. Build the inventory starting from the sample file
    d. Build the ansible related vars
3. Create the cephadm user and distribute the keys
4. Run the cephadm playbook


All these steps can be done runnning the following:

    ./build_env -d $plan_name

You can also delete an existing env running:

    ./build_env -d $plan_name

This command will also delete the generated inventory, the ansible vars associated to the last
executions and the related logs.

