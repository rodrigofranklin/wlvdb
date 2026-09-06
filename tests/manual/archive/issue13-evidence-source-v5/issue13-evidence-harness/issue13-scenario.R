script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) {
  stop("Run issue13-scenario.R with Rscript.", call. = FALSE)
}
script_path <- normalizePath(sub("^--file=", "", script_argument[[1L]]),
  winslash = "/", mustWork = TRUE
)
script_dir <- dirname(script_path)
sys.source(file.path(script_dir, "issue13-lib.R"), envir = environment())
sys.source(file.path(script_dir, "issue13-matrix.R"), envir = environment())
sys.source(file.path(dirname(script_dir), "issue13-prep-paper-lib.R"),
  envir = environment()
)

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop("Expected <scenario.json> <evidence-directory>.", call. = FALSE)
}
spec_path <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
evidence_dir <- wlv13_ensure_dir(arguments[[2L]], "scenario evidence directory")
spec <- wlv13_json_read(spec_path, simplify = TRUE)

required <- c(
  "schema", "scenario_id", "project_root", "expected_commit", "kind",
  "checkpoint_path"
)
if (!is.list(spec) || any(!required %in% names(spec)) ||
    !identical(spec$schema, "wlv-issue13-scenario/1")) {
  stop("Scenario specification has an invalid schema.", call. = FALSE)
}
scenario_id <- wlv13_id(spec$scenario_id, "scenario_id")
project_root <- wlv13_normalize_existing_dir(spec$project_root, "project root")
expected_commit <- wlv13_scalar_text(
  spec$expected_commit,
  "expected_commit",
  "^[0-9a-f]{40}$"
)
kind <- match.arg(spec$kind, c(
  "calculate", "recalculate", "prepare", "prepare_euklems", "paper0"
))
checkpoint_path <- normalizePath(spec$checkpoint_path,
  winslash = "/", mustWork = FALSE
)
if (wlv13_is_within(evidence_dir, project_root)) {
  stop("Scenario evidence must be outside the evaluated worktree.",
    call. = FALSE
  )
}
scenario_safe <- gsub("/", "__", scenario_id, fixed = TRUE)
spec_directory <- dirname(spec_path)
plan_root <- dirname(dirname(spec_directory))
plan_evidence <- normalizePath(
  file.path(plan_root, "scenarios", scenario_safe),
  winslash = "/",
  mustWork = FALSE
)
is_prep_fault_plan <- identical(basename(dirname(spec_directory)), "specs") &&
  identical(basename(spec_directory), scenario_safe) &&
  identical(tolower(evidence_dir), tolower(plan_evidence))
expected_checkpoint_path <- normalizePath(if (is_prep_fault_plan) {
  file.path(spec_directory, "execution-checkpoint.json")
} else {
  file.path(dirname(dirname(dirname(evidence_dir))), "execution-checkpoint.json")
}, winslash = "/", mustWork = FALSE)
if (!identical(tolower(checkpoint_path), tolower(expected_checkpoint_path)) ||
    wlv13_is_within(checkpoint_path, project_root)) {
  stop("Execution checkpoint is outside its canonical attempt binding.",
    call. = FALSE
  )
}

value_or <- function(name, default = NULL) {
  if (name %in% names(spec) && !is.null(spec[[name]])) spec[[name]] else default
}
method <- NULL
methods <- character()
if (kind %in% c("calculate", "recalculate")) {
  method <- wlv13_scalar_text(value_or("method", NULL),
    "method", "^[a-z][a-z0-9_]*$"
  )
  methods <- method
} else if (kind %in% c("prepare", "paper0")) {
  methods <- enc2utf8(as.character(unlist(
    value_or("methods", value_or("method", NULL)),
    use.names = FALSE
  )))
  if (!length(methods) || anyNA(methods) || any(!nzchar(methods)) ||
      any(!grepl("^[a-z][a-z0-9_]*$", methods)) || anyDuplicated(methods)) {
    stop("`methods` must contain unique method identifiers.", call. = FALSE)
  }
  method <- if (length(methods) == 1L) methods[[1L]] else NULL
}
channel <- wlv13_scalar_text(value_or("channel", "issue13-gate"),
  "channel", "^[a-z0-9][a-z0-9._-]*$"
)
workers <- wlv13_integer(as.numeric(value_or("workers", 1L)), "workers", 1L)
allow_experimental <- isTRUE(value_or("allow_experimental", TRUE))
expected_failure <- isTRUE(value_or("expected_failure", FALSE))
error_pattern <- value_or("expected_error_pattern", NULL)
if (expected_failure && is.null(value_or("fault", NULL))) {
  error_pattern <- wlv13_scalar_text(error_pattern, "expected_error_pattern")
}

