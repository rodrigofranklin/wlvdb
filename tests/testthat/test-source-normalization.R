source_normalization_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "source_normalization.R"),
  envir = source_normalization_environment
)

wlv_test_source_m_io <- function() {
  array(
    c(1, NA_real_, -2, 4, 5, 6, 7, 8),
    dim = c(2L, 2L, 2L),
    dimnames = list(
      year = c("2000", "2001"),
      input = c("A.s1", "A.s2"),
      output = c("A.s1", "A.c1")
    )
  )
}

wlv_test_source_sea <- function(contract, value = 2) {
  variables <- contract$sea$variable
  result <- array(
    value,
    dim = c(2L, length(variables), 1L, 1L),
    dimnames = list(
      year = c("2000", "2001"),
      variable = variables,
      sector = "s1",
      country = "A"
    )
  )
  result[2L, variables[[1L]], 1L, 1L] <- NA_real_
  result
}

test_that("stable WIOD contracts cover every prepared SEA variable", {
  contract <- source_normalization_environment$wlv_source_normalization_contract
  wiodr13 <- contract("wiodr13")
  wiodr16 <- contract("wiodr16")

  expect_s3_class(wiodr13, "wlv_source_normalization_contract")
  expect_identical(wiodr13$contract_id, "wiodr13_source_normalization_v1")
  expect_identical(wiodr13$m_io$multiplier, 1e6)
  expect_setequal(
    wiodr13$sea$variable,
    c(
      "GO", "II", "VA", "COMP", "LAB", "CAP", "GFCF", "EMP", "EMPE",
      "H_EMP", "H_EMPE", "GO_P", "II_P", "VA_P", "GFCF_P", "GO_QI",
      "II_QI", "VA_QI", "LABHS", "LABMS", "LABLS", "H_HS", "H_MS",
      "H_LS", "K_GFCF", "VA_USD", "GO_USD"
    )
  )
  expect_identical(nrow(wiodr13$sea), 27L)
  expect_identical(
    wiodr13$sea$canonical_unit[wiodr13$sea$variable == "K_GFCF"],
    "constant_1995_lcu"
  )

  expect_identical(wiodr16$contract_id, "wiodr16_source_normalization_v1")
  expect_identical(nrow(wiodr16$sea), 18L)
  expect_setequal(
    wiodr16$sea$variable,
    c(
      "GO", "II", "VA", "COMP", "LAB", "CAP", "K", "EMP", "EMPE",
      "H_EMPE", "GO_PI", "II_PI", "VA_PI", "GO_QI", "II_QI", "VA_QI",
      "VA_USD", "GO_USD"
    )
  )

  expect_error(
    contract("other"),
    "Unknown source normalization contract `other`.",
    fixed = TRUE
  )
})

test_that("WIOD13 normalization applies each declared canonical scale once", {
  contract <-
    source_normalization_environment$wlv_source_normalization_contract("wiodr13")
  m_io <- wlv_test_source_m_io()
  sea <- wlv_test_source_sea(contract)
  normalized <- source_normalization_environment$wlv_normalize_source(
    m_io,
    sea,
    "wiodr13",
    contract
  )

  expect_identical(dim(normalized$m_io), dim(m_io))
  expect_identical(dimnames(normalized$m_io), dimnames(m_io))
  expect_equal(as.numeric(normalized$m_io), as.numeric(m_io) * 1e6)
  expect_identical(dim(normalized$sea), dim(sea))
  expect_identical(dimnames(normalized$sea), dimnames(sea))
  expect_identical(which(is.na(normalized$sea)), which(is.na(sea)))

  expect_equal(normalized$sea[1L, "GO", 1L, 1L], 2e6)
  expect_equal(normalized$sea[1L, "EMP", 1L, 1L], 2e3)
  expect_equal(normalized$sea[1L, "H_EMP", 1L, 1L], 2e6)
  expect_equal(normalized$sea[1L, "GO_P", 1L, 1L], 0.02)
  expect_equal(normalized$sea[1L, "GO_QI", 1L, 1L], 0.02)
  expect_equal(normalized$sea[1L, "LABHS", 1L, 1L], 2)
  expect_equal(normalized$sea[1L, "K_GFCF", 1L, 1L], 2e6)
  expect_equal(normalized$sea[1L, "VA_USD", 1L, 1L], 2e6)

  marker <-
    source_normalization_environment$wlv_source_normalization_marker(normalized$sea)
  expect_identical(marker$contract_id, contract$contract_id)
  expect_identical(marker$source, "wiodr13")
  expect_identical(marker$artifact, "sea")
  expect_true(marker$canonical)
})

