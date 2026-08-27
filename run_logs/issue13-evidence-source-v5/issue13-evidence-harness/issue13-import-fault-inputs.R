# Copy and authenticate prepared sources plus one immutable full-run seed into
# the isolated fault-gate worktree. This never writes to either source store.

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) stop("Run with Rscript.", call. = FALSE)
script_path <- normalizePath(
  sub("^--file=", "", script_argument[[1L]]),
  winslash = "/",
  mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())
sys.source(file.path(dirname(script_dir), "issue13-prep-paper-lib.R"),
  envir = environment()
)
sys.source(file.path(dirname(script_dir), "issue13-preparation-auth-lib.R"),
  envir = environment()
)

options <- wlv13_parse_cli(commandArgs(trailingOnly = TRUE))
wlv13_cli_required(options, c(
  "prepared_root", "preparation_comparison", "seed_project_root",
  "seed_result", "seed_commit", "fault_root", "candidate_commit",
  "method", "output"
))
wlv_gate_require_namespaces(c("jsonlite", "openssl"))

prepared_root <- wlv13_normalize_existing_dir(
  options$prepared_root, "prepared candidate root"
)
seed_project_root <- wlv13_normalize_existing_dir(
  options$seed_project_root, "seed project root"
)
fault_root <- wlv13_normalize_existing_dir(options$fault_root, "fault root")
comparison_path <- normalizePath(options$preparation_comparison,
  winslash = "/", mustWork = TRUE
)
seed_result_path <- normalizePath(options$seed_result,
  winslash = "/", mustWork = TRUE
)
seed_commit <- wlv13_scalar_text(options$seed_commit, "seed_commit",
  "^[0-9a-f]{40}$"
)
candidate_commit <- wlv13_scalar_text(options$candidate_commit,
  "candidate_commit", "^[0-9a-f]{40}$"
)
method <- wlv13_scalar_text(options$method, "method", "^[a-z][a-z0-9_]*$")
if (!identical(method, "wiodr13")) {
  stop("Fault gates must be seeded from the normative wiodr13 full run.",
    call. = FALSE
  )
}
output_requested <- normalizePath(options$output,
  winslash = "/", mustWork = FALSE
)
output_preexisted <- dir.exists(output_requested)
if (file.exists(output_requested) && !output_preexisted) {
  stop("Fault-input evidence path is not a directory.", call. = FALSE)
}
if (any(vapply(c(prepared_root, seed_project_root, fault_root), function(root) {
  wlv13_is_within(output_requested, root)
}, logical(1L)))) {
  stop("Fault-input evidence must be outside all evaluated worktrees.",
    call. = FALSE
  )
}
output <- if (output_preexisted) {
  normalizePath(output_requested, winslash = "/", mustWork = TRUE)
} else {
  wlv13_ensure_dir(output_requested, "fault-input evidence directory")
}
report_path <- file.path(output, "fault-input-import.json")
running_path <- file.path(output, "fault-input-import.running.json")
failed_path <- file.path(output, "fault-input-import.failed.json")
proof_path <- file.path(output, "imported-seed-scenario-result.json")
if (file.exists(report_path) || dir.exists(report_path) ||
    file.exists(failed_path) || dir.exists(failed_path)) {
  stop("Fault-input import already has terminal evidence.", call. = FALSE)
}
wlv13_import_json_temp_names <- function(entries, target) {
  prefix <- paste0(".", basename(target), "-")
  matches <- entries[startsWith(entries, prefix)]
  suffix <- substring(matches, nchar(prefix) + 1L)
  matches[nzchar(suffix) & grepl("^[0-9a-f]+$", suffix)]
}
proof_temp <- final_temp <- failed_temp <- character()
running_identity <- list(
  schema = "wlv-issue13-fault-input-import-running/1",
  status = "running",
  passed = FALSE,
  started_at = if (output_preexisted) NULL else wlv13_now(),
  prepared_root = prepared_root,
  preparation_comparison_path = comparison_path,
  preparation_comparison_sha256 = wlv13_sha256_file(comparison_path),
  seed_project_root = seed_project_root,
  seed_result_path = seed_result_path,
  seed_result_sha256 = wlv13_sha256_file(seed_result_path),
  fault_root = fault_root,
  candidate_commit = candidate_commit,
  seed_commit = seed_commit,
  method = method
)
if (!output_preexisted) {
  wlv13_json_write(running_identity, running_path)
} else {
  entries <- sort(list.files(output, all.files = TRUE, no.. = TRUE),
    method = "radix"
  )
  proof_temp <- wlv13_import_json_temp_names(entries, proof_path)
  final_temp <- wlv13_import_json_temp_names(entries, report_path)
  failed_temp <- wlv13_import_json_temp_names(entries, failed_path)
  if (any(lengths(list(proof_temp, final_temp, failed_temp)) > 1L) ||
      (length(final_temp) && length(failed_temp)) ||
      (length(proof_temp) && file.exists(proof_path)) ||
      (length(proof_temp) && length(failed_temp))) {
    stop("Interrupted fault-input JSON staging is ambiguous.", call. = FALSE)
  }
  allowed_entries <- c(
    "fault-input-import.running.json",
    "imported-seed-scenario-result.json",
    proof_temp,
    final_temp,
    failed_temp
  )
  if (!file.exists(running_path) || any(!entries %in% allowed_entries) ||
      any(vapply(file.path(output, entries), dir.exists, logical(1L)))) {
    stop("Interrupted fault-input evidence is non-canonical.", call. = FALSE)
  }
  if (length(final_temp) && !file.exists(proof_path)) {
    stop("Final import staging lacks its canonical imported proof.",
      call. = FALSE
    )
  }
  installed_running <- wlv13_json_read(running_path, simplify = FALSE)
  expected_names <- names(running_identity)
  running_identity$started_at <- installed_running$started_at
  if (!is.list(installed_running) ||
      !identical(names(installed_running), expected_names) ||
      !identical(installed_running, running_identity) ||
      !is.character(installed_running$started_at) ||
      length(installed_running$started_at) != 1L ||
      !nzchar(installed_running$started_at)) {
    stop("Interrupted fault-input marker is not resumable.", call. = FALSE)
  }
}
running_path <- normalizePath(running_path, winslash = "/", mustWork = TRUE)
running_sha256 <- wlv13_sha256_file(running_path)
resume_import <- output_preexisted
report <- list(
  schema = "wlv-issue13-fault-input-import/1",
  status = "running",
  passed = FALSE,
  started_at = running_identity$started_at,
  prepared_root = prepared_root,
  seed_project_root = seed_project_root,
  fault_root = fault_root,
  candidate_commit = candidate_commit,
  seed_commit = seed_commit,
  method = method,
  running_marker_path = running_path,
  running_marker_sha256 = running_sha256
)

