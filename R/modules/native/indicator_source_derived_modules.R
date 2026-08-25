# Native WIOD-derived indicator modules -----------------------------------

wlv_native_exchange_us_spec <- function(id, historical_v09 = FALSE) {
  metadata <- wlv_native_indicator_metadata_row(
    "exchange.r.us",
    "Exchange rate (local currency per USD)",
    if (historical_v09) {
      "Exchange rate is the correspondence between local currency and USD."
    } else {
      "Current exchange rate measured in units of local currency per current USD (LCU/USD)."
    },
    if (historical_v09) {
      "Calculated as the implicit exchange rate of Value Added (VA in local currency / VA in USD)."
    } else {
      paste0(
        "Calculated for each country-year as total Value Added in local currency ",
        "divided by total Value Added in current USD, then broadcast to every sector. ",
        "USA totals are validated against 1 USD/USD before being canonicalized to exactly 1."
      )
    },
    "Others", "usd"
  )
  wlv_native_indicator_spec(
    id,
    checkpoint = 1L,
    requires = wlv_native_source_requirements(),
    provides = wlv_native_indicator_output("exchange.r.us"),
    services = if (historical_v09) "contract_runtime" else character(),
    metadata = metadata,
    run = local({
      historical_formula <- historical_v09
      module_name <- id
      function(ctx) {
        source <- ctx$input("source")
        lists <- ctx$input("lists")
        numerator <- wlv_native_source_variable(source, "VA", lists)
        denominator <- wlv_native_source_variable(source, "VA_USD", lists)
        value <- if (historical_formula) {
          wlv_exchange_rate_by_sector_v09(
            numerator,
            denominator,
            runtime = ctx$service("contract_runtime"),
            module = module_name
          )
        } else {
          wlv_exchange_rate_by_country(numerator, denominator)
        }
        value <- wlv_native_sector_array(value, lists)
        if (historical_formula) value[, , "USA"] <- 1
        wlv_module_result(outputs = list(value = value))
      }
    })
  )
}

wlv_indicator_exchange_r_us_wiod_spec <- function() {
  wlv_native_exchange_us_spec("indicator.exchange.r.us.wiod")
}
wlv_indicator_exchange_r_us_v09_spec <- function() {
  wlv_native_exchange_us_spec(
    "indicator.exchange.r.us.v09",
    historical_v09 = TRUE
  )
}

wlv_native_exchange_index_spec <- function(id, historical_v09 = FALSE) {
  wlv_native_indicator_spec(
    id,
    checkpoint = 1L,
    requires = c(
      wlv_native_indicator_ref(
        "exchange.r.us",
        "exchange_rate",
        producer = "indicator.exchange.r.us"
      ),
      wlv_native_run_ref("dimensions/lists", "lists", "list")
    ),
    provides = wlv_native_indicator_output("exchange.r.id"),
    metadata = wlv_native_indicator_metadata_row(
      "exchange.r.id", "Exchange rate index",
      if (historical_v09) {
        "Unitless index of the historical v0.9 sector-level local-currency-per-current-USD exchange rate, normalized to 1 in 2000."
      } else {
        "Unitless index of the local-currency-per-current-USD exchange rate, normalized to 1 in 2000."
      },
      paste0(
        "Calculated as the current country-year exchange rate (LCU/USD) divided by ",
        "that country's 2000 exchange rate. The ROW index mirrors the USA index. ",
        "The presentation scale is defined by method-specific unit metadata."
      ),
      "Others", "index"
    ),
    run = function(ctx) {
      exchange_rate <- ctx$input("exchange_rate")
      if (!"2000" %in% dimnames(exchange_rate)[[1L]]) {
        stop("Exchange-rate normalization requires base year 2000.", call. = FALSE)
      }
      value <- sweep(
        exchange_rate,
        MARGIN = c(2L, 3L),
        STATS = exchange_rate["2000", , ],
        FUN = "/"
      )
      value[, , "ROW"] <- value[, , "USA"]
      value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
      wlv_module_result(outputs = list(value = value))
    }
  )
}

wlv_indicator_exchange_r_id_wiod_spec <- function() {
  wlv_native_exchange_index_spec("indicator.exchange.r.id.wiod")
}
wlv_indicator_exchange_r_id_v09_spec <- function() {
  wlv_native_exchange_index_spec(
    "indicator.exchange.r.id.v09",
    historical_v09 = TRUE
  )
}

