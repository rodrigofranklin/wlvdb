preflight_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "catalog.R"),
  envir = preflight_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "gfcf_contracts.R"),
  envir = preflight_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "wiodr13_validation.R"),
  envir = preflight_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "wiodr16_allocation.R"),
  envir = preflight_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "wiodr16_validation.R"),
  envir = preflight_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "source_manifest.R"),
  envir = preflight_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "unit_dimensions.R"),
  envir = preflight_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "aggregation_specs.R"),
  envir = preflight_environment
)
sys.source(
  file.path(wlv_test_root, "R", "lib", "execution.R"),
  envir = preflight_environment
)

wlv_touch_with_metadata <- function(path, years = "2000") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  file.create(path)
  saveRDS(
    list(
      dim = c(length(years), 1L, 1L),
      as.character(years),
      "row",
      "column"
    ),
    paste0(path, ".meta")
  )
  invisible(path)
}

wlv_make_preflight_fixture <- function(
    method_status = "experimental",
    can_calculate = TRUE,
    can_recalculate = TRUE) {
  root <- tempfile("wlv-preflight-")
  method <- "demo"
  source <- "fixture_source"

  dir.create(file.path(root, "catalog"), recursive = TRUE)
  dir.create(file.path(root, "methods", method), recursive = TRUE)
  dir.create(file.path(root, "R", "utils", "papers"), recursive = TRUE)
  dir.create(file.path(root, "R", "lib"), recursive = TRUE)
  dir.create(file.path(root, "docs"), recursive = TRUE)
  dir.create(file.path(root, "parameters", source), recursive = TRUE)
  dir.create(file.path(root, "parameters", "common_ground"), recursive = TRUE)
  dir.create(file.path(root, "R", "modules", "assumptions"), recursive = TRUE)
  dir.create(file.path(root, "R", "modules", "matrices"), recursive = TRUE)
  dir.create(file.path(root, "R", "modules", "reduced_matrices"), recursive = TRUE)
  dir.create(file.path(root, "R", "modules", "variables", "fixture"), recursive = TRUE)
  dir.create(file.path(root, "source_data", source), recursive = TRUE)
  dir.create(file.path(root, "results", method), recursive = TRUE)

  writeLines(
    c(
      "source;code;name;description",
      paste(source, "demo", "Fixture method", "", sep = ";")
    ),
    file.path(root, "methods", method, "_parameters.csv")
  )
  writeLines(
    c("sector;include", "fixture;1"),
    file.path(root, "methods", method, "_sectors.csv")
  )
  writeLines(
    "invisible(NULL)",
    file.path(root, "R", "utils", paste0("prepare_", source, "_data.R"))
  )
  writeLines(
    "invisible(NULL)",
    file.path(root, "R", "utils", "papers", "paper_0_selection.R")
  )

  sources_catalog <- data.frame(
    source = source,
    status = "experimental",
    year_start = "2000",
    year_end = "2000",
    parameter_set = source,
    data_dir = paste("source_data", source, sep = "/"),
    can_prepare = "TRUE",
    preparer = paste("R", "utils", paste0("prepare_", source, "_data.R"), sep = "/"),
    validator_script = "",
    validator_function = "",
    artifact_profile = "fixture_core",
    missingness_policy = "fixture_v1",
    unit_contract = "fixture_units_v1",
    documentation = "",
    limitations = "Synthetic source used only by preflight tests.",
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  methods_catalog <- data.frame(
    method = method,
    source = source,
    code = "demo",
    description = "Fixture method",
    status = method_status,
    can_calculate = if (can_calculate) "TRUE" else "FALSE",
    can_recalculate = if (can_recalculate) "TRUE" else "FALSE",
    test = "",
    documentation = "",
    limitations = "Synthetic method used only by preflight tests.",
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  artifacts_catalog <- data.frame(
    profile = rep("fixture_core", 5L),
    artifact = c(
      "normalized/m_io*.fst", "normalized/sea.fst",
      "normalized/countries.csv", "normalized/demand.csv",
      "normalized/_source_manifest.csv"
    ),
    kind = c("fst_array_glob", "fst_array", "csv", "csv", "csv"),
    sidecar = c("TRUE", "TRUE", "FALSE", "FALSE", "FALSE"),
    operations = rep("prepare|calculate|recalculate", 5L),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  missingness_policies_catalog <- data.frame(
    policy = "fixture_v1",
    script = "R/lib/fixture_missingness.R",
    factory = "wlv_fixture_missingness_policy",
    documentation = "docs/fixture-missingness.md",
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  unit_contracts_catalog <- data.frame(
    contract = "fixture_units_v1",
    schema_version = "1",
    source = source,
    units = "contracts/units/fixture_v1-units.csv",
    aggregations = "contracts/units/fixture_v1-aggregations.csv",
    documentation = "docs/fixture-units.md",
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  catalogs <- list(
    sources = sources_catalog,
    methods = methods_catalog,
    `artifact-profiles` = artifacts_catalog,
    `missingness-policies` = missingness_policies_catalog,
    `unit-contracts` = unit_contracts_catalog
  )
  for (name in names(catalogs)) {
    utils::write.table(
      catalogs[[name]],
      file.path(root, "catalog", paste0(name, ".csv")),
      sep = ";",
      row.names = FALSE,
      col.names = TRUE,
      quote = FALSE
    )
  }

  writeLines(
    "wlv_fixture_missingness_policy <- function(...) list(policy_id = 'fixture_v1')",
    file.path(root, "R", "lib", "fixture_missingness.R")
  )
  writeLines(
    "# Fixture missingness policy",
    file.path(root, "docs", "fixture-missingness.md")
  )
  writeLines(
    "# Fixture unit contract",
    file.path(root, "docs", "fixture-units.md")
  )
  unit_definitions <- data.frame(
    indicator = "fixture_value",
    quantity_kind = "monetary",
    source_unit = "usd",
    source_scale = "1",
    canonical_unit = "usd",
    currency = "usd",
    price_basis = "current",
    base_year = "",
    index_base = "",
    labour_concept = "not_applicable",
    notes = "",
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  unit_aggregations <- data.frame(
    indicator = rep("fixture_value", 2L),
    level = c("sector_to_country", "country_to_world"),
    strategy = rep("formula", 2L),
    module = rep("fixture/country.R", 2L),
    numerator = "",
    denominator = "",
    weight = "",
    zero_denominator = "",
    notes = "",
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  dir.create(file.path(root, "contracts", "units"), recursive = TRUE)
  utils::write.table(
    unit_definitions,
    file.path(root, "contracts", "units", "fixture_v1-units.csv"),
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )
  utils::write.table(
    unit_aggregations,
    file.path(root, "contracts", "units", "fixture_v1-aggregations.csv"),
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )

  writeLines(
    c("names;computation;order", "fixture_assumption;fixture-assumption.R;1"),
    file.path(root, "parameters", source, "_source_assumptions.csv")
  )
  writeLines(
    c("names;computation;order", "fixture_matrix;fixture-matrix.R;1"),
    file.path(root, "parameters", source, "_source_matrices.csv")
  )
  writeLines(
    c(
      "names;sector_solution;country_solution;stage;order",
      "fixture_value;fixture/sector.R;fixture/country.R;1;1"
    ),
    file.path(root, "parameters", source, "_source_solutions.csv")
  )
  writeLines(
    c("names;computation;order", "fixture_matrix;missing-placeholder;1"),
    file.path(root, "parameters", "common_ground", "_common_matrices.csv")
  )
  writeLines(
    c("names;computation", "fixture_reduced;fixture-reduced.R"),
    file.path(root, "parameters", "common_ground", "_common_reduced_matrices.csv")
  )
  for (script in c(
    file.path(root, "R", "modules", "assumptions", "fixture-assumption.R"),
    file.path(root, "R", "modules", "matrices", "fixture-matrix.R"),
    file.path(root, "R", "modules", "reduced_matrices", "fixture-reduced.R"),
    file.path(root, "R", "modules", "variables", "fixture", "sector.R"),
    file.path(root, "R", "modules", "variables", "fixture", "country.R")
  )) {
    writeLines("invisible(NULL)", script)
  }

  source_path <- file.path(root, "source_data", source, "normalized")
  dir.create(source_path, recursive = TRUE, showWarnings = FALSE)
  writeLines("country", file.path(source_path, "countries.csv"))
  writeLines("demand", file.path(source_path, "demand.csv"))
  wlv_touch_with_metadata(file.path(source_path, "sea.fst"))
  wlv_touch_with_metadata(file.path(source_path, "m_io-source.fst"))
  source_manifest <- preflight_environment$wlv_build_source_manifest(
    source_root = source_path,
    artifacts = c(
      "countries.csv", "demand.csv", "m_io-source.fst",
      "m_io-source.fst.meta", "sea.fst", "sea.fst.meta"
    ),
    artifact_roles = c(
      "label", "label", "input_output", "array_metadata",
      "socioeconomic", "array_metadata"
    ),
    contract_path = file.path(
      root,
      "contracts",
      "units",
      c("fixture_v1-units.csv", "fixture_v1-aggregations.csv")
    ),
    contract_id = "fixture_units_v1",
    contract_version = "1"
  )
  preflight_environment$wlv_write_source_manifest(
    source_manifest,
    file.path(source_path, "_source_manifest.csv")
  )

  results_path <- file.path(root, "results", method)
  wlv_touch_with_metadata(file.path(results_path, "m_countries.fst"))
  wlv_touch_with_metadata(file.path(results_path, "sea_sectors.fst"))
  wlv_touch_with_metadata(file.path(results_path, "m_io-result.fst"))
  preflight_environment$wlv_write_result_source_provenance(
    results_path,
    source = source,
    manifest = source_manifest
  )

  list(
    root = root,
    method = method,
    source = source,
    source_path = source_path,
    results_path = results_path,
    methods_catalog = file.path(root, "catalog", "methods.csv")
  )
}

wlv_fixture_request <- function(
    fixture,
    mode = "calculate",
    allow_experimental = TRUE,
    ...) {
  preflight_environment$wlv_validate_request(
    methods = fixture$method,
    mode = mode,
    root = fixture$root,
    allow_experimental = allow_experimental,
    ...
  )
}

wlv_refresh_preflight_manifest <- function(fixture) {
  manifest_path <- file.path(fixture$source_path, "_source_manifest.csv")
  previous <- preflight_environment$wlv_read_source_manifest(manifest_path)
  refreshed <- preflight_environment$wlv_build_source_manifest(
    source_root = fixture$source_path,
    artifacts = previous$artifact,
    artifact_roles = previous$artifact_role,
    contract_path = file.path(
      fixture$root,
      "contracts",
      "units",
      c("fixture_v1-units.csv", "fixture_v1-aggregations.csv")
    ),
    contract_id = "fixture_units_v1",
    contract_version = "1"
  )
  preflight_environment$wlv_write_source_manifest(refreshed, manifest_path)
  invisible(refreshed)
}

test_that("request validation rejects unknown methods and traversal", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  for (method in c("missing", "../demo", "demo/../../outside")) {
    expect_error(
      preflight_environment$wlv_validate_request(
        methods = method,
        root = fixture$root
      ),
      "[Mm]ethod"
    )
  }
})

test_that("experimental methods require an explicit opt-in", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_error(
    wlv_fixture_request(fixture, allow_experimental = FALSE),
    "experimental",
    fixed = TRUE
  )
  expect_s3_class(
    wlv_fixture_request(fixture, allow_experimental = TRUE),
    "wlv_run_plan"
  )
})

test_that("stage-1 recalculation cannot select a partial indicator set", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_error(
    wlv_fixture_request(
      fixture,
      mode = "recalculate",
      at_stage = 1L,
      sea_vars = "emp.s.un"
    ),
    "unsafe at stage 1",
    fixed = TRUE
  )
  expect_no_error(wlv_fixture_request(
    fixture,
    mode = "recalculate",
    at_stage = 1L,
    sea_vars = NULL
  ))
})

test_that("recalculation rejects checkpoints that are not implemented", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  for (stage in c(2L, 3L)) {
    expect_error(
      wlv_fixture_request(
        fixture,
        mode = "recalculate",
        at_stage = stage
      ),
      "implemented checkpoints: 1, 4, or 5",
      fixed = TRUE,
      info = paste("stage", stage)
    )
  }
})

test_that("disabled methods remain blocked with experimental opt-in", {
  fixture <- wlv_make_preflight_fixture(
    method_status = "disabled",
    can_calculate = FALSE,
    can_recalculate = FALSE
  )
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  for (allow_experimental in c(FALSE, TRUE)) {
    expect_error(
      wlv_fixture_request(
        fixture,
        allow_experimental = allow_experimental
      ),
      "disabled",
      fixed = TRUE
    )
  }
})

test_that("disabled sources remain blocked with experimental opt-in", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  sources_path <- file.path(fixture$root, "catalog", "sources.csv")
  sources <- utils::read.csv2(
    sources_path,
    stringsAsFactors = FALSE,
    colClasses = "character"
  )
  sources$status <- "disabled"
  sources$can_prepare <- "FALSE"
  sources$preparer <- ""
  utils::write.table(
    sources,
    sources_path,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )

  expect_error(
    wlv_fixture_request(fixture, allow_experimental = TRUE),
    "Source `fixture_source` used by method `demo` is disabled.",
    fixed = TRUE
  )
})

test_that("catalog capabilities are enforced before method validation", {
  fixture <- wlv_make_preflight_fixture(can_calculate = FALSE)
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_error(
    wlv_fixture_request(fixture),
    "does not support operation(s): calculate",
    fixed = TRUE
  )
  expect_s3_class(
    wlv_fixture_request(
      fixture,
      repeat_pp = TRUE,
      requested_operations = "prepare"
    ),
    "wlv_run_plan"
  )
})

test_that("a blocked batch aborts before running any preparer", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  blocked <- "blocked"
  dir.create(file.path(fixture$root, "methods", blocked))
  file.copy(
    file.path(fixture$root, "methods", fixture$method, c("_parameters.csv", "_sectors.csv")),
    file.path(fixture$root, "methods", blocked),
    overwrite = TRUE
  )
  writeLines(
    c(
      "source;code;name;description",
      paste(fixture$source, "BLOCKED", "Fixture method", "", sep = ";")
    ),
    file.path(fixture$root, "methods", blocked, "_parameters.csv")
  )
  methods <- utils::read.csv2(
    fixture$methods_catalog,
    stringsAsFactors = FALSE,
    colClasses = "character"
  )
  blocked_method <- methods[1L, , drop = FALSE]
  blocked_method$method <- blocked
  blocked_method$code <- "BLOCKED"
  blocked_method$status <- "disabled"
  blocked_method$can_calculate <- "FALSE"
  blocked_method$can_recalculate <- "FALSE"
  blocked_method$limitations <- "Deliberately blocked by the integration test."
  utils::write.table(
    rbind(methods, blocked_method),
    fixture$methods_catalog,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )

  marker <- file.path(fixture$root, "preparer-ran")
  writeLines(
    "file.create(file.path(getwd(), 'preparer-ran'))",
    file.path(
      fixture$root,
      "R",
      "utils",
      paste0("prepare_", fixture$source, "_data.R")
    )
  )

  expect_error({
    plan <- preflight_environment$wlv_validate_request(
      methods = c(fixture$method, blocked),
      repeat_pp = TRUE,
      root = fixture$root,
      allow_experimental = TRUE
    )
    preflight_environment$wlv_prepare_sources(plan)
  }, "disabled", fixed = TRUE)
  expect_false(file.exists(marker))
})

test_that("request validation checks the selected data preparer", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  unlink(file.path(
    fixture$root,
    "R",
    "utils",
    paste0("prepare_", fixture$source, "_data.R")
  ))

  expect_error(
    wlv_fixture_request(fixture, repeat_pp = TRUE),
    "[Pp]repar"
  )
})

