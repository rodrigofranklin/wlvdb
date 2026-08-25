wlv_test_clone_runtime <- function(root = wlv_test_root) {
  source <- wlv_test_load_runtime(root)
  clone <- new.env(parent = baseenv())
  for (name in ls(source, all.names = TRUE)) {
    value <- get(name, envir = source, inherits = FALSE)
    if (is.function(value) && identical(environment(value), source)) {
      environment(value) <- clone
    }
    assign(name, value, envir = clone)
  }
  clone
}

wlv_native_test_country_total <- function(value) {
  country <- apply(value, c(1L, 3L), sum)
  country <- array(
    country,
    dim = c(dim(value)[[1L]], dim(value)[[3L]]),
    dimnames = dimnames(value)[c(1L, 3L)]
  )
  dimnames(country) <- stats::setNames(
    dimnames(country),
    c("year", "country")
  )
  result <- cbind(country, WWW = rowSums(country))
  dimnames(result) <- list(
    year = dimnames(country)[[1L]],
    country = c(dimnames(country)[[2L]], "WWW")
  )
  result
}

wlv_native_test_source_contract <- function(runtime, unit) {
  runtime$wlv_resource_contract(
    scope = "run",
    axes = c("year", "sector", "country"),
    value_type = "double",
    unit = unit,
    missingness = "none",
    validator = function(value) all(is.finite(value))
  )
}

wlv_native_test_producer_spec <- function(runtime) {
  gross_contract <- wlv_native_test_source_contract(runtime, "test:gross")
  runtime$wlv_module_spec(
    id = "test.gross",
    scope = "run",
    checkpoint = 4L,
    operations = c("calculate", "recalculate"),
    parameters = list(
      predecessor = runtime$wlv_module_parameter(
        "character",
        default = ""
      ),
      failure = runtime$wlv_module_parameter(
        "character",
        default = "none",
        choices = c("none", "shape")
      ),
      warning = runtime$wlv_module_parameter(
        "character",
        default = ""
      )
    ),
    requires = list(
      gross = runtime$wlv_resource_ref(
        "test/source/gross",
        gross_contract,
        producer = runtime$wlv_runtime_seed_producer()
      )
    ),
    provides = function(args) {
      action <- if (nzchar(args$predecessor)) "replace" else "create"
      c(
        runtime$wlv_native_indicator_output(
          "gross_output.s.mv",
          alias = "sector",
          action = action,
          predecessor = if (nzchar(args$predecessor)) {
            args$predecessor
          } else {
            NULL
          }
        ),
        runtime$wlv_native_indicator_output(
          "gross_output.s.mv",
          alias = "country",
          level = "country",
          action = action,
          predecessor = if (nzchar(args$predecessor)) {
            args$predecessor
          } else {
            NULL
          }
        )
      )
    },
    run = function(ctx) {
      message <- ctx$arg("warning")
      if (nzchar(message)) warning(message, call. = FALSE)
      sector <- ctx$input("gross")
      if (identical(ctx$arg("failure"), "shape")) {
        sector <- sector[, 1L, ]
      }
      runtime$wlv_module_result(list(
        sector = sector,
        country = wlv_native_test_country_total(ctx$input("gross"))
      ), diagnostics = list(
        `_native_test_gross.csv` = data.frame(
          check_id = "gross_output",
          passed = TRUE,
          stringsAsFactors = FALSE
        )
      ))
    }
  )
}

