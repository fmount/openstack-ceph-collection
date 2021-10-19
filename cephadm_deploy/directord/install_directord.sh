#!/bin/env bash

pushd ~ || exit
sudo dnf -y install git gcc python3-pip python3-devel
git clone https://github.com/directord/directord
pip3 install --user tox
pushd directord || exit
export PATH=$PATH:/root/.local/bin
tox -e venv python3 setup.py install_data
popd || exit

# Execute directord

./directord/.tox/venv/bin/directord bootstrap --catalog directord-inventory-catalog.yml \
    --catalog directord/tools/directord-dev-bootstrap-catalog.yaml

sudo chgrp "$USER" /var/run/directord.sock && sudo chmod g+w /var/run/directord.sock
