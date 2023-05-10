curl --silent --remote-name --location https://github.com/ceph/ceph/raw/quincy/src/cephadm/cephadm
chmod +x cephadm
./cephadm add-repo --release quincy
./cephadm install ceph-common
yum -y install python3 chrony lvm2 podman vim jq tmux
