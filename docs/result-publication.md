# Transactional result publication

WLVDB publishes validated results as immutable method runs and exposes a
coherent set of runs through an immutable release. The WLVPanel never selects a
partially written directory and never opens a modern result before validating
the complete checksum chain.

## Layout

```text
results/
  runs/<method>/<run_id>/
    ... method artifacts ...
    run_manifest.json
  releases/<release_id>/
    indicators_en.csv
    meta_indicators.csv
    release_manifest.json
  channels/<channel>/
    <20-digit-sequence>-<release_id>.json
  diagnostics/
```

A run directory and a release directory are installed under new identifiers;
neither overwrites an earlier generation. Channel markers are append-only. The
valid marker with the greatest 20-digit sequence is the current release for
that channel. This avoids replacing a `current` file, whose crash semantics are
not portable across Windows and Unix filesystems.

## Commit protocol

One global results lock covers requested source preparation, validation, every
requested method run, release construction, and marker installation.

1. Each method calculates in a same-volume private staging namespace under
   `results/.staging/`; it cannot be mistaken for a legacy method directory.
2. FST data and `.meta` sidecars are written as verified bundles. A v1 sidecar
   binds dimensions and dimnames to the SHA-256 of its FST payload.
3. Scientific contracts, schemas, metadata, serialization round trips, and the
   exact artifact inventory are validated.
4. `run_manifest.json` is written and read back. Only then is the staging
   directory renamed to its unique run path.
5. After every requested method succeeds, a release is built. Runs of methods
   not recalculated in the call are carried forward from the current release of
   the same channel. Panel metadata is derived only from those referenced runs;
   conflicting definitions abort the release.
6. The release manifest and its artifacts are verified, the release directory
   is installed under a new ID, and the channel marker is written last.

An error before step 6 cannot change what consumers see. A process termination
may leave an unreferenced run or release, but the previous marker and all data
reachable from it remain intact. The explicit retention workflow can later
collect those orphans.

## Manifests and identities

The normative JSON Schemas live in [`../contracts/results/`](../contracts/results/).
Contract v1 uses:

- run schema `wlv-run-manifest`, version `1`;
- release schema `wlv-release-manifest`, version `1`;
- marker schema `wlv-channel-marker`, version `1`;
- output contract `wlvpanel-output`, version `1.0.0`.

Every artifact record contains a normalized relative path, role, byte size, and
lowercase SHA-256. Inventories are exact: missing, additional, corrupted, or
unpaired FST/`.meta` files are rejected. A manifest never hashes itself. The
release hashes referenced run manifests, and the marker hashes its release
manifest.

`result_id` hashes the canonical stable projection: method, output contract,
stable result provenance/request/schema/audit summary, and artifact inventory.
It excludes `run_id`, timestamps, `parent_run_id`, duration, warnings, and host
details. Thus repeated equivalent requests can have distinct execution IDs but
the same result identity.

Run provenance includes the Git commit and dirty-state fingerprint, the
`renv.lock` hash, R/platform and package versions, normalized-source contracts,
the complete normalized-source manifest, and relative size/SHA-256 records for
supplemental source inputs. The calculation inventory covers R code, modules,
catalogs, result contracts, complementary data, method configuration, and
parameter files. Git status is inspected over the corresponding directory
scopes so additions and deletions also affect the dirty-state fingerprint.

Persisted execution warnings are valid single-line UTF-8 text. Project, home,
temporary, and other absolute paths are replaced with redaction markers, as are
URLs and common inline credential fields. User names, hostnames, absolute paths,
or environment-variable snapshots are not added as structured provenance.
Diagnostic code must still avoid putting arbitrary sensitive prose into a
warning when it does not use one of the recognized credential forms.

## Recalculation and lineage

`recalc_wlv()` resolves the selected channel, verifies marker → release → run →
artifacts, and copies that immutable run into a new staging snapshot. The child
manifest records `parent_run_id`. The parent is never modified or removed by
the recalculation itself.

Legacy `results/<method>/` directories remain readable only as an explicit
warning-based migration fallback when a channel has no marker. They are not
assigned invented provenance. Create a fresh full run to migrate a method.

## Channels and consumers

`stable` is the default. Use `channel = "research/input-v3"` from R,
`--channel research/input-v3` from the CLI, or `WLV_CHANNEL` for the CLI. The
WLVPanel selects the corresponding channel with `WLV_RELEASE_CHANNEL`.
Exploration channels have independent marker histories and cannot change the
stable release.

The publication topology is canonical and link-free: `results`, its store
roots, method directories, and every channel component must be real directories,
not symbolic links or junctions. This keeps promotions and marker renames on the
intended publication volume.

The WLVPanel validates schemas, versions, canonical paths, identities, exact
inventories, sizes, hashes, and FST/sidecar pairing before loading any modern
array. An invalid marker never falls back to legacy data. The temporary legacy
fallback applies only when no marker exists at all.

Immutable history increases storage use. No automatic deletion occurs; see
[`publication-storage.md`](publication-storage.md) for the dry-run-first,
channel-aware retention workflow.
