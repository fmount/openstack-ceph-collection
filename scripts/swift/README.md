# Swift Recovery Scripts

## Scripts

### check_swift_hash_config.sh

Verifies Swift hash configuration consistency across all controllers. Checks
three things: the on-disk puppet-generated config, the bind-mounted config
inside running Swift containers, and container uptime (to detect stale
processes still using the old hash in memory).

Run from the undercloud or a jump host with SSH access to controllers.

```bash
# Default: 3 controllers
./check_swift_hash_config.sh

# Custom controller count
./check_swift_hash_config.sh 5
```

### check_hash.py

Determines which `swift_hash_path_suffix` produced a quarantined object's hash.
Computes `md5(prefix + /account/container/object + suffix)` for each known
suffix and compares against both:
- The hash reported by `swift-object-info` (current swift.conf)
- The quarantine directory name (the hash when the file was originally placed)

Requires: Python 3, `swift-object-info` in PATH. Run inside the Swift container.

```bash
# From a quarantined .data file (auto-reads metadata + quarantine dir hash)
python3 check_hash.py --from-file \
  /srv/node/pv/quarantined/objects/33a01451d5fc8019061168238529431f/1781720008.14973.data

# Direct arguments
python3 check_hash.py AUTH_abc123 glance image-uuid 5848c0567ad16d70eccd3297c9408e21

# With custom prefix/suffix overrides
python3 check_hash.py --prefix "myprefix" --suffixes "TEST:someHashValue" \
  AUTH_abc123 glance image-uuid expected_hash
```

Example output:

```
File: /srv/node/pv/quarantined/objects/33a014.../1781720008.14973.data
Path:   /AUTH_abc123/glance/image-uuid
Prefix: 'wwWGUO6PXQj0QpzK'

Expected hashes:
  swift-object-info: 5848c0567ad16d70eccd3297c9408e21
  quarantine_dir:    33a01451d5fc8019061168238529431f

  GOOD     suffix (hXu8HT32RTTJ...): 5848c0567ad16d70eccd3297c9408e21  [MATCH (swift-object-info)]
  BAD      suffix (rE53TXbYHXeL...): 33a01451d5fc8019061168238529431f  [MATCH (quarantine_dir)]

CONCLUSION: Object was written with the BAD suffix.
  Object was written with: BAD suffix
  Current config uses:     GOOD suffix
  -> Object needs to move from quarantine to the ring path
     computed with the GOOD suffix.
```

### quarantine_classifier.sh

Samples 200 quarantined `.data` files, classifies them by container type
(glance, gnocchi, other), and writes the file paths to separate lists for
targeted recovery or bulk deletion.

Requires: `swift-object-info`, `shuf`. Run inside the Swift container.

```bash
./quarantine_classifier.sh
```

Produces:
- `/tmp/quarantined_glance.txt` — paths to Glance objects (recover these)
- `/tmp/quarantined_gnocchi.txt` — paths to Gnocchi/telemetry objects (likely safe to delete)
- `/tmp/quarantined_other.txt` — everything else

### reconstruct_slo_manifest.py

Reconstructs or restores SLO (Static Large Object) manifests. Two modes:

**Restore mode** — moves a quarantined manifest `.data` file back to its correct
ring path. Use when the manifest itself is quarantined but intact.

```bash
# Dry run
python3 reconstruct_slo_manifest.py --dry-run --restore-manifest \
  /srv/node/pv/quarantined/objects/33a014.../1781720008.14973.data

# Restore for real
python3 reconstruct_slo_manifest.py --restore-manifest \
  /srv/node/pv/quarantined/objects/33a014.../1781720008.14973.data
```

**Reconstruct mode** — rebuilds a lost SLO manifest from quarantined segments.
Scans quarantine for segments, assembles the manifest JSON, places it at the
correct ring path, and stamps Swift xattrs via `write_metadata()`.

```bash
# Dry run (builds manifest JSON, saves to /tmp, does not write to ring path)
python3 reconstruct_slo_manifest.py --dry-run AUTH_abc123 glance image-uuid

# Full reconstruction
python3 reconstruct_slo_manifest.py AUTH_abc123 glance image-uuid
```

Requires: Python 3, `swift` package (`from swift.obj.diskfile import write_metadata`),
`swift-object-info` and `swift-get-nodes` in PATH. Run inside the Swift container.

## Recovery Workflow

1. **Verify config** — run `check_swift_hash_config.sh` across all controllers.
   If any container shows the wrong hash or hasn't been restarted since the fix,
   restart it before doing anything else.

2. **Classify quarantine** — run `quarantine_classifier.sh` to understand the
   glance-vs-gnocchi ratio. Confirm with the customer that gnocchi data is
   expendable.

3. **Check hash provenance** — run `check_hash.py --from-file` on a few
   quarantined files to confirm they were written with the bad suffix and that
   the current config produces the correct ring path.

4. **Delete useless objects** — free some space by removing quarantined files
   (e.g. the paths in `/tmp/quarantined_gnocchi.txt` in the example)

5. **Restore objects** — use `reconstruct_slo_manifest.py --restore-manifest`
   for quarantined files with intact metadata. Use the reconstruction mode only
   if the manifest itself is lost and segments are available.

6. **Controlled service restart** — start Swift services one at a time (object
   server first, then auditor on one controller, monitor, then replicator),
   watching disk usage and logs at each step.
