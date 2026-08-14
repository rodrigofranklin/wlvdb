###############################################################################
#                                                                             #
#                       World Labour Values Database                          #
#                                                                             #
###############################################################################

source("R/lib/dependencies.R", local = TRUE)
source("R/lib/wiodr13_validation.R", local = TRUE)
source("R/lib/execution.R", local = TRUE)

method_list <- basename(list.dirs("methods", recursive = FALSE, full.names = TRUE))

prepare_wlv <- function(methods = "wiodr13") {
  plan <- wlv_validate_request(
    methods = methods,
    repeat_pp = TRUE,
    workers = 1L,
    mode = "calculate"
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
    workers = getOption("wlv.workers", 1L)) {
  plan <- wlv_validate_request(
    methods = methods,
    repeat_pp = repeat_pp,
    papern = papern,
    prepaper = prepaper,
    workers = workers,
    mode = "calculate"
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
    workers = getOption("wlv.workers", 1L)) {
  plan <- wlv_validate_request(
    methods = methods,
    papern = papern,
    prepaper = prepaper,
    workers = workers,
    mode = "recalculate",
    at_stage = at_stage,
    sea_vars = sea_vars
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
