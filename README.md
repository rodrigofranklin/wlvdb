# World Labour Values Database (WLVDB)

<!-- documentation-revision: wiod-consolidation-v1 -->

[Português](README-PT.md) | English

WLVDB estimates labour values, surplus-value rates, capital and trade transfers
from world input-output tables and socioeconomic accounts. It connects economic
categories to reproducible calculations and publishes the results read by
WLVPanel. These are estimates under explicit assumptions, not direct observations
of Marxian categories.

This release supports **only `wiodr13` (1995–2009) and `wiodr16` (2000–2014)**.
Both prepare sources, calculate, validate, recalculate variables and publish
panel-ready results. EXIOBASE and EORA are future work in
[#14](https://github.com/rodrigofranklin/wlvdb/issues/14). Preserved alternative
definitions are not executable, including with experimental opt-in. Researchers
can use results in their own external analysis scripts; paper preparation and
generation are outside this project.

## Choose a reading path

The documentation connects **what is being measured**, **how it is calculated**
and **how to work with the code and results**. Start with the theory if labour
values are new to you. The mathematical chapter builds a small economy step
by step before mapping its equations to the implementation.

| Start here | Reading path |
| --- | --- |
| Understand the concepts and their measurement | [Theory: labour, value, reproduction, exploitation and trade](docs/theory-en.md), with [ABNT references](docs/references-en.md) |
| Understand the mathematics | [Methodology: notation, derivations, worked example and code mapping](docs/methodology-en.md) |
| Evaluate assumptions and research gaps | [Assumptions, imputations, exceptional data and work still needed](docs/assumptions-en.md) |
| Use results without running a calculation | [Files, units, missing values and reading data](docs/guide-en.md#use-the-results), then the [complete indicator dictionary](docs/results-dictionary-en.md) |
| Reproduce or improve the project | [Installation and executable workflow](docs/guide-en.md#run-the-project), then the [contribution walkthrough](docs/guide-en.md#contribute-an-improvement) |

The conceptual chapters draw on Franklin et al. (2022) and Franklin (2025).
They distinguish those studies' assumptions from the current code: productive
industry classifications, labour-reduction alternatives and depreciation
treatment are not identical across all versions. A successful run therefore
does not by itself reproduce every table in either publication.

## Run the supported methods

From the repository root, with R 4.6.1 installed:

```sh
Rscript --vanilla scripts/bootstrap.R
Rscript --vanilla scripts/run_wlv.R --method wiodr13 --prepare-only --check
Rscript --vanilla scripts/run_wlv.R --method wiodr13 --prepare-only
Rscript --vanilla scripts/run_wlv.R --method wiodr13 --workers 1
```

The bootstrap restores packages from `renv.lock`. Preparation downloads and
verifies economic inputs. `--check` only checks the environment and request;
it does not validate source data or calculate results. Opening the project
does not install packages, load a saved workspace or start a calculation.
The workflow is independent of an IDE: use your preferred editor or terminal;
personal IDE settings are not versioned. Read the
[resource measurements](docs/guide-en.md#resources) before a real run.

The [support catalog](docs/methods.md), [WIOD13 source contract](docs/wiodr13.md),
[WIOD16 source contract](docs/wiodr16.md), [scientific checks](docs/scientific-validation.md)
and [publication contract](docs/result-publication.md) provide technical details.
The theory, mathematics, assumptions, practical guide and references are available
in full in English and Portuguese. Technical annexes and historical audit records
retain their original language. Documentation revision and maintenance rules are recorded in
the [synchronization convention](docs/documentation-sync.md).

Application code and maintenance commands live in `scripts/`. The `tests/`
directory contains versioned test code and fixtures used to detect regressions.
Generated test results, logs, local experiments and campaigns belong exclusively
in `temp/<id>/`, ignored by Git. See
[local campaigns and cleanup](docs/local-campaigns.md). Campaign 054 is preserved
in `temp/054/` and must not be rerun, changed or deleted.

For reproducible citation, record the method, years, Git commit, unit contract,
`run_id`, `result_id`, `release_id` and source references supplied with the run.
Source attribution and licenses are explained in the
[guide](docs/guide-en.md#sources-and-attribution).