wlv_native_current_usd_spec <- function(id, indicator, source_variable, metadata) {
  wlv_native_indicator_spec(
    id,
    checkpoint = 1L,
    requires = wlv_native_source_requirements(
      wlv_native_indicator_ref(
        "exchange.r.us",
        "exchange_rate",
        producer = "indicator.exchange.r.us"
      )
    ),
    provides = wlv_native_indicator_output(indicator),
    metadata = metadata,
    run = local({
      variable <- source_variable
      function(ctx) {
        value <- wlv_native_source_variable(
          ctx$input("source"), variable, ctx$input("lists")
        ) / ctx$input("exchange_rate")
        value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
        wlv_module_result(outputs = list(value = value))
      }
    })
  )
}

wlv_indicator_compensation_empe_s_us_spec <- function() {
  wlv_native_current_usd_spec(
  "indicator.compensation.empe.s.us", "compensation.empe.s.us", "COMP",
  wlv_native_indicator_metadata_row(
    "compensation.empe.s.us", "Salaries and wages (USD)",
    "Remuneration received by wage and salaried workers.",
    "Converted from national currency using the exchange rate.",
    "Wages and value of labour force", "usd"
  )
)
}
wlv_indicator_compensation_emp_s_us_spec <- function() {
  wlv_native_current_usd_spec(
  "indicator.compensation.emp.s.us", "compensation.emp.s.us", "LAB",
  wlv_native_indicator_metadata_row(
    "compensation.emp.s.us", "Labour compensation (USD)",
    paste0(
      "Labour compensation expressed in market prices represents the income received ",
      "all persons engaged as a result of their labour. It includes wages, salaries, ",
      "and income received by non-waged and non-salaried workers (self-employed, etc.)."
    ),
    "Converted from national currency using the exchange rate.",
    "Wages and value of labour force", "usd"
  )
)
}
wlv_indicator_profit_s_us_spec <- function() {
  wlv_native_current_usd_spec(
  "indicator.profit.s.us", "profit.s.us", "CAP",
  wlv_native_indicator_metadata_row(
    "profit.s.us", "Profit (USD)", "Profit and others capital compensations.",
    "Converted from national currency using the exchange rate.",
    "Capital", "usd"
  )
)
}

wlv_indicator_capital_stock_s_us_wiodr13_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.capital_stock.s.us.wiodr13",
  checkpoint = 1L,
  requires = wlv_native_source_requirements(
    wlv_native_indicator_ref(
      "exchange.r.us", "exchange_rate", producer = "indicator.exchange.r.us"
    )
  ),
  provides = wlv_native_indicator_output("capital_stock.s.us"),
  metadata = wlv_native_indicator_metadata_row(
    "capital_stock.s.us", "Capital stock (USD)",
    "Capital stock is the prices in current USD of capital assets.",
    "Converted from national currency using the exchange rate.",
    "Capital", "usd"
  ),
  run = function(ctx) {
    lists <- ctx$input("lists")
    value <- wlv_native_source_variable(ctx$input("source"), "K_GFCF", lists) *
      wlv_native_source_variable(ctx$input("source"), "GFCF_P", lists) /
      ctx$input("exchange_rate")
    value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
    wlv_module_result(outputs = list(value = value))
  }
)
}

