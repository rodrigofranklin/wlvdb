native_output_environment <- new.env(parent = globalenv())
for (path in c(
  "R/lib/catalog.R",
  "R/lib/missingness.R",
  "R/lib/result_contracts.R",
  "R/lib/unit_dimensions.R",
  "R/lib/aggregation_specs.R",
  "R/lib/module_config.R",
  "R/lib/native_aggregation_registry.R",
  "R/lib/native_output_contract.R"
)) {
  sys.source(file.path(wlv_test_root, path), envir = native_output_environment)
}

wlv_native_scientific_fixture <- function() {
  root <- tempfile("wlv-scientific-contract-")
  dir.create(root, recursive = TRUE)
  source_root <- normalizePath(wlv_test_root, winslash = "/", mustWork = TRUE)
  paths <- unlist(lapply(c(
    file.path(source_root, "config", "outputs"),
    file.path(source_root, "config", "contracts"),
    file.path(source_root, "config", "modules")
  ), function(directory) {
    list.files(directory, recursive = TRUE, full.names = TRUE)
  }), use.names = FALSE)
  for (path in paths) {
    relative <- substring(
      normalizePath(path, winslash = "/", mustWork = TRUE),
      nchar(source_root) + 2L
    )
    destination <- file.path(root, relative)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    if (!file.copy(path, destination, overwrite = TRUE)) {
      stop("Could not create scientific-contract fixture.", call. = FALSE)
    }
  }
  root
}

wlv_native_scientific_edit <- function(root, name, edit) {
  path <- file.path(root, "config", "contracts", name)
  value <- utils::read.csv2(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL,
    fileEncoding = "UTF-8"
  )
  utils::write.table(
    edit(value),
    path,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE,
    na = "",
    fileEncoding = "UTF-8"
  )
  invisible(path)
}

# Only this in-memory fixture enables deferred definitions for unit checks.
# Public entrypoints always use the checked-in catalog's capability flags.
wlv_test_all_native_profile_catalog <- function() {
  catalog <- native_output_environment$wlv_load_catalog(wlv_test_root)
  declared <- catalog$methods$status != "disabled"
  catalog$methods$can_calculate[declared] <- TRUE
  catalog$methods$can_recalculate[declared] <- TRUE
  catalog
}

test_that("only the two main methods expose executable output and scientific profiles", {
  e <- native_output_environment
  catalog <- e$wlv_load_catalog(wlv_test_root)
  indicators <- e$wlv_validate_native_output_profiles(wlv_test_root, catalog)
  profiles <- e$wlv_validate_native_scientific_profiles(
    wlv_test_root, catalog, indicators
  )
  expect_identical(names(indicators), c("wiodr13", "wiodr16"))
  expect_identical(names(profiles), names(indicators))
})

test_that("retained output maps cannot hide missing active or unknown methods", {
  e <- native_output_environment
  catalog <- e$wlv_load_catalog(wlv_test_root)
  root <- wlv_native_scientific_fixture()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  path <- file.path(root, "config", "outputs", "method_profiles.csv")
  original <- e$wlv_native_output_profile_map(root)
  invalid <- list(
    original[original$method != "wiodr13", , drop = FALSE],
    rbind(original, data.frame(method = "unknown_method", profile = "wiodr13_standard"))
  )
  for (mapping in invalid) {
    utils::write.table(
      mapping, path, sep = ";", row.names = FALSE, col.names = TRUE,
      quote = FALSE, fileEncoding = "UTF-8"
    )
    expect_error(
      e$wlv_validate_native_output_profiles(root, catalog),
      "Output profile coverage is invalid"
    )
  }
})

test_that("retained output profiles preserve the five historical panel orders", {
  e <- native_output_environment
  catalog <- wlv_test_all_native_profile_catalog()
  profiles <- e$wlv_validate_native_output_profiles(wlv_test_root, catalog)
  expect_length(profiles, 12L)

  hashes <- vapply(profiles, function(indicators) {
    as.character(openssl::sha256(charToRaw(paste(indicators, collapse = "\n"))))
  }, character(1L))
  expect_identical(
    unname(hashes[c("wiodr13", "norow_w13", "zerodep_1")]),
    rep("68848ddbba1a0935d84ff8394d7b2eae33b13b2e14eb71d8753f6f0d7c77be55", 3L)
  )
  expect_identical(
    unname(hashes[c("wiodr16", "zerodep_2")]),
    rep("f4663edee461ee20f7313bb8371bf2ef57ddae3871703f7b4c0f2891307880df", 2L)
  )
  expect_identical(
    unname(hashes[c(
      "alternative_1", "alternative_2", "ochoa_1", "ochoa_2", "petrovic"
    )]),
    rep("cce4b63b7c821afd77d79bcbf05f0d8a6cc0e00c98b63d5cf3945d6b302e03c4", 5L)
  )
  expect_identical(
    unname(hashes[["wiodr13v09"]]),
    "c4e2f6d47dfbe1e28e1e995d28f31b74de98e702c37b59ceb9e908011005a06f"
  )
  expect_identical(
    unname(hashes[["wiodr16v09"]]),
    "46cd1a1bb12a1f7b4d3271e82aed0d5a5d66653707bbdff2f2357e028a9aec19"
  )
})

