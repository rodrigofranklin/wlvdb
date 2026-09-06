# Mathematical methodology

<!-- documentation-revision: wiod-reader-workflows-v2 -->

[Português](methodology-pt.md) · [Theory](theory-en.md) · [Assumptions and open work](assumptions-en.md) · [Practical guide](guide-en.md) · [ABNT references](references-en.md)

Documentation revision: `wiod-reader-workflows-v2`.

This chapter follows the **currently executable `wiodr13` and `wiodr16` methods**. It translates the native calculation into equations and a small example. The article by Franklin et al. (2022, p. 370–375) explains the common input-output framework and compares several reductions of skilled labour; Franklin (2025, p. 190–200) develops the international application. Their research alternatives are not all executable methods in this release. In particular, the standard methods use equal labour-hour multipliers and national consumption baskets. See the [method catalog](methods.md) for support status.

| Source-to-code distinction | Consequence for reproduction |
| --- | --- |
| Franklin et al. (2022, note 21, p. 386–387) exclude hotels/restaurants and other community/social/personal services; current [WIOD13 classification](../methods/wiodr13/_sectors.csv) includes `H` and `O` as productive | Current WIOD13 has 25 productive industries per region (1,025 positions), rather than the article's 23 (943 positions). The article's exact numerical tables require its historical classification and other assumptions. |
| The book's simplified empirical equations omit depreciation, while the current runtime includes it | Do not copy the simplified equation as a complete account of the current calculation. |
| The article compares several labour reductions; current stable methods set both multipliers to 1 | Agreement with its equal-hours assumption does not establish full historical-method equivalence. |

## 1. Read the table before reading the equation

For one year, an industry is a **country–sector pair**. A Brazilian steel industry and a German steel industry occupy different rows. The worldwide table records both domestic and international production links. Rows supply goods or services; columns use them. Industry columns are followed by final-demand columns.

| Symbol | Meaning | Unit / shape |
| --- | --- | --- |
| $M_{ij}$ | Monetary sale from supplier $i$ to industry or final-demand destination $j$ | Current USD; full supply–use array for a year |
| $Z$ | Intermediate industry-to-industry block of $M$ | Current USD; $n\times n$ |
| $x_j$ | Gross output of industry $j$ | Current USD |
| $H_j$, $H_j^e$ | Annual hours of all persons engaged, or employees only | Hours |
| $z_j$, $z_j^e$ | Labour complexity/intensity multipliers | Dimensionless; both are 1 in standard methods |
| $P$ | Set of industries classified as productive | Classification, not a monetary observation |
| $k_j$, $K_{ij}$ | Capital stock of user $j$; stock allocated to supplying industry $i$ | Current USD; vector and $n\times n$ matrix |
| $D_{ij}$ | Annual depreciation of that allocated stock | Current USD over the accounting year |
| $\lambda_j$ | Direct and indirect productive labour embodied per USD of output | Labour-value units per USD; `.mv/USD` |
| $b_{ic}$ | Share of supplier $i$ in country $c$'s consumption basket | Dimensionless |
| $W_j$, $v_j$ | Employee compensation in money; its basket equivalent in labour value | Current USD; labour-value units |

Here **$D$ is a depreciation flow matrix**, matching `k_depreciation`. The article uses $D$ for depreciation *coefficients*. Below, $d=D\,\mathrm{diag}(x)^{-1}$ denotes those coefficients. Keeping this distinction avoids adding a stock or an unscaled flow to a coefficient matrix.

The source generation is normalized before calculation: money is in currency units, labour in hours, and employment in persons, rather than the provider's millions/thousands. A stored `.mv` unit has the numerical scale of an hour under $z=1$, but its theoretical meaning depends on the productive classification and reduction assumption. The [unit contracts](units.md), including `_normalization_contract.csv` and `_unit_contract.csv`, are authoritative. The full WIOD13 industry system has 1,435 pairs; WIOD16 has 2,464. The solve uses their productive subset.