test_that("request validation checks an explicitly selected paper", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  expect_error(
    wlv_fixture_request(fixture, prepaper = TRUE, papern = 99L),
    "[Pp]aper"
  )
})

test_that("request validation resolves overrides before checking modules", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  plan <- wlv_fixture_request(fixture)
  expect_identical(
    plan$configuration[[fixture$method]]$matrices$computation,
    "fixture-matrix.R"
  )

  unlink(file.path(fixture$root, "R", "modules", "matrices", "fixture-matrix.R"))
  expect_error(wlv_fixture_request(fixture), "fixture-matrix\\.R")
})

test_that("source validators are loaded from the catalog in isolation", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  validator_path <- file.path(fixture$root, "R", "lib", "fixture_validation.R")
  dir.create(dirname(validator_path), recursive = TRUE, showWarnings = FALSE)
  writeLines(
    paste(
      "wlv_validate_fixture_prepared <- function(source_dir)",
      "list(sectors = 'fixture')"
    ),
    validator_path
  )
  sources_path <- file.path(fixture$root, "catalog", "sources.csv")
  sources <- utils::read.csv2(
    sources_path,
    stringsAsFactors = FALSE,
    colClasses = "character"
  )
  sources$validator_script <- "R/lib/fixture_validation.R"
  sources$validator_function <- "wlv_validate_fixture_prepared"
  utils::write.table(
    sources,
    sources_path,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )
  writeLines(
    c("sector.source;sector", "fixture;Fixture sector"),
    file.path(fixture$root, "methods", fixture$method, "_sectors.csv")
  )

  plan <- wlv_fixture_request(fixture)
  expect_s3_class(preflight_environment$wlv_validate_data(plan), "wlv_run_plan")
  expect_false(exists(
    "wlv_validate_fixture_prepared",
    envir = preflight_environment,
    inherits = FALSE
  ))
})

