native_data_environment <- new.env(parent = globalenv())
sys.source(
  file.path(wlv_test_root, "scripts", "lib", "native_data.R"),
  envir = native_data_environment
)

test_that("native semicolon reader preserves the UTF-8 method label", {
  parameters <- native_data_environment$wlv_native_read_semicolon(
    file.path(wlv_test_root, "methods", "norow_w13", "_parameters.csv")
  )
  expected <- "Teste sem suposições para resto do mundo"
  expect_identical(
    charToRaw(enc2utf8(parameters$name[[1L]])),
    charToRaw(enc2utf8(expected))
  )
  expect_false(grepl("\uFFFD", parameters$name[[1L]], fixed = TRUE))
})

test_that("native semicolon reader preserves row names and rejects mojibake", {
  valid <- tempfile(fileext = ".csv")
  writeLines(c("id;value", "a;ok"), valid, useBytes = TRUE)
  parsed <- native_data_environment$wlv_native_read_semicolon(
    valid,
    row.names = 1L
  )
  expect_identical(row.names(parsed), "a")
  expect_identical(parsed$value, "ok")

  invalid <- tempfile(fileext = ".csv")
  writeLines(c("id;value", "a;suposiÃ§ões"), invalid, useBytes = TRUE)
  expect_error(
    native_data_environment$wlv_native_read_semicolon(invalid),
    "invalid UTF-8 text"
  )
})

test_that("native dimensions precompute the exact historical import groups", {
  normalized_dir <- tempfile("wlv-native-dimensions-")
  dir.create(normalized_dir)
  on.exit(unlink(normalized_dir, recursive = TRUE, force = TRUE), add = TRUE)
  writeLines(
    c("country.source;country", "AAA;A", "BBB;B"),
    file.path(normalized_dir, "countries.csv"),
    useBytes = TRUE
  )
  writeLines(
    c("demand", "c41"),
    file.path(normalized_dir, "demand.csv"),
    useBytes = TRUE
  )
  source_sea <- array(
    1,
    dim = c(1L, 1L, 2L, 2L),
    dimnames = list(
      year = "2000",
      variable = "EMP",
      sector = c("S1", "S2"),
      country = c("AAA", "BBB")
    )
  )
  sectors <- data.frame(
    sector.source = c("S1", "S2"),
    productive = c(1L, 0L),
    stringsAsFactors = FALSE
  )

  dimensions <- native_data_environment$wlv_native_dimensions(
    source_sea,
    sectors,
    normalized_dir
  )
  historical_groups <- base::as.factor(
    dimensions$io_filters["imports", , ]
  )
  expected_indices <- base::split(
    base::seq_along(historical_groups),
    historical_groups,
    drop = FALSE
  )

  expect_silent(native_data_environment$wlv_native_import_group_indices_validate(
    expected_indices,
    historical_groups
  ))

  expect_s3_class(
    dimensions$import_group_indices,
    "wlv_import_group_indices"
  )
  expect_identical(
    unclass(dimensions$import_group_indices),
    expected_indices
  )

  filter_calls <- 0L
  import_group_calls <- 0L
  original_filters <- native_data_environment$wlv_native_io_filters
  original_import_groups <-
    native_data_environment$wlv_native_import_group_indices
  assign(
    "wlv_native_io_filters",
    function(...) {
      filter_calls <<- filter_calls + 1L
      original_filters(...)
    },
    envir = native_data_environment
  )
  assign(
    "wlv_native_import_group_indices",
    function(...) {
      import_group_calls <<- import_group_calls + 1L
      original_import_groups(...)
    },
    envir = native_data_environment
  )
  on.exit({
    assign(
      "wlv_native_io_filters",
      original_filters,
      envir = native_data_environment
    )
    assign(
      "wlv_native_import_group_indices",
      original_import_groups,
      envir = native_data_environment
    )
  }, add = TRUE)

  lightweight <- native_data_environment$wlv_native_dimensions_from_years(
    "2000",
    sectors,
    normalized_dir,
    required_keys = c("dimensions/lists", "dimensions/rows")
  )
  expect_null(lightweight$io_filters)
  expect_null(lightweight$import_group_indices)
  expect_identical(filter_calls, 0L)
  expect_identical(import_group_calls, 0L)

  filters_only <- native_data_environment$wlv_native_dimensions_from_years(
    "2000",
    sectors,
    normalized_dir,
    required_keys = "dimensions/io_filters"
  )
  expect_true(is.array(filters_only$io_filters))
  expect_null(filters_only$import_group_indices)
  expect_identical(filter_calls, 1L)
  expect_identical(import_group_calls, 0L)

  groups_only <- native_data_environment$wlv_native_dimensions_from_years(
    "2000",
    sectors,
    normalized_dir,
    required_keys = "dimensions/import_group_indices"
  )
  expect_null(groups_only$io_filters)
  expect_s3_class(groups_only$import_group_indices, "wlv_import_group_indices")
  expect_identical(filter_calls, 2L)
  expect_identical(import_group_calls, 1L)

  duplicated <- expected_indices
  duplicated[[1L]][[1L]] <- duplicated[[1L]][[2L]]
  expect_error(
    native_data_environment$wlv_native_import_group_indices_validate(
      duplicated,
      historical_groups
    ),
    "exact canonical partition"
  )
  out_of_range <- expected_indices
  out_of_range[[1L]][[1L]] <- length(historical_groups) + 1L
  expect_error(
    native_data_environment$wlv_native_import_group_indices_validate(
      out_of_range,
      historical_groups
    ),
    "exact canonical partition"
  )
  wrong_group <- expected_indices
  temporary <- wrong_group[[1L]][[1L]]
  wrong_group[[1L]][[1L]] <- wrong_group[[2L]][[1L]]
  wrong_group[[2L]][[1L]] <- temporary
  expect_error(
    native_data_environment$wlv_native_import_group_indices_validate(
      wrong_group,
      historical_groups
    ),
    "exact canonical partition"
  )
})

