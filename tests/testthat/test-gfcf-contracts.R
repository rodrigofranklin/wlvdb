gfcf_contract_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "missingness.R"),
  envir = gfcf_contract_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "result_contracts.R"),
  envir = gfcf_contract_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "gfcf_contracts.R"),
  envir = gfcf_contract_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "gfcf_diagnostics.R"),
  envir = gfcf_contract_environment
)

wlv_read_gfcf_source_slice <- function(method, demand) {
  path <- file.path(wlv_test_root, "source_data", method, "m_io.fst")
  metadata <- readRDS(paste0(path, ".meta"))
  dimensions <- metadata$dim
  years <- metadata[[2L]]
  inputs <- metadata[[3L]]
  outputs <- metadata[[4L]]
  output_positions <- grep(paste0("[.]", demand, "$"), outputs)
  block_size <- dimensions[[1L]] * dimensions[[2L]]
  value <- array(
    NA_real_,
    dim = c(dimensions[[1L]], dimensions[[2L]], length(output_positions)),
    dimnames = list(years, inputs, outputs[output_positions])
  )
  for (index in seq_along(output_positions)) {
    output_position <- output_positions[[index]]
    block <- fst::read_fst(
      path,
      from = (output_position - 1L) * block_size + 1L,
      to = output_position * block_size
    )[[1L]]
    value[, , index] <- matrix(
      block,
      nrow = dimensions[[1L]],
      ncol = dimensions[[2L]]
    )
  }
  value
}

test_that("WIOD negative-GFCF contracts expose the reviewed exact pins", {
  wiodr13 <- gfcf_contract_environment$wlv_wiodr_negative_gfcf_pin("wiodr13")
  wiodr16 <- gfcf_contract_environment$wlv_wiodr_negative_gfcf_pin("wiodr16")

  expect_identical(wiodr13$count, 24L)
  expect_identical(
    wiodr13$coordinate_md5,
    "61cfd5d08a9934a703335e14968e5b43"
  )
  expect_identical(
    wiodr13$value_md5,
    "0287db08451f74a23fe7657cc07e9165"
  )
  expect_identical(wiodr16$count, 649L)
  expect_identical(
    wiodr16$coordinate_md5,
    "5b638a35212f2b91cab933f19a037caa"
  )
  expect_identical(
    wiodr16$value_md5,
    "a3699faded649bb4d62c2f785e930d93"
  )
  expect_identical(wiodr13$canonical_unit, "million_usd")
  expect_identical(wiodr16$canonical_unit, "million_usd")
  expect_identical(wiodr13$demand, "c41")
  expect_identical(wiodr16$demand, "c60")
  expect_error(
    gfcf_contract_environment$wlv_wiodr_negative_gfcf_pin("other"),
    "Unknown WIOD GFCF contract",
    fixed = TRUE
  )
})

test_that("analysis is immutable and allocation alone applies the zero floor", {
  value <- array(
    c(1, 0),
    dim = c(1L, 2L, 1L),
    dimnames = list("2000", c("A.S1", "A.S2"), "A.c60")
  )
  original <- value
  analysis <- gfcf_contract_environment$wlv_wiodr_analyze_negative_gfcf(
    value,
    "wiodr16"
  )
  expect_identical(value, original)
  expect_false(analysis$canonical_scope)
  expect_identical(nrow(analysis$observations), 0L)

  result <- gfcf_contract_environment$wlv_wiodr_apply_negative_gfcf_policy(
    value,
    "wiodr16",
    input_unit = "million_usd"
  )
  expect_identical(as.numeric(result), c(1, 0))
  expect_identical(
    nrow(attr(result, "wlv.truncated_negative_gfcf")),
    0L
  )

  value[[1L]] <- -1
  expect_error(
    gfcf_contract_environment$wlv_wiodr_analyze_negative_gfcf(
      value,
      "wiodr16"
    ),
    "outside the pinned full source scope",
    fixed = TRUE
  )
  expect_error(
    gfcf_contract_environment$wlv_wiodr_apply_negative_gfcf_policy(
      value,
      "wiodr16",
      input_unit = "million_usd"
    ),
    "outside the pinned full source scope",
    fixed = TRUE
  )
  value[[1L]] <- Inf
  expect_error(
    gfcf_contract_environment$wlv_wiodr_analyze_negative_gfcf(
      value,
      "wiodr16"
    ),
    "finite, named three-dimensional array",
    fixed = TRUE
  )
})

