native_semantic_seed_bootstrap <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "bootstrap.R"),
  envir = native_semantic_seed_bootstrap
)
native_semantic_seed_runtime <- native_semantic_seed_bootstrap$wlv_load_runtime(
  wlv_test_root
)

test_that("parent seed requests separate source origin from child locator", {
  runtime <- native_semantic_seed_runtime
  contract <- runtime$wlv_native_indicator_contract("go_price.r.id")
  value <- array(
    1,
    dim = c(1L, 1L, 1L),
    dimnames = list(year = "2000", sector = "S1", country = "ROW")
  )
  state <- runtime$wlv_semantic_capture_value_state(
    value,
    "sea/sector/go_price.r.id",
    contract$axes
  )$state
  terminal <- runtime$wlv_parent_seed_request(
    key = "sea/sector/go_price.r.id",
    source = runtime$wlv_parent_source_terminal(),
    child_producer = "indicator.go_price.r.id",
    contract = contract
  )
  resolution <- runtime$wlv_parent_seed_resolution(
    terminal,
    origin_producer = "normalize.indicator.go_price.r.id",
    origin_state_producer = "normalize.indicator.go_price.r.id",
    value = value,
    state = state,
    snapshot_sha256 = paste0(rep("a", 64L), collapse = "")
  )
  expect_identical(resolution$source_mode, "terminal")
  expect_identical(resolution$source_producer, "")
  expect_identical(resolution$child_producer, "indicator.go_price.r.id")
  expect_identical(
    resolution$origin_producer,
    "normalize.indicator.go_price.r.id"
  )
  expect_identical(
    resolution$state_sha256,
    runtime$wlv_runtime_snapshot_state_sha256(state)
  )
  expect_error(
    runtime$wlv_parent_seed_resolution(
      terminal,
      origin_producer = "normalize.indicator.go_price.r.id",
      origin_state_producer = "normalize.indicator.go_price.r.id",
      value = value,
      state = state,
      snapshot_sha256 = paste0(rep("a", 64L), collapse = ""),
      authenticated_state_sha256 = "bad"
    ),
    "invalid authenticated state hash"
  )

  exact <- runtime$wlv_parent_seed_request(
    key = "sea/sector/go_price.r.id",
    source = runtime$wlv_parent_source_exact("indicator.go_price.r.id"),
    child_producer = "indicator.go_price.r.id",
    contract = contract
  )
  expect_error(
    runtime$wlv_parent_seed_resolution(
      exact,
      origin_producer = "normalize.indicator.go_price.r.id",
      origin_state_producer = "normalize.indicator.go_price.r.id",
      value = value,
      state = state,
      snapshot_sha256 = paste0(rep("a", 64L), collapse = "")
    ),
    "exact generation `indicator.go_price.r.id` is not retained"
  )
  expect_error(
    runtime$wlv_parent_seed_request(
      key = "sea/sector/go_price.r.id",
      child_producer = "indicator.go_price.r.id",
      contract = contract
    ),
    "must declare its source selector"
  )
})

wlv_test_write_parent_states <- function(runtime, path, records) {
  records <- records[runtime$wlv_contract_state_columns()]
  utils::write.table(
    records,
    file = path,
    sep = ";",
    dec = ",",
    row.names = FALSE,
    col.names = TRUE,
    quote = TRUE,
    na = "",
    fileEncoding = "UTF-8"
  )
}

