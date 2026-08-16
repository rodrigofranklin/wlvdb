leontief_diagnostic_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "leontief_diagnostics.R"),
  envir = leontief_diagnostic_environment
)

test_that("asymmetric Leontief systems use the transposed productive solve", {
  labels <- c("A.S1", "A.S2", "A.U")
  coefficients <- matrix(
    c(
      0.10, 0.30, 0,
      0.05, 0.20, 0,
      0, 0, 0
    ),
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(labels, labels)
  )
  labour <- stats::setNames(c(2, 1, 0), labels)
  result <- leontief_diagnostic_environment$wlv_solve_leontief(
    coefficients,
    labour,
    productive = c(TRUE, TRUE, FALSE),
    gross_output = c(10, 20, 0),
    method = "asymmetric",
    year = "2000"
  )
  block_result <- leontief_diagnostic_environment$wlv_solve_leontief(
    coefficients[1:2, 1:2, drop = FALSE],
    labour,
    productive = c(TRUE, TRUE, FALSE),
    gross_output = stats::setNames(c(10, 20, 0), labels),
    method = "asymmetric",
    year = "2000"
  )
  expected <- c(
    base::solve(
      t(diag(2L) - coefficients[1:2, 1:2, drop = FALSE]),
      labour[1:2]
    ),
    0
  )
  old_inverse_result <- c(
    as.vector(
      labour[1:2] %*%
        base::solve(diag(2L) - coefficients[1:2, 1:2, drop = FALSE])
    ),
    0
  )
  wrong_solve_without_transpose <- c(
    base::solve(
      diag(2L) - coefficients[1:2, 1:2, drop = FALSE],
      labour[1:2]
    ),
    0
  )

  expect_equal(unname(result$lambda), unname(expected), tolerance = 1e-14)
  expect_identical(block_result$lambda, result$lambda)
  expect_identical(block_result$diagnostics, result$diagnostics)
  expect_equal(
    unname(result$lambda),
    unname(old_inverse_result),
    tolerance = 1e-14
  )
  expect_false(isTRUE(all.equal(
    unname(result$lambda),
    unname(wrong_solve_without_transpose),
    tolerance = 1e-10
  )))
  expect_identical(names(result$lambda), labels)
  expect_identical(result$lambda[[3L]], 0)
  expect_identical(result$diagnostics$productive_dimension, 2L)
  expect_identical(result$diagnostics$gross_output_zero_count, 1L)
  expect_identical(
    result$diagnostics$system_orientation,
    "t(I - C)[productive, productive] %*% lambda = direct_labour"
  )
  expect_identical(result$diagnostics$rcond_norm, "infinity")
  expect_identical(
    result$diagnostics$certificate_type,
    "productivity_nonnegative"
  )
  expect_equal(
    result$diagnostics$rcond_min,
    result$diagnostics$gamma_n /
      result$diagnostics$forward_error_budget,
    tolerance = 0
  )
  expect_equal(
    result$diagnostics$max_backward_error,
    8 * result$diagnostics$gamma_n,
    tolerance = 0
  )
  expect_equal(
    result$diagnostics$refinement_trigger,
    64 * .Machine$double.eps,
    tolerance = 0
  )
  expect_equal(
    result$diagnostics$forward_error_bound,
    result$diagnostics$eta_normwise / result$diagnostics$rcond,
    tolerance = 0
  )
  expect_lt(result$diagnostics$certificate_ratio_upper, 1)
  expect_match(result$diagnostics$lambda_fingerprint, "^[0-9a-f]{32}$")
})

test_that("lambda fingerprints bind canonical labels and full precision values", {
  fingerprint <- leontief_diagnostic_environment$wlv_lambda_fingerprint
  lambda <- stats::setNames(c(1 / 3, 2), c("A.S1", "B.S2"))

  expect_identical(fingerprint(lambda), fingerprint(lambda))
  expect_false(identical(
    fingerprint(lambda),
    fingerprint(stats::setNames(lambda, rev(names(lambda))))
  ))
  changed <- lambda
  changed[[1L]] <- changed[[1L]] + .Machine$double.eps
  expect_false(identical(fingerprint(lambda), fingerprint(changed)))
})

