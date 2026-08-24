# Native input-output matrix modules ---------------------------------------

wlv_native_filters_contract <- function() {
  wlv_native_array_contract(
    scope = "run",
    axes = c("filter", "input", "output"),
    missingness = "none"
  )
}

wlv_matrix_transformation_spec <- wlv_module_spec(
  id = "matrix.transformation",
  scope = "io_period",
  checkpoint = 3L,
  operations = "calculate",
  requires = c(
    wlv_native_source_io_ref(),
    wlv_native_io_ref("k_depreciation"),
    wlv_native_indicator_ref("abstract_labour.emp.s.mv", "abstract_labour"),
    wlv_native_indicator_ref("gross_output.s.us", "gross_output"),
    wlv_native_run_ref("dimensions/lists", "lists", "list"),
    wlv_native_run_ref("dimensions/nums", "nums", "list"),
    wlv_native_run_ref("dimensions/rows", "rows", "data.frame"),
    wlv_native_run_ref("request/method", "method", "character")
  ),
  provides = c(
    wlv_native_io_output("values"),
    wlv_native_intermediate_output(
      "lambda",
      axes = c("year", "input")
    )
  ),
  services = "contract_runtime",
  run = function(ctx) {
    m_io_source <- ctx$input("source_io")
    k_depreciation <- ctx$input("k_depreciation")
    abstract_labour <- ctx$input("abstract_labour")
    gross_output_sector <- ctx$input("gross_output")
    lists <- ctx$input("lists")
    nums <- ctx$input("nums")
    rows <- ctx$input("rows")
    method <- ctx$input("method")
    contract_runtime <- ctx$service("contract_runtime")

    year_count <- nums$years
    input_count <- nums$input
    productive <- as.logical(rows$productive)
    productive_indices <- which(productive)
    productive_labels <- lists$input[productive_indices]

    leontief_numerator_for_year <- function(year_index) {
      intermediate_consumption <- matrix(
        m_io_source[
          year_index,
          productive_indices,
          productive_indices,
          drop = FALSE
        ],
        nrow = length(productive_indices),
        ncol = length(productive_indices),
        dimnames = list(productive_labels, productive_labels)
      )
      depreciation <- matrix(
        k_depreciation[
          year_index,
          productive_indices,
          productive_indices,
          drop = FALSE
        ],
        nrow = length(productive_indices),
        ncol = length(productive_indices),
        dimnames = list(productive_labels, productive_labels)
      )
      wlv_sum_input_flows(intermediate_consumption, depreciation)
    }

    # Preserve the labelled sector/country shape during the contractual
    # division. The legacy scientific path only flattens the same values for
    # the Leontief solve after the missingness/state operation has completed.
    labour_denominator <- gross_output_sector
    gross_output <- newDim(
      gross_output_sector,
      c(year_count, input_count)
    )
    dimnames(gross_output) <- list(lists$years, lists$input)

    zero_output_scans <- vector("list", year_count)
    for (year_index in seq_len(year_count)) {
      annual_numerator <- leontief_numerator_for_year(year_index)
      zero_output_scans[[year_index]] <- wlv_scan_leontief_zero_output_year(
        numerator_block = annual_numerator,
        gross_output = gross_output[year_index, ],
        productive = productive,
        year_index = year_index,
        year_count = year_count,
        inputs = lists$input,
        outputs = lists$input
      )
    }
    zero_output_profile <- wlv_combine_leontief_zero_output_scans(
      zero_output_scans,
      years = lists$years,
      inputs = lists$input,
      outputs = lists$input
    )
    zero_output_profile <- wlv_validate_leontief_zero_output_profile(
      contract_runtime,
      zero_output_profile
    )
    wlv_record_leontief_zero_output_profile(
      contract_runtime,
      zero_output_profile,
      include_both_zero = TRUE
    )

    labour_numerator <- abstract_labour *
      rep(rows$productive, each = year_count)
    labour_requirements <- wlv_safe_divide_runtime(
      contract_runtime,
      labour_numerator,
      labour_denominator,
      zero = "zero_if_both_zero",
      artifact = "sea_sectors",
      indicator = "labour_requirements",
      checkpoint = "after_matrices",
      stage = 3L,
      module = "matrix.transformation",
      axes = c(year = 1L, sector = 2L)
    )
    labour_requirements <- newDim(
      labour_requirements,
      c(year_count, input_count)
    )
    dimnames(labour_requirements) <- list(lists$years, lists$input)

    lambda <- labour_requirements
    diagnostic_rows <- vector("list", year_count)
    for (year_index in seq_len(year_count)) {
      annual_numerator <- leontief_numerator_for_year(year_index)
      annual_output <- gross_output[year_index, productive_indices]
      zero_output <- annual_output == 0
      invalid <- matrix(
        zero_output,
        nrow = nrow(annual_numerator),
        ncol = length(zero_output),
        byrow = TRUE
      ) & annual_numerator != 0
      if (any(invalid)) annual_numerator[invalid] <- 0
      coefficients <- annual_numerator
      if (any(!zero_output)) {
        coefficients[, !zero_output] <- sweep(
          annual_numerator[, !zero_output, drop = FALSE],
          2L,
          annual_output[!zero_output],
          "/"
        )
      }
      if (any(zero_output)) coefficients[, zero_output] <- 0
      dimnames(coefficients) <- list(productive_labels, productive_labels)
      result <- wlv_solve_leontief(
        coefficient_matrix = coefficients,
        labour_requirements = stats::setNames(
          as.numeric(labour_requirements[year_index, ]),
          lists$input
        ),
        productive = productive,
        gross_output = stats::setNames(
          as.numeric(gross_output[year_index, ]),
          lists$input
        ),
        method = method,
        year = lists$years[[year_index]]
      )
      lambda[year_index, ] <- result$lambda
      diagnostic_rows[[year_index]] <- result$diagnostics
    }
    leontief_diagnostics <- do.call(rbind, diagnostic_rows)
    row.names(leontief_diagnostics) <- NULL

    values <- m_io_source * rep(lambda, times = nums$output)
    values <- wlv_native_with_named_axes(values, c("year", "input", "output"))
    lambda <- wlv_native_with_named_axes(lambda, c("year", "input"))
    wlv_module_result(
      outputs = list(value = values, lambda = lambda),
      diagnostics = list(`_leontief_diagnostics.csv` = leontief_diagnostics)
    )
  }
)