test_that("missing input data fails before cluster creation", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  unlink(file.path(fixture$source_path, "demand.csv"))
  starts <- 0L

  expect_error({
    plan <- wlv_fixture_request(fixture)
    plan <- preflight_environment$wlv_validate_data(plan)
    preflight_environment$wlv_with_cluster(
      workers = 2L,
      run = function(cluster) invisible(NULL),
      make_cluster = function(workers) {
        starts <<- starts + 1L
        structure(list(), class = "wlv_test_cluster")
      }
    )
  }, "[Mm]issing|[Aa]usente|demand\\.csv")

  expect_identical(starts, 0L)
})

test_that("artifact validation covers every requested operation", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  artifacts_path <- file.path(
    fixture$root,
    "catalog",
    "artifact-profiles.csv"
  )
  artifacts <- utils::read.csv2(
    artifacts_path,
    stringsAsFactors = FALSE,
    colClasses = "character"
  )
  artifacts$operations[
    artifacts$artifact == "normalized/demand.csv"
  ] <- "prepare"
  utils::write.table(
    artifacts,
    artifacts_path,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE
  )

  plan <- wlv_fixture_request(fixture, repeat_pp = TRUE)
  unlink(file.path(fixture$source_path, "demand.csv"))
  expect_error(
    preflight_environment$wlv_validate_data(plan),
    "demand.csv",
    fixed = TRUE
  )
})

