missingness_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "missingness.R"),
  envir = missingness_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "result_contracts.R"),
  envir = missingness_environment
)

wlv_missingness_test_context <- function(
    policy_id = "test.strict",
    axes = c(year = 1L, sector = 2L, country = 3L)) {
  missingness_environment$wlv_contract_context(
    artifact = "sea_sectors",
    indicator = "test.indicator",
    checkpoint = "after_stage_1",
    stage = 1L,
    module = "test-module.R",
    policy_id = policy_id,
    axes = axes
  )
}

test_that("WIOD policy factories are pure and expose canonical IDs", {
  wiodr13 <- missingness_environment$wlv_wiodr13_missingness_policy()
  wiodr16 <- missingness_environment$wlv_wiodr16_missingness_policy()

  expect_s3_class(wiodr13, "wlv_missingness_policy")
  expect_s3_class(wiodr16, "wlv_missingness_policy")
  expect_identical(
    wiodr13,
    missingness_environment$wlv_wiodr13_missingness_policy()
  )
  expect_identical(
    wiodr16,
    missingness_environment$wlv_wiodr16_missingness_policy()
  )
  expect_identical(wiodr13$policy_id, "wiodr13_v1")
  expect_identical(wiodr13$source, "wiodr13")
  expect_identical(wiodr13$source_rules$country_selector, "ROW")
  expect_identical(wiodr16$policy_id, "wiodr16_v1")
  expect_identical(wiodr16$source, "wiodr16")
  expect_identical(wiodr16$source_rules$country_selector, c("ROW", "CHN"))
  expect_identical(wiodr16$non_finite_action, "error")
  expect_setequal(
    wiodr16$aggregation_policies,
    c("error", "propagate", "available")
  )
  expect_setequal(
    wiodr16$division_policies,
    c(
      "error", "zero_if_both_zero", "not_applicable",
      "not_applicable_if_both_zero", "zero_if_denominator_zero"
    )
  )

  strict <- missingness_environment$wlv_strict_missingness_policy(
    source = "synthetic",
    policy_id = "synthetic_strict"
  )
  expect_s3_class(strict, "wlv_missingness_policy")
  expect_identical(strict$source, "synthetic")
  expect_identical(strict$policy_id, "synthetic_strict")
  expect_identical(nrow(strict$source_rules), 0L)
})

test_that("contract runtimes require one explicit canonical scientific profile", {
  e <- missingness_environment
  policy <- e$wlv_strict_missingness_policy(
    source = "synthetic",
    policy_id = "synthetic_strict"
  )
  expect_error(
    e$wlv_new_contract_runtime(
      method = "synthetic",
      source = "synthetic",
      policy = policy
    ),
    "must be supplied explicitly",
    fixed = TRUE
  )
  expect_error(
    e$wlv_new_contract_runtime(
      method = "synthetic",
      source = "synthetic",
      policy = policy,
      scientific_profile = NULL
    ),
    "must be supplied explicitly",
    fixed = TRUE
  )
  profile <- wlv_test_scientific_profile(
    e,
    method = "synthetic",
    source = "synthetic"
  )
  runtime <- e$wlv_new_contract_runtime(
    method = "synthetic",
    source = "synthetic",
    policy = policy,
    scientific_profile = profile
  )
  expect_true(is.environment(runtime))
  expect_identical(runtime$scientific_profile, profile)

  forged <- profile
  forged$leontief_zero$exception_count <- 1L
  expect_error(
    e$wlv_new_contract_runtime(
      method = "synthetic",
      source = "synthetic",
      policy = policy,
      scientific_profile = forged
    ),
    "Invalid Leontief zero-output grouped counts",
    fixed = TRUE
  )
  expect_error(
    e$wlv_new_contract_runtime(
      method = "different",
      source = "synthetic",
      policy = policy,
      scientific_profile = profile
    ),
    "Invalid or mismatched scientific profile",
    fixed = TRUE
  )
})

test_that("WIOD16 CHN stage-1 derivatives remain structural until assumptions", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "wiodr16",
    source = "wiodr16",
    policy = missingness_environment$wlv_wiodr16_missingness_policy()
  )
  value <- array(
    NA_real_,
    dim = c(1L, 1L, 1L, 2L),
    dimnames = list("2000", "hours_worked.emp.s.hr", "A", c("CHN", "ROW"))
  )

  stage_states <- missingness_environment$wlv_contract_declared_states(
    runtime,
    artifact = "sea_sectors",
    indicator = "hours_worked.emp.s.hr",
    value = value,
    checkpoint = "after_stage_1"
  )
  expect_identical(
    as.vector(stage_states),
    rep("source_missing", 2L)
  )

  assumed_states <- missingness_environment$wlv_contract_declared_states(
    runtime,
    artifact = "sea_sectors",
    indicator = "hours_worked.emp.s.hr",
    value = value,
    checkpoint = "after_assumptions"
  )
  expect_true(is.na(assumed_states[1L, 1L, 1L, "CHN"]))
})

test_that("WIOD16 employee hours distinguish zero employment from a pinned fallback", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "wiodr16",
    source = "wiodr16",
    policy = missingness_environment$wlv_wiodr16_missingness_policy()
  )
  shape <- c(1L, 3L, 1L)
  labels <- list("2001", c("M72", "OTHER", "ZERO"), "MLT")
  employee_hours <- array(c(9000, 2e6, 0), dim = shape, dimnames = labels)
  employees <- array(c(0, 1000, 0), dim = shape, dimnames = labels)
  persons <- array(c(10, 1000, 0), dim = shape, dimnames = labels)

  result <- missingness_environment$wlv_wiodr16_hours_worked_runtime(
    runtime,
    employee_hours,
    employees,
    persons
  )
  expect_equal(result[1L, "M72", "MLT"], 2009 / 1 * 10)
  expect_equal(result[1L, "OTHER", "MLT"], 2e6)
  expect_identical(result[1L, "ZERO", "MLT"], 0)
  expect_setequal(
    runtime$anomalies$action,
    c("zero_hours_when_persons_engaged_zero", "fallback_to_country_employee_hours")
  )
  expect_identical(
    unique(runtime$anomalies$module),
    "indicator.hours_worked.emp.s.hr.wiodr16"
  )

  invalid_runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "wiodr16",
    source = "wiodr16",
    policy = missingness_environment$wlv_wiodr16_missingness_policy()
  )
  persons[1L, "ZERO", "MLT"] <- 1
  expect_error(
    missingness_environment$wlv_wiodr16_hours_worked_runtime(
      invalid_runtime,
      employee_hours,
      employees,
      persons
    ),
    class = "wlv_contract_error"
  )
})

test_that("WIOD16 ROW capital uses a pinned country-intensity fallback", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "wiodr16",
    source = "wiodr16",
    policy = missingness_environment$wlv_wiodr16_missingness_policy()
  )
  missing_sectors <- c(
    "C33", "E37-E39", "H53", "J58", "J59_J60", "K66", "M72",
    "M73", "M74_M75", "T", "U"
  )
  sectors <- c("A", missing_sectors)
  row_hours <- stats::setNames(c(2, rep(2, 7), 0, rep(2, 3)), sectors)
  reference_capital <- stats::setNames(c(4, rep(0, 11)), sectors)
  reference_hours <- stats::setNames(c(1, rep(0, 11)), sectors)

  for (year in as.character(2000:2014)) {
    result <- missingness_environment$wlv_row_capital_stock_runtime(
      runtime,
      row_hours,
      reference_capital,
      reference_hours,
      reference_country_intensity = 4,
      year = year,
      reference_country = "IND"
    )
  }
  expect_identical(result[["A"]], 8)
  expect_identical(result[["M73"]], 0)
  expect_true(all(result[setdiff(missing_sectors, "M73")] == 8))
  expect_identical(
    table(runtime$anomalies$action),
    table(c(
      rep("fallback_to_reference_country_capital_intensity", 150L),
      rep("zero_row_capital_when_hours_zero", 15L)
    ))
  )
  expect_identical(unique(runtime$anomalies$country), "ROW")
})