wlv13_import_json_roundtrip <- function(value) {
  jsonlite::fromJSON(jsonlite::toJSON(
    value,
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = NA,
    null = "null",
    na = "string"
  ), simplifyVector = FALSE)
}

wlv13_import_json_equivalent <- function(left, right) {
  identical(
    wlv13_import_json_roundtrip(left),
    wlv13_import_json_roundtrip(right)
  )
}

wlv13_import_stop_recoverable <- function(message) {
  stop(structure(
    list(message = message, call = NULL),
    class = c("wlv13_import_recoverable_error", "error", "condition")
  ))
}

wlv13_import_remove_invalid_temp <- function(path, label, reason) {
  if (!file.exists(path) || isTRUE(file.info(path)$isdir) ||
      !identical(normalizePath(dirname(path), winslash = "/", mustWork = TRUE),
        output
      )) {
    stop(sprintf("Cannot safely discard invalid %s staging.", label),
      call. = FALSE
    )
  }
  if (unlink(path, force = TRUE) != 0L || file.exists(path)) {
    stop(sprintf("Cannot discard invalid %s staging: %s.", label, path),
      call. = FALSE
    )
  }
  message(sprintf("Discarded invalid %s staging: %s.", label, reason))
  invisible(FALSE)
}

wlv13_import_promote_json_temp <- function(temp_name, target, label,
    validator) {
  if (length(temp_name) != 1L) {
    stop(sprintf("Expected exactly one %s staging file.", label),
      call. = FALSE
    )
  }
  temporary <- file.path(output, temp_name)
  if (file.exists(target) || dir.exists(target)) {
    stop(sprintf("Refusing to replace canonical %s evidence.", label),
      call. = FALSE
    )
  }
  observed <- tryCatch(
    wlv13_json_read(temporary, simplify = FALSE),
    error = function(error) {
      wlv13_import_remove_invalid_temp(
        temporary, label, conditionMessage(error)
      )
      NULL
    }
  )
  if (is.null(observed)) return(NULL)
  if (!isTRUE(validator(observed))) {
    wlv13_import_remove_invalid_temp(
      temporary, label, "payload authentication failed"
    )
    return(NULL)
  }
  before <- list(
    size_bytes = as.numeric(file.info(temporary)$size),
    sha256 = wlv13_sha256_file(temporary)
  )
  if (file.exists(target) || dir.exists(target) ||
      !file.rename(temporary, target)) {
    stop(sprintf("Cannot install authenticated %s staging.", label),
      call. = FALSE
    )
  }
  after <- list(
    size_bytes = as.numeric(file.info(target)$size),
    sha256 = wlv13_sha256_file(target)
  )
  installed <- wlv13_json_read(target, simplify = FALSE)
  if (!identical(before, after) ||
      !wlv13_import_json_equivalent(installed, observed)) {
    stop(sprintf("Installed %s evidence changed during promotion.", label),
      call. = FALSE
    )
  }
  installed
}

