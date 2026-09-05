wlv_make_source_input_receipt_fixture <- function() {
  fixture <- wlv_make_native_publication_fixture(mutable = TRUE)
  runtime <- fixture$runtime
  source_path <- file.path(
    fixture$root,
    "source_data",
    "native_source",
    "input.csv"
  )
  wlv_native_test_write_text(source_path, "key;value\ninput;original\n")
  source_path <- normalizePath(source_path, winslash = "/", mustWork = TRUE)

  method <- data.frame(
    method = "native_test",
    source = "native_source",
    artifact_profile = "native_profile",
    unit_contract = "native_units_v1",
    stringsAsFactors = FALSE
  )
  plan <- structure(
    list(
      root = fixture$root,
      method_names = method$method,
      methods = method
    ),
    class = c("wlv_run_plan", "list")
  )
  manifest <- list(
    schema_version = "1",
    source = "native_source",
    source_generation_id = "generation-1"
  )
  provenance <- data.frame(
    source = "native_source",
    source_generation_id = "generation-1",
    contract_sha256 = strrep("1", 64L),
    manifest_sha256 = strrep("2", 64L),
    stringsAsFactors = FALSE
  )
  inventory <- runtime$wlv_publication_source_input_inventory(
    fixture$root,
    source_path
  )
  run_data <- list(
    source_manifest = manifest,
    source_provenance = provenance,
    source_provenance_inputs = source_path,
    source_provenance_input_inventory = inventory
  )

  counters <- new.env(parent = emptyenv())
  reset_counters <- function() {
    counters$content_sha <- 0L
    counters$full_verifier <- 0L
    counters$manifest_sha <- 0L
    counters$provenance <- 0L
    counters$fail_full <- FALSE
    invisible(NULL)
  }
  reset_counters()

  original_file_sha256 <- runtime$wlv_publication_file_sha256
  runtime$wlv_publication_file_sha256 <- function(...) {
    counters$content_sha <- counters$content_sha + 1L
    original_file_sha256(...)
  }
  runtime$wlv_validate_source_manifest <- function(value) invisible(value)
  runtime$wlv_validate_source_provenance <- function(value) invisible(value)
  runtime$wlv_source_manifest_sha256 <- function(value) {
    counters$manifest_sha <- counters$manifest_sha + 1L
    strrep("a", 64L)
  }
  runtime$wlv_resolve_source_artifacts <- function(...) {
    list(manifest = source_path, required = source_path)
  }
  runtime$wlv_method_source_input_paths <- function(...) source_path
  runtime$wlv_validate_method_source_manifest <- function(...) {
    counters$full_verifier <- counters$full_verifier + 1L
    if (isTRUE(counters$fail_full)) {
      stop("full source verifier detected drift", call. = FALSE)
    }
    list(manifest = manifest)
  }
  runtime$wlv_source_provenance <- function(...) {
    counters$provenance <- counters$provenance + 1L
    provenance
  }

  paths <- source_path
  stamps <- runtime$wlv_publication_input_path_stamps(paths)
  run_data$source_input_receipt <- runtime$wlv_source_input_receipt(
    plan,
    method,
    run_data,
    paths,
    stamps
  )
  reset_counters()

  list(
    fixture = fixture,
    runtime = runtime,
    plan = plan,
    method = method,
    run_data = run_data,
    source_path = source_path,
    counters = counters,
    reset_counters = reset_counters
  )
}

wlv_source_input_receipt_run_environment <- function(value) {
  run_environment <- new.env(parent = emptyenv())
  run_environment$wlv_run_manifest <- list(
    method = value$method$method[[1L]]
  )
  run_environment$wlv_source_manifest <- value$run_data$source_manifest
  run_environment$wlv_source_provenance <- value$run_data$source_provenance
  run_environment$wlv_source_provenance_inputs <-
    value$run_data$source_provenance_inputs
  run_environment$wlv_source_provenance_input_inventory <-
    value$run_data$source_provenance_input_inventory
  run_environment$wlv_source_input_receipt <-
    value$run_data$source_input_receipt
  run_environment
}

test_that("source input receipts are isolated and fully locked", {
  value <- wlv_make_source_input_receipt_fixture()
  on.exit(wlv_remove_native_fixture(value$fixture), add = TRUE)
  receipt <- value$run_data$source_input_receipt

  expect_true(is.environment(receipt))
  expect_identical(parent.env(receipt), emptyenv())
  expect_true(environmentIsLocked(receipt))
  fields <- ls(receipt, all.names = TRUE)
  expect_true(all(vapply(
    fields,
    bindingIsLocked,
    logical(1L),
    env = receipt
  )))
  expect_false(any(vapply(
    fields,
    bindingIsActive,
    logical(1L),
    env = receipt
  )))
  expect_error(
    assign("method", "changed", envir = receipt),
    "locked binding",
    ignore.case = TRUE
  )
})

