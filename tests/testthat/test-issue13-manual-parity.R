issue13_parity_environment <- new.env(parent = baseenv())
sys.source(
  file.path(
    wlv_test_root,
    "tests",
    "manual",
    "issue13-native-parity.R"
  ),
  envir = issue13_parity_environment
)

wlv_issue13_passing_comparison <- function() {
  data.frame(
    artifact = c("sea_sectors", "sea_countries", "m_io", "m_countries"),
    same_dim = TRUE,
    same_dimnames = TRUE,
    same_axis_labels = TRUE,
    same_axis_names = TRUE,
    same_na = TRUE,
    same_nan = TRUE,
    identical_values = TRUE,
    mismatch_count = 0,
    maximum_absolute_difference = 0,
    stringsAsFactors = FALSE
  )
}

test_that("manual issue 13 parity gate fails closed on every difference", {
  comparison <- wlv_issue13_passing_comparison()
  no_indicator_differences <- data.frame(
    artifact = character(),
    indicator = character(),
    mismatch_count = numeric(),
    stringsAsFactors = FALSE
  )
  expect_no_error(issue13_parity_environment$wlv_assert_issue13_parity(
    comparison,
    no_indicator_differences,
    TRUE
  ))

  for (field in issue13_parity_environment$wlv_issue13_parity_boolean_fields) {
    changed <- comparison
    changed[[field]][[1L]] <- FALSE
    expect_error(
      issue13_parity_environment$wlv_assert_issue13_parity(
        changed,
        no_indicator_differences,
        TRUE
      ),
      "scientific parity failed",
      fixed = TRUE,
      info = field
    )
  }
  changed <- comparison
  changed$mismatch_count[[1L]] <- 1
  expect_error(issue13_parity_environment$wlv_assert_issue13_parity(
    changed,
    no_indicator_differences,
    TRUE
  ))
  changed <- comparison
  changed$maximum_absolute_difference[[1L]] <- .Machine$double.eps
  expect_error(issue13_parity_environment$wlv_assert_issue13_parity(
    changed,
    no_indicator_differences,
    TRUE
  ))
  indicator_difference <- data.frame(
    artifact = "sea_sectors",
    indicator = "value.m.mv",
    mismatch_count = 1,
    stringsAsFactors = FALSE
  )
  expect_error(issue13_parity_environment$wlv_assert_issue13_parity(
    comparison,
    indicator_difference,
    TRUE
  ))
  expect_error(issue13_parity_environment$wlv_assert_issue13_parity(
    comparison,
    no_indicator_differences,
    FALSE
  ))
})
