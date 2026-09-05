###############################################################################
#                                                                             #
#                       World Labour Values Database                          #
#                                                                             #
###############################################################################

# Public API definitions. This file is loaded last by R/bootstrap.R into the
# private runtime namespace. It contains definitions only: repository-backed
# catalog data is loaded afresh for each public operation.

wlv_runtime_catalog <- function() {
  wlv_assert_loaded_runtime_unchanged()
  wlv_load_catalog(.wlv_runtime_root())
}

prepare_wlv <- function(methods = "wiodr13", allow_experimental = FALSE) {
  catalog <- wlv_runtime_catalog()
  plan <- wlv_validate_request(
    methods = methods,
    repeat_pp = TRUE,
    workers = 1L,
    mode = "calculate",
    requested_operations = "prepare",
    root = .wlv_runtime_root(),
    allow_experimental = allow_experimental,
    catalog = catalog
  )
  wlv_assert_dependencies(include_preparation = TRUE, attach = FALSE)
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
  catalog <- wlv_runtime_catalog()
  plan <- wlv_validate_request(
    methods = methods,
    repeat_pp = repeat_pp,
    papern = papern,
    prepaper = prepaper,
    workers = workers,
    channel = channel,
    mode = "calculate",
    root = .wlv_runtime_root(),
    allow_experimental = allow_experimental,
    catalog = catalog
  )
  wlv_assert_dependencies(
    include_preparation = plan$repeat_pp,
    attach = FALSE
  )

  execution <- wlv_execute_run_plan(plan)
  plan <- execution$plan

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
  catalog <- wlv_runtime_catalog()
  plan <- wlv_validate_request(
    methods = methods,
    papern = papern,
    prepaper = prepaper,
    workers = workers,
    channel = channel,
    mode = "recalculate",
    at_stage = at_stage,
    sea_vars = sea_vars,
    root = .wlv_runtime_root(),
    allow_experimental = allow_experimental,
    catalog = catalog
  )
  wlv_assert_dependencies(attach = FALSE)
  execution <- wlv_execute_run_plan(plan)
  plan <- execution$plan

  invisible(plan$method_names)
}