test_that("retained native definitions select explicit orthogonal scientific traits", {
  e <- native_output_environment
  catalog <- wlv_test_all_native_profile_catalog()
  indicators <- e$wlv_validate_native_output_profiles(wlv_test_root, catalog)
  profiles <- e$wlv_validate_native_scientific_profiles(
    wlv_test_root,
    catalog,
    indicators
  )

  expect_length(profiles, 12L)
  expect_setequal(names(profiles), names(indicators))
  expect_true(all(vapply(
    profiles,
    inherits,
    logical(1L),
    "wlv_scientific_profile"
  )))
  expect_identical(
    profiles$wiodr13$leontief_zero$exception_count,
    3150L
  )
  expect_identical(
    profiles$alternative_1$leontief_zero$exception_count,
    2945L
  )
  expect_identical(
    profiles$wiodr13$leontief_signed$rows$
      coefficient_negative_count[profiles$wiodr13$leontief_signed$rows$year == "2006"],
    397L
  )
  expect_identical(
    profiles$wiodr13v09$leontief_signed$rows$
      coefficient_negative_count[profiles$wiodr13v09$leontief_signed$rows$year == "2006"],
    396L
  )
  expect_identical(
    profiles$zerodep_1$output_profile,
    profiles$wiodr13$output_profile
  )
  expect_identical(profiles$zerodep_1$leontief_zero$exception_count, 0L)
  expect_true(all(
    profiles$zerodep_1$leontief_signed$rows$coefficient_negative_count == 0L
  ))
  expect_identical(
    profiles$alternative_2$nonfinite_resolution$expected_count,
    405L
  )
  expect_identical(
    nrow(profiles$alternative_2$nonfinite_resolution$rules),
    27L
  )
  expect_identical(
    profiles$petrovic$nonfinite_resolution$action,
    "replace_nan_with_zero"
  )
  expect_identical(
    profiles$petrovic$nonfinite_resolution$expected_count,
    405L
  )
  expect_identical(
    profiles$petrovic$nonfinite_resolution$groups[
      setdiff(names(profiles$petrovic$nonfinite_resolution$groups), "module")
    ],
    profiles$alternative_2$nonfinite_resolution$groups[
      setdiff(names(profiles$alternative_2$nonfinite_resolution$groups), "module")
    ]
  )
  expect_identical(
    profiles$petrovic$nonfinite_resolution$rules,
    profiles$alternative_2$nonfinite_resolution$rules
  )
  expect_identical(
    profiles$ochoa_1$nonfinite_resolution$action,
    "replace_zero_denominator_with_zero"
  )
  expect_identical(
    profiles$ochoa_1$nonfinite_resolution$expected_count,
    530L
  )
  expect_identical(
    profiles$ochoa_1$nonfinite_resolution$groups$expected_count,
    c(264L, 4L, 262L)
  )
  expect_identical(
    profiles$ochoa_1$nonfinite_resolution$groups[
      setdiff(names(profiles$ochoa_1$nonfinite_resolution$groups), "module")
    ],
    profiles$ochoa_2$nonfinite_resolution$groups[
      setdiff(names(profiles$ochoa_2$nonfinite_resolution$groups), "module")
    ]
  )
  expect_true(all(grepl("[.]ochoa_1$",
    profiles$ochoa_1$nonfinite_resolution$groups$module
  )))
  expect_true(all(grepl("[.]ochoa_2$",
    profiles$ochoa_2$nonfinite_resolution$groups$module
  )))
  expect_true(all(vapply(
    profiles[!names(profiles) %in% c(
      "alternative_2", "petrovic", "ochoa_1", "ochoa_2"
    )],
    function(profile) {
      identical(profile$nonfinite_resolution$action, "reject") &&
        identical(profile$nonfinite_resolution$expected_count, 0L)
    },
    logical(1L)
  )))
})