runtime_files <- c(
  "R", "catalog", "config", "contracts", "methods", "parameters",
  "scripts/run_wlv.R", "renv.lock", "DESCRIPTION"
)
if (!identical(wlv13_git_commit(project_root), expected_commit)) {
  stop("Scenario worktree is not pinned to expected_commit.", call. = FALSE)
}
if (!wlv13_git_runtime_clean(project_root)) {
  stop(sprintf("Scenario runtime inputs are dirty (%s).",
    paste(runtime_files, collapse = ", ")
  ), call. = FALSE)
}

loaded_runtime <- wlv_gate_load_runtime(project_root)
runtime <- loaded_runtime$runtime
runtime_kind <- loaded_runtime$kind
assert_runtime_unchanged <- function() {
  if (identical(runtime_kind, "candidate")) {
    runtime$wlv_assert_loaded_runtime_unchanged()
  }
  invisible(TRUE)
}
assert_runtime_unchanged()

fault <- value_or("fault", NULL)
fault_state <- new.env(parent = emptyenv())
fault_state$calls <- 0L
fault_state$injected <- FALSE
fault_state$armed <- FALSE
fault_original <- NULL
fault_binding <- NULL
fault_when <- NULL
fault_call <- NULL
fault_checkpoint <- NULL
restore_fault <- function() invisible(NULL)
if (!is.null(fault)) {
  if (!identical(runtime_kind, "candidate")) {
    stop("Fault injection is supported only by the candidate runtime.",
      call. = FALSE
    )
  }
  if (!expected_failure || !is.list(fault) ||
      !setequal(names(fault), c(
        "fault_id", "binding", "when", "call", "checkpoint", "token"
      ))) {
    stop("Fault injection has an invalid schema.", call. = FALSE)
  }
  fault_id <- wlv13_scalar_text(fault$fault_id, "fault_id",
    "^[a-z][a-z0-9-]*$"
  )
  expected_fault_scenario <- paste0("candidate/fault/", fault_id)
  if (!identical(scenario_id, expected_fault_scenario)) {
    stop("Fault scenario_id does not match fault_id.", call. = FALSE)
  }
  binding_index <- match(fault_id, wlv13_fault_bindings$fault_id)
  if (is.na(binding_index)) {
    stop("Fault injection is not part of the canonical gate.", call. = FALSE)
  }
  fault_binding <- wlv13_scalar_text(fault$binding, "fault binding",
    "^[A-Za-z][A-Za-z0-9_.]*$"
  )
  fault_when <- match.arg(fault$when, c("before", "after", "checkpoint"))
  fault_call <- wlv13_integer(as.numeric(fault$call), "fault call", 1L)
  fault_checkpoint <- if (is.null(fault$checkpoint)) {
    NULL
  } else {
    wlv13_scalar_text(
      fault$checkpoint,
      "fault checkpoint",
      "^[a-z][a-z0-9_.-]*:[A-Za-z0-9][A-Za-z0-9_.-]*$"
    )
  }
  fault_token <- wlv13_scalar_text(fault$token, "fault token",
    "^issue13-injected-[a-z0-9-]{16,}$"
  )
  expected_kind <- wlv13_fault_bindings$kind[[binding_index]]
  expected_binding <- wlv13_fault_bindings$binding[[binding_index]]
  expected_when <- wlv13_fault_bindings$when[[binding_index]]
  expected_call <- wlv13_fault_bindings$call[[binding_index]]
  expected_checkpoint <- wlv13_fault_bindings$checkpoint[[binding_index]]
  observed_checkpoint <- if (is.null(fault_checkpoint)) NA_character_ else
    fault_checkpoint
  if (!identical(kind, expected_kind)) {
    stop("Fault action does not match the canonical gate.", call. = FALSE)
  }
  if (!identical(fault_binding, expected_binding) ||
      !identical(fault_when, expected_when) ||
      !identical(fault_call, expected_call) ||
      !identical(observed_checkpoint, expected_checkpoint)) {
    stop("Fault boundary does not match the canonical gate.",
      call. = FALSE
    )
  }
  if (!exists(fault_binding, envir = runtime, inherits = FALSE) ||
      !is.function(get(fault_binding, envir = runtime, inherits = FALSE))) {
    stop(sprintf("Fault binding is unavailable: %s.", fault_binding),
      call. = FALSE
    )
  }
  fault_original <- get(fault_binding, envir = runtime, inherits = FALSE)
  injected_wrapper <- local({
    original <- fault_original
    state <- fault_state
    target <- fault_call
    when <- fault_when
    checkpoint <- fault_checkpoint
    token <- fault_token
    function(...) {
      if (!isTRUE(state$armed)) return(original(...))
      state$calls <- state$calls + 1L
      hit <- identical(state$calls, target)
      if (hit && identical(when, "before")) {
        state$injected <- TRUE
        stop(token, call. = FALSE)
      }
      if (hit && identical(when, "checkpoint")) {
        arguments <- list(...)
        argument_names <- names(arguments)
        context_index <- if (length(argument_names) &&
            "context" %in% argument_names) {
          match("context", argument_names)
        } else {
          2L
        }
        if (length(arguments) < context_index ||
            !is.environment(arguments[[context_index]]) ||
            !exists("checkpoint", arguments[[context_index]], inherits = FALSE) ||
            !is.function(arguments[[context_index]]$checkpoint)) {
          stop("Preparation checkpoint injection could not bind its context.",
            call. = FALSE
          )
        }
        context <- arguments[[context_index]]
        original_checkpoint <- context$checkpoint
        checkpoint_was_locked <- bindingIsLocked("checkpoint", context)
        injected_checkpoint <- local({
          delegate <- original_checkpoint
          label_target <- checkpoint
          injected_state <- state
          injected_token <- token
          function(label) {
            if (identical(label, label_target)) {
              injected_state$injected <- TRUE
              stop(injected_token, call. = FALSE)
            }
            delegate(label)
          }
        })
        if (checkpoint_was_locked) unlockBinding("checkpoint", context)
        assign("checkpoint", injected_checkpoint, envir = context)
        if (checkpoint_was_locked) lockBinding("checkpoint", context)
        on.exit({
          if (bindingIsLocked("checkpoint", context)) {
            unlockBinding("checkpoint", context)
          }
          assign("checkpoint", original_checkpoint, envir = context)
          if (checkpoint_was_locked) lockBinding("checkpoint", context)
        }, add = TRUE)
        return(do.call(original, arguments))
      }
      value <- original(...)
      if (hit && identical(when, "after")) {
        state$injected <- TRUE
        stop(token, call. = FALSE)
      }
      value
    }
  })
  unlockBinding(fault_binding, runtime)
  assign(fault_binding, injected_wrapper, envir = runtime)
  lockBinding(fault_binding, runtime)
  restore_fault <- local({
    binding <- fault_binding
    original <- fault_original
    namespace <- runtime
    restored <- FALSE
    function() {
      if (restored) return(invisible(NULL))
      unlockBinding(binding, namespace)
      assign(binding, original, envir = namespace)
      lockBinding(binding, namespace)
      restored <<- TRUE
      invisible(NULL)
    }
  })
  on.exit(restore_fault(), add = TRUE)
  error_pattern <- fault_token
}