test_that("WIOD13 scientific validation fails before cluster creation", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  starts <- 0L
  validations <- 0L

  writeLines(
    c("sector.source;sector", "fixture;Fixture sector"),
    file.path(fixture$root, "methods", fixture$method, "_sectors.csv")
  )
  plan <- wlv_fixture_request(fixture)
  plan$methods$source <- "wiodr13"

  expect_error({
    plan <- preflight_environment$wlv_validate_data(
      plan,
      wiodr13_validator = function(source_dir) {
        validations <<- validations + 1L
        stop("scientific validation sentinel", call. = FALSE)
      }
    )
    preflight_environment$wlv_with_cluster(
      workers = 2L,
      run = function(cluster) invisible(NULL),
      make_cluster = function(workers) {
        starts <<- starts + 1L
        structure(list(), class = "wlv_test_cluster")
      }
    )
  }, "scientific validation sentinel", fixed = TRUE)

  expect_identical(validations, 1L)
  expect_identical(starts, 0L)
})

test_that("WIOD13 source sector labels must match the selected method", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  writeLines(
    c("sector.source;sector", "method_sector;Fixture sector"),
    file.path(fixture$root, "methods", fixture$method, "_sectors.csv")
  )
  plan <- wlv_fixture_request(fixture)
  plan$methods$source <- "wiodr13"

  expect_error(
    preflight_environment$wlv_validate_data(
      plan,
      wiodr13_validator = function(source_dir) list(sectors = "source_sector")
    ),
    "source sectors do not match method",
    fixed = TRUE
  )
})

