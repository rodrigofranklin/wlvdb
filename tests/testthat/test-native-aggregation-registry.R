native_aggregation_environment <- new.env(parent = baseenv())
for (native_aggregation_file in c(
  "R/lib/unit_dimensions.R",
  "R/lib/aggregation_specs.R",
  "R/lib/module_config.R",
  "R/lib/catalog.R",
  "R/lib/native_aggregation_registry.R"
)) {
  sys.source(
    file.path(wlv_test_root, native_aggregation_file),
    envir = native_aggregation_environment
  )
}
rm(native_aggregation_file)

wlv_test_native_aggregation_catalog <- function() {
  native_aggregation_environment$wlv_load_catalog(wlv_test_root)
}

wlv_test_native_aggregation_methods <- c(
  "wiodr13", "wiodr16", "alternative_1", "alternative_2",
  "norow_w13", "ochoa_1", "ochoa_2", "petrovic", "wiodr13v09",
  "wiodr16v09", "zerodep_1", "zerodep_2"
)

wlv_test_native_aggregation_fixture_root <- function(catalog) {
  root <- tempfile("wlv-native-aggregation-")
  config <- file.path(root, "config", "aggregations")
  dir.create(config, recursive = TRUE, showWarnings = FALSE)
  files <- c(
    "method_profiles.csv",
    "stable_formula_modules.csv",
    "wiodr13_historical_v1.csv",
    "wiodr16_historical_v1.csv"
  )
  copied <- file.copy(
    file.path(wlv_test_root, "config", "aggregations", files),
    file.path(config, files)
  )
  stopifnot(all(copied))
  catalog$root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  list(root = root, catalog = catalog)
}

test_that("native aggregation registries exactly cover all 12 methods", {
  catalog <- wlv_test_native_aggregation_catalog()
  executable <- catalog$methods$method[
    catalog$methods$can_calculate | catalog$methods$can_recalculate
  ]
  expect_setequal(executable, wlv_test_native_aggregation_methods)

  for (method in wlv_test_native_aggregation_methods) {
    method_record <- native_aggregation_environment$wlv_catalog_method(
      catalog,
      method
    )
    source_record <- native_aggregation_environment$wlv_catalog_source(
      catalog,
      method_record$source[[1L]]
    )
    contract <- native_aggregation_environment$wlv_catalog_unit_contract(
      catalog,
      source_record$unit_contract[[1L]]
    )
    registry <- native_aggregation_environment$wlv_native_aggregation_registry(
      wlv_test_root,
      catalog,
      method
    )
    expect_s3_class(registry, "wlv_aggregation_registry")
    expect_false("legacy" %in% names(registry), info = method)
    expect_true(all(vapply(registry$bindings, function(binding) {
      !"legacy" %in% names(binding)
    }, logical(1L))), info = method)
    expect_identical(
      registry$rows$indicator,
      rep(contract$units$indicator, each = 2L),
      info = method
    )
    expect_identical(
      registry$rows$level,
      rep(
        c("sector_to_country", "country_to_world"),
        times = nrow(contract$units)
      ),
      info = method
    )
    expect_equal(nrow(registry$rows), 2L * nrow(contract$units), info = method)
    formula <- registry$rows$strategy == "formula"
    expect_identical(
      registry$rows$module[formula],
      paste0("aggregation.", registry$rows$indicator[formula]),
      info = method
    )
    expect_false(any(nzchar(registry$rows$module[!formula])), info = method)
    expect_false(any(grepl("[/\\\\]", registry$rows$module)), info = method)
    expect_false(any(grepl("[.]R$", registry$rows$module)), info = method)
  }
})