WIOD13 supplies total hours of persons engaged. WIOD16 normally derives them as `H_EMPE / EMPE * EMP`, assuming the same average annual hours for employees and other persons engaged in a sector. China, ROW and exactly registered zero-denominator cases require the additional treatments described in [the assumptions](assumptions-en.md).

## 2. From observed money flows to total labour requirements

First compute input coefficients by **dividing each column by its user's output**:

$$
A_{ij}=\frac{Z_{ij}}{x_j},\qquad d_{ij}=\frac{D_{ij}}{x_j},\qquad C=A+d.
$$

Thus $A_{ij}=0.2$ means that USD 1 of output in industry $j$ uses USD 0.20 of intermediate output from $i$. It does not mean 0.2 physical tonnes. For the productive block, direct labour requirements are

$$
\ell_j=\frac{H_jz_j}{x_j},\quad j\in P.
$$

One unit of output embodies its direct labour plus the labour required to reproduce its inputs. With labour requirements written as a row vector,

$$
\lambda_P=\ell_P+\lambda_PC_{PP},\qquad
\lambda_P=\ell_P(I-C_{PP})^{-1}.
$$

The implementation solves the equivalent column-vector system

$$
(I-C_{PP})^\mathsf T\lambda_P^\mathsf T=\ell_P^\mathsf T
$$

without explicitly constructing an inverse. Industries outside $P$ receive $\lambda_j=0$ in this method. This excludes their rows and columns from the value-producing system; merely setting their direct hours to zero while retaining the full matrix would be a different model.

For nonnegative $C_{PP}$ with spectral radius $\rho(C_{PP})<1$,

$$
\lambda_P=\ell_P+\ell_PC_{PP}+\ell_PC_{PP}^2+\cdots.
$$

These are direct labour, labour in the immediate inputs, labour in the inputs of those inputs, and so on. Each successive term accounts for another production round. This is why the inverse is meaningful economically under its assumptions, rather than just a convenient matrix operation.

Using money accounts does not require the assumption that observed prices already equal labour values. In the ideal case of a coherent physical table, let $Q$ be physical deliveries, $q$ physical output and $p_i>0$ the price per physical unit of product $i$. Then $Z=\mathrm{diag}(p)Q$, $x=\mathrm{diag}(p)q$, and monetary coefficients are a change of units of physical coefficients. The corresponding labour coefficient is physical labour value divided by $p_i$. Real country–industry aggregates approximate this case: differences in product mix, valuation and aggregation remain empirical limitations. Matrix algebra does not remove them.

More explicitly, write $S=\mathrm{diag}(p)$, with superscripts $m$ and $q$ for monetary and physical units. For inputs and depreciation valued on the same coherent basis,

$$
C^m=SC^qS^{-1},\qquad \ell^m=\ell^qS^{-1},
$$

$$
\lambda^m=\ell^qS^{-1}(I-SC^qS^{-1})^{-1}
=\ell^q(I-C^q)^{-1}S^{-1}=\lambda^qS^{-1}.
$$

Consequently $\lambda_i^mM_{ij}=(\lambda_i^q/p_i)(p_iQ_{ij})=\lambda_i^qQ_{ij}$ for a consistently valued delivery. The price cancels as a unit conversion. This conditional result explains why monetary data can be used; it does not prove that every aggregated or imputed empirical table satisfies those conditions.

Implementation: [`matrix_modules.R`](../scripts/modules/native/matrix_modules.R), `wlv_matrix_transformation_spec()`; numerical checks: [`leontief_diagnostics.R`](../scripts/lib/leontief_diagnostics.R). The runtime checks residuals, conditioning and a productivity/convergence certificate. WIOD13's explicitly allowed signed 2006 case uses an **absolute-convergence certificate**, not a nonnegative productivity claim. Exact nonzero-input/zero-output exceptions are validated before their protected replacement; see [WIOD13](wiodr13.md) and [scientific validation](scientific-validation.md).

## 3. Reconstruct capital composition and depreciation