wlv_native_wiodr16_capital_spec <- function(
    id,
    indicator,
    constant = FALSE) {
  extra <- c(
    wlv_native_indicator_ref(
      "exchange.r.us", "exchange_rate", producer = "indicator.exchange.r.us"
    ),
    if (constant) wlv_native_indicator_ref(
      "go_price.r.id", "go_price", producer = "indicator.go_price.r.id"
    ) else list()
  )
  wlv_native_indicator_spec(
    id,
    checkpoint = 1L,
    requires = wlv_native_source_requirements(extra),
    provides = wlv_native_indicator_output(indicator),
    services = "contract_runtime",
    metadata = wlv_native_indicator_metadata_row(
      indicator,
      if (constant) "Capital stock (constant USD)" else "Capital stock (USD)",
      if (constant) {
        "Capital stock is the prices in constant USD of capital assets (base year = 2000)."
      } else {
        "Capital stock is the prices in current USD of capital assets."
      },
      if (constant) {
        "Deflated by Gross Output Price Index and converted from national currency using the exchange rate."
      } else {
        "Converted from national currency using the exchange rate."
      },
      "Capital", "usd"
    ),
    run = local({
      output_indicator <- indicator
      is_constant <- constant
      module_name <- id
      function(ctx) {
        lists <- ctx$input("lists")
        value <- wlv_native_source_variable(ctx$input("source"), "K", lists)
        if (is_constant) {
          exchange_base <- ctx$input("exchange_rate")[1L, , ]
          exchange_base <- array(
            rep(exchange_base, times = length(lists$years)),
            dim = c(length(lists$sectors), length(lists$countries), length(lists$years))
          )
          exchange_base <- aperm(exchange_base, c(3L, 1L, 2L))
          dimnames(exchange_base) <- dimnames(value)
          value <- value / ctx$input("go_price") / exchange_base
        } else {
          value <- value / ctx$input("exchange_rate")
        }
        runtime <- ctx$service("contract_runtime")
        for (year in lists$years) {
          capital_stock <- as.numeric(value[year, , ])
          capital_stock <- wlv_wiodr16_clean_structural_nonfinite_stock(
            capital_stock, lists$input
          )
          sanitized <- wlv_wiodr16_sanitize_capital_stock(
            capital_stock, year, lists$input
          )
          truncated <- attr(sanitized, "wlv.truncated_negative_stock")
          if (nrow(truncated)) {
            wlv_record_observed_transformations(
              runtime,
              truncated,
              artifact = "sea_sectors",
              indicator = output_indicator,
              checkpoint = "after_stage_1",
              stage = 1L,
              module = module_name,
              coordinate_columns = c(
                year = "year", country = "country", sector = "sector"
              )
            )
          }
          value[year, , ] <- sanitized
        }
        value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
        wlv_module_result(outputs = list(value = value))
      }
    })
  )
}

wlv_indicator_capital_stock_s_us_wiodr16_spec <- function() {
  wlv_native_wiodr16_capital_spec(
    "indicator.capital_stock.s.us.wiodr16", "capital_stock.s.us"
  )
}
wlv_indicator_capital_stock_s_cu_wiodr16_spec <- function() {
  wlv_native_wiodr16_capital_spec(
    "indicator.capital_stock.s.cu.wiodr16", "capital_stock.s.cu", TRUE
  )
}

wlv_indicator_hours_worked_emp_s_hr_wiodr16_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.hours_worked.emp.s.hr.wiodr16",
  checkpoint = 1L,
  requires = wlv_native_source_requirements(),
  provides = wlv_native_indicator_output("hours_worked.emp.s.hr"),
  services = "contract_runtime",
  metadata = wlv_native_indicator_metadata_row(
    "hours_worked.emp.s.hr", "Total hours worked by persons engaged",
    "Total hours worked by persons engaged represents the sum of hours worker in a year by persons engaged.",
    "Estimated from the average hours worked by employees.",
    "Labour and employment", "hours"
  ),
  run = function(ctx) {
    lists <- ctx$input("lists")
    value <- wlv_wiodr16_hours_worked_runtime(
      ctx$service("contract_runtime"),
      wlv_native_source_variable(ctx$input("source"), "H_EMPE", lists),
      wlv_native_source_variable(ctx$input("source"), "EMPE", lists),
      wlv_native_source_variable(ctx$input("source"), "EMP", lists),
      module = "indicator.hours_worked.emp.s.hr.wiodr16"
    )
    value <- wlv_native_sector_array(value, lists)
    wlv_module_result(outputs = list(value = value))
  }
)
}

wlv_indicator_go_price_r_id_wiodr16_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.go_price.r.id.wiodr16",
  checkpoint = 1L,
  requires = wlv_native_source_requirements(),
  provides = wlv_native_indicator_output("go_price.r.id"),
  metadata = wlv_native_indicator_metadata_row(
    "go_price.r.id", "Gross output price index (national currency)",
    "Gross-output price index stored canonically with 2000 = 1.",
    "Presentation metadata multiplies the canonical value by 100; the stored value is never rescaled.",
    "Others", "index"
  ),
  run = function(ctx) {
    lists <- ctx$input("lists")
    source_value <- wlv_native_source_variable(ctx$input("source"), "GO_PI", lists)
    if (!"2000" %in% lists$years) {
      stop("Gross-output price normalization requires base year 2000.", call. = FALSE)
    }
    base <- array(
      rep(source_value["2000", , ], times = length(lists$years)),
      dim = c(length(lists$sectors), length(lists$countries), length(lists$years))
    )
    base <- aperm(base, c(3L, 1L, 2L))
    dimnames(base) <- dimnames(source_value)
    value <- source_value / base
    value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
    wlv_module_result(outputs = list(value = value))
  }
)
}