test_that("scientific preflight rejects missing, mismatched and orphan traits", {
  e <- native_output_environment
  catalog <- e$wlv_load_catalog(wlv_test_root)
  indicators <- e$wlv_validate_native_output_profiles(wlv_test_root, catalog)
  roots <- character()
  on.exit(unlink(roots, recursive = TRUE, force = TRUE), add = TRUE)
  validate <- function(edit_file, edit, message) {
    root <- wlv_native_scientific_fixture()
    roots <<- c(roots, root)
    wlv_native_scientific_edit(root, edit_file, edit)
    expect_error(
      e$wlv_validate_native_scientific_profiles(root, catalog, indicators),
      message
    )
  }

  validate(
    "scientific_method_profiles.csv",
    function(value) value[-1L, , drop = FALSE],
    "coverage does not exactly match cataloged native methods"
  )
  validate(
    "scientific_method_profiles.csv",
    function(value) {
      value$method[value$method == "alternative_2"] <- "unknown_method"
      value
    },
    "coverage does not exactly match cataloged native methods"
  )
  validate(
    "scientific_method_profiles.csv",
    function(value) {
      value$output_profile[value$method == "alternative_2"] <-
        "wiodr13_standard"
      value
    },
    "Scientific/output profile mismatch"
  )
  validate(
    "scientific_method_profiles.csv",
    function(value) {
      value$scientific_profile[value$method == "alternative_1"] <-
        "wiodr13_standard_v1"
      value
    },
    "Scientific profile IDs map to incompatible source/output contracts"
  )
  validate(
    "scientific_profiles.csv",
    function(value) {
      value$source[value$scientific_profile == "wiodr13_standard_v1"] <-
        "wiodr16"
      value
    },
    "Scientific profile source mismatch"
  )
  validate(
    "leontief_zero_profiles.csv",
    function(value) rbind(value, data.frame(
      leontief_zero_profile = "orphan_zero_v1",
      exception_count = "0",
      coordinate_md5 = "d41d8cd98f00b204e9800998ecf8427e",
      stringsAsFactors = FALSE
    )),
    "zero-output profiles are missing or unreachable"
  )
  validate(
    "leontief_signed_profiles.csv",
    function(value) rbind(value, data.frame(
      leontief_signed_profile = "orphan_signed_v1",
      year = "2000",
      coefficient_negative_count = "0",
      certificate_type = "productivity_nonnegative",
      stringsAsFactors = FALSE
    )),
    "Signed Leontief profiles are missing or unreachable"
  )
  validate(
    "nonfinite_resolution_profiles.csv",
    function(value) rbind(value, data.frame(
      nonfinite_resolution_profile = "orphan_nonfinite_v1",
      action = "reject",
      expected_count = "0",
      stringsAsFactors = FALSE
    )),
    "Non-finite resolution profiles are missing or unreachable"
  )
  validate(
    "nonfinite_resolution_groups.csv",
    function(value) {
      selected <- value$nonfinite_resolution_profile ==
        "alternative_2_nonfinite_v1"
      value$module[which(selected)[[1L]]] <- "indicator.unreachable"
      value
    },
    "reference an unreachable module"
  )
  validate(
    "nonfinite_resolution_groups.csv",
    function(value) {
      selected <- value$nonfinite_resolution_profile ==
        "ochoa_1_wage_nonfinite_v1" & value$binding == "emp"
      value$indicator[selected] <- "unknown.indicator"
      value
    },
    "groups reference an unknown `ochoa_1` indicator"
  )
  validate(
    "nonfinite_resolution_groups.csv",
    function(value) {
      selected <- value$nonfinite_resolution_profile ==
        "alternative_2_nonfinite_v1"
      value$module[which(selected)[[1L]]] <-
        "indicator.complex_labour_multiplier.emp.r.un.alternative_2"
      value
    },
    "Non-finite resolution groups are invalid"
  )
  validate(
    "nonfinite_resolution_groups.csv",
    function(value) {
      selected <- value$nonfinite_resolution_profile ==
        "ochoa_1_wage_nonfinite_v1" &
        value$binding == "empe" & value$kind == "Inf"
      value$module[selected] <-
        "indicator.complex_labour_multiplier.emp.r.un.ochoa_1"
      value
    },
    "Profiled zero-denominator groups are invalid"
  )
  validate(
    "nonfinite_resolution_rules.csv",
    function(value) {
      selected <- value$nonfinite_resolution_profile ==
        "alternative_2_nonfinite_v1"
      value$year[which(selected)[[1L]]] <- "1994"
      value
    },
    "Non-finite resolution coverage is invalid"
  )
})

test_that("output order is separate from DAG and unit-contract row order", {
  e <- native_output_environment
  catalog <- e$wlv_load_catalog(wlv_test_root)
  aggregation <- e$wlv_native_aggregation_registry(
    wlv_test_root,
    catalog,
    "wiodr13"
  )
  output <- e$wlv_native_output_indicators(
    wlv_test_root,
    catalog,
    "wiodr13",
    aggregation
  )
  expect_null(attributes(output))
  source <- e$wlv_catalog_source(catalog, "wiodr13")
  units <- e$wlv_catalog_unit_contract(
    catalog,
    source$unit_contract[[1L]]
  )$units$indicator
  expect_setequal(output, units)
  expect_false(identical(unname(output), unname(units)))
  expect_identical(
    output[11:13],
    c("gross_output.s.us", "gdp.s.us", "go_price.r.id")
  )

  reduction <- e$wlv_native_output_indicators(
    wlv_test_root,
    catalog,
    "alternative_1"
  )
  expect_identical(
    reduction[20:21],
    c(
      "complex_labour_multiplier.emp.r.un",
      "complex_labour_multiplier.empe.r.un"
    )
  )
  legacy <- e$wlv_native_output_indicators(
    wlv_test_root,
    catalog,
    "wiodr13v09"
  )
  expect_identical(legacy[14:15], c("exchange.r.us", "exchange.r.id"))
})
