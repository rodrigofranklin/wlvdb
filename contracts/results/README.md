# Results publication contract v1

The publication chain has three strict JSON documents:

- `run_manifest.json` inventories every regular file in one immutable run,
  except the manifest itself.
- `release_manifest.json` inventories release-level artifacts and references
  run manifests by path, identity, and SHA-256. It never embeds or hashes
  itself.
- `<sequence>-<release_id>.json` is an append-only channel marker. The
  sequence is a zero-padded 20-digit decimal string and must match the
  filename.

All paths use forward slashes and are relative to their declared root. FST
artifacts and their `.meta` sidecars are an inseparable pair. Inventories are
unique and sorted by relative path; release run references are unique and
sorted by method.

`result_id` is the SHA-256 of the canonical semantic payload composed of the
method, output contract, stable `result` object, and artifact inventory. It
does not include `run_id`, timestamps, `parent_run_id`, or `execution` data.

The v1 output contract literals are `wlvpanel-output` and `1.0.0`. Unknown
schemas, schema versions, fields, or output-contract versions must be rejected.