wlv_matrix_transfers_spec <- wlv_module_spec(
  id = "matrix.transfers",
  scope = "io_period",
  checkpoint = 3L,
  operations = "calculate",
  requires = c(
    wlv_native_source_io_ref(),
    wlv_native_io_ref("values"),
    list(filters = wlv_resource_ref(
      "dimensions/io_filters",
      wlv_native_filters_contract(),
      producer = wlv_runtime_seed_producer
    )),
    wlv_native_run_ref("dimensions/nums", "nums", "list")
  ),
  provides = c(
    wlv_native_io_output("transfers_values"),
    wlv_native_intermediate_output("balance_factor", axes = "year")
  ),
  run = function(ctx) {
    source_io <- ctx$input("source_io")
    values <- ctx$input("values")
    filters <- ctx$input("filters")
    nums <- ctx$input("nums")
    trade <- filters["trade", , ]
    productive_trade <- trade * filters["productive_sectors", , ]
    trade_repeated <- rep(trade, each = nums$years)
    productive_trade_repeated <- rep(productive_trade, each = nums$years)
    numerator <- apply(
      newDim(values * trade_repeated, c(nums$years, nums$input, nums$output)),
      1L,
      sum,
      na.rm = TRUE
    )
    denominator <- apply(
      newDim(
        source_io * productive_trade_repeated,
        c(nums$years, nums$input, nums$output)
      ),
      1L,
      sum,
      na.rm = TRUE
    )
    balance_factor <- numerator / denominator
    transfers <- (source_io * trade_repeated * balance_factor) -
      (values * trade_repeated)
    transfers <- wlv_native_with_named_axes(
      transfers,
      c("year", "input", "output")
    )
    balance_factor <- array(
      balance_factor,
      dim = length(balance_factor),
      dimnames = list(year = dimnames(source_io)[[1L]])
    )
    wlv_module_result(outputs = list(
      value = transfers,
      balance_factor = balance_factor
    ))
  }
)

