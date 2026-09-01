# Build the exhaustive cross-engine metadata equivalence manifest.
#
# This is a gate-construction utility. It reads only configuration, registry and
# catalog definitions from the two pinned engines; it never opens scientific
# FST payloads. The resulting manifest records every cell, in row order, for
# the three architecture-dependent method sidecars.

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 4L) {
  stop(paste(
    "Usage: issue13-v5-build-metadata-equivalence.R",
    "<baseline-root> <candidate-root> <harness-runtime-root> <output.json>"
  ), call. = FALSE)
}

baseline_root <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
candidate_root <- normalizePath(arguments[[2L]], winslash = "/", mustWork = TRUE)
harness_root <- normalizePath(arguments[[3L]], winslash = "/", mustWork = TRUE)
output_path <- normalizePath(
  arguments[[4L]], winslash = "/", mustWork = FALSE
)

sys.source(
  file.path(harness_root, "issue13-prep-paper-lib.R"),
  envir = environment(),
  chdir = FALSE
)
wlv_gate_require_namespaces("jsonlite")

baseline_commit <- wlv_gate_git_commit(baseline_root)
if (!identical(
    baseline_commit,
    "cc2c86189a06676bcb9f0e05e08033d710a92509"
)) {
  stop("Metadata equivalence requires the exact Issue #12 baseline commit.",
    call. = FALSE
  )
}
candidate_commit <- wlv_gate_git_commit(candidate_root)
if (!identical(
    candidate_commit,
    "899f6379daffeb5697c08a605260c64dea750ec7"
)) {
  stop("Metadata equivalence requires its exact derivation commit.",
    call. = FALSE
  )
}

methods <- c(
  "wiodr13", "wiodr16", "alternative_1", "alternative_2", "norow_w13",
  "ochoa_1", "ochoa_2", "petrovic", "wiodr13v09", "wiodr16v09",
  "zerodep_1", "zerodep_2"
)
artifacts <- c(
  `_method_assumptions.csv` = "assumptions",
  `_method_matrices.csv` = "matrices",
  `_method_solutions.csv` = "solutions"
)
columns <- list(
  `_method_assumptions.csv` = c("names", "computation", "order"),
  `_method_matrices.csv` = c("names", "computation", "order"),
  `_method_solutions.csv` = c(
    "names", "sector_solution", "country_solution", "stage", "order"
  )
)

normalize_table <- function(value, expected_columns) {
  if (!is.data.frame(value) || !identical(names(value), expected_columns)) {
    stop("Reconstructed metadata has an unexpected schema.", call. = FALSE)
  }
  value <- as.data.frame(lapply(value, function(column) {
    column <- as.character(column)
    column[is.na(column)] <- ""
    enc2utf8(column)
  }), stringsAsFactors = FALSE, check.names = FALSE)
  rownames(value) <- NULL
  value
}

encode_table <- function(value) {
  list(
    columns = as.list(names(value)),
    rows = lapply(seq_len(nrow(value)), function(index) {
      as.list(unname(vapply(
        value[index, , drop = FALSE],
        function(column) as.character(column[[1L]]),
        character(1L)
      )))
    })
  )
}

baseline_sidecars <- function(plan, method) {
  configuration <- plan$configuration[[method]]
  assumptions <- configuration$assumptions[
    order(configuration$assumptions$order), , drop = FALSE
  ]
  matrices <- configuration$matrices[
    order(configuration$matrices$order), , drop = FALSE
  ]
  solutions <- configuration$solutions[
    order(configuration$solutions$order), , drop = FALSE
  ]
  solutions <- solutions[order(solutions$stage), , drop = FALSE]
  list(
    assumptions = assumptions,
    matrices = matrices,
    solutions = solutions
  )
}

baseline <- wlv_gate_load_runtime(baseline_root)
candidate <- wlv_gate_load_runtime(candidate_root)
if (!identical(baseline$kind, "baseline") ||
    !identical(candidate$kind, "candidate")) {
  stop("Metadata equivalence roots do not identify the two engine generations.",
    call. = FALSE
  )
}
expected_planner_formals <- c(
  "methods", "repeat_pp", "papern", "prepaper", "workers", "channel",
  "mode", "at_stage", "sea_vars", "root", "allow_experimental",
  "requested_operations", "catalog"
)
for (loaded in list(baseline, candidate)) {
  if (!identical(
      names(formals(loaded$runtime$wlv_validate_request)),
      expected_planner_formals
  )) {
    stop("Metadata derivation received an unexpected planner signature.",
      call. = FALSE
    )
  }
}
candidate_runtime_generation <- unname(unclass(as.character(
  candidate$runtime$.wlv_runtime_compatibility_generation()
)))
if (!is.character(candidate_runtime_generation) ||
    length(candidate_runtime_generation) != 1L ||
    !grepl("^[0-9a-f]{64}$", candidate_runtime_generation)) {
  stop("Candidate runtime generation is not a concrete SHA-256.",
    call. = FALSE
  )
}

