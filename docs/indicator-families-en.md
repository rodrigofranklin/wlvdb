# Indicator-family cards

<!-- documentation-revision: wiod-reader-workflows-v2 -->

[Português](indicator-families-pt.md) | English | [Use the data](use-results-en.md) | [Dictionary](results-dictionary-en.md) | [Mathematics](methodology-en.md)

These cards help select and interpret measures. The dictionary gives each
method's exact identifiers; `_unit_contract.csv` governs a run's units,
display and aggregation. Numerical examples below are **hypothetical**, not
WIOD results. Formulas summarize cases with defined operands; zeros,
missingness and partial coverage follow the contracts.

## 1. Persons, hours and abstract labour

**Question.** How many people participate in an activity, how many hours do
they work, and how do those hours enter the model's labour measure?

`emp.s.un` counts persons engaged; `empe.s.un` restricts to employees.
`hours_worked.*.s.hr` records annual hours. The reduction multiplier converts
hours into operational abstract labour: $L_j=z_jH_j$. Both current methods
use $z_j=1$; numerical equality does not remove the conceptual distinction.
The `abstract_labour.*.m.mv` variants divide annual labour by the corresponding
population.

**Example.** Ten employees working 18,000 annual hours, with weight 1,
correspond to 1,800 abstract hours per employee per year. To aggregate two
industries, sum hours and persons before dividing; do not give equal weight
to industries employing 10 and 1,000 people.

**What it does not measure.** Annual labour per person is not daily working
time. Abstract labour including unproductive industries is not the productive
new-value aggregate. `emp` and `empe` are not interchangeable populations.

**Before use.** Check the Chinese employee/persons-engaged approximation,
imputed ROW hours and counts, denominator coverage and hour weights. See
[labour and rest-of-world assumptions](assumptions-en.md).

## 2. Gross output, new value and direct prices

**Question.** How much was produced, how much labour is required across
production chains, and how much new productive labour occurred during the year?

`gross_output.s.us` measures monetary gross output; `gdp.s.us` measures monetary
value added. `value.m.mv` is $\lambda$, direct and indirect productive labour
per USD. Multiplying each supplier's deliveries by its coefficient produces
`values`; the sum of its sales gives `gross_output.s.mv`. `gdp.s.mv` records
direct labour of persons engaged in productive industries.

**Example.** If flour requires 2 hours and baking adds 1, bread requires 3 hours.
Adding flour and bread in gross output gives 5 hours, while final bread requires
3 throughout the chain. Embodied gross output and new value are different
objects even when both are expressed in hours.

For direct prices, $\mu=\sum x/\sum V^{GO}$ converts labour values into USD.
`gross_output.s.du` and `gdp.s.du` use this common numeraire. The normalization
preserves world monetary gross output, not equality between each market price
and direct price or between the two GDP totals.

**What it does not measure.** A direct price is not an observed price, price
of production, exchange rate, purchasing-power parity or deflator. Summing
embodied values across all intermediate products does not measure only new labour.

**Before use.** Check current/constant prices, productive classification,
units, aggregation and matrix coverage. Aggregate intensity is the ratio of
value and output totals, not an arithmetic mean of coefficients. See the
[derivation and the two normalizations](methodology-en.md).

## 3. Reproduction value and surplus-value rates

**Question.** How does performed labour compare with labour embodied in the
basket financed by the selected population's compensation?

For employees, `labour_force_value.s.mv` estimates $v$ from compensation and
national consumption composition; for all persons engaged, use
`labour_force_value.emp.s.mv`. Per-person averages divide by the correct count.
The rate is $e=L/v-1$, with both operands in labour units.

| Indicator | Population and scope |
| --- | --- |
| `surplus_value.empe_p.r.pc` | Employees in productive industries. |
| `surplus_value.empe.r.pc` | Employees, including unproductive industries. |
| `surplus_value.emp_p.r.pc` | Persons engaged in productive industries, including non-employees. |
| `surplus_value.emp.r.pc` | Persons engaged, including non-employees and unproductive industries. |
| `surplus_value.empe_hs.r.pc`, `surplus_value.empe_ms.r.pc`, `surplus_value.empe_ls.r.pc` | WIOD13 skill variants; full codes are in the dictionary. |

**Example.** Two industries with labour of 100 and 300 and reproduction values
of 50 and 100 have rates of 100% and 200%. The aggregate rate is $400/150-1$,
approximately 166.67%, not the arithmetic mean of 150%. The contract stores
the ratio before percentage display. A missing denominator is not zero
reproduction cost.

**What it does not measure.** The compensation-financed basket is not an
independent observation of a normative subsistence minimum. A high rate alone
does not establish superexploitation, working-day duration, physical
productivity or a profit rate. The persons-engaged variant has a broader
interpretation than a measure exclusive to the capitalist wage relation.