wlv_matrix_basket_spec <- function(id, international = FALSE) {
  wlv_module_spec(
    id = id,
    scope = "io_period",
    checkpoint = 3L,
    operations = "calculate",
    requires = c(
      wlv_native_source_io_ref(),
      wlv_native_run_ref("dimensions/nums", "nums", "list"),
      wlv_native_run_ref("dimensions/columns", "columns", "data.frame"),
      wlv_native_run_ref("labels/demands", "demands", "data.frame")
    ),
    provides = wlv_native_io_output("consumption_basket"),
    run = local({
      use_international <- international
      function(ctx) {
        source_io <- ctx$input("source_io")
        nums <- ctx$input("nums")
        columns <- ctx$input("columns")
        demands <- ctx$input("demands")
        if (use_international) {
          demand_columns <- grep("c37", columns$sector)
          basket <- source_io[, seq_len(nums$input), demand_columns, drop = FALSE]
          basket <- newDim(basket, c(nums$years, nums$input, nums$countries))
          basket <- apply(basket, 1L, rowSums, na.rm = TRUE)
          basket <- prop.table(basket, margin = 2L)
          basket <- rep(basket, each = nums$countries_sectors)
          basket <- newDim(basket, c(nums$input, nums$input, nums$years))
          basket <- aperm(basket, c(3L, 2L, 1L))
        } else {
          demand_columns <- grep(demands$demand[[1L]], columns$sector)
          basket <- source_io[, seq_len(nums$input), demand_columns, drop = FALSE]
          basket <- newDim(basket, c(nums$years, nums$input, nums$countries))
          basket <- apply(basket, 1L, prop.table, margin = 2L)
          basket <- rep(basket, each = nums$sectors)
          basket <- newDim(
            basket,
            c(
              nums$sectors, nums$sectors, nums$countries, nums$countries,
              nums$years
            )
          )
          basket <- aperm(basket, c(5L, 2L, 3L, 1L, 4L))
          basket <- newDim(basket, c(nums$years, nums$input, nums$input))
        }
        dimnames(basket) <- list(
          year = dimnames(source_io)[[1L]],
          input = dimnames(source_io)[[2L]],
          output = dimnames(source_io)[[2L]]
        )
        # The public matrix keeps the complete source output axis. As in the
        # legacy preallocated `m_io`, only the inter-industry block is filled;
        # final-demand columns remain explicitly missing.
        complete <- array(
          NA_real_,
          dim = dim(source_io),
          dimnames = dimnames(source_io)
        )
        names(dimnames(complete)) <- c("year", "input", "output")
        complete[, , seq_len(nums$input)] <- basket
        wlv_module_result(outputs = list(value = complete))
      }
    })
  )
}

wlv_matrix_basket_national_spec <- wlv_matrix_basket_spec(
  "matrix.basket.national",
  international = FALSE
)
wlv_matrix_basket_international_spec <- wlv_matrix_basket_spec(
  "matrix.basket.international",
  international = TRUE
)

wlv_matrix_zero_depreciation_spec <- function(id) {
  wlv_module_spec(
    id = id,
    scope = "io_period",
    checkpoint = 3L,
    operations = "calculate",
    requires = wlv_native_io_ref(
      "k_depreciation",
      producer = "matrix.capital"
    ),
    provides = wlv_native_io_output(
      "k_depreciation",
      action = "replace",
      predecessor = "matrix.capital"
    ),
    run = function(ctx) {
      value <- ctx$input("k_depreciation")
      value[] <- 0
      wlv_module_result(outputs = list(value = value))
    }
  )
}

wlv_matrix_zero_depreciation_wiodr13_spec <-
  wlv_matrix_zero_depreciation_spec("matrix.depreciation.zero.wiodr13")
wlv_matrix_zero_depreciation_wiodr16_spec <-
  wlv_matrix_zero_depreciation_spec("matrix.depreciation.zero.wiodr16")
