# Synthetic, lightweight tests for the external issue #13 evidence harness.
# No project worktree, official cache, or real scientific job is touched.

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) stop("Run with Rscript.", call. = FALSE)
script_path <- normalizePath(sub("^--file=", "", script_argument[[1L]]),
  winslash = "/", mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())
sys.source(file.path(script_dir, "issue13-matrix.R"), envir = environment())
sys.source(file.path(script_dir, "issue13-baseline-runtime-index-lib.R"),
  envir = environment()
)
sys.source(file.path(script_dir, "issue13-compare-lib.R"), envir = environment())
wlv13_require("fst")

assert <- function(value, message) {
  if (!isTRUE(value)) stop(message, call. = FALSE)
}
assert_error <- function(expression, pattern, message) {
  observed <- tryCatch({
    force(expression)
    NULL
  }, error = conditionMessage)
  assert(!is.null(observed) && grepl(pattern, observed, perl = TRUE),
    paste0(message, if (is.null(observed)) " (no error)" else
      paste0(" (observed: ", observed, ")"))
  )
  invisible(observed)
}
temporary_root <- tempfile("wlv13-harness-selftest-")
if (!dir.create(temporary_root, recursive = TRUE, showWarnings = FALSE)) {
  stop("Cannot create self-test root.", call. = FALSE)
}
on.exit(unlink(temporary_root, recursive = TRUE, force = TRUE), add = TRUE)

renv_library <- file.path(
  temporary_root, "renv", "library", "windows", "R-4.6",
  "x86_64-w64-mingw32"
)
if (!dir.create(renv_library, recursive = TRUE, showWarnings = FALSE)) {
  stop("Cannot create the sealed renv layout self-test.", call. = FALSE)
}
renv_environment <- wlv13_r_environment(renv_library)
assert(
  identical(names(renv_environment), c(
    "R_LIBS_USER", "RENV_PATHS_LIBRARY",
    "RENV_CONFIG_AUTO_SNAPSHOT", "RENV_CONFIG_CACHE_ENABLED",
    "RENV_CONFIG_LOCKING_ENABLED",
    "RENV_CONFIG_SANDBOX_ENABLED", "RENV_CONFIG_UPDATES_CHECK",
    "RENV_CONFIG_USER_ENVIRON", "RENV_CONFIG_USER_LIBRARY", "TZ"
  )) &&
    identical(renv_environment$R_LIBS_USER,
      normalizePath(renv_library, winslash = "/", mustWork = TRUE)
    ) &&
    identical(renv_environment$RENV_PATHS_LIBRARY,
      normalizePath(file.path(temporary_root, "renv", "library"),
        winslash = "/", mustWork = TRUE
      )
    ) &&
    identical(renv_environment$RENV_CONFIG_AUTO_SNAPSHOT, "FALSE") &&
    identical(renv_environment$RENV_CONFIG_CACHE_ENABLED, "FALSE") &&
    identical(renv_environment$RENV_CONFIG_LOCKING_ENABLED, "FALSE") &&
    identical(renv_environment$RENV_CONFIG_SANDBOX_ENABLED, "FALSE") &&
    identical(renv_environment$RENV_CONFIG_UPDATES_CHECK, "FALSE") &&
    identical(renv_environment$RENV_CONFIG_USER_ENVIRON, "FALSE") &&
    identical(renv_environment$RENV_CONFIG_USER_LIBRARY, "FALSE") &&
    identical(renv_environment$TZ, "UTC"),
  "The explicit renv library environment binding differs."
)
assert_error(
  wlv13_r_environment(NULL), "r_library.*required",
  "The monitored R environment accepted an absent library."
)
invalid_renv_library <- file.path(temporary_root, "invalid-library")
dir.create(invalid_renv_library, recursive = TRUE)
assert_error(
  wlv13_renv_library_root(invalid_renv_library),
  "sealed renv profile layout",
  "An invalid renv library layout was accepted."
)

write_text <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(enc2utf8(value), path, useBytes = TRUE)
  invisible(path)
}

# Comparator: chunked numeric states plus duplicate-preserving unordered
# diagnostics. The same diagnostic rows in a different order must pass.
comparison_root <- file.path(temporary_root, "comparison")
baseline_root <- file.path(comparison_root, "baseline")
candidate_root <- file.path(comparison_root, "candidate")
manifest_root <- file.path(comparison_root, "manifests")
dir.create(baseline_root, recursive = TRUE)
dir.create(candidate_root, recursive = TRUE)
dir.create(manifest_root, recursive = TRUE)
dimensions <- c(2L, 3L)
axes <- list(c("1995", "1996"), c("gross", "value", "skill"))
baseline_values <- c(1, NA_real_, NaN, Inf, -Inf, 6)
candidate_values <- baseline_values
for (root in c(baseline_root, candidate_root)) {
  values <- if (identical(root, baseline_root)) baseline_values else
    candidate_values
  fst::write_fst(data.frame(Data = values), file.path(root, "array.fst"))
  saveRDS(c(list(dimensions), axes), file.path(root, "array.fst.meta"))
}
diagnostics <- data.frame(
  action = c("raw", "normalized", "raw"),
  value = c("1", "2", "1"),
  stringsAsFactors = FALSE
)
utils::write.csv(diagnostics, file.path(baseline_root, "_anomalies.csv"),
  row.names = FALSE, fileEncoding = "UTF-8"
)
utils::write.csv(diagnostics[c(3L, 1L, 2L), ],
  file.path(candidate_root, "_anomalies.csv"),
  row.names = FALSE, fileEncoding = "UTF-8"
)
paths <- c("_anomalies.csv", "array.fst", "array.fst.meta")
roles <- c("diagnostic", "array", "array_metadata")
baseline_snapshot_path <- file.path(manifest_root, "baseline.json")
candidate_snapshot_path <- file.path(manifest_root, "candidate.json")
wlv13_create_snapshot(baseline_root, paths, roles, "selftest/baseline",
  baseline_snapshot_path
)
wlv13_create_snapshot(candidate_root, paths, roles, "selftest/candidate",
  candidate_snapshot_path
)
comparison <- wlv13_compare_inventories(
  wlv13_snapshot_inventory(candidate_snapshot_path),
  wlv13_snapshot_inventory(baseline_snapshot_path),
  chunk_rows = 2L,
  scenario_id = "selftest/comparison-pass"
)
assert(comparison$passed,
  "Reordered diagnostic multiset or identical array failed comparison."
)
diagnostic_summary <- comparison$artifacts[[which(vapply(
  comparison$artifacts,
  function(value) identical(value$key, "file:_anomalies.csv"),
  logical(1L)
))]]
assert(identical(diagnostic_summary$comparison_mode,
  "unordered-row-multiset"), "Diagnostic comparison mode was not applied."
)