wlv_native_test_productivity_spec <- function(runtime) {
  labour_contract <- wlv_native_test_source_contract(runtime, "test:labour")
  runtime$wlv_module_spec(
    id = "test.productivity",
    scope = "run",
    checkpoint = 5L,
    operations = c("calculate", "recalculate"),
    requires = c(
      runtime$wlv_native_indicator_ref(
        "gross_output.s.mv",
        alias = "gross",
        producer = "indicator.gross"
      ),
      list(labour = runtime$wlv_resource_ref(
        "test/source/labour",
        labour_contract,
        producer = runtime$wlv_runtime_seed_producer()
      ))
    ),
    provides = runtime$wlv_native_stage5_provides(
      "labour_productivity.r.id"
    ),
    run = function(ctx) {
      gross <- ctx$input("gross")
      labour <- ctx$input("labour")
      sector <- gross / labour
      gross_country <- wlv_native_test_country_total(gross)
      labour_country <- wlv_native_test_country_total(labour)
      runtime$wlv_module_result(list(
        sector = sector,
        country = gross_country / labour_country
      ), diagnostics = list())
    }
  )
}

wlv_make_native_calculation_fixture <- function(runtime = wlv_test_load_runtime()) {
  labels <- list(
    year = c("2000", "2001"),
    sector = c("A", "B"),
    country = c("AAA", "BBB")
  )
  gross <- array(
    c(10, 20, 30, 40, 12, 24, 36, 48),
    dim = c(2L, 2L, 2L),
    dimnames = labels
  )
  labour <- array(
    c(2, 4, 5, 8, 3, 6, 6, 12),
    dim = dim(gross),
    dimnames = dimnames(gross)
  )
  registry <- runtime$wlv_module_registry(list(
    wlv_native_test_producer_spec(runtime),
    wlv_native_test_productivity_spec(runtime),
    runtime$wlv_native_panel_assembler_spec()
  ))
  list(
    runtime = runtime,
    registry = registry,
    labels = labels,
    gross = gross,
    labour = labour,
    indicators = c("gross_output.s.mv", "labour_productivity.r.id")
  )
}

wlv_native_test_base_store <- function(fixture, gross = fixture$gross) {
  runtime <- fixture$runtime
  runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource(
      "dimensions/lists",
      list(
        years = fixture$labels$year,
        sectors = fixture$labels$sector,
        countries = fixture$labels$country
      ),
      runtime$wlv_resource_contract(scope = "run", value_type = "list")
    ),
    runtime$wlv_seed_resource(
      "test/source/gross",
      gross,
      wlv_native_test_source_contract(runtime, "test:gross")
    ),
    runtime$wlv_seed_resource(
      "test/source/labour",
      fixture$labour,
      wlv_native_test_source_contract(runtime, "test:labour")
    )
  ))
}

wlv_native_test_calculation_instances <- function(
    fixture,
    failure = "none",
    warning = "") {
  runtime <- fixture$runtime
  list(
    runtime$wlv_module_instance(
      "indicator.gross",
      "test.gross",
      args = list(failure = failure, warning = warning)
    ),
    runtime$wlv_module_instance(
      "indicator.productivity",
      "test.productivity"
    ),
    runtime$wlv_module_instance(
      "assembler.panel",
      "assembler.panel",
      args = list(indicators = as.list(fixture$indicators))
    )
  )
}

wlv_run_native_test_calculation <- function(
    fixture,
    gross = fixture$gross,
    failure = "none",
    warning = "",
    reverse_instances = FALSE) {
  runtime <- fixture$runtime
  store <- wlv_native_test_base_store(fixture, gross = gross)
  instances <- wlv_native_test_calculation_instances(
    fixture,
    failure = failure,
    warning = warning
  )
  if (reverse_instances) instances <- rev(instances)
  plan <- runtime$wlv_compile_module_plan(
    fixture$registry,
    instances,
    store,
    operation = "calculate"
  )
  result <- runtime$wlv_run_module_plan(plan, store)
  list(store = store, plan = plan, result = result)
}

wlv_native_test_artifacts <- function(fixture, result) {
  runtime <- fixture$runtime
  list(
    sea_sectors = runtime$wlv_native_artifact_value(
      result$store,
      "sea_sectors",
      c("year", "indicator", "sector", "country")
    ),
    sea_countries = runtime$wlv_native_artifact_value(
      result$store,
      "sea_countries",
      c("year", "indicator", "country")
    )
  )
}

