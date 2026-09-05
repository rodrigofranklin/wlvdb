script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) {
  stop("Run issue13-aggregate.R with Rscript.", call. = FALSE)
}
script_path <- normalizePath(sub("^--file=", "", script_argument[[1L]]),
  winslash = "/", mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())
sys.source(file.path(script_dir, "issue13-matrix.R"), envir = environment())
sys.source(file.path(script_dir, "issue13-baseline-runtime-index-lib.R"),
  envir = environment()
)

options <- wlv13_parse_cli(commandArgs(trailingOnly = TRUE))
wlv13_cli_required(options, c(
  "evidence_root", "output", "baseline_base_commit", "candidate_commit",
  "candidate_seed_commit", "baseline_runtime_index",
  "baseline_runtime_index_sha256"
))
evidence_root <- wlv13_normalize_existing_dir(options$evidence_root,
  "evidence root"
)
output <- wlv13_ensure_dir(options$output, "aggregate output directory")
baseline_base_commit <- wlv13_scalar_text(options$baseline_base_commit,
  "baseline_base_commit", "^[0-9a-f]{40}$"
)
candidate_commit <- wlv13_scalar_text(options$candidate_commit,
  "candidate_commit", "^[0-9a-f]{40}$"
)
candidate_seed_commit <- wlv13_scalar_text(options$candidate_seed_commit,
  "candidate_seed_commit", "^[0-9a-f]{40}$"
)
if (identical(baseline_base_commit, candidate_commit)) {
  stop("Baseline and candidate commits must differ.", call. = FALSE)
}
baseline_runtime_index <- wlv13_read_baseline_runtime_index(
  options$baseline_runtime_index,
  options$baseline_runtime_index_sha256,
  baseline_base_commit
)
wlv13_validate_baseline_runtime_matrix(
  baseline_runtime_index, candidate_commit
)
if (file.exists(file.path(output, "aggregate.json"))) {
  stop("Refusing to overwrite aggregate evidence.", call. = FALSE)
}