wlv_test_runtime_snapshot_store <- function(
    runtime,
    parent_io,
    lambda,
    sea_sectors,
    sea_countries,
    sector_states,
    country_states,
    partition = "2000-2000") {
  seeds <- list()
  for (resource in runtime$wlv_runtime_snapshot_io_resources()) {
    key <- paste0("io/", resource)
    value <- parent_io[, resource, , , drop = FALSE]
    value <- array(
      value,
      dim = dim(parent_io)[c(1L, 3L, 4L)],
      dimnames = stats::setNames(
        dimnames(parent_io)[c(1L, 3L, 4L)],
        c("year", "input", "output")
      )
    )
    io_states <- runtime$wlv_semantic_state_array(
      value,
      c("year", "input", "output")
    )
    io_states[is.na(value) & !is.nan(value)] <- "not_applicable"
    seeds <- c(
      seeds,
      runtime$wlv_native_stateful_seed_pair(runtime$wlv_seed_resource(
        key,
        value,
        runtime$wlv_native_io_contract(resource),
        partition = partition,
        producer = paste0("parent.", resource)
      ), states = io_states)
    )
  }
  seeds <- c(
    seeds,
    runtime$wlv_native_stateful_seed_pair(runtime$wlv_seed_resource(
      "intermediate/lambda",
      lambda,
      runtime$wlv_native_intermediate_contract(
        "lambda",
        c("year", "input"),
        "io_period"
      ),
      partition = partition,
      producer = "parent.lambda"
    ), states = runtime$wlv_semantic_state_array(
      lambda,
      c("year", "input")
    )),
    runtime$wlv_native_stateful_seed_pair(runtime$wlv_seed_resource(
      "artifact/sea_sectors",
      sea_sectors,
      runtime$wlv_native_artifact_array_contract(
        "sea_sectors",
        c("year", "indicator", "sector", "country")
      ),
      producer = "assembler.panel"
    ), states = sector_states),
    runtime$wlv_native_stateful_seed_pair(runtime$wlv_seed_resource(
      "artifact/sea_countries",
      sea_countries,
      runtime$wlv_native_artifact_array_contract(
        "sea_countries",
        c("year", "indicator", "country")
      ),
      producer = "assembler.panel"
    ), states = country_states)
  )
  indicator <- dimnames(sea_sectors)$indicator[[1L]]
  sector_value <- array(
    sea_sectors[, indicator, , , drop = FALSE],
    dim = dim(sea_sectors)[c(1L, 3L, 4L)],
    dimnames = dimnames(sea_sectors)[c("year", "sector", "country")]
  )
  country_value <- array(
    sea_countries[, indicator, , drop = FALSE],
    dim = dim(sea_countries)[c(1L, 3L)],
    dimnames = dimnames(sea_countries)[c("year", "country")]
  )
  seeds <- c(
    seeds,
    runtime$wlv_native_stateful_seed_pair(runtime$wlv_seed_resource(
      runtime$wlv_native_indicator_key(indicator, "sector"),
      sector_value,
      runtime$wlv_native_indicator_contract(indicator, level = "sector"),
      producer = "parent.sector"
    ), states = array(
      sector_states[, indicator, , , drop = FALSE],
      dim = dim(sector_states)[c(1L, 3L, 4L)],
      dimnames = dimnames(sector_states)[c("year", "sector", "country")]
    )),
    runtime$wlv_native_stateful_seed_pair(runtime$wlv_seed_resource(
      runtime$wlv_native_indicator_key(indicator, "country"),
      country_value,
      runtime$wlv_native_indicator_contract(indicator, level = "country"),
      producer = "parent.country"
    ), states = array(
      country_states[, indicator, , drop = FALSE],
      dim = dim(country_states)[c(1L, 3L)],
      dimnames = dimnames(country_states)[c("year", "country")]
    ))
  )
  runtime$wlv_new_resource_store(seeds)
}

