# Missingness policies

Missingness is part of the scientific contract, not a formatting detail. A zero
is a measured or computed value; it must never be used as a generic replacement
for an absent, undefined, or not-yet-computed value.

## Registry and runtime selection

The canonical source-to-policy relationship is declared in
`catalog/sources.csv`. Policy implementations are declared once in
`catalog/missingness-policies.csv` and are inherited by methods through their
canonical source. Catalog loading validates identifiers, repository-relative
paths, documentation, and the static presence of every factory without executing
scientific code. The selected factory is loaded only after request validation and
its policy is passed explicitly to the calculation or recalculation runtime.

The two stable policies are `wiodr13_v1` and `wiodr16_v1`. Indicator scheduling
continues to come from the effective method parameters; it is not duplicated in
the missingness registry.

## States

Every result cell is interpreted as one of four states:

- `finite`: a computed finite number, including a legitimate zero;
- `uncomputed`: the indicator is not due at the current checkpoint;
- `source_missing`: the source contract declares that coordinate absent;
- `not_applicable`: the operation has no defined value at that coordinate.

`NaN`, `Inf`, and `-Inf` are never valid states, even at a coordinate whose
policy permits an ordinary `NA`. An unexpected `NA` is also an error. Arrays
remain initialized with `NA`, so an omitted module remains `uncomputed` and is
rejected when its stage becomes due instead of being published as zero. A final
artifact may persist `source_missing` and `not_applicable`, but never
`uncomputed`.

## Stable source masks

The prepared-source validators and runtime policies share the following exact
scientific rules:

- WIOD 2013: `VA_USD` and `GO_USD` must be finite everywhere. All other SEA
  variables must be finite outside `ROW` and exactly `NA` in `ROW`.
- WIOD 2016: all raw SEA variables are exactly `NA` in `ROW`; `EMPE` and
  `H_EMPE` are also exactly `NA` in `CHN`. Every other coordinate is finite.
  At production dimensions this is 13,440 `ROW` cells plus 1,680 `CHN` cells,
  or 15,120 declared source-missing cells.

The validators reject a filled structural coordinate, a missing coordinate
outside the mask, and every `NaN` or infinite value. WIOD 2016 source anomalies
that are part of the official pinned data, including the 26 negative `VA_USD`
coordinates, are versioned as exact coordinate/value allowlists rather than
silently cleaned.

## Aggregation

Aggregations choose an explicit policy:

- `error`: any missing component aborts;
- `propagate`: a missing component makes the aggregate missing;
- `available`: aggregate the finite components and record incomplete coverage.

