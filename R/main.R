###############################################################################
#                                                                             #
#                       World Labour Values Database                          #
#                                                                             #
###############################################################################

source("R/lib/catalog.R", local = TRUE)
source("R/lib/dependencies.R", local = TRUE)
source("R/lib/missingness.R", local = TRUE)
source("R/lib/unit_dimensions.R", local = TRUE)
source("R/lib/aggregation_specs.R", local = TRUE)
source("R/lib/indicator_metadata.R", local = TRUE)
source("R/lib/gfcf_contracts.R", local = TRUE)
source("R/lib/gfcf_diagnostics.R", local = TRUE)
source("R/lib/leontief_diagnostics.R", local = TRUE)
source("R/lib/scientific_validation.R", local = TRUE)
source("R/lib/result_contracts.R", local = TRUE)
source("R/lib/source_manifest.R", local = TRUE)
source("R/lib/source_normalization.R", local = TRUE)
source("R/lib/publication_manifest.R", local = TRUE)
source("R/lib/publication.R", local = TRUE)
source("R/lib/publication_retention.R", local = TRUE)
source("R/lib/execution.R", local = TRUE)

method_catalog <- wlv_load_catalog(".")
method_list <- wlv_catalog_method_table(method_catalog)$method

prepare_wlv <- function(methods = "wiodr13", allow_experimental = FALSE) {
  plan <- wlv_validate_request(
    methods = methods,
    repeat_pp = TRUE,
    workers = 1L,
    mode = "calculate",
    requested_operations = "prepare",
    allow_experimental = allow_experimental,
    catalog = method_catalog
  )
  wlv_assert_dependencies(include_preparation = TRUE)
  plan <- wlv_execute_preparation_plan(plan)

  invisible(plan$method_names)
}

get_wlv <- function(
    methods = "wiodr13",
    repeat_pp = FALSE,
    papern = 0,
    prepaper = FALSE,
    workers = getOption("wlv.workers", 1L),
    channel = getOption("wlv.channel", "stable"),
    allow_experimental = FALSE) {
  plan <- wlv_validate_request(
    methods = methods,
    repeat_pp = repeat_pp,
    papern = papern,
    prepaper = prepaper,
    workers = workers,
    channel = channel,
    mode = "calculate",
    allow_experimental = allow_experimental,
    catalog = method_catalog
  )
  wlv_assert_dependencies(
    include_preparation = plan$repeat_pp,
    include_papers = plan$prepaper
  )

  execution <- wlv_execute_run_plan(plan)
  plan <- execution$plan
  run_environments <- execution$run_environments

  if (plan$prepaper) {
    wlv_run_paper(
      plan,
      run_environments[[length(run_environments)]],
      release = execution$release
    )
  }

  invisible(plan$method_names)
}

recalc_wlv <- function(
    methods = "wiodr13",
    at_stage = 1,
    sea_vars = NULL,
    papern = 0,
    prepaper = FALSE,
    workers = getOption("wlv.workers", 1L),
    channel = getOption("wlv.channel", "stable"),
    allow_experimental = FALSE) {
  plan <- wlv_validate_request(
    methods = methods,
    papern = papern,
    prepaper = prepaper,
    workers = workers,
    channel = channel,
    mode = "recalculate",
    at_stage = at_stage,
    sea_vars = sea_vars,
    allow_experimental = allow_experimental,
    catalog = method_catalog
  )
  wlv_assert_dependencies(include_papers = plan$prepaper)
  execution <- wlv_execute_run_plan(plan)
  plan <- execution$plan
  run_environments <- execution$run_environments

  if (plan$prepaper) {
    wlv_run_paper(
      plan,
      run_environments[[length(run_environments)]],
      release = execution$release
    )
  }

  invisible(plan$method_names)
}