test_that("legacy WIOD16 ROW capital keeps its pinned per-worker basis", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "wiodr16v09",
    source = "wiodr16",
    policy = missingness_environment$wlv_wiodr16_missingness_policy()
  )
  missing_sectors <- c(
    "C33", "E37-E39", "H53", "J58", "J59_J60", "K66", "M72",
    "M73", "M74_M75", "T", "U"
  )
  sectors <- c("A", missing_sectors)
  row_workers <- stats::setNames(c(2, rep(2, 7), 0, rep(2, 3)), sectors)
  reference_capital <- stats::setNames(c(4, rep(0, 11)), sectors)
  reference_workers <- stats::setNames(c(1, rep(0, 11)), sectors)

  for (year in as.character(2000:2014)) {
    result <- missingness_environment$wlv_row_capital_stock_runtime(
      runtime,
      row_workers,
      reference_capital,
      reference_workers,
      reference_country_intensity = 4,
      year = year,
      reference_country = "IND",
      module = "row/row.old.R",
      basis = "workers"
    )
  }
  expect_identical(result[["A"]], 8)
  expect_identical(result[["M73"]], 0)
  expect_true(all(result[setdiff(missing_sectors, "M73")] == 8))
  expect_identical(
    table(runtime$anomalies$action),
    table(c(
      rep("fallback_to_reference_country_capital_per_worker", 150L),
      rep("zero_row_capital_when_workers_zero", 15L)
    ))
  )
  expect_identical(
    unique(runtime$anomalies$policy_id),
    "wiodr16v09_row_capital_per_worker_v1"
  )
})

test_that("WIOD16 ROW capital rejects every divergence from its pinned policy", {
  make_runtime <- function() {
    wlv_test_contract_runtime(missingness_environment,
      method = "wiodr16",
      source = "wiodr16",
      policy = missingness_environment$wlv_wiodr16_missingness_policy()
    )
  }
  missing_sectors <- c(
    "C33", "E37-E39", "H53", "J58", "J59_J60", "K66", "M72",
    "M73", "M74_M75", "T", "U"
  )
  sectors <- c("A", missing_sectors)
  row_hours <- stats::setNames(c(2, rep(2, 7), 0, rep(2, 3)), sectors)
  reference_capital <- stats::setNames(c(4, rep(0, 11)), sectors)
  reference_hours <- stats::setNames(c(1, rep(0, 11)), sectors)
  all_positive_hours <- reference_hours
  all_positive_hours[missing_sectors] <- 1
  all_positive_intensity <- sum(reference_capital) / sum(all_positive_hours)

  expect_error(
    missingness_environment$wlv_row_capital_stock_runtime(
      make_runtime(), row_hours, reference_capital, all_positive_hours,
      reference_country_intensity = all_positive_intensity,
      year = "2000", reference_country = "USA"
    ),
    "reference country=USA (expected IND)",
    fixed = TRUE
  )
  expect_error(
    missingness_environment$wlv_row_capital_stock_runtime(
      make_runtime(), row_hours, reference_capital, all_positive_hours,
      reference_country_intensity = all_positive_intensity,
      year = "2015", reference_country = "IND"
    ),
    "year=2015 (expected 2000:2014)",
    fixed = TRUE
  )
  expect_error(
    missingness_environment$wlv_row_capital_stock_runtime(
      make_runtime(), row_hours, reference_capital, all_positive_hours,
      reference_country_intensity = 3, year = "2000", reference_country = "IND"
    ),
    "reference intensity=3 (expected aggregate intensity=",
    fixed = TRUE
  )

  expect_error(
    missingness_environment$wlv_row_capital_stock_runtime(
      make_runtime(), row_hours, reference_capital, all_positive_hours,
      reference_country_intensity = all_positive_intensity,
      year = "2000", reference_country = "IND"
    ),
    "zero-zero sectors= (expected",
    fixed = TRUE
  )

  extra_zero_hours <- reference_hours
  extra_zero_capital <- reference_capital
  extra_zero_hours[["A"]] <- 0
  extra_zero_capital[["A"]] <- 0
  expect_error(
    missingness_environment$wlv_row_capital_stock_runtime(
      make_runtime(), row_hours, extra_zero_capital, extra_zero_hours,
      reference_country_intensity = 4, year = "2000", reference_country = "IND"
    ),
    "zero-zero sectors=A,",
    fixed = TRUE
  )

  wrong_partition_hours <- row_hours
  wrong_partition_hours[["M73"]] <- 2
  wrong_partition_hours[["M72"]] <- 0
  expect_error(
    missingness_environment$wlv_row_capital_stock_runtime(
      make_runtime(), wrong_partition_hours, reference_capital, reference_hours,
      reference_country_intensity = 4, year = "2000", reference_country = "IND"
    ),
    "zero ROW-hours sectors=M72 (expected M73)",
    fixed = TRUE
  )
})

test_that("synthetic ROW capital retains the generic fallback path", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = missingness_environment$wlv_strict_missingness_policy(
      source = "synthetic",
      policy_id = "synthetic_strict"
    )
  )
  sectors <- c("A", "B")
  row_hours <- stats::setNames(c(2, 3), sectors)
  reference_capital <- stats::setNames(c(4, 0), sectors)
  reference_hours <- stats::setNames(c(1, 0), sectors)

  result <- missingness_environment$wlv_row_capital_stock_runtime(
    runtime,
    row_hours,
    reference_capital,
    reference_hours,
    reference_country_intensity = 4,
    year = "1999",
    reference_country = "SYN"
  )
  expect_identical(unname(result), c(8, 12))
})

test_that("declared source missingness overrides legacy cleaned zeroes", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "wiodr13",
    source = "wiodr13",
    policy = missingness_environment$wlv_wiodr13_missingness_policy()
  )
  value <- array(
    c(2, 0, 0),
    dim = c(1L, 1L, 1L, 3L),
    dimnames = list(
      "2000", "surplus_value.empe_hs.r.pc", "A", c("USA", "AUS", "ROW")
    )
  )
  denominator <- array(
    c(1, 0, 0),
    dim = dim(value),
    dimnames = dimnames(value)
  )

  result <- missingness_environment$wlv_ratio_runtime(
    runtime,
    value,
    denominator,
    zero = "not_applicable",
    artifact = "sea_sectors",
    indicator = "surplus_value.empe_hs.r.pc",
    checkpoint = "after_stage_5",
    stage = 5L,
    module = "test-source-missing.R",
    axes = c(year = 1L, sector = 3L, country = 4L)
  )

  expect_equal(result[1L, 1L, 1L, "USA"], 2)
  expect_true(is.na(result[1L, 1L, 1L, "AUS"]))
  expect_true(is.na(result[1L, 1L, 1L, "ROW"]))
  expect_identical(
    as.vector(attr(result, "wlv_state")),
    c("finite", "not_applicable", "source_missing")
  )
  expect_true(
    "restore_declared_source_missing" %in%
      attr(result, "wlv_actions")$action
  )
  expect_silent(
    missingness_environment$wlv_contract_declared_states(
      runtime,
      artifact = "sea_sectors",
      indicator = "surplus_value.empe_hs.r.pc",
      value = result,
      checkpoint = "after_stage_5"
    )
  )

  invalid_runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "wiodr13",
    source = "wiodr13",
    policy = missingness_environment$wlv_wiodr13_missingness_policy()
  )
  value[1L, 1L, 1L, "ROW"] <- Inf
  caught <- tryCatch(
    missingness_environment$wlv_ratio_runtime(
      invalid_runtime,
      value,
      denominator,
      zero = "not_applicable",
      artifact = "sea_sectors",
      indicator = "surplus_value.empe_hs.r.pc",
      checkpoint = "after_stage_5",
      stage = 5L,
      module = "test-source-missing.R",
      axes = c(year = 1L, sector = 3L, country = 4L)
    ),
    wlv_contract_error = identity
  )
  expect_s3_class(caught, "wlv_contract_error")
  expect_identical(caught$anomalies$action, "abort_non_finite")
})

