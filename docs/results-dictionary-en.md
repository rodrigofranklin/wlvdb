# Results dictionary

<!-- documentation-revision: wiod-reader-workflows-v2 -->

[Português](results-dictionary-pt.md) | [English guide](guide-en.md) | [Use data](use-results-en.md) | [Cards](indicator-families-en.md)

This dictionary covers every indicator published by `wiodr13` (1995–2009) and `wiodr16` (2000–2014). Tables are generated from v2 contracts and reviewed economic descriptions. Each row applies to `sea_sectors` and `sea_countries`, except for the world absence indicated in the aggregation column. Countries and sectors follow each run's labels: the sources do not have identical classifications or geographic coverage.

Units describe storage after normalization: USD, persons and hours, with no implicit millions or thousands. USD means United States dollar. Unqualified USD means current prices. `×100` is applied exactly once for display, never in calculation. A stored rate of 0.25 appears as 25%. Skill shares remain ratios (0.25) in the contract despite their `.pc` suffix. Index 1 appears as 1 in WIOD13 and as 100 points in WIOD16, according to display_multiplier.

`NA` means justified absence, not zero. Consult `_states.csv` to distinguish `source_missing` (absent in the source) from `not_applicable` (undefined operation). National exchange rates and indices have no comparable world aggregate. Zero denominators or weights make the corresponding ratios or averages not applicable. Available components can produce partial-coverage aggregates recorded in `_anomalies.csv`: inspect that report before comparing countries. Do not fill missing values with zero. WIOD13 loses capital coverage in 2008–2009: historical preparation converts pinned absences to compatibility zeros, and WLVPanel excludes those years from all series. Database files can still contain finite values in those years.

The aggregation column gives sector → country / country → world. Weighted means show their weight in parentheses. For formulas, the description explains numerator and denominator: national and world rates use the relevant totals, not an average of sector rates. Each run's effective contract is `_unit_contract.csv`, which governs historical files.