**Before use.** Check the common national basket assumption, population,
productive filter and each operand's coverage. A productive industry rate
zeroed outside scope expresses a model mask, not observed absence of
exploitation. Skill-specific hour and compensation shares do not change
standard equal hour weights. For `WWW`, examine ROW and
[sums with different operand coverage](use-results-en.md#compare-ratios-on-common-coverage).

## 4. Capital, depreciation and accounting profitability

**Question.** What is estimated capital stock, how much depreciates during
the year, and how does net capital compensation compare with that stock?

`capital_stock.s.us` measures stock in current USD. `k_composition` allocates
stock by asset suppliers and users; a column sum recovers the user's stock.
`k_depreciation` allocates annual depreciation; `capital_depreciation.s.us`
sums it by user.

`appropriated_profit.r.pc` applies $r^{app}=(\Pi-D)/K$, using monetary capital
compensation, estimated depreciation and fixed capital stock.

**Example.** Capital compensation of USD 30, depreciation of USD 10 and stock
of USD 100 yield a ratio of 0.20, displayed as 20%. Aggregation requires
summing the relevant components before dividing. A zero denominator is not
zero profitability.

**What it does not measure.** Stock is not annual investment, and depreciation
is not the full stock. Composition is estimated, not each purchase's observed
history. Accounting profitability does not implement the Marxian rate
$s/(c+v)$ and should not be named as such.

**Before use.** Check KLEMS composition, the average-country profile, fallback
weights, following-year depreciation convention, signed exceptions and WIOD13
coverage loss in 2008–2009. Accounting-rate operands are also aggregated
separately and need coverage review. See [capital and exceptional rules](assumptions-en.md).

## 5. Baskets, indices, constant compensation and exchange rates

**Question.** How do prices and labour content of a reference basket change
over time, and how is compensation deflated under that convention?

`basket_price.r.pc` and `basket_value.r.pc` are national price and labour-content
indices of the implemented basket. Weight years are 1995 for WIOD13 and 2000
for WIOD16; published indices have base 2000 = 1. A stored index of 1 appears
as 1 for WIOD13 and 100 points for WIOD16 under the contract.
`compensation.*.s.cu` means compensation in constant 2000 USD despite `.cu`.
`exchange.r.us` is local currency per USD; `exchange.r.id` is its base-2000 index.

**Example.** An index moving from 1 to 1.2 rises 20% relative to the base.
Two countries with index 1 in 2000 do not thereby have the same cost of living.
Adding national indices does not produce a comparable world index.

**What it does not measure.** A temporal index is not an international price
level, purchasing-power parity or the basket's nominal cost. Local-currency
appreciation against the dollar is not the same as an increase in the
local-currency-per-USD index. Deflated compensation is not labour value.

**Before use.** WIOD13's 1995 source weights/prices and 2000 exchange-rate
index require the methodological evaluation described in the mathematical
chapter. Do not interpret the implemented index as an already demonstrated
exact physical reproduction of a fixed 1995 basket. Final rebasing alone does
not resolve that question. WIOD16 constant capital also uses its own approximate
deflator. See [baskets and bases](methodology-en.md) and preserve the qualification
in conclusions.

## 6. Trade, transfers and appropriation

**Question.** How much labour is embodied in trade, and what transfer is
estimated when that content is compared with value represented by payments?

`exports.s.us` and `imports.s.us` measure monetary flows; `.mv` versions measure
embodied labour. `trade_balance` is exports minus imports. An outward-flow
transfer is $\tau_{ij}=T_{ij}(\beta M_{ij}-V_{ij})$; the country balance is
$\Delta_c=\beta(X_c^{USD}-M_c^{USD})-(X_c^V-M_c^V)$. **A positive national
balance means net receipt**. Trade factor $\beta$ is generally not the inverse
of production direct-price numeraire $\mu$.

**Example.** A country exporting 100 hours and importing 150 for the same
monetary amount receives 50 net hours in this example. With a monetary
imbalance, the hour difference alone does not isolate the transfer: the
expression above includes a trade-balance correction.

`trade_transfers.p.s.mv` restricts supplying products to the productive scope;
`.u.s.mv` is total minus productive. `trade_transfers.p.m.pc` divides productive
transfers by `gdp.s.mv`, not monetary GDP. Bilateral matrices retain origin ×
destination. Industry imports group the supplied product's industry and the
receiving country, including final demand, not just the purchasing industry.

**What it does not measure.** The indicator alone does not identify the
transfer's cause or every channel of dependence, such as interest, dividends
and ownership relations. The sum of country balances, which cancels by
accounting, is not the sum of bilateral transfer cells. Productive cells are
normalized to sum to zero; total cells need not do so, because they include
unproductive suppliers with zero modelled value.

**Before use.** Check sign, orientation, productive component, denominator,
unit and coverage. Do not add `WWW` to countries. Examine whether rankings
and conclusions are robust to labour and capital imputations. See
[trade methodology](methodology-en.md) and [theoretical limits](theory-en.md).