wlv_run_native_test_selective_recalculation <- function(
    fixture,
    parent,
    gross) {
  runtime <- fixture$runtime
  artifacts <- wlv_native_test_artifacts(fixture, parent$result)
  sector_gross <- artifacts$sea_sectors[, "gross_output.s.mv", , ]
  country_gross <- artifacts$sea_countries[, "gross_output.s.mv", ]
  sector_productivity <- artifacts$sea_sectors[
    , "labour_productivity.r.id", ,
  ]
  country_productivity <- artifacts$sea_countries[
    , "labour_productivity.r.id",
  ]
  dimnames(sector_gross) <- stats::setNames(
    dimnames(sector_gross),
    c("year", "sector", "country")
  )
  dimnames(country_gross) <- stats::setNames(
    dimnames(country_gross),
    c("year", "country")
  )
  dimnames(sector_productivity) <- stats::setNames(
    dimnames(sector_productivity),
    c("year", "sector", "country")
  )
  dimnames(country_productivity) <- stats::setNames(
    dimnames(country_productivity),
    c("year", "country")
  )
  store <- runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource(
      "dimensions/lists",
      list(
        years = fixture$labels$year,
        sectors = fixture$labels$sector,
        countries = fixture$labels$country
      ),
      runtime$wlv_resource_contract(scope = "run", value_type = "list")
    ),
    runtime$wlv_seed_resource(
      "test/source/gross",
      gross,
      wlv_native_test_source_contract(runtime, "test:gross")
    ),
    runtime$wlv_seed_resource(
      runtime$wlv_native_indicator_key("gross_output.s.mv"),
      sector_gross,
      runtime$wlv_native_indicator_contract("gross_output.s.mv"),
      producer = "indicator.gross"
    ),
    runtime$wlv_seed_resource(
      runtime$wlv_native_indicator_key("gross_output.s.mv", "country"),
      country_gross,
      runtime$wlv_native_indicator_contract(
        "gross_output.s.mv",
        level = "country"
      ),
      producer = "indicator.gross"
    ),
    runtime$wlv_seed_resource(
      runtime$wlv_native_indicator_key("labour_productivity.r.id"),
      sector_productivity,
      runtime$wlv_native_indicator_contract("labour_productivity.r.id"),
      producer = "indicator.productivity"
    ),
    runtime$wlv_seed_resource(
      runtime$wlv_native_indicator_key(
        "labour_productivity.r.id",
        "country"
      ),
      country_productivity,
      runtime$wlv_native_indicator_contract(
        "labour_productivity.r.id",
        level = "country"
      ),
      producer = "indicator.productivity"
    )
  ))
  instances <- list(
    runtime$wlv_module_instance(
      "recalc.gross",
      "test.gross",
      args = list(predecessor = "indicator.gross")
    ),
    runtime$wlv_module_instance(
      "assembler.panel",
      "assembler.panel",
      args = list(indicators = as.list(fixture$indicators))
    )
  )
  plan <- runtime$wlv_compile_module_plan(
    fixture$registry,
    instances,
    store,
    operation = "recalculate"
  )
  result <- runtime$wlv_run_module_plan(plan, store)
  list(store = store, plan = plan, result = result)
}

wlv_native_test_write_text <- function(path, value) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeBin(charToRaw(enc2utf8(value)), path)
  invisible(path)
}

wlv_make_native_publication_fixture <- function(mutable = FALSE) {
  runtime <- if (mutable) {
    wlv_test_clone_runtime()
  } else {
    wlv_test_load_runtime()
  }
  root <- tempfile("wlv-native-publication-")
  dir.create(root, recursive = TRUE)
  runtime$wlv_publication_ensure_store(root)
  list(
    root = normalizePath(root, winslash = "/", mustWork = TRUE),
    runtime = runtime,
    method = "native_test"
  )
}