The sources provide a sector's total capital stock more directly than the origins of the assets composing that stock. The method combines the known stock with EU KLEMS asset composition and WIOT gross fixed capital formation (GFCF).

For ordinary, nonexceptional columns, the allocation can be summarized as

$$
\omega_{ij,t}=G_{i,c(j),t}\,u_{a(i),g(j),r(j),t}\,s_{j,t},\qquad
K_{ij,t}=k_{j,t}\frac{\omega_{ij,t}}{\sum_i\omega_{ij,t}},
$$

$$
D_{ij,t}=K_{ij,t}\,\delta_{a(i),g(j),r(j),t+1}.
$$

Here $G$ is GFCF by supplying industry and investing country; $a(i)$ maps the supplier to an asset class; $g(j)$ maps the user to EU KLEMS industry groups; $r(j)$ is the observed or proxy EU KLEMS country; $u$ is its asset weight; and $s_j=VA_j/VA_{g(j),c(j)}$ is the WIOD disaggregation share. A common nonzero scalar $s_j$ cancels when its column is normalized; zero or anomalous shares still matter for the allocation rules. The conservation target is $\sum_iK_{ij}=k_j$.

This is an **estimated composition of an observed/estimated stock**, not an observation of every historical asset purchase. Current investment patterns help distribute the existing stock. EU KLEMS supplies depreciation assumptions; both standard methods apply the **following year's rate** to the current year's allocated stock. Countries without composition coverage use the prepared synthetic `MD` profile. A positive stock without usable primary weights can use its national GFCF distribution only under the source-specific registered fallback.

WIOD13 converts its constant-price stock through `K_GFCF * GFCF_P / exchange.r.us`; WIOD16 uses current `K / exchange.r.us`. The implicit country-year exchange rate is

$$
e_{ct}=\frac{\sum_{j\in c}VA^{LCU}_{jt}}{\sum_{j\in c}VA^{USD}_{jt}},
$$

in local-currency units per USD. Dividing local compensation or stock by $e_{ct}$ gives current USD.

Negative GFCF, zero weights, negative stocks and signed exceptions have **different, exact policies in each source**. They cannot be replaced by a general “turn all negatives or missing cells into zero” rule. The detailed [assumption register](assumptions-en.md), [WIOD13](wiodr13.md) and [WIOD16](wiodr16.md) document their scope and diagnostics. Native code: [`capital_matrix_modules.R`](../scripts/modules/native/capital_matrix_modules.R), [`indicator_source_derived_modules.R`](../scripts/modules/native/indicator_source_derived_modules.R) and [`native_euklems.R`](../scripts/preparation/native_euklems.R).

## 4. Transform output and choose a monetary scale

After solving for $\lambda$, each supplier's monetary sales are converted by its own coefficient:

$$
V_{ij}=\lambda_iM_{ij}.
$$

Summing across destinations gives `gross_output.s.mv`. This total includes embodied intermediate labour and should not be interpreted as new labour alone. New value is represented by

$$
N_j=\mathbf 1(j\in P)H_jz_j,
$$

published as `gdp.s.mv`. Its name refers to a value-based measure of new product; it is not conventional monetary GDP expressed in another currency.

For production indicators at **direct prices**, the runtime chooses one annual scale

$$
\mu_t=\frac{\sum_jx_{jt}}{\sum_jV^{GO}_{jt}}\quad[USD/\text{labour value}].
$$

It publishes `gross_output.s.du` = $\mu V^{GO}$ and `gdp.s.du` = $\mu N$. This fixes the numeraire so world gross output at direct prices sums to world monetary gross output. It does not force each industry's direct price to equal its market price, and it does not force total direct-price GDP to equal monetary GDP. The scale is neither an exchange rate nor a time deflator.

Native code: [`indicator_common_modules.R`](../scripts/modules/native/indicator_common_modules.R), `wlv_native_direct_price_spec()`.

## 5. From wages to reproduction value and surplus-value rates

The national basket uses the first final-consumption category declared by the source labels. For destination country $c$,

