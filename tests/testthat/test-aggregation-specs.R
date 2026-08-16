aggregation_spec_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "aggregation_specs.R"),
  envir = aggregation_spec_environment
)

wlv_aggregation_test_array <- function(values, sectors = c("S1", "S2")) {
  array(
    values,
    dim = c(1L, length(sectors), 1L),
    dimnames = list(year = "2000", sector = sectors, country = "A")
  )
}

test_that("aggregation specifications are strict validated S3 values", {
  strategies <- aggregation_spec_environment$wlv_aggregation_strategies()
  for (strategy in strategies) {
    spec <- aggregation_spec_environment$wlv_aggregation_spec(
      strategy = strategy,
      level = "sector_to_country",
      missing = "error",
      zero_denominator = if (
        strategy %in% c("ratio_of_sums", "weighted_mean")
      ) "error" else NULL
    )
    expect_s3_class(spec, "wlv_aggregation_spec")
    expect_true(aggregation_spec_environment$is.wlv_aggregation_spec(spec))
    expect_invisible(
      aggregation_spec_environment$wlv_validate_aggregation_spec(spec)
    )
  }

  expect_error(
    aggregation_spec_environment$wlv_aggregation_spec(
      "sum", "sector_to_country"
    ),
    "declared explicitly",
    fixed = TRUE
  )
  expect_error(
    aggregation_spec_environment$wlv_aggregation_spec(
      "ratio_of_sums", "sector_to_country", "error"
    ),
    "zero_denominator",
    fixed = TRUE
  )
  expect_error(
    aggregation_spec_environment$wlv_aggregation_spec(
      "sum", "sector_to_country", "error", zero_denominator = "zero"
    ),
    "valid only",
    fixed = TRUE
  )
  expect_error(
    aggregation_spec_environment$wlv_aggregation_spec(
      "average", "sector_to_country", "error"
    ),
    "strategy",
    fixed = TRUE
  )
  expect_error(
    aggregation_spec_environment$wlv_aggregation_spec(
      "sum", "region_to_world", "error"
    ),
    "level",
    fixed = TRUE
  )
})

test_that("mean, weighted mean and ratio of sums remain distinct", {
  value <- wlv_aggregation_test_array(c(1, 9))
  weight <- wlv_aggregation_test_array(c(1, 3))
  numerator <- wlv_aggregation_test_array(c(1, 90))
  denominator <- wlv_aggregation_test_array(c(1, 10))

  legacy <- aggregation_spec_environment$wlv_aggregate(
    aggregation_spec_environment$wlv_aggregation_spec(
      "legacy_mean", "sector_to_country", "error"
    ),
    value = value
  )
  weighted <- aggregation_spec_environment$wlv_aggregate(
    aggregation_spec_environment$wlv_aggregation_spec(
      "weighted_mean", "sector_to_country", "error", "error"
    ),
    value = value,
    weight = weight
  )
  ratio <- aggregation_spec_environment$wlv_aggregate(
    aggregation_spec_environment$wlv_aggregation_spec(
      "ratio_of_sums", "sector_to_country", "error", "error"
    ),
    numerator = numerator,
    denominator = denominator
  )

  expect_equal(as.numeric(legacy), 5)
  expect_equal(as.numeric(weighted), 7)
  expect_equal(as.numeric(ratio), 91 / 11)
  expect_length(unique(c(legacy, weighted, ratio)), 3L)
  expect_identical(dimnames(legacy), list(year = "2000", country = "A"))
  expect_identical(
    dimnames(aggregation_spec_environment$wlv_aggregation_state(legacy)),
    dimnames(legacy)
  )
  expect_true(all(aggregation_spec_environment$wlv_aggregation_state(legacy) == "finite"))
})

test_that("sum and invariant dispatch preserve retained dimensions", {
  value <- array(
    NA_real_,
    dim = c(2L, 2L, 2L),
    dimnames = list(
      year = c("2000", "2001"),
      sector = c("S1", "S2"),
      country = c("A", "B")
    )
  )
  value[, , "A"] <- 3
  value[, , "B"] <- 5

  invariant <- aggregation_spec_environment$wlv_aggregate(
    aggregation_spec_environment$wlv_aggregation_spec(
      "invariant", "sector_to_country", "error"
    ),
    value = value
  )
  expect_identical(dim(invariant), c(2L, 2L))
  expect_identical(
    dimnames(invariant),
    list(year = c("2000", "2001"), country = c("A", "B"))
  )
  expect_equal(unname(invariant[, "A"]), c(3, 3))
  expect_equal(unname(invariant[, "B"]), c(5, 5))

  country <- array(
    c(1, 2, 3, 4),
    dim = c(2L, 2L),
    dimnames = list(year = c("2000", "2001"), country = c("A", "B"))
  )
  world <- aggregation_spec_environment$wlv_aggregate(
    aggregation_spec_environment$wlv_aggregation_spec(
      "sum", "country_to_world", "error"
    ),
    value = country
  )
  expect_identical(dimnames(world), list(year = c("2000", "2001")))
  expect_equal(as.numeric(world), c(4, 6))

  value[1L, 2L, "A"] <- 3.1
  expect_error(
    aggregation_spec_environment$wlv_aggregate(
      aggregation_spec_environment$wlv_aggregation_spec(
        "invariant", "sector_to_country", "error", tolerance = 1e-12
      ),
      value = value
    ),
    "Invariant aggregation differs",
    fixed = TRUE
  )
})

