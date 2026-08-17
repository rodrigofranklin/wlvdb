# Versioned unit contracts

The unit registry makes the semantic meaning of every stable result indicator
machine-readable. Each source selects one versioned contract in
`catalog/sources.csv`; `catalog/unit-contracts.csv` resolves that identifier to
two relational tables:

- `*-units.csv` describes the quantity, input scale, canonical result unit,
  currency, price basis, index base and labour concept of every indicator;
- `*-aggregations.csv` records the current sector-to-country and
  country-to-world operation for the same indicator.

Schema version `1` is descriptive. Loading the catalog checks paths, schemas,
enums, identifiers, foreign keys, exact two-level aggregation coverage and the
effective indicator set of every stable method. It also verifies that the
declared aggregation reproduces the operation or dedicated module selected by
the current parameter fragments. These declarations do not yet transform a
value or select a different aggregation algorithm.

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