wlv13_write_csv_once <- function(value, path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  directory <- wlv13_normalize_existing_dir(dirname(path),
    "aggregate CSV directory"
  )
  path <- file.path(directory, basename(path))
  if (file.exists(path) || dir.exists(path)) {
    stop(sprintf("Refusing to overwrite aggregate CSV: %s.", path),
      call. = FALSE
    )
  }
  temporary <- tempfile(
    pattern = paste0(".", basename(path), "-"),
    tmpdir = directory,
    fileext = ".tmp"
  )
  on.exit(if (file.exists(temporary)) unlink(temporary, force = TRUE), add = TRUE)
  utils::write.csv(value, temporary,
    row.names = FALSE, fileEncoding = "UTF-8", na = ""
  )
  if (!file.exists(temporary) || isTRUE(file.info(temporary)$isdir)) {
    stop(sprintf("Aggregate CSV staging was not materialized: %s.", path),
      call. = FALSE
    )
  }
  if (file.exists(path) || !file.rename(temporary, path)) {
    stop(sprintf("Cannot atomically install aggregate CSV: %s.", path),
      call. = FALSE
    )
  }
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

wlv13_value <- function(value, name, type = c("character", "logical", "numeric")) {
  type <- match.arg(type)
  valid <- length(value) == 1L && !is.null(value) && !is.na(value)
  valid <- valid && switch(type,
    character = is.character(value) && nzchar(value),
    logical = is.logical(value),
    numeric = is.numeric(value) && is.finite(value)
  )
  if (!valid) stop(sprintf("Invalid scalar `%s`.", name), call. = FALSE)
  value
}

wlv13_text_vector <- function(value) {
  if (is.null(value)) return(character())
  enc2utf8(as.character(unlist(value, use.names = FALSE)))
}

wlv13_document_map <- function(filename, schema) {
  paths <- list.files(evidence_root,
    pattern = paste0("^", filename, "$"), recursive = TRUE,
    full.names = TRUE, all.files = TRUE, include.dirs = FALSE
  )
  documents <- list()
  locations <- character()
  for (path in paths) {
    value <- wlv13_json_read(path, simplify = FALSE)
    if (!is.list(value) || !identical(value$schema, schema)) {
      stop(sprintf("Invalid %s schema: %s.", filename, path), call. = FALSE)
    }
    id <- wlv13_id(value$scenario_id, paste0(filename, " scenario_id"))
    if (id %in% names(documents)) {
      stop(sprintf("Duplicate %s for `%s`: %s and %s.",
        filename, id, locations[[id]], path
      ), call. = FALSE)
    }
    documents[[id]] <- value
    locations[[id]] <- normalizePath(path, winslash = "/", mustWork = TRUE)
  }
  list(values = documents, paths = locations)
}

checks <- list()
add_check <- function(category, id, passed, detail, priority = "P0") {
  passed <- isTRUE(passed)
  checks[[length(checks) + 1L]] <<- data.frame(
    category = category,
    id = id,
    priority = priority,
    passed = passed,
    detail = enc2utf8(as.character(detail)),
    stringsAsFactors = FALSE
  )
  invisible(passed)
}

scenario_docs <- metrics_docs <- comparison_docs <- fault_docs <- NULL
fatal_error <- NULL
tryCatch({
  scenario_docs <- wlv13_document_map(
    "scenario-result[.]json", wlv13_schema$scenario
  )
  metrics_docs <- wlv13_document_map(
    "process-metrics[.]json", "wlv-issue13-process-metrics/2"
  )
  comparison_docs <- wlv13_document_map(
    "comparison[.]json", wlv13_schema$comparison
  )
  fault_docs <- wlv13_document_map("fault-result[.]json", wlv13_schema$fault)
}, error = function(error) fatal_error <<- conditionMessage(error))

if (is.null(fatal_error)) {
  expected_scenarios <- wlv13_scenario_ids()
  expected_comparisons <- wlv13_comparison_ids()
  expected_faults <- paste0("candidate/fault/", wlv13_fault_names)
  observed_scenarios <- sort(names(scenario_docs$values), method = "radix")
  observed_metrics <- sort(names(metrics_docs$values), method = "radix")
  observed_comparisons <- sort(names(comparison_docs$values), method = "radix")
  observed_faults <- sort(names(fault_docs$values), method = "radix")
  add_check("completeness", "scenario-results",
    identical(observed_scenarios, expected_scenarios),
    sprintf("expected=%d observed=%d missing=[%s] extra=[%s]",
      length(expected_scenarios), length(observed_scenarios),
      paste(setdiff(expected_scenarios, observed_scenarios), collapse = ","),
      paste(setdiff(observed_scenarios, expected_scenarios), collapse = ",")
    )
  )
  add_check("completeness", "process-metrics",
    identical(observed_metrics, expected_scenarios),
    sprintf("expected=%d observed=%d missing=[%s] extra=[%s]",
      length(expected_scenarios), length(observed_metrics),
      paste(setdiff(expected_scenarios, observed_metrics), collapse = ","),
      paste(setdiff(observed_metrics, expected_scenarios), collapse = ",")
    )
  )
  add_check("completeness", "comparisons",
    identical(observed_comparisons, expected_comparisons),
    sprintf("expected=%d observed=%d missing=[%s] extra=[%s]",
      length(expected_comparisons), length(observed_comparisons),
      paste(setdiff(expected_comparisons, observed_comparisons), collapse = ","),
      paste(setdiff(observed_comparisons, expected_comparisons), collapse = ",")
    )
  )
  add_check("completeness", "fault-results",
    identical(observed_faults, sort(expected_faults, method = "radix")),
    sprintf("expected=%d observed=%d missing=[%s] extra=[%s]",
      length(expected_faults), length(observed_faults),
      paste(setdiff(expected_faults, observed_faults), collapse = ","),
      paste(setdiff(observed_faults, expected_faults), collapse = ",")
    )
  )
}

wlv13_output <- function(report, kind, qualifier = NULL) {
  outputs <- report$outputs
  if (!is.list(outputs)) return(NULL)
  matches <- vapply(outputs, function(output) {
    if (!is.list(output) || !identical(output$kind, kind)) return(FALSE)
    if (is.null(qualifier)) return(TRUE)
    identical(output$method, qualifier) || identical(output$source, qualifier)
  }, logical(1L))
  if (sum(matches) != 1L) return(NULL)
  outputs[[which(matches)]]
}

wlv13_output_for_phase <- function(arm, phase) {
  if (startsWith(phase, "prepare/")) {
    source <- sub("^prepare/", "", phase)
    report <- scenario_docs$values[[paste0(arm, "/prepare/all")]]
    kind <- if (identical(source, "euklems")) "snapshot" else "source"
    return(wlv13_output(report, kind, source))
  }
  if (identical(phase, "paper/0")) {
    return(wlv13_output(
      scenario_docs$values[[paste0(arm, "/paper/0")]], "release"
    ))
  }
  report <- scenario_docs$values[[paste0(arm, "/", phase)]]
  wlv13_output(report, "run", wlv13_phase_method(phase))
}

wlv13_signature <- function(output) {
  if (!is.list(output)) return(NULL)
  value <- output$inventory_sha256
  if (is.character(value) && length(value) == 1L &&
      grepl("^[0-9a-f]{64}$", value)) value else NULL
}

wlv13_hash_file_matches <- function(path, expected) {
  is.character(path) && length(path) == 1L && file.exists(path) &&
    is.character(expected) && length(expected) == 1L &&
    identical(wlv13_sha256_file(path), expected)
}

wlv13_expected_workers <- function(id) {
  if (grepl("/workers2$", id)) 2L else 0L
}

profile_root_checks <- new.env(parent = emptyenv())
wlv13_cached_profile_root_check <- function(root, profile) {
  normalized <- normalizePath(root, winslash = "/", mustWork = TRUE)
  key <- paste(profile$id, normalized, sep = "|")
  if (!exists(key, envir = profile_root_checks, inherits = FALSE)) {
    value <- tryCatch({
      wlv13_validate_profile_root(
        normalized, profile, baseline_base_commit
      )
      list(passed = TRUE, detail = "profile root and overlay commit authenticated")
    }, error = function(error) list(
      passed = FALSE,
      detail = conditionMessage(error)
    ))
    assign(key, value, envir = profile_root_checks)
  }
  get(key, envir = profile_root_checks, inherits = FALSE)
}

wlv13_validate_scenario <- function(id) {
  report <- scenario_docs$values[[id]]
  metrics <- metrics_docs$values[[id]]
  if (is.null(report)) return(invisible(NULL))
  arm <- strsplit(id, "/", fixed = TRUE)[[1L]][[1L]]
  execution_mode_present <- "execution_mode" %in% names(report)
  authentication_present <- "authentication" %in% names(report)
  execution_mode_ok <- !execution_mode_present && !authentication_present
  add_check("execution-mode", id, execution_mode_ok,
    if (execution_mode_ok) "native executed scenario" else
      "execution_mode/authentication is forbidden in the native final gate"
  )
  if (is.null(metrics)) return(invisible(NULL))
  runtime_record <- if (identical(arm, "baseline")) {
    baseline_runtime_index$scenarios[[id]]
  } else {
    NULL
  }
  runtime_profile <- if (identical(arm, "baseline") &&
      !is.null(runtime_record)) {
    baseline_runtime_index$profiles[[runtime_record$profile_id]]
  } else {
    NULL
  }
  expected_commit <- if (identical(arm, "baseline")) {
    runtime_record$runtime_commit
  } else {
    candidate_commit
  }
  suffix <- sub("^(baseline|candidate)/", "", id)
  is_seed_calculation <- grepl(
    "^calculate/[a-z][a-z0-9_]*/workers1$", suffix
  )
  if (is_seed_calculation) {
    if (identical(arm, "candidate")) {
      expected_commit <- candidate_seed_commit
    }
  }
  if (identical(arm, "baseline")) {
    root_validation <- tryCatch(
      wlv13_cached_profile_root_check(report$project_root, runtime_profile),
      error = function(error) list(
        passed = FALSE,
        detail = conditionMessage(error)
      )
    )
    runtime_binding_ok <- !is.null(runtime_record) &&
      identical(report$expected_commit, runtime_record$runtime_commit) &&
      identical(report$observed_commit, runtime_record$runtime_commit) &&
      isTRUE(root_validation$passed)
    add_check("baseline-runtime-index", id, runtime_binding_ok,
      if (runtime_binding_ok) {
        sprintf("profile=%s runtime_commit=%s",
          runtime_record$profile_id, runtime_record$runtime_commit
        )
      } else {
        paste0("scenario/profile runtime binding failed: ",
          root_validation$detail
        )
      }
    )
  }
  is_fault <- startsWith(id, "candidate/fault/")
  error_ok <- if (is_fault) {
    is.character(report$error) && length(report$error) == 1L &&
      !is.na(report$error) && nzchar(report$error)
  } else {
    is.null(report$error)
  }
  scenario_ok <- isTRUE(report$passed) && identical(report$status, "passed") &&
    identical(report$scenario_id, id) &&
    identical(report$expected_commit, expected_commit) &&
    identical(report$observed_commit, expected_commit) && error_ok
  add_check("scenario", id, scenario_ok,
    if (scenario_ok) "scenario passed at pinned commit" else
      "scenario failed, changed commit, or retained an error"
  )
  expected_workers <- wlv13_expected_workers(id)
  metrics_ok <- isTRUE(metrics$passed) && identical(metrics$status, "passed") &&
    identical(metrics$scenario_id, id) && !isTRUE(metrics$timed_out) &&
    isTRUE(metrics$exit_code_matched) && isTRUE(metrics$cluster_closed) &&
    isTRUE(metrics$worker_count_matched) &&
    identical(as.integer(metrics$expected_worker_processes), expected_workers) &&
    identical(as.integer(metrics$max_concurrent_worker_processes),
      expected_workers) &&
    is.numeric(metrics$elapsed_seconds) && metrics$elapsed_seconds > 0 &&
    is.numeric(metrics$peak_rss_bytes) && metrics$peak_rss_bytes >= 0 &&
    identical(
      normalizePath(metrics$working_directory, winslash = "/", mustWork = TRUE),
      normalizePath(report$project_root, winslash = "/", mustWork = TRUE)
    )
  authenticated_logs <- all(c(
    wlv13_hash_file_matches(metrics$stdout_path, metrics$stdout_sha256),
    wlv13_hash_file_matches(metrics$stderr_path, metrics$stderr_sha256),
    wlv13_hash_file_matches(metrics$samples_path, metrics$samples_sha256),
    wlv13_hash_file_matches(metrics$process_spec_path,
      metrics$process_spec_sha256)
  ))
  process_spec_ok <- tryCatch({
    process_spec <- wlv13_json_read(metrics$process_spec_path, simplify = FALSE)
    process_environment <- process_spec$environment
    identical(process_spec$schema, "wlv-issue13-process-spec/1") &&
      identical(process_spec$scenario_id, id) &&
      identical(names(process_environment), c(
        "R_LIBS_USER", "RENV_PATHS_LIBRARY",
        "RENV_CONFIG_AUTO_SNAPSHOT", "RENV_CONFIG_CACHE_ENABLED",
        "RENV_CONFIG_LOCKING_ENABLED",
        "RENV_CONFIG_SANDBOX_ENABLED", "RENV_CONFIG_UPDATES_CHECK",
        "RENV_CONFIG_USER_ENVIRON", "RENV_CONFIG_USER_LIBRARY", "TZ"
      )) &&
      identical(
        normalizePath(process_environment$RENV_PATHS_LIBRARY,
          winslash = "/", mustWork = TRUE
        ),
        wlv13_renv_library_root(process_environment$R_LIBS_USER)
      ) &&
      identical(process_environment$RENV_CONFIG_AUTO_SNAPSHOT, "FALSE") &&
      identical(process_environment$RENV_CONFIG_CACHE_ENABLED, "FALSE") &&
      identical(process_environment$RENV_CONFIG_LOCKING_ENABLED, "FALSE") &&
      identical(process_environment$RENV_CONFIG_SANDBOX_ENABLED, "FALSE") &&
      identical(process_environment$RENV_CONFIG_UPDATES_CHECK, "FALSE") &&
      identical(process_environment$RENV_CONFIG_USER_ENVIRON, "FALSE") &&
      identical(process_environment$RENV_CONFIG_USER_LIBRARY, "FALSE") &&
      identical(process_environment$TZ, "UTC") &&
      identical(as.integer(process_spec$expected_worker_processes),
        expected_workers) &&
      identical(
        normalizePath(process_spec$working_directory,
          winslash = "/", mustWork = TRUE
        ),
        normalizePath(report$project_root, winslash = "/", mustWork = TRUE)
      )
  }, error = function(error) FALSE)
  add_check("process", id, metrics_ok && authenticated_logs && process_spec_ok,
    if (metrics_ok && authenticated_logs && process_spec_ok) {
      sprintf("elapsed=%.3fs peak_rss=%s workers=%d cluster_closed=true",
        as.numeric(metrics$elapsed_seconds),
        format(as.numeric(metrics$peak_rss_bytes), scientific = FALSE),
        expected_workers
      )
    } else {
      "process metrics, worker count, cluster closure, or evidence hashes failed"
    }
  )

  request <- report$request
  request_ok <- is.list(request)
  if (startsWith(suffix, "calculate/")) {
    method <- wlv13_phase_method(suffix)
    workers <- if (endsWith(suffix, "workers2")) 2L else 1L
    request_ok <- request_ok && identical(report$kind, "calculate") &&
      identical(request$method, method) &&
      identical(as.integer(request$workers), workers)
  } else if (startsWith(suffix, "recalculate/")) {
    expectation <- wlv13_recalculation_expectation(suffix)
    sea_vars <- wlv13_text_vector(request$sea_vars)
    expected_sea_vars <- if (is.null(expectation$sea_vars)) character() else
      expectation$sea_vars
    request_ok <- request_ok && identical(report$kind, "recalculate") &&
      identical(request$method, expectation$method) &&
      identical(as.integer(request$workers), 1L) &&
      identical(as.integer(request$at_stage), expectation$stage) &&
      identical(sea_vars, expected_sea_vars)
  } else if (identical(suffix, "prepare/all")) {
    request_ok <- request_ok && identical(report$kind, "prepare") &&
      identical(wlv13_text_vector(request$methods), c("wiodr13", "wiodr16"))
  } else if (identical(suffix, "paper/0")) {
    request_ok <- request_ok && identical(report$kind, "paper0") &&
      identical(wlv13_text_vector(request$methods), wlv13_paper0_methods) &&
      identical(as.integer(request$paper), 0L)
  }
  add_check("request", id, request_ok,
    if (request_ok) "canonical request" else "request differs from the matrix"
  )
}

if (is.null(fatal_error)) {
  invisible(lapply(intersect(wlv13_scenario_ids(), names(scenario_docs$values)),
    wlv13_validate_scenario
  ))
}

# Authenticate each distinct output inventory once at aggregation time. This is
# the final TOCTOU check after all comparisons have completed.
verified_inventory_count <- 0L
if (is.null(fatal_error)) {
  inventory_outputs <- list()
  for (id in intersect(wlv13_scenario_ids(), names(scenario_docs$values))) {
    outputs <- scenario_docs$values[[id]]$outputs
    if (!is.list(outputs)) next
    for (output_record in outputs) {
      if (!is.list(output_record) || is.null(output_record$kind)) next
      key <- paste(output_record$kind, output_record$root,
        output_record$manifest_path, sep = "|")
      inventory_outputs[[key]] <- output_record
    }
  }
  for (key in names(inventory_outputs)) {
    output_record <- inventory_outputs[[key]]
    ok <- tryCatch({
      inventory <- wlv13_inventory(
        output_record$kind,
        if (identical(output_record$kind, "snapshot")) {
          output_record$manifest_path
        } else {
          output_record$root
        }
      )
      identical(wlv13_inventory_signature(inventory),
        output_record$inventory_sha256) &&
        identical(inventory$manifest_sha256, output_record$manifest_sha256)
    }, error = function(error) {
      attr(FALSE, "reason") <- conditionMessage(error)
      FALSE
    })
    add_check("inventory", key, ok,
      if (ok) "manifest and all authenticated bytes reverified" else
        "manifest/inventory changed or failed final verification"
    )
    if (ok) verified_inventory_count <- verified_inventory_count + 1L
  }
}

wlv13_validate_comparison_base <- function(id, allow_failed = FALSE) {
  report <- comparison_docs$values[[id]]
  if (is.null(report)) return(FALSE)
  exceptions <- report$policy_exceptions
  valid <- identical(report$scenario_id, id) && is.logical(report$passed) &&
    length(report$passed) == 1L && !is.na(report$passed) &&
    identical(report$status, if (isTRUE(report$passed)) "passed" else "failed") &&
    is.list(exceptions) && !length(exceptions) &&
    (allow_failed || isTRUE(report$passed))
  add_check("comparison", id, valid,
    if (valid) {
      if (isTRUE(report$passed)) "semantic comparison passed" else
        "failed comparison retained as an oracle observation"
    } else {
      "invalid comparison schema/status, policy exception, or scientific mismatch"
    }
  )
  valid
}

wlv13_comparison_signatures <- function(report, left, right) {
  identical(report$candidate$inventory_sha256, wlv13_signature(left)) &&
    identical(report$baseline$inventory_sha256, wlv13_signature(right))
}

oracle_rows <- list()
if (is.null(fatal_error)) {
  for (phase in wlv13_parity_phases()) {
    id <- paste0("parity/", phase)
    valid <- wlv13_validate_comparison_base(id, allow_failed = FALSE)
    report <- comparison_docs$values[[id]]
    binding_ok <- valid && wlv13_comparison_signatures(
      report,
      wlv13_output_for_phase("candidate", phase),
      wlv13_output_for_phase("baseline", phase)
    )
    add_check("comparison-binding", id, binding_ok,
      if (binding_ok) "comparison is bound to matching scenario outputs" else
        "comparison points to the wrong or unauthenticated output"
    )
    if (identical(phase, "paper/0")) {
      workbooks <- if (is.list(report$artifacts)) {
        Filter(function(artifact) {
          is.list(artifact) && identical(artifact$type, "xlsx")
        }, report$artifacts)
      } else {
        list()
      }
      paper_semantics_ok <- binding_ok && length(workbooks) == 1L
      if (paper_semantics_ok) {
        workbook <- workbooks[[1L]]
        sheet_reports <- workbook$sheets
        paper_semantics_ok <-
          identical(workbook$schema,
            "wlv-issue13-paper0-workbook-comparison/1") &&
          identical(workbook$comparison_mode, "ooxml-semantic") &&
          isTRUE(workbook$passed) &&
          isTRUE(workbook$sheet_names_identical) &&
          isTRUE(workbook$sheet_states_identical) &&
          isTRUE(workbook$package_entry_names_identical) &&
          isTRUE(workbook$package_semantics_identical) &&
          isTRUE(
            workbook$core_properties_identical_after_timestamp_normalization
          ) &&
          !length(workbook$changed_package_entries) &&
          !length(workbook$baseline_only_sheets) &&
          !length(workbook$candidate_only_sheets) &&
          is.list(sheet_reports) && length(sheet_reports) > 0L &&
          all(vapply(sheet_reports, function(sheet) {
            is.list(sheet) && isTRUE(sheet$passed)
          }, logical(1L)))
      }
      add_check("paper-workbook-semantics", id, paper_semantics_ok,
        if (paper_semantics_ok) {
          "OOXML formulas, types, masks, sheet states and package semantics match"
        } else {
          "paper workbook lacks the complete pinned OOXML semantic proof"
        }
      )
    }
  }

  for (arm in wlv13_arms) {
    for (method in c("wiodr13", "wiodr16")) {
      id <- paste0("equivalence/", arm, "/calculate/", method,
        "/workers2-vs-workers1"
      )
      valid <- wlv13_validate_comparison_base(id, allow_failed = FALSE)
      report <- comparison_docs$values[[id]]
      binding_ok <- valid && wlv13_comparison_signatures(
        report,
        wlv13_output_for_phase(arm, wlv13_calculate_phase(method, 2L)),
        wlv13_output_for_phase(arm, wlv13_calculate_phase(method, 1L))
      )
      add_check("comparison-binding", id, binding_ok,
        if (binding_ok) "workers=2 equals workers=1" else
          "worker-equivalence comparison is invalid or misbound"
      )
    }
  }

  for (method in wlv13_methods) {
    full_phase <- wlv13_calculate_phase(method, 1L)
    for (phase in wlv13_recalculation_phases(method)) {
      oracle <- list()
      oracle_valid <- logical()
      for (arm in wlv13_arms) {
        id <- paste0("oracle/", arm, "/", phase)
        oracle[[arm]] <- comparison_docs$values[[id]]
        valid <- wlv13_validate_comparison_base(id, allow_failed = TRUE)
        binding_ok <- valid && wlv13_comparison_signatures(
          oracle[[arm]],
          wlv13_output_for_phase(arm, phase),
          wlv13_output_for_phase(arm, full_phase)
        )
        add_check("comparison-binding", id, binding_ok,
          if (binding_ok) "oracle is bound to child and immutable full run" else
            "oracle is invalid or points to the wrong runs"
        )
        oracle_valid[[arm]] <- binding_ok
      }
      same_outcome <- all(oracle_valid) &&
        identical(oracle$baseline$passed, oracle$candidate$passed)
      classification <- if (!same_outcome) {
        "oracle-mismatch"
      } else if (isTRUE(oracle$baseline$passed)) {
        "exact-to-full"
      } else {
        "baseline-known-divergence"
      }
      add_check("oracle", phase, same_outcome,
        paste0("classification=", classification)
      )
      baseline_artifacts <- oracle$baseline$artifacts
      mismatch_artifacts <- if (is.list(baseline_artifacts)) {
        vapply(baseline_artifacts[!vapply(baseline_artifacts, function(value) {
          isTRUE(value$passed)
        }, logical(1L))], function(value) {
          if (is.null(value$key)) "unknown" else value$key
        }, character(1L))
      } else {
        character()
      }
      oracle_rows[[length(oracle_rows) + 1L]] <- data.frame(
        phase = phase,
        method = method,
        classification = classification,
        baseline_exact = isTRUE(oracle$baseline$passed),
        candidate_exact = isTRUE(oracle$candidate$passed),
        baseline_mismatch_artifacts = paste(mismatch_artifacts, collapse = "|"),
        stringsAsFactors = FALSE
      )
    }
  }
}

# Every recalculation must prove that its current channel was reset to the
# independently authenticated workers=1 full run before execution.
if (is.null(fatal_error)) {
  identity_fields <- c(
    "run_id", "result_id", "manifest_sha256",
    "inventory_sha256", "method", "parent_run_id"
  )
  for (arm in wlv13_arms) {
    for (method in wlv13_methods) {
      full <- wlv13_output_for_phase(arm, wlv13_calculate_phase(method, 1L))
      expected_full_seed_commit <- if (identical(arm, "baseline")) {
        full_id <- paste0("baseline/", wlv13_calculate_phase(method, 1L))
        baseline_runtime_index$scenarios[[full_id]]$runtime_commit
      } else {
        candidate_seed_commit
      }
      for (phase in wlv13_recalculation_phases(method)) {
        id <- paste0(arm, "/", phase)
        report <- scenario_docs$values[[id]]
        child <- wlv13_output(report, "run", method)
        seed <- report$seed
      seed_ok <- is.list(seed) && is.list(seed$expected) &&
          is.list(seed$observed_before) &&
          identical(seed$expected[identity_fields], full[identity_fields]) &&
          identical(seed$observed_before[identity_fields], full[identity_fields]) &&
          identical(seed$expected_seed_commit, expected_full_seed_commit) &&
          identical(child$parent_run_id, full$run_id) &&
          !identical(child$run_id, full$run_id) &&
          wlv13_hash_file_matches(seed$proof_path, seed$proof_sha256)
        add_check("independent-seed", id, seed_ok,
          if (seed_ok) "direct child of independently restored immutable full run" else
            "recalculation was chained, mis-seeded, or its seed proof changed"
        )
      }
    }
  }
}

# Fault evidence is accepted only when the named wrapper actually reached its
# canonical call/checkpoint and every prior visible state was preserved.
if (is.null(fatal_error)) {
  required_fault_flags <- c(
    "passed", "injected", "expected_failure_observed",
    "expected_error_matched", "channel_marker_unchanged",
    "no_partial_release_visible", "staging_clean",
    "preparation_staging_clean",
    "normalized_generation_unchanged", "previous_release_verified"
  )
  for (fault_id in wlv13_fault_names) {
    id <- paste0("candidate/fault/", fault_id)
    report <- fault_docs$values[[id]]
    scenario_report <- scenario_docs$values[[id]]
    binding_index <- match(fault_id, wlv13_fault_bindings$fault_id)
    expected_checkpoint <- wlv13_fault_bindings$checkpoint[[binding_index]]
    observed_checkpoint <- if (is.null(report$checkpoint)) NA_character_ else
      report$checkpoint
    valid <- !is.null(report) && !is.null(scenario_report) &&
      identical(scenario_report$kind,
        wlv13_fault_bindings$kind[[binding_index]]) &&
      identical(report$status, "passed") &&
      identical(report$fault_id, fault_id) &&
      identical(report$binding,
        wlv13_fault_bindings$binding[[binding_index]]) &&
      identical(report$when, wlv13_fault_bindings$when[[binding_index]]) &&
      identical(as.integer(report$call),
        wlv13_fault_bindings$call[[binding_index]]) &&
      identical(observed_checkpoint, expected_checkpoint) &&
      all(vapply(required_fault_flags, function(field) {
        isTRUE(report[[field]])
      }, logical(1L))) &&
      identical(as.integer(report$binding_call_count),
        wlv13_fault_bindings$call[[binding_index]])
    add_check("fault", id, valid,
      if (valid) "injected boundary failed with no visible partial state" else
        "fault was not injected at its boundary or transactional invariants failed"
    )
  }
}

performance_rows <- list()
if (is.null(fatal_error)) {
  paired_suffixes <- c(
    wlv13_core_phases(), wlv13_worker2_phases(), "prepare/all", "paper/0"
  )
  for (suffix in paired_suffixes) {
    baseline <- metrics_docs$values[[paste0("baseline/", suffix)]]
    candidate <- metrics_docs$values[[paste0("candidate/", suffix)]]
    if (is.null(baseline) || is.null(candidate)) next
    baseline_time <- as.numeric(baseline$elapsed_seconds)
    candidate_time <- as.numeric(candidate$elapsed_seconds)
    baseline_rss <- as.numeric(baseline$peak_rss_bytes)
    candidate_rss <- as.numeric(candidate$peak_rss_bytes)
    time_limits <- wlv13_performance_time_limits(baseline_time)
    time_ratio_limit <- time_limits$ratio_limit_seconds
    time_absolute_allowance <- time_limits$absolute_allowance_seconds
    time_absolute_limit <- time_limits$absolute_limit_seconds
    time_limit <- time_limits$effective_limit_seconds
    rss_limit <- baseline_rss + max(baseline_rss * 0.1, 512 * 1024^2)
    valid_time <- is.finite(baseline_time) && baseline_time > 0 &&
      is.finite(candidate_time)
    time_ratio_ok <- valid_time && candidate_time <= time_ratio_limit
    time_absolute_ok <- valid_time && candidate_time <= time_absolute_limit
    time_ok <- time_ratio_ok || time_absolute_ok
    rss_ok <- is.finite(baseline_rss) && baseline_rss >= 0 &&
      is.finite(candidate_rss) && candidate_rss <= rss_limit
    add_check("performance-time", suffix, time_ok,
      sprintf(
        paste0(
          "candidate=%.3f baseline=%.3f ratio_limit=%.3f ",
          "absolute_limit=%.3f effective_limit=%.3f"
        ),
        candidate_time, baseline_time, time_ratio_limit,
        time_absolute_limit, time_limit
      ), priority = "P1"
    )
    add_check("performance-rss", suffix, rss_ok,
      sprintf("candidate=%s baseline=%s limit=%s",
        format(candidate_rss, scientific = FALSE),
        format(baseline_rss, scientific = FALSE),
        format(rss_limit, scientific = FALSE)
      ), priority = "P1"
    )
    performance_rows[[length(performance_rows) + 1L]] <- data.frame(
      scenario = suffix,
      baseline_seconds = baseline_time,
      candidate_seconds = candidate_time,
      time_ratio_limit_seconds = time_ratio_limit,
      time_absolute_allowance_seconds = time_absolute_allowance,
      time_absolute_limit_seconds = time_absolute_limit,
      time_limit_seconds = time_limit,
      time_ratio_passed = time_ratio_ok,
      time_absolute_passed = time_absolute_ok,
      time_passed = time_ok,
      baseline_peak_rss_bytes = baseline_rss,
      candidate_peak_rss_bytes = candidate_rss,
      rss_limit_bytes = rss_limit,
      rss_passed = rss_ok,
      stringsAsFactors = FALSE
    )
  }
}

if (!is.null(fatal_error)) {
  add_check("aggregate", "fatal", FALSE, fatal_error)
}
check_table <- if (length(checks)) do.call(rbind, checks) else data.frame()
row.names(check_table) <- NULL
oracle_table <- if (length(oracle_rows)) do.call(rbind, oracle_rows) else
  data.frame()
performance_table <- if (length(performance_rows)) {
  do.call(rbind, performance_rows)
} else {
  data.frame()
}
passed <- nrow(check_table) > 0L && all(check_table$passed)
failed <- if (nrow(check_table)) check_table[!check_table$passed, , drop = FALSE] else
  data.frame()
report <- list(
  schema = wlv13_schema$aggregate,
  status = if (passed) "passed" else "failed",
  passed = passed,
  generated_at = wlv13_now(),
  evidence_root = evidence_root,
  baseline_base_commit = baseline_base_commit,
  baseline_runtime_index_path = baseline_runtime_index$path,
  baseline_runtime_index_sha256 = baseline_runtime_index$sha256,
  candidate_commit = candidate_commit,
  candidate_seed_commit = candidate_seed_commit,
  matrix = wlv13_matrix_summary(),
  verified_inventory_count = verified_inventory_count,
  check_count = nrow(check_table),
  failed_check_count = nrow(failed),
  failed_checks = if (nrow(failed)) lapply(seq_len(nrow(failed)), function(index) {
    as.list(failed[index, , drop = FALSE])
  }) else list(),
  oracle_classification = if (nrow(oracle_table)) {
    lapply(seq_len(nrow(oracle_table)), function(index) {
      as.list(oracle_table[index, , drop = FALSE])
    })
  } else {
    list()
  },
  limitations = list(
    "Diagnostic CSV order is non-normative; duplicate-preserving row multisets are compared.",
    "A baseline oracle divergence is recorded, never whitelisted by method.",
    "Final artifact authentication rereads every manifest-guided inventory and can be I/O intensive."
  )
)
invisible(wlv13_write_csv_once(check_table, file.path(output, "checks.csv")))
invisible(wlv13_write_csv_once(
  oracle_table,
  file.path(output, "oracle-classification.csv")
))
invisible(wlv13_write_csv_once(
  performance_table,
  file.path(output, "performance.csv")
))
# aggregate.json is the commit record for the three CSV companions. It is
# installed only after every CSV has reached its canonical write-once path.
wlv13_json_write(report, file.path(output, "aggregate.json"))
quit(save = "no", status = if (passed) 0L else 1L, runLast = FALSE)