test_that("missingness policies produce explicit and aligned states", {
  value <- array(
    NA_real_,
    dim = c(1L, 3L, 2L),
    dimnames = list(
      year = "2000", sector = c("S1", "S2", "S3"), country = c("A", "B")
    )
  )
  value[1L, , "A"] <- c(1, NA, 3)

  available <- aggregation_spec_environment$wlv_aggregate(
    aggregation_spec_environment$wlv_aggregation_spec(
      "sum", "sector_to_country", "available"
    ),
    value = value
  )
  expect_equal(as.numeric(available), c(4, NA_real_))
  expect_identical(
    as.vector(aggregation_spec_environment$wlv_aggregation_state(available)),
    c("partial", "missing")
  )

  propagated <- aggregation_spec_environment$wlv_aggregate(
    aggregation_spec_environment$wlv_aggregation_spec(
      "sum", "sector_to_country", "propagate"
    ),
    value = value
  )
  expect_true(all(is.na(propagated)))
  expect_identical(
    as.vector(aggregation_spec_environment$wlv_aggregation_state(propagated)),
    c("missing", "missing")
  )

  expect_error(
    aggregation_spec_environment$wlv_aggregate(
      aggregation_spec_environment$wlv_aggregation_spec(
        "sum", "sector_to_country", "error"
      ),
      value = value
    ),
    "Missing aggregation input",
    fixed = TRUE
  )
})

test_that("zero denominators obey each explicit policy", {
  numerator <- wlv_aggregation_test_array(c(1, 2))
  denominator <- wlv_aggregation_test_array(c(0, 0))
  value <- wlv_aggregation_test_array(c(2, 8))
  weight <- denominator

  for (strategy in c("ratio_of_sums", "weighted_mean")) {
    arguments <- if (strategy == "ratio_of_sums") {
      list(numerator = numerator, denominator = denominator)
    } else {
      list(value = value, weight = weight)
    }
    expect_error(
      do.call(
        aggregation_spec_environment$wlv_aggregate,
        c(
          list(spec = aggregation_spec_environment$wlv_aggregation_spec(
            strategy, "sector_to_country", "error", "error"
          )),
          arguments
        )
      ),
      "Zero aggregation denominator",
      fixed = TRUE
    )

    not_applicable <- do.call(
      aggregation_spec_environment$wlv_aggregate,
      c(
        list(spec = aggregation_spec_environment$wlv_aggregation_spec(
          strategy, "sector_to_country", "error", "not_applicable"
        )),
        arguments
      )
    )
    expect_true(is.na(as.numeric(not_applicable)))
    expect_identical(
      as.vector(aggregation_spec_environment$wlv_aggregation_state(not_applicable)),
      "not_applicable"
    )

    zero <- do.call(
      aggregation_spec_environment$wlv_aggregate,
      c(
        list(spec = aggregation_spec_environment$wlv_aggregation_spec(
          strategy, "sector_to_country", "error", "zero"
        )),
        arguments
      )
    )
    expect_identical(as.numeric(zero), 0)
    expect_identical(
      as.vector(aggregation_spec_environment$wlv_aggregation_state(zero)),
      "zero_denominator"
    )
  }
})

test_that("not-applicable aggregation is shape preserving and explicit", {
  value <- array(
    1:6,
    dim = c(2L, 3L),
    dimnames = list(year = c("2000", "2001"), country = c("A", "B", "C"))
  )
  result <- aggregation_spec_environment$wlv_aggregate(
    aggregation_spec_environment$wlv_aggregation_spec(
      "not_applicable", "country_to_world", "propagate"
    ),
    value = value
  )
  expect_identical(dimnames(result), list(year = c("2000", "2001")))
  expect_true(all(is.na(result)))
  expect_true(all(
    aggregation_spec_environment$wlv_aggregation_state(result) ==
      "not_applicable"
  ))
})