$$
b_{ic}=\frac{F_{ic}}{\sum_iF_{ic}},\qquad \sum_i b_{ic}=1.
$$

The supplier dimension includes imports. Every industry within that country receives the same composition, while its compensation level can differ. The method treats compensation as purchasing that basket:

$$
v_j=W_j\sum_i\lambda_ib_{i,c(j)}.
$$

`labour_force_value.s.mv` uses employee compensation (`COMP`, converted to USD); `labour_force_value.emp.s.mv` uses compensation of all persons engaged (`LAB`, including the labour income attributed to nonemployees). Their per-person indicators divide by employee and persons-engaged counts respectively. These are estimates from **average consumption shares and compensation**, not household observations of workers' saving, taxes, transfers or individual consumption needs.

For employees, let $L_j^e=H_j^ez_j^e$. The reported surplus-value rate is

$$
e_j^e=\frac{L_j^e-v_j}{v_j}=\frac{L_j^e}{v_j}-1.
$$

The persons-engaged variant substitutes $H_jz_j$ and the broader labour-compensation basket. The unrestricted series include industries classified as unproductive. The `_p` variants restrict the aggregate's numerator **and** denominator to productive industries:

$$
e_c^{e,P}=\frac{\sum_{j\in c\cap P}L_j^e}{\sum_{j\in c\cap P}v_j}-1.
$$

Therefore an unrestricted rate in an unproductive industry must not be read as a claim that it creates new value in the Leontief system. Outside the productive mask, the productive *sector* variant multiplies the underlying rate by zero; semantic missingness can still remain missing. Country and world variants recompute ratios of totals.

WIOD13 also publishes skill-group rates. If $h_{jq}$ is group $q$'s share of employee hours and $a_{jq}$ its share of compensation, the formula is $e_{jq}=L_j^eh_{jq}/(v_ja_{jq})-1$. High, medium and low skill labels do not change the standard multiplier $z=1$; their rates reflect the observed hours/compensation shares under the common national basket assumption. Country and world rates again use the summed numerators and denominators.

The profit indicator is a separate monetary accounting approximation:

$$
r_j^{app}=\frac{\Pi_j-\sum_iD_{ij}}{k_j},\qquad
\Pi_j=CAP_j/e_{c(j)}.
$$

It is published as `appropriated_profit.r.pc`. It does **not** implement the Marxian rate $s/(c+v)$: the numerator is monetary capital compensation net of estimated depreciation and the denominator is a fixed-capital stock. A zero denominator normally produces semantic `not_applicable`, not a zero rate. Rates are stored as ratios: 0.25 is displayed as 25% when the unit contract's multiplier is 100.

Native code: [`matrix_modules.R`](../scripts/modules/native/matrix_modules.R) for baskets; [`indicator_common_modules.R`](../scripts/modules/native/indicator_common_modules.R) for reproduction value, surplus-value rates and profit; [`indicator_source_derived_modules.R`](../scripts/modules/native/indicator_source_derived_modules.R) for monetary source conversions.

## 6. Measure transfers through international trade

Let $T_{ij}=1$ when supplier and destination are in different countries, otherwise 0. Productive trade additionally requires $i\in P$. The annual trade normalization is

$$
\beta_t=\frac{\sum_{ij}T_{ij}V_{ij}}{\sum_{ij}T_{ij}\mathbf1(i\in P)M_{ij}}
\quad[\text{labour value}/USD].
$$

This is the code's `balance_factor`. It is based on international trade and is generally **not** $1/\mu_t$, which is based on total production. The transfer assigned to an outward flow is

$$
\tau_{ij}=T_{ij}(\beta M_{ij}-V_{ij}).
$$

For that seller, a positive number means its monetary receipt represents more labour value than it delivers. For a country, net appropriation is outgoing transfers minus incoming transfers:

$$
\Delta_c=\sum_{i\in c,j}\tau_{ij}-\sum_{i,j\in c}\tau_{ij}
=\beta(X_c^{USD}-M_c^{USD})-(X_c^{V}-M_c^{V}).
$$