test_that("WIOD16 normalization applies source-specific scales", {
  contract <-
    source_normalization_environment$wlv_source_normalization_contract("wiodr16")
  normalized <- source_normalization_environment$wlv_normalize_source(
    wlv_test_source_m_io(),
    wlv_test_source_sea(contract),
    "wiodr16",
    contract
  )

  expect_equal(normalized$sea[1L, "K", 1L, 1L], 2e6)
  expect_equal(normalized$sea[1L, "EMP", 1L, 1L], 2e3)
  expect_equal(normalized$sea[1L, "H_EMPE", 1L, 1L], 2e6)
  expect_equal(normalized$sea[1L, "GO_PI", 1L, 1L], 0.02)
  expect_equal(normalized$sea[1L, "VA_QI", 1L, 1L], 0.02)
  expect_equal(normalized$sea[1L, "GO_USD", 1L, 1L], 2e6)
})

test_that("normalization rejects incomplete labels and variable coverage", {
  contract <-
    source_normalization_environment$wlv_source_normalization_contract("wiodr13")
  normalize <- source_normalization_environment$wlv_normalize_source
  m_io <- wlv_test_source_m_io()
  sea <- wlv_test_source_sea(contract)

  missing <- sea[, -1L, , , drop = FALSE]
  expect_error(
    normalize(m_io, missing, "wiodr13", contract),
    "SEA variable coverage differs from the contract (missing: GO).",
    fixed = TRUE
  )

  unexpected <- sea
  dimnames(unexpected)[[2L]][1L] <- "EXTRA"
  expect_error(
    normalize(m_io, unexpected, "wiodr13", contract),
    "missing: GO; unexpected: EXTRA",
    fixed = TRUE
  )

  incomplete_labels <- m_io
  dimnames(incomplete_labels)[[3L]] <- NULL
  expect_error(
    normalize(incomplete_labels, sea, "wiodr13", contract),
    "must have complete, non-duplicated labels",
    fixed = TRUE
  )
  expect_error(
    source_normalization_environment$wlv_normalize_source_array(
      matrix(1, 2L, 2L),
      contract,
      "m_io"
    ),
    "must be a non-empty numeric 3-dimensional array",
    fixed = TRUE
  )
})

test_that("explicit markers prevent a second normalization", {
  contract <-
    source_normalization_environment$wlv_source_normalization_contract("wiodr16")
  m_io <- wlv_test_source_m_io()
  sea <- wlv_test_source_sea(contract)
  normalized <- source_normalization_environment$wlv_normalize_source(
    m_io,
    sea,
    "wiodr16",
    contract
  )

  expect_error(
    source_normalization_environment$wlv_normalize_source_array(
      normalized$m_io,
      contract,
      "m_io"
    ),
    "already source-normalized by `wiodr16_source_normalization_v1`",
    fixed = TRUE
  )
  expect_error(
    source_normalization_environment$wlv_normalize_source(
      normalized$m_io,
      normalized$sea,
      "wiodr16",
      contract
    ),
    "already source-normalized",
    fixed = TRUE
  )
})

test_that("an already-USD source can declare an identity contract", {
  new_contract <-
    source_normalization_environment$wlv_new_source_normalization_contract
  contract <- new_contract(
    source = "usd_ready",
    contract_id = "usd_ready_identity_v1",
    m_io_multiplier = 1,
    sea_multipliers = c(VA_USD = 1, GO_USD = 1),
    m_io_source_unit = "current_usd",
    m_io_canonical_unit = "current_usd",
    sea_source_units = "current_usd",
    sea_canonical_units = "current_usd"
  )
  m_io <- wlv_test_source_m_io()
  sea <- wlv_test_source_sea(contract, value = 17)
  normalized <- source_normalization_environment$wlv_normalize_source(
    m_io,
    sea,
    "usd_ready",
    contract
  )

  expect_equal(as.numeric(normalized$m_io), as.numeric(m_io))
  expect_equal(as.numeric(normalized$sea), as.numeric(sea))
  expect_identical(dimnames(normalized$m_io), dimnames(m_io))
  expect_identical(dimnames(normalized$sea), dimnames(sea))
  expect_identical(
    normalized$contract$sea$canonical_unit,
    c("current_usd", "current_usd")
  )
  expect_error(
    source_normalization_environment$wlv_normalize_source(
      m_io,
      sea,
      "wiodr13",
      contract
    ),
    "does not match contract source",
    fixed = TRUE
  )
})
