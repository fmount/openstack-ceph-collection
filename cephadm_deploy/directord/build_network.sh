#!/bin/bash

# Additional networks can be added to the directord nodes

BR_NAME=directord-network
MAC=52:54:00:e5:01:42
echo "Creating virtual bridge $BR_NAME"

cat > /tmp/directord-network.xml <<- EOF
<network>
  <name>$BR_NAME</name>
  <bridge name='$BR_NAME' stp='off' delay='0'/>
  <mac address='$MAC'/>
</network>
EOF

sudo virsh net-define /tmp/directord-network.xml
sudo virsh net-start $BR_NAME
sudo virsh net-autostart $BR_NAME

for i in 0 1; do
    sudo virsh attach-interface directord-node0$i --model virtio --source $BR_NAME --type network --config
done