test_that("stable registries preserve v2 contracts and validate dimensions", {
  catalog <- wlv_test_native_aggregation_catalog()
  for (method in c("wiodr13", "wiodr16")) {
    method_record <- native_aggregation_environment$wlv_catalog_method(
      catalog,
      method
    )
    source_record <- native_aggregation_environment$wlv_catalog_source(
      catalog,
      method_record$source[[1L]]
    )
    contract <- native_aggregation_environment$wlv_catalog_unit_contract(
      catalog,
      source_record$unit_contract[[1L]]
    )
    expect_identical(
      as.character(contract$metadata$schema_version[[1L]]),
      "2",
      info = method
    )
    registry <- native_aggregation_environment$wlv_native_aggregation_registry(
      wlv_test_root,
      catalog,
      method
    )
    expected <- native_aggregation_environment$
      wlv_native_aggregation_canonical_rows(
        contract$aggregations,
        contract$units,
        method
      )
    formula <- expected$strategy == "formula"
    expected$module[formula] <- paste0(
      "aggregation.",
      expected$indicator[formula]
    )
    expect_identical(registry$rows, expected, info = method)
    expect_no_error(native_aggregation_environment$
      wlv_validate_aggregation_dimensions(
        contract$units,
        registry$rows,
        strict_cross_country = TRUE
      ))
  }

  source_record <- native_aggregation_environment$wlv_catalog_source(
    catalog,
    "wiodr13"
  )
  contract_id <- source_record$unit_contract[[1L]]
  broken <- catalog$unit_aggregations[[contract_id]]
  target <- broken$indicator == "value.m.mv" &
    broken$strategy == "ratio_of_sums"
  broken$numerator[target] <- "emp.s.un"
  catalog$unit_aggregations[[contract_id]] <- broken
  expect_error(
    native_aggregation_environment$wlv_native_aggregation_registry(
      wlv_test_root,
      catalog,
      "wiodr13"
    ),
    "Aggregation unit contract",
    fixed = TRUE
  )
})

