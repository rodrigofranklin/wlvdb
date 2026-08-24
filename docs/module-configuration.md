# Typed module configuration

Executable methods select native modules through inert CSV configuration under
`config/modules/`. Module contracts, dependencies, checkpoints and executable R
functions are defined together in R; they are never supplied by configuration.

The effective configuration is resolved in this fixed direction:

1. `config/modules/common.csv`
2. `config/modules/sources/<source>.csv`
3. `config/modules/methods/<method>.csv`

Each fragment has these columns:

- `instance_id`: stable semantic slot in the execution graph.
- `module_id`: alias of a module already present in the native registry.
- `action`: `add`, `replace` or `remove`.
- `replaces`: earlier `instance_id` required by `replace` and `remove`.
- `variant`: optional typed variant consumed by modules that declare it.
- `source_variable`: optional normalized SEA variable consumed by
  `source_indicator`.
- `args_json`: a JSON object containing inert typed arguments.

Duplicate instances within one layer, implicit overwrites, replacement of an
unknown instance, paths, R filenames and malformed JSON are rejected before a
graph is compiled. Resolution does not use CSV row order: each layer is sorted
by `instance_id`, and cross-layer precedence is explicit in `action`.

`wlv_resolve_module_config()` returns the effective data frame expected by the
native graph compiler. Its `args` list-column contains the parsed arguments,
including declared `variant` and `source_variable` values.

## Historical aggregation profiles

The ten executable experimental methods explicitly select one of two shared
profiles through `config/aggregations/method_profiles.csv`:

- `wiodr13_historical_v1`
- `wiodr16_historical_v1`

These profiles preserve the exact pre-v2 `sum`, arithmetic `mean` and formula
bindings. Formula bindings refer to registered aliases, never script paths.
There is no runtime fallback from a missing typed aggregation row.
