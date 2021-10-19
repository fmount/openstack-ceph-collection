# Deploy a Standalone Ceph cluster

The purpose of this script is to handle a cephadm based deployment of a standalone Ceph cluster.

A few options are exposed to make sure it can be customized according to the use case you're trying
to cover.

For this reason the features provided by this script are mostly related to:

1. **IP address customization**: based on that info, the mon daemons can be deployed on a given network
2. **OSD(s) device path**: The device path where the osd(s) should be deployed can be passed. If no paths are specified,
[all the available devices are used](https://docs.ceph.com/en/latest/cephadm/osd/#creating-new-osds)
3. **Pools**: pools can be passed as parameter using the -p option: either -p \<pool\> and -p \<pool\>:\<application\> works
4. **Daemons**: more services/daemons can be added when the cluster is up and running

## Usage and examples

Deploy a standalone Ceph cluster.

Syntax: ./deploy_ceph.sh [-i <ip>][-p <pool><application>][-s <service>][-d </dev/device/path>]" 1>&2;

~~~
Options:
d     Device path that is used to build OSD(s).
i     IP address where the mon(s)/mgr(s) daemons are deployed.
p     Pool that is created (this option can be passed in the form pool:application multiple times)
k     Key that is created (this option can be passed multiple times)
s     Services/Daemons that are added to the cluster.
t     Tear down the previously deployed Ceph cluster.
~~~

Examples

1. Deploy a minimal Ceph cluster using the specified IP"
> ./deploy_ceph.sh -i \<IP\>

2. Build the OSD(s) according to the specified paths
> ./deploy_ceph.sh -i \<IP\> -d /dev/ceph_vg/ceph_lv_data -d /dev/ceph_vg/ceph_lv_data1

3. Deploy the Ceph cluster and add the specified pools
> ./deploy_ceph.sh -i \<IP\> -p volumes -p images:rbd

4. Deploy the Ceph cluster and add the specified keys
> ./deploy_ceph.sh -i \<IP\> -k client.***REMOVED*** -k client.manila -k client.glance

5. Deploy the Ceph cluster and add the specified services
> ./deploy_ceph.sh -i \<IP\> -s rgw -s mds -s nfs

6. Deploy the Ceph cluster using the given image:tag
> ./deploy_ceph.sh -i \<IP\> -c image:tag"

7. Tear Down the Ceph cluster
> ./deploy_ceph.sh -t

**A real use case Example**:

> ./deploy_ceph.sh -c quay.io/ceph/ceph:v16.2.6 -i 192.168.121.205 -p volumes:rbd -p images -k client.***REMOVED*** -k client.glance -k client.manila -s rgw -s nfs -s mds -d /dev/vdb
