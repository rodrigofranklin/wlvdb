###############################################################################
#                                                                             #
#                       World Labour Values Database                          #
#                                                                             #
###############################################################################

source("R/lib/catalog.R", local = TRUE)
source("R/lib/dependencies.R", local = TRUE)
source("R/lib/missingness.R", local = TRUE)
source("R/lib/result_contracts.R", local = TRUE)
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
  wlv_prepare_sources(plan)
  plan <- wlv_validate_data(plan)

  invisible(plan$method_names)
}

get_wlv <- function(
    methods = "wiodr13",
    repeat_pp = FALSE,
    papern = 0,
    prepaper = FALSE,
    workers = getOption("wlv.workers", 1L),
    allow_experimental = FALSE) {
  plan <- wlv_validate_request(
    methods = methods,
    repeat_pp = repeat_pp,
    papern = papern,
    prepaper = prepaper,
    workers = workers,
    mode = "calculate",
    allow_experimental = allow_experimental,
    catalog = method_catalog
  )
  wlv_assert_dependencies(
    include_preparation = plan$repeat_pp,
    include_papers = plan$prepaper
  )

  if (plan$repeat_pp) {
    wlv_prepare_sources(plan)
  }
  plan <- wlv_validate_data(plan)

  run_environments <- wlv_with_cluster(plan$workers, function(cluster) {
    lapply(plan$method_names, function(method) {
      message(sprintf("Calculating %s...", method))
      wlv_run_method(plan, method, cluster = cluster)
    })
  })

  if (plan$prepaper) {
    wlv_run_paper(plan, run_environments[[length(run_environments)]])
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
    allow_experimental = FALSE) {
  plan <- wlv_validate_request(
    methods = methods,
    papern = papern,
    prepaper = prepaper,
    workers = workers,
    mode = "recalculate",
    at_stage = at_stage,
    sea_vars = sea_vars,
    allow_experimental = allow_experimental,
    catalog = method_catalog
  )
  wlv_assert_dependencies(include_papers = plan$prepaper)
  plan <- wlv_validate_data(plan)

  run_environments <- wlv_with_cluster(plan$workers, function(cluster) {
    lapply(plan$method_names, function(method) {
      message(sprintf("Recalculating %s...", method))
      wlv_run_method(plan, method, cluster = cluster)
    })
  })

  if (plan$prepaper) {
    wlv_run_paper(plan, run_environments[[length(run_environments)]])
  }

  invisible(plan$method_names)
}