Here $X_c$ and $M_c$ denote export and import totals. The last expression makes the **trade-balance correction** explicit. Simply subtracting embodied exports from embodied imports would mix unequal exchange with lending/borrowing or other financing of an unbalanced money trade account. The standard calculation does not physically rebalance every country's trade; it compares the two balances in the same labour-value unit using the common normalization.

For a complete, consistently covered world, country net balances cancel because each outward flow is another country's inward flow. This accounting identity is distinct from the normalization: the sum of **productive transfer flows** is zero by the definition of $\beta$, whereas the sum of all transfer flows need not be zero because unproductive suppliers have $\lambda=0$. `trade_transfers.p.s.mv` restricts supplier industries to $P$; `trade_transfers.u.s.mv` is total minus productive transfers. `trade_transfers.p.m.pc` divides productive net transfers by `gdp.s.mv`.

Country matrices retain **origin × destination**. `transfers_dp` and `transfers_productive_dp` divide bilateral transfers by $\beta$ to express their monetary equivalent. Import *sector* indicators group by the supplied product's sector and receiving country, including final demand; they do not identify only the purchasing industry.

Native code: [`matrix_modules.R`](../scripts/modules/native/matrix_modules.R), [`reduced_matrix_modules.R`](../scripts/modules/native/reduced_matrix_modules.R), [`indicator_common_modules.R`](../scripts/modules/native/indicator_common_modules.R). Source/missingness validation is essential: several sums use available cells, and an arithmetic cancellation is not proof of complete coverage.

## 7. Compare a fixed basket through time

The basket-index calculation freezes shares $b^0$ and initial labour coefficients $\lambda^0$ in **1995 for WIOD13** and **2000 for WIOD16**. Let $p_{it}$ denote the source-based gross-output price index and $E_{it}=e_{c(i),t}/e_{c(i),2000}$ the supplying country's exchange-rate index. Before final rebasing, its formulas are

$$
P_{ct}^{raw}=\sum_i b^0_{ic}p_{it},\qquad
B_{ct}^{raw}=\frac{\sum_i b^0_{ic}(p_{it}/E_{it})\lambda_{it}}
{\sum_i b^0_{ic}\lambda_i^0}.
$$

Each resulting trajectory is then divided by its own 2000 observation. **Weight year, source price-index base and published index base are different concepts.** WIOD13's basket formula needs the original `GO_P` levels with 1995 = 1, not the already rebased published sector price indices. Both methods store the resulting public indices with 2000 = 1; presentation follows method-specific unit metadata. National baskets use a national currency framework, so these indices are not added across countries into a world index. See [`indicator_source_derived_modules.R`](../scripts/modules/native/indicator_source_derived_modules.R) and [the WIOD13 recalculation correction](validation/issue-28.md).

This describes the **implemented frozen-share index**, not a proof of exact physical reproduction of a 1995 basket. In WIOD13, the price/weight base and the exchange-index base differ. Origin-specific differences in those bases can affect import weights; rebasing the final aggregate does not by itself remove that issue. Assessing base compatibility and comparison with a fully consistent physical-basket construction remains methodological work.

Constant compensation is `COMP` or `LAB` in current local currency divided by the rebased basket price index and the **2000 exchange rate**. Despite its historical `.cu` suffix, it is stored in constant-2000 USD. WIOD16's constant capital series instead uses the gross-output price index as a capital deflator proxy and the base-year exchange rate; its ROW series is reconstructed after current stock is imputed. Neither operation is the conversion from money to labour value.

## 8. A two-sector example you can reproduce

Consider two productive industries, all labour treated as employee labour, with one common basket comprising equal monetary shares from each industry. All figures below are illustrative, not WIOD observations.

$$
x=\begin{pmatrix}100\\200\end{pmatrix},\quad
Z=\begin{pmatrix}15&10\\15&50\end{pmatrix},\quad
K=\begin{pmatrix}50&100\\50&100\end{pmatrix},\quad
D=0.1K=\begin{pmatrix}5&10\\5&10\end{pmatrix}.
$$