test_that("WIOD16 scientific validation and sector matching happen before execution", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  validations <- 0L

  writeLines(
    c("sector.source;sector", "fixture;Fixture sector"),
    file.path(fixture$root, "methods", fixture$method, "_sectors.csv")
  )
  plan <- wlv_fixture_request(fixture)
  plan$methods$source <- "wiodr16"

  validated <- preflight_environment$wlv_validate_data(
    plan,
    wiodr16_validator = function(source_dir) {
      validations <<- validations + 1L
      list(sectors = "fixture")
    }
  )
  expect_s3_class(validated, "wlv_run_plan")
  expect_identical(validations, 1L)

  expect_error(
    preflight_environment$wlv_validate_data(
      plan,
      wiodr16_validator = function(source_dir) list(sectors = "different")
    ),
    "WIOD16 source sectors do not match method",
    fixed = TRUE
  )
})

test_that("source fst files require sidecar metadata", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  unlink(file.path(fixture$source_path, "sea.fst.meta"))

  plan <- wlv_fixture_request(fixture)
  expect_error(
    preflight_environment$wlv_validate_data(plan),
    "[Mm]eta|sea\\.fst\\.meta"
  )
})

test_that("input-output globs cannot admit files outside the source manifest", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  wlv_touch_with_metadata(file.path(fixture$source_path, "m_io-extra.fst"))

  plan <- wlv_fixture_request(fixture)
  expect_error(
    preflight_environment$wlv_validate_data(plan),
    "absent from the generation manifest: m_io-extra.fst",
    fixed = TRUE
  )
})