test_that("stable formula routing fails closed without native module IDs", {
  catalog <- wlv_test_native_aggregation_catalog()
  fixture <- wlv_test_native_aggregation_fixture_root(catalog)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  path <- file.path(
    fixture$root,
    "config",
    "aggregations",
    "stable_formula_modules.csv"
  )
  mapping <- utils::read.csv2(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
  mapping$module_id[[1L]] <- "common/legacy-country.R"
  utils::write.table(
    mapping,
    path,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE,
    fileEncoding = "UTF-8"
  )
  expect_error(
    native_aggregation_environment$wlv_native_aggregation_registry(
      fixture$root,
      fixture$catalog,
      "wiodr13"
    ),
    "invalid declarations",
    fixed = TRUE
  )
})

test_that("experimental registries exactly reproduce explicit historical profiles", {
  catalog <- wlv_test_native_aggregation_catalog()
  experimental <- setdiff(
    wlv_test_native_aggregation_methods,
    c("wiodr13", "wiodr16")
  )
  for (method in experimental) {
    method_record <- native_aggregation_environment$wlv_catalog_method(
      catalog,
      method
    )
    source_record <- native_aggregation_environment$wlv_catalog_source(
      catalog,
      method_record$source[[1L]]
    )
    contract <- native_aggregation_environment$wlv_catalog_unit_contract(
      catalog,
      source_record$unit_contract[[1L]]
    )
    profile <- native_aggregation_environment$
      wlv_read_method_aggregation_profile(
        wlv_test_root,
        method,
        method_record$source[[1L]]
      )
    expected <- native_aggregation_environment$
      wlv_native_aggregation_canonical_rows(
        profile,
        contract$units,
        method
      )
    registry <- native_aggregation_environment$wlv_native_aggregation_registry(
      wlv_test_root,
      catalog,
      method
    )
    expect_identical(registry$rows, expected, info = method)
    expect_false("legacy" %in% names(registry), info = method)
  }
})

test_that("native formula bindings remain compatible with registry lookup", {
  catalog <- wlv_test_native_aggregation_catalog()
  registry <- native_aggregation_environment$wlv_native_aggregation_registry(
    wlv_test_root,
    catalog,
    "wiodr13"
  )
  formula <- registry$rows$indicator[registry$rows$strategy == "formula"][[1L]]
  binding <- native_aggregation_environment$wlv_aggregation_registry_binding(
    registry,
    formula,
    "country_to_world"
  )
  expect_identical(binding$contract_strategy, "formula")
  expect_identical(binding$module, paste0("aggregation.", formula))
  expect_false("legacy" %in% names(binding))

  direct <- native_aggregation_environment$wlv_aggregation_registry_binding(
    registry,
    "emp.s.un",
    "sector_to_country"
  )
  expect_identical(direct$contract_strategy, "sum")
  expect_s3_class(direct$spec, "wlv_aggregation_spec")
  expect_false("legacy" %in% names(direct))
})

test_that("experimental resolution has no missing-profile or legacy fallback", {
  catalog <- wlv_test_native_aggregation_catalog()
  fixture <- wlv_test_native_aggregation_fixture_root(catalog)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  map_path <- file.path(
    fixture$root,
    "config",
    "aggregations",
    "method_profiles.csv"
  )
  mapping <- native_aggregation_environment$wlv_read_aggregation_profile_map(
    fixture$root
  )
  complete_mapping <- mapping
  mapping <- mapping[mapping$method != "alternative_1", , drop = FALSE]
  utils::write.table(
    mapping,
    map_path,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE,
    fileEncoding = "UTF-8"
  )
  expect_error(
    native_aggregation_environment$wlv_native_aggregation_registry(
      fixture$root,
      fixture$catalog,
      "alternative_1"
    ),
    "requires exactly one historical aggregation profile",
    fixed = TRUE
  )

  utils::write.table(
    complete_mapping,
    map_path,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE,
    fileEncoding = "UTF-8"
  )
  unlink(file.path(
    fixture$root,
    "config",
    "aggregations",
    "wiodr13_historical_v1.csv"
  ))
  expect_error(
    native_aggregation_environment$wlv_native_aggregation_registry(
      fixture$root,
      fixture$catalog,
      "alternative_1"
    ),
    "Aggregation profile does not exist",
    fixed = TRUE
  )

  historical <- native_aggregation_environment$wlv_read_aggregation_profile(
    wlv_test_root,
    "wiodr13_historical_v1"
  )
  formula <- historical$strategy == "formula"
  historical$module[which(formula)[[1L]]] <-
    "common/legacy-country.R"
  expect_error(
    native_aggregation_environment$wlv_native_validate_formula_module_ids(
      historical,
      "Tampered aggregation profile"
    ),
    "explicit native formula module IDs",
    fixed = TRUE
  )
})

test_that("stable profiles and disabled methods are rejected", {
  catalog <- wlv_test_native_aggregation_catalog()
  fixture <- wlv_test_native_aggregation_fixture_root(catalog)
  on.exit(unlink(fixture$root, recursive = TRUE), add = TRUE)
  map_path <- file.path(
    fixture$root,
    "config",
    "aggregations",
    "method_profiles.csv"
  )
  mapping <- native_aggregation_environment$wlv_read_aggregation_profile_map(
    fixture$root
  )
  mapping <- rbind(
    mapping,
    data.frame(
      method = "wiodr13",
      source = "wiodr13",
      profile = "wiodr13_historical_v1",
      stringsAsFactors = FALSE
    )
  )
  utils::write.table(
    mapping,
    map_path,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE,
    fileEncoding = "UTF-8"
  )
  expect_error(
    native_aggregation_environment$wlv_native_aggregation_registry(
      fixture$root,
      fixture$catalog,
      "wiodr13"
    ),
    "must not select a historical profile",
    fixed = TRUE
  )
  expect_error(
    native_aggregation_environment$wlv_native_aggregation_registry(
      fixture$root,
      fixture$catalog,
      "eora26"
    ),
    "is not executable",
    fixed = TRUE
  )
})

test_that("native aggregation solution sidecars contain no legacy routes", {
  catalog <- wlv_test_native_aggregation_catalog()
  contract <- native_aggregation_environment$wlv_catalog_unit_contract(
    catalog,
    "wiodr13_units_v2"
  )
  registry <- native_aggregation_environment$wlv_native_aggregation_registry(
    wlv_test_root,
    catalog,
    "wiodr13"
  )
  solutions <- native_aggregation_environment$wlv_native_aggregation_solutions(
    contract$units,
    registry$rows
  )

  expect_identical(solutions$names, as.character(contract$units$indicator))
  expect_identical(
    solutions$country_solution[solutions$names == "exchange.r.us"],
    "not_applicable"
  )
  expect_identical(
    solutions$country_solution[solutions$names == "value.m.mv"],
    "ratio_of_sums"
  )
  expect_identical(
    solutions$country_solution[
      solutions$names == "surplus_value.empe.r.pc"
    ],
    "aggregation.surplus_value.empe.r.pc"
  )
  expect_false(any(grepl("[.]R$", solutions$country_solution)))
})