publication_state <- function() {
  release <- runtime$wlv_read_current_release(
    project_root,
    channel = channel,
    required = FALSE
  )
  staging_root <- file.path(project_root, "results", ".staging")
  staging <- if (dir.exists(staging_root)) {
    sort(list.files(staging_root, all.files = TRUE, no.. = TRUE), method = "radix")
  } else {
    character()
  }
  if (is.null(release)) {
    return(list(exists = FALSE, channel = channel, staging = as.list(staging)))
  }
  list(
    exists = TRUE,
    channel = channel,
    sequence = release$marker$sequence,
    release_id = release$manifest$release_id,
    marker_path = release$marker_path,
    marker_sha256 = wlv13_sha256_file(release$marker_path),
    release_path = release$path,
    release_manifest_sha256 = wlv13_sha256_file(release$manifest_path),
    runs = lapply(release$manifest$runs, function(record) {
      list(
        method = record$method,
        run_id = record$run_id,
        result_id = record$result_id,
        manifest_sha256 = record$manifest_sha256
      )
    }),
    staging = as.list(staging)
  )
}

source_state <- function() {
  sources <- c("wiodr13", "wiodr16")
  values <- lapply(sources, function(source) {
    root <- file.path(project_root, "source_data", source, "normalized")
    path <- file.path(root, "_source_manifest.csv")
    if (!file.exists(path)) return(list(exists = FALSE))
    list(
      exists = TRUE,
      manifest_sha256 = wlv13_sha256_file(path),
      generation_id = tryCatch(
        unique(wlv13_source_inventory(root)$identity$source_generation_id),
        error = function(error) paste0("invalid:", conditionMessage(error))
      )
    )
  })
  names(values) <- sources
  euklems_root <- file.path(project_root, "source_data", "euklems")
  euklems <- if (dir.exists(euklems_root)) {
    paths <- sort(list.files(
      euklems_root,
      pattern = "^(ekk|ekdeprate)_[0-9]{4}[.]fst$",
      full.names = TRUE
    ), method = "radix")
    hashes <- if (length(paths)) vapply(paths, wlv13_sha256_file, character(1L)) else
      character()
    stats::setNames(as.list(hashes), basename(paths))
  } else {
    list()
  }
  preparation_staging_root <- file.path(
    project_root,
    "source_data",
    ".preparation-staging"
  )
  preparation_staging <- if (dir.exists(preparation_staging_root)) {
    sort(list.files(
      preparation_staging_root,
      all.files = TRUE,
      no.. = TRUE,
      recursive = TRUE,
      include.dirs = TRUE,
      full.names = FALSE
    ), method = "radix")
  } else {
    character()
  }
  preparation_locks <- sort(list.files(
    file.path(project_root, "source_data"),
    pattern = "^[.]prepare-lock-",
    all.files = TRUE,
    no.. = TRUE,
    full.names = FALSE
  ), method = "radix")
  list(
    sources = values,
    euklems = euklems,
    preparation_staging = as.list(preparation_staging),
    preparation_locks = as.list(preparation_locks)
  )
}

