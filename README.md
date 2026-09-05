Summary

Open Science project to develop, implement and improve methodologies to obtain values (marxian, sraffian ...) and categorical concepts estimates based on world - level public available information such as World Input Output matrices, KLEMS, cepal io data. Further extensions to include EXIOBASE, better estimates available for more countries.

When using the data, please cite:

FRANKLIN, R.;BORGES, R,; SÁNCHEZ, C.; MONTIBELER, E. Skilled labour and the reduction problem: questioning the exploitation rate equalization hypoyhesis. _World Review of Political Economy_ (in press), 2022.



Also included preliminary estimates on:
- Unequal Exchange;
- Exploitation rates;
- Profit rates;
- different approximation to values - direct prices, sraffian prices

Temporal coverage varies by source and is declared in the canonical support
matrix below; unverified legacy coverage is intentionally left unspecified.




## Method and source support

The canonical support matrix is generated from the repository's
machine-readable catalog and published in
[`docs/methods.md`](docs/methods.md). In that matrix, `stable` means that the
declared lifecycle is recovered, validated, tested, and documented;
`experimental` requires explicit opt-in and is not yet a supported scientific
release; and `disabled` means execution remains blocked until its documented
recovery work is complete.

WIOD13 and WIOD16 are currently the recovered source families. Their reference
methods, `wiodr13` and `wiodr16`, are the only executable methods in this release.
The alternative WIOD definitions are retained for later incorporation, with
calculation and recalculation disabled even with experimental opt-in.
EXIOBASE and EORA sources remain experimental, and their methods are disabled
until their preparation and calculation lifecycles are recovered.

Every published WIOD calculation is also subject to a versioned scientific
contract: structural identities, aggregation and conservation rules, numerical
error bounds, Leontief stability certificates and recalculation equivalence are
documented in [`docs/scientific-validation.md`](docs/scientific-validation.md).
The process-isolated comparison of explicit inversion, direct solution and the
productive-block solution is reproducible with
[`scripts/benchmark_leontief.R`](scripts/benchmark_leontief.R); protocol and
reference measurements are in
[`docs/leontief-benchmark.md`](docs/leontief-benchmark.md).
Validated outputs are published as immutable runs and coherent releases; the
manifest/checksum chain, channels, crash behavior, recalculation lineage, and
WLVPanel contract are documented in
[`docs/result-publication.md`](docs/result-publication.md). Storage retention is
explicit and dry-run-first as described in
[`docs/publication-storage.md`](docs/publication-storage.md).

## Safe startup and main function

Opening the project does not install packages, update the Git checkout, load a
saved workspace, or start a calculation. From the repository root, restore the
exact package versions once and run a method explicitly:

```sh
Rscript --vanilla scripts/bootstrap.R
Rscript --vanilla scripts/run_wlv.R --method wiodr13
```

The bootstrap restores `renv.lock`; it does not download the economic source
data. To work interactively after bootstrapping, activate the project library
and load the main functions explicitly:

```r
source("renv/activate.R")
bootstrap <- new.env(parent = baseenv())
sys.source("R/bootstrap.R", envir = bootstrap)
wlv <- bootstrap$wlv_load_runtime(".")
wlv$get_wlv("wiodr13")
```

Use `Rscript --vanilla scripts/run_wlv.R --list-methods` to inspect status,
coverage, and supported operations using the pinned project library, without
loading source data. Use `--help` for all command-line options, or add `--check` to
validate the environment and method without calculating.
To rebuild and validate a source without immediately starting the calculation,
use `--method wiodr13 --prepare-only` or `--method wiodr16 --prepare-only`.
Pinned sources, checksums, temporal coverage, and compatibility rules are
documented in [`docs/wiodr13.md`](docs/wiodr13.md) and
[`docs/wiodr16.md`](docs/wiodr16.md).

### get_wlv function

get_wlv is a function that wraps all calculations and outputs files to the results folder with all variables, and arrays with Country and Sector Socio-Economic Accounts(SEAs).


For example, calculate WIOD13 with `wlv$get_wlv("wiodr13")` from the private
runtime returned by the bootstrap above. `R/main.R` is a definition file and
must not be loaded directly.

The function accepts the following arguments:

* methods - a string or a character vector like `c("wiodr13", "wiodr16")` for the methods to be calculated. Defaults to `"wiodr13"`
* repeat_pp - boolean to indicate if full download and preparation of source data should be performed . Defaults to FALSE
* papern, prepaper - retired arguments retained only for call compatibility at their defaults (`0`, `FALSE`); paper generation has been removed and requests to enable it fail before calculation
* workers - positive integer controlling PSOCK workers. The default is `1`, which runs sequentially without creating a cluster
* channel - lowercase publication channel, optionally hierarchical, such as `stable` or `research/input-v3`. Defaults to `stable`
* allow_experimental - boolean explicit opt-in for experimental capabilities. Defaults to `FALSE`; it cannot enable a method whose calculation or recalculation capability is disabled


 ## Repository Folder Structure
 1) source_data - to be downloaded separatedly from gitlab -  [link here](https://cloud.worldlabourvalues.org/s/wjMfkBXDnptADXF)

Folder with data downloaded from primary input-output tables sources.

The data in this folder is also formatted to keep a tractable structure from different sources to the virtually same processing 

Data is also formatted to


 2) catalog and configuration
 
`catalog/` declares sources, methods, capabilities, validation profiles and
public contracts. `config/modules/` composes method, source and common native
module instances with typed `add`, `replace` and `remove` operations.
`config/aggregations/` declares the historical aggregation profile. CSV files
contain identifiers and typed arguments only; executable paths, R expressions
and semantic ordering are not configuration.

 3) methods
 
 The first and reference paper shows how the same source can be subject to different methods. In that case, different methods to convent from concrete to abstract labour time.
 
 One of the features of the World Labour Values Database is the ease to create, apply and compare different methods for estimating categories. As such, it provides subsidiary complement to theoretical discussions.
 
The subfolders in `methods/` contain method metadata, parameters and sector
classifications. Executable scientific behavior is registered as native
function definitions under `R/modules/native/`; the compiled dependency graph,
not CSV row position, determines execution order.
 
 
 
 4) results - to be downloaded separatedly if one wants to check results already arrived by our team - [ink here](https://coletiva.imperialismoedependencia.org/s/NMMDyMxL8fWxfjq)
 
 Results are stored as immutable method runs under
 `results/runs/<method>/<run_id>/`. A release under `results/releases/` fixes
 the coherent set consumed by the panel, and an append-only marker under
 `results/channels/<channel>/` selects the current release.
 
 The variables are either saved in:
 
 m_io files (in values, for ex), if sectorial , m_countries, if national 
 SEA_countries and SEA_sectors arrays
 
 
5) R

The deterministic bootstrap loads function definitions from `R/lib/`,
`R/modules/native/`, `R/preparation/` and `R/main.R` into one locked private
namespace. Scientific modules receive declared inputs, arguments and injected
services through an explicit context; legacy sourced executors are not part of
the reachable runtime.