test_that("dependency states license only the denominator operand", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = missingness_environment$wlv_strict_missingness_policy(
      source = "synthetic", policy_id = "synthetic_strict"
    )
  )
  template <- array(
    NA_real_,
    dim = c(1L, 1L, 1L),
    dimnames = list("2000", "A", "X")
  )
  missingness_environment$wlv_contract_register_states(
    runtime,
    "sea_sectors",
    "dependency",
    missingness_environment$wlv_character_like(template, "not_applicable")
  )

  caught <- tryCatch(
    missingness_environment$wlv_ratio_with_dependency_states_runtime(
      runtime,
      numerator = template,
      denominator = template,
      dependencies = list(dependency = template),
      zero = "not_applicable",
      artifact = "sea_sectors",
      indicator = "ratio",
      checkpoint = "after_stage_5",
      stage = 5L,
      module = "test-dependency.R",
      axes = c(year = 1L, sector = 2L, country = 3L)
    ),
    wlv_contract_error = identity
  )
  expect_s3_class(caught, "wlv_contract_error")
  expect_identical(caught$anomalies$action, "abort_unexpected_missing")
})

test_that("registering a finite result clears stale missingness state", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = missingness_environment$wlv_strict_missingness_policy(
      source = "synthetic", policy_id = "synthetic_strict"
    )
  )
  value <- stats::setNames(NA_real_, "2000")
  attr(value, "wlv_state") <- stats::setNames("not_applicable", "2000")
  missingness_environment$wlv_contract_register_result(
    runtime, "sea_sectors", "ratio", value
  )
  expect_true(exists(
    missingness_environment$wlv_contract_state_key("sea_sectors", "ratio"),
    envir = runtime$states,
    inherits = FALSE
  ))

  missingness_environment$wlv_contract_register_result(
    runtime, "sea_sectors", "ratio", stats::setNames(1, "2000")
  )
  expect_false(exists(
    missingness_environment$wlv_contract_state_key("sea_sectors", "ratio"),
    envir = runtime$states,
    inherits = FALSE
  ))
})

test_that("persisted singleton indicator states apply to an array slice", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = missingness_environment$wlv_strict_missingness_policy(
      source = "synthetic", policy_id = "synthetic_strict"
    )
  )
  stored <- array(
    "not_applicable",
    dim = c(1L, 1L, 1L, 1L),
    dimnames = list("2000", "ratio", "A", "X")
  )
  missingness_environment$wlv_contract_register_states(
    runtime, "sea_sectors", "ratio", stored
  )
  value <- array(
    NA_real_,
    dim = c(1L, 1L, 1L),
    dimnames = list("2000", "A", "X")
  )

  result <- missingness_environment$wlv_ratio_runtime(
    runtime,
    numerator = value,
    denominator = value,
    zero = "not_applicable",
    artifact = "sea_sectors",
    indicator = "ratio",
    checkpoint = "after_stage_5",
    stage = 5L,
    module = "test-roundtrip-slice.R",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
  expect_true(is.na(result[[1L]]))
  expect_identical(attr(result, "wlv_state")[[1L]], "not_applicable")
})

test_that("persisted singleton states cannot be relabelled onto another slice", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = missingness_environment$wlv_strict_missingness_policy(
      source = "synthetic", policy_id = "synthetic_strict"
    )
  )
  stored <- array(
    "not_applicable",
    dim = c(1L, 1L, 1L, 1L),
    dimnames = list("2000", "ratio", "OLD_SECTOR", "OLD_COUNTRY")
  )
  missingness_environment$wlv_contract_register_states(
    runtime, "sea_sectors", "ratio", stored
  )
  relabelled <- array(
    NA_real_,
    dim = c(1L, 1L, 1L),
    dimnames = list("2001", "NEW_SECTOR", "NEW_COUNTRY")
  )

  expect_error(
    missingness_environment$wlv_contract_declared_states(
      runtime,
      artifact = "sea_sectors",
      indicator = "ratio",
      value = relabelled,
      checkpoint = "after_stage_5"
    ),
    "labels do not match",
    fixed = TRUE
  )
})

test_that("registered slice states expand only onto the matching indicator", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = missingness_environment$wlv_strict_missingness_policy(
      source = "synthetic", policy_id = "synthetic_strict"
    )
  )
  stored <- array(
    "not_applicable",
    dim = c(1L, 1L, 1L),
    dimnames = list("2000", "S", "A")
  )
  missingness_environment$wlv_contract_register_states(
    runtime, "sea_sectors", "ratio", stored
  )
  matching <- array(
    NA_real_,
    dim = c(1L, 1L, 1L, 1L),
    dimnames = list("2000", "ratio", "S", "A")
  )
  expect_identical(
    as.vector(missingness_environment$wlv_contract_declared_states(
      runtime,
      artifact = "sea_sectors",
      indicator = "ratio",
      value = matching,
      checkpoint = "pre_publish"
    )),
    "not_applicable"
  )

  dimnames(matching)[[2L]] <- "other"
  expect_error(
    missingness_environment$wlv_contract_declared_states(
      runtime,
      artifact = "sea_sectors",
      indicator = "ratio",
      value = matching,
      checkpoint = "pre_publish"
    ),
    "labels do not match",
    fixed = TRUE
  )
})

test_that("same-rank registered states reject relabelled coordinates", {
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = missingness_environment$wlv_strict_missingness_policy(
      source = "synthetic", policy_id = "synthetic_strict"
    )
  )
  stored <- array(
    "not_applicable",
    dim = c(1L, 1L, 1L),
    dimnames = list("2000", "OLD_SECTOR", "OLD_COUNTRY")
  )
  missingness_environment$wlv_contract_register_states(
    runtime, "sea_sectors", "ratio", stored
  )
  relabelled <- array(
    NA_real_,
    dim = c(1L, 1L, 1L),
    dimnames = list("2001", "NEW_SECTOR", "NEW_COUNTRY")
  )
  expect_error(
    missingness_environment$wlv_contract_declared_states(
      runtime,
      artifact = "sea_sectors",
      indicator = "ratio",
      value = relabelled,
      checkpoint = "pre_publish"
    ),
    "labels do not match",
    fixed = TRUE
  )

  longer <- array(
    NA_real_,
    dim = c(2L, 1L, 1L),
    dimnames = list(c("2000", "2001"), "OLD_SECTOR", "OLD_COUNTRY")
  )
  expect_error(
    missingness_environment$wlv_contract_declared_states(
      runtime,
      artifact = "sea_sectors",
      indicator = "ratio",
      value = longer,
      checkpoint = "pre_publish"
    ),
    "shape does not match",
    fixed = TRUE
  )
})

test_that("persisted non-applicable states survive selective recalculation", {
  root <- tempfile("wlv-contract-states-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  policy <- missingness_environment$wlv_strict_missingness_policy(
    source = "synthetic",
    policy_id = "synthetic_strict"
  )
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = policy
  )
  sea_sectors <- array(
    c(NA_real_, 1),
    dim = c(1L, 2L, 1L, 1L),
    dimnames = list("2000", c("ratio", "other"), "S", "A")
  )
  sea_countries <- array(
    c(NA_real_, 1, NA_real_, 2),
    dim = c(1L, 2L, 2L),
    dimnames = list("2000", c("ratio", "other"), c("A", "WWW"))
  )
  sector_states <- array(
    "not_applicable",
    dim = c(1L, 1L, 1L, 1L),
    dimnames = list("2000", "ratio", "S", "A")
  )
  country_states <- array(
    "not_applicable",
    dim = c(1L, 1L, 2L),
    dimnames = list("2000", "ratio", c("A", "WWW"))
  )
  missingness_environment$wlv_contract_register_states(
    runtime, "sea_sectors", "ratio", sector_states
  )
  missingness_environment$wlv_contract_register_states(
    runtime, "sea_countries", "ratio", country_states
  )
  reader <- function(path) {
    if (basename(path) == "sea_sectors.fst") sea_sectors else sea_countries
  }
  state_path <- missingness_environment$wlv_write_contract_states(
    runtime,
    root,
    reader = reader
  )
  records <- utils::read.csv2(state_path, stringsAsFactors = FALSE)
  expect_identical(nrow(records), 3L)
  expect_true(all(records$state == "not_applicable"))

  semantically_corrupt <- records
  semantically_corrupt$state[[1L]] <- "source_missing"
  expect_error(
    missingness_environment$wlv_assert_contract_states_roundtrip(
      runtime,
      semantically_corrupt,
      values = list(
        sea_sectors = sea_sectors,
        sea_countries = sea_countries
      )
    ),
    "differ from the in-memory contract",
    fixed = TRUE
  )

  restored <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = policy
  )
  expect_true(missingness_environment$wlv_load_contract_states(
    restored,
    state_path,
    values = list(
      sea_sectors = sea_sectors,
      sea_countries = sea_countries
    )
  ))
  missingness_environment$wlv_contract_clear_states(
    restored,
    "sea_sectors",
    "other"
  )
  solutions <- data.frame(
    names = c("ratio", "other"),
    stage = c(5L, 5L),
    stringsAsFactors = FALSE
  )
  expect_no_error(missingness_environment$wlv_validate_sea_stage(
    restored,
    sea_sectors,
    solutions,
    stage = 5L,
    checkpoint = "recalc_preserved"
  ))
  expect_no_error(missingness_environment$wlv_validate_sea_countries_contract(
    restored,
    sea_countries,
    checkpoint = "recalc_preserved"
  ))

  corrupt <- records
  corrupt$country[[1L]] <- "UNKNOWN"
  corrupt_path <- file.path(root, "corrupt-states.csv")
  utils::write.csv2(corrupt, corrupt_path, row.names = FALSE)
  expect_error(
    missingness_environment$wlv_load_contract_states(
      wlv_test_contract_runtime(missingness_environment,
        method = "synthetic", source = "synthetic", policy = policy
      ),
      corrupt_path,
      values = list(sea_sectors = sea_sectors, sea_countries = sea_countries)
    ),
    "unknown country coordinate",
    fixed = TRUE
  )
  expect_error(
    missingness_environment$wlv_load_contract_states(
      wlv_test_contract_runtime(missingness_environment,
        method = "synthetic", source = "synthetic", policy = policy
      ),
      file.path(root, "missing-states.csv"),
      values = list(sea_sectors = sea_sectors, sea_countries = sea_countries)
    ),
    "cannot authorize persisted missing values",
    fixed = TRUE
  )
})