test_that("singular and policy-defined near-singular systems fail informatively", {
  singular <- diag(c(1, 0.2))
  expect_error(
    leontief_diagnostic_environment$wlv_solve_leontief(
      singular,
      c(1, 1),
      method = "singular",
      year = "2000"
    ),
    "is singular",
    fixed = TRUE
  )

  near_singular <- diag(c(1 - 1e-10, 0.2))
  expect_error(
    leontief_diagnostic_environment$wlv_solve_leontief(
      near_singular,
      c(1, 1),
      method = "near-singular",
      year = "2001"
    ),
    "numerically near-singular",
    fixed = TRUE
  )
  relaxed <- leontief_diagnostic_environment$wlv_solve_leontief(
    near_singular,
    c(1, 1),
    method = "near-singular",
    year = "2001",
    policy = list(rcond_min = .Machine$double.eps)
  )
  expect_gt(relaxed$diagnostics$rcond, .Machine$double.eps)
  expect_lt(relaxed$diagnostics$rcond, sqrt(.Machine$double.eps))
})

test_that("invertible but unproductive nonnegative systems are rejected", {
  coefficients <- diag(c(1.1, 0.2))
  expect_error(
    leontief_diagnostic_environment$wlv_solve_leontief(
      coefficients,
      c(1, 1),
      method = "unproductive",
      year = "2000"
    ),
    "not certified as productive",
    fixed = TRUE
  )
})

test_that("solution diagnostics expose perturbations through residual errors", {
  system <- matrix(c(0.8, -0.1, -0.2, 0.9), nrow = 2L, byrow = TRUE)
  rhs <- c(1, 2)
  exact <- base::solve(system, rhs)
  perturbed <- exact + c(1e-4, -2e-4)
  exact_diagnostics <-
    leontief_diagnostic_environment$wlv_leontief_diagnose_solution(
      system,
      exact,
      rhs
    )
  perturbed_diagnostics <-
    leontief_diagnostic_environment$wlv_leontief_diagnose_solution(
      system,
      perturbed,
      rhs
    )

  expect_gt(
    perturbed_diagnostics$absolute_residual_max,
    exact_diagnostics$absolute_residual_max
  )
  expect_gt(
    perturbed_diagnostics$eta_normwise,
    exact_diagnostics$eta_normwise
  )
  expect_gt(
    perturbed_diagnostics$berr_componentwise,
    exact_diagnostics$berr_componentwise
  )
  expect_gt(perturbed_diagnostics$sensitivity_estimate, 0)
})

test_that("signed coefficients require and record absolute convergence", {
  coefficients <- matrix(
    c(0.20, -0.10, 0.05, 0.10),
    nrow = 2L,
    byrow = TRUE
  )
  labour <- c(1, 2)
  result <- leontief_diagnostic_environment$wlv_solve_leontief(
    coefficients,
    labour,
    method = "signed",
    year = "2006"
  )

  expect_equal(
    result$lambda,
    base::solve(t(diag(2L) - coefficients), labour),
    tolerance = 1e-14,
    ignore_attr = TRUE
  )
  expect_identical(
    result$diagnostics$certificate_type,
    "absolute_convergence_signed"
  )
  expect_identical(result$diagnostics$coefficient_negative_count, 1L)
  expect_gt(result$diagnostics$certificate_margin, 0)
  expect_lt(result$diagnostics$certificate_ratio_upper, 1)

  divergent_absolute_system <- matrix(
    c(0.2, -0.9, 0.9, 0.2),
    nrow = 2L,
    byrow = TRUE
  )
  expect_error(
    leontief_diagnostic_environment$wlv_solve_leontief(
      divergent_absolute_system,
      labour,
      method = "signed",
      year = "2007"
    ),
    "not certified as absolutely convergent",
    fixed = TRUE
  )
})

