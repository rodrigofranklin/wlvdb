# WIOD13 typed aggregation migration

`wiodr13_units_v2` is the first WIOD13 unit contract whose aggregation rows
are executable scientific specifications instead of descriptions of the
legacy `sum` and arithmetic-`mean` dispatcher. The source catalog selects v2
for new calculations. The immutable v1 contract remains registered so that
historical result sidecars can still be interpreted and audited.

This is a breaking scientific change. A result carrying
`wiodr13_units_v1` must not be selectively recalculated under v2. It remains
readable, but producing v2 values requires a complete calculation from the
normalized source generation.

## Rules and expected impact

| Indicator family | v1 operation | v2 sector-to-country | v2 country-to-world | Scientific reason |
| --- | --- | --- | --- | --- |
| Employee compensation skill shares | Arithmetic mean | Weighted mean by `compensation.empe.s.us` | Same weighting over country totals | A share represents compensation in the skill group divided by total compensation. |
| Employee hours skill shares | Arithmetic mean | Weighted mean by `hours_worked.empe.s.hr` | Same weighting over country totals | A share represents skill-group hours divided by total employee hours. |
| `exchange.r.us` | Arithmetic mean | Invariant | Not applicable | LCU/USD is broadcast within a country and currencies are incompatible across countries. |
| Basket price, exchange and basket value indices | Arithmetic mean | Invariant | Not applicable | Each national index is broadcast to sectors and has no currency-compatible world value. |
| `go_price.r.id` | Arithmetic mean | Weighted mean by `gross_output.s.us` | Not applicable | A national output-price index needs an economic output weight; national-currency indices are not combined globally. |
| Complex-labour multiplier, employees | Arithmetic mean | Weighted mean by `hours_worked.empe.s.hr` | Same weighting over country totals | The multiplier transforms employee hours. |
| Complex-labour multiplier, persons engaged | Arithmetic mean | Weighted mean by `hours_worked.emp.s.hr` | Same weighting over country totals | The multiplier transforms hours of persons engaged. |
| `value.m.mv` | Sum of sector ratios | Ratio of sums: `gross_output.s.mv / gross_output.s.us` | Same ratio over country totals | Labour value per USD is an intensive quantity, not an additive stock. |

Every weighted or ratio aggregation declares `not_applicable` for a zero
weight or denominator. The typed reducer persists that state rather than
publishing a non-finite value.

The asymmetric golden cases make the numerical migration visible:

| Case | Inputs | v1 | v2 |
| --- | --- | ---: | ---: |
| Compensation share | shares `0.9, 0.1`; compensation `10, 90` | `0.5` | `0.18` |
| Hours share | shares `0.8, 0.2`; hours `25, 75` | `0.5` | `0.35` |
| Gross-output price | indices `0.8, 1.2`; output `10, 90` | `1.0` | `1.16` |
| Employee complexity | multipliers `1, 3`; hours `90, 10` | `2.0` | `1.2` |
| Value per USD | labour value `8, 90`; USD output `2, 30` | `7.0` | `3.0625` |

The examples are intentionally asymmetric: a symmetric fixture can let an
unweighted mean pass while still implementing the wrong science.

## Canonical index base

WIOD13 source price indices are normalized from provider base 100 to canonical
base 1 before calculation. Basket modules therefore consume the canonical
price level directly; they no longer divide it by 100 a second time. The
published basket price, basket value, exchange and gross-output price indices
are all rebased to `2000 = 1`, and display metadata now states that same base.

Removing the redundant internal division does not intentionally change a
finite rebased basket series: the constant factor previously cancelled when
the series was divided by its 2000 value. It does remove an undocumented
intermediate scale and makes the module dimensionally consistent with the
normalized-source contract.

## Compatibility boundary

Indicator identifiers, array dimensions, dimension order and country/sector
labels are unchanged. The deliberate value-level changes are:

- intensive indicators use their declared weights or numerator/denominator;
- incompatible `WWW` aggregates become `NA` with state `not_applicable`;
- a violated country-level invariant fails instead of being hidden by a mean;
- all WIOD13 index metadata consistently describes base 1.

Consumers that need to compare historical and migrated results should group
by the contract identifier stored in `_unit_contract.csv`; they must not treat
v1 and v2 values as the same scientific series.
