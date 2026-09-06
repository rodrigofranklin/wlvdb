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

| Start here | Reading path |
| --- | --- |
| Understand the economic project | [Purpose, coverage, glossary and methodology](docs/guide-en.md#understand-the-project) |
| Use results without running a calculation | [Files, units, missing values and reading data](docs/guide-en.md#use-the-results), then the [complete indicator dictionary](docs/results-dictionary-en.md) |
| Run or maintain a calculation | [Installation and executable workflow](docs/guide-en.md#run-the-project), then the [code map](docs/guide-en.md#understand-the-code) |

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
Read the [resource measurements](docs/guide-en.md#resources) before a real run.

The [support catalog](docs/methods.md), [WIOD13 source contract](docs/wiodr13.md),
[WIOD16 source contract](docs/wiodr16.md), [scientific checks](docs/scientific-validation.md)
and [publication contract](docs/result-publication.md) provide technical details.
The complete bilingual guide is self-contained; technical annexes retain their
original language. Documentation revision and maintenance rules are recorded in
the [synchronization convention](docs/documentation-sync.md).

Local experiments and campaigns belong exclusively in `temp/<id>/`, ignored by
Git. See [local campaigns and cleanup](docs/local-campaigns.md). Campaign 054 is
preserved in `temp/054/` and must not be rerun, changed or deleted.

For reproducible citation, record the method, years, Git commit, unit contract,
`run_id`, `result_id`, `release_id` and source references supplied with the run.
Source attribution and licenses are explained in the
[guide](docs/guide-en.md#sources-and-attribution).
