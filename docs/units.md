# Versioned unit contracts

The unit registry makes the semantic meaning of every stable result indicator
machine-readable. Each source selects one versioned contract in
`catalog/sources.csv`; `catalog/unit-contracts.csv` resolves that identifier to
two relational tables:

- `*-units.csv` describes the quantity, input scale, canonical result unit,
  currency, price basis, index base and labour concept of every indicator;
- `*-aggregations.csv` records the current sector-to-country and
  country-to-world operation for the same indicator.

Schema versions `1` and `2` are executable. Loading the catalog checks paths, schemas,
enums, identifiers, foreign keys, exact two-level aggregation coverage and the
effective indicator set of every stable method. Request validation translates
each direct declaration into a validated aggregation spec and checks its unit
algebra before a result lock is acquired or any variable module is run. The
contract, rather than the legacy `country_solution` string, selects the direct
algorithm; only `formula` rows remain on the dedicated module route.

| Contract strategy | Runtime rule | Required references |
| --- | --- | --- |
| `sum` | Sum the selected components. | The indicator itself. |
| `mean` | Use the compatibility arithmetic mean (`legacy_mean`). | The indicator itself. |
| `ratio_of_sums` | Divide the aggregate numerator by the aggregate denominator. | `numerator`, `denominator`, and a zero-denominator policy. |
| `weighted_mean` | Divide the weighted value total by the weight total. | The indicator, `weight`, and a zero-denominator policy. |
| `invariant` | Require the selected finite values to agree and publish that invariant. | The indicator itself. |
| `not_applicable` | Publish semantic `NA` without reducing its values. | The indicator itself, to define the output shape. |
| `formula` | Execute the named dedicated module after direct reductions. | `module`. |

The schema-v1 adapter declares `missing = available` explicitly when it builds
each spec. Missing inputs, partial coverage, undefined aggregates and protected
zero denominators are then handed to the versioned missingness runtime and its
state/anomaly sidecars. Direct sector-to-country reductions finish before
direct country-to-world reductions, so a world-level weight may consume its
already aggregated country value. A world-level direct row may not depend on a
country value produced later by a `formula` module; such a contract fails the
registry preflight instead of silently reading an uncomputed value.

Stable methods require a complete, valid typed contract and never infer missing
rows from legacy parameter strings. Experimental methods may use the legacy
adapter only with explicit experimental opt-in, and every adapted binding is
reported in a warning. Existing schema-v1 WIOD contracts use `sum`, `mean`, and
`formula`, so this runtime migration preserves their numerical output. Changing
a row to one of the other strategies is a separately reviewed numerical
migration.

Canonical units are also mapped to symbolic dimensions (`USD`, country-scoped
`LCU`, person, hour and labour value). Ratio-of-sums outputs must equal the
dimension implied by numerator divided by denominator, and world ratios and
weighted means reject inputs whose local currencies are not comparable. Schema
1 keeps historical `sum`/`mean`/`formula` cross-country behavior as an explicit
compatibility path. Schema 2 is strict: every country-to-world strategy rejects
an LCU-bearing output or input unless the row is `not_applicable`. This permits
a national LCU result while preventing a meaningless world total or average of
different currencies.

`source_scale` documents the multiplier between the effective source
generation consumed by a calculation and the published canonical unit. Stable
WIOD source generations are normalized before publication, so direct stable
indicators now declare canonical source units and a scale of `1`. The separate
`_normalization_contract.csv` source sidecar records conversions from the raw
provider units. Derived indicators also use a scale of `1`. `index_base`
records the value actually published in the base year; this intentionally
exposes the current WIOD13 base-one and WIOD16 gross-output-price base-100
conventions.

The historical `.cu` suffix on `compensation.emp.s.cu` and
`compensation.empe.s.cu` does not mean local-currency storage. Their modules
deflate the local-currency numerator and convert it with the 2000 exchange
rate, so the canonical result is additive constant-2000 USD.

Every successful calculation or recalculation writes `_unit_contract.csv` in
the method result directory. The sidecar is an ordered, effective expansion of
the selected contract: contract and schema identifiers, unit semantics and one
row for each aggregation level. It is staged and byte-compared with the rest
of the result metadata, so stale or missing contract metadata prevents
publication.

Changing a unit, scale, index base, labour concept or aggregation declaration
is a contract change. Such changes require a new contract identifier unless
they only correct prose in `notes`; numerical migrations belong in separately
reviewed changes with before/after validation.