test_that("successful anomaly reports append repeated recalculation events", {
  root <- tempfile("wlv-contract-report-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  policy <- missingness_environment$wlv_strict_missingness_policy(
    source = "synthetic", policy_id = "synthetic_strict"
  )
  context <- wlv_missingness_test_context(policy_id = "synthetic_strict")
  value <- array(
    NaN,
    dim = c(1L, 1L, 1L),
    dimnames = list("2000", "S", "A")
  )
  event <- missingness_environment$wlv_contract_table(
    value,
    array(TRUE, dim = dim(value), dimnames = dimnames(value)),
    context,
    "mark_not_applicable"
  )
  first <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic", source = "synthetic", policy = policy
  )
  missingness_environment$wlv_contract_record(first, event)
  path <- file.path(root, "_anomalies.csv")
  missingness_environment$wlv_write_contract_report(first, path)

  second <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic", source = "synthetic", policy = policy
  )
  expect_true(missingness_environment$wlv_load_contract_report(second, path))
  missingness_environment$wlv_contract_record(second, event)
  missingness_environment$wlv_write_contract_report(second, path)
  restored <- missingness_environment$wlv_read_contract_report(path)
  expect_identical(nrow(restored), 2L)
  expect_identical(as.list(restored[1L, ]), as.list(restored[2L, ]))
})

test_that("classification keeps zero finite and requires explicit missing states", {
  value <- array(
    c(0, NA_real_, NA_real_, NA_real_),
    dim = c(4L, 1L, 1L),
    dimnames = list(as.character(2000:2003), "S", "A")
  )
  states <- array(
    c(NA, "uncomputed", "source_missing", "not_applicable"),
    dim = dim(value),
    dimnames = dimnames(value)
  )

  classified <- missingness_environment$wlv_classify_missingness(
    value,
    allowed_missing = states,
    context = wlv_missingness_test_context()
  )

  expect_identical(
    as.vector(classified),
    c("finite", "uncomputed", "source_missing", "not_applicable")
  )
  expect_identical(value[[1L]], 0)

  masks <- list(source_missing = is.na(value))
  expect_identical(
    as.vector(missingness_environment$wlv_classify_missingness(
      value,
      allowed_missing = masks,
      context = wlv_missingness_test_context()
    )),
    c("finite", rep("source_missing", 3L))
  )

  caught <- tryCatch(
    missingness_environment$wlv_classify_missingness(
      value,
      context = wlv_missingness_test_context()
    ),
    wlv_contract_error = identity
  )
  expect_s3_class(caught, "wlv_contract_error")
  expect_identical(
    names(caught$anomalies),
    c(
      "artifact", "indicator", "checkpoint", "stage", "module", "year",
      "country", "sector", "output", "original_value", "policy_id", "action"
    )
  )
  expect_identical(caught$anomalies$original_value, rep("NA", 3L))
  expect_identical(caught$anomalies$action, rep("abort_unexpected_missing", 3L))
})

test_that("dimension roles can be inferred and missing masks must align by label", {
  value <- array(
    c(1, NA_real_),
    dim = c(2L, 1L, 1L),
    dimnames = list(
      year = c("2000", "2001"),
      sector = "S",
      country = "A"
    )
  )
  context <- missingness_environment$wlv_contract_context(
    artifact = "sea_sectors",
    indicator = "test.indicator",
    checkpoint = "after_stage_1",
    policy_id = "labels.strict"
  )
  mask <- is.na(value)

  classified <- missingness_environment$wlv_classify_missingness(
    value,
    allowed_missing = list(source_missing = mask),
    context = context
  )
  expect_identical(as.vector(classified), c("finite", "source_missing"))

  unexpected <- tryCatch(
    missingness_environment$wlv_classify_missingness(value, context = context),
    wlv_contract_error = identity
  )
  expect_identical(unexpected$anomalies$year, "2001")
  expect_identical(unexpected$anomalies$sector, "S")
  expect_identical(unexpected$anomalies$country, "A")

  misaligned <- mask
  dimnames(misaligned)[[1L]] <- rev(dimnames(misaligned)[[1L]])
  expect_error(
    missingness_environment$wlv_classify_missingness(
      value,
      allowed_missing = list(source_missing = misaligned),
      context = context
    ),
    "different labels",
    fixed = TRUE
  )

  states <- array(
    c(NA_character_, "source_missing"),
    dim = dim(value),
    dimnames = dimnames(value)
  )
  dimnames(states)[[1L]] <- rev(dimnames(states)[[1L]])
  expect_error(
    missingness_environment$wlv_classify_missingness(
      value,
      allowed_missing = states,
      context = context
    ),
    "shape and labels",
    fixed = TRUE
  )
})

test_that("NaN and both infinities are anomalies even under an allowed mask", {
  value <- array(
    c(NaN, Inf, -Inf),
    dim = c(3L, 1L, 1L),
    dimnames = list(as.character(2000:2002), "S", "A")
  )
  allowed <- list(
    source_missing = array(TRUE, dim = dim(value), dimnames = dimnames(value))
  )

  caught <- tryCatch(
    missingness_environment$wlv_classify_missingness(
      value,
      allowed_missing = allowed,
      context = wlv_missingness_test_context(policy_id = "never.nonfinite")
    ),
    wlv_contract_error = identity
  )

  expect_s3_class(caught, "wlv_contract_error")
  expect_identical(caught$anomalies$year, as.character(2000:2002))
  expect_identical(caught$anomalies$country, rep("A", 3L))
  expect_identical(caught$anomalies$sector, rep("S", 3L))
  expect_identical(caught$anomalies$original_value, c("NaN", "Inf", "-Inf"))
  expect_identical(caught$anomalies$policy_id, rep("never.nonfinite", 3L))
  expect_identical(caught$anomalies$action, rep("abort_non_finite", 3L))
})

