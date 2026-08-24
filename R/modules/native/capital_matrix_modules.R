# Native capital-composition and depreciation matrices ---------------------
#
# EU KLEMS tables and canonical GFCF observations are run-scoped seeds.  The
# preparation layer owns all file access; these scientific modules only read
# immutable, declared resources from their contexts.

wlv_native_euklems_table_list_contract <- function(resource) {
  wlv_resource_contract(
    scope = "run",
    value_type = "list",
    unit = paste0("euklems:", resource),
    missingness = "validated_source"
  )
}

wlv_native_euklems_table_list_ref <- function(
    resource,
    alias = resource,
    producer = wlv_runtime_seed_producer) {
  stats::setNames(
    list(wlv_resource_ref(
      key = paste0("source/euklems/", resource),
      contract = wlv_native_euklems_table_list_contract(resource),
      producer = producer
    )),
    alias
  )
}

wlv_native_gfcf_observations_contract <- function() {
  wlv_resource_contract(
    scope = "run",
    value_type = "data.frame",
    unit = "million_usd",
    missingness = "validated_source"
  )
}

wlv_native_gfcf_observations_ref <- function(
    alias = "gfcf_observations",
    producer = wlv_runtime_seed_producer,
    optional = TRUE) {
  stats::setNames(
    list(wlv_resource_ref(
      key = "source/gfcf_observations",
      contract = wlv_native_gfcf_observations_contract(),
      producer = producer,
      optional = optional
    )),
    alias
  )
}

wlv_native_capital_matrix_requires <- function() {
  c(
    wlv_native_source_io_ref(),
    wlv_native_indicator_ref("gdp.s.us", "gdp"),
    wlv_native_indicator_ref("capital_stock.s.us", "capital_stock"),
    wlv_native_run_ref("dimensions/lists", "lists", "list"),
    wlv_native_run_ref("dimensions/nums", "nums", "list"),
    wlv_native_run_ref("dimensions/rows", "rows", "data.frame"),
    wlv_native_run_ref("dimensions/columns", "columns", "data.frame"),
    wlv_native_run_ref("configuration/sectors", "sectors", "data.frame"),
    wlv_native_euklems_table_list_ref("capital_weights", "capital_weights"),
    wlv_native_euklems_table_list_ref(
      "depreciation_rates",
      "depreciation_rates"
    ),
    wlv_native_gfcf_observations_ref()
  )
}

wlv_native_capital_table_for_year <- function(tables, year, resource) {
  if (
    !is.list(tables) || is.null(names(tables)) || any(!nzchar(names(tables))) ||
      anyDuplicated(names(tables))
  ) {
    stop(
      sprintf("EU KLEMS `%s` must be a uniquely year-named list.", resource),
      call. = FALSE
    )
  }
  table <- tables[[as.character(year)]]
  if (
    is.null(table) || !is.data.frame(table) ||
      !all(c("country", "sector") %in% names(table))
  ) {
    stop(
      sprintf("EU KLEMS `%s` is missing a valid table for %s.", resource, year),
      call. = FALSE
    )
  }
  table
}

