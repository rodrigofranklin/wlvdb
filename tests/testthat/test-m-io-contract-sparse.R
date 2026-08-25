wlv_test_m_io_contract_value <- function() {
  dimensions <- c(2L, 5L, 2L, 4L)
  array(
    as.double(seq_len(prod(dimensions))),
    dim = dimensions,
    dimnames = list(
      year = c("2000", "2001"),
      variable = c(
        "values", "k_composition", "transfers_values",
        "k_depreciation", "consumption_basket"
      ),
      input = c("A", "B"),
      output = c("A", "B", "HFCE", "INV")
    )
  )
}

wlv_test_m_io_contract_runtime <- function(runtime) {
  policy <- runtime$wlv_strict_missingness_policy(
    source = "synthetic",
    policy_id = "synthetic_strict"
  )
  wlv_test_contract_runtime(
    runtime,
    method = "synthetic",
    source = "synthetic",
    policy = policy,
    years = c("2000", "2001")
  )
}

wlv_test_run_m_io_validator <- function(
    runtime,
    validator,
    value,
    register = NULL,
    checkpoint = "test_checkpoint") {
  contract_runtime <- wlv_test_m_io_contract_runtime(runtime)
  if (!is.null(register)) {
    register(contract_runtime)
  }
  observed <- tryCatch(
    list(
      value = runtime[[validator]](
        contract_runtime,
        value,
        checkpoint = checkpoint
      ),
      error = NULL
    ),
    error = function(error) list(value = NULL, error = error)
  )
  observed$runtime_anomalies <- contract_runtime$anomalies
  observed
}

wlv_expect_m_io_sparse_matches_detailed <- function(
    runtime,
    value,
    register = NULL,
    checkpoint = "test_checkpoint") {
  detailed <- wlv_test_run_m_io_validator(
    runtime,
    "wlv_validate_m_io_contract_detailed",
    value,
    register,
    checkpoint
  )
  sparse <- wlv_test_run_m_io_validator(
    runtime,
    "wlv_validate_m_io_contract_sparse",
    value,
    register,
    checkpoint
  )
  selected <- wlv_test_run_m_io_validator(
    runtime,
    "wlv_validate_m_io_contract",
    value,
    register,
    checkpoint
  )
  expect_identical(is.null(sparse$error), is.null(detailed$error))
  expect_identical(is.null(selected$error), is.null(detailed$error))
  if (is.null(detailed$error)) {
    expect_identical(sparse$value, detailed$value)
    expect_identical(selected$value, detailed$value)
  } else {
    expect_identical(class(sparse$error), class(detailed$error))
    expect_identical(conditionMessage(sparse$error), conditionMessage(detailed$error))
    expect_identical(sparse$error$anomalies, detailed$error$anomalies)
    expect_identical(class(selected$error), class(detailed$error))
    expect_identical(conditionMessage(selected$error), conditionMessage(detailed$error))
    expect_identical(selected$error$anomalies, detailed$error$anomalies)
  }
  expect_identical(sparse$runtime_anomalies, detailed$runtime_anomalies)
  expect_identical(selected$runtime_anomalies, detailed$runtime_anomalies)
  invisible(list(detailed = detailed, sparse = sparse, selected = selected))
}

test_that("chunked m_io scan preserves exact non-finite positions", {
  runtime <- wlv_test_load_runtime()
  value <- as.double(seq_len(10L))
  value[c(1L, 3L, 4L, 10L)] <- c(NA_real_, NaN, Inf, -Inf)
  probe <- new.env(parent = environment(runtime$wlv_m_io_nonfinite_positions))
  probe$maximum <- 0L
  probe$is.finite <- function(current) {
    probe$maximum <- max(probe$maximum, length(current))
    base::is.finite(current)
  }
  scan <- runtime$wlv_m_io_nonfinite_positions
  environment(scan) <- probe
  expect_identical(scan(value, chunk_values = 3L), c(1L, 3L, 4L, 10L))
  expect_lte(probe$maximum, 3L)
  expect_identical(scan(as.double(seq_len(10L)), chunk_values = 3L), integer())
})