Under `available`, an all-missing group remains `NA` with its declared state. It
never becomes zero or `NaN`. Consequently `c(NA, NA)` and `c(0, 0)` remain
scientifically distinct. The active standard stage-5 ratio modules sum their
numerator and denominator independently through
`wlv_native_independent_country_ratio()`; their coverage can therefore differ.
The appropriated-profit module also aggregates capital compensation,
depreciation and capital stock separately. A paired-coverage strategy elsewhere
in the aggregation machinery must not be generalized to these published rates.
For example, world persons-engaged surplus-value rates can include imputed ROW
hours without corresponding reproduction costs. Review each operand before
interpreting the ratio; see the [methodology](methodology-en.md) and the
[coverage workflow](use-results-en.md#compare-ratios-on-common-coverage).

The typed dispatcher keeps its more detailed reduction state (`finite`,
`partial`, `missing`, `zero_denominator`, or `not_applicable`) on the result and
maps it to the persisted runtime vocabulary. Incomplete coverage and protected
zero-denominator decisions are also registered in `_anomalies.csv`; semantic
missing results are registered in `_states.csv`. Thus adding a new aggregation
strategy does not create a second, disconnected missingness channel.

## Division by zero

Every protected division selects one of these policies:

- `error`: any zero denominator aborts;
- `zero_if_both_zero`: `0 / 0` becomes zero, while nonzero over zero aborts;
- `zero_if_denominator_zero`: a declared zero-output domain maps every ratio
  with a zero denominator to zero and records the original `NaN` or infinity;
- `not_applicable`: any zero denominator becomes an `NA` in the
  `not_applicable` state;
- `not_applicable_if_both_zero`: `0 / 0` is not applicable, while nonzero over
  zero aborts.

The Leontief and direct-labour transformations use `zero_if_both_zero` for
explicitly empty flows. WIOD 2013 has one separately pinned Leontief exception
set: its known nonzero flows into zero-output columns are audited and converted
to the empty-flow case only after their complete coordinate set has matched the
versioned count, groups, and checksum documented in `docs/wiodr13.md`. Any new
nonzero-over-zero coordinate aborts. Result ratios use either
`not_applicable_if_both_zero` when a nonzero numerator signals an inconsistency,
or `not_applicable` when any zero denominator makes the rate undefined
(including the WIOD 2013 skill-specific surplus-value rates). The WIOD 2016
capital allocation keeps its separately tested `0 / 0` aggregate exception.
The standard WIOD exchange-rate calculation uses one ratio of compatible
national totals for every country-year and broadcasts it to all sectors. An
invalid national numerator, denominator, or rate aborts; it is never replaced
with zero or a sector mean. The preserved `wiodr13v09` and `wiodr16v09`
definitions describe the prior sector calculation solely for historical
auditing; neither is executable in the current release, including with
experimental opt-in.

## Checkpoints, diagnostics, and publication

Contracts run after source preflight, initialization, each due variable stage,
assumptions, matrix construction, matrix reduction, country/world aggregation,
serialization round trips, and immediately before publication. Errors contain
the artifact, indicator, checkpoint, stage/module, and up to three concrete
year/country/sector coordinates.

Every successful result directory contains `_anomalies.csv`, the audit history
for the current full calculation and all successful recalculations subsequently
applied to it, with these columns:

`artifact`, `indicator`, `checkpoint`, `stage`, `module`, `year`, `country`,
`sector`, `output`, `original_value`, `policy_id`, and `action`.

Expected transformations and missing-aware aggregations are recorded there. A
recalculation loads the published report and appends its new events without
deduplication, so repeated identical events remain visible as separate runs. A
new full calculation starts a new history. The staged CSV is read back and
compared with the in-memory audit table before publication. When a contract
aborts, the same evidence is written under `results/diagnostics/`; the failed
run does not alter the published history.

This includes finite negative-value transformations that would otherwise be
invisible to missingness checks: the pinned WIOD13/WIOD16 GFCF truncations,
the effective WIOD16 EU KLEMS weight truncations, both WIOD16 capital-stock
series, and the single Romanian value-added ratio made absolute. Each row keeps
the pre-transformation value and its exact source coordinates under a dedicated
versioned policy ID.

Negative-GFCF transformations are additionally published as two calculation-
specific method sidecars. `_gfcf_negative_cells.csv` preserves each original
and applied value and their delta; `_gfcf_negative_summary.csv` supplies the
total and year/country/sector profiles. Unlike `_anomalies.csv`, these files are
rebuilt by a full calculation and do not accumulate duplicate events across
recalculations. Because recalculation intentionally does not rerun matrix
allocation, it reloads both sidecars, revalidates their canonical magnitudes and
coordinates against the pinned source profile, and republishes them unchanged;
a missing or altered file requires a full calculation.

The sparse `_states.csv` sidecar persists the semantics of every ordinary `NA`
in `sea_sectors` and `sea_countries`: each row identifies its artifact,
indicator, coordinates, and either the `source_missing` or `not_applicable`
state. It never persists `finite` or `uncomputed`. Recalculation reloads those
states before it validates preserved indicators, then replaces the states of
every recomputed indicator. A missing or empty sidecar cannot authorize a
persisted `NA`, and duplicate, unknown, non-missing, or out-of-bounds records
abort. After serialization, the normalized sidecar must equal the in-memory
semantic state set, and a fresh runtime reloads it and validates the result
again. This keeps a legitimate prior `NA` distinct from an omitted module.

Calculation and recalculation write into a run-specific staging directory. The
complete artifact set, audit history, and semantic sidecar are serialized, read
back, and validated before publication. A manifest inventories and hashes the
validated staging tree, which is then renamed to a new immutable run ID. After
all requested methods succeed, a release fixes their run IDs and derives global
indicator metadata from exactly those runs. An append-only channel marker is
installed last. A failed run or release therefore leaves the prior marker and
everything it references unchanged. A global results lock serializes the full
protocol; recalculation reads arrays, state, and audit history only from its
verified isolated snapshot.
