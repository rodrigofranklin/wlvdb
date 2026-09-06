# Assumptions, limitations and work still needed

<!-- documentation-revision: wiod-consolidation-v1 -->

[Português](assumptions-pt.md) | English | [Home](../README.md) | [Theory](theory-en.md) | [Mathematics](methodology-en.md) | [Practical guide](guide-en.md)

## How to read this register

A result is conditional on a model and its data. An **assumption** connects an
economic concept to something measurable; an **imputation** supplies an absent
observation; a **numerical rule** determines what to do when a calculation is
undefined or unusually sensitive. These choices have different justifications.
Passing a software check establishes that the chosen rule was implemented
consistently. It does not establish that every assumption describes the economy
equally well.

This register covers the public `wiodr13` and `wiodr16` methods, from source
preparation to interpretation. Their active selections are in
[common modules](../config/modules/common.csv), [WIOD13 modules](../config/modules/sources/wiodr13.csv)
and [WIOD16 modules](../config/modules/sources/wiodr16.csv). Preserved alternative
files are not evidence that an alternative is executable. Exact cell lists and
tolerances remain in the linked contracts; they are too large to replace with
a verbal summary. Read this page alongside the mathematical derivation.

## Economic model and measurement

| Choice | Why it is needed and what it means | Consequence for interpretation |
| --- | --- | --- |
| One representative technology for each country-industry-year | Annual IO accounts pool producers and products. Input requirements and labour intensity are treated as proportional within each cell; the model follows observed average requirements. | Firm differences, joint production and product quality are aggregated. A computed hour requirement is conditional on this aggregation, not an individual commodity's independently observed value. |
| Annual reproduction with fixed coefficients | Intermediate inputs and annual depreciation enter the labour-value system at the year's coefficients. | This is a static reproduction estimate; it does not model adjustment paths, capacity constraints, substitution or technical change within the year. Depreciation represents current replacement requirements, not the historical labour actually spent on each surviving machine. |
| Monetary deliveries represent quantities valued consistently | Dividing a supplier's monetary flows by the purchasing industry's output creates monetary coefficients. Labour per USD converts the supplier's flows back into labour requirements. | The construction does not assume market prices equal values. It does require sufficiently consistent prices, units and homogeneous industry products; the [derivation](methodology-en.md) explains the price cancellation and its limits. |
| Equal weight for each hour | Both standard methods set `complex_labour_multiplier` to 1. | Skill, intensity and national differences are not separately reduced to simple labour. WIOD13 skill-specific rates still use this assumption. The article's alternative reduction methods cannot be reproduced by merely running a standard method. |
| Productive industry classification | The productive block is selected by `productive` in the [WIOD13](../methods/wiodr13/_sectors.csv) and [WIOD16](../methods/wiodr16/_sectors.csv) sector tables. Labour-value creation is attributed to that block. | Unproductive industries may provide socially useful services and receive value. Structural zeros in the transformation express the classification, not the absence of workers or economic activity. Changing the classification changes the model. |
| Household consumption as a reproduction basket | The national household purchase composition is used to translate compensation into the labour required by the basket it finances. The same national composition is applied to the industries' workers. | Workers need not consume like the average household. Saving, credit, differences between skill groups, household composition and publicly provided services are not separately identified. The result estimates reproduction under this convention, not a normative subsistence threshold. |
| Compensation as basket-purchasing resources | Employee compensation and total labour compensation finance the corresponding baskets; the latter includes the source's treatment of non-employees. | A rate for `empe` and a rate for `emp` have different populations and remuneration concepts. Compensation is an accounting measure and is not identical to take-home pay. |
| Surplus-value rate as a ratio in labour units | The appropriate labour total is divided by the corresponding basket value, then 1 is subtracted. Productive variants restrict the population. | A high rate alone establishes neither wage payment below the value of labour power nor a causal diagnosis of dependency. Total hours and dollars cannot be inserted directly into the same ratio. |
| Two different world normalizations | Direct prices use world gross-output money/value totals; trade transfers use productive international trade money/value totals. | They answer different questions. Neither factor is an observed exchange rate or a purchasing-power-parity conversion. Trade transfers describe the selected trade mechanism, not all cross-border income appropriation. |

The productive classification is not identical to the article's: its note 21
excludes Hotels and Restaurants and Other Community, Social and Personal
Services, whereas the current WIOD13 table includes both (`H` and `O`). The
current mask has 25 productive industries; the article's stated system uses 23.
Matching the IO release is therefore insufficient to reproduce that study.