test_that("weighted aggregation obeys scale, ratio and convexity properties", {
  value <- array(
    c(1, 5, 9, 2, 4, 8, 3, 6, 7, 0, 10, 12),
    dim = c(2L, 3L, 2L),
    dimnames = list(
      year = c("2000", "2001"),
      sector = c("S1", "S2", "S3"),
      country = c("A", "B")
    )
  )
  weight <- array(
    c(1, 2, 3, 4, 2, 1, 5, 2, 4, 3, 1, 6),
    dim = dim(value),
    dimnames = dimnames(value)
  )
  weighted_spec <- aggregation_spec_environment$wlv_aggregation_spec(
    "weighted_mean", "sector_to_country", "error", "error"
  )
  weighted <- aggregation_spec_environment$wlv_aggregate(
    weighted_spec,
    value = value,
    weight = weight
  )
  scaled <- aggregation_spec_environment$wlv_aggregate(
    weighted_spec,
    value = value,
    weight = weight * 37
  )
  expect_equal(weighted, scaled, tolerance = 1e-14)

  denominator <- weight
  numerator <- value * denominator
  ratio <- aggregation_spec_environment$wlv_aggregate(
    aggregation_spec_environment$wlv_aggregation_spec(
      "ratio_of_sums", "sector_to_country", "error", "error"
    ),
    numerator = numerator,
    denominator = denominator
  )
  expect_equal(weighted, ratio, tolerance = 1e-14)

  for (year in dimnames(value)$year) {
    for (country in dimnames(value)$country) {
      observed <- weighted[year, country]
      bounds <- range(value[year, , country])
      expect_gte(observed, bounds[[1L]])
      expect_lte(observed, bounds[[2L]])
    }
  }
})

test_that("weighted means reject negative weights and mismatched axes", {
  value <- wlv_aggregation_test_array(c(1, 2))
  weight <- wlv_aggregation_test_array(c(1, -1))
  spec <- aggregation_spec_environment$wlv_aggregation_spec(
    "weighted_mean", "sector_to_country", "error", "error"
  )
  expect_error(
    aggregation_spec_environment$wlv_aggregate(
      spec,
      value = value,
      weight = weight
    ),
    "non-negative",
    fixed = TRUE
  )
  expect_error(
    aggregation_spec_environment$wlv_aggregate(
      spec,
      value = value,
      weight = abs(weight),
      axis = 1L
    ),
    "cannot collapse dimension `year`",
    fixed = TRUE
  )
})

wlv_aggregation_contract_test_rows <- function() {
  levels <- c("sector_to_country", "country_to_world")
  indicators <- c("target", "numerator", "denominator")
  rows <- expand.grid(
    indicator = indicators,
    level = levels,
    stringsAsFactors = FALSE
  )
  rows$strategy <- ifelse(rows$indicator == "target", "ratio_of_sums", "sum")
  rows$module <- ""
  rows$numerator <- ifelse(rows$indicator == "target", "numerator", "")
  rows$denominator <- ifelse(rows$indicator == "target", "denominator", "")
  rows$weight <- ""
  rows$zero_denominator <- ifelse(rows$indicator == "target", "zero", "")
  rows$notes <- ""
  rows
}

test_that("stable registries take typed contracts over legacy routing strings", {
  solutions <- data.frame(
    names = c("target", "numerator", "denominator"),
    country_solution = c("mean", "sum", "sum"),
    stringsAsFactors = FALSE
  )
  registry <- aggregation_spec_environment$wlv_resolve_aggregation_registry(
    aggregations = wlv_aggregation_contract_test_rows(),
    solutions = solutions,
    method = "stable_demo",
    stable = TRUE
  )
  binding <- aggregation_spec_environment$wlv_aggregation_registry_binding(
    registry,
    "target",
    "sector_to_country"
  )
  expect_identical(binding$spec$strategy, "ratio_of_sums")
  expect_identical(binding$numerator, "numerator")
  expect_identical(binding$denominator, "denominator")
  expect_false(binding$legacy)
  expect_false(registry$legacy)

  broken <- wlv_aggregation_contract_test_rows()
  broken$numerator[broken$indicator == "target"] <- "unknown"
  expect_error(
    aggregation_spec_environment$wlv_resolve_aggregation_registry(
      broken,
      solutions,
      method = "stable_demo",
      stable = TRUE
    ),
    "lacks a valid typed aggregation",
    fixed = TRUE
  )

  formula_rows <- data.frame(
    indicator = "formula_weight",
    level = c("sector_to_country", "country_to_world"),
    strategy = "formula",
    module = "demo/formula_weight-country.R",
    numerator = "",
    denominator = "",
    weight = "",
    zero_denominator = "",
    notes = "",
    stringsAsFactors = FALSE
  )
  scheduled <- rbind(wlv_aggregation_contract_test_rows(), formula_rows)
  target_country <- scheduled$indicator == "target" &
    scheduled$level == "sector_to_country"
  scheduled$strategy[target_country] <- "sum"
  scheduled$numerator[target_country] <- ""
  scheduled$denominator[target_country] <- ""
  scheduled$zero_denominator[target_country] <- ""
  target_world <- scheduled$indicator == "target" &
    scheduled$level == "country_to_world"
  scheduled$strategy[target_world] <- "weighted_mean"
  scheduled$numerator[target_world] <- ""
  scheduled$denominator[target_world] <- ""
  scheduled$weight[target_world] <- "formula_weight"
  expect_error(
    aggregation_spec_environment$wlv_resolve_aggregation_registry(
      scheduled,
      rbind(
        solutions,
        data.frame(
          names = "formula_weight",
          country_solution = "demo/formula_weight-country.R",
          stringsAsFactors = FALSE
        )
      ),
      method = "stable_demo",
      stable = TRUE
    ),
    "depends on formula-produced country indicator",
    fixed = TRUE
  )
})