profiles <- lapply(methods, function(method) {
  plan_arguments <- list(
    methods = method,
    repeat_pp = FALSE,
    papern = 0L,
    prepaper = FALSE,
    workers = 1L,
    channel = "stable",
    mode = "calculate",
    at_stage = 1L,
    sea_vars = NULL,
    allow_experimental = TRUE,
    requested_operations = "calculate",
    catalog = NULL
  )
  baseline_plan <- do.call(
    baseline$runtime$wlv_validate_request,
    c(plan_arguments, list(root = baseline_root))
  )
  candidate_plan <- do.call(
    candidate$runtime$wlv_validate_request,
    c(plan_arguments, list(root = candidate_root))
  )
  for (record in list(
      list(plan = baseline_plan, root = baseline_root),
      list(plan = candidate_plan, root = candidate_root)
    )) {
    if (!inherits(record$plan, "wlv_run_plan") ||
        !identical(
          normalizePath(record$plan$root, winslash = "/", mustWork = TRUE),
          record$root
        ) ||
        !identical(record$plan$mode, "calculate") ||
        !identical(record$plan$requested_operations, "calculate") ||
        !identical(record$plan$method_names, method) ||
        !identical(record$plan$allow_experimental, TRUE)) {
      stop("Metadata derivation produced an unexpected run plan.",
        call. = FALSE
      )
    }
  }
  source <- candidate_plan$methods$source[[1L]]
  partition <- switch(source,
    wiodr13 = "1995-2009",
    wiodr16 = "2000-2014",
    stop(sprintf("No sealed partition is registered for `%s`.", source),
      call. = FALSE
    )
  )
  legacy <- baseline_sidecars(baseline_plan, method)
  native <- candidate$runtime$wlv_native_configuration_sidecars(
    candidate_plan,
    method,
    list(partitions = partition)
  )
  artifact_profiles <- lapply(names(artifacts), function(artifact) {
    group <- unname(artifacts[[artifact]])
    list(
      artifact = artifact,
      baseline = encode_table(normalize_table(
        legacy[[group]], columns[[artifact]]
      )),
      candidate = encode_table(normalize_table(
        native[[group]], columns[[artifact]]
      ))
    )
  })
  list(
    method = method,
    source = source,
    partition = partition,
    artifacts = artifact_profiles
  )
})

candidate$runtime$wlv_assert_loaded_runtime_unchanged()

manifest <- list(
  schema = "wlv-issue13-metadata-equivalence/1",
  baseline_commit = baseline_commit,
  candidate_commit_at_derivation = candidate_commit,
  candidate_runtime_generation_sha256 = candidate_runtime_generation,
  derivation = paste(
    "Exact engine-reconstructed sidecars paired by method and artifact;",
    "no category, wildcard, tolerance or row-order projection."
  ),
  methods = as.list(methods),
  artifacts = as.list(names(artifacts)),
  profiles = profiles
)

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(
  manifest,
  output_path,
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null",
  na = "string"
)
observed <- jsonlite::fromJSON(
  output_path,
  simplifyVector = FALSE,
  simplifyDataFrame = FALSE,
  simplifyMatrix = FALSE
)
expected <- jsonlite::fromJSON(
  jsonlite::toJSON(
    manifest,
    auto_unbox = TRUE,
    null = "null",
    na = "string"
  ),
  simplifyVector = FALSE,
  simplifyDataFrame = FALSE,
  simplifyMatrix = FALSE
)
if (!identical(observed, expected)) {
  stop("Metadata equivalence manifest failed its JSON round trip.",
    call. = FALSE
  )
}

cat(sprintf(
  "issue13 metadata equivalence: %d methods, %d artifact pairs\n",
  length(profiles),
  sum(vapply(profiles, function(profile) length(profile$artifacts), integer(1L)))
))
