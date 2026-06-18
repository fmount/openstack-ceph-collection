#!/usr/bin/env python3
"""
Reconstruct an SLO manifest from quarantined segments.

Merges the functionality of:
  - build_manifest_simple.sh   (scan quarantine, build manifest JSON)
  - set_manifest_xattrs.py     (stamp xattrs via Swift's write_metadata)
  - reconstruct_slo_manifest.sh (orchestrate: ring lookup, place .data, verify)

Usage:
  ./reconstruct_slo_manifest.py ACCOUNT CONTAINER OBJECT
  ./reconstruct_slo_manifest.py --dry-run AUTH_service glance_abc123 image-uuid

Requires: Swift installed (runs inside swift_object_server container or a
virtualenv with swift). Uses swift-object-info and swift-get-nodes CLIs.
"""

import argparse
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import time

from swift.obj.diskfile import write_metadata

SWIFT_UID = 42445
SWIFT_GID = 42445

PORT_TO_NODE = {
    "6010": "/srv/node1",
    "6020": "/srv/node2",
    "6030": "/srv/node3",
    "6040": "/srv/node4",
}

QUARANTINE_ROOTS = [
    "/srv/node*/sdb*/quarantined/objects",
    "/srv/node*/sdc*/quarantined/objects",
    "/srv/node*/sdd*/quarantined/objects",
    "/srv/node*/sde*/quarantined/objects",
]


def run_cmd(cmd):
    """Run a shell command and return stdout, or None on failure."""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except subprocess.TimeoutExpired:
        pass
    return None


def parse_swift_object_info(output):
    """Parse swift-object-info output into a dict of key fields."""
    info = {}
    for line in output.splitlines():
        line = line.rstrip("\r")
        if line.startswith("  Account:"):
            info["account"] = line.split(":", 1)[1].strip()
        elif line.startswith("  Container:"):
            info["container"] = line.split(":", 1)[1].strip()
        elif line.startswith("  Object:"):
            info["object"] = line.split(":", 1)[1].strip()
        elif line.startswith("ETag:"):
            info["etag"] = line.split(":", 1)[1].strip().strip('"')
        elif line.startswith("Content-Length:"):
            info["content_length"] = line.split(":", 1)[1].strip()
    return info


def find_quarantined_data_files():
    """Find all .data files across quarantine directories."""
    data_files = []
    for pattern in QUARANTINE_ROOTS:
        for qdir in glob.glob(pattern):
            for root, _dirs, files in os.walk(qdir):
                for f in files:
                    if f.endswith(".data"):
                        data_files.append(os.path.join(root, f))
    return data_files


def build_manifest(segments_container, dry_run=False):
    """
    Scan quarantine for segments belonging to segments_container.
    Returns (manifest_json_string, total_bytes, segment_count).
    """
    print(f"==> Scanning quarantine for segments in '{segments_container}'...")

    data_files = find_quarantined_data_files()
    print(f"    Found {len(data_files)} quarantined .data files to check")

    seen = set()
    segments = []

    for i, data_file in enumerate(data_files, 1):
        if i % 500 == 0:
            print(f"    ... checked {i}/{len(data_files)} files, "
                  f"found {len(segments)} matching segments")

        output = run_cmd(f"swift-object-info '{data_file}'")
        if not output:
            continue

        info = parse_swift_object_info(output)
        if info.get("container") != segments_container:
            continue

        obj_name = info.get("object", "")
        if obj_name in seen:
            continue
        seen.add(obj_name)

        # Extract segment number from the last path component for sorting
        seg_num = obj_name.rsplit("/", 1)[-1] if "/" in obj_name else obj_name

        segments.append({
            "sort_key": seg_num,
            "name": f"/{segments_container}/{obj_name}",
            "hash": info.get("etag", ""),
            "bytes": int(info.get("content_length", 0)),
            "content_type": "application/swiftclient-segment",
        })

    if not segments:
        print("    ERROR: No matching segments found in quarantine")
        return None, 0, 0

    segments.sort(key=lambda s: s["sort_key"])

    manifest_entries = []
    for s in segments:
        manifest_entries.append({
            "name": s["name"],
            "bytes": s["bytes"],
            "hash": s["hash"],
            "content_type": s["content_type"],
        })

    manifest_json = json.dumps(manifest_entries, indent=2)
    total_bytes = sum(s["bytes"] for s in segments)

    print(f"    Found {len(segments)} segments, total {total_bytes} bytes")

    return manifest_json, total_bytes, len(segments)


def get_ring_location(account, container, obj):
    """
    Query swift-get-nodes for the correct on-disk location.
    Returns (partition, hash, suffix, device, port) or None.
    """
    output = run_cmd(
        f"swift-get-nodes /etc/swift/object.ring.gz "
        f"'{account}' '{container}' '{obj}'"
    )
    if not output:
        return None

    partition = None
    obj_hash = None
    device = None
    port = None

    for line in output.splitlines():
        if line.startswith("Partition"):
            partition = line.split()[1]
        elif line.startswith("Hash"):
            obj_hash = line.split()[1]
        elif "Server:Port Device" in line and "Handoff" not in line:
            if "127.0.0" in line:
                parts = line.split()
                device = parts[3]
                port_match = re.search(r':(\d+)', parts[2])
                if port_match:
                    port = port_match.group(1)

    if not all([partition, obj_hash, port, device]):
        return None

    suffix = obj_hash[-3:]
    return partition, obj_hash, suffix, device, port