test_that("stateful seeds publish exact same-locator semantic resources", {
  runtime <- native_semantic_seed_runtime
  value <- array(
    c(1, NA_real_),
    dim = c(1L, 2L, 1L),
    dimnames = list(year = "2000", sector = c("S1", "S2"), country = "A")
  )
  states <- runtime$wlv_semantic_state_array(
    value,
    c("year", "sector", "country")
  )
  states[is.na(value)] <- "source_missing"
  pair <- runtime$wlv_native_stateful_seed_pair(
    runtime$wlv_seed_resource(
      "sea/sector/test",
      value,
      runtime$wlv_native_indicator_contract("test"),
      producer = "parent.test"
    ),
    states = states
  )

  expect_length(pair, 2L)
  expect_identical(vapply(pair, `[[`, character(1L), "producer"),
    rep("parent.test", 2L)
  )
  expect_identical(pair[[2L]]$key, "semantic_state/sea/sector/test")
  expect_identical(pair[[2L]]$contract$role, "semantic_state")
  expect_identical(
    runtime$wlv_semantic_state_expand(pair[[2L]]$value, pair[[1L]]$value),
    states
  )
  expect_silent(runtime$wlv_native_validate_seed_semantic_pairs(pair))
  expect_error(
    runtime$wlv_native_stateful_seed_pair(runtime$wlv_seed_resource(
      "sea/sector/test",
      value,
      runtime$wlv_native_indicator_contract("test"),
      producer = "parent.test"
    )),
    "lacks explicit semantic-state provenance"
  )
})

test_that("source seed state rules distinguish source and structural missingness", {
  runtime <- native_semantic_seed_runtime
  source_io <- array(
    c(NA_real_, 1, NA_real_, 2),
    dim = c(1L, 2L, 2L),
    dimnames = list(
      year = "2000",
      input = c("A", "B"),
      output = c("A", "FINAL")
    )
  )
  pair <- runtime$wlv_native_stateful_seed_pair(runtime$wlv_seed_resource(
    "source/io",
    source_io,
    runtime$wlv_native_source_io_contract(),
    partition = "2000-2000"
  ))
  states <- runtime$wlv_semantic_state_expand(pair[[2L]]$value, pair[[1L]]$value)

  expect_identical(states["2000", "A", "A"], "source_missing")
  expect_identical(states["2000", "A", "FINAL"], "not_applicable")
})

test_that("preflight seeds expose controls and canonical semantic pairs", {
  runtime <- native_semantic_seed_runtime
  contracts <- runtime$wlv_native_preflight_seed_contracts(
    source = "wiodr13",
    mode = "calculate",
    at_stage = 1L,
    indicators = "test"
  )
  controls <- c(
    "request/method", "request/source",
    "configuration/missingness_policy",
    "configuration/scientific_profile"
  )
  expect_identical(
    unname(vapply(contracts[controls], `[[`, character(1L), "role")),
    rep("control", length(controls))
  )
  expect_identical(
    contracts[["dimensions/import_group_indices"]]$value_type,
    "list"
  )
  expect_type(
    runtime$wlv_native_dummy_value(
      contracts[["dimensions/import_group_indices"]]
    ),
    "list"
  )
  for (key in c("source/sea", "source/io")) {
    state_key <- runtime$wlv_semantic_state_key(key)
    expect_true(state_key %in% names(contracts))
    value <- runtime$wlv_native_dummy_value(contracts[[key]])
    state <- runtime$wlv_native_preflight_dummy_value(
      state_key,
      contracts[[state_key]],
      contracts
    )
    expect_silent(runtime$wlv_semantic_state_validate(
      state,
      value = value,
      target_key = key,
      axes = contracts[[key]]$axes,
      state_key = state_key
    ))
  }
})

