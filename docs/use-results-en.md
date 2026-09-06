# Use, interpret and cite the results

<!-- documentation-revision: wiod-reader-workflows-v2 -->

[Português](use-results-pt.md) | English | [Home](../README.md) | [Indicator families](indicator-families-en.md) | [Dictionary](results-dictionary-en.md)

## Start with the data

WLVDB results are available through [World Labour Values](https://panel.worldlabourvalues.org/)
and the [LabCidades/UFES access point](http://labcidades.ufes.br/worldlabourvalues/).
Consulting and obtaining data through the website does not require installing
R, cloning the repository or recalculating world input-output matrices.

This workflow follows an analysis: formulate the question, choose an indicator,
obtain data, review coverage, interpret the result and record its provenance.
The [technical guide](guide-en.md) is the reference for native files,
installation and reproduction. [Theory](theory-en.md) and
[methodology](methodology-en.md) explain the meaning and construction of measures.

| Task | Required material | Next step |
| --- | --- | --- |
| Consult or analyse through the website | Browser and a record of the selection | Follow this chapter through the data note; R is optional. |
| Analyse an export | Obtained file, descriptions, units and selection identity | Read its format and preserve the scale declared in the export. |
| Read a native publication in R | Repository, restored packages and complete publication tree | Follow this chapter's FST example. |
| Reconstruct the database | Code, pinned statistical sources and computing resources | Follow [run the project](guide-en.md#run-the-project). |

An analysis export and a native publication are different products. A tabular
file may suffice for a study; it does not replace the manifests, channels,
releases, runs and sidecars required by the native reader or WLVPanel. Inspect
the files actually obtained before choosing a reader. Do not rename a CSV to FST.

## Turn the question into a selection

A well-defined introductory question is: **how did the surplus-value rate of
employees in industries classified as productive in Brazil evolve from 1995
to 2007, according to `wiodr13`?** Its selection is:

| Field | Choice and meaning |
| --- | --- |
| Method | `wiodr13`, distinguishing this release from `wiodr16`. |
| Country | Brazil, code `BRA`; distinguish it from `ROW` and `WWW`. |
| Indicator | `surplus_value.empe_p.r.pc`: employees, productive industries, labour divided by reproduction value minus one. |
| Period | 1995–2007, an initial selection consistent with the WIOD13 coverage presented by the panel. |
| Reading unit | Percentage rate; the native file stores the ratio before display scaling. |
| Aggregation | The already calculated national rate, not an arithmetic mean of industry rates. |

Use these criteria in the query and record them when obtaining data. Preserve
the original export and analyse a copy. Record displayed labels alongside
codes: similarly named industries do not establish a correspondence between
WIOD13 and WIOD16.

WIOD13 calculation coverage extends to 2009, but 2008–2009 have capital-data
limitations, including compatibility zeros that can produce finite results.
The panel excludes those years from its WIOD13 series. The selection above
is a conservative first exercise, not a claim that every other year and
indicator is free of imputations. Studying the final years requires justifying
sources, treatments and their impact; consult the [assumptions](assumptions-en.md).

## Check scale, coverage and meaning

Before interpreting the series, inspect its definition in the
[indicator-family cards](indicator-families-en.md) and dictionary. Distinguish
a stored ratio from its presentation. Under the native contract, 1.5 can be
displayed as 150%. An export already containing 150% must not be multiplied by
100 again. The `.pc` suffix cannot resolve this distinction: it also appears
in indicators following other historical conventions.

For each series, record method, indicator, unit, period, population and
productive filter. For each observation, retain the original value and its
condition for use. `NA` is not zero; a finite number does not prove full coverage.

| Evidence | Analysis decision |
| --- | --- |
| `source_missing` or `not_applicable` | Preserve the absence and reason; do not automatically interpolate or fill it. |
| Anomaly or partial coverage | Read the rule and affected components; record inclusion/exclusion and a justification. An anomaly may be a known treatment rather than an error. |
| Aggregate rate with missing components | Inspect numerator and denominator separately and evaluate a common-coverage comparison. |
| Export without diagnostics or technical identifiers | Record which metadata were and were not supplied; do not invent a `run_id`, hash or cell state. |
| Change of source, classification, assumption or contract | Keep series separate until an explicit correspondence is established. |

An export supports analysis of the fields it contains. Auditing sources,
imputations or publication integrity requires the corresponding documents and
artifacts. An auxiliary file missing from an export does not prove the absence
of problems or, by itself, invalidate every analysis of that export.

## Interpret before comparing

In a **hypothetical** example, 250 hours of labour and a reproduction basket
containing 100 hours yield `250 / 100 - 1 = 1.5`, or 150%. Estimated surplus
labour is 1.5 times estimated reproduction value under the method's assumptions.
This does not mean 150 hours, a profit rate of 150%, or independent proof of
superexploitation.

Moving from 150% to 160% is a change of **10 percentage points**. The relative
change in the rate is approximately 6.67%, a different question. None of these
hypothetical numbers is a result for Brazil.

Choosing `surplus_value.empe.r.pc` adds employees in unproductive industries.
Choosing `emp` also includes non-employees and the treatment of their labour
compensation. These are not merely alternative display labels. The
[theory chapter](theory-en.md) clarifies the scope of interpreting exploitation
under each population definition.

## Read a native publication in R

This section is optional for website users. Run the blocks from the repository
root after restoring packages and obtaining a complete native publication in
`results/`. [Installation](guide-en.md#installation-and-preparation) and the
[publication contract](result-publication.md) explain the prerequisites.
The example neither downloads panel files nor assumes an export API.

```r
source("renv/activate.R")
bootstrap <- new.env(parent = baseenv())
sys.source("scripts/runtime_bootstrap.R", envir = bootstrap)
wlv <- bootstrap$wlv_load_runtime(".")
method <- "wiodr13"
run_dir <- wlv$wlv_current_result_dir(method, root = ".", channel = "stable")
countries <- wlv$read_fst_array(file.path(run_dir, "sea_countries.fst"))
units <- read.csv2(file.path(run_dir, "_unit_contract.csv"), stringsAsFactors = FALSE)
states <- read.csv2(file.path(run_dir, "_states.csv"), stringsAsFactors = FALSE)
anomalies <- read.csv2(file.path(run_dir, "_anomalies.csv"), stringsAsFactors = FALSE)
example <- new.env(parent = baseenv())
sys.source("scripts/examples/analysis_review.R", envir = example)
report <- example$wlv_example_review_series(
  countries, units, states, anomalies,
  method = method, country = "BRA",
  indicator = "surplus_value.empe_p.r.pc", years = 1995:2007
)
print(report$series)
print(report$states)
print(utils::head(report$anomalies, 20L))
```

The public reader resolves the publication before analysis. The example helper
only organizes review: it does not authenticate files itself, recalculate
indicators or alter published results. It links each `NA` to the series state
and rejects an absence without a state, a state attached to a finite value,
duplicate states, ambiguous scale, `NaN` and infinities.

The output retains **every year in the file**, including years outside the
initial question. `in_requested_period` marks the scope;
`wiodr13_coverage_alert` identifies the final years; `candidate_by_scope` marks
candidates, not scientifically approved observations. `decision` starts as
`pending` for candidates and `exclude` otherwise, with a reason in `reason`.

Anomaly events are retained for all countries in relevant years, including
events without a specific year. This matters because an imputation outside
Brazil can affect world labour requirements. Counts are review pointers, not
weights, significance tests or quality scores. `head()` is only a preview:
inspect the complete table before deciding.

After reading diagnostics and operand coverage, record `include` or `exclude`
in `report$series$decision` and a justification in `reason` for each candidate.
You can edit a review copy in your analysis project. **Do not approve every
candidate simply because it is finite.** Run the following block only after
that review; it rejects pending decisions and out-of-scope inclusions.

```r
review <- report$series
stopifnot(
  all(review$decision %in% c("include", "exclude")),
  all(!is.na(review$reason) & nzchar(trimws(review$reason))),
  !any(review$decision == "include" & !review$candidate_by_scope),
  !any(review$decision == "include" & review$reason == "pending_scientific_review")
)
analysis <- review[review$decision == "include", , drop = FALSE]
print(analysis[, c("year", "stored_value", "display_value", "display_unit", "reason")])
```

Preserve `review`, complete diagnostics and manifests with the final selection.
Save derivatives in your analysis project, or in a `temp/<id>/` campaign when
working inside this repository; never inside the published run. The example
does not choose an output directory or silently write files.

## Compare ratios on common coverage

The standard calculation of some rates sums operands independently. A world
persons-engaged rate can therefore include imputed ROW hours without the
corresponding reproduction costs. The rules are documented in
[methodology](methodology-en.md) and [missingness](missingness.md).

A sensitivity analysis can select the **same complete coordinates** for both
operands, preserving the population and productive filter of the question.
This changes coverage and requires its own label; it is neither a silent
correction of the published rate nor an estimate of the missing population.
For industry-level gaps, use industry data: a finite national rate alone
does not reveal which industries contributed to each operand.

The following example is self-contained, uses base R and **hypothetical data**.
A second group has known hours but missing reproduction costs. The ratio of
independent sums is 300%; in the group with both operands, it is 100%.

```r
example <- new.env(parent = baseenv())
sys.source("scripts/examples/analysis_review.R", envir = example)
H <- c(100, 100)
V <- c(50, NA_real_)
independent_rate <- sum(H, na.rm = TRUE) / sum(V, na.rm = TRUE) - 1
matched <- example$wlv_example_common_coverage(H, V)
stopifnot(independent_rate == 3, matched$rate == 1,
          identical(matched$excluded, 2L))
print(c(independent_percent = 100 * independent_rate,
        common_coverage_percent = 100 * matched$rate))
```

In an empirical application, report included and excluded countries/industries,
the number of complete pairs and the sample's share of known totals for each
operand. For temporal comparisons, also inspect a constant sample: coverage
varying by year can create composition effects. Excluding ROW alone does not
guarantee complete coverage of other countries. Interpretation is conditional
on the resulting sample.

## Record a reproducible data note

A data note identifies the material actually used, not just an access address.
Keep the acquisition date, file name and format, method, years, indicator codes,
population, industries/countries, units, transformations, coverage decisions
and analysis-script version. Include publication identifiers when supplied;
explicitly record fields not provided with an export.

For a native publication, also inspect:

```r
manifest <- jsonlite::fromJSON(
  file.path(run_dir, "run_manifest.json"), simplifyVector = FALSE
)
print(manifest[c("method", "run_id", "result_id", "parent_run_id")])
print(manifest$output_contract)
str(manifest$result$provenance, max.level = 2L)
```

Preserve the corresponding release and complete manifests, not only the fields
printed above. A channel such as `stable` can select another release; a file
obtained today must not be identified by a future channel state. The
[citation template](citation-en.md) distinguishes software, results, exports,
methodological publications and statistical sources, with references to adapt.

## Reproduction and contribution are separate next workflows

To reconstruct estimates, follow [run the project](guide-en.md#run-the-project).
To propose a change, follow [contribute](guide-en.md#contribute-an-improvement).
An interpretation improvement need not change formulas; a new population,
assumption or aggregation rule requires its own definition and evidence of
its effects. The helpers are checked in
`tests/testthat/test-analysis-review-example.R`; these synthetic tests do not
replace a run using real sources.