test_that("Leontief diagnostics accumulate deterministically beside GFCF", {
  solve_year <- function(year) {
    leontief_diagnostic_environment$wlv_solve_leontief(
      diag(c(0.2, 0.3)),
      c(1, 2),
      method = "method-a",
      year = year
    )$diagnostics
  }
  sentinel <- data.frame(value = "preserved", stringsAsFactors = FALSE)
  artifacts <- list(`_gfcf_negative_cells.csv` = sentinel)
  artifacts <-
    leontief_diagnostic_environment$wlv_append_leontief_diagnostics(
      artifacts,
      solve_year("2001")
    )
  artifacts <-
    leontief_diagnostic_environment$wlv_append_leontief_diagnostics(
      artifacts,
      solve_year("2000")
    )

  expect_identical(artifacts[["_gfcf_negative_cells.csv"]], sentinel)
  expect_identical(
    artifacts[["_leontief_diagnostics.csv"]]$year,
    c("2000", "2001")
  )
  expect_no_error(
    leontief_diagnostic_environment$wlv_validate_leontief_diagnostic_artifact(
      artifacts[["_leontief_diagnostics.csv"]],
      method = "method-a",
      expected_years = c("2001", "2000")
    )
  )
  expect_error(
    leontief_diagnostic_environment$wlv_append_leontief_diagnostics(
      artifacts,
      solve_year("2000")
    ),
    "duplicate method-years",
    fixed = TRUE
  )
  invalid_backward_error <- artifacts[["_leontief_diagnostics.csv"]]
  invalid_backward_error$berr_componentwise[[1L]] <-
    2 * invalid_backward_error$max_backward_error[[1L]]
  expect_error(
    leontief_diagnostic_environment$wlv_validate_leontief_diagnostic_artifact(
      invalid_backward_error
    ),
    "numerical contract",
    fixed = TRUE
  )

  result_dir <- tempfile("wlv-leontief-diagnostics-")
  dir.create(result_dir)
  on.exit(unlink(result_dir, recursive = TRUE, force = TRUE), add = TRUE)
  utils::write.csv2(
    artifacts[["_leontief_diagnostics.csv"]],
    file.path(result_dir, "_leontief_diagnostics.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  loaded <-
    leontief_diagnostic_environment$wlv_load_leontief_diagnostic_artifact(
      result_dir,
      method = "method-a",
      expected_years = c("2000", "2001")
    )
  expect_identical(loaded$year, c("2000", "2001"))
})

test_that("published diagnostics cannot relax the canonical numerical policy", {
  diagnostics <- leontief_diagnostic_environment$wlv_solve_leontief(
    diag(c(0.2, 0.3)),
    c(1, 2),
    method = "method-a",
    year = "2000"
  )$diagnostics
  policy_fields <- c(
    "machine_epsilon", "gamma_n", "forward_error_budget", "rcond_min",
    "max_backward_error", "refinement_trigger"
  )
  for (field in policy_fields) {
    tampered <- diagnostics
    tampered[[field]] <- 2 * tampered[[field]]
    expect_error(
      leontief_diagnostic_environment$
        wlv_validate_leontief_diagnostic_artifact(tampered),
      field,
      fixed = TRUE,
      info = sprintf("canonical policy field `%s`", field)
    )
  }

  excessive_refinement <- diagnostics
  canonical_policy <- leontief_diagnostic_environment$wlv_leontief_policy(
    diagnostics$productive_dimension
  )
  excessive_refinement$refinement_count <-
    canonical_policy$max_refinements + 1L
  expect_error(
    leontief_diagnostic_environment$
      wlv_validate_leontief_diagnostic_artifact(excessive_refinement),
    "refinement_count exceeds max_refinements",
    fixed = TRUE
  )

  relaxed_sidecar <- diagnostics
  relaxed_sidecar$forward_error_budget <- 1
  relaxed_sidecar$rcond_min <- .Machine$double.eps
  relaxed_sidecar$max_backward_error <- 1
  relaxed_sidecar$refinement_trigger <- 1
  result_dir <- tempfile("wlv-relaxed-leontief-policy-")
  dir.create(result_dir)
  on.exit(unlink(result_dir, recursive = TRUE, force = TRUE), add = TRUE)
  utils::write.csv2(
    relaxed_sidecar,
    file.path(result_dir, "_leontief_diagnostics.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  expect_error(
    leontief_diagnostic_environment$wlv_load_leontief_diagnostic_artifact(
      result_dir,
      method = "method-a",
      expected_years = "2000"
    ),
    "canonical numerical policy",
    fixed = TRUE
  )
})

test_that("the transformation script contains two annual productive-block passes", {
  script <- readLines(
    file.path(wlv_test_root, "R", "modules", "matrices", "transformation.R"),
    warn = FALSE,
    encoding = "UTF-8"
  )
  source_text <- paste(script, collapse = "\n")

  expect_length(
    grep("for (year_index in seq_len(a))", script, fixed = TRUE),
    2L
  )
  expect_match(source_text, "productive_indices", fixed = TRUE)
  expect_false(grepl("newDim(c(a, d, d))", source_text, fixed = TRUE))
  expect_false(grepl("rep(times = d)", source_text, fixed = TRUE))
  expect_false(grepl("myApply(1, solve)", source_text, fixed = TRUE))
})
