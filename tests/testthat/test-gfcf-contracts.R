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
  expect_identical(wiodr13$md5, "61cfd5d08a9934a703335e14968e5b43")
  expect_identical(wiodr16$count, 649L)
  expect_identical(wiodr16$md5, "5b638a35212f2b91cab933f19a037caa")
  expect_error(
    gfcf_contract_environment$wlv_wiodr_negative_gfcf_pin("other"),
    "Unknown WIOD GFCF contract",
    fixed = TRUE
  )
})

test_that("partial fixtures cannot introduce unpinned negative GFCF", {
  value <- array(
    c(1, 0),
    dim = c(1L, 2L, 1L),
    dimnames = list("2000", c("A.S1", "A.S2"), "A.c60")
  )
  result <- gfcf_contract_environment$wlv_wiodr_sanitize_negative_gfcf(
    value,
    "wiodr16"
  )
  expect_identical(as.numeric(result), c(1, 0))
  expect_identical(
    nrow(attr(result, "wlv.truncated_negative_gfcf")),
    0L
  )

  value[[1L]] <- -1
  expect_error(
    gfcf_contract_environment$wlv_wiodr_sanitize_negative_gfcf(
      value,
      "wiodr16"
    ),
    "outside the pinned full source scope",
    fixed = TRUE
  )
  value[[1L]] <- Inf
  expect_error(
    gfcf_contract_environment$wlv_wiodr_sanitize_negative_gfcf(
      value,
      "wiodr16"
    ),
    "finite, named three-dimensional array",
    fixed = TRUE
  )
})

test_that("prepared WIOD sources match the exact negative-GFCF key sets", {
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
    result <- gfcf_contract_environment$wlv_wiodr_sanitize_negative_gfcf(
      source,
      method
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

    drifted <- source
    first <- which(drifted < 0, arr.ind = TRUE)[1L, ]
    drifted[first[[1L]], first[[2L]], first[[3L]]] <- 0
    expect_error(
      gfcf_contract_environment$wlv_wiodr_sanitize_negative_gfcf(
        drifted,
        method
      ),
      "differs from the pinned set",
      fixed = TRUE
    )
    rm(source, result, drifted)
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
