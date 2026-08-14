# WIOD 2016 recovery and source contract

The WIOD 2016 preparation is pinned to the official **World Input-Output
Database 2016 Release, 2000-2014**, DOI
[`10.34894/PJ2M1C`](https://doi.org/10.34894/PJ2M1C). The University of
Groningen describes the release and its coverage on the
[official WIOD 2016 page](https://www.rug.nl/ggdc/valuechain/wiod/wiod-2016-release).

## Pinned inputs

| Input | Dataverse file | Bytes | Checksum |
|---|---:|---:|---|
| WIOTs in R format | `199101` | 641,578,409 | SHA-1 `51efc2a6c0358cff485e24d6b4b96ffe27f4e23a` |
| Socio-Economic Accounts | `199095` | 5,536,437 | SHA-1 `821bba29c42f3a42009eb1b14dbdaa2922d01236` |

Both files are downloaded over HTTPS from the Dataverse access API. A cached
file is reused only after its exact byte length, checksum and structure have
been verified. Downloads are staged in the destination directory and installed
with an atomic rename, so an interrupted or corrupt replacement cannot destroy
a previously verified cache.

The WIOT archive must contain exactly the required annual files named
`WIOT2000_October16_ROW.RData` through
`WIOT2014_October16_ROW.RData`. Preparation extracts only these 15 members into
`source_data/wiodr16`. The verified ZIP remains cached; the extracted `.RData`
files are deleted only after all prepared outputs have been validated and
written successfully.

## Structural contract

The prepared coverage is 2000-2014. Each annual WIOT contains 44 regions (the
43 explicitly covered countries plus `ROW`), 56 industries and five final
demand categories. Preparation writes:

- `m_io.fst`: `15 x 2,464 x 2,684`, with 2,464 industry inputs and 2,464
  industry plus 220 final-demand outputs;
- `sea.fst`: `15 x 18 x 56 x 44`, with the 16 original SEA variables plus
  `VA_USD` and `GO_USD` recovered from the WIOTs;
- `countries.csv`, `sectors.csv` and `demand.csv`, preserving the official
  ordering used by the arrays.

The method also prepares the shared pinned EU KLEMS capital-composition and
depreciation inputs for 2000-2015. Capital composition for year *t* comes from
`ekk_<t>.fst`, while `ekdeprate_<t+1>.fst` supplies the depreciation rate
applied to that stock; the extra 2015 file is therefore required for the 2014
calculation. The requested year range is passed explicitly and does not alter
the WIOD13 preparer's default range.
When EU KLEMS supplies a depreciation rate for an aggregate directly, that
rate is authoritative; weighted component rates are synthesized only for
aggregate-rate cells absent from the complementary rate table.

WIOD16 names its five final-demand categories `c57` through `c61`. Gross fixed
capital formation (GFCF) is the fourth category, `c60`; the capital-allocation
matrix requires exactly one `<country>.c60` column for every region. This
replaces the legacy `c41` lookup, which belonged to the earlier WIOD convention
and selected no WIOD16 data.

Every FST array and its `.meta` file are installed together as one transaction.
Country, sector, row, column and year order are checked before conversion, and
all WIOT values must be finite.

The official SEA workbook contains 112 missing observations in every year:
all 56 sectors for `CHN` in each of `EMPE` and `H_EMPE`. Preparation checks this
exact profile and preserves those 1,680 missing values so the source absence
remains distinguishable and the later China assumption remains mandatory. This
is an intentional correction to the legacy preparer, which replaced every
missing value with zero before the assumption ran. The original 16 SEA
variables are structurally absent for `ROW` (13,440 values); only `VA_USD` and
`GO_USD` are supplied for that region from the WIOTs. The prepared SEA therefore
contains exactly 15,120 documented missing values and no other missing or
non-finite values.

## Explicit allocation anomaly policy

The prepared source files remain unchanged. Their scientifically relevant
negative observations are pinned by exact position and value before the
calculation starts: `K[2012:2014, C33, PRT]` is respectively `-313.147`,
`-554.413` and `-873.203` million national-currency units, and
`VA_USD[2007, J58, ROU]` is `-17.404439964866128`. The full EU KLEMS capital
tables are likewise checked against an exact allowlist of 21 negative cells in
2010-2015. An added, missing or numerically changed anomaly aborts validation.

Only the derived WIOD16 allocation layer is sanitized. The three known
negative capital stocks and the 21 known negative EU KLEMS weights are set to
zero. The Romanian `J58` value-added disaggregation ratio in 2007 is checked
against `-0.027559192993556868` and then made absolute; because every element
of that allocation column shares this scalar, its sign cancels during
normalization, while the explicit treatment avoids a transient negative
composition. No WIOD13 allocation helper or source file is changed by this
policy.

EU KLEMS provides zero total weights for five positive-stock columns in 2000
(`MEX.T`, `MEX.U`, `TUR.T`, `TWN.T`, `USA.T`) and the same five plus `LUX.T`
in every year from 2001 through 2014. Truncating the allowlisted negative EU
KLEMS weights also leaves `EST.H51` without a positive weight in 2012. These 90
country-sector-year cases use
the composition of their own country's non-negative `c60` GFCF column as the
fallback distribution. Any other positive stock without a positive finite
weight total, or an allowlisted fallback whose GFCF total is not positive,
aborts the calculation. Every allocated column is finally checked to be
finite, non-negative and exactly stock-conserving within numeric tolerance.

## China labour-input supplement

The official WIOD16 SEA does not provide `EMPE` or `H_EMPE` for China. The
calculation therefore uses the versioned complementary file
`complementar/wiodr16/china_hours_per_worker.csv`; this file is an explicit
methodological assumption, not an official WIOD16 source input.

The file restores the exact historical Git blob
`41d50475500bf41a9ee022a6b33cd3e7625eb0d4`, formerly stored as
`sourcedata/Nov16/China H_EMPE-EMPE.csv`. Its coefficients were derived from
the WIOD 2013 `H_EMP / EMP` ratio and mapped from the earlier industry
classification to the 56 WIOD16 sectors. Since `H_EMP` is measured in million
hours and `EMP` in thousand persons, every coefficient is expressed in
**thousand annual hours per person engaged**. The last available observation,
2009 (already equal to 2008 in the restored file), is held constant through
2014. During calculation the coefficient is multiplied by employment in
persons and by 1,000 to obtain hours; all persons engaged are then treated as
employees for China. Exact sector codes, sector names, year order, numeric
finiteness and the physical unit range are validated before the assumption is
applied. The historical repository does not contain an executable script for
the Rev.3-to-Rev.4 mapping, so the exact versioned blob is the reproducible
artifact for this assumption.

## Rebuild

After restoring the project library, rebuild and validate the source layer
without starting the calculation:

```sh
Rscript --vanilla scripts/run_wlv.R --method wiodr16 --prepare-only
```

The WIOD inputs total about 647 MB. A clean first run also downloads about
174 MB of shared EU KLEMS inputs; later runs verify and reuse both pinned
caches.