test_that("source inputs are verified again immediately before publication", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  plan <- wlv_fixture_request(fixture)
  plan <- preflight_environment$wlv_validate_data(plan)
  run_data <- plan$data[[fixture$method]]

  writeLines("changed-country", file.path(fixture$source_path, "countries.csv"))
  wlv_refresh_preflight_manifest(fixture)

  expect_error(
    preflight_environment$wlv_assert_method_source_inputs_unchanged(
      plan,
      plan$methods[1L, , drop = FALSE],
      run_data
    ),
    "Source inputs changed after preflight validation",
    fixed = TRUE
  )
})

test_that("WIOD13 EUKLEMS inputs fail before cluster creation", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  starts <- 0L

  saveRDS(
    list(dim = c(2L, 1L, 1L), c("1999", "2000"), "row", "column"),
    file.path(fixture$source_path, "m_io-source.fst.meta")
  )
  wlv_refresh_preflight_manifest(fixture)

  plan <- wlv_fixture_request(fixture)
  plan$configuration[[fixture$method]]$matrices$computation <-
    "wiodr13/euklems.R"
  expected_files <- c(
    "ekk_1999.fst", "ekk_2000.fst",
    "ekdeprate_2000.fst", "ekdeprate_2001.fst"
  )
  expect_setequal(
    basename(preflight_environment$wlv_wiodr13_euklems_files(
      fixture$root,
      file.path(fixture$source_path, "m_io-source.fst"),
      "wiodr13/euklems.R"
    )),
    expected_files
  )

  expect_error({
    plan <- preflight_environment$wlv_validate_data(plan)
    preflight_environment$wlv_with_cluster(
      workers = 2L,
      run = function(cluster) invisible(NULL),
      make_cluster = function(workers) {
        starts <<- starts + 1L
        structure(list(), class = "wlv_test_cluster")
      }
    )
  }, "EUKLEMS|ekk_1999\\.fst|ekdeprate_2001\\.fst")
  expect_identical(starts, 0L)

  euklems_dir <- file.path(fixture$root, "source_data", "euklems")
  dir.create(euklems_dir, recursive = TRUE)
  file.create(file.path(euklems_dir, expected_files))
  expect_no_error(preflight_environment$wlv_validate_data(plan))

  recalculate_plan <- wlv_fixture_request(
    fixture,
    mode = "recalculate",
    at_stage = 5L
  )
  recalculate_plan$configuration[[fixture$method]]$matrices$computation <-
    "wiodr13/euklems.R"
  unlink(euklems_dir, recursive = TRUE, force = TRUE)
  expect_error(
    preflight_environment$wlv_validate_data(recalculate_plan),
    "EUKLEMS provenance|ekk_1999\\.fst"
  )
})