Theory and the supplied texts' specific positions are explained in
[theory](theory-en.md), with [ABNT references](references-en.md). Runtime
implementations are in [matrix modules](../scripts/modules/native/matrix_modules.R),
[common indicator modules](../scripts/modules/native/indicator_common_modules.R) and
[source-derived indicators](../scripts/modules/native/indicator_source_derived_modules.R).

## Labour and the rest of the world

### China and employees versus persons engaged

WIOD13 supplies total hours and employment; its China assumption substitutes
persons engaged for employees, for both headcounts and hours. WIOD16's general
formula estimates total hours as employee hours per employee multiplied by all
persons engaged. It therefore assumes the same mean annual hours for employees
and non-employees in each country-industry.

For China, WIOD16 instead uses a [versioned supplementary table](../complementar/wiodr16/china_hours_per_worker.csv)
derived from WIOD13 `H_EMP / EMP` and mapped to the WIOD16 industries:

$$
H^{CHN}_{s,t}=N^{CHN}_{s,t}\,a_{s,t}\,1000.
$$

Here $N$ is persons engaged and $a$ is **thousand annual hours per person**.
The multiplication by 1,000 converts units. The 2009 coefficient, already equal
to 2008 in the file, is held through 2014. China employees and their hours are
then set equal to all persons engaged and their hours. The original script
that mapped industries is missing: authenticated table bytes can be reused,
but that mapping cannot yet be regenerated independently from a checked-in
recipe. This distinction matters for reproducibility.

### Rest-of-world employment, hours and capital

`ROW` is an aggregate residual region. Its observed IO flows do not supply
complete labour and capital accounts. The model reads a
[complementary employment total](../complementar/worldbank/employment_row.new.csv)
based on World Bank labour-force and unemployment series. The total is
distributed across industries using ROW value added and the employment
intensity of the explicitly observed countries.

For one year, let $N_R$ be that total, $Y_{Rs}$ ROW value added in industry $s$,
and $N_{Os},H_{Os},Y_{Os}$ the employment, hours and value-added **totals** for
the same industry over observed countries. The construction is:

$$
w_s=Y_{Rs}\frac{N_{Os}}{Y_{Os}},\qquad
N_{Rs}=N_R\frac{w_s}{\sum_u w_u},\qquad
H_{Rs}=N_{Rs}\frac{H_{Os}}{N_{Os}}.
$$

Normalization preserves the external employment total. It does not show that
the estimated sector distribution is observed. The hours formula extrapolates
the observed countries' employment-weighted mean hours for each industry.

The standard method selects a reference country using its lowest nonzero
aggregate capital-per-hour intensity among observed countries; on the pinned
WIOD16 inputs the reference is India. Subject to the explicit zero-denominator
rules below, each ROW industry's capital is:

$$
K_{Rs}=H_{Rs}\frac{K_{qs}}{H_{qs}},
$$

where $q$ is the selected country. This is an extrapolation of capital intensity,
not a direct observation or proof of a country's development status. ROW's
gross-output price index follows the USA's. WIOD16 reconstructs constant-USD
ROW capital from current capital multiplied by the exchange-rate index and
divided by the gross-output price index, both based in 2000.

The public ROW assumption does **not** complete employee counts, employee hours
or compensation. Resulting absences must retain their semantic states. They
also limit the coverage of aggregates involving wages or employee reproduction.
The historical alternative that completes those variables is a different,
non-executable method. See [native assumptions](../scripts/modules/native/assumption_modules.R)
and [ROW capital rules](../scripts/lib/row_capital.R).

## Capital, prices and time comparisons