test_that("aggregation distinguishes all missing, zero and partial groups", {
  value <- matrix(
    c(NA_real_, NA_real_, 0, 0, 1, NA_real_),
    nrow = 2L,
    dimnames = list(c("S1", "S2"), c("all_missing", "zeros", "partial"))
  )
  allowed <- list(source_missing = is.na(value))
  context <- wlv_missingness_test_context(
    policy_id = "country.available",
    axes = c(sector = 1L, country = 2L)
  )

  available_sum <- missingness_environment$wlv_contract_aggregate(
    value,
    margin = 2L,
    operation = "sum",
    missing = "available",
    allowed_missing = allowed,
    context = context
  )
  expect_equal(as.vector(available_sum), c(NA_real_, 0, 1))
  expect_identical(
    as.vector(attr(available_sum, "wlv_state")),
    c("source_missing", "finite", "finite")
  )
  expect_identical(
    unique(attr(available_sum, "wlv_actions")$action),
    c("preserve_all_missing", "aggregate_available")
  )

  available_mean <- missingness_environment$wlv_contract_aggregate(
    value,
    margin = 2L,
    operation = "mean",
    missing = "available",
    allowed_missing = allowed,
    context = context
  )
  expect_equal(as.vector(available_mean), c(NA_real_, 0, 1))

  propagated <- missingness_environment$wlv_contract_aggregate(
    value,
    margin = 2L,
    operation = "sum",
    missing = "propagate",
    allowed_missing = allowed,
    context = context
  )
  expect_equal(as.vector(propagated), c(NA_real_, 0, NA_real_))
  expect_identical(
    as.vector(attr(propagated, "wlv_state")),
    c("source_missing", "finite", "source_missing")
  )

  caught <- tryCatch(
    missingness_environment$wlv_contract_aggregate(
      value,
      margin = 2L,
      operation = "sum",
      missing = "error",
      allowed_missing = allowed,
      context = context
    ),
    wlv_contract_error = identity
  )
  expect_s3_class(caught, "wlv_contract_error")
  expect_identical(nrow(caught$anomalies), 3L)
  expect_identical(
    caught$anomalies$action,
    rep("abort_missing_aggregation", 3L)
  )
})

test_that("safe division implements each zero-denominator policy explicitly", {
  context <- wlv_missingness_test_context(
    policy_id = "ratio.zero",
    axes = c(year = 1L)
  )
  numerator <- stats::setNames(c(0, 1, 4), as.character(2000:2002))
  denominator <- stats::setNames(c(0, 0, 2), as.character(2000:2002))

  caught <- tryCatch(
    missingness_environment$wlv_safe_divide(
      numerator,
      denominator,
      zero = "error",
      context = context
    ),
    wlv_contract_error = identity
  )
  expect_s3_class(caught, "wlv_contract_error")
  expect_identical(caught$anomalies$original_value, c("NaN", "Inf"))
  expect_identical(caught$anomalies$action, rep("abort_zero_denominator", 2L))

  both_zero <- missingness_environment$wlv_safe_divide(
    numerator[c(1L, 3L)],
    denominator[c(1L, 3L)],
    zero = "zero_if_both_zero",
    context = context
  )
  expect_equal(as.vector(both_zero), c(0, 2))
  expect_identical(as.vector(attr(both_zero, "wlv_state")), rep("finite", 2L))
  expect_identical(
    attr(both_zero, "wlv_actions")$action,
    "replace_both_zero_with_zero"
  )

  expect_error(
    missingness_environment$wlv_safe_divide(
      numerator,
      denominator,
      zero = "zero_if_both_zero",
      context = context
    ),
    class = "wlv_contract_error"
  )

  not_applicable <- missingness_environment$wlv_safe_divide(
    numerator,
    denominator,
    zero = "not_applicable",
    context = context
  )
  expect_equal(as.vector(not_applicable), c(NA_real_, NA_real_, 2))
  expect_identical(
    as.vector(attr(not_applicable, "wlv_state")),
    c("not_applicable", "not_applicable", "finite")
  )
  expect_identical(
    attr(not_applicable, "wlv_actions")$action,
    rep("mark_not_applicable", 2L)
  )

  strict_not_applicable <- missingness_environment$wlv_safe_divide(
    numerator[c(1L, 3L)],
    denominator[c(1L, 3L)],
    zero = "not_applicable_if_both_zero",
    context = context
  )
  expect_equal(as.vector(strict_not_applicable), c(NA_real_, 2))
  expect_identical(
    as.vector(attr(strict_not_applicable, "wlv_state")),
    c("not_applicable", "finite")
  )
  expect_error(
    missingness_environment$wlv_safe_divide(
      numerator,
      denominator,
      zero = "not_applicable_if_both_zero",
      context = context
    ),
    class = "wlv_contract_error"
  )

  legitimate_zero <- missingness_environment$wlv_safe_divide(
    stats::setNames(0, "2000"),
    stats::setNames(2, "2000"),
    zero = "error",
    context = context
  )
  expect_identical(as.vector(legitimate_zero), 0)
  expect_identical(as.vector(attr(legitimate_zero, "wlv_state")), "finite")
})

test_that("array axis titles do not make otherwise aligned values incompatible", {
  numerator <- array(
    1:4,
    dim = c(2L, 2L),
    dimnames = list(year = c("2000", "2001"), sector = c("A", "B"))
  )
  denominator <- numerator
  names(dimnames(denominator)) <- c("period", "industry")

  expect_invisible(
    missingness_environment$wlv_assert_conformable_numeric(
      numerator, denominator
    )
  )
})

test_that("Leontief nonzero-over-zero exceptions are source- and hash-pinned", {
  policy <- missingness_environment$wlv_strict_missingness_policy(
    source = "synthetic", policy_id = "synthetic_strict"
  )
  numerator <- array(1, dim = c(1L, 1L, 1L))
  denominator <- array(0, dim = c(1L, 1L, 1L))

  synthetic_runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic", source = "synthetic", policy = policy
  )
  expect_error(
    missingness_environment$wlv_allowlisted_leontief_zero_output(
      synthetic_runtime,
      numerator,
      denominator,
      years = "2000",
      inputs = "A.X",
      outputs = "A.X"
    ),
    "differ from explicit scientific profile"
  )

  wiodr13_runtime <- missingness_environment$wlv_new_contract_runtime(
    method = "wiodr13v09",
    source = "wiodr13",
    policy = policy,
    scientific_profile = missingness_environment$
      wlv_scientific_profile_contract(
        id = "wiodr13_v09_v1",
        method = "wiodr13v09",
        source = "wiodr13",
        output_profile = "wiodr13_v09",
        leontief_zero = list(
          id = "wiodr13_v09_zero_v1",
          exception_count = 2945L,
          coordinate_md5 = "3fd6663ca00317b42d3044df5019db4c",
          counts = data.frame(
            year = "2000",
            output = "A.X",
            exception_count = 2945L,
            stringsAsFactors = FALSE
          )
        ),
        leontief_signed = list(
          id = "wiodr13_v09_signed_v1",
          rows = data.frame(
            year = "2000",
            coefficient_negative_count = 0L,
            certificate_type = "productivity_nonnegative",
            stringsAsFactors = FALSE
          )
        ),
        nonfinite_resolution = list(
          id = "nonfinite_none_v1",
          action = "reject",
          expected_count = 0L,
          groups = data.frame(
            binding = character(), indicator = character(),
            kind = character(), module = character(),
            expected_count = integer(), coordinate_sha256 = character(),
            stringsAsFactors = FALSE
          ),
          rules = data.frame(
            artifact = character(), indicator = character(),
            year = character(), country = character(),
            sector = character(), from = character(), to = character(),
            stringsAsFactors = FALSE
          )
        )
      )
  )
  expect_error(
    missingness_environment$wlv_allowlisted_leontief_zero_output(
      wiodr13_runtime,
      numerator,
      denominator,
      years = "2000",
      inputs = "A.X",
      outputs = "A.X"
    ),
    "differ from explicit scientific profile"
  )

  wrong_source_runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "wiodr13", source = "synthetic", policy = policy
  )
  expect_error(
    missingness_environment$wlv_allowlisted_leontief_zero_output(
      wrong_source_runtime,
      numerator,
      denominator,
      years = "2000",
      inputs = "A.X",
      outputs = "A.X"
    ),
    "differ from explicit scientific profile"
  )
})