test_that("canonical magnitude signatures detect drift at fixed coordinates", {
  observed <- data.frame(
    year = c("2000", "2001"),
    input = c("A.S1", "B.S2"),
    output = c("A.c60", "B.c60"),
    value = c(-1500000, -2250000),
    value_million_usd = c(-1.5, -2.25),
    stringsAsFactors = FALSE
  )
  signature <- gfcf_contract_environment$
    wlv_wiodr_negative_gfcf_signature(observed)
  pin <- list(
    count = signature$count,
    coordinate_md5 = signature$coordinate_md5,
    value_md5 = signature$value_md5,
    canonical_unit = "million_usd"
  )
  expect_no_error(
    gfcf_contract_environment$wlv_wiodr_assert_negative_gfcf_profile(
      observed,
      method = "fixture",
      pin = pin
    )
  )

  drifted <- observed
  drifted$value[[1L]] <- drifted$value[[1L]] * 1.01
  drifted$value_million_usd[[1L]] <-
    drifted$value_million_usd[[1L]] * 1.01
  drifted_signature <- gfcf_contract_environment$
    wlv_wiodr_negative_gfcf_signature(drifted)
  expect_identical(
    drifted_signature$coordinate_md5,
    signature$coordinate_md5
  )
  expect_false(identical(drifted_signature$value_md5, signature$value_md5))
  expect_error(
    gfcf_contract_environment$wlv_wiodr_assert_negative_gfcf_profile(
      drifted,
      method = "fixture",
      pin = pin
    ),
    "magnitudes differ",
    fixed = TRUE
  )

  observed_usd <- gfcf_contract_environment$wlv_wiodr_observe_negative_gfcf(
    array(
      observed$value,
      dim = c(1L, 2L, 1L),
      dimnames = list("2000", c("A.S1", "B.S2"), "A.c60")
    ),
    input_unit = "usd"
  )
  expect_equal(observed_usd$value_million_usd, c(-1.5, -2.25))
})

test_that("WIOD preflight analyzes the GFCF slice before accounting", {
  wiodr13 <- wlv_make_wiodr13_validation_fixture()
  wiodr13$demands[[2L]] <- "c41"
  dimnames(wiodr13$m_io)[[3L]] <- sub(
    "[.]INV$",
    ".c41",
    dimnames(wiodr13$m_io)[[3L]]
  )
  expect_error(
    wlv_validate_wiodr13_fixture(wiodr13),
    "negative GFCF cannot be accepted outside the pinned full source scope",
    fixed = TRUE
  )

  wiodr16 <- wlv_make_wiodr16_validation_fixture()
  wiodr16$demands[[2L]] <- "c60"
  dimnames(wiodr16$m_io)[[3L]] <- sub(
    "[.]c58$",
    ".c60",
    dimnames(wiodr16$m_io)[[3L]]
  )
  wiodr16$m_io["2000", "A.S1", "A.c60"] <- -1
  expect_error(
    wlv_validate_wiodr16_fixture(wiodr16),
    "negative GFCF cannot be accepted outside the pinned full source scope",
    fixed = TRUE
  )
})

