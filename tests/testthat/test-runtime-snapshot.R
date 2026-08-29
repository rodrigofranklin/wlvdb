runtime_snapshot_environment <- wlv_test_load_runtime()

test_that("bound FST slices preserve multidimensional column-major order", {
  skip_if_not_installed("fst")
  runtime <- runtime_snapshot_environment
  root <- tempfile("wlv-runtime-slices-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(root, "slices.fst")
  value <- array(
    as.double(seq_len(2L * 3L * 2L * 2L)),
    dim = c(2L, 3L, 2L, 2L),
    dimnames = list(
      year = c("2000", "2001"),
      variable = c("first", "second", "third"),
      input = c("A", "B"),
      output = c("X", "Y")
    )
  )
  runtime$write_fst_array(value, path, drop_axis_names = TRUE)
  slices <- runtime$wlv_runtime_snapshot_read_bound_slices(
    root,
    basename(path),
    runtime$wlv_publication_file_sha256(path),
    runtime$wlv_publication_file_sha256(paste0(path, ".meta")),
    axes = c("year", "variable", "input", "output"),
    selectors = c("third", "first"),
    max_chunk_values = 7L
  )
  expect_identical(names(slices$values), c("third", "first"))
  for (selector in names(slices$values)) {
    expected <- array(
      value[, selector, , , drop = FALSE],
      dim = dim(value)[c(1L, 3L, 4L)],
      dimnames = dimnames(value)[c("year", "input", "output")]
    )
    expect_identical(slices$values[[selector]], expected)
    expect_identical(
      slices$value_sha256[[selector]],
      runtime$wlv_runtime_snapshot_value_sha256(expected)
    )
    expect_identical(
      runtime$wlv_runtime_snapshot_second_axis_slice_sha256(
        value,
        match(selector, dimnames(value)$variable),
        dimnames(value)[c("year", "input", "output")]
      ),
      runtime$wlv_runtime_snapshot_value_sha256(expected)
    )
  }
  expect_identical(
    slices$dimnames$variable,
    c("first", "second", "third")
  )
})

test_that("runtime snapshot array hashes preserve integer and double storage", {
  skip_if_not_installed("fst")
  runtime <- runtime_snapshot_environment
  root <- tempfile("wlv-runtime-storage-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  integer_value <- array(
    seq_len(2L * 2L * 2L * 2L),
    dim = c(2L, 2L, 2L, 2L),
    dimnames = list(
      year = c("2000", "2001"),
      variable = c("first", "second"),
      input = c("A", "B"),
      output = c("X", "Y")
    )
  )
  double_value <- integer_value
  storage.mode(double_value) <- "double"
  expect_false(identical(
    runtime$wlv_runtime_snapshot_value_sha256(integer_value),
    runtime$wlv_runtime_snapshot_value_sha256(double_value)
  ))
  expect_false(identical(
    runtime$wlv_runtime_snapshot_numeric_chunk_sha256(seq_len(16L)),
    runtime$wlv_runtime_snapshot_numeric_chunk_sha256(as.double(seq_len(16L)))
  ))

  path <- file.path(root, "integer-slices.fst")
  runtime$write_fst_array(integer_value, path, drop_axis_names = TRUE)
  slices <- runtime$wlv_runtime_snapshot_read_bound_slices(
    root,
    basename(path),
    runtime$wlv_publication_file_sha256(path),
    runtime$wlv_publication_file_sha256(paste0(path, ".meta")),
    axes = c("year", "variable", "input", "output"),
    selectors = "second",
    max_chunk_values = 5L
  )
  expected <- array(
    integer_value[, "second", , , drop = FALSE],
    dim = dim(integer_value)[c(1L, 3L, 4L)],
    dimnames = dimnames(integer_value)[c("year", "input", "output")]
  )
  expect_type(slices$values$second, "integer")
  expect_identical(
    slices$value_sha256[["second"]],
    runtime$wlv_runtime_snapshot_value_sha256(expected)
  )
  expect_identical(
    runtime$wlv_runtime_snapshot_second_axis_slice_sha256(
      integer_value,
      2L,
      dimnames(integer_value)[c("year", "input", "output")]
    ),
    runtime$wlv_runtime_snapshot_value_sha256(expected)
  )
})

test_that("runtime snapshot hashes semantic states independently of ALTREP", {
  runtime <- runtime_snapshot_environment
  years <- as.character(1995:2009)
  value <- array(
    NA_real_,
    dim = c(length(years), 1L, 1L),
    dimnames = list(year = years, sector = "S1", country = "AAA")
  )
  rows <- data.frame(
    year = years,
    sector = rep("S1", length(years)),
    country = rep("AAA", length(years)),
    state = rep("source_missing", length(years)),
    stringsAsFactors = FALSE
  )
  terminal <- runtime$wlv_semantic_new_state_resource(
    rows,
    "sea/sector/test",
    c("year", "sector", "country")
  )
  panel_state <- runtime$wlv_native_lift_semantic_states(
    list(terminal),
    "test",
    "indicator",
    "artifact/sea_sectors",
    c("year", "indicator", "sector", "country")
  )
  slice <- runtime$wlv_runtime_snapshot_panel_state_slice(
    panel_state,
    "sea_sectors",
    "test",
    value
  )

  expect_identical(slice, terminal)
  expect_identical(
    runtime$wlv_runtime_snapshot_value_sha256(slice),
    runtime$wlv_runtime_snapshot_value_sha256(terminal)
  )
  expect_identical(
    runtime$wlv_runtime_snapshot_binding_sha256(
      "panel-test",
      paste0(rep("a", 64L), collapse = ""),
      slice
    ),
    runtime$wlv_runtime_snapshot_binding_sha256(
      "panel-test",
      paste0(rep("a", 64L), collapse = ""),
      terminal
    )
  )

  materialized_years <- character(length(years))
  materialized_years[] <- years
  expect_identical(years, materialized_years)
  expect_identical(
    runtime$wlv_runtime_snapshot_value_sha256(years),
    runtime$wlv_runtime_snapshot_value_sha256(materialized_years)
  )
  ordinary_payload <- list(
    parameters = data.frame(
      name = "workers",
      value = "1",
      stringsAsFactors = FALSE
    ),
    policy = list(id = "strict")
  )
  expect_identical(
    runtime$wlv_runtime_snapshot_value_sha256(ordinary_payload),
    runtime$wlv_publication_sha256_raw(
      serialize(ordinary_payload, NULL, version = 3L)
    )
  )
  deferred_array <- array(
    as.double(seq_along(years)),
    dim = c(length(years), 1L),
    dimnames = list(year = years, input = "AAA.S1")
  )
  materialized_array <- array(
    as.double(seq_along(years)),
    dim = c(length(years), 1L),
    dimnames = list(year = materialized_years, input = "AAA.S1")
  )
  expect_identical(deferred_array, materialized_array)
  expect_identical(
    runtime$wlv_runtime_snapshot_value_sha256(deferred_array),
    runtime$wlv_runtime_snapshot_value_sha256(materialized_array)
  )
  expect_identical(
    runtime$wlv_runtime_snapshot_axes_sha256(
      deferred_array,
      c("year", "input")
    ),
    runtime$wlv_runtime_snapshot_axes_sha256(
      materialized_array,
      c("year", "input")
    )
  )

  deferred_numeric <- as.double(seq_len(1024L))
  materialized_numeric <- numeric(length(deferred_numeric))
  materialized_numeric[] <- deferred_numeric
  expect_identical(deferred_numeric, materialized_numeric)
  expect_identical(
    runtime$wlv_runtime_snapshot_numeric_chunk_sha256(deferred_numeric),
    runtime$wlv_runtime_snapshot_numeric_chunk_sha256(materialized_numeric)
  )

  filtered_empty <- runtime$wlv_semantic_new_state_resource(
    rows[FALSE, , drop = FALSE],
    "sea/sector/test",
    c("year", "sector", "country")
  )
  canonical_empty <- runtime$wlv_semantic_empty_state(
    "sea/sector/test",
    c("year", "sector", "country")
  )
  expect_identical(filtered_empty, canonical_empty)
  expect_identical(
    runtime$wlv_runtime_snapshot_value_sha256(filtered_empty),
    runtime$wlv_runtime_snapshot_value_sha256(canonical_empty)
  )
})

wlv_test_runtime_snapshot_fixture <- function() {
  runtime <- runtime_snapshot_environment
  partition <- "2000-2000"
  io_resources <- runtime$wlv_runtime_snapshot_io_resources()
  io_value <- array(
    c(1, NA_real_),
    dim = c(1L, 1L, 2L),
    dimnames = list(
      year = "2000",
      input = "AAA.S1",
      output = c("AAA.S1", "AAA.c41")
    )
  )
  io_states <- array(
    c("finite", "not_applicable"),
    dim = dim(io_value),
    dimnames = dimnames(io_value)
  )
  seeds <- list()
  for (resource in io_resources) {
    key <- paste0("io/", resource)
    contract <- runtime$wlv_native_io_contract(resource)
    state <- runtime$wlv_semantic_state_encode(
      io_value,
      io_states,
      key,
      contract$axes
    )
    seeds <- c(seeds, list(
      runtime$wlv_seed_resource(
        key,
        io_value,
        contract,
        partition = partition,
        producer = paste0("snapshot.", resource)
      ),
      runtime$wlv_seed_resource(
        runtime$wlv_semantic_state_key(key),
        state,
        runtime$wlv_native_semantic_state_contract(contract),
        partition = partition,
        producer = paste0("snapshot.", resource)
      )
    ))
  }
  lambda <- array(
    1,
    dim = c(1L, 1L),
    dimnames = list(year = "2000", input = "AAA.S1")
  )
  lambda_contract <- runtime$wlv_native_intermediate_contract(
    "lambda",
    c("year", "input"),
    "io_period"
  )
  lambda_state <- runtime$wlv_semantic_state_encode(
    lambda,
    array("finite", dim = dim(lambda), dimnames = dimnames(lambda)),
    "intermediate/lambda",
    lambda_contract$axes
  )
  seeds <- c(seeds, list(
    runtime$wlv_seed_resource(
      "intermediate/lambda",
      lambda,
      lambda_contract,
      partition = partition,
      producer = "snapshot.lambda"
    ),
    runtime$wlv_seed_resource(
      "semantic_state/intermediate/lambda",
      lambda_state,
      runtime$wlv_native_semantic_state_contract(lambda_contract),
      partition = partition,
      producer = "snapshot.lambda"
    )
  ))
  sea_sectors <- array(
    1,
    dim = c(1L, 1L, 1L, 1L),
    dimnames = list(
      year = "2000", indicator = "test", sector = "S1", country = "AAA"
    )
  )
  sea_countries <- array(
    c(NA_real_, 1),
    dim = c(1L, 1L, 2L),
    dimnames = list(
      year = "2000", indicator = "test", country = c("AAA", "WWW")
    )
  )
  panel_values <- list(
    sea_sectors = sea_sectors,
    sea_countries = sea_countries
  )
  panel_axes <- list(
    sea_sectors = c("year", "indicator", "sector", "country"),
    sea_countries = c("year", "indicator", "country")
  )
  for (name in names(panel_values)) {
    key <- paste0("artifact/", name)
    value <- panel_values[[name]]
    contract <- runtime$wlv_native_artifact_array_contract(
      name,
      panel_axes[[name]]
    )
    states <- array("finite", dim = dim(value), dimnames = dimnames(value))
    states[is.na(value)] <- "source_missing"
    state <- runtime$wlv_semantic_state_encode(
      value,
      states,
      key,
      panel_axes[[name]]
    )
    seeds <- c(seeds, list(
      runtime$wlv_seed_resource(
        key,
        value,
        contract,
        producer = "assembler.panel"
      ),
      runtime$wlv_seed_resource(
        runtime$wlv_semantic_state_key(key),
        state,
        runtime$wlv_native_semantic_state_contract(contract),
        producer = "assembler.panel"
      )
    ))
    indicator <- dimnames(value)$indicator[[1L]]
    level <- if (identical(name, "sea_sectors")) "sector" else "country"
    indicator_value <- if (identical(level, "sector")) {
      array(
        value[, indicator, , , drop = FALSE],
        dim = dim(value)[c(1L, 3L, 4L)],
        dimnames = dimnames(value)[c("year", "sector", "country")]
      )
    } else {
      array(
        value[, indicator, , drop = FALSE],
        dim = dim(value)[c(1L, 3L)],
        dimnames = dimnames(value)[c("year", "country")]
      )
    }
    indicator_key <- runtime$wlv_native_indicator_key(indicator, level)
    indicator_contract <- runtime$wlv_native_indicator_contract(
      indicator,
      level = level
    )
    indicator_states <- array(
      "finite",
      dim = dim(indicator_value),
      dimnames = dimnames(indicator_value)
    )
    indicator_states[is.na(indicator_value)] <- "source_missing"
    indicator_state <- runtime$wlv_semantic_state_encode(
      indicator_value,
      indicator_states,
      indicator_key,
      indicator_contract$axes
    )
    seeds <- c(seeds, list(
      runtime$wlv_seed_resource(
        indicator_key,
        indicator_value,
        indicator_contract,
        producer = paste0("snapshot.", level)
      ),
      runtime$wlv_seed_resource(
        runtime$wlv_semantic_state_key(indicator_key),
        indicator_state,
        runtime$wlv_native_semantic_state_contract(indicator_contract),
        producer = paste0("snapshot.", level)
      )
    ))
  }
  list(
    runtime = runtime,
    partition = partition,
    io_resources = io_resources,
    io_value = io_value,
    panel_values = panel_values,
    compatibility = wlv_test_runtime_compatibility(runtime),
    store = runtime$wlv_new_resource_store(seeds)
  )
}

test_that("runtime snapshot persists lambda and IO states without duplicating IO", {
  fixture <- wlv_test_runtime_snapshot_fixture()
  runtime <- fixture$runtime
  root <- tempfile("wlv-runtime-snapshot-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  io_path <- file.path(root, "m_io.synthetic.fst")
  m_io <- array(
    NA_real_,
    dim = c(1L, length(fixture$io_resources), 1L, 2L),
    dimnames = list(
      year = "2000",
      variable = fixture$io_resources,
      input = "AAA.S1",
      output = c("AAA.S1", "AAA.c41")
    )
  )
  for (resource in fixture$io_resources) {
    m_io[, resource, , ] <- fixture$io_value
  }
  runtime$write_fst_array(m_io, io_path, drop_axis_names = TRUE)
  for (name in names(fixture$panel_values)) {
    runtime$write_fst_array(
      fixture$panel_values[[name]],
      file.path(root, paste0(name, ".fst")),
      drop_axis_names = TRUE
    )
  }
  snapshot <- runtime$wlv_runtime_snapshot_create(
    fixture$store,
    method = "synthetic",
    source = "wiodr13",
    partitions = fixture$partition,
    io_artifacts = stats::setNames(io_path, fixture$partition),
    panel_artifacts = stats::setNames(
      file.path(root, paste0(names(fixture$panel_values), ".fst")),
      names(fixture$panel_values)
    ),
    compatibility = fixture$compatibility
  )
  capture <- runtime$wlv_runtime_snapshot_capture(
    fixture$store,
    method = "synthetic",
    source = "wiodr13",
    partitions = fixture$partition,
    compatibility = fixture$compatibility
  )
  phased <- runtime$wlv_runtime_snapshot_finalize(
    capture,
    io_artifacts = stats::setNames(io_path, fixture$partition),
    panel_artifacts = stats::setNames(
      file.path(root, paste0(names(fixture$panel_values), ".fst")),
      names(fixture$panel_values)
    )
  )
  expect_identical(phased, snapshot)
  receipt <- runtime$wlv_runtime_snapshot_write(
    snapshot,
    root,
    return_receipt = TRUE
  )
  expect_s3_class(receipt, "wlv_runtime_snapshot_receipt")
  expect_s3_class(
    attr(
      receipt,
      runtime$wlv_runtime_snapshot_receipt_bindings_attribute(),
      exact = TRUE
    ),
    "wlv_runtime_snapshot_binding_expectations"
  )
  expect_match(receipt$snapshot_commitment_sha256, "^[0-9a-f]{64}$")
  expect_match(
    attr(
      receipt,
      runtime$wlv_runtime_snapshot_receipt_seal_attribute(),
      exact = TRUE
    ),
    "^[0-9a-f]{64}$"
  )
  unverified_receipt <- runtime$wlv_runtime_snapshot_write(
    snapshot,
    root,
    validate_snapshot = FALSE,
    authenticate_bound_files = FALSE,
    return_receipt = TRUE,
    defer_verification = TRUE
  )
  expect_null(attr(
    unverified_receipt,
    runtime$wlv_runtime_snapshot_receipt_bindings_attribute(),
    exact = TRUE
  ))
  expect_null(attr(
    unverified_receipt,
    runtime$wlv_runtime_snapshot_receipt_seal_attribute(),
    exact = TRUE
  ))
  deferred_receipt <- runtime$wlv_runtime_snapshot_verify_write(
    unverified_receipt,
    root,
    authenticate_bound_files = TRUE
  )
  expect_identical(deferred_receipt, receipt)
  logical_receipt <- runtime$wlv_runtime_snapshot_write(
    snapshot,
    root,
    validate_snapshot = FALSE,
    authenticate_bound_files = FALSE,
    return_receipt = TRUE,
    defer_verification = TRUE
  )
  altered_internal_snapshot <- snapshot
  altered_internal_snapshot$compatibility$configuration_sha256 <- paste0(
    rep("0", 64L),
    collapse = ""
  )
  altered_internal_snapshot$compatibility$sha256 <-
    runtime$wlv_runtime_compatibility_sha256(
      altered_internal_snapshot$compatibility[setdiff(
        names(altered_internal_snapshot$compatibility),
        "sha256"
      )]
    )
  lambda_id <- paste(
    "intermediate/lambda",
    fixture$partition,
    sep = "\034"
  )
  altered_internal_snapshot$resources[[lambda_id]]$producer <-
    "snapshot.lambda.altered"
  altered_internal_snapshot$resources[[lambda_id]]$state_producer <-
    "snapshot.lambda.altered"
  altered_internal_snapshot$state_bindings <-
    runtime$wlv_runtime_snapshot_state_bindings(altered_internal_snapshot)
  expect_silent(runtime$wlv_runtime_snapshot_validate(
    altered_internal_snapshot
  ))
  read_hook <- new.env(parent = emptyenv())
  read_hook$mutated <- FALSE
  write_environment <- new.env(
    parent = environment(runtime$wlv_runtime_snapshot_write)
  )
  write_environment$readRDS <- function(path) {
    observed <- base::readRDS(path)
    if (identical(
          basename(path),
          runtime$wlv_runtime_snapshot_filename()
        ) && !isTRUE(read_hook$mutated)) {
      read_hook$mutated <- TRUE
      base::saveRDS(
        altered_internal_snapshot,
        path,
        version = 3L,
        compress = FALSE
      )
    }
    observed
  }
  write_with_mutation <- runtime$wlv_runtime_snapshot_write
  environment(write_with_mutation) <- write_environment
  expect_error(
    write_with_mutation(
      snapshot,
      root,
      return_receipt = TRUE
    ),
    "changed during its write round trip"
  )
  runtime$wlv_runtime_snapshot_write(snapshot, root)
  snapshot_path <- file.path(root, runtime$wlv_runtime_snapshot_filename())
  saveRDS(
    altered_internal_snapshot,
    snapshot_path,
    version = 3L,
    compress = FALSE
  )
  logical_snapshot_row <- match(
    runtime$wlv_runtime_snapshot_filename(),
    logical_receipt$files$path
  )
  logical_receipt$files$sha256[[logical_snapshot_row]] <-
    runtime$wlv_publication_file_sha256(snapshot_path)
  expect_error(
    runtime$wlv_runtime_snapshot_verify_write(
      logical_receipt,
      root,
      authenticate_bound_files = FALSE
    ),
    "logical commitment"
  )
  runtime$wlv_runtime_snapshot_write(snapshot, root)
  artifacts <- runtime$wlv_capture_validated_run_artifacts(root)
  bindings <- runtime$wlv_runtime_snapshot_receipt_assert(
    receipt,
    method = "synthetic",
    source = "wiodr13",
    partitions = fixture$partition,
    artifacts = artifacts,
    staging = root
  )
  expect_s3_class(bindings, "wlv_runtime_snapshot_binding_expectations")
  expect_identical(
    bindings,
    attr(
      receipt,
      runtime$wlv_runtime_snapshot_receipt_bindings_attribute(),
      exact = TRUE
    )
  )
  io_bindings <- runtime$wlv_runtime_snapshot_io_binding_expectations(bindings)
  expect_s3_class(
    io_bindings,
    "wlv_runtime_snapshot_io_binding_expectations"
  )
  expect_false(any(c("panel_states", "panel_provenance") %in% names(io_bindings)))
  fallback_receipt <- receipt
  attr(
    fallback_receipt,
    runtime$wlv_runtime_snapshot_receipt_bindings_attribute()
  ) <- NULL
  attr(
    fallback_receipt,
    runtime$wlv_runtime_snapshot_receipt_seal_attribute()
  ) <- NULL
  expect_s3_class(
    runtime$wlv_runtime_snapshot_receipt_assert(
      fallback_receipt,
      method = "synthetic",
      source = "wiodr13",
      partitions = fixture$partition,
      artifacts = artifacts,
      staging = root
    ),
    "wlv_runtime_snapshot_binding_expectations"
  )
  tampered_receipt <- receipt
  tampered_expectations <- attr(
    tampered_receipt,
    runtime$wlv_runtime_snapshot_receipt_bindings_attribute(),
    exact = TRUE
  )
  tampered_expectations$io$value_sha256[[1L]] <- paste0(
    rep("0", 64L),
    collapse = ""
  )
  attr(
    tampered_receipt,
    runtime$wlv_runtime_snapshot_receipt_bindings_attribute()
  ) <- tampered_expectations
  expect_error(
    runtime$wlv_runtime_snapshot_receipt_assert(
      tampered_receipt,
      method = "synthetic",
      source = "wiodr13",
      partitions = fixture$partition,
      artifacts = artifacts,
      staging = root
    ),
    "seal authentication failed"
  )
  coordinated_receipt <- receipt
  coordinated_expectations <- attr(
    coordinated_receipt,
    runtime$wlv_runtime_snapshot_receipt_bindings_attribute(),
    exact = TRUE
  )
  forged_sha256 <- paste0(rep("0", 64L), collapse = "")
  forged_path <- "sea_sectors.fst"
  coordinated_receipt$files$sha256[
    coordinated_receipt$files$path == forged_path
  ] <- forged_sha256
  coordinated_expectations$panel_provenance$value_sha256[
    coordinated_expectations$panel_provenance$artifact == "sea_sectors"
  ] <- forged_sha256
  attr(
    coordinated_receipt,
    runtime$wlv_runtime_snapshot_receipt_bindings_attribute()
  ) <- coordinated_expectations
  coordinated_artifacts <- artifacts
  coordinated_artifact_index <- match(
    forged_path,
    vapply(coordinated_artifacts, `[[`, character(1L), "path")
  )
  coordinated_artifacts[[coordinated_artifact_index]]$sha256 <- forged_sha256
  expect_error(
    runtime$wlv_runtime_snapshot_receipt_assert(
      coordinated_receipt,
      method = "synthetic",
      source = "wiodr13",
      partitions = fixture$partition,
      artifacts = coordinated_artifacts,
      staging = root
    ),
    "seal authentication failed"
  )
  for (name in names(fixture$panel_values)) {
    expect_silent(runtime$wlv_runtime_snapshot_validate_materialized_panel(
      bindings,
      name,
      fixture$panel_values[[name]]
    ))
  }
  expect_silent(runtime$wlv_runtime_snapshot_validate_materialized_io(
    io_bindings,
    fixture$partition,
    m_io
  ))
  drifted_io <- m_io
  drifted_io[1L] <- drifted_io[1L] + 1
  expect_error(
    runtime$wlv_runtime_snapshot_validate_materialized_io(
      bindings,
      fixture$partition,
      drifted_io
    ),
    "IO generation differs"
  )
  drifted_panel <- fixture$panel_values$sea_sectors
  drifted_panel[1L] <- drifted_panel[1L] + 1
  expect_error(
    runtime$wlv_runtime_snapshot_validate_materialized_panel(
      bindings,
      "sea_sectors",
      drifted_panel
    ),
    "panel generation differs"
  )
  drifted_capture <- capture
  drifted_capture$panel_states$sea_countries$state[[1L]] <- "not_applicable"
  drifted_snapshot <- runtime$wlv_runtime_snapshot_finalize(
    drifted_capture,
    io_artifacts = stats::setNames(io_path, fixture$partition),
    panel_artifacts = stats::setNames(
      file.path(root, paste0(names(fixture$panel_values), ".fst")),
      names(fixture$panel_values)
    ),
    validate_snapshot = FALSE,
    validate_bound = FALSE
  )
  drifted_receipt <- runtime$wlv_runtime_snapshot_write(
    drifted_snapshot,
    root,
    validate_snapshot = FALSE,
    authenticate_bound_files = FALSE,
    return_receipt = TRUE,
    defer_verification = TRUE
  )
  drifted_receipt <- runtime$wlv_runtime_snapshot_verify_write(
    drifted_receipt,
    root,
    authenticate_bound_files = FALSE
  )
  drifted_artifacts <- runtime$wlv_capture_validated_run_artifacts(root)
  drifted_bindings <- runtime$wlv_runtime_snapshot_receipt_assert(
    drifted_receipt,
    method = "synthetic",
    source = "wiodr13",
    partitions = fixture$partition,
    artifacts = drifted_artifacts,
    staging = root
  )
  expect_error(
    runtime$wlv_runtime_snapshot_validate_materialized_panel(
      drifted_bindings,
      "sea_countries",
      fixture$panel_values$sea_countries
    ),
    "panel state generation differs"
  )
  runtime$wlv_runtime_snapshot_write(snapshot, root)
  artifacts <- runtime$wlv_capture_validated_run_artifacts(root)
  tampered_artifacts <- artifacts
  snapshot_index <- match(
    runtime$wlv_runtime_snapshot_filename(),
    vapply(tampered_artifacts, `[[`, character(1L), "path")
  )
  tampered_artifacts[[snapshot_index]]$sha256 <- paste0(rep("0", 64L), collapse = "")
  expect_error(
    runtime$wlv_runtime_snapshot_receipt_assert(
      receipt,
      method = "synthetic",
      source = "wiodr13",
      partitions = fixture$partition,
      artifacts = tampered_artifacts
    ),
    "does not authenticate"
  )
  snapshot_path <- file.path(root, runtime$wlv_runtime_snapshot_filename())
  altered_snapshot <- snapshot
  altered_snapshot$compatibility$configuration_sha256 <- paste0(
    rep("0", 64L),
    collapse = ""
  )
  saveRDS(altered_snapshot, snapshot_path, version = 3L, compress = FALSE)
  expect_error(
    runtime$wlv_runtime_snapshot_receipt_assert(
      receipt,
      method = "synthetic",
      source = "wiodr13",
      partitions = fixture$partition,
      artifacts = artifacts,
      staging = root
    ),
    "failed persisted envelope authentication"
  )
  runtime$wlv_runtime_snapshot_write(snapshot, root)
  expect_identical(
    runtime$wlv_publication_file_sha256(snapshot_path),
    receipt$files$sha256[[match(
      runtime$wlv_runtime_snapshot_filename(),
      receipt$files$path
    )]]
  )
  expect_error(
    runtime$wlv_runtime_snapshot_finalize(
      capture,
      io_artifacts = stats::setNames(io_path, fixture$partition),
      panel_artifacts = stats::setNames(
        file.path(root, paste0(names(fixture$panel_values), ".fst")),
        names(fixture$panel_values)
      ),
      validate_bound = c(FALSE, TRUE)
    ),
    "flags are invalid"
  )
  expect_error(
    runtime$wlv_runtime_snapshot_write(
      snapshot,
      root,
      authenticate_bound_files = TRUE,
      return_receipt = TRUE,
      defer_verification = TRUE
    ),
    "cannot authenticate bound files"
  )
  expect_error(
    runtime$wlv_runtime_snapshot_write(
      snapshot,
      root,
      validate_snapshot = c(FALSE, TRUE)
    ),
    "flags are invalid"
  )
  expect_identical(
    runtime$wlv_runtime_snapshot_read_envelope(
      root,
      expected_sha256 = runtime$wlv_publication_file_sha256(snapshot_path)
    ),
    snapshot
  )
  expect_error(
    runtime$wlv_runtime_snapshot_read_envelope(
      root,
      expected_sha256 = paste0(rep("0", 64L), collapse = "")
    ),
    "parent-manifest authentication"
  )
  observed <- runtime$wlv_runtime_snapshot_read(
    root,
    method = "synthetic",
    source = "wiodr13",
    partitions = fixture$partition
  )
  expect_identical(observed, snapshot)

  lambda <- runtime$wlv_runtime_snapshot_resource(
    observed,
    "intermediate/lambda",
    fixture$partition
  )
  expect_true(is.array(lambda$value))
  expect_s3_class(lambda$state, "wlv_semantic_state")
  io <- runtime$wlv_runtime_snapshot_resource(
    observed,
    "io/values",
    fixture$partition
  )
  expect_null(io$value)
  expect_s3_class(io$state, "wlv_semantic_state")
  expect_identical(
    observed$panel_provenance$producer,
    c("snapshot.sector", "snapshot.country")
  )
})

test_that("runtime snapshot states are bound to persisted artifact coordinates", {
  fixture <- wlv_test_runtime_snapshot_fixture()
  runtime <- fixture$runtime
  root <- tempfile("wlv-runtime-snapshot-binding-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  io_path <- file.path(root, "m_io.synthetic.fst")
  m_io <- array(
    NA_real_,
    dim = c(1L, length(fixture$io_resources), 1L, 2L),
    dimnames = list(
      year = "2000",
      variable = fixture$io_resources,
      input = "AAA.S1",
      output = c("AAA.S1", "AAA.c41")
    )
  )
  for (resource in fixture$io_resources) {
    m_io[, resource, , ] <- fixture$io_value
  }
  runtime$write_fst_array(m_io, io_path)
  for (name in names(fixture$panel_values)) {
    runtime$write_fst_array(
      fixture$panel_values[[name]],
      file.path(root, paste0(name, ".fst"))
    )
  }
  snapshot <- runtime$wlv_runtime_snapshot_create(
    fixture$store,
    method = "synthetic",
    source = "wiodr13",
    partitions = fixture$partition,
    io_artifacts = stats::setNames(io_path, fixture$partition),
    panel_artifacts = stats::setNames(
      file.path(root, paste0(names(fixture$panel_values), ".fst")),
      names(fixture$panel_values)
    ),
    compatibility = fixture$compatibility
  )

  shifted_panel <- snapshot
  shifted_panel$panel_states$sea_countries$country[[1L]] <- "WWW"
  expect_error(
    runtime$wlv_runtime_snapshot_validate(shifted_panel),
    "state bindings are invalid"
  )

  shifted_io <- snapshot
  io_id <- paste("io/values", fixture$partition, sep = "\034")
  shifted_io$resources[[io_id]]$state$output[[1L]] <- "AAA.S1"
  expect_error(
    runtime$wlv_runtime_snapshot_validate(shifted_io),
    "provenance is invalid"
  )

  shifted_producer <- snapshot
  shifted_producer$panel_provenance$producer[[1L]] <- "unexpected-producer"
  shifted_producer$panel_provenance$state_producer[[1L]] <-
    "unexpected-producer"
  expect_error(
    runtime$wlv_runtime_snapshot_validate(shifted_producer),
    "state bindings are invalid"
  )

  shifted_contract <- snapshot
  shifted_contract$panel_provenance$contract_sha256[[1L]] <- paste0(
    rep("0", 64L),
    collapse = ""
  )
  expect_error(
    runtime$wlv_runtime_snapshot_validate(shifted_contract),
    "panel contract provenance is invalid"
  )
})

test_that("runtime snapshot rejects incomplete coverage and provenance drift", {
  fixture <- wlv_test_runtime_snapshot_fixture()
  runtime <- fixture$runtime
  root <- tempfile("wlv-runtime-snapshot-invalid-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  io_path <- file.path(root, "m_io.synthetic.fst")
  m_io <- array(
    NA_real_,
    dim = c(1L, length(fixture$io_resources), 1L, 2L),
    dimnames = list(
      year = "2000",
      variable = fixture$io_resources,
      input = "AAA.S1",
      output = c("AAA.S1", "AAA.c41")
    )
  )
  for (resource in fixture$io_resources) {
    m_io[, resource, , ] <- fixture$io_value
  }
  runtime$write_fst_array(m_io, io_path)
  for (name in names(fixture$panel_values)) {
    runtime$write_fst_array(
      fixture$panel_values[[name]],
      file.path(root, paste0(name, ".fst"))
    )
  }
  snapshot <- runtime$wlv_runtime_snapshot_create(
    fixture$store,
    method = "synthetic",
    source = "wiodr13",
    partitions = fixture$partition,
    io_artifacts = stats::setNames(io_path, fixture$partition),
    panel_artifacts = stats::setNames(
      file.path(root, paste0(names(fixture$panel_values), ".fst")),
      names(fixture$panel_values)
    ),
    compatibility = fixture$compatibility
  )
  incomplete <- snapshot
  incomplete$resources <- incomplete$resources[-1L]
  expect_error(
    runtime$wlv_runtime_snapshot_validate(incomplete),
    "coverage is incomplete"
  )
  wrong_source <- snapshot
  expect_error(
    runtime$wlv_runtime_snapshot_validate(wrong_source, source = "wiodr16"),
    "source does not match"
  )
})

test_that("runtime snapshot authenticates FST metadata before consumption", {
  fixture <- wlv_test_runtime_snapshot_fixture()
  runtime <- fixture$runtime
  root <- tempfile("wlv-runtime-snapshot-meta-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  io_path <- file.path(root, "parent-period.fst")
  m_io <- array(
    NA_real_,
    dim = c(1L, length(fixture$io_resources), 1L, 2L),
    dimnames = list(
      year = "2000",
      variable = fixture$io_resources,
      input = "AAA.S1",
      output = c("AAA.S1", "AAA.c41")
    )
  )
  for (resource in fixture$io_resources) {
    m_io[, resource, , ] <- fixture$io_value
  }
  runtime$write_fst_array(m_io, io_path, drop_axis_names = TRUE)
  panel_paths <- stats::setNames(
    file.path(root, paste0("parent-", names(fixture$panel_values), ".fst")),
    names(fixture$panel_values)
  )
  for (name in names(panel_paths)) {
    runtime$write_fst_array(
      fixture$panel_values[[name]],
      panel_paths[[name]],
      drop_axis_names = TRUE
    )
  }
  snapshot <- runtime$wlv_runtime_snapshot_create(
    fixture$store,
    method = "synthetic",
    source = "wiodr13",
    partitions = fixture$partition,
    io_artifacts = stats::setNames(io_path, fixture$partition),
    panel_artifacts = panel_paths,
    compatibility = fixture$compatibility
  )
  runtime$wlv_runtime_snapshot_write(snapshot, root)

  metadata_path <- paste0(panel_paths[["sea_sectors"]], ".meta")
  metadata <- readRDS(metadata_path)
  metadata$array_dimnames[[1L]][[1L]] <- "1999"
  saveRDS(metadata, metadata_path, version = 3L)
  expect_error(
    runtime$wlv_runtime_snapshot_read(root),
    "failed provenance verification"
  )
})

test_that("runtime compatibility fails closed before parent imports", {
  skip_if_not_installed("jsonlite")
  runtime <- runtime_snapshot_environment
  current <- wlv_test_runtime_compatibility(runtime)
  descriptor <- runtime$wlv_runtime_compatibility_manifest(current)
  descriptor <- jsonlite::fromJSON(
    jsonlite::toJSON(descriptor, auto_unbox = TRUE, null = "null"),
    simplifyVector = FALSE
  )
  manifest <- list(result = list(provenance = list(
    runtime_compatibility = descriptor
  )))
  expect_silent(runtime$wlv_runtime_manifest_assert_compatible(
    manifest,
    current
  ))

  changed_unit <- wlv_test_runtime_compatibility(
    runtime,
    unit_contract_id = "synthetic_v2",
    unit_token = "unit-v2"
  )
  expect_error(
    runtime$wlv_runtime_manifest_assert_compatible(manifest, changed_unit),
    "differs from the current scientific contracts"
  )
  changed_policy <- wlv_test_runtime_compatibility(
    runtime,
    missingness_policy_id = "synthetic_missingness_v2",
    missingness_token = "missingness-v2"
  )
  expect_error(
    runtime$wlv_runtime_manifest_assert_compatible(manifest, changed_policy),
    "differs from the current scientific contracts"
  )
  same_policy_id_changed_body <- wlv_test_runtime_compatibility(
    runtime,
    missingness_token = "missingness-v1-drift"
  )
  expect_error(
    runtime$wlv_runtime_manifest_assert_compatible(
      manifest,
      same_policy_id_changed_body
    ),
    "differs from the current scientific contracts"
  )
  changed_runtime <- wlv_test_runtime_compatibility(
    runtime,
    runtime_generation_token = "runtime-generation-v2"
  )
  expect_error(
    runtime$wlv_runtime_manifest_assert_compatible(manifest, changed_runtime),
    "differs from the current scientific contracts"
  )
  changed_parameters <- wlv_test_runtime_compatibility(
    runtime,
    method_parameters_token = "method-parameters-v2"
  )
  expect_error(
    runtime$wlv_runtime_manifest_assert_compatible(
      manifest,
      changed_parameters
    ),
    "differs from the current scientific contracts"
  )
  changed_sectors <- wlv_test_runtime_compatibility(
    runtime,
    method_sectors_token = "method-sectors-productive-v2"
  )
  expect_error(
    runtime$wlv_runtime_manifest_assert_compatible(manifest, changed_sectors),
    "differs from the current scientific contracts"
  )
  missing <- manifest
  missing$result$provenance$runtime_compatibility <- NULL
  expect_error(
    runtime$wlv_runtime_manifest_assert_compatible(missing, current),
    "lacks authenticated runtime compatibility"
  )
})

test_that("runtime snapshot rejects a finite IO publication drift", {
  skip_if_not_installed("fst")
  fixture <- wlv_test_runtime_snapshot_fixture()
  runtime <- fixture$runtime
  root <- tempfile("wlv-runtime-io-drift-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  io_path <- file.path(root, "m_io.synthetic.fst")
  m_io <- array(
    NA_real_,
    dim = c(1L, length(fixture$io_resources), 1L, 2L),
    dimnames = list(
      year = "2000",
      variable = fixture$io_resources,
      input = "AAA.S1",
      output = c("AAA.S1", "AAA.c41")
    )
  )
  for (resource in fixture$io_resources) {
    m_io[, resource, , ] <- fixture$io_value
  }
  m_io["2000", "values", "AAA.S1", "AAA.S1"] <- 999
  runtime$write_fst_array(m_io, io_path)
  panel_paths <- stats::setNames(
    file.path(root, paste0(names(fixture$panel_values), ".fst")),
    names(fixture$panel_values)
  )
  for (name in names(panel_paths)) {
    runtime$write_fst_array(fixture$panel_values[[name]], panel_paths[[name]])
  }
  expect_error(
    runtime$wlv_runtime_snapshot_create(
      fixture$store,
      method = "synthetic",
      source = "wiodr13",
      partitions = fixture$partition,
      io_artifacts = stats::setNames(io_path, fixture$partition),
      panel_artifacts = panel_paths,
      compatibility = fixture$compatibility
    ),
    "IO generation differs"
  )
})
