# OPENSTACKCLIENT

The openstackclient is used to interact with an existing controlplane, and it
can be used in kuttl tests to execute scripts that are supposed to verify that
a given functionality works as expected.

## Deploy the openstackclient via kustomize

It is possible to inject script via kustomize, and we have two choices:
- inject a particular script to test a feature or verify there's no regressions
- inject the script directory that contains the whole set of scripts

In case you want to inject a particular script, add the following in the
kustomization.yaml file:

```
- op: add
  path: /spec/volumes/0
  value:
   configMap:
     name: openstack-scripts
     defaultMode: 755
   name: openstack-scripts
- op: add
  path: /spec/containers/0/volumeMounts/0
  value:
    mountPath: /home/cloud-admin/import-image-container.sh
    name: distributed-image-import
    subPath: import-image-container.sh
```

The snippet above adds the `import-image-container` script to the `cloud-admin`
home directory, and it will be available under the defined subPath.
If the purpose is to test multiple features, it is possible to inject the entire
`scripts` directory and select the script that should be executed from an external
test suite.

```
- op: add
  path: /spec/containers/0/volumeMounts/0
  value:
   mountPath: /home/cloud-admin/scripts
   name: openstack-scripts
- op: add
  path: /spec/volumes/0
  value:
    configMap:
      defaultMode: 0755
      name: openstack-scripts
    name: openstack-scripts
```

Without a `subPath`, we can mount all the scripts provided by the `ConfigMap`
within a `scripts` directory.
This represents the default approach for kuttl tests.

## Define a new kuttl test

To define a new kuttl `TestStep` where a script is executed through the `Command`
kuttl object, it is possible to use the `openstackclient` to perform a feature
verification against a particular component.
The steps to define a new kuttl test are:
1. Create the bash script that contains all the steps required to test a given
   functionality; kuttl makes no assumption about the content of the script, so
   it should take care about the logic of terminating with the right exit code
   to determine `PASS` or `FAIL` on a kuttl test
2. Add the script created at step 1 into the `hack/scripts` directory of the
   service operator
3. Create, within the target `namespace`, the `openstack-scripts` `ConfigMap`
   that is mounted to the `openstackclient` via kustomize as described in the
   previous section
   The `ConfigMap` can be created with the following command:
   ```bash
   oc -n <namespace> create cm openstack-scripts --from-file=<service_operator>/hack/scripts
   ```
4. Add to the newly defined kuttl test the following line to a `00-deploy.yaml`
   step (Note that `00-deploy.yaml` might not be the same for all the repositories):
   ```bash
   oc -n <namespace> kustomize  openstackclient | oc -n <namespace> apply -f -
   ```
5. Add, to the last step (which is generally prefixed with `cleanup`), the following:
   ```bash
   oc -n <namespace> kustomize  openstackclient | oc -n <namespace> delete -f -
   ```
   The above ensures the resource is terminated when the environment is cleaned up
   and the test returned its status to the end user.