# The base basket and base lambda are run resources shared by every period.
wlv_indicator_basket_zero_collector_spec <- function() {
  wlv_module_spec(
  id = "indicator.basket_zero.collector",
  scope = "run",
  checkpoint = 3L,
  operations = c("calculate", "recalculate"),
  parameters = list(
    base_year = wlv_module_parameter("character", default = "first")
  ),
  requires = list(
    baskets = wlv_resource_ref(
      "io/consumption_basket",
      wlv_native_io_contract("consumption_basket"),
      partition = "*",
      collect = TRUE
    ),
    lambdas = wlv_resource_ref(
      "intermediate/lambda",
      wlv_native_intermediate_contract("lambda", c("year", "input"), "io_period"),
      partition = "*",
      collect = TRUE
    )
  ),
  provides = c(
    wlv_native_intermediate_output(
      "basket_zero", axes = c("input", "output"), scope = "run"
    ),
    wlv_native_intermediate_output(
      "lambda_zero", axes = "input", scope = "run"
    )
  ),
  run = function(ctx) {
    base_year <- ctx$arg("base_year")
    baskets <- ctx$input("baskets")
    lambdas <- ctx$input("lambdas")
    if (identical(base_year, "first")) {
      observed_years <- sort(unique(unlist(lapply(baskets, function(value) {
        dimnames(value)[[1L]]
      }), use.names = FALSE)))
      if (!length(observed_years) || anyNA(observed_years)) {
        stop("Consumption-basket partitions do not declare valid years.",
          call. = FALSE
        )
      }
      # The historical engine used the first matrix row as its fixed basket
      # and lambda. That is 1995 for WIOD13 and 2000 for WIOD16.
      base_year <- observed_years[[1L]]
    }
    basket_matches <- which(vapply(
      baskets,
      function(value) base_year %in% dimnames(value)[[1L]],
      logical(1L)
    ))
    lambda_matches <- which(vapply(
      lambdas,
      function(value) base_year %in% dimnames(value)[[1L]],
      logical(1L)
    ))
    if (length(basket_matches) != 1L || length(lambda_matches) != 1L) {
      stop(
        sprintf(
          "Base basket/lambda coverage must contain year %s exactly once.",
          base_year
        ),
        call. = FALSE
      )
    }
    basket_source <- baskets[[basket_matches]]
    input_labels <- dimnames(basket_source)[[2L]]
    input_columns <- match(input_labels, dimnames(basket_source)[[3L]])
    if (anyNA(input_columns)) {
      stop("The base consumption basket lacks inter-industry output columns.",
        call. = FALSE
      )
    }
    basket <- basket_source[
      base_year,
      ,
      input_columns,
      drop = TRUE
    ]
    lambda <- lambdas[[lambda_matches]][base_year, , drop = TRUE]
    basket <- array(
      basket,
      dim = c(length(input_labels), length(input_columns)),
      dimnames = list(input_labels, input_labels)
    )
    names(dimnames(basket)) <- c("input", "output")
    lambda <- array(
      lambda,
      dim = length(lambda),
      dimnames = list(input = dimnames(lambdas[[lambda_matches]])[[2L]])
    )
    wlv_module_result(outputs = list(basket_zero = basket, lambda_zero = lambda))
  }
)
}

