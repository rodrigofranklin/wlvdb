# Publication storage and retention

Publication is intentionally immutable. A method run is written once under
`results/runs/<method>/<run_id>/`, and a release is a small manifest that
references one run per method. Creating another release does **not** copy a run
that is reused from an earlier release. Storage growth therefore comes mainly
from newly executed method runs, while release manifests and channel markers
are small. Two executions with the same semantic `result_id` remain distinct
auditable runs until an explicit retention operation removes the older,
unreferenced run.

Channels make version exploration independent. For example, `stable` can keep a
longer history while `exploration/v2` keeps only a few comparison points. A
release becomes visible only through a marker under
`results/channels/<channel>/`; the marker with the highest sequence is the
channel's current release.

## Retention is explicit

No calculation, publication, or application startup performs garbage
collection. Retention has two separate calls:

1. `wlv_plan_publication_prune()` validates the complete store and produces an
   immutable snapshot of eligible paths and reclaimable bytes.
2. `wlv_prune_publications()` consumes that snapshot and is a dry run by
   default. Deletion requires `dry_run = FALSE` explicitly.

Load the regular runtime, then inspect a plan:

```r
bootstrap <- new.env(parent = baseenv())
sys.source("R/bootstrap.R", envir = bootstrap)
runtime <- bootstrap$wlv_load_runtime(".")

plan <- runtime$wlv_plan_publication_prune(
  root = ".",
  keep_releases = c(
    stable = 5,
    `exploration/v2` = 2
  )
)

plan$channels
plan$delete$markers
plan$delete$releases
plan$delete$runs
plan$reclaimable_bytes

# This does not delete anything.
preview <- runtime$wlv_prune_publications(plan)
```

After reviewing the exact paths and byte estimate, apply the same plan:

```r
result <- runtime$wlv_prune_publications(plan, dry_run = FALSE)
result$deleted
result$reclaimed_bytes
```

The apply step acquires the global results lock, rebuilds the plan, and compares
it byte-for-byte with the reviewed snapshot. If a publication appeared or any
file changed in the meantime, it refuses to delete anything and asks for a new
plan.

## Policy semantics

An unnamed value applies to every channel:

```r
wlv_plan_publication_prune(".", keep_releases = 10)
```

A named vector applies only to the named channels. Any existing channel omitted
from a named policy is preserved in full. This makes a stable-only cleanup safe
for independent exploration channels:

```r
# Keeps the newest three stable releases and every release in all other channels.
wlv_plan_publication_prune(".", keep_releases = c(stable = 3))
```

Use `Inf` to preserve all marked releases in a channel. Counts must be positive
integers, so every channel always retains at least one marker and its current
release. Hierarchical lowercase channel names such as `research/input-v3` are
supported.

For every retained marker, retention preserves:

- its release directory and verified release manifest;
- every run directory referenced by that release;
- every run manifest and artifact in those run directories.

A run shared by several retained releases is counted and stored only once.
Runs referenced only by releases outside the retention window are eligible for
collection. `parent_run_id` is provenance rather than a storage reference, so a
parent used only by pruned releases is not retained automatically; keep the
corresponding release or a separate archival copy when full ancestry is needed.

## Safety and failure behavior

Planning refuses the store instead of offering a force mode when it finds any
of the following:

- an unreadable or schema-invalid run, release, or channel manifest;
- a missing artifact, size mismatch, or SHA-256 mismatch;
- a release reference that does not resolve to the canonical run layout;
- a marker that does not resolve to the canonical release layout;
- an unexpected file where a run, release, channel directory, or marker is
  required;
- a symbolic link, junction, path escape, duplicate channel sequence, partial
  store, or active results lock.

Only three kinds of planned targets can be removed: old channel marker files,
unretained whole release directories, and unreferenced whole run directories.
The operation never deletes individual artifacts, channel directories, method
directories, or legacy paths such as `results/<method>/`. Valid orphan releases
and runs left by an interrupted publication are eligible, but an invalid orphan
blocks the whole plan so that corruption is never silently discarded.

Removal order is markers, then release directories, then run directories. Each
eligible object is first renamed atomically into `results/.trash/` on the same
volume. The retained publication graph is validated again before quarantine is
deleted. A hard interruption during recursive deletion can therefore damage
only `.trash`, never a marked release or the active `runs/`, `releases/`, and
`channels/` graph. The next explicit apply finishes stale quarantine under the
lock after the reviewed plan has been rebuilt and matched against current
storage.

`reclaimable_bytes` and `reclaimed_bytes` are sums of regular file sizes in
disjoint planned targets. Actual filesystem space returned to the volume can
differ because of allocation units, compression, deduplication, or snapshots.

Retention is not a backup policy. Releases needed for audit, reproducibility, or
long-term comparison should also be copied to durable archival storage before
their channel retention window expires.

A hard process termination can also leave private children under
`results/.staging/`. They are never part of the published graph and are not
treated as legacy methods, but the v1 retention API deliberately does not remove
them automatically. An operator may remove a confirmed abandoned staging child
only while no calculation is active and while holding the global results lock;
automated, dry-run-first staging recovery is reserved for a later maintenance
extension.