Annual hours are $H=(40,40)$; compensation is $W=(27,54)$. Dividing columns gives

$$
C=\begin{pmatrix}0.2&0.1\\0.2&0.3\end{pmatrix},\quad
\ell=(0.4,0.2),\quad
\lambda=(16/27,10/27).
$$

For example, the first equality is $16/27=0.4+0.2(16/27)+0.2(10/27)$. It includes the first industry's own direct labour and the indirect labour in both inputs.

| Result | Sector 1 | Sector 2 | Combined |
| --- | ---: | ---: | ---: |
| Gross output in labour value | $1600/27$ | $2000/27$ | $400/3$ |
| New labour value | 40 | 40 | 80 |
| Reproduction value $v$ | 13 | 26 | 39 |
| Surplus $H-v$ | 27 | 14 | 41 |
| Surplus-value rate | $27/13$ | $7/13$ | $41/39$ |

The basket contains $(\lambda_1+\lambda_2)/2=13/27$ labour-value units per USD. This turns USD 27 and USD 54 of compensation into 13 and 26 units. The combined surplus-value rate is $80/39-1=41/39$, approximately 105.13%; the arithmetic mean of the sector rates would instead give 130.77% and answer a different question. The production numeraire is $300/(400/3)=9/4$ USD per labour-value unit.

For a separate illustration of the trade formula using these same labour coefficients, suppose country A exports USD 20 of product 1 to B, and B exports USD 10 of product 2 to A. Then $\beta=14/27$, outward transfers are $-40/27$ and $+40/27$, and A's net transfer is $-80/27$. Its positive monetary trade balance of USD 10 does not by itself imply appropriation of labour value.

The following **base R** block implements these examples without packages or files. It illustrates the mathematics; it does not reproduce source preparation, missingness policies or the full production validation pipeline.

```r
x <- c(100, 200)
Z <- matrix(c(15, 10, 15, 50), nrow = 2, byrow = TRUE)
K <- matrix(c(50, 100, 50, 100), nrow = 2, byrow = TRUE)
Dep <- 0.1 * K
H <- c(40, 40)
W <- c(27, 54)
C <- sweep(Z + Dep, 2, x, "/")
ell <- H / x
lambda <- as.vector(solve(t(diag(2) - C), ell))
gross_value <- lambda * x
basket <- c(0.5, 0.5)
v <- W * sum(lambda * basket)
surplus <- H - v
surplus_rate <- H / v - 1
aggregate_rate <- sum(H) / sum(v) - 1
mu <- sum(x) / sum(gross_value)
capital_stock <- colSums(K)
monetary_va <- x - colSums(Z)
capital_compensation <- monetary_va - W
profit_rate <- (capital_compensation - colSums(Dep)) / capital_stock

trade_usd <- matrix(c(0, 20, 10, 0), nrow = 2, byrow = TRUE)
trade_value <- sweep(trade_usd, 1, lambda, "*")
beta <- sum(trade_value) / sum(trade_usd)
transfers <- beta * trade_usd - trade_value
net_transfers <- rowSums(transfers) - colSums(transfers)

stopifnot(
  max(abs(lambda - c(16, 10) / 27)) < 1e-12,
  max(abs(as.vector(lambda %*% (diag(2) - C)) - ell)) < 1e-12,
  max(abs(v - c(13, 26))) < 1e-12,
  abs(aggregate_rate - 41 / 39) < 1e-12,
  abs(sum(mu * gross_value) - sum(x)) < 1e-12,
  max(abs(profit_rate - 0.33)) < 1e-12,
  abs(beta - 14 / 27) < 1e-12,
  max(abs(net_transfers - c(-80, 80) / 27)) < 1e-12,
  abs(sum(net_transfers)) < 1e-12
)
print(data.frame(lambda, gross_value, v, surplus, surplus_rate, profit_rate))
print(c(aggregate_rate = aggregate_rate, mu = mu, beta = beta))
print(net_transfers)
```