bad_root <- file.path(comparison_root, "candidate-bad")
dir.create(bad_root)
invisible(file.copy(file.path(candidate_root, "_anomalies.csv"), bad_root))
bad_values <- baseline_values
bad_values[[2L]] <- NaN
fst::write_fst(data.frame(Data = bad_values), file.path(bad_root, "array.fst"))
saveRDS(c(list(dimensions), axes), file.path(bad_root, "array.fst.meta"))
bad_snapshot_path <- file.path(manifest_root, "candidate-bad.json")
wlv13_create_snapshot(bad_root, paths, roles, "selftest/candidate-bad",
  bad_snapshot_path
)
bad_comparison <- wlv13_compare_inventories(
  wlv13_snapshot_inventory(bad_snapshot_path),
  wlv13_snapshot_inventory(baseline_snapshot_path),
  chunk_rows = 2L,
  scenario_id = "selftest/comparison-state-fail"
)
assert(!bad_comparison$passed,
  "NA-to-NaN transition was not rejected by the chunked comparator."
)
assert(nrow(bad_comparison$transitions) >= 1L,
  "Numeric-state failure did not emit transition evidence."
)

# Cross-engine v3: module ids, legacy script paths, DAG order and the explicit
# non-finite diagnostic are architectural. Numeric arrays, states,
# GFCF/Leontief evidence and normalized scientific contracts remain exact.
cross_root <- file.path(temporary_root, "cross-engine-v3")
dir.create(cross_root)
write_semicolon <- function(value, path) {
  utils::write.table(
    value, path, sep = ";", quote = TRUE, row.names = FALSE,
    col.names = TRUE, fileEncoding = "UTF-8", na = ""
  )
}
cross_unit <- function(candidate) {
  columns <- wlv13_cross_engine_schema("_unit_contract.csv")
  value <- as.data.frame(
    stats::setNames(as.list(rep("", length(columns))), columns),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  value$contract <- "fixture_units_v1"
  value$schema_version <- "1"
  value$source <- "fixture"
  value$indicator <- "gross_output.s.mv"
  value$quantity_kind <- "monetary_flow"
  value$source_unit <- "million_usd"
  value$source_scale <- "1"
  value$canonical_unit <- "million_usd"
  value$display_unit <- "million_usd"
  value$display_multiplier <- "1"
  value$currency <- "USD"
  value$price_basis <- "current"
  value$level <- "sector_to_country"
  value$strategy <- "sum"
  value$module <- if (candidate) "aggregation.gross_output" else
    "common/gross_output-country.R"
  value$unit_notes <- "scientific unit"
  value$aggregation_notes <- if (candidate) "" else "legacy adapter route"
  value
}
write_cross_run <- function(root, candidate = FALSE, mutation = "none") {
  dir.create(root, recursive = TRUE)
  values <- c(1, 2)
  if (identical(mutation, "array")) values[[2L]] <- 3
  fst::write_fst(data.frame(Data = values), file.path(root, "sea_sectors.fst"))
  saveRDS(
    c(list(c(2L)), list(c("1995", "1996"))),
    file.path(root, "sea_sectors.fst.meta")
  )
  write_semicolon(data.frame(
    indicator = "gross_output.s.mv", state = "observed",
    stringsAsFactors = FALSE
  ), file.path(root, "_states.csv"))
  write_semicolon(data.frame(
    method = "fixture", cell_count = "1",
    removed_mass = if (identical(mutation, "gfcf")) "3" else "2",
    stringsAsFactors = FALSE
  ), file.path(root, "_gfcf_negative_summary.csv"))
  write_semicolon(data.frame(
    method = "fixture", year = "1995",
    certificate = if (identical(mutation, "leontief")) "changed" else "pass",
    stringsAsFactors = FALSE
  ), file.path(root, "_leontief_diagnostics.csv"))
  assumptions <- if (candidate) {
    data.frame(
      names = c("assumption.china", "assumption.row"),
      computation = c("assumption.china.standard", "assumption.row.standard"),
      order = c(1L, 2L), stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      names = c("china", "row"),
      computation = c("china/china.R", "row/row.R"),
      order = c(1L, 2L), stringsAsFactors = FALSE
    )
  }
  write_semicolon(assumptions, file.path(root, "_method_assumptions.csv"))
  matrices <- if (candidate) {
    data.frame(
      names = c(
        "matrix.capital", "matrix.consumption_basket",
        "matrix.transfers_values", "matrix.values"
      ),
      computation = c(
        "matrix.capital.standard", "matrix.basket.international",
        "matrix.transfers", "matrix.transformation"
      ), order = 1:4, stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      names = c("k_composition", "k_depreciation", "transfers_values", "values"),
      computation = c(
        "source/euklems.R", "source/depreciation.R", "transfers.R",
        "transformation.R"
      ), order = 1:4, stringsAsFactors = FALSE
    )
  }
  write_semicolon(matrices, file.path(root, "_method_matrices.csv"))
  solutions <- if (candidate) {
    data.frame(
      names = c("gross_output.s.mv", "value.m.mv"),
      sector_solution = c("indicator.gross_output", "indicator.value"),
      country_solution = c("sum", "aggregation.value"),
      stage = c(4L, 5L), order = c(2L, 1L), stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      names = c("gross_output.s.mv", "value.m.mv"),
      sector_solution = c("GO", "common/value.R"),
      country_solution = c("sum", "common/value-country.R"),
      stage = c(0L, 5L), order = c(1L, 1L), stringsAsFactors = FALSE
    )
  }
  write_semicolon(solutions, file.path(root, "_method_solutions.csv"))
  checks <- data.frame(
    method = "fixture",
    check_id = c(
      "aggregation_contract",
      if (candidate) "nonfinite_resolution" else "aggregation_legacy_adapter",
      "leontief_diagnostics"
    ),
    artifact = c("_unit_contract.csv", "_anomalies.csv",
      "_leontief_diagnostics.csv"),
    indicator = "",
    scope = if (candidate) c("native", "native", "all years") else
      c("legacy", "legacy", "1995:1996"),
    status = "pass",
    observations = c(if (candidate) "1" else "0", "1", "2"),
    maximum_absolute_error = "",
    maximum_scaled_error = "",
    tolerance = "exact",
    detail = if (candidate) "native module ids" else "legacy script paths",
    stringsAsFactors = FALSE, check.names = FALSE
  )
  write_semicolon(checks, file.path(root, "_scientific_checks.csv"))
  anomaly_columns <- wlv13_cross_engine_schema("_anomalies.csv")
  core <- data.frame(
    artifact = c("m_io", "sea_countries"),
    indicator = c("gross_output", "value.m.mv"),
    checkpoint = c("after_stage_4", "after_stage_5"),
    stage = c("4", "5"),
    module = if (candidate) {
      c("indicator.gross_output", "indicator.value")
    } else {
      c("common/gross_output.R", "common/value-country.R")
    },
    year = "1995", country = "A", sector = c("S", ""), output = "A.S",
    original_value = c("Inf", "0"),
    policy_id = if (candidate) {
      c("wiodr13_v09_leontief_zero_output_v1", "wiodr13_v1")
    } else {
      c("wiodr13_leontief_zero_output_v1", "wiodr13_v1")
    },
    action = c("allowlisted_nonzero_over_zero", "mark_not_applicable"),
    stringsAsFactors = FALSE, check.names = FALSE
  )
  if (candidate) {
    resolution <- core[1L, , drop = FALSE]
    resolution$indicator <- "wage.r.pc"
    resolution$checkpoint <- "after_stage_2"
    resolution$stage <- "2"
    resolution$module <- "indicator.wage"
    resolution$original_value <- "NaN"
    resolution$policy_id <- "fixture_nonfinite_v1"
    resolution$action <- "replace_zero_denominator_with_zero"
    anomalies <- rbind(core, resolution)
  } else {
    # The legacy child appends an identical stage-five diagnostic generation.
    anomalies <- rbind(core, core[2L, , drop = FALSE])
  }
  if (identical(mutation, "anomaly_stage4_duplicate")) {
    anomalies <- rbind(anomalies, core[1L, , drop = FALSE])
  }
  if (identical(mutation, "anomaly_missing")) {
    anomalies <- anomalies[anomalies$indicator != "value.m.mv", , drop = FALSE]
  }
  anomalies <- anomalies[anomaly_columns]
  write_semicolon(anomalies, file.path(root, "_anomalies.csv"))
  unit <- cross_unit(candidate)
  if (identical(mutation, "unit")) unit$source_unit <- "changed_unit"
  write_semicolon(unit, file.path(root, "_unit_contract.csv"))
  if (candidate) {
    diagnostic_columns <- wlv13_cross_engine_schema(
      "_nonfinite_resolution_diagnostics.csv"
    )
    diagnostic <- data.frame(
      method = "fixture", scientific_profile = "fixture_science_v1",
      nonfinite_resolution_profile = "fixture_nonfinite_v1",
      action = "replace_zero_denominator_with_zero",
      module = "indicator.wage", binding = "wage",
      indicator = "wage.r.pc", kind = "NaN", resolved_count = "1",
      coordinate_sha256 = strrep("a", 64L),
      stringsAsFactors = FALSE, check.names = FALSE
    )
    write_semicolon(diagnostic[diagnostic_columns], file.path(
      root, "_nonfinite_resolution_diagnostics.csv"
    ))
  }
  if (identical(mutation, "unexpected_extra")) {
    write_semicolon(data.frame(value = "unexpected"), file.path(
      root, "_unexpected.csv"
    ))
  }
  paths <- sort(list.files(root), method = "radix")
  roles <- vapply(paths, function(path) {
    if (grepl("[.]fst[.]meta$", path)) return("array_metadata")
    if (grepl("[.]fst$", path)) return("array")
    if (path %in% c(
      "_anomalies.csv", "_scientific_checks.csv",
      "_leontief_diagnostics.csv", "_nonfinite_resolution_diagnostics.csv"
    )) return("diagnostic")
    if (path %in% c("_states.csv", "_unit_contract.csv")) return("contract")
    "metadata"
  }, character(1L))
  list(paths = paths, roles = roles)
}
cross_inventory <- function(root, record, id) {
  manifest <- file.path(cross_root, paste0(id, ".json"))
  wlv13_create_snapshot(root, record$paths, record$roles, id, manifest)
  value <- wlv13_snapshot_inventory(manifest)
  value$kind <- "run"
  value$identity <- list(
    method = "fixture",
    output_contract = list(id = "wlvpanel-output", version = "1.0.0")
  )
  value
}
cross_baseline_root <- file.path(cross_root, "baseline")
cross_candidate_root <- file.path(cross_root, "candidate")
cross_baseline_record <- write_cross_run(cross_baseline_root, candidate = FALSE)
cross_candidate_record <- write_cross_run(cross_candidate_root, candidate = TRUE)
cross_baseline <- cross_inventory(
  cross_baseline_root,
  cross_baseline_record,
  "cross/baseline"
)
cross_candidate <- cross_inventory(
  cross_candidate_root,
  cross_candidate_record,
  "cross/candidate"
)
cross_pass <- wlv13_compare_inventories(
  cross_candidate, cross_baseline, 2L, "selftest/cross-engine-v3-pass",
  comparison_mode = "cross_engine_run_v3"
)
assert(cross_pass$passed,
  "Closed cross-engine architectural normalization did not pass."
)
assert(length(cross_pass$architecture_differences) >= 1L &&
    identical(cross_pass$allowed_candidate_only_artifacts,
      list("file:_nonfinite_resolution_diagnostics.csv")),
  "Cross-engine architectural evidence was not recorded."
)
cross_strict <- wlv13_compare_inventories(
  cross_candidate, cross_baseline, 2L, "selftest/cross-engine-strict-fail"
)
assert(!cross_strict$passed,
  "Strict within-engine comparison accepted architectural differences."
)
for (mutation in c(
  "array", "gfcf", "leontief", "unit", "unexpected_extra",
  "anomaly_stage4_duplicate", "anomaly_missing"
)) {
  mutation_root <- file.path(cross_root, paste0("candidate-", mutation))
  mutation_record <- write_cross_run(
    mutation_root, candidate = TRUE, mutation = mutation
  )
  mutation_inventory <- cross_inventory(
    mutation_root,
    mutation_record,
    paste0("cross/candidate-", mutation)
  )
  mutation_result <- wlv13_compare_inventories(
    mutation_inventory, cross_baseline, 2L,
    paste0("selftest/cross-engine-v3-", mutation, "-fail"),
    comparison_mode = "cross_engine_run_v3"
  )
  assert(!mutation_result$passed,
    sprintf("Cross-engine v3 accepted scientific mutation `%s`.", mutation)
  )
}

aggregate_root <- file.path(temporary_root, "aggregate")
evidence_root <- file.path(aggregate_root, "evidence")
artifact_root <- file.path(aggregate_root, "artifacts")
project_roots <- file.path(aggregate_root, c("baseline-project", "candidate-project"))
dir.create(evidence_root, recursive = TRUE)
dir.create(artifact_root, recursive = TRUE)
invisible(lapply(project_roots, dir.create, recursive = TRUE))
names(project_roots) <- wlv13_arms
git_fixture_commit <- function(root, arm) {
  run_git <- function(arguments) {
    value <- system2("git", c("-C", root, arguments),
      stdout = TRUE, stderr = TRUE
    )
    status <- attr(value, "status", exact = TRUE)
    if (!is.null(status) && !identical(status, 0L)) {
      stop(sprintf("Synthetic Git command failed for `%s`: %s.", arm,
        paste(value, collapse = " ")
      ), call. = FALSE)
    }
    invisible(value)
  }
  run_git(c("init", "--quiet"))
  run_git(c("config", "user.name", "Issue13Selftest"))
  run_git(c("config", "user.email", "issue13-selftest@example.invalid"))
  write_text(paste0("Package: wlvselftest", arm),
    file.path(root, "DESCRIPTION")
  )
  run_git(c("add", "DESCRIPTION"))
  run_git(c("commit", "--quiet", "-m", paste0("selftest-", arm)))
  wlv13_git_commit(root)
}
commits <- vapply(names(project_roots), function(arm) {
  git_fixture_commit(project_roots[[arm]], arm)
}, character(1L))
seed_commits <- commits

safe_id <- function(value) gsub("[^A-Za-z0-9._-]", "__", value)
artifact_records <- function(root, paths, roles) {
  records <- wlv13_capture_records(root, paths, roles)
  lapply(seq_len(nrow(records)), function(index) {
    as.list(records[index, , drop = FALSE])
  })
}

make_run <- function(arm, phase, method, payload, parent = NULL) {
  id <- paste(arm, phase, sep = "/")
  root <- file.path(artifact_root, "runs", safe_id(id))
  dir.create(root, recursive = TRUE)
  write_text(payload, file.path(root, "payload.txt"))
  run_id <- paste0("run-", substr(wlv13_sha256_text(id), 1L, 24L))
  result_id <- wlv13_sha256_text(paste0("result|", id, "|", payload))
  request <- if (startsWith(phase, "recalculate/")) {
    expectation <- wlv13_recalculation_expectation(phase)
    list(
      mode = "recalculate", method = method, workers = 1L,
      at_stage = expectation$stage,
      sea_vars = if (is.null(expectation$sea_vars)) NULL else
        as.list(expectation$sea_vars)
    )
  } else {
    list(
      mode = "calculate", method = method,
      workers = if (endsWith(phase, "workers2")) 2L else 1L,
      at_stage = NULL, sea_vars = NULL
    )
  }
  manifest <- list(
    schema = "wlv-run-manifest",
    schema_version = 1L,
    run_id = run_id,
    result_id = result_id,
    created_at_utc = "2026-01-01T00:00:00.000Z",
    parent_run_id = if (is.null(parent)) NULL else parent$run_id,
    method = method,
    output_contract = list(id = "wlvpanel-output", version = "1.0.0"),
    result = list(request = request),
    execution = list(duration_seconds = 1),
    artifacts = artifact_records(root, "payload.txt", "metadata")
  )
  manifest_path <- file.path(root, "run_manifest.json")
  wlv13_json_write(manifest, manifest_path)
  inventory <- wlv13_run_inventory(root)
  list(
    kind = "run",
    root = root,
    manifest_path = manifest_path,
    manifest_sha256 = inventory$manifest_sha256,
    inventory_sha256 = wlv13_inventory_signature(inventory),
    run_id = run_id,
    result_id = result_id,
    parent_run_id = if (is.null(parent)) NULL else parent$run_id,
    release_id = paste0("release-", substr(wlv13_sha256_text(id), 1L, 20L)),
    method = method,
    request = request
  )
}

make_source <- function(arm, source) {
  root <- file.path(artifact_root, "sources", arm, source)
  dir.create(root, recursive = TRUE)
  write_text(paste(source, "normalized"), file.path(root, "payload.txt"))
  record <- wlv13_capture_records(root, "payload.txt", "normalized_data")
  manifest <- data.frame(
    schema_version = "1",
    source_generation_id = paste0(arm, "-", source, "-generation"),
    contract_id = paste0(source, "-contract"),
    contract_version = "1.0.0",
    contract_sha256 = wlv13_sha256_text(paste0(source, "-contract")),
    artifact = record$path,
    artifact_role = record$role,
    size_bytes = format(record$size_bytes, scientific = FALSE, trim = TRUE),
    sha256 = record$sha256,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  utils::write.csv(manifest, file.path(root, "_source_manifest.csv"),
    row.names = FALSE, fileEncoding = "UTF-8", quote = TRUE
  )
  inventory <- wlv13_source_inventory(root)
  list(
    kind = "source", source = source, root = root,
    manifest_path = inventory$manifest_path,
    manifest_sha256 = inventory$manifest_sha256,
    inventory_sha256 = wlv13_inventory_signature(inventory),
    identity = inventory$identity
  )
}

make_euklems <- function(arm, directory) {
  root <- file.path(artifact_root, "euklems", arm)
  dir.create(root, recursive = TRUE)
  write_text("euklems", file.path(root, "euklems.txt"))
  manifest_path <- file.path(directory, "euklems-snapshot.json")
  inventory <- wlv13_create_snapshot(
    root, "euklems.txt", "euklems_table", paste0(arm, "/euklems"),
    manifest_path
  )
  list(
    kind = "snapshot", source = "euklems", root = root,
    manifest_path = inventory$manifest_path,
    manifest_sha256 = inventory$manifest_sha256,
    inventory_sha256 = wlv13_inventory_signature(inventory),
    identity = inventory$identity
  )
}

make_release <- function(arm) {
  root <- file.path(artifact_root, "releases", arm)
  dir.create(root, recursive = TRUE)
  write_text("paper zero semantic workbook fixture",
    file.path(root, "paper.txt")
  )
  release_id <- paste0("release-paper-", arm)
  manifest <- list(
    schema = "wlv-release-manifest",
    schema_version = 1L,
    release_id = release_id,
    channel = paste0("selftest-", arm),
    sequence = 1L,
    created_at_utc = "2026-01-01T00:00:00.000Z",
    metadata = list(methods = as.list(wlv13_paper0_methods)),
    runs = list(),
    artifacts = artifact_records(root, "paper.txt", "paper")
  )
  manifest_path <- file.path(root, "release_manifest.json")
  wlv13_json_write(manifest, manifest_path)
  inventory <- wlv13_release_inventory(root)
  list(
    kind = "release", root = root, manifest_path = manifest_path,
    manifest_sha256 = inventory$manifest_sha256,
    inventory_sha256 = wlv13_inventory_signature(inventory),
    release_id = release_id, paper_path = "paper.txt"
  )
}

scenario_directories <- list()
scenario_reports <- list()
scenario_paths <- list()
write_process_evidence <- function(id, project_root, workers, directory,
                                   elapsed) {
  stdout <- write_text("synthetic stdout", file.path(directory, "stdout.log"))
  stderr <- write_text(character(), file.path(directory, "stderr.log"))
  samples <- write_text(
    "sample_at_utc,pid,parent_pid,name,created_at_utc,working_set_bytes,private_bytes,cpu_seconds",
    file.path(directory, "process-samples.csv")
  )
  spec_path <- file.path(directory, "process-spec.json")
  spec <- list(
    schema = "wlv-issue13-process-spec/1",
    scenario_id = id,
    executable = "Rscript",
    arguments = list("--vanilla"),
    working_directory = project_root,
    environment = renv_environment,
    expected_exit_codes = list(0L),
    timeout_seconds = 60,
    sample_interval_ms = 100L,
    shutdown_grace_seconds = 2,
    expected_worker_processes = workers
  )
  wlv13_json_write(spec, spec_path)
  metrics <- list(
    schema = "wlv-issue13-process-metrics/2",
    scenario_id = id,
    status = "passed", passed = TRUE,
    executable = "Rscript", arguments = list("--vanilla"),
    working_directory = project_root,
    root_pid = 100L, exit_code = 0L, expected_exit_codes = list(0L),
    exit_code_matched = TRUE, timed_out = FALSE, timeout_seconds = 60,
    started_at_utc = "2026-01-01T00:00:00.000Z",
    finished_at_utc = "2026-01-01T00:00:10.000Z",
    elapsed_seconds = elapsed,
    sample_interval_ms = 100L, samples = 1L,
    peak_rss_bytes = 100 * 1024^2,
    peak_private_bytes = 110 * 1024^2,
    cumulative_cpu_seconds_peak = 1,
    max_concurrent_processes = workers + 1L,
    expected_worker_processes = workers,
    max_concurrent_worker_processes = workers,
    worker_count_matched = TRUE, cluster_closed = TRUE,
    lingering_pids = list(), observed_processes = list(),
    stdout_path = stdout, stderr_path = stderr,
    stdout_sha256 = wlv13_sha256_file(stdout),
    stderr_sha256 = wlv13_sha256_file(stderr),
    samples_path = samples, samples_sha256 = wlv13_sha256_file(samples),
    process_spec_path = spec_path,
    process_spec_sha256 = wlv13_sha256_file(spec_path)
  )
  wlv13_json_write(metrics, file.path(directory, "process-metrics.json"))
}

write_scenario <- function(id, kind, request, outputs, seed = NULL,
                           error = NULL) {
  arm <- strsplit(id, "/", fixed = TRUE)[[1L]][[1L]]
  suffix <- sub("^(baseline|candidate)/", "", id)
  scenario_commit <- if (grepl(
    "^calculate/[a-z][a-z0-9_]*/workers1$", suffix
  )) seed_commits[[arm]] else commits[[arm]]
  directory <- file.path(evidence_root, "scenarios", safe_id(id))
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  report <- list(
    schema = wlv13_schema$scenario,
    scenario_id = id,
    status = "passed", passed = TRUE, kind = kind,
    project_root = project_roots[[arm]],
    expected_commit = scenario_commit, observed_commit = scenario_commit,
    started_at = "2026-01-01T00:00:00.000Z",
    finished_at = "2026-01-01T00:00:10.000Z",
    elapsed_seconds = 9,
    request = request, outputs = outputs, seed = seed,
    publication_before = list(), publication_after = list(),
    source_before = list(), source_after = list(), error = error
  )
  report_path <- file.path(directory, "scenario-result.json")
  wlv13_json_write(report, report_path)
  workers <- if (grepl("/workers2$", id)) 2L else 0L
  elapsed <- if (identical(arm, "baseline")) 10 else 11
  if (startsWith(id, "candidate/fault/")) elapsed <- 1
  write_process_evidence(id, project_roots[[arm]], workers, directory, elapsed)
  scenario_directories[[id]] <<- directory
  scenario_reports[[id]] <<- report
  scenario_paths[[id]] <<- report_path
  invisible(report)
}

phase_outputs <- list()
for (arm in wlv13_arms) {
  for (method in wlv13_methods) {
    phase <- wlv13_calculate_phase(method, 1L)
    output <- make_run(arm, phase, method, paste(method, "full", sep = "|"))
    id <- paste0(arm, "/", phase)
    request <- list(
      method = method, methods = as.list(method), channel = "selftest",
      workers = 1L, at_stage = NULL, sea_vars = NULL, paper = NULL,
      expected_failure = FALSE
    )
    write_scenario(id, "calculate", request, list(output))
    phase_outputs[[id]] <- output
  }
}

for (arm in wlv13_arms) {
  for (method in wlv13_methods) {
    full_id <- paste0(arm, "/", wlv13_calculate_phase(method, 1L))
    full <- phase_outputs[[full_id]]
    for (phase in wlv13_recalculation_phases(method)) {
      expectation <- wlv13_recalculation_expectation(phase)
      divergent <- identical(method, "alternative_2") &&
        identical(expectation$stage, 1L) &&
        identical(expectation$variant, "full")
      payload <- if (divergent) paste(method, "baseline-known-stage1", sep = "|") else
        paste(method, "full", sep = "|")
      output <- make_run(arm, phase, method, payload, parent = full)
      id <- paste0(arm, "/", phase)
      proof_path <- scenario_paths[[full_id]]
      seed <- list(
        proof_path = proof_path,
        proof_sha256 = wlv13_sha256_file(proof_path),
        expected_seed_commit = seed_commits[[arm]],
        expected = full,
        observed_before = full,
        seed_release_id = paste0("seed-", safe_id(id))
      )
      request <- list(
        method = method, methods = as.list(method), channel = "selftest",
        workers = 1L, at_stage = expectation$stage,
        sea_vars = if (is.null(expectation$sea_vars)) NULL else
          as.list(expectation$sea_vars),
        paper = NULL, expected_failure = FALSE
      )
      write_scenario(id, "recalculate", request, list(output), seed = seed)
      phase_outputs[[id]] <- output
    }
  }
  for (method in c("wiodr13", "wiodr16")) {
    phase <- wlv13_calculate_phase(method, 2L)
    output <- make_run(arm, phase, method, paste(method, "full", sep = "|"))
    id <- paste0(arm, "/", phase)
    request <- list(
      method = method, methods = as.list(method), channel = "selftest",
      workers = 2L, at_stage = NULL, sea_vars = NULL, paper = NULL,
      expected_failure = FALSE
    )
    write_scenario(id, "calculate", request, list(output))
    phase_outputs[[id]] <- output
  }

  prepare_id <- paste0(arm, "/prepare/all")
  prepare_directory <- file.path(evidence_root, "scenarios", safe_id(prepare_id))
  dir.create(prepare_directory, recursive = TRUE, showWarnings = FALSE)
  prepare_outputs <- list(
    make_source(arm, "wiodr13"),
    make_source(arm, "wiodr16"),
    make_euklems(arm, prepare_directory)
  )
  request <- list(
    method = NULL, methods = as.list(c("wiodr13", "wiodr16")),
    channel = "selftest", workers = 1L, at_stage = NULL,
    sea_vars = NULL, paper = NULL, expected_failure = FALSE
  )
  write_scenario(prepare_id, "prepare", request, prepare_outputs)
  for (output in prepare_outputs) {
    phase_outputs[[paste0(arm, "/prepare/", output$source)]] <- output
  }

  paper_id <- paste0(arm, "/paper/0")
  release_output <- make_release(arm)
  request <- list(
    method = NULL, methods = as.list(wlv13_paper0_methods),
    channel = "selftest", workers = 1L, at_stage = NULL,
    sea_vars = NULL, paper = 0L, expected_failure = FALSE
  )
  write_scenario(paper_id, "paper0", request, list(release_output))
  phase_outputs[[paste0(arm, "/paper/0")]] <- release_output
}

for (index in seq_along(wlv13_fault_names)) {
  fault_id <- wlv13_fault_names[[index]]
  id <- paste0("candidate/fault/", fault_id)
  token <- paste0("issue13-injected-selftest-", gsub("-", "", fault_id))
  fault_kind <- wlv13_fault_bindings$kind[[index]]
  request <- list(
    method = if (identical(fault_kind, "prepare_euklems")) NULL else "wiodr13",
    methods = if (identical(fault_kind, "prepare_euklems")) list() else
      as.list("wiodr13"),
    channel = "selftest", workers = 1L, at_stage = NULL,
    sea_vars = NULL, paper = NULL, expected_failure = TRUE
  )
  write_scenario(id, fault_kind, request, NULL, error = token)
  fault <- list(
    schema = wlv13_schema$fault,
    scenario_id = id,
    status = "passed", passed = TRUE,
    fault_id = fault_id,
    binding = wlv13_fault_bindings$binding[[index]],
    when = wlv13_fault_bindings$when[[index]],
    call = wlv13_fault_bindings$call[[index]],
    checkpoint = if (is.na(wlv13_fault_bindings$checkpoint[[index]])) NULL else
      wlv13_fault_bindings$checkpoint[[index]],
    binding_call_count = wlv13_fault_bindings$call[[index]],
    injected = TRUE,
    expected_failure_observed = TRUE,
    expected_error_matched = TRUE,
    channel_marker_unchanged = TRUE,
    no_partial_release_visible = TRUE,
    staging_clean = TRUE,
    preparation_staging_clean = TRUE,
    normalized_generation_unchanged = TRUE,
    previous_release_verified = TRUE,
    error = token
  )
  wlv13_json_write(fault,
    file.path(scenario_directories[[id]], "fault-result.json")
  )
}

write_comparison <- function(id, left, right, passed) {
  directory <- file.path(evidence_root, "comparisons", safe_id(id))
  dir.create(directory, recursive = TRUE)
  artifacts <- if (identical(id, "parity/paper/0")) {
    list(list(
      key = "file:paper.xlsx",
      type = "xlsx",
      passed = passed,
      schema = "wlv-issue13-paper0-workbook-comparison/1",
      comparison_mode = "ooxml-semantic",
      sheet_names_identical = passed,
      sheet_states_identical = passed,
      package_entry_names_identical = passed,
      package_semantics_identical = passed,
      core_properties_identical_after_timestamp_normalization = passed,
      changed_package_entries = list(),
      baseline_only_sheets = list(),
      candidate_only_sheets = list(),
      sheets = list(summary = list(passed = passed)),
      mismatch_count = if (passed) 0L else 1L
    ))
  } else {
    list(list(
      key = "file:payload.txt", passed = passed,
      mismatch_count = if (passed) 0L else 1L
    ))
  }
  report <- list(
    schema = wlv13_schema$comparison,
    scenario_id = id,
    status = if (passed) "passed" else "failed",
    passed = passed,
    compared_at = "2026-01-01T00:00:00.000Z",
    candidate = list(inventory_sha256 = left$inventory_sha256),
    baseline = list(inventory_sha256 = right$inventory_sha256),
    artifacts = artifacts,
    policy_exceptions = list()
  )
  path <- file.path(directory, "comparison.json")
  wlv13_json_write(report, path)
  path
}

for (phase in wlv13_parity_phases()) {
  write_comparison(
    paste0("parity/", phase),
    phase_outputs[[paste0("candidate/", phase)]],
    phase_outputs[[paste0("baseline/", phase)]],
    TRUE
  )
}
for (arm in wlv13_arms) {
  for (method in c("wiodr13", "wiodr16")) {
    write_comparison(
      paste0("equivalence/", arm, "/calculate/", method,
        "/workers2-vs-workers1"),
      phase_outputs[[paste0(arm, "/", wlv13_calculate_phase(method, 2L))]],
      phase_outputs[[paste0(arm, "/", wlv13_calculate_phase(method, 1L))]],
      TRUE
    )
  }
  for (method in wlv13_methods) {
    full <- phase_outputs[[paste0(arm, "/", wlv13_calculate_phase(method, 1L))]]
    for (phase in wlv13_recalculation_phases(method)) {
      expectation <- wlv13_recalculation_expectation(phase)
      divergent <- identical(method, "alternative_2") &&
        identical(expectation$stage, 1L) &&
        identical(expectation$variant, "full")
      write_comparison(
        paste0("oracle/", arm, "/", phase),
        phase_outputs[[paste0(arm, "/", phase)]], full, !divergent
      )
    }
  }
}

baseline_index_path <- file.path(aggregate_root, "baseline-runtime-index.json")
baseline_profile <- list(
  schema = wlv13_schema$validation_profile,
  id = "strict-selftest",
  inventory_value = "strict-cc2",
  source_commit = commits[["baseline"]],
  runtime_commit = commits[["baseline"]],
  run_dirty = FALSE,
  overlay_patch_path = NULL,
  overlay_patch_sha256 = NULL,
  overlay_patch_id = NULL
)
baseline_scenario_ids <- sort(wlv13_scenario_ids()[
  startsWith(wlv13_scenario_ids(), "baseline/")
], method = "radix")
baseline_index <- list(
  schema = wlv13_schema$baseline_runtime_index,
  baseline_base_commit = commits[["baseline"]],
  created_at = "2026-01-01T00:00:00.000Z",
  profiles = list(baseline_profile),
  scenarios = lapply(baseline_scenario_ids, function(id) {
    list(
      scenario_id = id,
      runtime_commit = commits[["baseline"]],
      profile_id = baseline_profile$id
    )
  })
)
wlv13_json_write(baseline_index, baseline_index_path)
baseline_index_sha256 <- wlv13_sha256_file(baseline_index_path)
validated_baseline_index <- wlv13_read_baseline_runtime_index(
  baseline_index_path, baseline_index_sha256, commits[["baseline"]]
)
wlv13_validate_baseline_runtime_matrix(
  validated_baseline_index, commits[["candidate"]]
)

candidate_collision <- validated_baseline_index
candidate_collision$scenarios[[1L]]$runtime_commit <- commits[["candidate"]]
assert_error(
  wlv13_validate_baseline_runtime_matrix(
    candidate_collision, commits[["candidate"]]
  ),
  "must not reference the candidate commit",
  "Runtime index accepted the candidate commit on the baseline arm."
)

mixed_method <- validated_baseline_index
mixed_id <- paste0(
  "baseline/", wlv13_recalculation_phases("wiodr13")[[1L]]
)
mixed_method$scenarios[[mixed_id]]$profile_id <- "different-profile"
assert_error(
  wlv13_validate_baseline_runtime_matrix(
    mixed_method, commits[["candidate"]]
  ),
  "must share one profile and commit",
  "Runtime index accepted mixed profiles within one method."
)

missing_index <- baseline_index
missing_index$scenarios <- missing_index$scenarios[-length(missing_index$scenarios)]
missing_index_path <- file.path(aggregate_root, "baseline-index-missing.json")
wlv13_json_write(missing_index, missing_index_path)
assert_error(
  wlv13_read_baseline_runtime_index(
    missing_index_path, wlv13_sha256_file(missing_index_path),
    commits[["baseline"]]
  ),
  "coverage differs",
  "Runtime index accepted a missing baseline scenario."
)

extra_index <- baseline_index
extra_index$scenarios[[length(extra_index$scenarios) + 1L]] <- list(
  scenario_id = "baseline/z-extra",
  runtime_commit = commits[["baseline"]],
  profile_id = baseline_profile$id
)
extra_index_path <- file.path(aggregate_root, "baseline-index-extra.json")
wlv13_json_write(extra_index, extra_index_path)
assert_error(
  wlv13_read_baseline_runtime_index(
    extra_index_path, wlv13_sha256_file(extra_index_path),
    commits[["baseline"]]
  ),
  "coverage differs",
  "Runtime index accepted an extra baseline scenario."
)

aggregate_output <- file.path(aggregate_root, "output-pass")
command <- file.path(R.home("bin"), "Rscript.exe")
arguments <- c(
  "--vanilla", file.path(script_dir, "issue13-aggregate.R"),
  "--evidence-root", evidence_root,
  "--output", aggregate_output,
  "--baseline-base-commit", commits[["baseline"]],
  "--candidate-commit", commits[["candidate"]],
  "--candidate-seed-commit", seed_commits[["candidate"]],
  "--baseline-runtime-index", baseline_index_path,
  "--baseline-runtime-index-sha256", baseline_index_sha256
)
status <- system2(command, shQuote(arguments), stdout = TRUE, stderr = TRUE)
exit_status <- attr(status, "status", exact = TRUE)
if (is.null(exit_status)) exit_status <- 0L
assert(identical(exit_status, 0L), paste(
  "Complete synthetic aggregate failed:", paste(status, collapse = "\n")
))
aggregate <- wlv13_json_read(file.path(aggregate_output, "aggregate.json"),
  simplify = FALSE
)
assert(isTRUE(aggregate$passed), "Synthetic aggregate did not pass.")
classifications <- vapply(aggregate$oracle_classification, `[[`,
  character(1L), "classification"
)
assert(sum(classifications == "baseline-known-divergence") == 1L,
  "Scenario-specific baseline oracle classification was not preserved."
)

run_negative_aggregate <- function(label, mutate, restore, category) {
  negative_output <- file.path(aggregate_root, paste0("output-", label))
  negative_arguments <- arguments
  negative_arguments[[which(negative_arguments == aggregate_output)]] <-
    negative_output
  mutate()
  on.exit(restore(), add = TRUE)
  negative_status <- suppressWarnings(system2(
    command, shQuote(negative_arguments), stdout = TRUE, stderr = TRUE
  ))
  negative_exit <- attr(negative_status, "status", exact = TRUE)
  if (is.null(negative_exit)) negative_exit <- 0L
  assert(!identical(negative_exit, 0L),
    sprintf("Aggregate accepted negative fixture `%s`.", label)
  )
  negative_report <- wlv13_json_read(
    file.path(negative_output, "aggregate.json"), simplify = FALSE
  )
  assert(!isTRUE(negative_report$passed),
    sprintf("Negative aggregate `%s` was marked passed.", label)
  )
  negative_checks <- utils::read.csv(
    file.path(negative_output, "checks.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  assert(any(negative_checks$category == category & !negative_checks$passed),
    sprintf("Negative aggregate `%s` did not fail `%s`.", label, category)
  )
  invisible(negative_report)
}

replace_scenario <- function(path, mutate) {
  original_size <- file.info(path)$size
  original <- readBin(path, what = "raw", n = original_size)
  original_value <- wlv13_json_read(path, simplify = FALSE)
  write_bytes <- function(bytes) {
    connection <- file(path, open = "wb")
    tryCatch(
      writeBin(bytes, connection),
      finally = close(connection)
    )
  }
  write_value <- function(value) {
    payload <- charToRaw(enc2utf8(paste0(jsonlite::toJSON(
      value,
      auto_unbox = TRUE,
      pretty = TRUE,
      digits = NA,
      null = "null",
      na = "string"
    ), "\n")))
    write_bytes(payload)
    invisible(wlv13_json_read(path, simplify = FALSE))
  }
  changed <- mutate(original_value)
  write_value(changed)
  function() write_bytes(original)
}

# The final gate is native-only. Any execution mode or authentication payload
# is rejected on both arms, including null and unknown values.
candidate_mode_path <- scenario_paths[[
  "candidate/calculate/wiodr13/workers1"
]]
candidate_restore <- NULL
run_negative_aggregate(
  "candidate-import-mode",
  mutate = function() {
    candidate_restore <<- replace_scenario(candidate_mode_path, function(value) {
      value$execution_mode <- "authenticated_import"
      value
    })
  },
  restore = function() candidate_restore(),
  category = "execution-mode"
)

baseline_mode_path <- scenario_paths[[
  "baseline/calculate/wiodr13/workers1"
]]
baseline_import_restore <- NULL
run_negative_aggregate(
  "baseline-import-mode",
  mutate = function() {
    baseline_import_restore <<- replace_scenario(
      baseline_mode_path,
      function(value) {
        value$execution_mode <- "authenticated_import"
        value
      }
    )
  },
  restore = function() baseline_import_restore(),
  category = "execution-mode"
)

null_restore <- NULL
run_negative_aggregate(
  "baseline-null-mode",
  mutate = function() {
    null_restore <<- replace_scenario(baseline_mode_path, function(value) {
      value["execution_mode"] <- list(NULL)
      value
    })
  },
  restore = function() null_restore(),
  category = "execution-mode"
)

baseline_auth_restore <- NULL
run_negative_aggregate(
  "baseline-authentication",
  mutate = function() {
    baseline_auth_restore <<- replace_scenario(
      baseline_mode_path,
      function(value) {
        value$authentication <- list(schema = "forbidden-selftest")
        value
      }
    )
  },
  restore = function() baseline_auth_restore(),
  category = "execution-mode"
)

candidate_auth_restore <- NULL
run_negative_aggregate(
  "candidate-authentication",
  mutate = function() {
    candidate_auth_restore <<- replace_scenario(
      candidate_mode_path,
      function(value) {
        value$authentication <- list(schema = "forbidden-selftest")
        value
      }
    )
  },
  restore = function() candidate_auth_restore(),
  category = "execution-mode"
)

unknown_restore <- NULL
run_negative_aggregate(
  "baseline-unknown-mode",
  mutate = function() {
    unknown_restore <<- replace_scenario(baseline_mode_path, function(value) {
      value$execution_mode <- "historical_copy"
      value
    })
  },
  restore = function() unknown_restore(),
  category = "execution-mode"
)

# Native-only mode cannot bypass the existing process-evidence completeness or
# byte authentication gates.
baseline_directory <- scenario_directories[[
  "baseline/calculate/wiodr13/workers1"
]]
metrics_path <- file.path(baseline_directory, "process-metrics.json")
metrics_backup <- paste0(metrics_path, ".selftest-backup")
run_negative_aggregate(
  "missing-process-metrics",
  mutate = function() {
    assert(file.rename(metrics_path, metrics_backup),
      "Could not hide process metrics for the negative fixture."
    )
  },
  restore = function() {
    assert(file.rename(metrics_backup, metrics_path),
      "Could not restore process metrics after the negative fixture."
    )
  },
  category = "completeness"
)

stdout_path <- file.path(baseline_directory, "stdout.log")
stdout_original <- readBin(stdout_path, what = "raw", n = file.info(stdout_path)$size)
run_negative_aggregate(
  "tampered-process-log",
  mutate = function() {
    connection <- file(stdout_path, open = "ab")
    tryCatch(writeBin(charToRaw("tampered"), connection),
      finally = close(connection)
    )
  },
  restore = function() {
    connection <- file(stdout_path, open = "wb")
    tryCatch(writeBin(stdout_original, connection), finally = close(connection))
  },
  category = "process"
)

# Completeness is fail-closed: remove one exact comparison in the temporary
# fixture and require the second aggregate to fail.
missing_id <- "parity/calculate/wiodr13/workers1"
missing_path <- file.path(
  evidence_root, "comparisons", safe_id(missing_id), "comparison.json"
)
assert(unlink(missing_path, force = TRUE) == 0L,
  "Could not create the missing-evidence self-test."
)
aggregate_missing_output <- file.path(aggregate_root, "output-missing")
missing_arguments <- arguments
missing_arguments[[which(missing_arguments == aggregate_output)]] <-
  aggregate_missing_output
missing_status <- suppressWarnings(system2(
  command, shQuote(missing_arguments), stdout = TRUE, stderr = TRUE
))
missing_exit <- attr(missing_status, "status", exact = TRUE)
if (is.null(missing_exit)) missing_exit <- 0L
assert(!identical(missing_exit, 0L),
  "Aggregate accepted an incomplete comparison matrix."
)
missing_aggregate <- wlv13_json_read(
  file.path(aggregate_missing_output, "aggregate.json"), simplify = FALSE
)
assert(!isTRUE(missing_aggregate$passed),
  "Incomplete aggregate report was not marked failed."
)

cat("issue13 harness synthetic self-tests: PASS\n")
cat("  environment: explicit ten-field renv/R library binding\n")
cat("  comparator: diagnostic multiset + chunked NA/NaN state gate\n")
cat("  aggregate: 162 scenarios, 202 comparisons, one evidence-derived defect\n")
cat(paste0(
  "  fail-closed: invalid import modes, missing/tampered process evidence, ",
  "and missing comparison rejected\n"
))
