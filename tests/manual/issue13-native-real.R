# Manual real-data gate for the issue #13 native runtime.
#
# Usage:
#   Rscript tests/manual/issue13-native-real.R \
#     <method> [baseline-run-directory] [output-root]
#
# Examples:
#   Rscript tests/manual/issue13-native-real.R wiodr13 <baseline> <output-root>
#   Rscript tests/manual/issue13-native-real.R wiodr16 <baseline> <output-root>
#
# The harness never publishes results. It resolves the typed configuration,
# compiles the graph before reading the large artifacts, executes it in memory,
# and optionally compares the four public arrays with one immutable baseline run.

arguments <- commandArgs(trailingOnly = TRUE)
method <- if (length(arguments)) arguments[[1L]] else "wiodr13"
baseline_dir <- if (length(arguments) >= 2L) arguments[[2L]] else NULL
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
sys.source(
  file.path(root, "tests", "manual", "issue13-native-parity.R"),
  envir = environment()
)
output_root <- if (length(arguments) >= 3L) {
  arguments[[3L]]
} else {
  file.path(
    Sys.getenv("LOCALAPPDATA"),
    "Temp", "wlv-issue13-native-real", method
  )
}
output_dir <- file.path(
  output_root,
  sprintf("run-%s-%d", format(Sys.time(), "%Y%m%dT%H%M%S"), Sys.getpid())
)
if (!dir.create(output_dir, recursive = TRUE, showWarnings = FALSE) &&
    !dir.exists(output_dir)) {
  stop(sprintf("Cannot create native harness output `%s`.", output_dir), call. = FALSE)
}
output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
root_prefix <- paste0(tolower(root), "/")
if (startsWith(tolower(output_dir), root_prefix)) {
  stop("The manual native gate must persist outside the Git worktree.", call. = FALSE)
}

bootstrap_environment <- new.env(parent = baseenv())
sys.source(file.path(root, "scripts", "runtime_bootstrap.R"), envir = bootstrap_environment)
runtime <- bootstrap_environment$wlv_load_runtime(root)

phase <- function(label) {
  message(format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), " ", label)
}

phase(paste0("loading catalog and graph for ", method))
catalog <- runtime$wlv_load_catalog(root)
method_record <- runtime$wlv_catalog_method(catalog, method)
source <- as.character(method_record$source[[1L]])
source_record <- runtime$wlv_catalog_source(catalog, source)
contract_id <- as.character(source_record$unit_contract[[1L]])
unit_contract <- runtime$wlv_catalog_unit_contract(catalog, contract_id)
units <- unit_contract$units
aggregation_registry <- runtime$wlv_native_aggregation_registry(
  root,
  catalog,
  method
)
indicators <- as.character(runtime$wlv_native_output_indicators(
  root,
  catalog,
  method,
  aggregation_registry
))
configuration <- runtime$wlv_resolve_module_config(root, method, source)
registry <- runtime$wlv_native_registry()

normalized_dir <- file.path(root, "source_data", source, "normalized")
source_io <- sort(list.files(
  normalized_dir,
  pattern = "^m_io.*[.]fst$",
  full.names = TRUE
))
source_sea <- file.path(normalized_dir, "sea.fst")
if (!length(source_io) || !file.exists(source_sea)) {
  stop("Normalized real-data inputs are unavailable.", call. = FALSE)
}
partitions <- unname(vapply(
  source_io,
  runtime$wlv_native_io_partition,
  character(1L)
))
instances <- runtime$wlv_native_plan_instances(
  registry = registry,
  config = configuration,
  aggregation_registry = aggregation_registry,
  indicators = indicators,
  partitions = partitions,
  mode = "calculate"
)

phase(sprintf("preflight (%d instances, %d partition(s))", length(instances), length(partitions)))
preflight <- runtime$wlv_native_preflight_plan(
  registry,
  instances,
  partitions,
  "calculate",
  source = source,
  at_stage = 1L,
  indicators = indicators
)
phase(sprintf("preflight complete (%d graph nodes)", length(preflight$order)))