def resolve_node_dir(port):
    """Map a Swift object-server port to its node directory."""
    if port in PORT_TO_NODE:
        return PORT_TO_NODE[port]
    return None


def create_manifest_data_file(target_dir, manifest_json):
    """Create the .data file with manifest content. Returns the file path."""
    os.makedirs(target_dir, exist_ok=True)

    timestamp = f"{int(time.time())}.{str(time.time_ns())[:5]}"
    data_file = os.path.join(target_dir, f"{timestamp}.data")

    with open(data_file, "w") as f:
        f.write(manifest_json)

    os.chown(data_file, SWIFT_UID, SWIFT_GID)
    os.chown(target_dir, SWIFT_UID, SWIFT_GID)

    return data_file


def set_manifest_xattrs(data_file, manifest_json, account, container, obj,
                        total_bytes):
    """Stamp Swift xattrs on the manifest .data file."""
    manifest_etag = hashlib.md5(manifest_json.encode()).hexdigest()
    manifest_size = len(manifest_json)

    timestamp = os.path.basename(data_file).replace(".data", "")

    metadata = {
        "name": f"/{account}/{container}/{obj}",
        "X-Timestamp": timestamp,
        "Content-Type": f"application/octet-stream;swift_bytes={total_bytes}",
        "Content-Length": str(manifest_size),
        "ETag": manifest_etag,
        "X-Static-Large-Object": "True",
    }

    write_metadata(data_file, metadata)
    return metadata


def main():
    parser = argparse.ArgumentParser(
        description="Reconstruct SLO manifest from quarantined segments"
    )
    parser.add_argument("account", help="Swift account (e.g. AUTH_service)")
    parser.add_argument("container", help="Container name (e.g. glance_UUID)")
    parser.add_argument("object", help="Object name (e.g. image-uuid)")
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Build manifest JSON but don't write to disk"
    )
    args = parser.parse_args()

    segments_container = f"{args.container}_segments"

    print("=" * 50)
    print("SLO Manifest Reconstruction")
    print("=" * 50)
    print(f"  Account:   {args.account}")
    print(f"  Container: {args.container}")
    print(f"  Object:    {args.object}")
    print(f"  Segments:  {segments_container}")
    print()

    # Step 1: Build manifest JSON from quarantined segments
    print("==> Step 1: Building manifest JSON from quarantined segments...")
    manifest_json, total_bytes, seg_count = build_manifest(segments_container,
                                                           args.dry_run)
    if manifest_json is None:
        sys.exit(1)

    print()
    print(f"  Manifest JSON ({seg_count} segments, {total_bytes} total bytes):")
    print(manifest_json[:500])
    if len(manifest_json) > 500:
        print("  ...")
    print()

    if args.dry_run:
        print("[DRY RUN] Would write manifest to disk. Stopping here.")
        manifest_path = f"/tmp/manifest_{args.object.replace('/', '_')}.json"
        with open(manifest_path, "w") as f:
            f.write(manifest_json)
        print(f"  Manifest JSON saved to: {manifest_path}")
        return

    # Step 2: Find manifest location from ring
    print("==> Step 2: Finding manifest location from ring...")
    ring_info = get_ring_location(args.account, args.container, args.object)
    if ring_info is None:
        print("ERROR: Could not get ring info for manifest")
        sys.exit(1)

    partition, obj_hash, suffix, device, port = ring_info
    print(f"  Hash:      {obj_hash}")
    print(f"  Partition: {partition}")
    print(f"  Suffix:    {suffix}")
    print(f"  Device:    {device}")
    print(f"  Port:      {port}")
    print()

    # Step 3: Determine node directory
    print("==> Step 3: Determining node directory...")
    node_dir = resolve_node_dir(port)
    if node_dir is None:
        print(f"ERROR: Could not determine node directory for port {port}")
        sys.exit(1)

    target_dir = os.path.join(
        node_dir, device, "objects", partition, suffix, obj_hash
    )
    print(f"  Target: {target_dir}")
    print()

    # Step 4: Create manifest .data file
    print("==> Step 4: Creating manifest .data file...")
    data_file = create_manifest_data_file(target_dir, manifest_json)
    print(f"  Created: {data_file}")
    print()

    # Step 5: Set xattrs
    print("==> Step 5: Setting Swift xattrs...")
    metadata = set_manifest_xattrs(
        data_file, manifest_json,
        args.account, args.container, args.object, total_bytes
    )
    for k, v in metadata.items():
        print(f"  {k}: {v}")
    print()

    # Step 6: Verify
    print("==> Step 6: Verifying manifest...")
    verify_output = run_cmd(f"swift-object-info '{data_file}'")
    if verify_output:
        print(verify_output)
    else:
        print("WARNING: Could not verify with swift-object-info")
    print()

    print("=" * 50)
    print("Manifest reconstruction complete!")
    print("=" * 50)
    print(f"  Manifest file: {data_file}")
    print(f"  Segments:      {seg_count}")
    print(f"  Total size:    {total_bytes} bytes")
    print()
    print("Next step: Restore segments from quarantine")
    print(f"  ./recover_segments_fixed.sh --account {args.account} "
          f"{args.container} {args.object}")


if __name__ == "__main__":
    main()