capture_run <- function(method_name = method) {
  current <- runtime$wlv_resolve_current_method_run(
    project_root,
    method_name,
    channel = channel
  )
  runtime$wlv_verify_run_manifest(
    current$manifest,
    current$path,
    reject_unlisted = TRUE
  )
  inventory <- wlv13_run_inventory(current$path)
  list(
    kind = "run",
    root = current$path,
    manifest_path = current$manifest_path,
    manifest_sha256 = inventory$manifest_sha256,
    inventory_sha256 = wlv13_inventory_signature(inventory),
    run_id = current$manifest$run_id,
    result_id = current$manifest$result_id,
    parent_run_id = current$manifest$parent_run_id,
    release_id = current$release_id,
    method = current$manifest$method,
    request = current$manifest$result$request
  )
}

capture_source <- function(source) {
  root <- file.path(project_root, "source_data", source, "normalized")
  inventory <- wlv13_source_inventory(root)
  list(
    kind = "source",
    source = source,
    root = root,
    manifest_path = inventory$manifest_path,
    manifest_sha256 = inventory$manifest_sha256,
    inventory_sha256 = wlv13_inventory_signature(inventory),
    identity = inventory$identity
  )
}

capture_euklems <- function() {
  root <- wlv13_normalize_existing_dir(
    file.path(project_root, "source_data", "euklems"),
    "EU KLEMS cache"
  )
  years <- value_or("euklems_years", NULL)
  paths <- sort(list.files(
    root,
    pattern = "^(ekk|ekdeprate)_[0-9]{4}[.]fst$",
    full.names = FALSE
  ), method = "radix")
  if (!is.null(years)) {
    years <- as.integer(unlist(years, use.names = FALSE))
    expected <- sort(c(paste0("ekk_", years, ".fst"),
      paste0("ekdeprate_", years, ".fst")), method = "radix"
    )
    missing <- setdiff(expected, paths)
    if (length(missing)) {
      stop(sprintf("EU KLEMS evidence is missing: %s.",
        paste(missing, collapse = ", ")
      ), call. = FALSE)
    }
    paths <- expected
  }
  snapshot_path <- file.path(evidence_dir, "euklems-snapshot.json")
  snapshot <- wlv13_create_snapshot(
    root,
    paths,
    roles = rep("euklems_table", length(paths)),
    snapshot_id = paste0(scenario_id, "/euklems"),
    output = snapshot_path
  )
  list(
    kind = "snapshot",
    source = "euklems",
    root = root,
    manifest_path = snapshot$manifest_path,
    manifest_sha256 = snapshot$manifest_sha256,
    inventory_sha256 = wlv13_inventory_signature(snapshot),
    identity = snapshot$identity
  )
}