gfcf_path <- file.path(normalized_dir, "_gfcf_canonical.rds")
run_data <- list(
  source_sea = source_sea,
  source_io = source_io,
  gfcf_observations = if (file.exists(gfcf_path)) gfcf_path else NULL
)
native_request <- list(
  root = root,
  mode = "calculate",
  at_stage = 1L
)
source_policy <- as.character(source_record$missingness_policy[[1L]])
policy <- switch(
  source_policy,
  wiodr13_v1 = runtime$wlv_wiodr13_missingness_policy(),
  wiodr16_v1 = runtime$wlv_wiodr16_missingness_policy(),
  runtime$wlv_strict_missingness_policy(source, source_policy)
)
scientific_profile <- runtime$wlv_native_scientific_profile(
  root,
  catalog,
  method,
  indicators
)
method_parameters <- runtime$wlv_native_method_parameters(root, method)
hash <- runtime$wlv_runtime_snapshot_value_sha256
compatibility <- runtime$wlv_runtime_compatibility(
  method = method,
  source = source,
  runtime_generation_sha256 = runtime$.wlv_runtime_compatibility_generation(),
  method_parameters_sha256 = hash(method_parameters$parameters),
  method_sectors_sha256 = hash(method_parameters$sectors),
  indicators = indicators,
  unit_contract_id = contract_id,
  unit_sidecar_sha256 = hash(runtime$wlv_catalog_unit_contract_sidecar(
    catalog,
    contract_id,
    indicators = indicators,
    resolved_aggregations = aggregation_registry$rows
  )),
  unit_definitions_sha256 = hash(units),
  missingness_policy_id = policy$policy_id,
  missingness_policy_sha256 = hash(policy),
  aggregation_registry_sha256 = hash(aggregation_registry),
  scientific_profile_sha256 = hash(scientific_profile),
  configuration_sha256 = hash(runtime$wlv_native_configuration_descriptor(
    configuration,
    registry
  ))
)

phase("building the real resource store")
store_data <- runtime$wlv_native_build_store(
  plan = native_request,
  method_record = method_record,
  run_data = run_data,
  registry = registry,
  instances = instances,
  indicators = indicators,
  unit_definitions = units,
  partitions = partitions,
  compatibility = compatibility
)
phase("compiling the real graph")
plan <- runtime$wlv_compile_module_plan(
  registry,
  instances,
  store = store_data$store,
  operation = "calculate",
  partitions = partitions
)

contract_runtime <- runtime$wlv_new_contract_runtime(
  method = method,
  source = source,
  policy = policy,
  scientific_profile = scientific_profile
)

phase(sprintf("running %d native graph nodes", length(plan$order)))
elapsed <- system.time({
  result <- runtime$wlv_run_module_plan(
    plan,
    store_data$store,
    services = list(
      contract_runtime = contract_runtime,
      year_apply = base::apply
    )
  )
})
phase(sprintf("native graph complete in %.1f seconds", elapsed[["elapsed"]]))

artifact <- function(name, axes) {
  ref <- runtime$wlv_native_artifact_ref(name, axes)[[1L]]
  runtime$wlv_store_read(result$store, ref)
}
artifacts <- list(
  sea_sectors = artifact(
    "sea_sectors",
    c("year", "indicator", "sector", "country")
  ),
  sea_countries = artifact(
    "sea_countries",
    c("year", "indicator", "country")
  ),
  m_io = artifact("m_io", c("year", "variable", "input", "output")),
  m_countries = artifact(
    "m_countries",
    c("year", "variable", "origin", "destination")
  )
)
indicator_metadata <- runtime$wlv_store_read(
  result$store,
  runtime$wlv_resource_ref(
    "metadata/indicators",
    runtime$wlv_native_indicator_metadata_contract()
  )
)
module_diagnostics <- runtime$wlv_native_csv_diagnostics(
  result,
  method = method,
  source = source,
  expected_years = runtime$wlv_native_metadata_years(source_sea)
)
module_trace <- result$trace

for (name in names(artifacts)) {
  phase(sprintf("%s dimensions: %s", name, paste(dim(artifacts[[name]]), collapse = " x ")))
}

# Keep only the public arrays and compact diagnostics before serializing or
# loading another multi-gigabyte panel (notably for WIOD16).
rm(result, store_data, plan, preflight)
gc(FALSE)

