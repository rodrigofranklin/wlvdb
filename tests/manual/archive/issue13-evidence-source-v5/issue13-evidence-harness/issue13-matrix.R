# Canonical evidence matrix for the final issue #13 real-data gate.

wlv13_methods <- c(
  "wiodr13", "wiodr16", "alternative_1", "alternative_2",
  "norow_w13", "ochoa_1", "ochoa_2", "petrovic", "wiodr13v09",
  "wiodr16v09", "zerodep_1", "zerodep_2"
)

wlv13_arms <- c("baseline", "candidate")

# This pair is explicitly accepted by the native paper-0 preflight and covers
# a historical profile plus the zero-depreciation counterfactual on WIOD13.
wlv13_paper0_methods <- c("ochoa_1", "ochoa_2")

wlv13_recalculation_variants <- data.frame(
  stage = c(1L, 4L, 5L, 4L, 5L),
  variant = c(
    "full", "full", "full", "select-gross-output-mv",
    "select-gross-output-du"
  ),
  sea_var = c(NA_character_, NA_character_, NA_character_,
    "gross_output.s.mv", "gross_output.s.du"),
  stringsAsFactors = FALSE
)

wlv13_fault_names <- c(
  "module-execution",
  "preparation-promotion",
  "publication-run-staging",
  "publication-semantic-validation",
  "publication-run-manifest",
  "publication-run-promotion",
  "publication-release-staging",
  "publication-release-manifest",
  "publication-release-promotion",
  "publication-channel-marker"
)

wlv13_fault_bindings <- data.frame(
  fault_id = wlv13_fault_names,
  kind = c(
    "calculate", "prepare_euklems", rep("calculate", 8L)
  ),
  binding = c(
    "wlv_run_module_plan",
    "wlv_commit_preparation_result",
    "wlv_new_contract_runtime",
    "wlv_validate_staged_results",
    "wlv_build_run_manifest",
    "wlv_read_run_manifest",
    "wlv_merge_panel_result_tables",
    "wlv_build_release_manifest",
    "wlv_read_release_manifest",
    "wlv_write_channel_marker"
  ),
  when = c(
    "before", "checkpoint", "before", "after", "after", "after", "before",
    "after", "after", "after"
  ),
  call = c(1L, 1L, 1L, 1L, 1L, 1L, 1L, 1L, 2L, 1L),
  checkpoint = c(
    NA_character_, "after_install:euklems.capital.1995",
    rep(NA_character_, 8L)
  ),
  stringsAsFactors = FALSE
)

wlv13_calculate_phase <- function(method, workers = 1L) {
  paste0("calculate/", method, "/workers", workers)
}

wlv13_recalculation_phases <- function(method) {
  paste0(
    "recalculate/", method, "/stage",
    wlv13_recalculation_variants$stage, "/",
    wlv13_recalculation_variants$variant
  )
}

wlv13_core_phases <- function() {
  unlist(lapply(wlv13_methods, function(method) {
    c(wlv13_calculate_phase(method), wlv13_recalculation_phases(method))
  }), use.names = FALSE)
}

wlv13_worker2_phases <- function() {
  vapply(c("wiodr13", "wiodr16"), wlv13_calculate_phase,
    character(1L), workers = 2L
  )
}

wlv13_scenario_ids <- function() {
  ordinary <- c(
    as.vector(outer(wlv13_arms, wlv13_core_phases(), paste, sep = "/")),
    as.vector(outer(wlv13_arms, wlv13_worker2_phases(), paste, sep = "/")),
    paste0(wlv13_arms, "/prepare/all"),
    paste0(wlv13_arms, "/paper/0")
  )
  sort(c(ordinary, paste0("candidate/fault/", wlv13_fault_names)),
    method = "radix"
  )
}

wlv13_parity_phases <- function() {
  c(
    wlv13_core_phases(),
    wlv13_worker2_phases(),
    "prepare/wiodr13", "prepare/wiodr16", "prepare/euklems", "paper/0"
  )
}

wlv13_oracle_ids <- function() {
  recalculations <- unlist(lapply(wlv13_methods, wlv13_recalculation_phases),
    use.names = FALSE
  )
  as.vector(outer(paste0("oracle/", wlv13_arms), recalculations,
    paste, sep = "/"
  ))
}

wlv13_worker_equivalence_ids <- function() {
  unlist(lapply(wlv13_arms, function(arm) {
    paste0(
      "equivalence/", arm, "/calculate/", c("wiodr13", "wiodr16"),
      "/workers2-vs-workers1"
    )
  }), use.names = FALSE)
}

wlv13_comparison_ids <- function() {
  sort(c(
    paste0("parity/", wlv13_parity_phases()),
    wlv13_oracle_ids(),
    wlv13_worker_equivalence_ids()
  ), method = "radix")
}

wlv13_phase_method <- function(phase) {
  pieces <- strsplit(phase, "/", fixed = TRUE)[[1L]]
  if (length(pieces) >= 2L && pieces[[1L]] %in% c("calculate", "recalculate")) {
    pieces[[2L]]
  } else {
    NULL
  }
}

wlv13_recalculation_expectation <- function(phase) {
  pieces <- strsplit(phase, "/", fixed = TRUE)[[1L]]
  if (length(pieces) != 4L || !identical(pieces[[1L]], "recalculate")) {
    stop(sprintf("Not a canonical recalculation phase: %s.", phase),
      call. = FALSE
    )
  }
  stage <- suppressWarnings(as.integer(sub("^stage", "", pieces[[3L]])))
  match_index <- which(
    wlv13_recalculation_variants$stage == stage &
      wlv13_recalculation_variants$variant == pieces[[4L]]
  )
  if (length(match_index) != 1L) {
    stop(sprintf("Unknown recalculation phase: %s.", phase), call. = FALSE)
  }
  row <- wlv13_recalculation_variants[match_index, , drop = FALSE]
  list(
    method = pieces[[2L]],
    stage = row$stage[[1L]],
    variant = row$variant[[1L]],
    sea_vars = if (is.na(row$sea_var[[1L]])) NULL else row$sea_var[[1L]]
  )
}

wlv13_matrix_summary <- function() {
  list(
    methods = as.list(wlv13_methods),
    arms = as.list(wlv13_arms),
    scenario_count = length(wlv13_scenario_ids()),
    comparison_count = length(wlv13_comparison_ids()),
    fault_count = length(wlv13_fault_names),
    scenarios = as.list(wlv13_scenario_ids()),
    comparisons = as.list(wlv13_comparison_ids())
  )
}