capture_paper <- function() {
  release <- runtime$wlv_read_current_release(
    project_root,
    channel = channel,
    required = TRUE
  )
  runtime$wlv_verify_release_manifest(
    release$manifest,
    release$root,
    publication_root = file.path(project_root, "results"),
    reject_unlisted = TRUE
  )
  inventory <- wlv13_release_inventory(release$root)
  paper <- inventory$records$path[inventory$records$role == "paper"]
  if (length(paper) != 1L) {
    stop("Paper 0 release must contain exactly one paper artifact.",
      call. = FALSE
    )
  }
  list(
    kind = "release",
    root = release$root,
    manifest_path = inventory$manifest_path,
    manifest_sha256 = inventory$manifest_sha256,
    inventory_sha256 = wlv13_inventory_signature(inventory),
    release_id = release$manifest$release_id,
    paper_path = paper[[1L]]
  )
}

seed_result_path <- NULL
seed_expected <- NULL
seed_before <- NULL
if (identical(kind, "recalculate")) {
  expected_seed_commit <- wlv13_scalar_text(
    value_or("expected_seed_commit", NULL),
    "expected_seed_commit",
    "^[0-9a-f]{40}$"
  )
  seed_result_path <- normalizePath(
    wlv13_scalar_text(value_or("seed_result_path", NULL),
      "seed_result_path"
    ),
    winslash = "/",
    mustWork = TRUE
  )
  if (wlv13_is_within(seed_result_path, project_root)) {
    stop("Recalculation seed proof must be outside the worktree.",
      call. = FALSE
    )
  }
  seed_report <- wlv13_json_read(seed_result_path, simplify = FALSE)
  arm <- strsplit(scenario_id, "/", fixed = TRUE)[[1L]][[1L]]
  expected_seed_scenario <- paste0(
    arm, "/calculate/", method, "/workers1"
  )
  if (!is.list(seed_report) ||
      !identical(seed_report$schema, wlv13_schema$scenario) ||
      !isTRUE(seed_report$passed) ||
      !identical(seed_report$scenario_id, expected_seed_scenario) ||
      !identical(seed_report$observed_commit, expected_seed_commit) ||
      !is.list(seed_report$outputs)) {
    stop("Recalculation seed proof is invalid or belongs to another scenario.",
      call. = FALSE
    )
  }
  run_index <- which(vapply(seed_report$outputs, function(output) {
    is.list(output) && identical(output$kind, "run") &&
      identical(output$method, method)
  }, logical(1L)))
  if (length(run_index) != 1L) {
    stop("Recalculation seed proof does not identify exactly one full run.",
      call. = FALSE
    )
  }
  seed_expected <- seed_report$outputs[[run_index]]
  if (!is.null(seed_expected$parent_run_id)) {
    stop("A recalculation seed must be a full run, not another child run.",
      call. = FALSE
    )
  }
  required_seed_fields <- c(
    "run_id", "result_id", "manifest_sha256",
    "inventory_sha256", "method"
  )
  if (any(!required_seed_fields %in% names(seed_expected))) {
    stop("Recalculation seed proof lacks authenticated run identity.",
      call. = FALSE
    )
  }
  seed_before <- capture_run(method)
  identity_fields <- c(
    required_seed_fields, "parent_run_id"
  )
  if (!identical(seed_before[identity_fields], seed_expected[identity_fields])) {
    stop(paste0(
      "The current channel is not independently seeded from the immutable ",
      "full-run evidence."
    ), call. = FALSE)
  }
}