test_that("the source receipt fast path avoids content SHA and full validation", {
  value <- wlv_make_source_input_receipt_fixture()
  on.exit(wlv_remove_native_fixture(value$fixture), add = TRUE)

  expect_invisible(value$runtime$wlv_assert_method_source_inputs_unchanged(
    value$plan,
    value$method,
    value$run_data,
    use_receipt = TRUE
  ))
  expect_identical(value$counters$content_sha, 0L)
  expect_identical(value$counters$full_verifier, 0L)
  expect_identical(value$counters$provenance, 0L)
  # This is an in-memory identity hash, not a source-file content hash.
  expect_identical(value$counters$manifest_sha, 1L)
})

test_that("source receipt drift and invalid receipts fall back safely", {
  drift <- wlv_make_source_input_receipt_fixture()
  on.exit(wlv_remove_native_fixture(drift$fixture), add = TRUE)
  wlv_native_test_write_text(
    drift$source_path,
    "key;value\ninput;changed source payload\n"
  )
  drift$counters$fail_full <- TRUE
  expect_error(
    drift$runtime$wlv_assert_method_source_inputs_unchanged(
      drift$plan,
      drift$method,
      drift$run_data,
      use_receipt = TRUE
    ),
    "full source verifier detected drift",
    fixed = TRUE
  )
  expect_identical(drift$counters$full_verifier, 1L)

  invalid <- wlv_make_source_input_receipt_fixture()
  on.exit(wlv_remove_native_fixture(invalid$fixture), add = TRUE)
  invalid_receipt <- new.env(parent = emptyenv())
  lockEnvironment(invalid_receipt, bindings = TRUE)
  invalid$run_data$source_input_receipt <- invalid_receipt
  expect_invisible(invalid$runtime$wlv_assert_method_source_inputs_unchanged(
    invalid$plan,
    invalid$method,
    invalid$run_data,
    use_receipt = TRUE
  ))
  expect_identical(invalid$counters$full_verifier, 1L)
  expect_identical(invalid$counters$content_sha, 1L)
})

test_that("fast receipt checks validate every run before strong deduplication", {
  value <- wlv_make_source_input_receipt_fixture()
  on.exit(wlv_remove_native_fixture(value$fixture), add = TRUE)
  first <- wlv_source_input_receipt_run_environment(value)
  second <- wlv_source_input_receipt_run_environment(value)
  invalid_receipt <- new.env(parent = emptyenv())
  lockEnvironment(invalid_receipt, bindings = TRUE)
  second$wlv_source_input_receipt <- invalid_receipt
  value$counters$fail_full <- TRUE

  expect_error(
    value$runtime$wlv_assert_run_environments_source_inputs_unchanged(
      value$plan,
      list(first, second),
      use_receipt = TRUE
    ),
    "full source verifier detected drift",
    fixed = TRUE
  )
  expect_identical(value$counters$full_verifier, 1L)
  expect_identical(value$counters$content_sha, 0L)
})

test_that("strong source checks remain the default and the final boundary", {
  value <- wlv_make_source_input_receipt_fixture()
  on.exit(wlv_remove_native_fixture(value$fixture), add = TRUE)
  run_environment <- wlv_source_input_receipt_run_environment(value)

  expect_identical(
    formals(value$runtime$wlv_assert_method_source_inputs_unchanged)$use_receipt,
    FALSE
  )
  expect_identical(
    formals(
      value$runtime$wlv_assert_run_environments_source_inputs_unchanged
    )$use_receipt,
    FALSE
  )
  expect_invisible(
    value$runtime$wlv_assert_run_environments_source_inputs_unchanged(
      value$plan,
      list(run_environment)
    )
  )
  expect_identical(value$counters$full_verifier, 1L)
  expect_identical(value$counters$content_sha, 1L)

  value$reset_counters()
  expect_invisible(
    value$runtime$wlv_assert_run_environments_source_inputs_unchanged(
      value$plan,
      list(run_environment),
      use_receipt = TRUE
    )
  )
  expect_identical(value$counters$full_verifier, 0L)
  expect_identical(value$counters$content_sha, 0L)

  statements <- as.list(body(value$runtime$wlv_commit_release))[-1L]
  statement_names <- vapply(statements, function(statement) {
    if (is.call(statement)) as.character(statement[[1L]])[[1L]] else ""
  }, character(1L))
  source_checks <- which(
    statement_names ==
      "wlv_assert_run_environments_source_inputs_unchanged"
  )
  final_check <- tail(source_checks, 1L)
  final_call <- statements[[final_check]]
  expect_identical(as.character(final_call[[2L]]), "plan")
  expect_identical(as.character(final_call[[3L]]), "run_environments")
  expect_false("use_receipt" %in% names(as.list(final_call)))
  expect_identical(statement_names[[final_check - 1L]],
    "wlv_assert_plan_publication_inputs_unchanged"
  )
  expect_identical(statement_names[[final_check + 1L]],
    "wlv_verify_channel_marker"
  )
})
