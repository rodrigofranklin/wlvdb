native_data_environment <- new.env(parent = globalenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "native_data.R"),
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
