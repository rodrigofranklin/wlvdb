# Unit and aggregation migration

## WIOD16 v1 to v2

`wiodr16_units_v1` remains available as the historical declaration. New stable
WIOD16 calculations select `wiodr16_units_v2`; the normalized source and result
provenance pin that selection.

| Indicator family | v1 storage or aggregation | v2 canonical rule | Presentation |
|---|---|---|---|
| Gross-output price index | Stored with `2000 = 100`; sector arithmetic mean | Stored with `2000 = 1`; gross-output-weighted national mean | Multiply by 100 |
| Basket-price, exchange, and basket-value indices | Base-one values with legacy mean declarations | Invariant within a country; no world aggregation across incompatible national bases | Multiply by 100 |
| Exchange rate (`exchange.r.us`) | Sector arithmetic mean and an arithmetic world mean | Invariant country-year LCU/USD scalar; world value is not applicable | No display scaling |
| Average value (`value.m.mv`) | Summed even though it is a ratio | `sum(gross_output.s.mv) / sum(gross_output.s.us)` at each level | No display scaling |
| Employee complexity multiplier | Sector and country arithmetic means | Weighted by employee hours | No display scaling |
| Persons-engaged complexity multiplier | Sector and country arithmetic means | Weighted by persons-engaged hours | No display scaling |

The asymmetric golden fixture makes these choices observable. For sector values
`1, 3` with output weights `10, 30`, the national price is `2.5`, not the simple
mean `2`. For abstract-labour totals `20, 120` over outputs `10, 30`, average
value is `140 / 40 = 3.5`, not the mean of the two sector ratios.

Constant-price capital now consumes the canonical base-one output-price index:

```
constant stock = current stock * exchange-rate index / output-price index
```

This is numerically equivalent to the old formula that multiplied by 100 and
divided by a base-100 price index. The scale factor has moved out of scientific
storage and into presentation metadata, so it cannot be applied twice.

## Compatibility

New results persist `canonical_unit`, `display_unit`, `display_multiplier`,
`index_base_year`, and `index_storage_base` in indicator metadata, and repeat
the same semantics in `_unit_contract.csv`.

An archived `meta_indicators.RDS` that predates these fields remains readable.
The compatibility reader emits a warning and supplies
`display_multiplier = 1`; it does not guess a historical scale or rewrite the
stored values. Archives without the normalized-source provenance required by
the current runtime remain viewable but are not eligible for recalculation.

## Labour concepts across WIOD releases

The contract does not treat workers, employees, or hours as interchangeable:

| Concept | WIOD13 | WIOD16 | Aggregation use |
|---|---|---|---|
| Persons engaged | `EMP`, normalized to persons | `EMP`, normalized to persons | Counts sum; persons-engaged multipliers use `hours_worked.emp.s.hr` |
| Employees | `EMPE`, normalized to employees | `EMPE`, normalized to employees | Counts sum; employee multipliers use `hours_worked.empe.s.hr` |
| Persons-engaged hours | Official `H_EMP`, normalized to hours | Derived from official employee hours and employment, with the versioned China supplement | Additive labour weight |
| Employee hours | Official `H_EMPE`, normalized to hours | Official except for the documented China source gap | Additive labour weight |
| Skill composition | WIOD13 exposes low-, medium-, and high-skill compensation and hour shares | WIOD16 SEA does not expose an equivalent skill-share series in this method | Never inferred across releases |

For China in WIOD16, the official SEA omits `EMPE` and `H_EMPE`. The versioned
supplement maps WIOD13 hours-per-worker information to WIOD16 industries and
treats persons engaged as employees. That documented assumption is specific to
WIOD16 and must not be silently generalized to WIOD13 or to cross-source
comparisons.
