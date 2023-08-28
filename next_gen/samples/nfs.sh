#!/bin/bash

NFS_SUBNET="192.168.130.0/24"

sudo iptables -I INPUT -s ${NFS_SUBNET} -p tcp --dport 32765:32768 -j ACCEPT
sudo iptables -I INPUT -s ${NFS_SUBNET} -p udp --dport 32765:32768 -j ACCEPT
sudo iptables -I INPUT -s ${NFS_SUBNET} -p tcp --dport 2049 -j ACCEPT
sudo iptables -I INPUT -s ${NFS_SUBNET} -p udp --dport 2049 -j ACCEPT
sudo iptables -I INPUT -s ${NFS_SUBNET} -p tcp --dport 111 -j ACCEPT
sudo iptables -I INPUT -s ${NFS_SUBNET} -p udp --dport 111 -j ACCEPT

# Create export
NFS_EXPORT=/var/nfs
mkdir -p ${NFS_EXPORT}
#chown nfsnobody:nfsnobody ${NFS_EXPORT}
chmod 755 ${NFS_EXPORT}
cat > /etc/exports <<EOF
${NFS_EXPORT}  ${NFS_SUBNET}(rw,sync,no_root_squash)
EOF

exportfs -a