test_that("experimental legacy aggregation requires opt-in and warns", {
  aggregations <- wlv_aggregation_contract_test_rows()[FALSE, , drop = FALSE]
  solutions <- data.frame(
    names = "legacy_metric",
    country_solution = "mean",
    stringsAsFactors = FALSE
  )
  expect_error(
    aggregation_spec_environment$wlv_resolve_aggregation_registry(
      aggregations,
      solutions,
      method = "experimental_demo",
      stable = FALSE,
      allow_legacy = FALSE
    ),
    "requires explicit opt-in",
    fixed = TRUE
  )
  registry <- NULL
  expect_warning(
    registry <- aggregation_spec_environment$wlv_resolve_aggregation_registry(
      aggregations,
      solutions,
      method = "experimental_demo",
      stable = FALSE,
      allow_legacy = TRUE
    ),
    "adapted legacy aggregations",
    fixed = TRUE
  )
  binding <- aggregation_spec_environment$wlv_aggregation_registry_binding(
    registry,
    "legacy_metric",
    "country_to_world"
  )
  expect_identical(binding$spec$strategy, "legacy_mean")
  expect_true(binding$legacy)
  expect_true(registry$legacy)
})

test_that("self-referenced ratios and weights share one named input", {
  row <- data.frame(
    indicator = "ratio",
    level = "sector_to_country",
    strategy = "ratio_of_sums",
    module = "",
    numerator = "x",
    denominator = "x",
    weight = "",
    zero_denominator = "not_applicable",
    notes = "",
    stringsAsFactors = FALSE
  )
  ratio <- aggregation_spec_environment$wlv_aggregation_binding_from_row(row)
  expect_identical(
    aggregation_spec_environment$wlv_aggregation_binding_inputs(ratio),
    "x"
  )
  partial_ratio <- aggregation_spec_environment$wlv_aggregate_binding(
    ratio,
    list(x = wlv_aggregation_test_array(c(2, NA_real_)))
  )
  expect_equal(as.numeric(partial_ratio), 1)
  expect_identical(
    as.vector(attr(partial_ratio, "wlv_state", exact = TRUE)),
    "partial"
  )
  zero_ratio <- aggregation_spec_environment$wlv_aggregate_binding(
    ratio,
    list(x = wlv_aggregation_test_array(c(0, 0)))
  )
  expect_true(is.na(zero_ratio))
  expect_identical(
    as.vector(attr(zero_ratio, "wlv_state", exact = TRUE)),
    "not_applicable"
  )

  row$indicator <- "x"
  row$strategy <- "weighted_mean"
  row$numerator <- ""
  row$denominator <- ""
  row$weight <- "x"
  weighted <- aggregation_spec_environment$wlv_aggregation_binding_from_row(row)
  expect_identical(
    aggregation_spec_environment$wlv_aggregation_binding_inputs(weighted),
    "x"
  )
  partial_weighted <- aggregation_spec_environment$wlv_aggregate_binding(
    weighted,
    list(x = wlv_aggregation_test_array(
      c(1, NA_real_, 3),
      sectors = c("S1", "S2", "S3")
    ))
  )
  expect_equal(as.numeric(partial_weighted), 2.5)
  expect_identical(
    as.vector(attr(partial_weighted, "wlv_state", exact = TRUE)),
    "partial"
  )
  zero_weighted <- aggregation_spec_environment$wlv_aggregate_binding(
    weighted,
    list(x = wlv_aggregation_test_array(c(0, 0)))
  )
  expect_true(is.na(zero_weighted))
  expect_identical(
    as.vector(attr(zero_weighted, "wlv_state", exact = TRUE)),
    "not_applicable"
  )
})