at_stage <- NULL
sea_vars <- NULL
euklems_years <- NULL
fail_at <- character()
if (identical(kind, "recalculate")) {
  at_stage <- wlv13_integer(as.numeric(value_or("at_stage", NA)),
    "at_stage", 1L
  )
  if (!at_stage %in% c(1L, 4L, 5L)) {
    stop("Recalculation stage must be 1, 4, or 5.", call. = FALSE)
  }
  sea_vars <- value_or("sea_vars", NULL)
  if (!is.null(sea_vars)) {
    sea_vars <- enc2utf8(as.character(unlist(sea_vars, use.names = FALSE)))
  }
}
if (identical(kind, "prepare_euklems")) {
  euklems_years <- as.integer(unlist(
    value_or("euklems_years", as.integer(1995:2010)),
    use.names = FALSE
  ))
  if (!length(euklems_years) || anyNA(euklems_years)) {
    stop("`euklems_years` must contain integer years.", call. = FALSE)
  }
  fail_at <- enc2utf8(as.character(unlist(
    value_or("fail_at", character()),
    use.names = FALSE
  )))
  if (anyNA(fail_at)) {
    stop("`fail_at` cannot contain missing values.", call. = FALSE)
  }
}

scenario_spec_sha256 <- wlv13_sha256_file(spec_path)
fault_request <- if (is.null(fault)) NULL else list(
  fault_id = fault_id,
  binding = fault_binding,
  when = fault_when,
  call = fault_call,
  checkpoint = fault_checkpoint,
  token = fault_token
)
seed_request <- if (identical(kind, "recalculate")) list(
  expected_seed_commit = expected_seed_commit,
  seed_result_path = seed_result_path,
  seed_result_sha256 = wlv13_sha256_file(seed_result_path),
  expected = seed_expected,
  observed_before = seed_before
) else NULL
request_binding <- list(
  scenario_spec_path = spec_path,
  scenario_spec_sha256 = scenario_spec_sha256,
  kind = kind,
  method = method,
  methods = as.list(methods),
  channel = channel,
  workers = workers,
  allow_experimental = allow_experimental,
  at_stage = at_stage,
  sea_vars = if (is.null(sea_vars)) NULL else as.list(sea_vars),
  euklems_years = if (is.null(euklems_years)) NULL else as.list(euklems_years),
  fail_at = as.list(fail_at),
  paper = if (identical(kind, "paper0")) 0L else NULL,
  expected_failure = expected_failure,
  expected_error_pattern = if (expected_failure) error_pattern else NULL,
  fault = fault_request,
  seed = seed_request
)

run_action <- function() {
  if (identical(kind, "calculate")) {
    runtime$get_wlv(
      methods = method,
      workers = workers,
      channel = channel,
      allow_experimental = allow_experimental
    )
    return(list(capture_run(method)))
  }
  if (identical(kind, "recalculate")) {
    runtime$recalc_wlv(
      methods = method,
      at_stage = at_stage,
      sea_vars = sea_vars,
      workers = workers,
      channel = channel,
      allow_experimental = allow_experimental
    )
    result <- capture_run(method)
    if (!identical(result$parent_run_id, seed_before$run_id) ||
        identical(result$run_id, seed_before$run_id) ||
        identical(result$result_id, seed_before$result_id)) {
      stop("Recalculation output is not a direct child of its authenticated seed.",
        call. = FALSE
      )
    }
    return(list(result))
  }
  if (identical(kind, "prepare")) {
    runtime$prepare_wlv(methods = methods, allow_experimental = allow_experimental)
    catalog <- if (exists("wlv_runtime_catalog", envir = runtime,
        mode = "function", inherits = FALSE)) {
      runtime$wlv_runtime_catalog()
    } else {
      runtime$method_catalog
    }
    sources <- unique(vapply(methods, function(method_name) {
      runtime$wlv_catalog_method(catalog, method_name)$source[[1L]]
    }, character(1L)))
    return(c(lapply(sources, capture_source), list(capture_euklems())))
  }
  if (identical(kind, "prepare_euklems")) {
    registry <- runtime$wlv_default_preparation_registry()
    services <- runtime$wlv_default_preparation_services()
    runtime$wlv_prepare_registered_source(
      registry = registry,
      source = "euklems",
      root = project_root,
      services = services,
      arguments = list(euklems_years = euklems_years),
      fail_at = fail_at
    )
    return(list(capture_euklems()))
  }
  runtime$get_wlv(
    methods = methods,
    papern = 0L,
    prepaper = TRUE,
    workers = workers,
    channel = channel,
    allow_experimental = allow_experimental
  )
  c(lapply(methods, capture_run), list(capture_paper()))
}