test_that("prepared WIOD sources match exact coordinate and magnitude profiles", {
  paths <- file.path(
    wlv_test_root,
    "source_data",
    c("wiodr13", "wiodr16"),
    "m_io.fst"
  )
  skip_if_not(
    all(file.exists(paths) & file.exists(paste0(paths, ".meta"))),
    "Prepared WIOD source arrays are not available."
  )

  specifications <- list(
    wiodr13 = list(demand = "c41", count = 24L),
    wiodr16 = list(demand = "c60", count = 649L)
  )
  for (method in names(specifications)) {
    source <- wlv_read_gfcf_source_slice(
      method,
      specifications[[method]]$demand
    )
    analysis <- gfcf_contract_environment$wlv_wiodr_analyze_negative_gfcf(
      source,
      method,
      input_unit = "million_usd"
    )
    expect_true(analysis$canonical_scope)
    expect_identical(
      analysis$signature$value_md5,
      gfcf_contract_environment$wlv_wiodr_negative_gfcf_pin(method)$value_md5
    )
    expect_identical(analysis$canonical_unit, "million_usd")

    diagnostic_observations <- gfcf_contract_environment$
      wlv_wiodr_canonical_gfcf_diagnostic_observations(source, method)
    diagnostic_artifacts <- gfcf_contract_environment$
      wlv_gfcf_diagnostic_artifacts(
        diagnostic_observations,
        method = method,
        input_unit = "million_usd"
      )
    expect_no_error(gfcf_contract_environment$
      wlv_validate_gfcf_diagnostic_artifacts(
        diagnostic_artifacts,
        method = method
      ))

    result <- gfcf_contract_environment$wlv_wiodr_apply_negative_gfcf_policy(
      source,
      method,
      input_unit = "million_usd"
    )
    observed <- attr(result, "wlv.truncated_negative_gfcf")
    expect_identical(nrow(observed), specifications[[method]]$count)
    expect_true(all(observed$value < 0))
    expect_true(all(result >= 0))
    expect_equal(
      as.numeric(result),
      pmax(as.numeric(source), 0)
    )
    expect_identical(
      unique(observed$policy_id),
      paste0(method, "_negative_gfcf_v1")
    )
    expect_identical(
      unique(observed$action),
      "truncate_allowlisted_negative_gfcf"
    )

    magnitude_drift <- source
    first <- which(magnitude_drift < 0, arr.ind = TRUE)[1L, ]
    magnitude_drift[first[[1L]], first[[2L]], first[[3L]]] <-
      magnitude_drift[first[[1L]], first[[2L]], first[[3L]]] * 1.01
    expect_error(
      gfcf_contract_environment$wlv_wiodr_analyze_negative_gfcf(
        magnitude_drift,
        method,
        input_unit = "million_usd"
      ),
      "magnitudes differ",
      fixed = TRUE
    )

    coordinate_drift <- source
    coordinate_drift[first[[1L]], first[[2L]], first[[3L]]] <- 0
    expect_error(
      gfcf_contract_environment$wlv_wiodr_analyze_negative_gfcf(
        coordinate_drift,
        method,
        input_unit = "million_usd"
      ),
      "coordinates differ",
      fixed = TRUE
    )

    runtime <- source * 1000000
    runtime_result <- gfcf_contract_environment$
      wlv_wiodr_apply_negative_gfcf_policy(runtime, method)
    expect_equal(as.numeric(runtime_result), pmax(as.numeric(runtime), 0))
    expect_true(all(
      attr(runtime_result, "wlv.truncated_negative_gfcf")$value < 0
    ))

    rm(
      source,
      analysis,
      diagnostic_observations,
      diagnostic_artifacts,
      result,
      magnitude_drift,
      coordinate_drift,
      runtime,
      runtime_result
    )
    gc()
  }
})

test_that("transformation observations round-trip through _anomalies.csv", {
  runtime <- gfcf_contract_environment$wlv_new_contract_runtime(
    method = "wiodr16",
    source = "wiodr16",
    policy = gfcf_contract_environment$wlv_wiodr16_missingness_policy()
  )
  observed <- data.frame(
    year = "2007",
    country = "ROU",
    sector = "J58",
    value = -0.027559192993556868,
    policy_id = "wiodr16_negative_va_ratio_v1",
    action = "absolute_allowlisted_negative_va_ratio",
    stringsAsFactors = FALSE
  )
  gfcf_contract_environment$wlv_record_observed_transformations(
    runtime,
    observed,
    artifact = "m_io",
    indicator = "value_added_disaggregation_ratio",
    checkpoint = "after_matrices",
    stage = 3L,
    module = "wiodr16/euklems.R",
    coordinate_columns = c(
      year = "year", country = "country", sector = "sector"
    )
  )

  path <- tempfile("wlv-anomalies-", fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  gfcf_contract_environment$wlv_write_contract_report(runtime, path)
  persisted <- gfcf_contract_environment$wlv_read_contract_report(path)
  expect_identical(nrow(persisted), 1L)
  expect_identical(persisted$year, "2007")
  expect_identical(persisted$country, "ROU")
  expect_identical(persisted$sector, "J58")
  expect_identical(
    persisted$original_value,
    sprintf("%.17g", observed$value)
  )
  expect_identical(persisted$policy_id, observed$policy_id)
  expect_identical(persisted$action, observed$action)
})
