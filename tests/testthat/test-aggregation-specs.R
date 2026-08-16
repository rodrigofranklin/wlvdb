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