checkpoint_leaf <- basename(checkpoint_path)
if (!grepl("[.]json$", checkpoint_leaf)) {
  stop("Execution checkpoint must use a JSON filename.", call. = FALSE)
}
started_marker_path <- file.path(
  dirname(checkpoint_path),
  sub("[.]json$", ".started.json", checkpoint_leaf)
)
checkpoint_entries <- list.files(
  dirname(checkpoint_path),
  all.files = TRUE,
  no.. = TRUE
)
checkpoint_temporary_prefixes <- paste0(
  ".",
  basename(c(started_marker_path, checkpoint_path)),
  "-"
)
has_checkpoint_temporary <- any(vapply(checkpoint_entries, function(entry) {
  any(startsWith(entry, checkpoint_temporary_prefixes))
}, logical(1L)))
if (file.exists(started_marker_path) || file.exists(checkpoint_path) ||
    has_checkpoint_temporary) {
  stop(paste0(
    "Execution checkpoint state already exists. Refusing to restart because ",
    "a second process sample would invalidate the scientific timing evidence."
  ), call. = FALSE)
}

publication_before <- publication_state()
source_before <- source_state()
started_at <- wlv13_now()
started_marker <- list(
  schema = "wlv-issue13-execution-started/1",
  status = "started",
  scenario_id = scenario_id,
  project_root = project_root,
  expected_commit = expected_commit,
  scenario_spec_path = spec_path,
  scenario_spec_sha256 = scenario_spec_sha256,
  request = request_binding,
  started_at = started_at,
  publication_before = publication_before,
  source_before = source_before
)
wlv13_json_write(started_marker, started_marker_path)
started_marker_path <- normalizePath(started_marker_path,
  winslash = "/", mustWork = TRUE
)
started_marker_sha256 <- wlv13_sha256_file(started_marker_path)
installed_started_marker <- wlv13_json_read(
  started_marker_path,
  simplify = FALSE
)
if (!identical(installed_started_marker$schema,
    "wlv-issue13-execution-started/1") ||
    !identical(installed_started_marker$status, "started") ||
    !identical(installed_started_marker$scenario_id, scenario_id) ||
    !identical(installed_started_marker$scenario_spec_path, spec_path) ||
    !identical(installed_started_marker$scenario_spec_sha256,
      scenario_spec_sha256
    ) || !identical(installed_started_marker$request, request_binding)) {
  stop("Installed execution-start marker failed identity validation.",
    call. = FALSE
  )
}

observed_error <- NULL
outputs <- NULL
fault_state$armed <- !is.null(fault)
elapsed <- system.time({
  tryCatch(
    outputs <- run_action(),
    error = function(error) observed_error <<- conditionMessage(error)
  )
})
fault_state$armed <- FALSE
restore_fault()
elapsed_seconds <- unname(as.numeric(elapsed[["elapsed"]]))
assert_runtime_unchanged()
if (!identical(wlv13_git_commit(project_root), expected_commit) ||
    !wlv13_git_runtime_clean(project_root)) {
  stop("Runtime inputs changed during the scenario.", call. = FALSE)
}
publication_after <- publication_state()
source_after <- source_state()
checkpoint <- list(
  schema = "wlv-issue13-execution-checkpoint/2",
  status = "finished",
  scenario_id = scenario_id,
  project_root = project_root,
  expected_commit = expected_commit,
  scenario_spec_path = spec_path,
  scenario_spec_sha256 = scenario_spec_sha256,
  request = request_binding,
  started_marker_path = started_marker_path,
  started_marker_sha256 = started_marker_sha256,
  started_at = started_at,
  finished_at = wlv13_now(),
  elapsed_seconds = elapsed_seconds,
  publication_before = publication_before,
  publication_after = publication_after,
  source_before = source_before,
  source_after = source_after,
  outputs = outputs,
  error = observed_error
)
wlv13_json_write(checkpoint, checkpoint_path)
checkpoint_path <- normalizePath(checkpoint_path,
  winslash = "/", mustWork = TRUE
)
checkpoint_sha256 <- wlv13_sha256_file(checkpoint_path)

