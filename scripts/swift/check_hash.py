#!/usr/bin/env python3
"""
Verify which swift_hash_path_suffix produced a quarantined object's hash.

Compares computed hashes against:
  1. The hash reported by swift-object-info (current swift.conf)
  2. The quarantine directory name (the hash when the file was originally placed)

Usage:
  ./check_hash.py --from-file /srv/node/pv/quarantined/objects/33a014.../timestamp.data
  ./check_hash.py ACCOUNT CONTAINER OBJECT EXPECTED_HASH
  ./check_hash.py --prefix PREFIX --suffixes "LABEL:VALUE,..." ACCOUNT CONTAINER OBJECT HASH
"""

import argparse
import hashlib
import os
import re
import subprocess
import sys


KNOWN_SUFFIXES = {
    "GOOD": "hXu8HT32RTTJDXAJMGq2yHJmv",
    "BAD":  "rE53TXbYHXeLI0WrSd8dCl9Hy",
}


def swift_hash(prefix, path, suffix):
    return hashlib.md5((prefix + path + suffix).encode()).hexdigest()


def read_prefix_from_conf():
    for conf_path in ["/etc/swift/swift.conf", "/srv/node/swift.conf"]:
        try:
            with open(conf_path) as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("swift_hash_path_prefix"):
                        return line.split("=", 1)[1].strip()
        except FileNotFoundError:
            continue
    return ""


def extract_quarantine_dir_hash(filepath):
    """
    Extract the hash directory name from a quarantine path.
    e.g. /srv/node/pv/quarantined/objects/33a01451d5fc.../file.data
    returns 33a01451d5fc...
    """
    parts = filepath.split("/")
    for i, part in enumerate(parts):
        if part == "objects" and i + 1 < len(parts):
            candidate = parts[i + 1]
            if re.match(r'^[a-f0-9]{32}$', candidate):
                return candidate
    parent = os.path.basename(os.path.dirname(filepath))
    if re.match(r'^[a-f0-9]{32}$', parent):
        return parent
    return None


def parse_swift_object_info(output):
    info = {}
    for line in output.splitlines():
        line = line.rstrip("\r")
        if line.startswith("  Account:"):
            info["account"] = line.split(":", 1)[1].strip()
        elif line.startswith("  Container:"):
            info["container"] = line.split(":", 1)[1].strip()
        elif line.startswith("  Object:"):
            info["object"] = line.split(":", 1)[1].strip()
        elif line.startswith("  Object hash:"):
            info["hash"] = line.split(":", 1)[1].strip()
        elif line.startswith("Hash"):
            if "hash" not in info:
                info["hash"] = line.split()[1].strip()
    return info


def check_hash(prefix, account, container, obj, expected_hashes, suffixes):
    """
    expected_hashes: dict of label -> hash to compare against.
    e.g. {"swift-object-info": "5848c...", "quarantine_dir": "33a0..."}
    """
    path = f"/{account}/{container}/{obj}"

    print(f"Path:   {path}")
    print(f"Prefix: '{prefix}'" if prefix else "Prefix: (empty)")
    print()
    print("Expected hashes:")
    for label, h in expected_hashes.items():
        print(f"  {label}: {h}")
    print()

    results = {}
    for label, suffix in suffixes.items():
        computed = swift_hash(prefix, path, suffix)
        matches = []
        for hlabel, hval in expected_hashes.items():
            if computed == hval:
                matches.append(hlabel)

        if matches:
            marker = "MATCH (" + ", ".join(matches) + ")"
        else:
            marker = "no match"

        results[label] = {"computed": computed, "matches": matches}
        print(f"  {label:8s} suffix ({suffix[:12]}...): {computed}  [{marker}]")

    print()

    # Summary
    any_match = any(r["matches"] for r in results.values())
    if not any_match:
        print("WARNING: No known suffix produced a matching hash.")
        print("Check swift_hash_path_prefix or add more suffixes with --suffixes.")
        return False

    for label, r in results.items():
        if "quarantine_dir" in r["matches"]:
            print(f"CONCLUSION: Object was written with the {label} suffix.")
            print(f"  The quarantine directory hash was computed with this suffix.")
        if "swift-object-info" in r["matches"]:
            print(f"  The current swift.conf produces the same hash ({label} suffix).")
            print(f"  Ring path is correct for restoration.")

    # Check if current config matches quarantine dir
    current_matches = [l for l, r in results.items() if "swift-object-info" in r["matches"]]
    quarantine_matches = [l for l, r in results.items() if "quarantine_dir" in r["matches"]]

    if current_matches and quarantine_matches and current_matches != quarantine_matches:
        print()
        print(f"  Object was written with: {quarantine_matches[0]} suffix")
        print(f"  Current config uses:     {current_matches[0]} suffix")
        print(f"  -> Object needs to move from quarantine to the ring path")
        print(f"     computed with the {current_matches[0]} suffix.")

    return True


def main():
    parser = argparse.ArgumentParser(
        description="Verify which swift_hash_path_suffix matches an object hash"
    )
    parser.add_argument(
        "--prefix", default=None,
        help="swift_hash_path_prefix (auto-detected from swift.conf if omitted)"
    )
    parser.add_argument(
        "--suffixes", default=None,
        help="Additional suffixes to test: LABEL:VALUE,LABEL:VALUE,..."
    )
    parser.add_argument(
        "--from-file", metavar="DATA_FILE", default=None,
        help="Read metadata from a .data file via swift-object-info"
    )
    parser.add_argument("account", nargs="?", help="Swift account")
    parser.add_argument("container", nargs="?", help="Container name")
    parser.add_argument("object", nargs="?", help="Object name")
    parser.add_argument("expected_hash", nargs="?", help="Expected object hash")

    args = parser.parse_args()

    # Build suffix dict
    suffixes = dict(KNOWN_SUFFIXES)
    if args.suffixes:
        for entry in args.suffixes.split(","):
            if ":" in entry:
                label, value = entry.split(":", 1)
            else:
                label = f"CUSTOM{len(suffixes)}"
                value = entry
            suffixes[label] = value

    # Resolve prefix
    if args.prefix is not None:
        prefix = args.prefix
    else:
        prefix = read_prefix_from_conf()

    # Get object info
    expected_hashes = {}

    if args.from_file:
        try:
            result = subprocess.run(
                ["swift-object-info", args.from_file],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode != 0:
                print(f"ERROR: swift-object-info failed: {result.stderr}")
                sys.exit(1)
            info = parse_swift_object_info(result.stdout)
        except FileNotFoundError:
            print("ERROR: swift-object-info not found in PATH")
            sys.exit(1)

        account = info.get("account")
        container = info.get("container")
        obj = info.get("object")
        obj_info_hash = info.get("hash")

        if not all([account, container, obj]):
            print(f"ERROR: Could not parse all fields from swift-object-info")
            print(f"  Parsed: {info}")
            sys.exit(1)

        if obj_info_hash:
            expected_hashes["swift-object-info"] = obj_info_hash

        quarantine_hash = extract_quarantine_dir_hash(args.from_file)
        if quarantine_hash and quarantine_hash != obj_info_hash:
            expected_hashes["quarantine_dir"] = quarantine_hash

        print(f"File: {args.from_file}")
    else:
        if not all([args.account, args.container, args.object, args.expected_hash]):
            parser.print_help()
            sys.exit(1)
        account = args.account
        container = args.container
        obj = args.object
        expected_hashes["provided"] = args.expected_hash

    found = check_hash(prefix, account, container, obj, expected_hashes, suffixes)
    sys.exit(0 if found else 1)


if __name__ == "__main__":
    main()