wlv_indicator_basket_price_r_pc_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.basket_price.r.pc",
  checkpoint = 4L,
  scope = "io_period",
  parameters = list(
    go_price_producer = wlv_module_parameter(
      "character", default = "assumption.row"
    )
  ),
  requires = function(args) {
    c(
      wlv_native_intermediate_ref(
        "basket_zero", "basket_zero", c("input", "output"), scope = "run",
        producer = "indicator.basket_zero.collector"
      ),
      wlv_native_indicator_ref(
        "go_price.r.id", "go_price", producer = args$go_price_producer
      ),
      wlv_native_source_io_ref("period_source"),
      wlv_native_run_ref("dimensions/lists", "lists", "list"),
      wlv_native_run_ref("dimensions/nums", "nums", "list")
    )
  },
  metadata = wlv_native_indicator_metadata_row(
    "basket_price.r.pc", "Consumption basket price index",
    "Consumption basket price index reflects changes in the prices for average worker of acquiring a fixed basket of goods and services. The Laspeyres formula is used.",
    "Stored canonically with 2000 = 1; the presentation scale is defined by the method-specific unit metadata.",
    "Others", "index"
  ),
  run = function(ctx) {
    period_source <- ctx$input("period_source")
    lists <- wlv_native_partition_lists(period_source, ctx$input("lists"))
    nums <- ctx$input("nums")
    year_count <- dim(period_source)[[1L]]
    go_price <- ctx$input("go_price")[lists$years, , , drop = FALSE]
    go_price[, , "ROW"] <- go_price[, , "USA"]
    value <- (
      aperm(
        array(rep(ctx$input("basket_zero"), times = year_count),
          dim = c(nums$input, nums$input, year_count)),
        c(3L, 1L, 2L)
      ) *
        array(rep(go_price, times = nums$input),
          dim = c(year_count, nums$input, nums$input))
    )
    value <- aperm(apply(value, 1L, colSums, na.rm = TRUE), c(2L, 1L))
    value <- wlv_native_sector_array(value, lists)
    wlv_module_result(outputs = list(value = value))
  }
)
}

wlv_indicator_basket_value_r_pc_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.basket_value.r.pc",
  checkpoint = 4L,
  scope = "io_period",
  parameters = list(
    go_price_producer = wlv_module_parameter(
      "character", default = "assumption.row"
    )
  ),
  requires = function(args) {
    c(
      wlv_native_intermediate_ref(
        "basket_zero", "basket_zero", c("input", "output"), scope = "run",
        producer = "indicator.basket_zero.collector"
      ),
      wlv_native_intermediate_ref(
        "lambda_zero", "lambda_zero", "input", scope = "run",
        producer = "indicator.basket_zero.collector"
      ),
      wlv_native_intermediate_ref("lambda", axes = c("year", "input")),
      wlv_native_indicator_ref(
        "go_price.r.id", "go_price", producer = args$go_price_producer
      ),
      wlv_native_indicator_ref("exchange.r.id", "exchange"),
      wlv_native_source_io_ref("period_source"),
      wlv_native_run_ref("dimensions/lists", "lists", "list"),
      wlv_native_run_ref("dimensions/nums", "nums", "list")
    )
  },
  metadata = wlv_native_indicator_metadata_row(
    "basket_value.r.pc", "Consumption basket value index",
    "Consumption basket value index reflects changes in the socially necessary labour-time to produce a fixed consumption basket necessary for reproduction of an avarage worker. The Laspeyres formula is used.",
    "Stored canonically with 2000 = 1; the presentation scale is defined by the method-specific unit metadata.",
    "Others", "index"
  ),
  run = function(ctx) {
    period_source <- ctx$input("period_source")
    lists <- wlv_native_partition_lists(period_source, ctx$input("lists"))
    nums <- ctx$input("nums")
    year_count <- dim(period_source)[[1L]]
    basket_zero <- ctx$input("basket_zero")
    basket_value_zero <- colSums(
      basket_zero * rep(ctx$input("lambda_zero"), times = nums$input),
      na.rm = TRUE
    )
    price_exchange <-
      ctx$input("go_price")[lists$years, , , drop = FALSE] /
      ctx$input("exchange")[lists$years, , , drop = FALSE]
    value <- (
      aperm(
        array(rep(basket_zero, times = year_count),
          dim = c(nums$input, nums$input, year_count)),
        c(3L, 1L, 2L)
      ) *
        array(rep(price_exchange, times = nums$input),
          dim = c(year_count, nums$input, nums$input)) *
        rep(ctx$input("lambda"), times = nums$input)
    )
    value <- aperm(apply(value, 1L, colSums, na.rm = TRUE), c(2L, 1L))
    # The legacy assignment materializes this flattened year/input matrix as
    # year/sector/country before applying the base-basket denominator.
    value <- wlv_native_sector_array(value, lists)
    value <- value / aperm(
      array(rep(basket_value_zero, times = year_count),
        dim = c(nums$sectors, nums$countries, year_count)),
      c(3L, 1L, 2L)
    )
    wlv_module_result(outputs = list(value = value))
  }
)
}

