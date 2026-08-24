catalog_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "catalog.R"),
  envir = catalog_environment
)

wlv_catalog_test_write <- function(path, value) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.table(
    value,
    path,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE,
    na = ""
  )
  invisible(path)
}

wlv_make_catalog_fixture <- function() {
  root <- tempfile("wlv-catalog-")
  paths <- c(
    file.path(root, "catalog"),
    file.path(root, "methods", "demo"),
    file.path(root, "parameters", "raw_demo"),
    file.path(root, "config", "outputs", "sources"),
    file.path(root, "R", "utils"),
    file.path(root, "R", "lib"),
    file.path(root, "docs"),
    file.path(root, "tests", "testthat")
  )
  for (path in paths) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }

  sources <- data.frame(
    source = "demo_source",
    status = "stable",
    year_start = "2000",
    year_end = "2001",
    parameter_set = "raw_demo",
    data_dir = "source_data/demo_source",
    can_prepare = "TRUE",
    preparation_task = "demo_source",
    validator_script = "R/lib/demo_validation.R",
    validator_function = "wlv_validate_demo_prepared",
    artifact_profile = "demo_core",
    missingness_policy = "demo_v1",
    unit_contract = "demo_units_v1",
    documentation = "docs/demo.md",
    limitations = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  methods <- data.frame(
    method = "demo",
    source = "demo_source",
    code = "DEMO",
    description = "Demonstration method",
    status = "stable",
    can_calculate = "TRUE",
    can_recalculate = "TRUE",
    test = "tests/testthat/test-demo.R",
    documentation = "docs/demo.md",
    limitations = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  artifacts <- data.frame(
    profile = c("demo_core", "demo_core"),
    artifact = c("m_io*.fst", "countries.csv"),
    kind = c("fst_array_glob", "csv"),
    sidecar = c("TRUE", "FALSE"),
    operations = c(
      "prepare|calculate|recalculate",
      "prepare|calculate|recalculate"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  missingness_policies <- data.frame(
    policy = "demo_v1",
    script = "R/lib/demo_missingness.R",
    factory = "wlv_demo_missingness_policy",
    documentation = "docs/demo.md",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  unit_contracts <- data.frame(
    contract = "demo_units_v1",
    schema_version = "1",
    source = "demo_source",
    units = "contracts/units/demo_v1-units.csv",
    aggregations = "contracts/units/demo_v1-aggregations.csv",
    documentation = "docs/demo.md",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  unit_definitions <- data.frame(
    indicator = "demo.value",
    quantity_kind = "monetary",
    source_unit = "usd",
    source_scale = "1",
    canonical_unit = "usd",
    display_unit = "usd",
    display_multiplier = "1",
    currency = "usd",
    price_basis = "current",
    base_year = "",
    index_base = "",
    labour_concept = "not_applicable",
    notes = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  unit_aggregations <- data.frame(
    indicator = rep("demo.value", 2L),
    level = c("sector_to_country", "country_to_world"),
    strategy = rep("sum", 2L),
    module = "",
    numerator = "",
    denominator = "",
    weight = "",
    zero_denominator = "",
    notes = "",
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  wlv_catalog_test_write(file.path(root, "catalog", "sources.csv"), sources)
  wlv_catalog_test_write(file.path(root, "catalog", "methods.csv"), methods)
  wlv_catalog_test_write(
    file.path(root, "catalog", "artifact-profiles.csv"),
    artifacts
  )
  wlv_catalog_test_write(
    file.path(root, "catalog", "missingness-policies.csv"),
    missingness_policies
  )
  wlv_catalog_test_write(
    file.path(root, "catalog", "unit-contracts.csv"),
    unit_contracts
  )
  wlv_catalog_test_write(
    file.path(root, "contracts", "units", "demo_v1-units.csv"),
    unit_definitions
  )
  wlv_catalog_test_write(
    file.path(root, "contracts", "units", "demo_v1-aggregations.csv"),
    unit_aggregations
  )
  wlv_catalog_test_write(
    file.path(root, "methods", "demo", "_parameters.csv"),
    data.frame(
      source = "raw_demo",
      code = "DEMO",
      name = "Demonstration method",
      description = "",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  writeLines(
    "invisible(NULL)",
    file.path(root, "R", "utils", "prepare_demo_data.R")
  )
  writeLines(
    "wlv_validate_demo_prepared <- function(...) invisible(TRUE)",
    file.path(root, "R", "lib", "demo_validation.R")
  )
  writeLines(
    "wlv_demo_missingness_policy <- function(...) list(policy_id = 'demo_v1')",
    file.path(root, "R", "lib", "demo_missingness.R")
  )
  writeLines(
    "# Demonstration source contract",
    file.path(root, "docs", "demo.md")
  )
  wlv_catalog_test_write(
    file.path(root, "config", "outputs", "method_profiles.csv"),
    data.frame(method = "demo", profile = "demo_standard")
  )
  wlv_catalog_test_write(
    file.path(root, "config", "outputs", "profiles.csv"),
    data.frame(profile = "demo_standard", source = "demo_source")
  )
  wlv_catalog_test_write(
    file.path(root, "config", "outputs", "overrides.csv"),
    data.frame(
      profile = "demo_standard",
      position = "1",
      indicator = "demo.value"
    )
  )
  wlv_catalog_test_write(
    file.path(root, "config", "outputs", "sources", "demo_source.csv"),
    data.frame(indicator = "demo.value")
  )
  writeLines(
    "# Demonstration method test",
    file.path(root, "tests", "testthat", "test-demo.R")
  )

  root
}

wlv_catalog_test_edit <- function(root, file, edit) {
  path <- file.path(root, "catalog", file)
  value <- utils::read.csv2(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
  value <- edit(value)
  wlv_catalog_test_write(path, value)
}

test_that("repository catalog classifies every method and source explicitly", {
  catalog <- catalog_environment$wlv_load_catalog(wlv_test_root)

  expect_s3_class(catalog, "wlv_catalog")
  expect_equal(nrow(catalog$methods), 17L)
  expect_equal(sum(catalog$methods$status == "stable"), 2L)
  expect_equal(sum(catalog$methods$status == "experimental"), 10L)
  expect_equal(sum(catalog$methods$status == "disabled"), 5L)
  expect_setequal(
    catalog$methods$method[catalog$methods$status == "stable"],
    c("wiodr13", "wiodr16")
  )
  expect_false(any(
    catalog$methods$can_calculate[catalog$methods$status == "disabled"]
  ))
  expect_false(any(
    catalog$methods$can_recalculate[catalog$methods$status == "disabled"]
  ))

  expect_equal(nrow(catalog$sources), 7L)
  expect_setequal(
    catalog$sources$source[catalog$sources$status == "stable"],
    c("wiodr13", "wiodr16")
  )
  exiobase395 <- catalog_environment$wlv_catalog_source(
    catalog,
    "exiobase395"
  )
  expect_identical(exiobase395$parameter_set, "exiobase")
  expect_identical(exiobase395$data_dir, "source_data/exiobase395")
  expect_equal(nrow(catalog$missingness_policies), 2L)
  expect_setequal(
    catalog$sources$missingness_policy[catalog$sources$status == "stable"],
    c("wiodr13_v1", "wiodr16_v1")
  )
  expect_equal(nrow(catalog$unit_contracts), 4L)
  expect_setequal(
    catalog$sources$unit_contract[catalog$sources$status == "stable"],
    c("wiodr13_units_v2", "wiodr16_units_v2")
  )
})

test_that("catalog accepts version 2 unit contracts", {
  root <- wlv_make_catalog_fixture()
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_catalog_test_edit(root, "unit-contracts.csv", function(value) {
    value$schema_version <- "2"
    value
  })

  catalog <- expect_no_error(catalog_environment$wlv_load_catalog(root))
  expect_identical(catalog$unit_contracts$schema_version, "2")
})

test_that("catalog accessors and output formats are deterministic", {
  catalog <- catalog_environment$wlv_load_catalog(wlv_test_root)
  methods <- catalog_environment$wlv_catalog_method_table(catalog)

  expect_identical(
    names(methods),
    c(
      "method", "code", "description", "source", "status", "source_status",
      "missingness_policy", "unit_contract", "year_start", "year_end", "years",
      "can_prepare", "can_calculate", "can_recalculate", "test",
      "documentation", "limitations"
    )
  )
  expect_identical(methods$years[methods$method == "wiodr13"], "1995-2009")
  expect_identical(methods$years[methods$method == "wiodr16"], "2000-2014")
  expect_true(methods$can_prepare[methods$method == "alternative_1"])
  expect_false(methods$can_prepare[methods$method == "exiobase395"])

  method <- catalog_environment$wlv_catalog_method(catalog, "wiodr13")
  expect_identical(method$code, "WIOD13")
  policy <- catalog_environment$wlv_catalog_missingness_policy(
    catalog,
    "wiodr13_v1"
  )
  expect_identical(policy$factory, "wlv_wiodr13_missingness_policy")
  unit_contract <- catalog_environment$wlv_catalog_unit_contract(
    catalog,
    "wiodr13_units_v2"
  )
  expect_identical(unit_contract$metadata$source, "wiodr13")
  expect_equal(nrow(unit_contract$units), 58L)
  expect_equal(nrow(unit_contract$aggregations), 116L)
  artifacts <- catalog_environment$wlv_catalog_artifacts(
    catalog,
    "wiod_core",
    "prepare"
  )
  expect_setequal(
    artifacts$artifact,
    c(
      "normalized/m_io*.fst", "normalized/sea.fst",
      "normalized/countries.csv", "normalized/sectors.csv",
      "normalized/demand.csv", "normalized/_source_manifest.csv"
    )
  )
  expect_true(all(
    artifacts$operations == "prepare|calculate|recalculate"
  ))
  expect_identical(methods$method, sort(methods$method))

  names_output <- catalog_environment$wlv_format_catalog_table(catalog, "names")
  expect_identical(strsplit(names_output, "\n", fixed = TRUE)[[1L]], methods$method)
  table_output <- catalog_environment$wlv_format_catalog_table(catalog, "table")
  expect_match(table_output, "METHOD\\s+SOURCE\\s+STATUS")
  expect_match(table_output, "exiobase395\\s+exiobase395\\s+disabled")
  csv_output <- catalog_environment$wlv_format_catalog_table(catalog, "csv")
  parsed <- utils::read.csv2(
    text = csv_output,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  expect_identical(parsed$method, methods$method)

  expect_error(
    catalog_environment$wlv_catalog_method(catalog, "missing"),
    "Unknown method"
  )
  expect_error(
    catalog_environment$wlv_catalog_artifacts(catalog, "wiod_core", "publish"),
    "operation"
  )
  expect_error(
    catalog_environment$wlv_catalog_missingness_policy(catalog, "missing"),
    "Unknown missingness policy"
  )
  expect_error(
    catalog_environment$wlv_catalog_unit_contract(catalog, "missing"),
    "Unknown unit contract"
  )
})

test_that("catalog schema rejects invalid enums, booleans, years, and paths", {
  cases <- list(
    list(
      file = "sources.csv",
      edit = function(value) {
        value$status[[1L]] <- "beta"
        value
      },
      message = "invalid `status`"
    ),
    list(
      file = "sources.csv",
      edit = function(value) {
        value$can_prepare[[1L]] <- "true"
        value
      },
      message = "can_prepare"
    ),
    list(
      file = "sources.csv",
      edit = function(value) {
        value$status[[1L]] <- "disabled"
        value$limitations[[1L]] <- "Temporarily disabled."
        value
      },
      message = "Disabled source.*preparation capability"
    ),
    list(
      file = "sources.csv",
      edit = function(value) {
        value$year_end[[1L]] <- "1999"
        value
      },
      message = "year_start.*after"
    ),
    list(
      file = "sources.csv",
      edit = function(value) {
        value$data_dir[[1L]] <- "../outside"
        value
      },
      message = "unsafe relative path"
    ),
    list(
      file = "methods.csv",
      edit = function(value) {
        value$can_calculate[[1L]] <- "1"
        value
      },
      message = "can_calculate"
    ),
    list(
      file = "artifact-profiles.csv",
      edit = function(value) {
        value$operations[[1L]] <- "prepare|publish"
        value
      },
      message = "operations"
    ),
    list(
      file = "missingness-policies.csv",
      edit = function(value) {
        value$factory[[1L]] <- "unsafe factory"
        value
      },
      message = "invalid `factory`"
    )
  )

  for (case in cases) {
    root <- wlv_make_catalog_fixture()
    tryCatch(
      {
        wlv_catalog_test_edit(root, case$file, case$edit)
        expect_error(
          catalog_environment$wlv_load_catalog(root),
          case$message,
          info = case$file
        )
      },
      finally = unlink(root, recursive = TRUE, force = TRUE)
    )
  }
})

test_that("catalog enforces method directories and parameter-set alignment", {
  root <- wlv_make_catalog_fixture()
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  dir.create(file.path(root, "methods", "unregistered"))
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "unregistered directories: unregistered"
  )

  unlink(file.path(root, "methods", "unregistered"), recursive = TRUE)
  dir.create(file.path(root, "parameters", "orphan"))
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "absent from the sources catalog: orphan",
    fixed = TRUE
  )
  unlink(file.path(root, "parameters", "orphan"), recursive = TRUE)
  parameters <- utils::read.csv2(
    file.path(root, "methods", "demo", "_parameters.csv"),
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
  parameters$source <- "different_parameter_set"
  wlv_catalog_test_write(
    file.path(root, "methods", "demo", "_parameters.csv"),
    parameters
  )
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "must declare source parameter set `raw_demo`"
  )
})

test_that("catalog and legacy method labels cannot drift", {
  root <- wlv_make_catalog_fixture()
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_catalog_test_edit(root, "methods.csv", function(value) {
    value$code <- "OTHER"
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "code must match catalog code `OTHER`"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "methods.csv", function(value) {
    value$description <- "Different display name"
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "name must match catalog description"
  )
})

test_that("catalog enforces foreign keys and uniqueness", {
  root <- wlv_make_catalog_fixture()
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_catalog_test_edit(root, "methods.csv", function(value) {
    value$source <- "unknown_source"
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "unknown source"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "artifact-profiles.csv", function(value) {
    value$artifact[[2L]] <- value$artifact[[1L]]
    value$kind[[2L]] <- value$kind[[1L]]
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "duplicate `profile/artifact`"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "sources.csv", function(value) {
    value$missingness_policy <- "unknown_policy"
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "unknown missingness policy"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "sources.csv", function(value) {
    value$unit_contract <- "unknown_units"
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "unknown unit contract"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "unit-contracts.csv", function(value) {
    value$source <- "unknown_source"
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "unit contracts catalog refers to unknown source"
  )
})

test_that("calculation capabilities require a source artifact profile", {
  root <- wlv_make_catalog_fixture()
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_catalog_test_edit(root, "sources.csv", function(value) {
    value$status <- "experimental"
    value$artifact_profile <- ""
    value$limitations <- "Runtime artifact contract is pending."
    value
  })
  wlv_catalog_test_edit(root, "methods.csv", function(value) {
    value$status <- "experimental"
    value$test <- ""
    value$documentation <- ""
    value$limitations <- "Runtime artifact contract is pending."
    value
  })

  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "calculation capabilities require a source artifact profile"
  )
})

test_that("artifact profiles cover every declared source operation", {
  root <- wlv_make_catalog_fixture()
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_catalog_test_edit(root, "artifact-profiles.csv", function(value) {
    value$operations <- "prepare|calculate"
    value
  })

  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "lacks required operation(s): recalculate",
    fixed = TRUE
  )
})

test_that("stable entries require complete and existing contracts", {
  root <- wlv_make_catalog_fixture()
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_catalog_test_edit(root, "sources.csv", function(value) {
    value$documentation <- ""
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "Stable source.*documentation"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "sources.csv", function(value) {
    value$missingness_policy <- ""
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "Stable source.*missingness and unit contracts"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "sources.csv", function(value) {
    value$unit_contract <- ""
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "Stable source.*unit contracts"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "methods.csv", function(value) {
    value$test <- ""
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "Stable method.*a test"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "methods.csv", function(value) {
    value$test <- "tests/testthat/missing.R"
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "declares missing `test`"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "sources.csv", function(value) {
    value$validator_function <- "wlv_missing_validator"
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "Validator `wlv_missing_validator` is not defined"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "missingness-policies.csv", function(value) {
    value$factory <- "wlv_missing_policy_factory"
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "Missingness policy factory `wlv_missing_policy_factory` is not defined"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "sources.csv", function(value) {
    value$documentation <- "docs/missing.md"
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "declares missing `documentation`"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "sources.csv", function(value) {
    value$status <- "experimental"
    value$limitations <- "Validation is pending."
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "Stable method.*stable source"
  )
})

test_that("disabled and non-stable entries expose their limitations", {
  root <- wlv_make_catalog_fixture()
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_catalog_test_edit(root, "methods.csv", function(value) {
    value$status <- "disabled"
    value$can_calculate <- "TRUE"
    value$documentation <- ""
    value$limitations <- "Temporarily disabled."
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "Disabled method.*capabilities"
  )

  unlink(root, recursive = TRUE, force = TRUE)
  root <- wlv_make_catalog_fixture()
  wlv_catalog_test_edit(root, "methods.csv", function(value) {
    value$status <- "experimental"
    value$documentation <- ""
    value$limitations <- ""
    value
  })
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "Non-stable method.*limitations"
  )
})

test_that("stable unit contracts have deterministic exact coverage", {
  catalog <- catalog_environment$wlv_load_catalog(wlv_test_root)
  expected <- c(
    wiodr13_units_v1 = 58L,
    wiodr13_units_v2 = 58L,
    wiodr16_units_v1 = 50L,
    wiodr16_units_v2 = 50L
  )

  for (contract in names(expected)) {
    value <- catalog_environment$wlv_catalog_unit_contract(catalog, contract)
    expect_equal(nrow(value$units), expected[[contract]])
    expect_equal(nrow(value$aggregations), 2L * expected[[contract]])
    expect_setequal(unique(value$aggregations$indicator), value$units$indicator)
    expect_true(all(table(value$aggregations$indicator) == 2L))

    first <- catalog_environment$wlv_catalog_unit_contract_sidecar(
      catalog,
      contract,
      value$units$indicator
    )
    second <- catalog_environment$wlv_catalog_unit_contract_sidecar(
      catalog,
      contract,
      value$units$indicator
    )
    expect_identical(first, second)
    expect_equal(nrow(first), 2L * expected[[contract]])
    expect_identical(
      unique(first$indicator),
      value$units$indicator
    )
    expect_identical(
      first$level[seq.int(1L, nrow(first), by = 2L)],
      rep("sector_to_country", expected[[contract]])
    )
  }
})

test_that("unit sidecars overlay resolved aggregation rows deterministically", {
  catalog <- catalog_environment$wlv_load_catalog(wlv_test_root)
  contract <- catalog_environment$wlv_catalog_unit_contract(
    catalog,
    "wiodr13_units_v1"
  )
  resolved <- contract$aggregations
  resolved$notes <- paste0("resolved:", seq_len(nrow(resolved)))
  sidecar <- catalog_environment$wlv_catalog_unit_contract_sidecar(
    catalog,
    "wiodr13_units_v1",
    indicators = contract$units$indicator,
    resolved_aggregations = resolved
  )
  expect_identical(sidecar$aggregation_notes, resolved$notes)
  expect_identical(sidecar$strategy, resolved$strategy)

  extra <- resolved[seq_len(2L), , drop = FALSE]
  extra$indicator <- "experimental.extra"
  expect_error(
    catalog_environment$wlv_catalog_unit_contract_sidecar(
      catalog,
      "wiodr13_units_v1",
      indicators = c(contract$units$indicator, "experimental.extra"),
      resolved_aggregations = rbind(resolved, extra)
    ),
    "does not exactly match",
    fixed = TRUE
  )
})

test_that("stable typed aggregation is independent from retired routing fragments", {
  root <- wlv_make_catalog_fixture()
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(
    root,
    "contracts",
    "units",
    "demo_v1-aggregations.csv"
  )
  aggregations <- utils::read.csv2(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
  aggregations$strategy <- "invariant"
  wlv_catalog_test_write(path, aggregations)

  catalog <- expect_no_error(catalog_environment$wlv_load_catalog(root))
  contract <- catalog_environment$wlv_catalog_unit_contract(
    catalog,
    "demo_units_v1"
  )
  expect_true(all(contract$aggregations$strategy == "invariant"))
})

test_that("constant compensation is declared in additive 2000 USD", {
  catalog <- catalog_environment$wlv_load_catalog(wlv_test_root)
  indicators <- c("compensation.emp.s.cu", "compensation.empe.s.cu")

  for (contract in c("wiodr13_units_v1", "wiodr16_units_v1")) {
    units <- catalog_environment$wlv_catalog_unit_contract(catalog, contract)$units
    selected <- units[match(indicators, units$indicator), , drop = FALSE]
    expect_identical(selected$source_unit, rep("usd", 2L))
    expect_identical(selected$canonical_unit, rep("usd", 2L))
    expect_identical(selected$currency, rep("usd", 2L))
    expect_identical(selected$price_basis, rep("constant", 2L))
    expect_identical(selected$base_year, rep("2000", 2L))
  }
})

test_that("scientific profile declarations are immutable catalog inputs", {
  catalog <- catalog_environment$wlv_load_catalog(wlv_test_root)
  inventory <- attr(catalog, "wlv_catalog_input_inventory", exact = TRUE)
  expect_true(all(c(
    "config/contracts/scientific_method_profiles.csv",
    "config/contracts/scientific_profiles.csv",
    "config/contracts/leontief_zero_profiles.csv",
    "config/contracts/leontief_signed_profiles.csv",
    "config/contracts/nonfinite_resolution_profiles.csv",
    "config/contracts/nonfinite_resolution_groups.csv"
  ) %in% names(inventory)))
})

test_that("unit contract schemas and foreign keys reject drift", {
  cases <- list(
    list(
      path = file.path("contracts", "units", "demo_v1-units.csv"),
      edit = function(value) {
        value$source_scale <- "0"
        value
      },
      message = "positive `source_scale`"
    ),
    list(
      path = file.path("contracts", "units", "demo_v1-aggregations.csv"),
      edit = function(value) value[-2L, , drop = FALSE],
      message = "both aggregation levels"
    ),
    list(
      path = file.path("contracts", "units", "demo_v1-aggregations.csv"),
      edit = function(value) {
        value$indicator[[1L]] <- "unknown.value"
        value
      },
      message = "absent from its unit definitions"
    )
  )

  for (case in cases) {
    root <- wlv_make_catalog_fixture()
    tryCatch(
      {
        path <- file.path(root, case$path)
        value <- utils::read.csv2(
          path,
          stringsAsFactors = FALSE,
          colClasses = "character",
          check.names = FALSE,
          na.strings = NULL
        )
        wlv_catalog_test_write(path, case$edit(value))
        expect_error(
          catalog_environment$wlv_load_catalog(root),
          case$message,
          info = case$path
        )
      },
      finally = unlink(root, recursive = TRUE, force = TRUE)
    )
  }

  root <- wlv_make_catalog_fixture()
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  unit_path <- file.path(root, "contracts", "units", "demo_v1-units.csv")
  units <- utils::read.csv2(
    unit_path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
  units$indicator <- "renamed.value"
  wlv_catalog_test_write(unit_path, units)
  aggregation_path <- file.path(
    root,
    "contracts",
    "units",
    "demo_v1-aggregations.csv"
  )
  aggregations <- utils::read.csv2(
    aggregation_path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
  aggregations$indicator <- "renamed.value"
  wlv_catalog_test_write(aggregation_path, aggregations)
  expect_error(
    catalog_environment$wlv_load_catalog(root),
    "does not exactly cover stable method"
  )
})
