# POC - ***REMOVED***-operator and Extra Volumes propagation

Assumptions:

0. local CRC up & running,
   - local-storage
   - basic operators running
   - glance, cinder and meta-operator CRD updated w/ "extraMounts"
   - glance, cinder, meta-operators --replicas=0

1. Two ceph clusters are available and can serve different services;

2. The ceph secrets are created by the human operator in advance;

3. Ceph Cluster 1 is connected to both Cinder and Glance;

4. Ceph Cluster 2 is only connected to CinderVolume (backend2);

5. For the POC purpose, both glance, cinder and the meta-operator
   are run locally

## Propagation

~~~
  extraMounts:
      extraVol: ---> /etc/ceph
      - propagation:
        - Glance
        - volume1
        - Compute
        - CinderBackup
        ...
        ...
      - propagation: ---> /etc/ceph2
        - Compute
        - volume2
        - Glance
        ...
        ...
~~~

## Summary:

- All "Glances" have both /etc/ceph and /etc/ceph2
- CinderBackup and cinder-volume1 mount /etc/ceph
- cinder-volume2 receives /etc/ceph2
- Compute (the ansibleEE pod) receives all the mounts