# One instance per price indicator keeps selective recalculation atomic.
wlv_indicator_price_index_normalize_spec <- function() {
  wlv_module_spec(
  id = "indicator.price_index.normalize",
  scope = "run",
  checkpoint = "after_price_normalization",
  operations = c("calculate", "recalculate"),
  parameters = list(
    indicator = wlv_module_parameter("character"),
    predecessor = wlv_module_parameter("character"),
    base_year = wlv_module_parameter("character", default = "2000"),
    copy_usa_to_row = wlv_module_parameter("logical", default = FALSE)
  ),
  requires = function(args) {
    c(
      wlv_native_indicator_ref(
        args$indicator, "current", producer = args$predecessor
      ),
      wlv_native_run_ref("dimensions/lists", "lists", "list")
    )
  },
  provides = function(args) {
    wlv_native_indicator_output(
      args$indicator,
      action = "replace",
      predecessor = args$predecessor
    )
  },
  services = "contract_runtime",
  run = function(ctx) {
    current <- ctx$input("current")
    indicator <- ctx$arg("indicator")
    base_year <- ctx$arg("base_year")
    if (ctx$arg("copy_usa_to_row")) current[, , "ROW"] <- current[, , "USA"]
    if (!base_year %in% dimnames(current)[[1L]]) {
      stop(sprintf("Price index `%s` lacks base year `%s`.", indicator, base_year), call. = FALSE)
    }
    base <- array(
      rep(current[base_year, , ], times = length(ctx$input("lists")$years)),
      dim = c(
        length(ctx$input("lists")$sectors),
        length(ctx$input("lists")$countries),
        length(ctx$input("lists")$years)
      )
    )
    base <- aperm(base, c(3L, 1L, 2L))
    dimnames(base) <- dimnames(current)
    value <- wlv_ratio_runtime(
      ctx$service("contract_runtime"), current, base,
      zero = "not_applicable", artifact = "sea_sectors",
      indicator = indicator, checkpoint = "after_price_normalization",
      stage = 4L, module = "indicator.price_index.normalize",
      axes = c(year = 1L, sector = 2L, country = 3L)
    )
    value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
    wlv_module_result(outputs = list(value = value))
  }
)
}

wlv_native_constant_compensation_spec <- function(id, indicator, source_variable) {
  wlv_native_indicator_spec(
    id,
    checkpoint = 5L,
    requires = wlv_native_source_requirements(c(
      wlv_native_indicator_ref(
        "basket_price.r.pc", "basket_price",
        producer = "normalize.indicator.basket_price.r.pc"
      ),
      wlv_native_indicator_ref(
        "exchange.r.us", "exchange_rate", producer = "indicator.exchange.r.us"
      )
    )),
    provides = wlv_native_indicator_output(indicator, alias = "sector"),
    services = "contract_runtime",
    metadata = wlv_native_indicator_metadata_row(
      indicator,
      if (identical(indicator, "compensation.emp.s.cu")) {
        "Labour compensation (constant USD)"
      } else {
        "Salaries and wages (constant USD)"
      },
      if (identical(indicator, "compensation.emp.s.cu")) {
        paste0(
          "Labour compensation expressed in market prices represents the income received ",
          "all persons engaged as a result of their labour. It includes wages, salaries, ",
          "and income received by non-waged and non-salaried workers (self-employed, etc.). ",
          "Data are in constant USD (base year = 2000)."
        )
      } else {
        "Remuneration received by wage and salaried workers in constant USD (base year = 2000)."
      },
      NA_character_, "Wages and value of labour force", "usd"
    ),
    run = local({
      variable <- source_variable
      output_indicator <- indicator
      module_name <- id
      function(ctx) {
        lists <- ctx$input("lists")
        basket <- ctx$input("basket_price")
        exchange <- ctx$input("exchange_rate")
        exchange_base <- array(
          rep(exchange["2000", , ], times = length(lists$years)),
          dim = c(length(lists$sectors), length(lists$countries), length(lists$years))
        )
        exchange_base <- aperm(exchange_base, c(3L, 1L, 2L))
        dimnames(exchange_base) <- dimnames(basket)
        numerator <- wlv_native_source_variable(ctx$input("source"), variable, lists)
        sector <- wlv_sequential_ratio_runtime(
          ctx$service("contract_runtime"), numerator,
          denominators = list(
            "basket_price.r.pc" = basket,
            "exchange.r.us" = exchange_base
          ),
          zero = "not_applicable", artifact = "sea_sectors",
          indicator = output_indicator, checkpoint = "after_stage_5",
          stage = 5L, module = module_name,
          axes = c(year = 1L, sector = 2L, country = 3L)
        )
        sector <- wlv_native_with_named_axes(sector, c("year", "sector", "country"))
        wlv_module_result(outputs = list(sector = sector))
      }
    })
  )
}