test_that("sparse m_io validation matches detailed successful classifications", {
  runtime <- wlv_test_load_runtime()
  finite <- wlv_test_m_io_contract_value()
  expect_true(runtime$wlv_can_validate_m_io_contract_sparse(finite))
  expect_no_error(wlv_expect_m_io_sparse_matches_detailed(runtime, finite))

  allowed <- finite
  allowed[, "k_composition", , c("HFCE", "INV")] <- NA_real_
  allowed[, "k_depreciation", , c("HFCE", "INV")] <- NA_real_
  allowed[, "consumption_basket", , c("HFCE", "INV")] <- NA_real_
  expect_true(runtime$wlv_can_validate_m_io_contract_sparse(allowed))
  expect_no_error(wlv_expect_m_io_sparse_matches_detailed(runtime, allowed))
})

test_that("sparse m_io validation preserves context validation", {
  runtime <- wlv_test_load_runtime()
  value <- wlv_test_m_io_contract_value()

  invalid_checkpoint <- wlv_expect_m_io_sparse_matches_detailed(
    runtime,
    value,
    checkpoint = NA_character_
  )
  expect_s3_class(invalid_checkpoint$detailed$error, "error")

  invalid_policy <- wlv_expect_m_io_sparse_matches_detailed(
    runtime,
    value,
    register = function(contract_runtime) {
      contract_runtime$policy$policy_id <- NULL
    }
  )
  expect_s3_class(invalid_policy$detailed$error, "error")
})

test_that("native m_io success stays on the sparse path", {
  runtime <- wlv_test_load_runtime()
  contract_runtime <- wlv_test_m_io_contract_runtime(runtime)
  value <- wlv_test_m_io_contract_value()
  allowed <- value
  allowed[, "k_composition", , c("HFCE", "INV")] <- NA_real_
  runtime$wlv_contract_register_states(
    contract_runtime,
    "m_io",
    "value_added_disaggregation_ratio",
    array("finite", dim = 1L, dimnames = list("intermediate"))
  )

  probe <- new.env(parent = environment(
    runtime$wlv_validate_m_io_contract_sparse
  ))
  probe$wlv_validate_m_io_contract_detailed <- function(...) {
    stop("detailed m_io validation invoked", call. = FALSE)
  }
  sparse <- runtime$wlv_validate_m_io_contract_sparse
  environment(sparse) <- probe

  expect_identical(sparse(contract_runtime, value), value)
  expect_identical(sparse(contract_runtime, allowed), allowed)
  invalid <- value
  invalid[1L] <- NA_real_
  expect_error(
    sparse(contract_runtime, invalid),
    "detailed m_io validation invoked",
    fixed = TRUE
  )

  dispatch <- new.env(parent = environment(runtime$wlv_validate_m_io_contract))
  dispatch$called <- FALSE
  dispatch$wlv_validate_m_io_contract_sparse <- function(
      runtime,
      value,
      checkpoint) {
    dispatch$called <- TRUE
    invisible(value)
  }
  selected <- runtime$wlv_validate_m_io_contract
  environment(selected) <- dispatch
  expect_identical(selected(contract_runtime, value), value)
  expect_true(dispatch$called)
})

