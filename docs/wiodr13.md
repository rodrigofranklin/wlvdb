# WIOD13 recovery and provenance

The `wiodr13` source is rebuilt from the files below. Downloads are installed
only after their exact byte size and cryptographic checksum have been
verified. Cached files are verified again before they are reused.

| Source file | Upstream | Bytes | Checksum |
| --- | --- | ---: | --- |
| `WIOTS_in_MATLAB.zip` | [WIOD 2013 Dataverse file 199125](https://dataverse.nl/api/access/datafile/199125) | 292,278,662 | SHA-1 `7e921fda5e3b80605a27e7404ac16fbf1f5a3cd7` |
| `Socio_Economic_Accounts_July14.xlsx` | [WIOD 2013 Dataverse file 199111](https://dataverse.nl/api/access/datafile/199111) | 7,831,205 | SHA-1 `4056b31e2399fd2bb92a311109f279f07ff15faa` |
| `Statistical_Capital.rds` | [EU KLEMS bulk file](https://euklems.eu/bulk/Statistical_Capital.rds) | 129,637,707 | SHA-256 `77bf752a4c79c0e324e6be31164e8f27fdc100c89b08f68c3a227da7c7ab3b44` |
| `Statistical_National-Accounts.rds` | [EU KLEMS bulk file](https://euklems.eu/bulk/Statistical_National-Accounts.rds) | 44,200,266 | SHA-256 `c6f7b65eb263839ea824fe223a8cf5fc13fad444db5b7a857b6aa01b29d0a4f2` |

The WIOD files belong to the
[World Input-Output Database 2013 Release, 1995-2011](https://doi.org/10.34894/XDTAUZ).
Use of the data must follow the attribution and licence terms published with
the source datasets.

## Versioned time coverage

Although the upstream WIOD release extends through 2011, the existing
`wiodr13` method deliberately retains its historical 1995-2009 contract. It
uses the revised WIOT file for 2008-2009 and EU KLEMS depreciation information
through 2010. Extending the period must be introduced as a separately reviewed
method version rather than silently changing historical results.

The legacy preparation also maps the official SEA workbook's 8,757 missing
numeric cells to zero. This exception is accepted only when its exact
`year|country|variable|sector` coordinate set has MD5
`c6d680700338a625abc5e3df78b61c0a`; a positional change aborts even if all
annual counts remain unchanged. The preparation reports the count and hash. SEA
variables not supplied for the Rest of the World remain explicitly missing;
the method's Rest-of-World assumption handles the required derived values.
These compatibility rules are documented here so they are not mistaken for
observed zeros or source measurements.

## Calculation safeguards restored

The recovered calculation also makes historical edge cases explicit:

- The standard method estimates one current exchange rate for each country-year
  as `sum(VA in local currency) / sum(VA in current USD)`, expressed in
  local-currency units per USD, and broadcasts that rate unchanged to every
  sector. Non-positive, missing, or non-finite national totals abort. The USA
  rate is checked against one before being canonicalized to exactly `1`; the
  derived unitless exchange-rate index has base `2000 = 1`. The explicitly
  versioned `wiodr13v09` method retains the former sector-level calculation for
  historical comparability.
- WIOD country codes `GBR` and `GRC` map to the EU KLEMS conventions `UK` and
  `EL`; they must not silently fall back to the synthetic mean country.
- A positive capital-stock column with no positive primary EU KLEMS allocation
  weight uses that country's non-negative WIOD GFCF distribution. The pinned
  1995-2009 run contains exactly 93 such sector-year columns, recorded as
  `use_national_gfcf_fallback` under `wiodr13_gfcf_fallback_v1`. A missing or
  non-positive national GFCF basis aborts; every allocated column must conserve
  its original capital stock within numeric tolerance.
- Before that distribution, the 24 negative WIOD GFCF source cells are checked
  as one exact set. The radix-sorted UTF-8 keys `year|input|output`, joined by
  newline, must have MD5 `61cfd5d08a9934a703335e14968e5b43`. Only those cells
  are accepted, and their key-plus-magnitude profile in canonical million USD
  must also have MD5 `0287db08451f74a23fe7657cc07e9165`. They are truncated to
  zero only in the non-negative capital-allocation input, with their original
  values and coordinates recorded as `truncate_allowlisted_negative_gfcf`
  under `wiodr13_negative_gfcf_v1`.
- World productive exploitation rates are calculated as ratios of global
  totals, rather than left missing or averaged across national rates.

## Closed signed-domain exception

The standard method has one signed capital case: `2006/GBR.23`. Its observed
`GFCF_P` is `-631.84349265723654`; the resulting capital stock and depreciation
are respectively `-75458950528.278488` and `-6684967062.9865351`. The
calculation accepts neither an extra negative cell nor a relocation or magnitude
change: the SEA coordinate and values, the 824 negative cells in each capital
matrix, and the method-year Leontief profile of 397 negative coefficients are
pinned and revalidated before publication.

Because the coefficient domain is signed, the calculation does **not** claim
Hawkins-Simon productivity for 2006. It instead certifies absolute convergence
using `abs(C)` and publishes `absolute_convergence_signed`; productivity is
recorded as `not_applicable`. Exact fingerprints, the reconstructed coefficient
profile and the distinction between enforced pins and independent audit
references are documented in
[`scientific-validation.md`](scientific-validation.md).

The Leontief transformation also contains 3,150 official nonzero input flows
whose reported output denominator is zero. They are accepted only as this exact
versioned set:

| Year | Zero-output column | Coordinates |
| ---: | --- | ---: |
| 2005 | `CYP.23` | 781 |
| 2006 | `CYP.23` | 776 |
| 2007 | `CYP.23` | 786 |
| 2005 | `MLT.23` | 807 |

The radix-sorted UTF-8 keys `year|input|output`, joined by newline, must have
MD5 `f66341eea44e71728bbda6f8e25765ba`. Only after the count, four groups, and
checksum match are these numerators set to zero for the protected `0 / 0`
division; every coordinate is audited as `allowlisted_nonzero_over_zero` under
`wiodr13_leontief_zero_output_v1`. Any added, removed, or changed coordinate
aborts the calculation.

In the serialized `m_io` result, capital and basket matrices are defined only
for the 1,435 industry outputs. Their 205 final-demand columns therefore remain
structurally `NA`; all remaining `m_io` cells must be finite. Published sector
and country arrays may contain an ordinary `NA` only when its exact coordinate
and `source_missing` or `not_applicable` meaning is persisted in `_states.csv`
and passes the semantic round-trip described in `docs/missingness.md`.

Every successful calculation also publishes `_gfcf_negative_cells.csv`, with
the original value, applied value, delta, exact coordinates, policy, and
absolute rank of every truncated cell, plus `_gfcf_negative_summary.csv`, with
totals and cuts by year, investing country, supplying country, and supplying
sector. These sidecars are staged and byte-validated with the method metadata;
they are derived from the current calculation rather than the append-only
anomaly history. A later variable recalculation revalidates and preserves these
matrix diagnostics; it cannot silently copy a missing or altered sidecar.

## Rebuild without calculating

From the repository root:

```sh
Rscript --vanilla scripts/bootstrap.R
Rscript --vanilla scripts/run_wlv.R --method wiodr13 --prepare-only
```

The command creates ignored files under `source_data/wiodr13` and
`source_data/euklems`, then validates labels, dimensions, years, finite values,
and the WIOD gross-output identity. It does not start the labour-value
calculation.

To run the standard calculation after preparation:

```sh
Rscript --vanilla scripts/run_wlv.R --method wiodr13 --workers 1
```