test_that("parent indicator seeds import exact persisted states without inference", {
  skip_if_not_installed("fst")
  runtime <- native_semantic_seed_runtime
  parent <- tempfile("wlv-parent-semantic-")
  dir.create(parent)
  on.exit(unlink(parent, recursive = TRUE, force = TRUE), add = TRUE)
  sector <- array(
    c(1, NA_real_),
    dim = c(1L, 1L, 2L, 1L),
    dimnames = list(
      year = "2000", indicator = "test", sector = c("S1", "S2"),
      country = "A"
    )
  )
  country <- array(
    NA_real_,
    dim = c(1L, 1L, 1L),
    dimnames = list(year = "2000", indicator = "test", country = "A")
  )
  runtime$write_fst_array(
    sector,
    file.path(parent, "sea_sectors.fst"),
    drop_axis_names = TRUE
  )
  runtime$write_fst_array(
    country,
    file.path(parent, "sea_countries.fst"),
    drop_axis_names = TRUE
  )
  io_resources <- runtime$wlv_runtime_snapshot_io_resources()
  parent_io <- array(
    as.double(seq_along(io_resources)),
    dim = c(1L, length(io_resources), 1L, 1L),
    dimnames = list(
      year = "2000", variable = io_resources, input = "A", output = "A"
    )
  )
  io_path <- file.path(parent, "m_io.fst")
  runtime$write_fst_array(parent_io, io_path)
  lambda <- array(
    1,
    dim = c(1L, 1L),
    dimnames = list(year = "2000", input = "A")
  )
  sector_states <- runtime$wlv_semantic_state_array(
    sector,
    c("year", "indicator", "sector", "country")
  )
  sector_states["2000", "test", "S1", "A"] <- "not_applicable"
  sector_states["2000", "test", "S2", "A"] <- "source_missing"
  country_states <- runtime$wlv_semantic_state_array(
    country,
    c("year", "indicator", "country")
  )
  country_states["2000", "test", "A"] <- "not_applicable"
  snapshot_store <- wlv_test_runtime_snapshot_store(
    runtime,
    parent_io,
    lambda,
    sector,
    country,
    sector_states,
    country_states
  )
  snapshot <- runtime$wlv_runtime_snapshot_create(
    snapshot_store,
    method = "test_method",
    source = "wiodr13",
    partitions = "2000-2000",
    io_artifacts = stats::setNames(io_path, "2000-2000"),
    panel_artifacts = c(
      sea_sectors = file.path(parent, "sea_sectors.fst"),
      sea_countries = file.path(parent, "sea_countries.fst")
    ),
    compatibility = wlv_test_runtime_compatibility(
      runtime,
      method = "test_method"
    )
  )
  runtime$wlv_runtime_snapshot_write(snapshot, parent)
  records <- data.frame(
    artifact = c("sea_sectors", "sea_countries"),
    indicator = "test",
    year = "2000",
    country = "A",
    sector = c("S2", ""),
    output = "",
    state = c("source_missing", "not_applicable"),
    stringsAsFactors = FALSE
  )
  wlv_test_write_parent_states(
    runtime,
    file.path(parent, "_states.csv"),
    records
  )
  resolved <- list(list(
    instance_id = "consumer",
    provides = list(),
    requires = list(
      runtime$wlv_resource_ref(
        "sea/sector/test",
        runtime$wlv_native_indicator_contract("test"),
        producer = "child.sector"
      ),
      runtime$wlv_resource_ref(
        "sea/country/test",
        runtime$wlv_native_indicator_contract("test", level = "country"),
        producer = "child.country"
      )
    )
  ))
  tampered_snapshot <- snapshot
  tampered_snapshot$panel_provenance$producer[[1L]] <- "forged.parent"
  tampered_snapshot$panel_provenance$state_producer[[1L]] <- "forged.parent"
  expect_error(
    runtime$wlv_native_parent_indicator_seeds(
      parent,
      indicators = "test",
      resolved = resolved,
      method = "test_method",
      source = "wiodr13",
      partitions = "2000-2000",
      snapshot = tampered_snapshot,
      snapshot_sha256 = runtime$wlv_publication_file_sha256(file.path(
        parent,
        runtime$wlv_runtime_snapshot_filename()
      ))
    ),
    "differs from its immutable file"
  )
  imported <- runtime$wlv_native_parent_indicator_seeds(
    parent,
    indicators = "test",
    resolved = resolved,
    method = "test_method",
    source = "wiodr13",
    partitions = "2000-2000"
  )
  expect_identical(names(imported), c("seeds", "resolutions"))
  expect_length(imported$seeds, 4L)
  expect_identical(nrow(imported$resolutions), 2L)
  expect_true(all(imported$resolutions$source_mode == "terminal"))
  expect_identical(
    imported$resolutions$child_producer,
    c("child.country", "child.sector")
  )
  expect_identical(
    imported$resolutions$origin_producer,
    c("parent.country", "parent.sector")
  )
  expect_silent(runtime$wlv_native_validate_seed_semantic_pairs(imported$seeds))
  state_seeds <- Filter(function(seed) {
    identical(seed$contract$role, "semantic_state")
  }, imported$seeds)
  imported_states <- sort(unlist(lapply(state_seeds, function(seed) {
    as.character(seed$value$state)
  }), use.names = FALSE))
  expect_identical(
    imported_states,
    c("not_applicable", "not_applicable", "source_missing")
  )

  wlv_test_write_parent_states(
    runtime,
    file.path(parent, "_states.csv"),
    records[1L, , drop = FALSE]
  )
  expect_error(
    runtime$wlv_native_parent_indicator_seeds(
      parent,
      indicators = "test",
      resolved = resolved,
      method = "test_method",
      source = "wiodr13",
      partitions = "2000-2000"
    ),
    "ordinary NAs without persisted semantic states"
  )
})