test_that("WIOD13 reduction inputs use same-year depreciation data", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  starts <- 0L

  saveRDS(
    list(dim = c(2L, 1L, 1L), c("1999", "2000"), "row", "column"),
    file.path(fixture$source_path, "m_io-source.fst.meta")
  )
  wlv_refresh_preflight_manifest(fixture)

  plan <- wlv_fixture_request(fixture)
  plan$configuration[[fixture$method]]$matrices$computation <-
    "wiodr13/euklems-reduction_problem.R"
  expected_files <- c(
    "ekk_1999.fst", "ekk_2000.fst",
    "ekdeprate_1999.fst", "ekdeprate_2000.fst"
  )
  expect_setequal(
    basename(preflight_environment$wlv_wiodr13_euklems_files(
      fixture$root,
      file.path(fixture$source_path, "m_io-source.fst"),
      "wiodr13/euklems-reduction_problem.R"
    )),
    expected_files
  )

  expect_error({
    plan <- preflight_environment$wlv_validate_data(plan)
    preflight_environment$wlv_with_cluster(
      workers = 2L,
      run = function(cluster) invisible(NULL),
      make_cluster = function(workers) {
        starts <<- starts + 1L
        structure(list(), class = "wlv_test_cluster")
      }
    )
  }, "EUKLEMS|ekdeprate_1999\\.fst")
  expect_identical(starts, 0L)

  euklems_dir <- file.path(fixture$root, "source_data", "euklems")
  dir.create(euklems_dir, recursive = TRUE)
  file.create(file.path(euklems_dir, expected_files))
  expect_no_error(preflight_environment$wlv_validate_data(plan))
})

