# A simple task-core Ceph POC

The relevant files are:

* task-core-inventory-ceph_nodes.yaml: the inventory containing the ceph nodes;
  cephadm is invoked to bootstrap the first minimal ceph cluster
* ceph.yaml: this represents the task-core role/ that applies all the services
  against the node(s) present in the inventory file
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

For this POC the [ssh_user](https://github.com/fultonj/task-core/commit/d8151ba3c118b961f053cca3e0bd1db4a8201492) is
imported and used.

Copy the files described in the previous section on the task-core workdir, then run:

    task-core -s . -i ~/task-core-inventory-ceph_nodes.yaml -r ../basic/ceph.yaml -d