wlv_native_capital_assert_dimensions <- function(
    source_io,
    gdp,
    capital_stock,
    lists,
    nums,
    rows,
    columns,
    sectors) {
  years <- dimnames(source_io)[[1L]]
  input_labels <- dimnames(source_io)[[2L]]
  output_labels <- dimnames(source_io)[[3L]]
  if (
    !is.list(lists) || !is.list(nums) ||
      !is.data.frame(rows) || !is.data.frame(columns) ||
      !is.data.frame(sectors) ||
      !all(c("countries", "sectors", "input", "output") %in% names(lists)) ||
      !all(c("countries", "sectors", "input", "output") %in% names(nums)) ||
      !all(c("country", "sector") %in% names(rows)) ||
      !all(c("sector", "country_sector") %in% names(columns)) ||
      !all(c("euklems.sector", "euklems.capital") %in% names(sectors)) ||
      !identical(as.character(lists$input), input_labels) ||
      !identical(as.character(lists$output), output_labels) ||
      !identical(as.integer(nums$input), length(input_labels)) ||
      !identical(as.integer(nums$output), length(output_labels)) ||
      !identical(as.integer(nums$countries), length(lists$countries)) ||
      !identical(as.integer(nums$sectors), length(lists$sectors)) ||
      nrow(rows) != nums$input || nrow(columns) != nums$output ||
      nrow(sectors) != nums$sectors ||
      !identical(
        as.character(rows$country),
        rep(as.character(lists$countries), each = nums$sectors)
      ) ||
      !identical(
        as.character(rows$sector),
        rep(as.character(lists$sectors), times = nums$countries)
      ) ||
      !identical(
        paste(rows$country, rows$sector, sep = "."),
        input_labels
      ) ||
      !identical(as.character(columns$country_sector), output_labels) ||
      !all(years %in% dimnames(gdp)[[1L]]) ||
      !all(years %in% dimnames(capital_stock)[[1L]]) ||
      !identical(dimnames(gdp)[[2L]], as.character(lists$sectors)) ||
      !identical(dimnames(gdp)[[3L]], as.character(lists$countries)) ||
      !identical(dimnames(capital_stock), dimnames(gdp))
  ) {
    stop(
      "Capital-matrix resources have incompatible dimensions or labels.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_native_capital_gfcf <- function(
    source_io,
    method,
    columns,
    lists,
    nums) {
  gfcf_columns <- if (identical(method, "wiodr16")) {
    wlv_wiodr16_gfcf_columns(columns$country_sector, lists$countries)
  } else {
    which(columns$sector == "c41")
  }
  if (length(gfcf_columns) != nums$countries) {
    stop(
      sprintf(
        "%s requires exactly one GFCF column per country; found %s.",
        method,
        length(gfcf_columns)
      ),
      call. = FALSE
    )
  }
  value <- wlv_wiodr_sanitize_negative_gfcf(
    source_io[, seq_len(nums$input), gfcf_columns, drop = FALSE],
    method = method
  )
  list(
    value = value,
    truncated = attr(value, "wlv.truncated_negative_gfcf", exact = TRUE)
  )
}

wlv_native_capital_gfcf_diagnostics <- function(
    observations,
    method,
    truncated) {
  if (!is.null(observations) && !is.data.frame(observations)) {
    stop("Canonical GFCF observations must be a data frame.", call. = FALSE)
  }
  selected <- if (is.null(observations)) truncated else observations
  input_unit <- if (identical(selected, truncated)) "usd" else "million_usd"
  wlv_gfcf_diagnostic_artifacts(
    selected,
    method = method,
    input_unit = input_unit
  )
}

wlv_native_capital_record_gfcf <- function(
    runtime,
    truncated,
    module) {
  if (!is.null(truncated) && nrow(truncated)) {
    wlv_record_observed_transformations(
      runtime,
      truncated,
      artifact = "m_io",
      indicator = "gross_fixed_capital_formation",
      checkpoint = "after_matrices",
      stage = 3L,
      module = module,
      coordinate_columns = c(
        year = "year", country = "country", sector = "input", output = "output"
      )
    )
  }
  invisible(runtime)
}

wlv_native_capital_wiodr13_ratio <- function(
    numerator,
    denominator,
    year,
    input_labels,
    runtime = NULL,
    module,
    use_contract = TRUE) {
  if (use_contract) {
    numerator_array <- array(
      numerator,
      dim = c(1L, length(input_labels)),
      dimnames = list(year, input_labels)
    )
    denominator_array <- array(
      denominator,
      dim = c(1L, length(input_labels)),
      dimnames = list(year, input_labels)
    )
    return(as.numeric(wlv_safe_divide_runtime(
      runtime,
      numerator_array,
      denominator_array,
      zero = "zero_if_both_zero",
      artifact = "m_io",
      indicator = "value_added_disaggregation_ratio",
      checkpoint = "after_matrices",
      stage = 3L,
      module = module,
      axes = c(year = 1L, sector = 2L)
    )))
  }
  invalid_zero <- denominator == 0 & numerator != 0
  if (any(invalid_zero)) {
    stop("WIOD13 value-added disaggregation has nonzero over zero.", call. = FALSE)
  }
  both_zero <- denominator == 0 & numerator == 0
  result <- numerator / denominator
  result[both_zero] <- 0
  result
}

wlv_native_capital_record_wiodr13_fallback <- function(
    runtime,
    gfcf,
    fallback_columns,
    year,
    input_labels,
    module) {
  if (!length(fallback_columns)) {
    return(invisible(runtime))
  }
  fallback_totals <- array(
    colSums(gfcf),
    dim = c(1L, ncol(gfcf)),
    dimnames = list(year, input_labels)
  )
  fallback_mask <- array(
    FALSE,
    dim = dim(fallback_totals),
    dimnames = dimnames(fallback_totals)
  )
  fallback_mask[1L, fallback_columns] <- TRUE
  fallback_context <- wlv_contract_context_for(
    runtime,
    artifact = "m_io",
    indicator = "capital_stock_allocation",
    checkpoint = "after_matrices",
    stage = 3L,
    module = module,
    axes = c(year = 1L, sector = 2L),
    policy_id = "wiodr13_gfcf_fallback_v1"
  )
  wlv_contract_record(
    runtime,
    wlv_contract_table(
      fallback_totals,
      fallback_mask,
      fallback_context,
      "use_national_gfcf_fallback"
    )
  )
  invisible(runtime)
}

wlv_native_capital_record_wiodr16_ratio <- function(
    runtime,
    raw_ratio,
    ratio,
    year,
    input_labels,
    module) {
  absolute_ratios <- attr(ratio, "wlv.absolute_va_ratios", exact = TRUE)
  if (!is.null(absolute_ratios) && nrow(absolute_ratios)) {
    wlv_record_observed_transformations(
      runtime,
      absolute_ratios,
      artifact = "m_io",
      indicator = "value_added_disaggregation_ratio",
      checkpoint = "after_matrices",
      stage = 3L,
      module = module,
      coordinate_columns = c(
        year = "year", country = "country", sector = "sector"
      )
    )
  }
  zero_positions <- attr(ratio, "wlv.zero_va_ratios", exact = TRUE)
  if (length(zero_positions)) {
    ratio_array <- array(
      raw_ratio,
      dim = c(1L, length(raw_ratio)),
      dimnames = list(year, input_labels)
    )
    failed <- array(
      FALSE,
      dim = dim(ratio_array),
      dimnames = dimnames(ratio_array)
    )
    failed[1L, zero_positions] <- TRUE
    ratio_context <- wlv_contract_context_for(
      runtime,
      artifact = "m_io",
      indicator = "value_added_disaggregation_ratio",
      checkpoint = "after_matrices",
      stage = 3L,
      module = module,
      axes = c(year = 1L, sector = 2L),
      policy_id = "wiodr16_va_zero_aggregate_v1"
    )
    wlv_contract_record(
      runtime,
      wlv_contract_table(
        ratio_array,
        failed,
        ratio_context,
        "replace_both_zero_with_zero"
      )
    )
  }
  invisible(runtime)
}

wlv_native_capital_record_wiodr16_fallback <- function(
    runtime,
    capital_stock,
    fallback,
    year,
    input_labels,
    module) {
  if (is.null(fallback) || !nrow(fallback)) {
    return(invisible(runtime))
  }
  stock_values <- array(
    capital_stock,
    dim = c(1L, length(input_labels)),
    dimnames = list(year, input_labels)
  )
  fallback_mask <- array(
    input_labels %in% fallback$input,
    dim = dim(stock_values),
    dimnames = dimnames(stock_values)
  )
  fallback_context <- wlv_contract_context_for(
    runtime,
    artifact = "m_io",
    indicator = "k_composition",
    checkpoint = "after_matrices",
    stage = 3L,
    module = module,
    axes = c(year = 1L, output = 2L),
    policy_id = "wiodr16_national_gfcf_fallback_v1"
  )
  wlv_contract_record(
    runtime,
    wlv_contract_table(
      stock_values,
      fallback_mask,
      fallback_context,
      "fallback_to_national_gfcf_weights"
    )
  )
  invisible(runtime)
}

wlv_native_capital_output_arrays <- function(source_io) {
  dimensions <- dim(source_io)
  labels <- dimnames(source_io)
  names(labels) <- c("year", "input", "output")
  list(
    k_composition = array(NA_real_, dim = dimensions, dimnames = labels),
    k_depreciation = array(NA_real_, dim = dimensions, dimnames = labels)
  )
}

wlv_native_capital_spec <- function(
    id,
    method,
    depreciation_year_offset,
    use_wiodr13_contract = TRUE,
    record_wiodr13_fallback = TRUE) {
  module_label <- switch(
    id,
    matrix.capital.wiodr13 = "wiodr13/euklems.R",
    matrix.capital.wiodr16 = "wiodr16/euklems.R",
    matrix.capital.reduction_problem = "wiodr13/euklems-reduction_problem.R"
  )
  wlv_module_spec(
    id = id,
    scope = "io_period",
    checkpoint = 3L,
    operations = "calculate",
    requires = wlv_native_capital_matrix_requires(),
    provides = c(
      wlv_native_io_output("k_composition", "k_composition"),
      wlv_native_io_output("k_depreciation", "k_depreciation")
    ),
    services = "contract_runtime",
    run = local({
      selected_method <- method
      depreciation_offset <- depreciation_year_offset
      selected_module <- module_label
      wiodr13_contract <- use_wiodr13_contract
      record_13_fallback <- record_wiodr13_fallback
      function(ctx) {
        source_io <- ctx$input("source_io")
        gdp <- ctx$input("gdp")
        capital_stock <- ctx$input("capital_stock")
        lists <- ctx$input("lists")
        nums <- ctx$input("nums")
        rows <- ctx$input("rows")
        columns <- ctx$input("columns")
        sectors <- ctx$input("sectors")
        capital_weights <- ctx$input("capital_weights")
        depreciation_rates <- ctx$input("depreciation_rates")
        observations <- ctx$input("gfcf_observations")
        runtime <- ctx$service("contract_runtime")

        wlv_native_capital_assert_dimensions(
          source_io,
          gdp,
          capital_stock,
          lists,
          nums,
          rows,
          columns,
          sectors
        )
        period_years <- dimnames(source_io)[[1L]]
        gfcf_result <- wlv_native_capital_gfcf(
          source_io,
          selected_method,
          columns,
          lists,
          nums
        )
        gfcf_by_country <- gfcf_result$value
        truncated_gfcf <- gfcf_result$truncated
        diagnostics <- wlv_native_capital_gfcf_diagnostics(
          observations,
          selected_method,
          truncated_gfcf
        )
        wlv_native_capital_record_gfcf(
          runtime,
          truncated_gfcf,
          selected_module
        )

        output <- wlv_native_capital_output_arrays(source_io)
        for (year in period_years) {
          local_rows <- rows
          local_rows$s_ek <- sectors$euklems.sector
          local_rows$k_ek <- sectors$euklems.capital
          country_codes <- if (identical(selected_method, "wiodr16")) {
            wlv_wiodr16_euklems_country_codes(lists$countries)
          } else {
            wlv_wiodr13_euklems_country_codes(lists$countries)
          }
          local_rows$p_ek <- rep(country_codes, each = nums$sectors)
          local_rows$pwiod_sek <- paste0(local_rows$country, local_rows$s_ek)

          ek_k <- wlv_native_capital_table_for_year(
            capital_weights,
            year,
            "capital_weights"
          )
          depreciation_year <- as.character(as.numeric(year) + depreciation_offset)
          ek_dep_rate <- wlv_native_capital_table_for_year(
            depreciation_rates,
            depreciation_year,
            "depreciation_rates"
          )
          if (identical(selected_method, "wiodr16")) {
            ek_k <- wlv_wiodr16_sanitize_euklems_weights(ek_k, year)
            truncated_weights <- attr(
              ek_k,
              "wlv.truncated_negative_weights",
              exact = TRUE
            )
            if (!is.null(truncated_weights) && nrow(truncated_weights)) {
              wlv_record_observed_transformations(
                runtime,
                truncated_weights,
                artifact = "m_io",
                indicator = "euklems_capital_weight",
                checkpoint = "after_matrices",
                stage = 3L,
                module = selected_module,
                coordinate_columns = c(
                  year = "year", country = "country", sector = "sector",
                  output = "variable"
                )
              )
            }
          }

          local_rows[!(local_rows$p_ek %in% unique(ek_k$country)), "p_ek"] <- "MD"
          local_rows$ps_ek <- paste0(local_rows$p_ek, local_rows$s_ek)
          ek_k$ps <- paste0(ek_k$country, ek_k$sector)
          if (identical(selected_method, "wiodr16")) {
            ek_dep_rate$ps <- paste0(ek_dep_rate$country, ek_dep_rate$sector)
          }

          gdp_year <- as.numeric(gdp[year, , , drop = FALSE])
          aggregates <- tapply(
            gdp_year,
            local_rows$pwiod_sek,
            sum,
            na.rm = FALSE
          )
          denominator <- as.numeric(aggregates[local_rows$pwiod_sek])
          if (identical(selected_method, "wiodr16")) {
            raw_ratio <- gdp_year / denominator
            ratio <- wlv_wiodr16_sanitize_va_ratios(
              raw_ratio,
              year,
              lists$input,
              numerator = gdp_year,
              denominator = denominator
            )
            wlv_native_capital_record_wiodr16_ratio(
              runtime,
              raw_ratio,
              ratio,
              year,
              lists$input,
              selected_module
            )
          } else {
            ratio <- wlv_native_capital_wiodr13_ratio(
              gdp_year,
              denominator,
              year,
              lists$input,
              runtime = runtime,
              module = selected_module,
              use_contract = wiodr13_contract
            )
          }

          composition <- matrix(1, nrow = nums$input, ncol = nums$input)
          depreciation <- matrix(1, nrow = nums$input, ncol = nums$input)
          composition[, seq_len(nums$input)] <- rep(
            ratio,
            each = nums$input
          )
          for (input_index in seq_len(nums$input)) {
            weight_column <- as.character(local_rows$k_ek[[input_index]])
            composition[input_index, ] <- composition[input_index, ] *
              ek_k[
                match(local_rows$ps_ek, ek_k$ps),
                weight_column
              ]
            depreciation_match <- if (identical(selected_method, "wiodr16")) {
              match(local_rows$ps_ek, ek_dep_rate$ps)
            } else {
              # The WIOD13 implementation intentionally uses the ordering key
              # from `ek_k`; parity requires preserving that historical rule.
              match(local_rows$ps_ek, ek_k$ps)
            }
            depreciation[input_index, ] <- ek_dep_rate[
              depreciation_match,
              weight_column
            ]
          }

          gfcf_year <- gfcf_by_country[year, , , drop = FALSE]
          dim(gfcf_year) <- c(nums$input, nums$countries)
          gfcf <- gfcf_year[
            , rep(seq_len(nums$countries), each = nums$sectors), drop = FALSE
          ]
          composition <- composition * gfcf
          stock_year <- as.numeric(capital_stock[year, , , drop = FALSE])
          if (identical(selected_method, "wiodr16")) {
            composition <- wlv_wiodr16_allocate_capital(
              weights = composition,
              capital_stock = stock_year,
              fallback_weights = gfcf,
              year = year,
              input_labels = lists$input
            )
            fallback <- attr(composition, "wlv.gfcf_fallbacks", exact = TRUE)
            if (!is.null(fallback) && nrow(fallback)) {
              message(sprintf(
                paste0(
                  "Used the explicit national-GFCF fallback for %s positive-stock ",
                  "sector(s) without EU KLEMS weights in %s: %s"
                ),
                nrow(fallback),
                year,
                paste(utils::head(fallback$input, 6L), collapse = ", ")
              ))
              wlv_native_capital_record_wiodr16_fallback(
                runtime,
                stock_year,
                fallback,
                year,
                lists$input,
                selected_module
              )
            }
            attr(composition, "wlv.gfcf_fallbacks") <- NULL
          } else {
            composition <- wlv_distribute_capital_stock(
              composition,
              stock_year,
              fallback_weights = gfcf
            )
            fallback <- attr(composition, "wlv.fallback_columns", exact = TRUE)
            if (length(fallback)) {
              message(sprintf(
                paste0(
                  "Used the explicit national-GFCF fallback for %s capital-stock ",
                  "sector(s) without primary weights in %s: %s"
                ),
                length(fallback),
                year,
                paste(utils::head(lists$input[fallback], 5L), collapse = ", ")
              ))
              if (record_13_fallback) {
                wlv_native_capital_record_wiodr13_fallback(
                  runtime,
                  gfcf,
                  fallback,
                  year,
                  lists$input,
                  selected_module
                )
              }
            }
            attr(composition, "wlv.fallback_columns") <- NULL
          }

          output$k_composition[
            year,
            seq_len(nums$input),
            seq_len(nums$input)
          ] <- composition
          output$k_depreciation[
            year,
            seq_len(nums$input),
            seq_len(nums$input)
          ] <- composition * depreciation
        }

        output$k_composition <- wlv_native_with_named_axes(
          output$k_composition,
          c("year", "input", "output")
        )
        output$k_depreciation <- wlv_native_with_named_axes(
          output$k_depreciation,
          c("year", "input", "output")
        )
        wlv_module_result(outputs = output, diagnostics = diagnostics)
      }
    })
  )
}

wlv_matrix_capital_wiodr13_spec <- wlv_native_capital_spec(
  id = "matrix.capital.wiodr13",
  method = "wiodr13",
  depreciation_year_offset = 1L,
  use_wiodr13_contract = TRUE,
  record_wiodr13_fallback = TRUE
)

wlv_matrix_capital_wiodr16_spec <- wlv_native_capital_spec(
  id = "matrix.capital.wiodr16",
  method = "wiodr16",
  depreciation_year_offset = 1L
)

wlv_matrix_capital_reduction_problem_spec <- wlv_native_capital_spec(
  id = "matrix.capital.reduction_problem",
  method = "wiodr13",
  depreciation_year_offset = 0L,
  use_wiodr13_contract = FALSE,
  record_wiodr13_fallback = FALSE
)

wlv_native_capital_matrix_specs <- function() {
  stats::setNames(
    list(
      wlv_matrix_capital_wiodr13_spec,
      wlv_matrix_capital_wiodr16_spec,
      wlv_matrix_capital_reduction_problem_spec
    ),
    c(
      "matrix.capital.wiodr13",
      "matrix.capital.wiodr16",
      "matrix.capital.reduction_problem"
    )
  )
}
