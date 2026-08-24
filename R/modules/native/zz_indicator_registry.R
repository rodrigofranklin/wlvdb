# Explicit native indicator registry --------------------------------------
#
# This inventory is intentionally declarative: the loader does not discover
# specs through `ls()` or naming conventions.
#
# Stable producer convention (also used when a recalculation hydrates parent
# resources): raw indicators use their configuration instance ID
# (`indicator.<code>`); ROW-adjusted inputs use `assumption.row`; collected
# stage-4 values use `collector.indicator.<code>`; normalized price indices use
# `normalize.indicator.<code>`. Reduction skill shares form the explicit chain
# `indicator.<skill> -> assumption.row ->
# indicator.complex_labour_multiplier.empe.r.un` when that final module
# rewrites the shares.

wlv_native_indicator_specs <- function() {
  list(
    wlv_source_indicator_spec,
    wlv_indicator_abstract_labour_emp_m_mv_spec,
    wlv_indicator_abstract_labour_emp_s_mv_spec,
    wlv_indicator_abstract_labour_empe_m_mv_spec,
    wlv_indicator_abstract_labour_empe_s_mv_spec,
    wlv_indicator_appropriated_profit_r_pc_spec,
    wlv_indicator_basket_price_r_pc_spec,
    wlv_indicator_basket_value_r_pc_spec,
    wlv_indicator_basket_zero_collector_spec,
    wlv_indicator_capital_depreciation_s_us_spec,
    wlv_indicator_capital_stock_s_cu_wiodr16_spec,
    wlv_indicator_capital_stock_s_us_wiodr13_spec,
    wlv_indicator_capital_stock_s_us_wiodr16_spec,
    wlv_indicator_compensation_emp_s_cu_spec,
    wlv_indicator_compensation_emp_s_us_spec,
    wlv_indicator_compensation_empe_s_cu_spec,
    wlv_indicator_compensation_empe_s_us_spec,
    wlv_indicator_complex_labour_multiplier_emp_spec,
    wlv_indicator_complex_labour_multiplier_empe_spec,
    wlv_indicator_complex_emp_alternative_1_spec,
    wlv_indicator_complex_emp_alternative_2_spec,
    wlv_indicator_complex_emp_ochoa_1_spec,
    wlv_indicator_complex_emp_ochoa_2_spec,
    wlv_indicator_complex_emp_petrovic_spec,
    wlv_indicator_complex_empe_alternative_1_spec,
    wlv_indicator_complex_empe_alternative_2_spec,
    wlv_indicator_complex_empe_ochoa_1_spec,
    wlv_indicator_complex_empe_ochoa_2_spec,
    wlv_indicator_complex_empe_petrovic_spec,
    wlv_indicator_exchange_r_id_v09_spec,
    wlv_indicator_exchange_r_id_wiod_spec,
    wlv_indicator_exchange_r_us_v09_spec,
    wlv_indicator_exchange_r_us_wiod_spec,
    wlv_indicator_exports_s_mv_spec,
    wlv_indicator_exports_s_us_spec,
    wlv_indicator_gdp_p_s_us_spec,
    wlv_indicator_gdp_s_du_spec,
    wlv_indicator_gdp_s_mv_spec,
    wlv_indicator_go_price_r_id_wiodr16_spec,
    wlv_indicator_gross_output_s_du_spec,
    wlv_indicator_gross_output_s_mv_spec,
    wlv_indicator_hours_worked_emp_s_hr_wiodr16_spec,
    wlv_indicator_imports_s_mv_spec,
    wlv_indicator_imports_s_us_spec,
    wlv_indicator_labour_force_value_emp_m_mv_spec,
    wlv_indicator_labour_force_value_emp_s_mv_spec,
    wlv_indicator_labour_force_value_m_mv_spec,
    wlv_indicator_labour_force_value_s_mv_spec,
    wlv_indicator_price_index_normalize_spec,
    wlv_indicator_profit_s_us_spec,
    wlv_indicator_stage4_collector_spec,
    wlv_indicator_surplus_value_emp_r_pc_spec,
    wlv_indicator_surplus_value_emp_p_r_pc_spec,
    wlv_indicator_surplus_value_empe_r_pc_spec,
    wlv_indicator_surplus_value_empe_hs_r_pc_spec,
    wlv_indicator_surplus_value_empe_ls_r_pc_spec,
    wlv_indicator_surplus_value_empe_ms_r_pc_spec,
    wlv_indicator_surplus_value_empe_p_r_pc_spec,
    wlv_indicator_trade_balance_s_mv_spec,
    wlv_indicator_trade_balance_s_us_spec,
    wlv_indicator_trade_transfers_p_m_pc_spec,
    wlv_indicator_trade_transfers_p_s_mv_spec,
    wlv_indicator_trade_transfers_s_mv_spec,
    wlv_indicator_trade_transfers_u_s_mv_spec,
    wlv_indicator_value_m_mv_spec
  )
}