test_that("WIOD16 EU KLEMS preflight requires year and year-plus-one inputs", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  saveRDS(
    list(dim = c(2L, 1L, 1L), c("2000", "2001"), "row", "column"),
    file.path(fixture$source_path, "m_io-source.fst.meta")
  )
  wlv_refresh_preflight_manifest(fixture)
  expected_files <- c(
    "ekk_2000.fst", "ekk_2001.fst",
    "ekdeprate_2001.fst", "ekdeprate_2002.fst"
  )
  expect_setequal(
    basename(preflight_environment$wlv_euklems_files(
      fixture$root,
      file.path(fixture$source_path, "m_io-source.fst"),
      "wiodr16/euklems.R"
    )),
    expected_files
  )

  plan <- wlv_fixture_request(fixture)
  plan$configuration[[fixture$method]]$matrices$computation <- "wiodr16/euklems.R"
  expect_error(
    preflight_environment$wlv_validate_data(plan),
    "EUKLEMS|ekk_2000\\.fst|ekdeprate_2002\\.fst"
  )
})

test_that("WIOD16 EU KLEMS preflight validates the files used by the method", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  writeLines(
    c(
      "sector.source;sector;euklems.capital;euklems.sector",
      "fixture;Fixture sector;K_ONE;A"
    ),
    file.path(fixture$root, "methods", fixture$method, "_sectors.csv")
  )

  plan <- wlv_fixture_request(fixture)
  plan$methods$source <- "wiodr16"
  plan$configuration[[fixture$method]]$matrices$computation <- "wiodr16/euklems.R"
  euklems_dir <- file.path(fixture$root, "source_data", "euklems")
  dir.create(euklems_dir, recursive = TRUE)
  euklems <- expand.grid(
    country = c("UK", "EL", "MD"),
    sector = "A",
    stringsAsFactors = FALSE
  )
  euklems$K_ONE <- seq_len(nrow(euklems))
  fst::write_fst(euklems, file.path(euklems_dir, "ekk_2000.fst"))
  fst::write_fst(euklems, file.path(euklems_dir, "ekdeprate_2001.fst"))

  validator <- function(source_dir) list(sectors = "fixture")
  expect_no_error(
    preflight_environment$wlv_validate_data(plan, wiodr16_validator = validator)
  )

  euklems$K_ONE[[1L]] <- Inf
  fst::write_fst(euklems, file.path(euklems_dir, "ekdeprate_2001.fst"))
  expect_error(
    preflight_environment$wlv_validate_data(plan, wiodr16_validator = validator),
    "non-finite value",
    fixed = TRUE
  )
})

test_that("recalculation result files require sidecar metadata", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)
  unlink(file.path(fixture$results_path, "sea_sectors.fst.meta"))

  plan <- wlv_fixture_request(fixture, mode = "recalculate")
  expect_error(
    preflight_environment$wlv_validate_data(plan),
    "[Mm]eta|sea_sectors\\.fst\\.meta"
  )
})

test_that("recalculation pairs source and result matrices by metadata years", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  saveRDS(
    list(dim = c(1L, 1L, 1L), "2001", "row", "column"),
    file.path(fixture$results_path, "m_io-result.fst.meta")
  )

  plan <- wlv_fixture_request(fixture, mode = "recalculate")
  expect_error(
    preflight_environment$wlv_validate_data(plan),
    "[Pp]eriod|[Yy]ear|[Cc]orrespond|2000|2001"
  )
})

test_that("stage five recalculation preserves result matrices but verifies source provenance", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  unlink(
    list.files(
      fixture$results_path,
      pattern = "^m_io.*\\.fst(\\.meta)?$",
      full.names = TRUE
    )
  )

  plan <- wlv_fixture_request(fixture, mode = "recalculate", at_stage = 5L)
  expect_no_error(preflight_environment$wlv_validate_data(plan))
})

test_that("complete calculate and recalculate fixtures pass preflight", {
  fixture <- wlv_make_preflight_fixture()
  on.exit(unlink(fixture$root, recursive = TRUE, force = TRUE), add = TRUE)

  calculate_plan <- wlv_fixture_request(fixture)
  recalculate_plan <- wlv_fixture_request(fixture, mode = "recalculate")

  expect_no_error(preflight_environment$wlv_validate_data(calculate_plan))
  expect_no_error(preflight_environment$wlv_validate_data(recalculate_plan))
})
