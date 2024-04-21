TIME=5
glance="glance --os-auth-url http://keystone-public.openstack.svc:5000/v3 --os-project-name admin --os-username admin --os-password 12345678 --os-user-domain-name default --os-project-domain-name default"
exec 0<&-

# Build a dodgy image
echo This is a dodgy image > $HOME/myimage

# Stage 0 - Delete any pre-existing image
openstack image list -c ID -f value | xargs -n 1 openstack image delete

# Stage 1 - Create an empty box
echo "$glance image-create --name testimage --disk-format qcow2 --container-format"
$glance --debug image-create  --name testimage --disk-format qcow2 --container-format bare

ID=$($glance image-list | awk /testimage/'{print $2}')
echo "Image ID: $ID"

STATE=$($glance image-show "$ID" | awk '/status/{print $4}')
echo "Image Status => $STATE"
sleep "$TIME"

# Stage 2 - Stage the image
echo "Stage image"
echo "$glance image-stage --progress --file myimage $ID"
$glance --os-image-url "http://glance-default-single-0.glance-default-single.openstack.svc:9292" image-stage --progress --file "$HOME"/myimage "$ID"

# Stage 3 - Import the image from a different replica
$glance --os-image-url "http://glance-default-single-1.glance-default-single.openstack.svc:9292" image-import --import-method glance-direct "$ID"

# Stage 4 - Check the image is active
$glance image-list
ACTIVE=$($glance image-show "$ID" | awk '/status/{print $4}')
if [[ $ACTIVE == "active" ]]; then
    echo "ACTIVE"
else
    echo "FAILED"
fi
