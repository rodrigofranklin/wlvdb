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

The legacy preparation also maps missing numeric cells in the official SEA
workbook to zero. The preparation reports the number of affected cells. SEA
variables not supplied for the Rest of the World remain explicitly missing;
the method's Rest-of-World assumption handles the required derived values.
These compatibility rules are documented here so they are not mistaken for
observed zeros or source measurements.

## Calculation safeguards restored

The recovered calculation also makes three historical edge cases explicit:

- WIOD country codes `GBR` and `GRC` map to the EU KLEMS conventions `UK` and
  `EL`; they must not silently fall back to the synthetic mean country.
- When a sector has capital stock but no WIOD GFCF weights with which to
  allocate it, its composition and depreciation matrix column is set to zero
  and reported. Intermediate-consumption flows remain intact; an undefined
  depreciation value no longer erases them.
- World productive exploitation rates are calculated as ratios of global
  totals, rather than left missing or averaged across national rates.

In the serialized `m_io` result, capital and basket matrices are defined only
for the 1,435 industry outputs. Their 205 final-demand columns therefore remain
structurally `NA`; all defined cells and all published sector, country, and
bilateral results must be finite.

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