## 9. Aggregate according to the economic quantity

| Quantity | Correct operation in the current contracts | Reason |
| --- | --- | --- |
| Hours, compensation, capital and other comparable totals | Sum | They are additive within the same unit and period |
| Labour value per USD | Total gross-output value / total monetary gross output | Large and small industries must not receive equal arbitrary weight |
| Reproduction value or labour per person | Total numerator / total relevant persons | Preserve the relevant employee/persons-engaged population |
| Surplus-value rate | Total labour / total reproduction value − 1 | Preserve both sides of the relation |
| Appropriated profit rate | Total net capital compensation / total stock | Preserve the accounting denominator |
| Labour-complexity multiplier | Hours-weighted mean | The multiplier acts on hours |
| National output price index | Current-USD gross-output-weighted mean | This is the declared current aggregation rule |
| Country exchange rate or shared basket index | Invariant across its sectors | These are broadcast country values |
| World exchange/basket/output price indices | `not_applicable` as declared | National currency bases are not one common world currency |

The [v2 unit and aggregation contracts](units.md) are executable specifications, not optional display advice. Some formulas are implemented in dedicated aggregation modules. Available-case sums require their semantic-state information: a finite total may have incomplete coverage. Consult `_states.csv`, `_anomalies.csv` and `_scientific_checks.csv` alongside numerical arrays; see [missingness](missingness.md).

## 10. Assumptions that must accompany an empirical result

The standard aggregate ratios use independently summed operands, rather than
automatically selecting complete numerator/denominator pairs. Thus `WWW` in
`surplus_value.emp.r.pc` can include imputed ROW labour in its numerator while
ROW reproduction costs are missing from its denominator; aggregate profit
also sums capital compensation, depreciation and stock separately. Inspect
each operand's coverage: these formulas do not establish that every term
refers to the same observed population.

The [full assumption register](assumptions-en.md) connects each assumption to its code, evidence, effects and unfinished work. At a minimum, report:

1. The selected source, period and productive classification; annual average sector technology represents heterogeneous producers, with proportional input requirements and no firm-level production reconstruction.
2. Equal labour-hour multipliers, rather than an empirically identified international reduction of complexity and intensity; observed wage differences are not used to prove productivity differences.
3. Capital composition estimated from EU KLEMS, investment shares and proxies, including the next-year depreciation convention and all source-specific fallbacks.
4. National average consumption shares used to translate compensation into labour-power reproduction value; no worker-specific budget, saving or unpaid-household-work model is estimated.
5. China and Rest-of-World supplementation: WIOD13 treats Chinese persons engaged as employees; WIOD16 additionally imports mapped WIOD13 hours per worker and holds the last observation through 2014. ROW employment is distributed using observed sector employment/value-added intensities, hours use observed sector hours per worker, and capital uses the minimum reference-country capital per hour. Remaining employee/compensation gaps are not automatically filled by these steps.
6. The monetary scale and international trade normalization, the distinction between gross-output value and new value, and between monetary profit and surplus value.
7. Registered zero/missing/signed policies, their diagnostics and the weaker capital coverage in WIOD13 for 2008–2009. Successful numerical validation is conditional on these choices; it is not external validation of their economic realism.

## 11. What remains to be developed

Scientifically useful extensions include sensitivity to labour reduction and productive boundaries; observed consumption baskets by worker group; alternative ROW labour and capital imputations; empirical asset-origin and depreciation estimates; and explicit analysis of the impact of compatibility zeros and truncated negative GFCF. Restoring an executable provenance chain for the historical China industry mapping would improve reproducibility. Extending periods, recovering other databases and implementing alternative methods require their own source, unit, missingness and validation contracts.

A future Marxian profit-rate series would need an explicit definition and measurement of advanced constant and variable capital, turnover and valuation; changing the label of the current accounting ratio would not supply those quantities. These are proposals, not implemented capabilities. The [practical guide](guide-en.md) explains how to use existing results, reproduce supported calculations and contribute a separately reviewed expansion.