wlv13_import_failed_temp_valid <- function(value) {
  required <- c(
    "schema", "status", "passed", "started_at", "prepared_root",
    "seed_project_root", "fault_root", "candidate_commit", "seed_commit",
    "method", "running_marker_path", "running_marker_sha256",
    "finished_at", "error"
  )
  allowed <- c(
    required,
    "preparation_comparison_path", "preparation_comparison_sha256",
    "source_tree", "seed_source_proof_path", "seed_source_proof_sha256",
    "run_id", "result_id", "run_manifest_sha256",
    "run_inventory_sha256", "imported_seed_proof_path",
    "imported_seed_proof_sha256", "source_stores_unchanged"
  )
  is.list(value) && !anyDuplicated(names(value)) &&
    all(required %in% names(value)) && all(names(value) %in% allowed) &&
    identical(value$schema, "wlv-issue13-fault-input-import-failed/1") &&
    identical(value$status, "failed") && identical(value$passed, FALSE) &&
    identical(value$started_at, report$started_at) &&
    identical(value$prepared_root, report$prepared_root) &&
    identical(value$seed_project_root, report$seed_project_root) &&
    identical(value$fault_root, report$fault_root) &&
    identical(value$candidate_commit, report$candidate_commit) &&
    identical(value$seed_commit, report$seed_commit) &&
    identical(value$method, report$method) &&
    identical(value$running_marker_path, report$running_marker_path) &&
    identical(value$running_marker_sha256, report$running_marker_sha256) &&
    is.character(value$finished_at) && length(value$finished_at) == 1L &&
    nzchar(value$finished_at) && is.character(value$error) &&
    length(value$error) == 1L && nzchar(value$error)
}

if (length(failed_temp)) {
  recovered_failed <- wlv13_import_promote_json_temp(
    failed_temp,
    failed_path,
    "failed import",
    wlv13_import_failed_temp_valid
  )
  if (!is.null(recovered_failed)) {
    stop("Recovered terminal fault-input import failure.", call. = FALSE)
  }
  failed_temp <- character()
}