test_that("persisted Leontief exceptions remain closed under the current profile", {
  e <- missingness_environment
  key <- "2000|A.X|B.Y"
  coordinate_md5 <- unclass(tolower(as.character(openssl::md5(
    charToRaw(enc2utf8(key))
  ))))
  profile <- e$wlv_scientific_profile_contract(
    id = "persisted_leontief_test_v1",
    method = "synthetic",
    source = "synthetic",
    output_profile = "synthetic_output",
    leontief_zero = list(
      id = "persisted_zero_test_v1",
      exception_count = 1L,
      coordinate_md5 = coordinate_md5,
      counts = data.frame(
        year = "2000",
        output = "B.Y",
        exception_count = 1L,
        stringsAsFactors = FALSE
      )
    ),
    leontief_signed = list(
      id = "persisted_signed_test_v1",
      rows = data.frame(
        year = "2000",
        coefficient_negative_count = 0L,
        certificate_type = "productivity_nonnegative",
        stringsAsFactors = FALSE
      )
    ),
    nonfinite_resolution = list(
      id = "persisted_nonfinite_none_v1",
      action = "reject",
      expected_count = 0L,
      groups = data.frame(
        binding = character(), indicator = character(),
        kind = character(), module = character(),
        expected_count = integer(), coordinate_sha256 = character(),
        stringsAsFactors = FALSE
      ),
      rules = data.frame(
        artifact = character(), indicator = character(),
        year = character(), country = character(), sector = character(),
        from = character(), to = character(), stringsAsFactors = FALSE
      )
    )
  )
  runtime <- e$wlv_new_contract_runtime(
    method = "synthetic",
    source = "synthetic",
    policy = e$wlv_strict_missingness_policy(
      source = "synthetic",
      policy_id = "synthetic_strict"
    ),
    scientific_profile = profile
  )
  anomaly <- data.frame(
    artifact = "m_io",
    indicator = "leontief_input_ratio",
    checkpoint = "after_matrices",
    stage = "3",
    module = "transformation.R",
    year = "2000",
    country = NA_character_,
    sector = "A.X",
    output = "B.Y",
    original_value = "Inf",
    policy_id = "persisted_zero_test_v1",
    action = "allowlisted_nonzero_over_zero",
    stringsAsFactors = FALSE
  )[e$wlv_contract_anomaly_columns()]
  expect_invisible(
    e$wlv_validate_leontief_zero_output_anomalies(runtime, anomaly)
  )

  tampered_policy <- anomaly
  tampered_policy$policy_id <- "old_profile_v1"
  expect_error(
    e$wlv_validate_leontief_zero_output_anomalies(runtime, tampered_policy),
    "differ from explicit scientific profile"
  )
  tampered_action <- anomaly
  tampered_action$action <- "replace_both_zero_with_zero"
  expect_error(
    e$wlv_validate_leontief_zero_output_anomalies(runtime, tampered_action),
    "differ from explicit scientific profile"
  )
  tampered_coordinate <- anomaly
  tampered_coordinate$sector <- "A.Z"
  expect_error(
    e$wlv_validate_leontief_zero_output_anomalies(runtime, tampered_coordinate),
    "differ from explicit scientific profile"
  )
  expect_error(
    e$wlv_validate_leontief_zero_output_anomalies(
      runtime,
      rbind(anomaly, anomaly)
    ),
    "differ from explicit scientific profile"
  )

  empty_runtime <- wlv_test_contract_runtime(
    e,
    method = "synthetic",
    source = "synthetic",
    policy = runtime$policy
  )
  expect_invisible(e$wlv_validate_leontief_zero_output_anomalies(
    empty_runtime,
    e$wlv_empty_contract_table()
  ))
})

test_that("streaming Leontief scans preserve the zero-output audit trail", {
  years <- "2000"
  inputs <- c("A.S1", "A.S2", "A.U")
  productive <- c(TRUE, TRUE, FALSE)
  block <- matrix(
    c(2, 0, 1, 0),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(inputs[productive], inputs[productive])
  )
  gross_output <- stats::setNames(c(10, 0, 5), inputs)
  scan <- missingness_environment$wlv_scan_leontief_zero_output_year(
    block,
    gross_output,
    productive,
    year_index = 1L,
    year_count = 1L,
    inputs = inputs
  )
  profile <- missingness_environment$wlv_combine_leontief_zero_output_scans(
    list(scan),
    years,
    inputs
  )
  policy <- missingness_environment$wlv_strict_missingness_policy(
    source = "synthetic",
    policy_id = "synthetic_strict"
  )
  streaming_runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = policy
  )
  profile <-
    missingness_environment$wlv_validate_leontief_zero_output_profile(
      streaming_runtime,
      profile
    )
  missingness_environment$wlv_record_leontief_zero_output_profile(
    streaming_runtime,
    profile
  )

  full_numerator <- array(
    0,
    dim = c(1L, 3L, 3L),
    dimnames = list(years, inputs, inputs)
  )
  full_numerator[1L, productive, productive] <- block
  denominator <- array(
    rep(gross_output, each = length(inputs)),
    dim = dim(full_numerator),
    dimnames = dimnames(full_numerator)
  )
  legacy_runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = policy
  )
  adjusted <-
    missingness_environment$wlv_allowlisted_leontief_zero_output(
      legacy_runtime,
      full_numerator,
      denominator,
      years,
      inputs,
      inputs
    )
  missingness_environment$wlv_safe_divide_runtime(
    legacy_runtime,
    adjusted,
    denominator,
    zero = "zero_if_both_zero",
    artifact = "m_io",
    indicator = "leontief_input_ratio",
    checkpoint = "after_matrices",
    stage = 3L,
    module = "transformation.R",
    axes = c(year = 1L, sector = 2L, output = 3L)
  )

  expect_identical(streaming_runtime$anomalies, legacy_runtime$anomalies)
  expect_identical(
    streaming_runtime$anomalies$action,
    rep("replace_both_zero_with_zero", length(inputs))
  )
  expect_false(any(vapply(profile, is.matrix, logical(1L))))
})

test_that("streaming Leontief profile validation is atomic", {
  inputs <- c("A.S1", "A.S2", "A.U")
  productive <- c(TRUE, TRUE, FALSE)
  block <- matrix(
    c(2, 3, 1, 0),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(inputs[productive], inputs[productive])
  )
  scan <- missingness_environment$wlv_scan_leontief_zero_output_year(
    block,
    c(10, 0, 5),
    productive,
    year_index = 1L,
    year_count = 1L,
    inputs = inputs
  )
  profile <- missingness_environment$wlv_combine_leontief_zero_output_scans(
    list(scan),
    years = "2000",
    inputs = inputs
  )
  runtime <- wlv_test_contract_runtime(missingness_environment,
    method = "synthetic",
    source = "synthetic",
    policy = missingness_environment$wlv_strict_missingness_policy(
      source = "synthetic",
      policy_id = "synthetic_strict"
    )
  )

  expect_error(
    missingness_environment$wlv_validate_leontief_zero_output_profile(
      runtime,
      profile
    ),
    "differ from explicit scientific profile"
  )
  expect_identical(nrow(runtime$anomalies), 0L)

  allowlisted <-
    missingness_environment$wlv_leontief_zero_output_contract_table(
      runtime,
      profile,
      "invalid"
    )
  replaced <-
    missingness_environment$wlv_leontief_zero_output_contract_table(
      runtime,
      profile,
      "both_zero"
    )
  invalid_coordinate <- paste(
    allowlisted$year,
    allowlisted$sector,
    allowlisted$output,
    sep = "|"
  )
  replacement_coordinates <- paste(
    replaced$year,
    replaced$sector,
    replaced$output,
    sep = "|"
  )
  expect_true(all(invalid_coordinate %in% replacement_coordinates))
  expect_true(all(
    allowlisted$action == "allowlisted_nonzero_over_zero"
  ))
  expect_true(all(
    replaced$action == "replace_both_zero_with_zero"
  ))
  combined_actions <- rbind(allowlisted, replaced)
  combined_coordinates <- paste(
    combined_actions$year,
    combined_actions$sector,
    combined_actions$output,
    sep = "|"
  )
  for (coordinate in invalid_coordinate) {
    expect_setequal(
      combined_actions$action[combined_coordinates == coordinate],
      c(
        "allowlisted_nonzero_over_zero",
        "replace_both_zero_with_zero"
      )
    )
  }
})

