test_that("complete IO periods reuse the assembled artifact", {
  runtime <- wlv_test_load_runtime()
  years <- c("2000", "2001", "2002")
  value <- array(
    as.double(seq_len(3L * 2L * 2L * 2L)),
    dim = c(3L, 2L, 2L, 2L),
    dimnames = list(
      year = years,
      variable = c("a", "b"),
      input = c("i1", "i2"),
      output = c("o1", "o2")
    )
  )

  skip_if_not(capabilities("profmem"))
  original_address <- tracemem(value)
  on.exit(untracemem(value), add = TRUE)
  complete <- runtime$wlv_native_select_io_years(value, years)
  expect_identical(tracemem(complete), original_address)

  subset <- runtime$wlv_native_select_io_years(value, years[c(1L, 3L)])
  expect_false(identical(tracemem(subset), original_address))
  expect_identical(
    subset,
    value[years[c(1L, 3L)], , , , drop = FALSE]
  )
})

test_that("persisted IO arrays can be written before snapshot capture", {
  runtime <- wlv_test_load_runtime()
  root <- tempfile("wlv-native-prewrite-io-")
  source_root <- file.path(root, "source")
  staging <- file.path(root, "staging")
  dir.create(source_root, recursive = TRUE)
  dir.create(staging, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)

  m_io <- array(
    as.double(seq_len(2L * 2L * 2L * 2L)),
    dim = c(2L, 2L, 2L, 2L),
    dimnames = list(
      year = c("2000", "2001"),
      variable = c("values", "prices"),
      input = c("A", "B"),
      output = c("A", "B")
    )
  )
  source_paths <- file.path(
    source_root,
    c("m_io.2000.fst", "m_io.2001.fst")
  )
  for (index in seq_along(source_paths)) {
    runtime$write_fst_array(
      m_io[index, , , , drop = FALSE],
      source_paths[[index]],
      drop_axis_names = TRUE
    )
  }

  expect_invisible(runtime$wlv_native_write_io_arrays(
    list(source_io = source_paths),
    m_io,
    staging
  ))
  for (index in seq_along(source_paths)) {
    expected <- m_io[index, , , , drop = FALSE]
    names(dimnames(expected)) <- NULL
    expect_identical(
      runtime$read_fst_array(file.path(staging, basename(source_paths[[index]]))),
      expected
    )
  }
})

test_that("snapshot fork releases persisted m_io without mutating its owner", {
  runtime <- wlv_test_load_runtime()
  value <- array(
    1,
    dim = c(1L, 1L, 1L, 1L),
    dimnames = list(
      year = "2000",
      variable = "values",
      input = "A",
      output = "A"
    )
  )
  target_key <- "artifact/m_io"
  axes <- names(dimnames(value))
  contract <- runtime$wlv_native_artifact_array_contract("m_io", axes)
  state <- runtime$wlv_semantic_state_encode(
    value,
    array("finite", dim = dim(value), dimnames = dimnames(value)),
    target_key,
    axes
  )
  owner <- runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource(target_key, value, contract),
    runtime$wlv_seed_resource(
      runtime$wlv_semantic_state_key(target_key),
      state,
      runtime$wlv_native_semantic_state_contract(contract)
    ),
    runtime$wlv_seed_resource(
      "configuration/parameters",
      data.frame(name = "kept", stringsAsFactors = FALSE),
      runtime$wlv_resource_contract(scope = "run", value_type = "data.frame")
    )
  ))
  owner_entries <- serialize(owner$entries, NULL, version = 3L)
  fork <- runtime$wlv_runtime_fork_store(owner)

  expect_identical(
    runtime$wlv_runtime_snapshot_capture_store_release(
      fork,
      target_key,
      NULL
    ),
    2L
  )
  expect_false(any(vapply(fork$entries, function(entry) {
    entry$key %in% c(target_key, runtime$wlv_semantic_state_key(target_key))
  }, logical(1L))))
  expect_true(any(vapply(fork$entries, function(entry) {
    identical(entry$key, "configuration/parameters")
  }, logical(1L))))
  expect_identical(
    serialize(owner$entries, NULL, version = 3L),
    owner_entries
  )
  expect_error(
    runtime$wlv_runtime_snapshot_capture_store_release(
      owner,
      target_key,
      NULL
    ),
    "mutable resource store"
  )
})

test_that("native result retention keeps only post-run deliverables", {
  runtime <- wlv_test_load_runtime()
  catalog <- data.frame(
    locator_id = paste0("locator-", seq_len(17L)),
    key = c(
      "configuration/parameters",
      "configuration/sectors",
      "metadata/indicators",
      "intermediate/lambda",
      "semantic_state/intermediate/lambda",
      "artifact/sea_sectors",
      "semantic_state/artifact/sea_sectors",
      "io/1995-2009",
      "semantic_state/io/1995-2009",
      "sea/sector/value",
      "sea/country/value",
      "semantic_state/sea/sector/value",
      "semantic_state/sea/country/value",
      "module/anomaly",
      "module/metadata",
      "module/diagnostic",
      "intermediate/dead"
    ),
    role = c(
      rep("value", 13L),
      "anomaly",
      "metadata",
      "diagnostic",
      "value"
    ),
    stringsAsFactors = FALSE
  )
  module_plan <- new.env(parent = emptyenv())
  module_plan$terminal_catalog <- catalog
  class(module_plan) <- "wlv_module_plan"
  lockEnvironment(module_plan, bindings = TRUE)

  retained <- runtime$wlv_native_result_locator_ids(module_plan)

  expect_identical(retained, catalog$locator_id[-17L])
  expect_false(catalog$locator_id[[17L]] %in% retained)
})