tree_inventory <- function(root) {
  root <- wlv13_normalize_existing_dir(root, "tree root")
  entries <- list.files(root,
    all.files = TRUE,
    no.. = TRUE,
    recursive = TRUE,
    include.dirs = TRUE,
    full.names = TRUE
  )
  if (!length(entries)) {
    records <- data.frame(
      path = character(), type = character(), size_bytes = numeric(),
      sha256 = character(), stringsAsFactors = FALSE
    )
  } else {
    relative <- substring(
      normalizePath(entries, winslash = "/", mustWork = TRUE),
      nchar(root) + 2L
    )
    info <- file.info(entries)
    order_index <- order(relative, method = "radix")
    entries <- entries[order_index]
    relative <- relative[order_index]
    info <- info[order_index, , drop = FALSE]
    is_directory <- info$isdir %in% TRUE
    hashes <- rep(NA_character_, length(entries))
    hashes[!is_directory] <- vapply(entries[!is_directory],
      wlv13_sha256_file, character(1L)
    )
    records <- data.frame(
      path = relative,
      type = ifelse(is_directory, "directory", "file"),
      size_bytes = ifelse(is_directory, NA_real_, as.numeric(info$size)),
      sha256 = hashes,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }
  signature <- paste(
    records$path,
    records$type,
    ifelse(is.na(records$size_bytes), "", format(records$size_bytes,
      scientific = FALSE, trim = TRUE
    )),
    ifelse(is.na(records$sha256), "", records$sha256),
    sep = "|",
    collapse = "\n"
  ) |>
    enc2utf8() |>
    charToRaw() |>
    wlv13_sha256_raw()
  list(root = root, records = records, signature = signature)
}

wlv13_import_copy_temp <- function(destination) {
  file.path(
    dirname(destination),
    paste0(".", basename(destination), ".wlv13-copy.tmp")
  )
}

wlv13_import_file_identity <- function(path, label) {
  if (!file.exists(path) || isTRUE(file.info(path)$isdir) ||
      nzchar(Sys.readlink(path))) {
    stop(sprintf("%s is not a regular, non-link file: %s.", label, path),
      call. = FALSE
    )
  }
  size <- as.numeric(file.info(path)$size)
  if (length(size) != 1L || is.na(size) || size < 0) {
    stop(sprintf("Cannot determine %s size: %s.", label, path),
      call. = FALSE
    )
  }
  list(size_bytes = size, sha256 = wlv13_sha256_file(path))
}

wlv13_import_require_file_identity <- function(path, expected, label) {
  observed <- wlv13_import_file_identity(path, label)
  if (!identical(observed, expected)) {
    stop(sprintf("%s differs from its source: %s.", label, path),
      call. = FALSE
    )
  }
  invisible(observed)
}

wlv13_import_discard_copy_temp <- function(temporary, label, reason) {
  if (!file.exists(temporary) || isTRUE(file.info(temporary)$isdir) ||
      !endsWith(basename(temporary), ".wlv13-copy.tmp")) {
    stop(sprintf("Cannot safely discard %s staging.", label), call. = FALSE)
  }
  if (unlink(temporary, force = TRUE) != 0L || file.exists(temporary)) {
    stop(sprintf("Cannot discard divergent %s staging: %s.",
      label, temporary
    ), call. = FALSE)
  }
  message(sprintf("Discarded divergent %s staging: %s.", label, reason))
  invisible(FALSE)
}

wlv13_import_install_copy_temp <- function(source, temporary, destination,
    expected, label) {
  temporary_identity <- tryCatch(
    wlv13_import_file_identity(temporary, paste(label, "staging")),
    error = function(error) {
      wlv13_import_discard_copy_temp(
        temporary, label, conditionMessage(error)
      )
      NULL
    }
  )
  if (is.null(temporary_identity)) return(FALSE)
  if (!identical(temporary_identity, expected)) {
    wlv13_import_discard_copy_temp(
      temporary, label, "size or SHA-256 mismatch"
    )
    return(FALSE)
  }
  wlv13_import_require_file_identity(source, expected, paste(label, "source"))
  if (file.exists(destination) || dir.exists(destination) ||
      !file.rename(temporary, destination)) {
    stop(sprintf("Cannot install %s without overwrite: %s.",
      label, destination
    ), call. = FALSE)
  }
  wlv13_import_require_file_identity(destination, expected,
    paste(label, "installed file")
  )
  TRUE
}

wlv13_import_stage_copy <- function(origin, temporary, label, relative_path) {
  for (attempt in seq_len(2L)) {
    copied <- file.copy(origin, temporary,
      overwrite = FALSE,
      copy.mode = TRUE,
      copy.date = TRUE
    )
    if (isTRUE(copied)) return(TRUE)
    if (file.exists(temporary)) {
      if (isTRUE(file.info(temporary)$isdir) ||
          !endsWith(basename(temporary), ".wlv13-copy.tmp") ||
          unlink(temporary, force = TRUE) != 0L || file.exists(temporary)) {
        stop(sprintf("Cannot safely clean failed %s staging: %s.",
          label, temporary
        ), call. = FALSE)
      }
    }
  }
  wlv13_import_stop_recoverable(sprintf(
    "Transient %s copy failed twice for `%s`; retry is required.",
    label,
    relative_path
  ))
}

copy_tree <- function(source, target, label, resume = FALSE) {
  source <- wlv13_normalize_existing_dir(source, paste(label, "source"))
  target <- normalizePath(target, winslash = "/", mustWork = FALSE)
  target_exists <- dir.exists(target)
  if ((file.exists(target) && !target_exists) || (target_exists && !resume)) {
    stop(sprintf("%s target already exists: %s.", label, target), call. = FALSE)
  }
  if (!target_exists &&
      !dir.create(target, recursive = TRUE, showWarnings = FALSE)) {
    stop(sprintf("Cannot create %s target: %s.", label, target), call. = FALSE)
  }
  target <- normalizePath(target, winslash = "/", mustWork = TRUE)
  entries <- list.files(source,
    all.files = TRUE,
    no.. = TRUE,
    recursive = TRUE,
    include.dirs = TRUE,
    full.names = TRUE
  )
  if (!length(entries)) return(invisible(target))
  normalized_entries <- normalizePath(entries, winslash = "/", mustWork = TRUE)
  relative <- substring(normalized_entries, nchar(source) + 2L)
  relative <- chartr("\\", "/", relative)
  info <- file.info(entries)
  directories <- relative[info$isdir %in% TRUE]
  file_indexes <- which(!(info$isdir %in% TRUE))
  files_relative <- relative[file_indexes]
  temporary_relative <- vapply(files_relative, function(path) {
    parent <- dirname(path)
    name <- paste0(".", basename(path), ".wlv13-copy.tmp")
    if (identical(parent, ".")) name else paste(parent, name, sep = "/")
  }, character(1L))
  if (anyDuplicated(c(directories, files_relative, temporary_relative))) {
    stop(sprintf("%s source collides with target-bound staging names.", label),
      call. = FALSE
    )
  }
  if (target_exists) {
    existing <- list.files(target,
      all.files = TRUE,
      no.. = TRUE,
      recursive = TRUE,
      include.dirs = TRUE,
      full.names = TRUE
    )
    if (length(existing)) {
      existing_relative <- substring(
        chartr("\\", "/", existing),
        nchar(target) + 2L
      )
      existing_info <- file.info(existing)
      valid <- ifelse(
        existing_info$isdir %in% TRUE,
        existing_relative %in% directories,
        existing_relative %in% c(files_relative, temporary_relative)
      )
      links <- vapply(existing, function(path) nzchar(Sys.readlink(path)),
        logical(1L)
      )
      if (any(!valid) || any(links)) {
        bad <- existing_relative[!valid | links]
        stop(sprintf("Interrupted %s target is non-canonical: %s.",
          label, paste(bad, collapse = ", ")
        ), call. = FALSE)
      }
    }
  }
  directories <- directories[order(nchar(directories), directories,
    method = "radix"
  )]
  for (directory in directories) {
    destination <- file.path(target, directory)
    if (!dir.create(destination, recursive = TRUE, showWarnings = FALSE) &&
        !dir.exists(destination)) {
      stop(sprintf("Cannot copy %s directory `%s`.", label, directory),
        call. = FALSE
      )
    }
    if (nzchar(Sys.readlink(destination))) {
      stop(sprintf("%s directory is a link: %s.", label, destination),
        call. = FALSE
      )
    }
  }
  for (index in file_indexes) {
    relative_path <- relative[[index]]
    origin <- entries[[index]]
    destination <- file.path(target, relative_path)
    temporary <- wlv13_import_copy_temp(destination)
    if (!dir.create(dirname(destination), recursive = TRUE,
        showWarnings = FALSE) && !dir.exists(dirname(destination))) {
      stop(sprintf("Cannot create parent for %s file `%s`.",
        label, relative_path
      ), call. = FALSE)
    }
    expected <- wlv13_import_file_identity(
      origin, paste(label, "source file")
    )
    destination_exists <- file.exists(destination) || dir.exists(destination)
    temporary_exists <- file.exists(temporary) || dir.exists(temporary)
    if (destination_exists) {
      wlv13_import_require_file_identity(
        destination, expected, paste(label, "existing file")
      )
      if (temporary_exists) {
        duplicate <- tryCatch(
          wlv13_import_file_identity(temporary, paste(label, "orphan staging")),
          error = function(error) NULL
        )
        if (is.null(duplicate) || !identical(duplicate, expected)) {
          wlv13_import_discard_copy_temp(
            temporary, label, "canonical exists but orphan staging diverges"
          )
          next
        }
        if (unlink(temporary, force = TRUE) != 0L || file.exists(temporary)) {
          stop(sprintf("Cannot discard duplicate %s staging: %s.",
            label, temporary
          ), call. = FALSE)
        }
      }
      next
    }
    installed <- FALSE
    if (temporary_exists) {
      installed <- wlv13_import_install_copy_temp(
        origin, temporary, destination, expected, label
      )
    }
    if (!isTRUE(installed)) {
      wlv13_import_stage_copy(origin, temporary, label, relative_path)
      installed <- wlv13_import_install_copy_temp(
        origin, temporary, destination, expected, label
      )
    }
    if (!isTRUE(installed)) {
      wlv13_import_stop_recoverable(sprintf(
        "Authenticated %s staging could not be reconstructed for `%s`.",
        label,
        relative_path
      ))
    }
    cat(sprintf("Copied %s: %s\n", label, relative_path))
    flush.console()
  }
  invisible(target)
}

main <- function() {
  roots <- c(prepared_root, seed_project_root, fault_root)
  expected_commits <- c(candidate_commit, seed_commit, candidate_commit)
  for (index in seq_along(roots)) {
    if (!identical(wlv13_git_commit(roots[[index]]), expected_commits[[index]]) ||
        !wlv13_git_runtime_clean(roots[[index]])) {
      stop("An import worktree is not pinned and runtime-clean.", call. = FALSE)
    }
  }
  comparison <- wlv13_json_read(comparison_path, simplify = FALSE)
  wlv_gate_prep_require <- function(condition, message) {
    if (!isTRUE(condition)) stop(message, call. = FALSE)
  }
  wlv_gate_prep_require(
    identical(comparison$schema, "wlv-issue13-preparation-comparison/2") &&
      identical(comparison$status, "passed") &&
      identical(comparison$candidate_commit, candidate_commit) &&
      identical(
        normalizePath(comparison$candidate_root,
          winslash = "/", mustWork = TRUE
        ), prepared_root
      ) &&
      isTRUE(comparison$inventory$candidate$passed) &&
      isTRUE(comparison$euklems$passed) &&
      isTRUE(comparison$transaction_state$candidate$passed) &&
      isTRUE(comparison$executions$candidate_passed),
    "Candidate preparation comparison is missing, stale, or failed."
  )
  prepared_cache <- wlv_gate_verify_raw_caches(prepared_root)
  prepared_inventory <- wlv_gate_preparation_inventory(prepared_root)
  if (!isTRUE(prepared_cache$passed) || !isTRUE(prepared_inventory$passed)) {
    stop("Prepared candidate source inventory is incomplete.", call. = FALSE)
  }
  prepared_transaction <- wlv_gate_prep_transaction_state(prepared_root)
  if (!isTRUE(prepared_transaction$passed)) {
    stop("Prepared candidate source contains staging or locks.", call. = FALSE)
  }
  fault_source <- file.path(fault_root, "source_data")
  fault_results <- file.path(fault_root, "results")
  occupied <- c(
    if (dir.exists(fault_source)) list.files(fault_source,
      all.files = TRUE, no.. = TRUE
    ) else character(),
    if (dir.exists(fault_results)) list.files(fault_results,
      all.files = TRUE, no.. = TRUE
    ) else character()
  )
  if (length(occupied) && !resume_import) {
    stop("Fault worktree source/results store is not empty.", call. = FALSE)
  }

  seed_report <- wlv13_json_read(seed_result_path, simplify = FALSE)
  if (!is.list(seed_report) ||
      !identical(seed_report$schema, wlv13_schema$scenario) ||
      !isTRUE(seed_report$passed) ||
      !identical(seed_report$status, "passed") ||
      !identical(seed_report$scenario_id,
        paste0("candidate/calculate/", method, "/workers1")
      ) ||
      !identical(seed_report$observed_commit, seed_commit) ||
      !identical(normalizePath(seed_report$project_root,
        winslash = "/", mustWork = TRUE
      ), seed_project_root) ||
      !identical(seed_report$kind, "calculate") ||
      !identical(seed_report$request$method, method) ||
      !identical(as.integer(seed_report$request$workers), 1L) ||
      !is.null(seed_report$error)) {
    stop("Source full-run seed report is invalid.", call. = FALSE)
  }
  run_index <- which(vapply(seed_report$outputs, function(output) {
    is.list(output) && identical(output$kind, "run") &&
      identical(output$method, method)
  }, logical(1L)))
  if (length(run_index) != 1L) {
    stop("Source seed report does not identify exactly one method run.",
      call. = FALSE
    )
  }
  seed <- seed_report$outputs[[run_index]]
  if (!is.null(seed$parent_run_id)) {
    stop("Source seed is a recalculated child, not a full run.", call. = FALSE)
  }
  source_run <- normalizePath(seed$root, winslash = "/", mustWork = TRUE)
  expected_source_run <- normalizePath(file.path(
    seed_project_root, "results", "runs", method, seed$run_id
  ), winslash = "/", mustWork = TRUE)
  if (!identical(tolower(source_run), tolower(expected_source_run))) {
    stop("Source seed run is not at its canonical path.", call. = FALSE)
  }
  source_run_inventory <- wlv13_run_inventory(source_run)
  if (!identical(source_run_inventory$manifest_sha256, seed$manifest_sha256) ||
      !identical(wlv13_inventory_signature(source_run_inventory),
        seed$inventory_sha256
      ) ||
      !identical(source_run_inventory$manifest$result$provenance$git$commit,
        seed_commit
      ) ||
      !identical(source_run_inventory$manifest$result$request$mode,
        "calculate"
      ) ||
      !identical(as.integer(
        source_run_inventory$manifest$result$request$workers
      ), 1L)) {
    stop("Source seed run differs from its authenticated report.", call. = FALSE)
  }

  source_tree_before <- tree_inventory(file.path(prepared_root, "source_data"))
  copy_tree(file.path(prepared_root, "source_data"), fault_source,
    "prepared source", resume = resume_import
  )
  target_tree <- tree_inventory(fault_source)
  if (!identical(source_tree_before$records, target_tree$records) ||
      !identical(source_tree_before$signature, target_tree$signature)) {
    stop("Copied preparation source tree differs byte-for-byte.", call. = FALSE)
  }
  target_cache <- wlv_gate_verify_raw_caches(fault_root)
  target_inventory <- wlv_gate_preparation_inventory(fault_root)
  target_transaction <- wlv_gate_prep_transaction_state(fault_root)
  if (!isTRUE(target_cache$passed) || !isTRUE(target_inventory$passed) ||
      !isTRUE(target_transaction$passed)) {
    stop("Copied preparation source contract failed in the fault store.",
      call. = FALSE
    )
  }

  target_run <- file.path(
    fault_root, "results", "runs", method, seed$run_id
  )
  copy_tree(source_run, target_run, "full-run seed", resume = resume_import)
  target_run_inventory <- wlv13_run_inventory(target_run)
  if (!identical(source_run_inventory$records, target_run_inventory$records) ||
      !identical(source_run_inventory$manifest_sha256,
        target_run_inventory$manifest_sha256
      ) ||
      !identical(wlv13_inventory_signature(source_run_inventory),
        wlv13_inventory_signature(target_run_inventory)
      )) {
    stop("Copied full-run seed differs from the source inventory.",
      call. = FALSE
    )
  }

  imported_proof <- seed_report
  imported_proof$project_root <- normalizePath(fault_root,
    winslash = "/", mustWork = TRUE
  )
  imported_proof$outputs[[run_index]]$root <- normalizePath(target_run,
    winslash = "/", mustWork = TRUE
  )
  imported_proof$outputs[[run_index]]$manifest_path <- normalizePath(
    file.path(target_run, "run_manifest.json"),
    winslash = "/",
    mustWork = TRUE
  )
  if (length(proof_temp)) {
    recovered_proof <- wlv13_import_promote_json_temp(
      proof_temp,
      proof_path,
      "imported seed proof",
      function(value) wlv13_import_json_equivalent(value, imported_proof)
    )
    if (is.null(recovered_proof)) {
      wlv13_json_write(imported_proof, proof_path)
    }
  } else if (!file.exists(proof_path)) {
    wlv13_json_write(imported_proof, proof_path)
  }
  proof_check <- wlv13_json_read(proof_path, simplify = FALSE)
  if (!wlv13_import_json_equivalent(proof_check, imported_proof) ||
      !identical(proof_check$project_root, imported_proof$project_root) ||
      !identical(proof_check$outputs[[run_index]]$root,
      imported_proof$outputs[[run_index]]$root) ||
      !identical(proof_check$outputs[[run_index]]$manifest_path,
        imported_proof$outputs[[run_index]]$manifest_path) ||
      !identical(proof_check$outputs[[run_index]]$inventory_sha256,
        seed$inventory_sha256
      )) {
    stop("Imported seed proof failed JSON round-trip validation.",
      call. = FALSE
    )
  }
  source_tree_after <- tree_inventory(file.path(prepared_root, "source_data"))
  source_run_after <- wlv13_run_inventory(source_run)
  if (!identical(source_tree_before$records, source_tree_after$records) ||
      !identical(wlv13_inventory_signature(source_run_inventory),
        wlv13_inventory_signature(source_run_after)
      )) {
    stop("A source store changed during the read-only import.", call. = FALSE)
  }
  if (!identical(wlv13_git_commit(fault_root), candidate_commit) ||
      !wlv13_git_runtime_clean(fault_root)) {
    stop("Fault runtime changed during input import.", call. = FALSE)
  }

  report$finished_at <<- wlv13_now()
  report$status <<- "passed"
  report$passed <<- TRUE
  report$preparation_comparison_path <<- comparison_path
  report$preparation_comparison_sha256 <<- wlv13_sha256_file(comparison_path)
  report$source_tree <<- list(
    file_count = sum(source_tree_before$records$type == "file"),
    directory_count = sum(source_tree_before$records$type == "directory"),
    signature = source_tree_before$signature,
    identical_after_copy = TRUE,
    source_unchanged = TRUE
  )
  report$seed_source_proof_path <<- seed_result_path
  report$seed_source_proof_sha256 <<- wlv13_sha256_file(seed_result_path)
  report$run_id <<- seed$run_id
  report$result_id <<- seed$result_id
  report$run_manifest_sha256 <<- seed$manifest_sha256
  report$run_inventory_sha256 <<- seed$inventory_sha256
  report$imported_seed_proof_path <<- proof_path
  report$imported_seed_proof_sha256 <<- wlv13_sha256_file(proof_path)
  report$source_stores_unchanged <<- TRUE
  if (length(final_temp)) {
    recovered <- wlv13_import_promote_json_temp(
      final_temp,
      report_path,
      "final import",
      function(value) {
        if (!is.list(value) || !is.character(value$finished_at) ||
            length(value$finished_at) != 1L || !nzchar(value$finished_at)) {
          return(FALSE)
        }
        expected <- report
        expected$finished_at <- value$finished_at
        wlv13_import_json_equivalent(value, expected)
      }
    )
    if (is.null(recovered)) {
      wlv13_json_write(report, report_path)
    } else {
      report <<- recovered
    }
  } else {
    wlv13_json_write(report, report_path)
  }
  invisible(report)
}

tryCatch(
  main(),
  error = function(error) {
    recoverable <- inherits(error, "wlv13_import_recoverable_error")
    if (!recoverable && !file.exists(report_path) &&
        !file.exists(failed_path)) {
      failed <- report
      failed$schema <- "wlv-issue13-fault-input-import-failed/1"
      failed$status <- "failed"
      failed$passed <- FALSE
      failed$finished_at <- wlv13_now()
      failed$error <- conditionMessage(error)
      wlv13_json_write(failed, failed_path)
    }
    stop(error)
  }
)

cat("Fault inputs imported and authenticated:", report_path, "\n")