test_that("parent IO and lambda reconstruction fail closed without provenance", {
  skip_if_not_installed("fst")
  runtime <- native_semantic_seed_runtime
  parent <- tempfile("wlv-parent-io-semantic-")
  source_root <- tempfile("wlv-source-io-semantic-")
  dir.create(parent)
  dir.create(source_root)
  on.exit(unlink(c(parent, source_root), recursive = TRUE, force = TRUE),
    add = TRUE
  )
  source_io <- array(
    1,
    dim = c(1L, 1L, 2L),
    dimnames = list(year = "2000", input = "A", output = c("A", "FD"))
  )
  io_resources <- runtime$wlv_runtime_snapshot_io_resources()
  parent_io <- array(
    NA_real_,
    dim = c(1L, length(io_resources), 1L, 2L),
    dimnames = list(
      year = "2000", variable = io_resources, input = "A",
      output = c("A", "FD")
    )
  )
  parent_io[, , , "A"] <- as.double(seq_along(io_resources))
  source_path <- file.path(source_root, "m_io_source.fst")
  parent_io_path <- file.path(parent, "parent-period.fst")
  runtime$write_fst_array(source_io, source_path)
  runtime$write_fst_array(parent_io, parent_io_path)
  resolved <- list(list(
    instance_id = "consumer",
    provides = list(),
    requires = list(
      runtime$wlv_resource_ref(
        "io/values",
        runtime$wlv_native_io_contract("values"),
        producer = "parent.values",
        partition = "2000-2000"
      ),
      runtime$wlv_resource_ref(
        "intermediate/lambda",
        runtime$wlv_native_intermediate_contract(
          "lambda",
          c("year", "input"),
          "io_period"
        ),
        producer = "parent.lambda",
        partition = "2000-2000"
      )
    )
  ))

  expect_error(
    runtime$wlv_native_parent_io_seeds(
      parent_result_dir = parent,
      source_io_paths = source_path,
      partitions = "2000-2000",
      resolved = resolved,
      dimensions = list(lists = list(input = "A", output = c("A", "FD"))),
      method = "test_method",
      source = "wiodr13"
    ),
    "Parent run lacks `_runtime_resources.rds`",
    fixed = TRUE
  )

  lambda <- array(
    2,
    dim = c(1L, 1L),
    dimnames = list(year = "2000", input = "A")
  )
  sea_sectors <- array(
    1,
    dim = c(1L, 1L, 1L, 1L),
    dimnames = list(
      year = "2000", indicator = "test", sector = "S1", country = "A"
    )
  )
  sea_countries <- array(
    1,
    dim = c(1L, 1L, 1L),
    dimnames = list(year = "2000", indicator = "test", country = "A")
  )
  runtime$write_fst_array(
    sea_sectors,
    file.path(parent, "sea_sectors.fst")
  )
  runtime$write_fst_array(
    sea_countries,
    file.path(parent, "sea_countries.fst")
  )
  snapshot_store <- wlv_test_runtime_snapshot_store(
    runtime,
    parent_io,
    lambda,
    sea_sectors,
    sea_countries,
    runtime$wlv_semantic_state_array(
      sea_sectors,
      c("year", "indicator", "sector", "country")
    ),
    runtime$wlv_semantic_state_array(
      sea_countries,
      c("year", "indicator", "country")
    )
  )
  snapshot <- runtime$wlv_runtime_snapshot_create(
    snapshot_store,
    method = "test_method",
    source = "wiodr13",
    partitions = "2000-2000",
    io_artifacts = stats::setNames(
      parent_io_path,
      "2000-2000"
    ),
    panel_artifacts = c(
      sea_sectors = file.path(parent, "sea_sectors.fst"),
      sea_countries = file.path(parent, "sea_countries.fst")
    ),
    compatibility = wlv_test_runtime_compatibility(
      runtime,
      method = "test_method"
    )
  )
  values_id <- paste("io/values", "2000-2000", sep = "\034")
  expect_identical(
    snapshot$resources[[values_id]]$state$encoding,
    "cartesian"
  )
  runtime$wlv_runtime_snapshot_write(snapshot, parent)
  imported <- runtime$wlv_native_parent_io_seeds(
    parent_result_dir = parent,
    source_io_paths = source_path,
    partitions = "2000-2000",
    resolved = resolved,
    dimensions = list(lists = list(input = "A", output = c("A", "FD"))),
    method = "test_method",
    source = "wiodr13"
  )
  expect_identical(names(imported), c("seeds", "resolutions"))
  expect_length(imported$seeds, 4L)
  expect_silent(runtime$wlv_native_validate_seed_semantic_pairs(imported$seeds))
  imported_values <- Filter(function(seed) {
    identical(seed$key, "io/values") &&
      identical(seed$contract$role, "value")
  }, imported$seeds)[[1L]]
  expected_values <- array(
    parent_io[, "values", , , drop = FALSE],
    dim = dim(parent_io)[c(1L, 3L, 4L)],
    dimnames = dimnames(parent_io)[c("year", "input", "output")]
  )
  expect_identical(imported_values$value, expected_values)
  imported_values_state <- Filter(function(seed) {
    identical(seed$key, "semantic_state/io/values")
  }, imported$seeds)[[1L]]
  expect_identical(
    imported_values_state$value,
    runtime$wlv_runtime_snapshot_state_unpack(
      snapshot$resources[[values_id]]$state,
      expected_values
    )
  )
  expect_identical(
    imported_values_state$value$state,
    "not_applicable"
  )
  values_resolution <- imported$resolutions[
    imported$resolutions$key == "io/values",
    ,
    drop = FALSE
  ]
  expect_identical(
    values_resolution$state_sha256,
    snapshot$resources[[values_id]]$state_sha256
  )
  imported_lambda <- Filter(function(seed) {
    identical(seed$key, "intermediate/lambda")
  }, imported$seeds)[[1L]]
  expect_identical(imported_lambda$value, lambda)
  expect_identical(nrow(imported$resolutions), 2L)
  expect_identical(
    imported$resolutions$origin_producer,
    c("parent.lambda", "parent.values")
  )

  incompatible <- resolved
  incompatible[[1L]]$requires[[1L]]$producer <- "wrong.values"
  aliased <- runtime$wlv_native_parent_io_seeds(
    parent_result_dir = parent,
    source_io_paths = source_path,
    partitions = "2000-2000",
    resolved = incompatible,
    dimensions = list(lists = list(input = "A", output = c("A", "FD"))),
    method = "test_method",
    source = "wiodr13"
  )
  value_resolution <- aliased$resolutions[
    aliased$resolutions$key == "io/values",
    ,
    drop = FALSE
  ]
  expect_identical(value_resolution$source_mode, "terminal")
  expect_identical(value_resolution$child_producer, "wrong.values")
  expect_identical(value_resolution$origin_producer, "parent.values")
})