phase(paste0("persisting candidate artifacts in ", output_dir))
for (name in names(artifacts)) {
  runtime$write_fst_array(
    artifacts[[name]],
    file.path(output_dir, paste0(name, ".fst")),
    drop_axis_names = TRUE
  )
}
saveRDS(indicator_metadata, file.path(output_dir, "meta_indicators.RDS"))
saveRDS(module_diagnostics, file.path(output_dir, "module_diagnostics.RDS"))
utils::write.csv(
  module_trace,
  file.path(output_dir, "module_trace.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)
phase("candidate artifacts persisted")

comparison <- list()
transition_tables <- list()
indicator_comparisons <- list()

wlv_value_state <- function(value) {
  state <- rep.int(1L, length(value))
  state[is.na(value)] <- 2L
  state[is.nan(value)] <- 3L
  state[is.infinite(value) & value > 0] <- 4L
  state[is.infinite(value) & value < 0] <- 5L
  state
}

wlv_coordinate_label <- function(value, indices) {
  axes <- names(dimnames(value))
  if (is.null(axes)) axes <- paste0("axis", seq_along(indices))
  labels <- vapply(seq_along(indices), function(axis) {
    axis_labels <- dimnames(value)[[axis]]
    if (is.null(axis_labels)) as.character(indices[[axis]]) else
      axis_labels[[indices[[axis]]]]
  }, character(1L))
  paste0(axes, "=", labels, collapse = ";")
}

compare_array <- function(candidate, baseline, label) {
  same_dim <- identical(dim(candidate), dim(baseline))
  same_dimnames <- identical(dimnames(candidate), dimnames(baseline))
  same_axis_labels <- identical(unname(dimnames(candidate)), unname(dimnames(baseline)))
  same_axis_names <- identical(names(dimnames(candidate)), names(dimnames(baseline)))
  if (!same_dim) {
    return(data.frame(
      artifact = label, same_dim = FALSE, same_dimnames = same_dimnames,
      same_axis_labels = same_axis_labels, same_axis_names = same_axis_names,
      same_na = FALSE, same_nan = FALSE, identical_values = FALSE,
      mismatch_count = NA_real_, maximum_absolute_difference = NA_real_,
      maximum_coordinate = "", candidate_at_maximum = NA_real_,
      baseline_at_maximum = NA_real_, stringsAsFactors = FALSE
    ))
  }
  state_names <- c("finite", "NA", "NaN", "+Inf", "-Inf")
  transitions <- matrix(
    0,
    nrow = length(state_names),
    ncol = length(state_names),
    dimnames = list(candidate = state_names, baseline = state_names)
  )
  same_na <- TRUE
  same_nan <- TRUE
  identical_values <- TRUE
  mismatch_count <- 0
  maximum_difference <- 0
  maximum_coordinate <- ""
  candidate_at_maximum <- NA_real_
  baseline_at_maximum <- NA_real_
  for (first_axis in seq_len(dim(candidate)[[1L]])) {
    indices <- c(
      list(first_axis),
      rep(list(TRUE), length(dim(candidate)) - 1L),
      list(drop = FALSE)
    )
    candidate_slice <- as.vector(do.call("[", c(list(candidate), indices)))
    baseline_slice <- as.vector(do.call("[", c(list(baseline), indices)))
    candidate_state <- wlv_value_state(candidate_slice)
    baseline_state <- wlv_value_state(baseline_slice)
    observed <- table(
      factor(candidate_state, levels = seq_along(state_names)),
      factor(baseline_state, levels = seq_along(state_names))
    )
    transitions <- transitions + unclass(observed)
    same_na <- same_na && identical(
      candidate_state %in% c(2L, 3L),
      baseline_state %in% c(2L, 3L)
    )
    same_nan <- same_nan && identical(candidate_state == 3L, baseline_state == 3L)
    finite <- candidate_state == 1L & baseline_state == 1L
    mismatch <- candidate_state != baseline_state
    mismatch[finite] <- candidate_slice[finite] != baseline_slice[finite]
    mismatch_count <- mismatch_count + sum(mismatch)
    identical_values <- identical_values && !any(mismatch)
    if (any(finite)) {
      difference <- abs(candidate_slice[finite] - baseline_slice[finite])
      local_maximum <- max(difference)
      if (local_maximum > maximum_difference ||
          (!nzchar(maximum_coordinate) && local_maximum == maximum_difference)) {
        finite_positions <- which(finite)
        position <- finite_positions[[which.max(difference)]]
        trailing_dimensions <- dim(candidate)[-1L]
        trailing <- if (length(trailing_dimensions)) {
          as.integer(arrayInd(position, trailing_dimensions))
        } else {
          integer()
        }
        full_indices <- c(first_axis, trailing)
        maximum_difference <- local_maximum
        maximum_coordinate <- wlv_coordinate_label(candidate, full_indices)
        candidate_at_maximum <- candidate_slice[[position]]
        baseline_at_maximum <- baseline_slice[[position]]
      }
    }
    rm(candidate_slice, baseline_slice, candidate_state, baseline_state)
  }
  transition_tables[[label]] <<- as.data.frame(as.table(transitions),
    stringsAsFactors = FALSE
  )
  names(transition_tables[[label]]) <- c("candidate_state", "baseline_state", "count")
  transition_tables[[label]]$artifact <- label
  data.frame(
    artifact = label,
    same_dim = same_dim,
    same_dimnames = same_dimnames,
    same_axis_labels = same_axis_labels,
    same_axis_names = same_axis_names,
    same_na = same_na,
    same_nan = same_nan,
    identical_values = identical_values,
    mismatch_count = mismatch_count,
    maximum_absolute_difference = maximum_difference,
    maximum_coordinate = maximum_coordinate,
    candidate_at_maximum = candidate_at_maximum,
    baseline_at_maximum = baseline_at_maximum,
    stringsAsFactors = FALSE
  )
}

compare_indicators <- function(candidate, baseline, artifact) {
  candidate_ids <- dimnames(candidate)[[2L]]
  baseline_ids <- dimnames(baseline)[[2L]]
  rows <- lapply(candidate_ids, function(indicator) {
    baseline_index <- match(indicator, baseline_ids)
    candidate_index <- match(indicator, candidate_ids)
    if (is.na(baseline_index)) {
      return(data.frame(
        artifact = artifact, indicator = indicator, mismatch_count = NA_real_,
        maximum_absolute_difference = NA_real_, stringsAsFactors = FALSE
      ))
    }
    candidate_indices <- c(
      list(TRUE, candidate_index),
      rep(list(TRUE), length(dim(candidate)) - 2L),
      list(drop = FALSE)
    )
    baseline_indices <- c(
      list(TRUE, baseline_index),
      rep(list(TRUE), length(dim(baseline)) - 2L),
      list(drop = FALSE)
    )
    candidate_value <- as.vector(do.call("[", c(list(candidate), candidate_indices)))
    baseline_value <- as.vector(do.call("[", c(list(baseline), baseline_indices)))
    candidate_state <- wlv_value_state(candidate_value)
    baseline_state <- wlv_value_state(baseline_value)
    finite <- candidate_state == 1L & baseline_state == 1L
    mismatch <- candidate_state != baseline_state
    mismatch[finite] <- candidate_value[finite] != baseline_value[finite]
    data.frame(
      artifact = artifact,
      indicator = indicator,
      mismatch_count = sum(mismatch),
      maximum_absolute_difference = if (any(finite)) {
        max(abs(candidate_value[finite] - baseline_value[finite]))
      } else {
        0
      },
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

if (!is.null(baseline_dir)) {
  baseline_dir <- normalizePath(baseline_dir, winslash = "/", mustWork = TRUE)
  phase(paste0("comparing against ", baseline_dir))
  baseline_paths <- c(
    sea_sectors = file.path(baseline_dir, "sea_sectors.fst"),
    sea_countries = file.path(baseline_dir, "sea_countries.fst"),
    m_countries = file.path(baseline_dir, "m_countries.fst")
  )
  baseline_io <- sort(list.files(
    baseline_dir,
    pattern = "^m_io.*[.]fst$",
    full.names = TRUE
  ))
  if (length(baseline_io) != 1L || any(!file.exists(baseline_paths))) {
    stop("The immutable baseline run is incomplete.", call. = FALSE)
  }
  baseline_paths <- c(baseline_paths, m_io = baseline_io[[1L]])
  for (name in names(artifacts)) {
    baseline <- runtime$read_fst_array(baseline_paths[[name]])
    comparison[[name]] <- compare_array(artifacts[[name]], baseline, name)
    if (name %in% c("sea_sectors", "sea_countries")) {
      indicator_comparisons[[name]] <- compare_indicators(
        artifacts[[name]],
        baseline,
        name
      )
    }
    rm(baseline)
    gc(FALSE)
  }
  comparison <- do.call(rbind, comparison)
  print(comparison, row.names = FALSE)
  transitions <- do.call(rbind, transition_tables)
  transitions <- transitions[transitions$count > 0, , drop = FALSE]
  indicators_differing <- do.call(rbind, indicator_comparisons)
  indicators_differing <- indicators_differing[
    is.na(indicators_differing$mismatch_count) |
      indicators_differing$mismatch_count > 0,
    ,
    drop = FALSE
  ]
  utils::write.csv(
    comparison,
    file.path(output_dir, "array_comparison.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  utils::write.csv(
    transitions,
    file.path(output_dir, "state_transitions.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  utils::write.csv(
    indicators_differing,
    file.path(output_dir, "indicator_comparison.csv"),
    row.names = FALSE,
    fileEncoding = "UTF-8"
  )
  print(indicators_differing, row.names = FALSE)
  baseline_metadata <- readRDS(file.path(baseline_dir, "meta_indicators.RDS"))
  metadata_identical <- identical(indicator_metadata, baseline_metadata)
  phase(sprintf(
    "indicator metadata identical: %s (candidate=%d x %d; baseline=%d x %d)",
    metadata_identical,
    nrow(indicator_metadata), ncol(indicator_metadata),
    nrow(baseline_metadata), ncol(baseline_metadata)
  ))
  wlv_assert_issue13_parity(
    comparison,
    indicators_differing,
    metadata_identical
  )
}

phase("manual native real-data gate finished")
