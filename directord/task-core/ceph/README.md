# A simple task-core Ceph POC

The relevant files are:

* task-core-inventory-ceph_first_mon.yaml: the inventory containing the first monitor where
  cephadm is invoked to bootstrap the first minimal ceph cluster
* single_node_ceph.yaml: this represents the task-core role/ that applies all the services
  against the node present in the inventory file
* task-core-hackfest.yaml: the option(s) file where all the variables (potentially produced
  by heat are defined)
* services: where the steps/actions/jobs that implements the Ceph bootstrap process are defined


The services structure looks like:
```
    ...
    ...
    services/
    ├── cephadm.yaml
    └── ceph_packages.yaml
    ...
    ...
```


## Run the Ceph role

Copy the files described in the previous section on the task-core workdir, then run:

    task-core -s . -i ~/task-core-inventory-ceph_first_mon.yaml -r ../basic/single_node_ceph.yaml -d