failure_observed <- !is.null(observed_error)
error_matched <- expected_failure && failure_observed && if (!is.null(fault)) {
  grepl(error_pattern, observed_error, fixed = TRUE)
} else {
  grepl(error_pattern, observed_error, perl = TRUE)
}
success_observed <- !failure_observed
passed <- if (expected_failure) error_matched else success_observed

fault_result <- NULL
if (expected_failure) {
  publication_unchanged <- identical(publication_before, publication_after)
  source_unchanged <- identical(source_before, source_after)
  preparation_staging_clean <-
    !length(source_before$preparation_staging) &&
    !length(source_after$preparation_staging) &&
    !length(source_before$preparation_locks) &&
    !length(source_after$preparation_locks)
  fault_result <- list(
    schema = wlv13_schema$fault,
    scenario_id = scenario_id,
    status = if (passed && publication_unchanged && source_unchanged) {
      "passed"
    } else {
      "failed"
    },
    passed = passed && publication_unchanged && source_unchanged,
    fault_id = if (is.null(fault)) NULL else fault$fault_id,
    binding = if (is.null(fault)) NULL else fault_binding,
    when = if (is.null(fault)) NULL else fault_when,
    call = if (is.null(fault)) NULL else fault_call,
    checkpoint = if (is.null(fault)) NULL else fault_checkpoint,
    binding_call_count = fault_state$calls,
    injected = !is.null(fault) && isTRUE(fault_state$injected),
    expected_failure_observed = failure_observed,
    expected_error_matched = error_matched,
    channel_marker_unchanged = publication_unchanged,
    no_partial_release_visible = publication_unchanged,
    staging_clean = !length(publication_before$staging) &&
      !length(publication_after$staging) && preparation_staging_clean,
    preparation_staging_clean = preparation_staging_clean,
    normalized_generation_unchanged = source_unchanged,
    previous_release_verified = isTRUE(publication_before$exists) &&
      publication_unchanged,
    error = observed_error
  )
  fault_result$passed <- isTRUE(fault_result$passed) &&
    isTRUE(fault_result$injected) && isTRUE(fault_result$staging_clean) &&
    isTRUE(fault_result$preparation_staging_clean) &&
    isTRUE(fault_result$previous_release_verified)
  fault_result$status <- if (fault_result$passed) "passed" else "failed"
  passed <- isTRUE(fault_result$passed)
  wlv13_json_write(fault_result, file.path(evidence_dir, "fault-result.json"))
}

report <- list(
  schema = wlv13_schema$scenario,
  scenario_id = scenario_id,
  status = if (passed) "passed" else "failed",
  passed = passed,
  kind = kind,
  project_root = project_root,
  expected_commit = expected_commit,
  observed_commit = wlv13_git_commit(project_root),
  started_at = started_at,
  finished_at = wlv13_now(),
  elapsed_seconds = elapsed_seconds,
  request = list(
    method = method,
    methods = as.list(methods),
    channel = channel,
    workers = workers,
    allow_experimental = allow_experimental,
    at_stage = at_stage,
    sea_vars = if (is.null(sea_vars)) NULL else as.list(sea_vars),
    euklems_years = if (is.null(euklems_years)) NULL else as.list(euklems_years),
    fail_at = as.list(fail_at),
    paper = if (identical(kind, "paper0")) 0L else NULL,
    expected_failure = expected_failure,
    expected_error_pattern = if (expected_failure) error_pattern else NULL,
    fault = fault_request
  ),
  execution_checkpoint = list(
    scenario_spec_path = spec_path,
    scenario_spec_sha256 = scenario_spec_sha256,
    started_marker_path = started_marker_path,
    started_marker_sha256 = started_marker_sha256,
    checkpoint_path = checkpoint_path,
    checkpoint_sha256 = checkpoint_sha256
  ),
  outputs = outputs,
  seed = if (is.null(seed_before)) NULL else list(
    proof_path = seed_result_path,
    proof_sha256 = wlv13_sha256_file(seed_result_path),
    expected_seed_commit = expected_seed_commit,
    expected = seed_expected,
    observed_before = seed_before,
    seed_release_id = seed_before$release_id
  ),
  publication_before = publication_before,
  publication_after = publication_after,
  source_before = source_before,
  source_after = source_after,
  error = observed_error
)
wlv13_json_write(report, file.path(evidence_dir, "scenario-result.json"))
quit(save = "no", status = if (passed) 0L else 1L, runLast = FALSE)