Assumptions about productive labour, equal hours, the rest of the world, China, capital, baskets and trade are in the [guide](guide-en.md#methodology). Appropriated profit is not the Marxian profit rate, and modelled transfers alone do not identify a causal relationship. For v1 → v2 changes, compare contracts rather than simply joining series.

## wiodr13 — 58 indicators

| Identifier | Economic meaning | Stored unit | Display | Aggregation: country / world |
| --- | --- | --- | --- | --- |
| `emp.s.un` | Persons engaged, including employees and self-employed workers. | persons | no additional scaling | sum / sum |
| `empe.s.un` | Wage and salaried employees. | persons | no additional scaling | sum / sum |
| `hours_worked.emp.s.hr` | Annual hours worked by all persons engaged. | hours | no additional scaling | sum / sum |
| `hours_worked.empe.s.hr` | Annual employee hours. | hours | no additional scaling | sum / sum |
| `compensation.empe_hs.r.pc` | High-skill share of employee compensation. | ratio | no additional scaling | weighted mean (`compensation.empe.s.us`) / weighted mean (`compensation.empe.s.us`) |
| `compensation.empe_ms.r.pc` | Medium-skill share of employee compensation. | ratio | no additional scaling | weighted mean (`compensation.empe.s.us`) / weighted mean (`compensation.empe.s.us`) |
| `compensation.empe_ls.r.pc` | Low-skill share of employee compensation. | ratio | no additional scaling | weighted mean (`compensation.empe.s.us`) / weighted mean (`compensation.empe.s.us`) |
| `hours_worked.empe_hs.r.pc` | High-skill share of employee hours. | ratio | no additional scaling | weighted mean (`hours_worked.empe.s.hr`) / weighted mean (`hours_worked.empe.s.hr`) |
| `hours_worked.empe_ms.r.pc` | Medium-skill share of employee hours. | ratio | no additional scaling | weighted mean (`hours_worked.empe.s.hr`) / weighted mean (`hours_worked.empe.s.hr`) |
| `hours_worked.empe_ls.r.pc` | Low-skill share of employee hours. | ratio | no additional scaling | weighted mean (`hours_worked.empe.s.hr`) / weighted mean (`hours_worked.empe.s.hr`) |
| `gross_output.s.us` | Gross output at market prices (GO_USD), including intermediate consumption: this is not GDP. | USD | no additional scaling | sum / sum |
| `gdp.s.us` | Value added (VA_USD), summing to GDP by the production approach. | USD | no additional scaling | sum / sum |
| `go_price.r.id` | Sector gross-output price index, rebased to 2000. | index (2000 = 1) | no additional scaling | weighted mean (`gross_output.s.us`) / NA |
| `exchange.r.us` | Local-currency units per dollar: national value added in local currency divided by its USD total. Identical across the country's sectors. | local currency/USD | no additional scaling | common national value / NA |
| `compensation.empe.s.us` | Employee compensation (COMP), converted at the national exchange rate. | USD | no additional scaling | sum / sum |
| `compensation.emp.s.us` | Labour compensation of all persons engaged (LAB), including imputed non-employee labour income. | USD | no additional scaling | sum / sum |
| `capital_stock.s.us` | Capital asset stock at current prices. WIOD13 combines K_GFCF and GFCF_P, WIOD16 uses K, with the documented exceptions. | USD | no additional scaling | sum / sum |
| `profit.s.us` | Capital compensation (CAP), including profit and other capital income: not a direct observation of surplus value. | USD | no additional scaling | sum / sum |
| `exchange.r.id` | National exchange rate divided by its 2000 level. An increase means more local currency per USD. | index (2000 = 1) | no additional scaling | common national value / NA |
| `complex_labour_multiplier.empe.r.un` | Factor applied to employee hours. Equals 1 in both current methods: every hour receives equal weight. | multiplier | no additional scaling | weighted mean (`hours_worked.empe.s.hr`) / weighted mean (`hours_worked.empe.s.hr`) |
| `complex_labour_multiplier.emp.r.un` | Factor applied to all-persons-engaged hours. Equals 1 in both current methods. | multiplier | no additional scaling | weighted mean (`hours_worked.emp.s.hr`) / weighted mean (`hours_worked.emp.s.hr`) |
| `gdp.p.s.us` | USD value added in productive sectors only. Zero in other sectors under the economic filter. | USD | no additional scaling | sum / sum |
| `abstract_labour.empe.s.mv` | Employee hours multiplied by the complex-labour factor. Includes productive and unproductive sectors. | abstract hours | no additional scaling | sum / sum |
| `abstract_labour.emp.s.mv` | All-persons-engaged hours multiplied by the complex-labour factor. | abstract hours | no additional scaling | sum / sum |
| `gdp.s.mv` | Abstract labour of all persons engaged in industries classified as productive. Other industries receive zero under the economic filter. | abstract hours | no additional scaling | sum / sum |
| `basket_price.r.pc` | National price index of the fixed consumption basket, rebased to 2000. Reference basket: 1995 for WIOD13, 2000 for WIOD16. | index (2000 = 1) | no additional scaling | common national value / NA |
| `basket_value.r.pc` | National labour-content index of the fixed monetary-share basket, rebased to 2000. Exact equivalence with a fixed physical basket requires evaluating WIOD13 price and exchange-rate bases. | index (2000 = 1) | no additional scaling | common national value / NA |
| `gross_output.s.mv` | Total productive labour embodied in gross output, directly and indirectly, from row sums of the values matrix. | abstract hours | no additional scaling | sum / sum |
| `labour_force_value.s.mv` | Value of the consumption basket financed by employee compensation, used as an estimate of variable capital. | abstract hours | no additional scaling | sum / sum |
| `value.m.mv` | Productive labour embodied per USD of gross output: lambda at sector level, ratio of totals at aggregate levels. | abstract hours/USD | no additional scaling | ratio of totals / ratio of totals |
| `capital_depreciation.s.us` | Annual depreciation of allocated capital, summed by column of k_depreciation. | USD | no additional scaling | sum / sum |
| `trade_transfers.s.mv` | Net trade transfer: value represented by prices minus embodied labour, exports minus imports. Positive means net receipt. | abstract hours | no additional scaling | sum / sum |
| `trade_transfers.p.s.mv` | Productive component of net trade transfers. Its world sum is zero within tolerance. | abstract hours | no additional scaling | sum / sum |
| `exports.s.us` | Sales to other countries, including final demand, at market prices. | USD | no additional scaling | sum / sum |
| `exports.s.mv` | Productive labour embodied in exports. | abstract hours | no additional scaling | sum / sum |
| `imports.s.us` | Purchases from other countries at market prices. Sector results group by the imported good's sector and purchasing country. | USD | no additional scaling | sum / sum |
| `imports.s.mv` | Productive labour embodied in imports, grouped as for USD imports. | abstract hours | no additional scaling | sum / sum |
| `labour_force_value.emp.s.mv` | Labour embodied in the basket financed by all-persons-engaged compensation, including non-employees. | abstract hours | no additional scaling | sum / sum |
| `surplus_value.empe_hs.r.pc` | Employee abstract labour weighted by the high-skill hours share, divided by labour-force value weighted by the corresponding compensation share, minus 1. | ratio | ×100 % | described formula / described formula |
| `surplus_value.empe_ms.r.pc` | Skill-specific surplus-value formula using medium-skill hours and compensation shares. | ratio | ×100 % | described formula / described formula |
| `surplus_value.empe_ls.r.pc` | Skill-specific surplus-value formula using low-skill hours and compensation shares. | ratio | ×100 % | described formula / described formula |
| `compensation.emp.s.cu` | All-persons-engaged compensation, deflated by the basket index and converted at the 2000 exchange rate. The cu suffix does not mean local-currency storage here. | USD at constant 2000 prices | no additional scaling | sum / sum |
| `compensation.empe.s.cu` | Employee compensation deflated by the basket index and converted at the 2000 exchange rate. | USD at constant 2000 prices | no additional scaling | sum / sum |
| `gdp.s.du` | GDP in productive hours converted by the world ratio of gross output in USD to gross output in hours. Modelled direct price. | USD | no additional scaling | sum / sum |
| `gross_output.s.du` | Gross output in hours converted by the same world USD-per-hour factor, preserving the world USD total. | USD | no additional scaling | sum / sum |
| `surplus_value.empe.r.pc` | Employee abstract labour divided by labour-force value, minus 1. Includes productive and unproductive sectors. | ratio | ×100 % | described formula / described formula |
| `labour_force_value.m.mv` | Labour-force value divided by employees: average annual reproduction cost in hours. | abstract hours/person | no additional scaling | described formula / described formula |
| `trade_transfers.u.s.mv` | Total transfer minus the productive component. This is an exports-minus-imports balance, distinct from summing bilateral matrix cells. | abstract hours | no additional scaling | sum / sum |
| `abstract_labour.empe.m.mv` | Annual employee abstract labour divided by employee count. This is not the length of one working day. | abstract hours/person | no additional scaling | described formula / described formula |
| `abstract_labour.emp.m.mv` | Annual all-persons-engaged abstract labour divided by their count. | abstract hours/person | no additional scaling | described formula / described formula |
| `trade_balance.s.us` | Exports minus imports in USD. | USD | no additional scaling | sum / sum |
| `trade_balance.s.mv` | Exports minus imports in embodied labour. | abstract hours | no additional scaling | sum / sum |
| `appropriated_profit.r.pc` | Capital compensation minus depreciation, divided by capital stock. An accounting profitability approximation, distinct from surplus value divided by constant plus variable capital. | ratio | ×100 % | described formula / described formula |
| `trade_transfers.p.m.pc` | Productive trade transfers divided by productive abstract labour (gdp.s.mv). Measures transfers relative to newly produced value. | ratio | ×100 % | described formula / described formula |
| `labour_force_value.emp.m.mv` | All-persons-engaged basket value divided by persons engaged. | abstract hours/person | no additional scaling | described formula / described formula |
| `surplus_value.emp.r.pc` | All-persons-engaged abstract labour divided by their basket value, minus 1. Includes non-employees and unproductive sectors. | ratio | ×100 % | described formula / described formula |
| `surplus_value.emp_p.r.pc` | All-persons-engaged rate restricted to productive industries. Aggregates use a ratio of totals, minus 1. | ratio | ×100 % | described formula / described formula |
| `surplus_value.empe_p.r.pc` | Employee rate restricted to productive industries. Aggregates use a ratio of totals, minus 1. | ratio | ×100 % | described formula / described formula |

## wiodr16 — 50 indicators

| Identifier | Economic meaning | Stored unit | Display | Aggregation: country / world |
| --- | --- | --- | --- | --- |
| `emp.s.un` | Persons engaged, including employees and self-employed workers. | persons | no additional scaling | sum / sum |
| `empe.s.un` | Wage and salaried employees. | persons | no additional scaling | sum / sum |
| `hours_worked.empe.s.hr` | Annual employee hours. | hours | no additional scaling | sum / sum |
| `gross_output.s.us` | Gross output at market prices (GO_USD), including intermediate consumption: this is not GDP. | USD | no additional scaling | sum / sum |
| `gdp.s.us` | Value added (VA_USD), summing to GDP by the production approach. | USD | no additional scaling | sum / sum |
| `hours_worked.emp.s.hr` | Annual hours worked by all persons engaged. | hours | no additional scaling | sum / sum |
| `exchange.r.us` | Local-currency units per dollar: national value added in local currency divided by its USD total. Identical across the country's sectors. | local currency/USD | no additional scaling | common national value / NA |
| `go_price.r.id` | Sector gross-output price index, rebased to 2000. | index (2000 = 1) | ×100 points | weighted mean (`gross_output.s.us`) / NA |
| `compensation.empe.s.us` | Employee compensation (COMP), converted at the national exchange rate. | USD | no additional scaling | sum / sum |
| `compensation.emp.s.us` | Labour compensation of all persons engaged (LAB), including imputed non-employee labour income. | USD | no additional scaling | sum / sum |
| `capital_stock.s.us` | Capital asset stock at current prices. WIOD13 combines K_GFCF and GFCF_P, WIOD16 uses K, with the documented exceptions. | USD | no additional scaling | sum / sum |
| `profit.s.us` | Capital compensation (CAP), including profit and other capital income: not a direct observation of surplus value. | USD | no additional scaling | sum / sum |
| `capital_stock.s.cu` | Capital stock in constant 2000 USD, deflated by the output-price index and converted at the 2000 exchange rate. | USD at constant 2000 prices | no additional scaling | sum / sum |
| `exchange.r.id` | National exchange rate divided by its 2000 level. An increase means more local currency per USD. | index (2000 = 1) | ×100 points | common national value / NA |
| `complex_labour_multiplier.empe.r.un` | Factor applied to employee hours. Equals 1 in both current methods: every hour receives equal weight. | multiplier | no additional scaling | weighted mean (`hours_worked.empe.s.hr`) / weighted mean (`hours_worked.empe.s.hr`) |
| `complex_labour_multiplier.emp.r.un` | Factor applied to all-persons-engaged hours. Equals 1 in both current methods. | multiplier | no additional scaling | weighted mean (`hours_worked.emp.s.hr`) / weighted mean (`hours_worked.emp.s.hr`) |
| `gdp.p.s.us` | USD value added in productive sectors only. Zero in other sectors under the economic filter. | USD | no additional scaling | sum / sum |
| `abstract_labour.empe.s.mv` | Employee hours multiplied by the complex-labour factor. Includes productive and unproductive sectors. | abstract hours | no additional scaling | sum / sum |
| `abstract_labour.emp.s.mv` | All-persons-engaged hours multiplied by the complex-labour factor. | abstract hours | no additional scaling | sum / sum |
| `gdp.s.mv` | Abstract labour of all persons engaged in industries classified as productive. Other industries receive zero under the economic filter. | abstract hours | no additional scaling | sum / sum |
| `basket_price.r.pc` | National price index of the fixed consumption basket, rebased to 2000. Reference basket: 1995 for WIOD13, 2000 for WIOD16. | index (2000 = 1) | ×100 points | common national value / NA |
| `basket_value.r.pc` | National labour-content index of the fixed monetary-share basket, rebased to 2000. Exact equivalence with a fixed physical basket requires evaluating WIOD13 price and exchange-rate bases. | index (2000 = 1) | ×100 points | common national value / NA |
| `gross_output.s.mv` | Total productive labour embodied in gross output, directly and indirectly, from row sums of the values matrix. | abstract hours | no additional scaling | sum / sum |
| `labour_force_value.s.mv` | Value of the consumption basket financed by employee compensation, used as an estimate of variable capital. | abstract hours | no additional scaling | sum / sum |
| `value.m.mv` | Productive labour embodied per USD of gross output: lambda at sector level, ratio of totals at aggregate levels. | abstract hours/USD | no additional scaling | ratio of totals / ratio of totals |
| `capital_depreciation.s.us` | Annual depreciation of allocated capital, summed by column of k_depreciation. | USD | no additional scaling | sum / sum |
| `trade_transfers.s.mv` | Net trade transfer: value represented by prices minus embodied labour, exports minus imports. Positive means net receipt. | abstract hours | no additional scaling | sum / sum |
| `trade_transfers.p.s.mv` | Productive component of net trade transfers. Its world sum is zero within tolerance. | abstract hours | no additional scaling | sum / sum |
| `exports.s.us` | Sales to other countries, including final demand, at market prices. | USD | no additional scaling | sum / sum |
| `exports.s.mv` | Productive labour embodied in exports. | abstract hours | no additional scaling | sum / sum |
| `imports.s.us` | Purchases from other countries at market prices. Sector results group by the imported good's sector and purchasing country. | USD | no additional scaling | sum / sum |
| `imports.s.mv` | Productive labour embodied in imports, grouped as for USD imports. | abstract hours | no additional scaling | sum / sum |
| `labour_force_value.emp.s.mv` | Labour embodied in the basket financed by all-persons-engaged compensation, including non-employees. | abstract hours | no additional scaling | sum / sum |
| `compensation.emp.s.cu` | All-persons-engaged compensation, deflated by the basket index and converted at the 2000 exchange rate. The cu suffix does not mean local-currency storage here. | USD at constant 2000 prices | no additional scaling | sum / sum |
| `compensation.empe.s.cu` | Employee compensation deflated by the basket index and converted at the 2000 exchange rate. | USD at constant 2000 prices | no additional scaling | sum / sum |
| `gdp.s.du` | GDP in productive hours converted by the world ratio of gross output in USD to gross output in hours. Modelled direct price. | USD | no additional scaling | sum / sum |
| `gross_output.s.du` | Gross output in hours converted by the same world USD-per-hour factor, preserving the world USD total. | USD | no additional scaling | sum / sum |
| `surplus_value.empe.r.pc` | Employee abstract labour divided by labour-force value, minus 1. Includes productive and unproductive sectors. | ratio | ×100 % | described formula / described formula |
| `labour_force_value.m.mv` | Labour-force value divided by employees: average annual reproduction cost in hours. | abstract hours/person | no additional scaling | described formula / described formula |
| `trade_transfers.u.s.mv` | Total transfer minus the productive component. This is an exports-minus-imports balance, distinct from summing bilateral matrix cells. | abstract hours | no additional scaling | sum / sum |
| `abstract_labour.empe.m.mv` | Annual employee abstract labour divided by employee count. This is not the length of one working day. | abstract hours/person | no additional scaling | described formula / described formula |
| `abstract_labour.emp.m.mv` | Annual all-persons-engaged abstract labour divided by their count. | abstract hours/person | no additional scaling | described formula / described formula |
| `trade_balance.s.us` | Exports minus imports in USD. | USD | no additional scaling | sum / sum |
| `trade_balance.s.mv` | Exports minus imports in embodied labour. | abstract hours | no additional scaling | sum / sum |
| `appropriated_profit.r.pc` | Capital compensation minus depreciation, divided by capital stock. An accounting profitability approximation, distinct from surplus value divided by constant plus variable capital. | ratio | ×100 % | described formula / described formula |
| `trade_transfers.p.m.pc` | Productive trade transfers divided by productive abstract labour (gdp.s.mv). Measures transfers relative to newly produced value. | ratio | ×100 % | described formula / described formula |
| `labour_force_value.emp.m.mv` | All-persons-engaged basket value divided by persons engaged. | abstract hours/person | no additional scaling | described formula / described formula |
| `surplus_value.emp.r.pc` | All-persons-engaged abstract labour divided by their basket value, minus 1. Includes non-employees and unproductive sectors. | ratio | ×100 % | described formula / described formula |
| `surplus_value.emp_p.r.pc` | All-persons-engaged rate restricted to productive industries. Aggregates use a ratio of totals, minus 1. | ratio | ×100 % | described formula / described formula |
| `surplus_value.empe_p.r.pc` | Employee rate restricted to productive industries. Aggregates use a ratio of totals, minus 1. | ratio | ×100 % | described formula / described formula |

Generated by `scripts/render_results_dictionary.R`. Edit source descriptions and contracts, regenerate both languages and run `--check`. See the [synchronization convention](documentation-sync.md).