test_that("alternative-2 historical 0/0 transitions are closed before storage", {
  e <- missingness_environment
  years <- c("2000", "2001")
  sectors <- c("P", "50")
  countries <- c("AUS", "CHN")
  indicators <- c(
    "hours_worked.empe_hs.r.pc",
    "hours_worked.empe_ms.r.pc",
    "hours_worked.empe_ls.r.pc"
  )
  coordinates <- data.frame(
    country = c("AUS", "CHN"),
    sector = c("P", "50"),
    stringsAsFactors = FALSE
  )
  rules <- do.call(rbind, lapply(indicators, function(indicator) {
    data.frame(
      artifact = "sea_sectors",
      indicator = indicator,
      year = "*",
      country = coordinates$country,
      sector = coordinates$sector,
      from = "NaN",
      to = "0",
      stringsAsFactors = FALSE
    )
  }))
  keys <- sort(unlist(lapply(indicators, function(indicator) {
    unlist(lapply(seq_len(nrow(coordinates)), function(index) {
      paste(
        indicator,
        years,
        coordinates$country[[index]],
        coordinates$sector[[index]],
        sep = "|"
      )
    }), use.names = FALSE)
  }), use.names = FALSE), method = "radix")
  group_keys <- sort(unlist(lapply(seq_len(nrow(coordinates)), function(index) {
    paste(
      years,
      coordinates$country[[index]],
      coordinates$sector[[index]],
      sep = "|"
    )
  }), use.names = FALSE), method = "radix")
  group_sha256 <- unclass(tolower(as.character(openssl::sha256(
    charToRaw(enc2utf8(paste(group_keys, collapse = "\n")))
  ))))
  scientific_profile <- e$wlv_scientific_profile_contract(
    id = "alternative_2_test_v1",
    method = "alternative_2",
    source = "wiodr13",
    output_profile = "wiodr13_reduction",
    leontief_zero = list(
      id = "test_zero_v1",
      exception_count = 0L,
      coordinate_md5 = "d41d8cd98f00b204e9800998ecf8427e",
      counts = data.frame(
        year = character(), output = character(),
        exception_count = integer(), stringsAsFactors = FALSE
      )
    ),
    leontief_signed = list(
      id = "test_signed_v1",
      rows = data.frame(
        year = years,
        coefficient_negative_count = c(0L, 0L),
        certificate_type = rep("productivity_nonnegative", 2L),
        stringsAsFactors = FALSE
      )
    ),
    nonfinite_resolution = list(
      id = "alternative_2_test_nonfinite_v1",
      action = "replace_nan_with_zero",
      expected_count = length(keys),
      groups = data.frame(
        binding = indicators,
        indicator = indicators,
        kind = rep("NaN", length(indicators)),
        module = rep("alternative_2_test", length(indicators)),
        expected_count = rep(length(group_keys), length(indicators)),
        coordinate_sha256 = rep(group_sha256, length(indicators)),
        stringsAsFactors = FALSE
      ),
      rules = rules
    )
  )
  new_runtime <- function() e$wlv_new_contract_runtime(
    method = "alternative_2",
    source = "wiodr13",
    policy = e$wlv_strict_missingness_policy(
      source = "wiodr13",
      policy_id = "test_strict"
    ),
    scientific_profile = scientific_profile
  )
  dimensions <- c(length(years), length(sectors), length(countries))
  labels <- list(year = years, sector = sectors, country = countries)
  denominator <- array(1, dim = dimensions, dimnames = labels)
  denominator[, "P", "AUS"] <- 0
  denominator[, "50", "CHN"] <- 0
  numerators <- stats::setNames(lapply(indicators, function(indicator) {
    value <- array(1, dim = dimensions, dimnames = labels)
    value[, "P", "AUS"] <- 0
    value[, "50", "CHN"] <- 0
    value
  }), indicators)
  raw <- lapply(numerators, function(numerator) numerator / denominator)

  runtime <- new_runtime()
  resolved <- e$wlv_resolve_profiled_nonfinite(
    runtime,
    values = raw,
    numerators = numerators,
    denominator = denominator,
    artifact = "sea_sectors",
    checkpoint = "after_stage_2",
    stage = 2L,
    module = "alternative_2_test",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
  diagnostic <- e$wlv_normalize_nonfinite_resolution_diagnostics(
    resolved$diagnostics[["_nonfinite_resolution_diagnostics.csv"]]
  )
  expect_identical(sum(diagnostic$resolved_count), length(keys))
  expect_identical(diagnostic$binding, sort(indicators, method = "radix"))
  expect_true(all(diagnostic$coordinate_sha256 == group_sha256))
  expect_true(all(vapply(resolved$values, function(value) {
    all(is.finite(value)) &&
      all(value[, "P", "AUS"] == 0) &&
      all(value[, "50", "CHN"] == 0)
  }, logical(1L))))
  expect_identical(nrow(runtime$anomalies), length(keys))
  expect_true(all(
    runtime$anomalies$action ==
      "replace_profiled_historical_nan_with_zero"
  ))
  expect_true(all(runtime$anomalies$original_value == "NaN"))
  expect_true(all(
    runtime$anomalies$policy_id == "alternative_2_test_nonfinite_v1"
  ))
  expect_invisible(e$wlv_validate_nonfinite_resolution_anomalies(
    runtime,
    runtime$anomalies
  ))
  tampered_values <- list(
    artifact = "sea_countries",
    indicator = "wrong.indicator",
    checkpoint = "after_stage_1",
    stage = "1",
    module = "wrong.module",
    year = "2099",
    country = "ZZZ",
    sector = "WRONG",
    output = "OUT",
    original_value = "Inf",
    policy_id = "wrong_policy",
    action = "wrong_action"
  )
  for (field in names(tampered_values)) {
    tampered <- runtime$anomalies
    tampered[[field]][[1L]] <- tampered_values[[field]]
    expect_error(
      e$wlv_validate_nonfinite_resolution_anomalies(runtime, tampered),
      "Non-finite anomaly",
      info = field
    )
  }
  expect_error(
    e$wlv_validate_nonfinite_resolution_anomalies(
      runtime,
      runtime$anomalies[-1L, , drop = FALSE]
    ),
    "Non-finite anomaly audit count"
  )
  expect_error(
    e$wlv_validate_nonfinite_resolution_anomalies(
      runtime,
      rbind(runtime$anomalies, runtime$anomalies[1L, , drop = FALSE])
    ),
    "Non-finite anomaly audit count"
  )

  reordered <- rev(indicators)
  reordered_result <- e$wlv_resolve_profiled_nonfinite(
    new_runtime(),
    values = raw[reordered],
    numerators = numerators[reordered],
    denominator = denominator,
    artifact = "sea_sectors",
    checkpoint = "after_stage_2",
    stage = 2L,
    module = "alternative_2_test",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
  expect_identical(names(reordered_result$values), reordered)

  missing_coordinate <- raw
  missing_coordinate[[1L]]["2000", "P", "AUS"] <- 0
  mismatch_runtime <- new_runtime()
  expect_error(
    e$wlv_resolve_profiled_nonfinite(
      mismatch_runtime,
      missing_coordinate,
      numerators,
      denominator,
      "sea_sectors",
      "after_stage_2",
      2L,
      "alternative_2_test",
      c(year = 1L, sector = 2L, country = 3L)
    ),
    "differs from explicit profile"
  )
  expect_false(any(
    mismatch_runtime$anomalies$action ==
      "replace_profiled_historical_nan_with_zero"
  ))

  wrong_origin <- numerators
  wrong_origin[[1L]]["2000", "P", "AUS"] <- 1
  origin_runtime <- new_runtime()
  expect_error(
    e$wlv_resolve_profiled_nonfinite(
      origin_runtime,
      raw,
      wrong_origin,
      denominator,
      "sea_sectors",
      "after_stage_2",
      2L,
      "alternative_2_test",
      c(year = 1L, sector = 2L, country = 3L)
    ),
    "0/0 origin",
    fixed = TRUE
  )
})

test_that("profiled zero-denominator resolution pins kinds and coordinates", {
  e <- missingness_environment
  hash <- function(keys) {
    unclass(tolower(as.character(openssl::sha256(
      charToRaw(enc2utf8(paste(sort(keys, method = "radix"), collapse = "\n")))
    ))))
  }
  nan_key <- "2000|AAA|S1"
  inf_key <- "2000|AAA|S2"
  profile <- e$wlv_scientific_profile_contract(
    id = "ochoa_test_v1",
    method = "ochoa_1",
    source = "wiodr13",
    output_profile = "wiodr13_reduction",
    leontief_zero = list(
      id = "test_zero_v1",
      exception_count = 0L,
      coordinate_md5 = "d41d8cd98f00b204e9800998ecf8427e",
      counts = data.frame(
        year = character(), output = character(),
        exception_count = integer(), stringsAsFactors = FALSE
      )
    ),
    leontief_signed = list(
      id = "test_signed_v1",
      rows = data.frame(
        year = "2000",
        coefficient_negative_count = 0L,
        certificate_type = "productivity_nonnegative",
        stringsAsFactors = FALSE
      )
    ),
    nonfinite_resolution = list(
      id = "ochoa_wage_test_v1",
      action = "replace_zero_denominator_with_zero",
      expected_count = 2L,
      groups = data.frame(
        binding = c("emp", "emp"),
        indicator = rep("complex_labour_multiplier.emp.r.un", 2L),
        kind = c("Inf", "NaN"),
        module = c("ochoa_test", "ochoa_test"),
        expected_count = c(1L, 1L),
        coordinate_sha256 = c(hash(inf_key), hash(nan_key)),
        stringsAsFactors = FALSE
      ),
      rules = data.frame(
        artifact = character(), indicator = character(),
        year = character(), country = character(), sector = character(),
        from = character(), to = character(), stringsAsFactors = FALSE
      )
    )
  )
  runtime <- e$wlv_new_contract_runtime(
    method = "ochoa_1",
    source = "wiodr13",
    policy = e$wlv_strict_missingness_policy(
      source = "wiodr13", policy_id = "test_strict"
    ),
    scientific_profile = profile
  )
  labels <- list(year = "2000", sector = c("S1", "S2"), country = "AAA")
  numerator <- array(c(0, 2), dim = c(1L, 2L, 1L), dimnames = labels)
  denominator <- array(0, dim = c(1L, 2L, 1L), dimnames = labels)
  resolved <- e$wlv_resolve_profiled_zero_denominator(
    runtime,
    numerator,
    denominator,
    binding = "emp",
    indicator = "complex_labour_multiplier.emp.r.un",
    artifact = "sea_sectors",
    checkpoint = "after_stage_2",
    stage = 2L,
    module = "ochoa_test",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )

  expect_identical(as.vector(resolved$value), c(0, 0))
  expect_identical(nrow(runtime$anomalies), 2L)
  expect_true(all(
    runtime$anomalies$action == "replace_zero_denominator_with_zero"
  ))
  diagnostic <- e$wlv_normalize_nonfinite_resolution_diagnostics(
    resolved$diagnostics[["_nonfinite_resolution_diagnostics.csv"]]
  )
  expect_identical(diagnostic$kind, c("Inf", "NaN"))
  expect_identical(diagnostic$resolved_count, c(1L, 1L))
  expect_invisible(e$wlv_validate_nonfinite_resolution_anomalies(
    runtime,
    runtime$anomalies
  ))
  swapped_kind <- runtime$anomalies
  swapped_kind$original_value[[1L]] <- if (
    swapped_kind$original_value[[1L]] == "NaN"
  ) "Inf" else "NaN"
  expect_error(
    e$wlv_validate_nonfinite_resolution_anomalies(runtime, swapped_kind),
    "Non-finite anomaly group"
  )
  negative_infinite <- runtime$anomalies
  negative_infinite$original_value[[1L]] <- "-Inf"
  expect_error(
    e$wlv_validate_nonfinite_resolution_anomalies(
      runtime,
      negative_infinite
    ),
    "Non-finite anomaly group"
  )

  changed <- numerator
  changed["2000", "S1", "AAA"] <- 1
  expect_error(
    e$wlv_resolve_profiled_zero_denominator(
      runtime,
      changed,
      denominator,
      binding = "emp",
      indicator = "complex_labour_multiplier.emp.r.un",
      artifact = "sea_sectors",
      checkpoint = "after_stage_2",
      stage = 2L,
      module = "ochoa_test",
      axes = c(year = 1L, sector = 2L, country = 3L)
    ),
    "kinds differ"
  )

  negative <- numerator
  negative["2000", "S2", "AAA"] <- -2
  expect_error(
    e$wlv_resolve_profiled_zero_denominator(
      runtime,
      negative,
      denominator,
      binding = "emp",
      indicator = "complex_labour_multiplier.emp.r.un",
      artifact = "sea_sectors",
      checkpoint = "after_stage_2",
      stage = 2L,
      module = "ochoa_test",
      axes = c(year = 1L, sector = 2L, country = 3L)
    ),
    "differs from explicit profile"
  )
})

test_that("an explicit empty Leontief exception profile accepts an empty scan", {
  e <- missingness_environment
  policy <- e$wlv_strict_missingness_policy(
    source = "wiodr16", policy_id = "wiodr16_strict"
  )
  profile <- e$wlv_scientific_profile_contract(
    id = "wiodr16_standard_v1",
    method = "wiodr16",
    source = "wiodr16",
    output_profile = "wiodr16_standard",
    leontief_zero = list(
      id = "wiodr16_zero_v1",
      exception_count = 0L,
      coordinate_md5 = "d41d8cd98f00b204e9800998ecf8427e",
      counts = data.frame(
        year = character(), output = character(),
        exception_count = integer(), stringsAsFactors = FALSE
      )
    ),
    leontief_signed = list(
      id = "wiodr16_signed_v1",
      rows = data.frame(
        year = "2000",
        coefficient_negative_count = 0L,
        certificate_type = "productivity_nonnegative",
        stringsAsFactors = FALSE
      )
    ),
    nonfinite_resolution = list(
      id = "nonfinite_none_v1",
      action = "reject",
      expected_count = 0L,
      groups = data.frame(
        binding = character(), indicator = character(),
        kind = character(), module = character(),
        expected_count = integer(), coordinate_sha256 = character(),
        stringsAsFactors = FALSE
      ),
      rules = data.frame(
        artifact = character(), indicator = character(),
        year = character(), country = character(),
        sector = character(), from = character(), to = character(),
        stringsAsFactors = FALSE
      )
    )
  )
  runtime <- e$wlv_new_contract_runtime(
    method = "wiodr16",
    source = "wiodr16",
    policy = policy,
    scientific_profile = profile
  )
  expect_invisible(e$wlv_validate_nonfinite_resolution_anomalies(
    runtime,
    runtime$anomalies
  ))
  forbidden_value <- array(
    NaN,
    dim = c(1L, 1L, 1L),
    dimnames = list(year = "2000", sector = "S1", country = "AAA")
  )
  forbidden_context <- e$wlv_contract_context_for(
    runtime,
    artifact = "sea_sectors",
    indicator = "forbidden.indicator",
    checkpoint = "after_stage_2",
    stage = 2L,
    module = "forbidden.module",
    axes = c(year = 1L, sector = 2L, country = 3L),
    policy_id = "nonfinite_none_v1"
  )
  forbidden <- e$wlv_contract_table(
    forbidden_value,
    array(TRUE, dim = dim(forbidden_value), dimnames = dimnames(forbidden_value)),
    forbidden_context,
    "replace_profiled_historical_nan_with_zero"
  )
  expect_error(
    e$wlv_validate_nonfinite_resolution_anomalies(runtime, forbidden),
    "forbidden by profile"
  )
  numerator <- array(1, dim = c(1L, 1L, 1L))
  denominator <- array(1, dim = c(1L, 1L, 1L))

  expect_identical(
    e$wlv_allowlisted_leontief_zero_output(
      runtime,
      numerator,
      denominator,
      years = "2000",
      inputs = "A.X",
      outputs = "A.X"
    ),
    numerator
  )
  expect_equal(nrow(runtime$anomalies), 0L)
})

test_that("safe division never accepts missing or non-finite operands", {
  context <- wlv_missingness_test_context(axes = c(year = 1L))
  denominator <- stats::setNames(c(1, 0), c("2000", "2001"))

  for (invalid in list(NA_real_, NaN, Inf, -Inf)) {
    numerator <- stats::setNames(c(invalid, 0), c("2000", "2001"))
    caught <- tryCatch(
      missingness_environment$wlv_safe_divide(
        numerator,
        denominator,
        zero = "not_applicable",
        context = context
      ),
      wlv_contract_error = identity
    )
    expect_s3_class(caught, "wlv_contract_error")
    expect_identical(caught$anomalies$year, "2000")
  }
})
