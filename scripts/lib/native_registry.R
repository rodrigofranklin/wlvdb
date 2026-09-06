# Deterministic native module registry -------------------------------------

wlv_native_assumption_specs <- function() {
  list(
    wlv_assumption_china_reduction_spec(),
    wlv_assumption_china_wiodr13_spec(),
    wlv_assumption_china_wiodr16_spec(),
    wlv_assumption_row_none_spec(),
    wlv_assumption_row_reduction_spec(),
    wlv_assumption_row_standard_spec(),
    wlv_assumption_row_v09_spec()
  )
}

wlv_native_matrix_specs <- function() {
  c(
    wlv_native_capital_matrix_specs(),
    list(
      wlv_matrix_transformation_spec(),
      wlv_matrix_transfers_spec(),
      wlv_matrix_basket_national_spec(),
      wlv_matrix_basket_international_spec(),
      wlv_matrix_zero_depreciation_wiodr13_spec(),
      wlv_matrix_zero_depreciation_wiodr16_spec(),
      wlv_reduced_exports_values_spec(),
      wlv_reduced_exports_mp_spec(),
      wlv_reduced_exports_productive_mp_spec(),
      wlv_reduced_transfers_values_spec(),
      wlv_reduced_transfers_productive_values_spec(),
      wlv_reduced_transfers_dp_spec(),
      wlv_reduced_transfers_productive_dp_spec()
    )
  )
}

wlv_native_infrastructure_specs <- function() {
  list(
    wlv_native_aggregation_spec(),
    wlv_native_matrix_assembler_spec(),
    wlv_native_panel_assembler_spec()
  )
}

wlv_native_module_specs <- function() {
  specs <- c(
    wlv_native_assumption_specs(),
    wlv_native_matrix_specs(),
    wlv_native_indicator_specs(),
    wlv_native_infrastructure_specs()
  )
  ids <- vapply(specs, function(spec) spec$id, character(1L))
  if (anyDuplicated(ids)) {
    stop(
      sprintf(
        "Native registry repeats module ID(s): %s.",
        paste(unique(ids[duplicated(ids)]), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  specs
}

wlv_native_registry <- function() {
  wlv_module_registry(wlv_native_module_specs())
}

wlv_native_assert_registry_covers_config <- function(registry, config) {
  if (!inherits(registry, "wlv_module_registry") ||
      !is.data.frame(config) || !"module_id" %in% names(config)) {
    stop("Invalid registry/configuration coverage request.", call. = FALSE)
  }
  missing <- setdiff(unique(config$module_id), names(registry$specs))
  if (length(missing)) {
    stop(
      sprintf(
        "Effective configuration refers to unregistered module(s): %s.",
        paste(sort(missing), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(config)
}
