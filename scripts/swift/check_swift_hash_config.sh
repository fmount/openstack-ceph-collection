#!/bin/bash
# Check Swift hash configuration consistency across controllers.
# Verifies: on-disk config, bind-mounted config inside containers, container uptime.
# Usage: Run from the undercloud or a jump host with SSH access to controllers.

set -euo pipefail

CONTROLLERS="${1:-3}"
TRIPLEO_CONF_DIR="/var/lib/config-data/puppet-generated/swift/etc/swift/swift.conf"

echo "=========================================="
echo "Swift Hash Configuration Check"
echo "=========================================="
echo ""

# Check the config on disk
for i in $(seq 0 $((CONTROLLERS - 1))); do
    echo "=== controller-$i (disk) ==="
    ssh tripleo-admin@controller-"$i".ctlplane grep -E "swift_hash_path_(prefix|suffix)" "$TRIPLEO_CONF_DIR"
    echo ""
done

# Check what the running containers see (bind-mounted file)
for i in $(seq 0 $((CONTROLLERS - 1))); do
    echo "=== controller-$i (containers) ==="
    ssh tripleo-admin@controller-"$i".ctlplane \
        'for c in $(sudo podman ps --format "{{.Names}}" | grep swift); do
            echo "  $c:"
            sudo podman exec "$c" grep -E "swift_hash_path_(prefix|suffix)" /etc/swift/swift.conf
        done'
    echo ""
done

# Check container uptime — restarted AFTER the fix?
for i in $(seq 0 $((CONTROLLERS - 1))); do
    echo "=== controller-$i (uptime) ==="
    ssh tripleo-admin@controller-"$i".ctlplane \
        'sudo podman ps --format "table {{.Names}}\t{{.Status}}" | grep swift'
    echo ""
done