test_that("hydrated m_io states remain sparse across public and subset shapes", {
  runtime <- wlv_test_load_runtime()
  contract_runtime <- wlv_test_m_io_contract_runtime(runtime)
  value <- wlv_test_m_io_contract_value()
  value["2000", "values", "A", "A"] <- NA_real_
  states <- array("finite", dim = dim(value), dimnames = dimnames(value))
  states["2000", "values", "A", "A"] <- "source_missing"
  target_key <- "artifact/m_io"
  axes <- names(dimnames(value))
  state <- runtime$wlv_semantic_state_encode(
    value,
    states,
    target_key,
    axes
  )
  target_contract <- runtime$wlv_native_artifact_array_contract("m_io", axes)
  store <- runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource(target_key, value, target_contract),
    runtime$wlv_seed_resource(
      runtime$wlv_semantic_state_key(target_key),
      state,
      runtime$wlv_native_semantic_state_contract(target_contract)
    )
  ))
  run_result <- new.env(parent = emptyenv())
  run_result$store <- store
  run_result$trace <- data.frame(
    node_id = character(),
    instance_id = character(),
    module_id = character(),
    partition = character(),
    stringsAsFactors = FALSE
  )
  class(run_result) <- "wlv_run_result"

  expect_invisible(runtime$wlv_native_hydrate_validation_runtime(
    contract_runtime,
    run_result
  ))
  expect_false(runtime$wlv_contract_has_registered_m_io_states(
    contract_runtime,
    dimnames(value)[[2L]]
  ))
  expect_identical(ls(contract_runtime$states, all.names = TRUE), character())
  expect_s3_class(
    contract_runtime$semantic_states[[target_key]],
    "wlv_semantic_state"
  )
  expect_identical(nrow(contract_runtime$semantic_states[[target_key]]), 1L)

  probe <- new.env(parent = environment(
    runtime$wlv_validate_m_io_contract_sparse
  ))
  probe$wlv_validate_m_io_contract_detailed <- function(...) {
    stop("detailed m_io validation invoked", call. = FALSE)
  }
  sparse <- runtime$wlv_validate_m_io_contract_sparse
  environment(sparse) <- probe

  expect_identical(sparse(contract_runtime, value), value)
  public <- value
  names(dimnames(public)) <- NULL
  expect_identical(sparse(contract_runtime, public), public)
  first_year <- value["2000", , , , drop = FALSE]
  second_year <- value["2001", , , , drop = FALSE]
  expect_identical(sparse(contract_runtime, first_year), first_year)
  expect_identical(sparse(contract_runtime, second_year), second_year)

  evaluate_failure <- function(validator, candidate) {
    current_runtime <- wlv_test_m_io_contract_runtime(runtime)
    runtime$wlv_contract_register_semantic_states(
      current_runtime,
      "m_io",
      state,
      value
    )
    error <- tryCatch(
      {
        runtime[[validator]](current_runtime, candidate)
        NULL
      },
      error = identity
    )
    list(error = error, anomalies = current_runtime$anomalies)
  }
  compare_failure <- function(candidate) {
    detailed <- evaluate_failure("wlv_validate_m_io_contract_detailed", candidate)
    sparse_failure <- evaluate_failure("wlv_validate_m_io_contract_sparse", candidate)
    expect_s3_class(detailed$error, "wlv_contract_error")
    expect_identical(class(sparse_failure$error), class(detailed$error))
    expect_identical(
      conditionMessage(sparse_failure$error),
      conditionMessage(detailed$error)
    )
    expect_identical(sparse_failure$error$anomalies, detailed$error$anomalies)
    expect_identical(sparse_failure$anomalies, detailed$anomalies)
  }
  unexpected <- value
  unexpected["2001", "values", "B", "B"] <- NA_real_
  compare_failure(unexpected)
  nonfinite <- value
  nonfinite["2001", "transfers_values", "B", "B"] <- NaN
  compare_failure(nonfinite)
})

test_that("sparse m_io validation reproduces detailed anomaly order and details", {
  runtime <- wlv_test_load_runtime()

  mixed <- wlv_test_m_io_contract_value()
  mixed["2000", "values", "A", "A"] <- NA_real_
  mixed["2001", "values", "B", "A"] <- Inf
  mixed["2000", "values", "B", "B"] <- -Inf
  comparison <- wlv_expect_m_io_sparse_matches_detailed(runtime, mixed)
  expect_identical(
    comparison$sparse$error$anomalies$action,
    c(
      "abort_non_finite", "abort_non_finite",
      "abort_unexpected_missing"
    )
  )

  allowed_nonfinite <- wlv_test_m_io_contract_value()
  allowed_nonfinite["2000", "k_composition", "A", "HFCE"] <- NaN
  allowed_nonfinite["2001", "k_composition", "A", "HFCE"] <- Inf
  allowed_nonfinite["2000", "k_composition", "B", "INV"] <- -Inf
  allowed_nonfinite["2001", "k_composition", "B", "INV"] <- NA_real_
  comparison <- wlv_expect_m_io_sparse_matches_detailed(
    runtime,
    allowed_nonfinite
  )
  expect_true(all(
    comparison$sparse$error$anomalies$action == "abort_non_finite"
  ))

  first_indicator <- wlv_test_m_io_contract_value()
  first_indicator["2001", "values", "B", "INV"] <- NA_real_
  first_indicator["2000", "k_composition", "A", "A"] <- NaN
  comparison <- wlv_expect_m_io_sparse_matches_detailed(runtime, first_indicator)
  expect_identical(
    unique(comparison$sparse$error$anomalies$indicator),
    "values"
  )
})