| Choice | Actual implementation | What remains uncertain |
| --- | --- | --- |
| Capital stock in current USD | WIOD13 uses constant-1995 local stock `K_GFCF`, its `GFCF_P` price index and the current exchange rate; WIOD16 divides current local stock `K` by the current exchange rate. | These releases' stock concepts and sources need a correspondence before comparisons. A stock is not annual investment. |
| Capital composition | EU KLEMS asset weights, the WIOD-to-KLEMS industry mapping, value-added disaggregation shares and the investing country's GFCF supply composition distribute each industry's stock across suppliers. Weights are normalized to conserve the stock. | Contemporary investment supply is used to approximate the composition/origin of an existing stock. It does not identify the vintage or actual origin of each asset. |
| EU KLEMS coverage | Countries without mapped KLEMS coverage use the prepared synthetic mean country `MD`. `GBR`/`GRC` are mapped to `UK`/`EL`. Directly available aggregate depreciation rates take precedence over synthesized component rates. | Mean-country coefficients extrapolate beyond observed countries; conserving a stock does not independently validate its asset composition. |
| Depreciation timing | Stock/composition in year $t$ uses EU KLEMS rates from $t+1$. | This is an explicit timing convention. The final calculation year requires the following year's rates. Zero depreciation is a preserved counterfactual, not a current option. |
| Exchange rate | For each country-year, local-currency value-added totals divided by current-USD value-added totals; one rate is broadcast to all industries. USA is checked against 1. | This is an implicit national conversion rate. Sector-specific exchange rates and averaging country currencies would have a different meaning. |
| Constant money and fixed baskets | The basket reference year is 1995 for WIOD13 and 2000 for WIOD16; output indices are presented relative to 2000. WIOD16 constant capital uses the gross-output price index as a stock deflator proxy. | A presentation base is not the basket's composition year. Constant USD, current USD, hours and purchasing-power-parity units are different measures. A temporal index is not an internationally comparable price level. |

The equations and code locations are in [methodology](methodology-en.md).
For exact base units, use the published `_unit_contract.csv` and the
[indicator dictionary](results-dictionary-en.md), rather than guessing from
historical name suffixes.

There is a further distinction for WIOD13 basket indices: the frozen monetary
shares and source price indices refer to 1995, whereas the exchange-rate index
uses 2000. The mathematical chapter reports that implemented combination
explicitly. Interpreting it as the cost in labour of exactly the same physical
1995 basket requires assessing the price/exchange bases by supplying country,
including imports. Rebasing the final aggregate to 2000 does not on its own
establish that equivalence.

## Exceptional data and numerical rules

These are closed rules for pinned sources. A count summarizes their scope;
it does not authorize treating any new observation the same way. Coordinates,
values and, where specified, fingerprints must also match the contract.

| Rule | Public method and extent | Interpretation and evidence |
| --- | --- | --- |
| Historical missing-to-zero compatibility | WIOD13 preparation retains a pinned historical conversion of missing source entries to zero. Capital coverage deteriorates in 2008–2009. | Finite values can still have incomplete coverage. WLVPanel excludes those two years from all WIOD13 series; this is not a database-wide `NA` mask. See [WIOD13 source contract](wiodr13.md) and published anomaly/coverage metadata. |
| Negative investment used in allocation | 24 WIOD13 and 649 WIOD16 negative GFCF cells are truncated to zero in allocation weights after validation. | Raw source flows remain intact. The choice changes the inferred distribution of capital. `_gfcf_negative_cells.csv` and `_gfcf_negative_summary.csv` allow the transformation to be inspected. |
| Missing positive primary allocation weights | 93 WIOD13 and 120 WIOD16 positive-stock columns use their own country's non-negative GFCF distribution. | This preserves stock totals while substituting a coarser composition. Exact cases are listed by the [WIOD13](wiodr13.md) and [WIOD16](wiodr16.md) contracts. |
| WIOD13 signed capital | The closed `2006/GBR.23` case preserves negative capital and depreciation. | The non-negative productivity argument cannot be used for that year's signed coefficient matrix. The implementation certifies absolute convergence using the absolute coefficient matrix and labels productivity `not_applicable`. |
| WIOD13 nonzero flows with zero output | 3,150 exact coordinates in four Cyprus/Malta sector-year columns are zeroed for the protected coefficient division. | These coefficients are not ordinary measured zeros. New undefined divisions are errors; the [scientific contract](scientific-validation.md) records the exception. |
| WIOD16 negative capital and KLEMS weights | Three Portuguese stock observations are truncated. Of 21 validated negative KLEMS weights in 2010–2015, 19 enter composition years 2010–2014 and are truncated. | Changes are recorded in `_anomalies.csv`. Negative value added is retained; the single Romanian 2007 J58 disaggregation sign is handled explicitly, not by removing all negative value added. |
| WIOD16 employment denominators | 1,914 zero-employee cases also have zero persons engaged and receive zero hours; `2001/MLT/M72` uses Malta's aggregate hours-per-employee ratio. | The lone fallback borrows a national rather than industry-specific work year. It is not a universal replacement for zero denominators. |
| WIOD16 ROW capital denominators | India's zero-hour reference sectors produce 15 explicit ROW M73 zeros and 150 uses of India's aggregate capital-per-hour intensity. | Zero ROW hours produce zero capital; other affected sectors use a broader intensity. The [source contract](wiodr16.md) identifies each group. |
| Linear-system admissibility | Productive dimensions, conditioning, residuals, sign/zero rules and an applicable convergence certificate are checked annually. | A small numerical residual supports a computed solution, not the truth of labour-value theory or the accuracy of imputations. Near-singular systems require diagnosis rather than an arbitrary inverse. |
| Missingness and aggregation | Ordinary `NA` requires `source_missing` or `not_applicable`; unfinished `uncomputed` states cannot be published. Available-component aggregates record partial coverage. Extensive variables sum; intensities and rates follow specified weights or ratios of totals. | `NA` is not zero. A world aggregate with missing components is not evidence of full world coverage. Do not average exploitation rates or sum `WWW` with its constituent countries. |

