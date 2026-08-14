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
methods are stable, while the alternative WIOD methods remain experimental.
EXIOBASE and EORA sources remain experimental, and their methods are disabled
until their preparation and calculation lifecycles are recovered.

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
source("R/main.R")
get_wlv("wiodr13")
```

Use `Rscript --vanilla scripts/run_wlv.R --list-methods` to inspect status,
coverage, and supported operations without loading project dependencies or
source data. Use `--help` for all command-line options, or add `--check` to
validate the environment and method without calculating.
To rebuild and validate a source without immediately starting the calculation,
use `--method wiodr13 --prepare-only` or `--method wiodr16 --prepare-only`.
Pinned sources, checksums, temporal coverage, and compatibility rules are
documented in [`docs/wiodr13.md`](docs/wiodr13.md) and
[`docs/wiodr16.md`](docs/wiodr16.md).

### get_wlv function

get_wlv is a function that wraps all calculations and outputs files to the results folder with all variables, and arrays with Country and Sector Socio-Economic Accounts(SEAs).


For example, to calculate the current standard procedure with WIOD13 data, call `get_wlv("wiodr13")` after loading `R/main.R`.

The function accepts the following arguments:

* methods - a string or a character vector like `c("wiodr13", "wiodr16")` for the methods to be calculated. Defaults to `"wiodr13"`
* repeat_pp - boolean to indicate if full download and preparation of source data should be performed . Defaults to FALSE
* papern - number of the paper to eventually trigger further tables and/or graphs that compare different methods, cross-sectional and longitudinal indicators, any custom analysis to be included in the paper referred to by the same number.
* prepaper - wether to actually trigger the preparation of such custom analysis (calls corresponding script from papers/ folder)
* workers - positive integer controlling PSOCK workers. The default is `1`, which runs sequentially without creating a cluster
* allow_experimental - boolean explicit opt-in for methods marked `experimental`. Defaults to `FALSE`; methods marked `disabled` remain blocked


 ## Repository Folder Structure
 1) source_data - to be downloaded separatedly from gitlab -  [link here](https://cloud.worldlabourvalues.org/s/wjMfkBXDnptADXF)

Folder with data downloaded from primary input-output tables sources.

The data in this folder is also formatted to keep a tractable structure from different sources to the virtually same processing 

Data is also formatted to


 2) parameters
 
 Folder with few parameters, organized in subfolders,
global parameters (common_ground subfolder) and general parameters for each of primary IO sources.
For each source, eg. WIOD13:


* _source_assumptions.csv - indicates how to deal to estimate important (and missing from source) info,currently mainly Rest of the World and China info on labour
* _source_matrices.csv - indicates how to deal mainly to infer Kapital and Depreciation Matrices
* _source_solutions.csv - indicates variables to be calculated and corresponding procedure for the estimate



 
These parameters are  to be used if no different specific definition is provided in any one method that uses the source

 3) methods
 
 The first and reference paper shows how the same source can be subject to different methods. In that case, different methods to convent from concrete to abstract labour time.
 
 One of the features of the World Labour Values Database is the ease to create, apply and compare different methods for estimating categories. As such, it provides subsidiary complement to theoretical discussions.
 
The subfolders in methods refer to a specific method. Their structure is similar to parameters:


* _method_assumptions.csv - indicates how to deal to estimate important (and missing from source) info,currently mainly Rest of the World and China info on labour
* _method_matrices.csv - indicates how to deal mainly to infer Kapital and Depreciation Matrices
* _method_solutions.csv - indicates variables to be calculated and corresponding procedure for the estimate
 
 Additionaly, there is a sectors.csv file indicating which sectors should be considered productive an unproductive.
 
 
 
 4) results - to be downloaded separatedly if one wants to check results already arrived by our team - [ink here](https://coletiva.imperialismoedependencia.org/s/NMMDyMxL8fWxfjq)
 
 The results of calculations get saved as files in subfolders named by the method that generated them.
 
 The variables are either saved in:
 
 m_io files (in values, for ex), if sectorial , m_countries, if national 
 SEA_countries and SEA_sectors arrays
 
 
 5) papers
A number would be suggested to be linked to a specific analysis for, say, a paper
From results, one can filter some indicators, regions, and produce new calculus - for example in reference paper, we estimate all distance measures from market prices and direct prices



6) R

Folder with  scripts

- lib
- modules
  - assumptions
  - matrices
  - reduced_matrices
  - variables
-utils

each subfolder will be structured in common and source or method specific scripts.