test_that("native empty requirements stay empty", {
  expect_identical(
    native_data_environment$wlv_native_instance_required_keys(NULL, list()),
    character()
  )
})

test_that("native assumptions return before reading when the DAG needs none", {
  original_reader <- native_data_environment$wlv_native_read_semicolon
  had_hours_reader <- exists(
    "wlv_read_wiodr16_china_hours_per_worker",
    envir = native_data_environment,
    inherits = FALSE
  )
  original_hours_reader <- if (had_hours_reader) {
    native_data_environment$wlv_read_wiodr16_china_hours_per_worker
  } else {
    NULL
  }
  assign(
    "wlv_native_read_semicolon",
    function(...) stop("Unexpected assumption read.", call. = FALSE),
    envir = native_data_environment
  )
  assign(
    "wlv_read_wiodr16_china_hours_per_worker",
    function(...) stop("Unexpected China-hours read.", call. = FALSE),
    envir = native_data_environment
  )
  on.exit({
    assign(
      "wlv_native_read_semicolon",
      original_reader,
      envir = native_data_environment
    )
    if (had_hours_reader) {
      assign(
        "wlv_read_wiodr16_china_hours_per_worker",
        original_hours_reader,
        envir = native_data_environment
      )
    } else {
      rm(
        list = "wlv_read_wiodr16_china_hours_per_worker",
        envir = native_data_environment
      )
    }
  }, add = TRUE)

  for (source in c("wiodr13", "wiodr16")) {
    expect_identical(
      native_data_environment$wlv_native_assumption_seeds(
        root = tempfile("unused-native-root-"),
        source = source,
        dimensions = list(),
        sectors = data.frame(),
        required_keys = character()
      ),
      list()
    )
  }
})

test_that("native assumptions read and seed only the required resource", {
  runtime <- wlv_test_clone_runtime()
  observed <- new.env(parent = emptyenv())
  observed$paths <- character()

  assign(
    "wlv_native_read_semicolon",
    function(path, row.names = NULL, ...) {
      observed$paths <- c(observed$paths, basename(path))
      value <- data.frame(value = 1, stringsAsFactors = FALSE)
      if (!is.null(row.names)) row.names(value) <- "row"
      value
    },
    envir = runtime
  )
  assign(
    "wlv_read_wiodr16_china_hours_per_worker",
    function(path, expected_codes, expected_names, expected_years) {
      observed$paths <- c(observed$paths, basename(path))
      array(
        1,
        dim = c(length(expected_years), length(expected_codes)),
        dimnames = list(expected_years, expected_codes)
      )
    },
    envir = runtime
  )

  dimensions <- list(lists = list(
    years = c("2000", "2001"),
    sectors = c("S1", "S2")
  ))
  sectors <- data.frame(
    sector = c("Sector 1", "Sector 2"),
    stringsAsFactors = FALSE
  )
  cases <- list(
    list(
      key = "assumption/employment_row_current",
      source = "wiodr13",
      path = "employment_row.new.csv",
      value_type = "data.frame",
      axes = NULL,
      missingness = NULL
    ),
    list(
      key = "assumption/employment_row_legacy",
      source = "wiodr13",
      path = "employment_row.csv",
      value_type = "data.frame",
      axes = NULL,
      missingness = NULL
    ),
    list(
      key = "assumption/employment_china",
      source = "wiodr13",
      path = "employment_china.csv",
      value_type = "data.frame",
      axes = NULL,
      missingness = NULL
    ),
    list(
      key = "assumption/china_hours_per_worker",
      source = "wiodr16",
      path = "china_hours_per_worker.csv",
      value_type = "array",
      axes = c("year", "sector"),
      missingness = "none"
    )
  )

  for (case in cases) {
    observed$paths <- character()
    seeds <- runtime$wlv_native_assumption_seeds(
      root = tempfile("selective-native-root-"),
      source = case$source,
      dimensions = dimensions,
      sectors = sectors,
      required_keys = case$key
    )
    expect_length(seeds, 1L)
    expect_s3_class(seeds[[1L]], "wlv_seed_resource")
    expect_identical(seeds[[1L]]$key, case$key)
    expect_identical(seeds[[1L]]$contract$scope, "run")
    expect_identical(seeds[[1L]]$contract$value_type, case$value_type)
    expect_identical(seeds[[1L]]$contract$axes, case$axes)
    expect_identical(
      seeds[[1L]]$contract$missingness,
      case$missingness
    )
    expect_identical(seeds[[1L]]$contract$role, "value")
    expect_false(seeds[[1L]]$contract$semantic_state)
    expect_identical(observed$paths, case$path)
  }
})
