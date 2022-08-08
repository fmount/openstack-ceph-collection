#!/usr/bin/env bash

# set -x

PODMAN=$(which podman)
LVIRT_IMAGES=/var/lib/libvirt/images
LVIRT_RUN=/var/run/libvirt
KCLI="karmab/kcli"
DEPLOYER="$PODMAN run --net host -it --rm --security-opt label=disable -v $HOME/.kcli:/root/.kcli -v $HOME/.ssh:/root/.ssh -v $LVIRT_IMAGES:/var/lib/libvirt/images -v $LVIRT_RUN:/var/run/libvirt -v $PWD:/workdir -v /var/tmp:/ignitiondir $KCLI"
DEFAULT_PLAN_PATH=plan/ceph_cluster.yml
DEFAULT_SSH_KEY="$HOME"/.ssh/kcli.pub
INVENTORY="$PWD"/inventory.yaml
VARS="$PWD"/vars/cephadm-extra-vars.yaml
CRUSH_HIERARCHY="$PWD"/vars/cephadm-crush-hierarchy.yaml
SLEEP=30
build=0
s_logs=1

deploy_nodes() {
    local plan="$1"
    echo "[DEPLOY] Deploy the Ceph Plan"
    $DEPLOYER create plan -f "$DEFAULT_PLAN_PATH" "$plan"
}

delete_plan() {
    PLAN="$1"
    if [ -z "$PLAN" ]; then
        usage
    fi
    $DEPLOYER delete plan -y "$PLAN"
    echo "[LOGS] Remove logs"
    if [ "$s_logs" -eq 1 ]; then
        rm -f "$PWD"/*.log
    fi
    echo "[INVENTORY] Delete inventory.yaml"
    rm -f "$INVENTORY"
    echo "[ANSIBLE VARS] Delete cephadm-extra-vars.yaml"
    rm -f "$VARS"
}

j2_patch() {
    local NODE="$1"
    local VALUE="$2"
    local FILE="$3"
    J2_REGEX="{{ $NODE }}"
    sed -i "s|$J2_REGEX|$VALUE|" "$FILE"
}

ping_nodes() {
    ansible -i "$INVENTORY" -m ping all
}

distribute_keys() {
    local ip="$1"
    ssh-copy-id -o StrictHostKeyChecking=no -i "$DEFAULT_SSH_KEY" root@"$ip"
}

run_cephadm() {
    echo "[CEPHADM] Create cephadm user and distribute keys on the nodes"
    ansible-playbook -i "$INVENTORY" distribute-keys.yaml -e @vars/ceph-admin.yaml 2>&1 | tee distribute_keys.log
    echo "[CEPHADM] Running cephadm playbook"

    ansible-playbook -i "$INVENTORY" cli-cephadm.yaml -e @"$VARS" -e @"$CRUSH_HIERARCHY" 2>&1 | tee cephadm_command.log
    # ansible-playbook -i "$INVENTORY" cli-cephadm.yaml -e @"$VARS" 2>&1 | tee cephadm_command.log

}

main() {
    if [ "$build" -eq 0 ]; then
        echo "No build options are passed"
        exit 0
    fi
    # Remove any previously deployed environment
    # delete_plan "$plan"

    # Deploy a new env
    deploy_nodes "$plan"
    #declare -A node

    # wait until the Ceph nodes are ready
    sleep "$SLEEP"

    # collect ip addresses and build the ansible inventory
    echo "[INVENTORY] Create inventory"
    cp "$PWD"/inventory.sample "$PWD"/inventory.yaml
    echo "[ANSIBLE] Build and patch vars"
    cp "$PWD"/vars/cephadm-extra-vars.sample "$PWD"/vars/cephadm-extra-vars.yaml

    i=0
    for ip in $($DEPLOYER list vm | grep ceph-node | awk '{print $6}'); do
        #node["ceph_0$i"]="$ip"
        echo "[INVENTORY] Patch Ip(s) for ceph_node_0$i"
        j2_patch "ceph_node_0$i" "$ip" "$INVENTORY"
        j2_patch "ceph_node_0$i" "$ip" "$VARS"
        echo "[NODE: ceph_node_0$i] Distribute key"
        distribute_keys "$ip"
        ((i++))
    done
    if ping_nodes; then
        run_cephadm
    fi
}

usage() {
  # Display Help
  echo "This script is the helper to build a Ceph(adm) env. "
  echo
  echo "Syntax: $0 [-a][-c][-k][-u <use_case>][-f <use_case>]" 1>&2;
  echo "Options:"
  echo "d     Deploy a new environment."
  echo "c     Cleanup the environment."
  echo "k     Distribute keys."
  echo
  echo "Examples"
  echo
  echo "./build_env.sh -d \$plan # build a new environment"
  echo "./build_env.sh -c \$plan # Cleanup the environment"
  exit 1
}


# processing options

while getopts ":c:d:h:k" o; do
    case "${o}" in
      c)
        plan=${OPTARG}
        delete_plan "$plan"
        exit 0
        ;;
      d)
        plan=${OPTARG}
        build=1
        ;;
      h)
        usage
        ;;
      k)
        for ip in $($DEPLOYER list vm | grep node | awk '{print $6}'); do
            distribute_keys "$ip"
        done
        ;;
      *)
        usage
        ;;
    esac
done

shift $((OPTIND-1))

main "$build" "$plan"