test_that("registered m_io states use exact detailed validation", {
  runtime <- wlv_test_load_runtime()
  value <- wlv_test_m_io_contract_value()
  register <- function(contract_runtime) {
    states <- array(
      "finite",
      dim = 1L,
      dimnames = list("malformed")
    )
    runtime$wlv_contract_register_states(
      contract_runtime,
      "m_io",
      "values",
      states
    )
  }

  comparison <- wlv_expect_m_io_sparse_matches_detailed(
    runtime,
    value,
    register
  )
  expect_s3_class(comparison$detailed$error, "error")
  expect_match(
    conditionMessage(comparison$detailed$error),
    "Registered missingness state shape does not match",
    fixed = TRUE
  )

  registered_runtime <- wlv_test_m_io_contract_runtime(runtime)
  register(registered_runtime)
  expect_true(runtime$wlv_contract_has_registered_m_io_states(
    registered_runtime,
    dimnames(value)[[2L]]
  ))

  unrelated_runtime <- wlv_test_m_io_contract_runtime(runtime)
  runtime$wlv_contract_register_states(
    unrelated_runtime,
    "m_io",
    "value_added_disaggregation_ratio",
    array("finite", dim = 1L, dimnames = list("intermediate"))
  )
  expect_false(runtime$wlv_contract_has_registered_m_io_states(
    unrelated_runtime,
    dimnames(value)[[2L]]
  ))
})

test_that("sparse m_io validation delegates non-native shapes exactly", {
  runtime <- wlv_test_load_runtime()

  character_value <- array(
    as.character(wlv_test_m_io_contract_value()),
    dim = dim(wlv_test_m_io_contract_value()),
    dimnames = dimnames(wlv_test_m_io_contract_value())
  )
  expect_false(runtime$wlv_can_validate_m_io_contract_sparse(character_value))
  expect_no_error(wlv_expect_m_io_sparse_matches_detailed(
    runtime,
    character_value
  ))

  three_dimensional <- array(
    seq_len(8L),
    dim = c(2L, 2L, 2L),
    dimnames = list(
      year = c("2000", "2001"),
      variable = c("values", "k_composition"),
      input = c("A", "B")
    )
  )
  storage.mode(three_dimensional) <- "double"
  expect_false(runtime$wlv_can_validate_m_io_contract_sparse(three_dimensional))
  expect_no_error(wlv_expect_m_io_sparse_matches_detailed(
    runtime,
    three_dimensional
  ))

  no_labels <- wlv_test_m_io_contract_value()
  dimnames(no_labels) <- NULL
  expect_false(runtime$wlv_can_validate_m_io_contract_sparse(no_labels))
  expect_no_error(wlv_expect_m_io_sparse_matches_detailed(runtime, no_labels))

  partial_labels <- wlv_test_m_io_contract_value()
  partial_dimnames <- dimnames(partial_labels)
  partial_dimnames[4L] <- list(NULL)
  dimnames(partial_labels) <- partial_dimnames
  partial_labels[1L] <- NA_real_
  expect_false(runtime$wlv_can_validate_m_io_contract_sparse(partial_labels))
  expect_no_error(wlv_expect_m_io_sparse_matches_detailed(
    runtime,
    partial_labels
  ))

  duplicate_indicator <- wlv_test_m_io_contract_value()
  dimnames(duplicate_indicator)[[2L]][2L] <- "values"
  expect_false(runtime$wlv_can_validate_m_io_contract_sparse(
    duplicate_indicator
  ))
  expect_no_error(wlv_expect_m_io_sparse_matches_detailed(
    runtime,
    duplicate_indicator
  ))

  missing_indicator <- wlv_test_m_io_contract_value()
  dimnames(missing_indicator)[[2L]][2L] <- NA_character_
  expect_false(runtime$wlv_can_validate_m_io_contract_sparse(missing_indicator))
  expect_no_error(wlv_expect_m_io_sparse_matches_detailed(
    runtime,
    missing_indicator
  ))
})