Machine-readable details are maintained in [contract profiles](../config/contracts),
[missingness policies](../catalog/missingness-policies.csv),
[scientific validation](scientific-validation.md) and [missingness](missingness.md).
They must accompany the values when assessing a result's reliability.

The standard aggregate ratios sum their operands independently; they do not
automatically restrict both sides to observations where both are present.
For example, `WWW` in `surplus_value.emp.r.pc` can include imputed ROW hours
in its numerator without corresponding ROW reproduction costs in its
denominator, because ROW compensation is absent. Aggregate profit likewise
sums capital compensation, depreciation and stock separately: inspect the
coverage of each operand before interpreting a finite ratio as a measure of
one consistently covered population.

## Work still needed

The following is a research and contribution agenda, not a claim that these
capabilities already exist or that their implementation is scheduled.

| Work item | Current boundary | Evidence needed to close it |
| --- | --- | --- |
| Independently reconstruct China's industry mapping | The historical supplementary table is authenticated, but its original mapping script is absent. | A source-to-target correspondence, weighting decisions, reproducible script and comparison with the pinned coefficients. |
| Evaluate labour reduction alternatives | Standard methods use homogeneous hours; alternative definitions are preserved with execution disabled. | A defended multiplier, effects on both created value and reproduction baskets, method-specific units/missingness/contracts, analytic examples and independent comparisons with the 2022 article. |
| Measure sensitivity to imputation and capital treatment | ROW, China, KLEMS mean-country coefficients, GFCF truncation/fallbacks and the signed exception affect estimates. | Explicit alternative assumptions, controlled comparable runs and reports of changes in levels, rankings and rates. Diagnostic sidecars alone are not a completed sensitivity study. |
| Improve WIOD13 late-period coverage | 2008–2009 source coverage limits interpretation even when outputs are finite. | Recovered source evidence or a separately versioned missingness/imputation policy, impact report and agreement with panel coverage. |
| Assess basket indices across currency and price bases | WIOD13 combines 1995 shares/source price indices with a 2000 exchange-rate index. | An independent fixed-quantity derivation by supplying country, comparison with the implemented index and a sensitivity assessment of imported basket components before asserting exact physical-basket equivalence. |
| Add other IO sources | EXIOBASE and EORA are disabled; [issue #14](https://github.com/rodrigofranklin/wlvdb/issues/14) records the deferred expansion. | Pinned sources and licenses, explicit labour units and capital policy, schemas, analytic fixtures, full calculation/recalculation/publication evidence and justified cross-source comparability. |
| Extend what dependency measures cover | Current trade transfers do not identify all interest, dividends, rents, ownership relations or political subordination. | Additional data and clearly defined mechanisms; distinguish new measures from the current trade-transfer indicator. |
| Strengthen empirical validation | Internal identities, analytical fixtures and historical parity validate important parts of implementation. | Independently reconstructed estimates and external/source comparisons, with discrepancies explained. Agreement with historical output alone cannot prove the model's economic assumptions. |

To propose one of these changes, follow the
[contribution walkthrough](guide-en.md#contribute-an-improvement).
Record the exact method, code commit, input provenance, units and assumptions
when reporting results. The [reference guide](references-en.md) explains how
to distinguish the supplied studies from the current software implementation.