wlv_native_indicator_stage4_modules <- function() {
  c(
    "indicator.basket_price.r.pc" = "basket_price.r.pc",
    "indicator.basket_value.r.pc" = "basket_value.r.pc",
    "indicator.capital_depreciation.s.us" = "capital_depreciation.s.us",
    "indicator.exports.s.mv" = "exports.s.mv",
    "indicator.exports.s.us" = "exports.s.us",
    "indicator.gross_output.s.mv" = "gross_output.s.mv",
    "indicator.imports.s.mv" = "imports.s.mv",
    "indicator.imports.s.us" = "imports.s.us",
    "indicator.labour_force_value.emp.s.mv" = "labour_force_value.emp.s.mv",
    "indicator.labour_force_value.s.mv" = "labour_force_value.s.mv",
    "indicator.trade_transfers.p.s.mv" = "trade_transfers.p.s.mv",
    "indicator.trade_transfers.s.mv" = "trade_transfers.s.mv",
    "indicator.value.m.mv" = "value.m.mv"
  )
}

wlv_native_indicator_auxiliary_instances <- function(
    config,
    partitions,
    go_price_predecessor = "assumption.row") {
  if (!is.data.frame(config) ||
      !all(c("instance_id", "module_id") %in% names(config))) {
    stop("`config` must be a resolved module configuration.", call. = FALSE)
  }
  partitions <- wlv_runtime_validate_names(partitions, "partitions", allow_empty = FALSE)
  go_price_predecessor <- wlv_runtime_scalar_character(
    go_price_predecessor,
    "go_price_predecessor",
    wlv_runtime_identifier_pattern
  )
  stage4_map <- wlv_native_indicator_stage4_modules()
  selected <- which(config$module_id %in% names(stage4_map))
  result <- lapply(selected, function(index) {
    instance_id <- config$instance_id[[index]]
    module_id <- config$module_id[[index]]
    wlv_module_instance(
      instance_id = paste0("collector.", instance_id),
      module_id = "indicator.stage4_collector",
      args = list(indicator = unname(stage4_map[[module_id]]))
    )
  })

  basket_selected <- "indicator.basket_price.r.pc" %in% config$module_id ||
    "indicator.basket_value.r.pc" %in% config$module_id
  if (basket_selected) {
    result[[length(result) + 1L]] <- wlv_module_instance(
      "indicator.basket_zero.collector",
      "indicator.basket_zero.collector",
      args = list(base_year = "first")
    )
  }

  if ("indicator.basket_price.r.pc" %in% config$module_id) {
    result[[length(result) + 1L]] <- wlv_module_instance(
      "normalize.indicator.basket_price.r.pc",
      "indicator.price_index.normalize",
      args = list(
        indicator = "basket_price.r.pc",
        predecessor = "collector.indicator.basket_price.r.pc",
        base_year = "2000",
        copy_usa_to_row = FALSE
      )
    )
  }
  if ("indicator.basket_value.r.pc" %in% config$module_id) {
    result[[length(result) + 1L]] <- wlv_module_instance(
      "normalize.indicator.basket_value.r.pc",
      "indicator.price_index.normalize",
      args = list(
        indicator = "basket_value.r.pc",
        predecessor = "collector.indicator.basket_value.r.pc",
        base_year = "2000",
        copy_usa_to_row = FALSE
      )
    )
  }
  if ("indicator.go_price.r.id.wiodr16" %in% config$module_id ||
      any(config$instance_id == "indicator.go_price.r.id")) {
    result[[length(result) + 1L]] <- wlv_module_instance(
      "normalize.indicator.go_price.r.id",
      "indicator.price_index.normalize",
      args = list(
        indicator = "go_price.r.id",
        predecessor = go_price_predecessor,
        base_year = "2000",
        copy_usa_to_row = TRUE
      )
    )
  }
  ids <- vapply(result, function(instance) instance$instance_id, character(1L))
  if (anyDuplicated(ids)) {
    stop("Native indicator auxiliary instance IDs are not unique.", call. = FALSE)
  }
  attr(result, "partitions") <- partitions
  attr(result, "primary_argument_overrides") <- list(
    "indicator.basket_price.r.pc" = list(
      go_price_producer = go_price_predecessor
    ),
    "indicator.basket_value.r.pc" = list(
      go_price_producer = go_price_predecessor
    )
  )
  result
}