wlv_indicator_compensation_emp_s_cu_spec <- function() {
  wlv_native_constant_compensation_spec(
  "indicator.compensation.emp.s.cu", "compensation.emp.s.cu", "LAB"
)
}
wlv_indicator_compensation_empe_s_cu_spec <- function() {
  wlv_native_constant_compensation_spec(
  "indicator.compensation.empe.s.cu", "compensation.empe.s.cu", "COMP"
)
}

wlv_native_skill_surplus_spec <- function(skill) {
  indicator <- paste0("surplus_value.empe_", skill, ".r.pc")
  hours <- paste0("hours_worked.empe_", skill, ".r.pc")
  compensation <- paste0("compensation.empe_", skill, ".r.pc")
  label <- c(hs = "high", ms = "medium", ls = "low")[[skill]]
  wlv_native_indicator_spec(
    paste0("indicator.", indicator),
    checkpoint = 5L,
    requires = c(
      wlv_native_indicator_ref("abstract_labour.empe.s.mv", "abstract_labour"),
      wlv_native_indicator_ref("labour_force_value.s.mv", "labour_force"),
      wlv_native_indicator_ref(hours, "hours_share"),
      wlv_native_indicator_ref(compensation, "compensation_share"),
      wlv_native_run_ref("dimensions/lists", "lists", "list")
    ),
    provides = wlv_native_stage5_provides(indicator),
    services = "contract_runtime",
    metadata = wlv_native_indicator_metadata_row(
      indicator,
      paste0("Rate of surplus value (", label, " skilled)"),
      paste0("Rate of surplus value ", label, " skilled employees. It is a measure of exploitation of labour in a capitalist relation of production."),
      paste0("Obtained by dividing the sum of abstract labour of ", label, " skilled employees by the sum of labour force value of ", label, " skilled employees, minus one."),
      "Rate of surplus value", "percent", TRUE
    ),
    run = local({
      output_indicator <- indicator
      hours_code <- hours
      compensation_code <- compensation
      function(ctx) {
        numerator <- ctx$input("abstract_labour") * ctx$input("hours_share")
        denominator <- ctx$input("labour_force") * ctx$input("compensation_share")
        runtime <- ctx$service("contract_runtime")
        sector <- wlv_ratio_runtime(
          runtime, numerator, denominator,
          zero = "not_applicable", artifact = "sea_sectors",
          indicator = output_indicator, checkpoint = "after_stage_5",
          stage = 5L, module = paste0("indicator.", output_indicator),
          axes = c(year = 1L, sector = 2L, country = 3L)
        ) - 1
        sector <- wlv_native_with_named_axes(sector, c("year", "sector", "country"))
        country <- wlv_native_country_and_world_ratio(
          runtime, numerator, denominator, output_indicator,
          hours_code, compensation_code,
          paste0("indicator.", output_indicator), ctx$input("lists"),
          subtract_one = TRUE
        )
        wlv_module_result(outputs = list(sector = sector, country = country))
      }
    })
  )
}

wlv_indicator_surplus_value_empe_hs_r_pc_spec <- function() {
  wlv_native_skill_surplus_spec("hs")
}
wlv_indicator_surplus_value_empe_ms_r_pc_spec <- function() {
  wlv_native_skill_surplus_spec("ms")
}
wlv_indicator_surplus_value_empe_ls_r_pc_spec <- function() {
  wlv_native_skill_surplus_spec("ls")
}