wlv_remove_native_fixture <- function(fixture) {
  root <- normalizePath(fixture$root, winslash = "/", mustWork = TRUE)
  temporary_root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
  prefix <- paste0(sub("/+$", "", temporary_root), "/")
  if (!startsWith(root, prefix) || identical(root, temporary_root)) {
    stop(sprintf("Refusing to remove non-temporary fixture path: %s", root),
      call. = FALSE
    )
  }
  unlink(root, recursive = TRUE, force = TRUE)
  invisible(NULL)
}

wlv_native_test_run_environment <- function(
    fixture,
    run_id,
    method = fixture$method,
    payload = "native-result-v1",
    warnings = character(),
    parent_run_id = NULL) {
  runtime <- fixture$runtime
  paths <- runtime$wlv_publication_ensure_store(fixture$root)
  run_root <- file.path(paths$runs, method, run_id)
  if (!dir.create(run_root, recursive = TRUE, showWarnings = FALSE)) {
    stop("Could not create native test run.", call. = FALSE)
  }
  wlv_native_test_write_text(file.path(run_root, "payload.txt"), payload)
  runtime$wlv_write_result_csv(
    data.frame(
      cod_label = "gross_output.s.mv",
      label = "Gross output",
      stringsAsFactors = FALSE
    ),
    file.path(run_root, "_panel_indicators.csv")
  )
  runtime$wlv_write_result_csv(
    data.frame(
      value = "gross_output.s.mv",
      groups = "Product",
      type = "value",
      reverted = FALSE,
      stringsAsFactors = FALSE
    ),
    file.path(run_root, "_panel_meta_indicators.csv")
  )
  artifacts <- c(
    "_panel_indicators.csv",
    "_panel_meta_indicators.csv",
    "payload.txt"
  )
  manifest <- runtime$wlv_build_run_manifest(
    run_root = run_root,
    artifacts = artifacts,
    artifact_roles = vapply(
      artifacts,
      runtime$wlv_result_artifact_role,
      character(1L)
    ),
    run_id = run_id,
    method = method,
    result = list(
      provenance = list(complete = TRUE),
      request = list(mode = if (is.null(parent_run_id)) {
        "calculate"
      } else {
        "recalculate"
      }),
      schema = list(indicators = "gross_output.s.mv"),
      audit_summary = list(valid = TRUE)
    ),
    execution = list(
      started_at_utc = "2026-08-20T11:59:00Z",
      finished_at_utc = "2026-08-20T12:00:00Z",
      duration_seconds = 60,
      warnings = runtime$wlv_sanitize_publication_warnings(
        warnings,
        fixture$root
      ),
      host = list(
        r_version = as.character(getRversion()),
        platform = R.version$platform,
        os = unname(Sys.info()[["sysname"]]),
        arch = unname(Sys.info()[["machine"]])
      )
    ),
    created_at_utc = "2026-08-20T12:00:00Z",
    parent_run_id = parent_run_id
  )
  manifest_path <- file.path(run_root, runtime$wlv_run_manifest_filename())
  runtime$wlv_write_run_manifest(manifest, manifest_path)
  runtime$wlv_verify_run_manifest(manifest, run_root, reject_unlisted = TRUE)
  environment <- new.env(parent = emptyenv())
  environment$wlv_run_id <- manifest$run_id
  environment$wlv_result_id <- manifest$result_id
  environment$wlv_run_dir <- normalizePath(
    run_root,
    winslash = "/",
    mustWork = TRUE
  )
  environment$wlv_run_manifest <- manifest
  environment
}

wlv_native_test_release_plan <- function(
    fixture,
    methods = fixture$method,
    channel = "stable") {
  plan <- list(
    root = fixture$root,
    channel = channel,
    method_names = methods,
    methods = data.frame(
      method = methods,
      method_dir = file.path(fixture$root, "methods", methods),
      parameter_set = methods,
      stringsAsFactors = FALSE
    )
  )
  plan$publication_inputs <- fixture$runtime$wlv_capture_plan_publication_inputs(plan)
  plan
}
