# Compare a persisted issue #13 native real-data run with an immutable baseline.
#
# Usage:
#   Rscript tests/manual/issue13-native-compare.R candidate-dir baseline-dir

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L) {
  stop("Expected `candidate-dir` and `baseline-dir`.", call. = FALSE)
}
candidate_dir <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
baseline_dir <- normalizePath(arguments[[2L]], winslash = "/", mustWork = TRUE)
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
sys.source(
  file.path(root, "tests", "manual", "issue13-native-parity.R"),
  envir = environment()
)
runtime <- new.env(parent = baseenv())
sys.source(file.path(root, "scripts", "lib", "functions.R"), envir = runtime)

phase <- function(label) {
  message(format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), " ", label)
}

candidate_paths <- c(
  sea_sectors = file.path(candidate_dir, "sea_sectors.fst"),
  sea_countries = file.path(candidate_dir, "sea_countries.fst"),
  m_io = file.path(candidate_dir, "m_io.fst"),
  m_countries = file.path(candidate_dir, "m_countries.fst")
)
baseline_io <- sort(list.files(
  baseline_dir,
  pattern = "^m_io.*[.]fst$",
  full.names = TRUE
))
baseline_paths <- c(
  sea_sectors = file.path(baseline_dir, "sea_sectors.fst"),
  sea_countries = file.path(baseline_dir, "sea_countries.fst"),
  m_io = if (length(baseline_io) == 1L) baseline_io else NA_character_,
  m_countries = file.path(baseline_dir, "m_countries.fst")
)
if (anyNA(baseline_paths) || any(!file.exists(candidate_paths)) ||
    any(!file.exists(baseline_paths))) {
  stop("Candidate or baseline artifacts are incomplete.", call. = FALSE)
}

axis_names <- list(
  sea_sectors = c("year", "indicator", "sector", "country"),
  sea_countries = c("year", "indicator", "country"),
  m_io = c("year", "variable", "input", "output"),
  m_countries = c("year", "variable", "origin", "destination")
)

value_state <- function(value) {
  state <- rep.int(1L, length(value))
  state[is.na(value)] <- 2L
  state[is.nan(value)] <- 3L
  state[is.infinite(value) & value > 0] <- 4L
  state[is.infinite(value) & value < 0] <- 5L
  state
}

coordinate_label <- function(value, indices, axes) {
  labels <- vapply(seq_along(indices), function(axis) {
    values <- dimnames(value)[[axis]]
    if (is.null(values)) as.character(indices[[axis]]) else
      values[[indices[[axis]]]]
  }, character(1L))
  paste0(axes, "=", labels, collapse = ";")
}

slice_position <- function(position, dimensions, first_axis) {
  trailing <- if (length(dimensions) > 1L) {
    as.integer(arrayInd(position, dimensions[-1L]))
  } else {
    integer()
  }
  c(first_axis, trailing)
}

compare_array <- function(candidate, baseline, artifact) {
  same_dim <- identical(dim(candidate), dim(baseline))
  if (!same_dim) {
    stop(sprintf("Artifact `%s` has different dimensions.", artifact), call. = FALSE)
  }
  states <- c("finite", "NA", "NaN", "+Inf", "-Inf")
  transitions <- matrix(
    0,
    nrow = length(states),
    ncol = length(states),
    dimnames = list(candidate = states, baseline = states)
  )
  mismatch_count <- 0
  maximum_difference <- 0
  maximum_coordinate <- ""
  candidate_at_maximum <- NA_real_
  baseline_at_maximum <- NA_real_
  first_mismatch_coordinate <- ""
  first_candidate_state <- ""
  first_baseline_state <- ""
  first_candidate_value <- NA_real_
  first_baseline_value <- NA_real_
  same_na <- TRUE
  same_nan <- TRUE

  for (first_axis in seq_len(dim(candidate)[[1L]])) {
    indices <- c(
      list(first_axis),
      rep(list(TRUE), length(dim(candidate)) - 1L),
      list(drop = FALSE)
    )
    candidate_value <- as.vector(do.call("[", c(list(candidate), indices)))
    baseline_value <- as.vector(do.call("[", c(list(baseline), indices)))
    candidate_state <- value_state(candidate_value)
    baseline_state <- value_state(baseline_value)
    transitions <- transitions + unclass(table(
      factor(candidate_state, levels = seq_along(states)),
      factor(baseline_state, levels = seq_along(states))
    ))
    same_na <- same_na && identical(
      candidate_state %in% c(2L, 3L),
      baseline_state %in% c(2L, 3L)
    )
    same_nan <- same_nan && identical(candidate_state == 3L, baseline_state == 3L)
    finite <- candidate_state == 1L & baseline_state == 1L
    mismatch <- candidate_state != baseline_state
    mismatch[finite] <- candidate_value[finite] != baseline_value[finite]
    mismatch_count <- mismatch_count + sum(mismatch)

    if (!nzchar(first_mismatch_coordinate) && any(mismatch)) {
      position <- which(mismatch)[[1L]]
      coordinates <- slice_position(position, dim(candidate), first_axis)
      first_mismatch_coordinate <- coordinate_label(
        candidate,
        coordinates,
        axis_names[[artifact]]
      )
      first_candidate_state <- states[[candidate_state[[position]]]]
      first_baseline_state <- states[[baseline_state[[position]]]]
      first_candidate_value <- candidate_value[[position]]
      first_baseline_value <- baseline_value[[position]]
    }
    if (any(finite)) {
      difference <- abs(candidate_value[finite] - baseline_value[finite])
      local_maximum <- max(difference)
      if (local_maximum > maximum_difference ||
          (!nzchar(maximum_coordinate) && local_maximum == maximum_difference)) {
        finite_positions <- which(finite)
        position <- finite_positions[[which.max(difference)]]
        coordinates <- slice_position(position, dim(candidate), first_axis)
        maximum_difference <- local_maximum
        maximum_coordinate <- coordinate_label(
          candidate,
          coordinates,
          axis_names[[artifact]]
        )
        candidate_at_maximum <- candidate_value[[position]]
        baseline_at_maximum <- baseline_value[[position]]
      }
    }
  }

  transition_table <- as.data.frame(as.table(transitions), stringsAsFactors = FALSE)
  names(transition_table) <- c("candidate_state", "baseline_state", "count")
  transition_table$artifact <- artifact
  transition_table <- transition_table[transition_table$count > 0, , drop = FALSE]
  comparison <- data.frame(
    artifact = artifact,
    same_dim = same_dim,
    same_dimnames = identical(dimnames(candidate), dimnames(baseline)),
    same_axis_labels = identical(unname(dimnames(candidate)), unname(dimnames(baseline))),
    same_axis_names = identical(names(dimnames(candidate)), names(dimnames(baseline))),
    same_na = same_na,
    same_nan = same_nan,
    identical_values = mismatch_count == 0,
    mismatch_count = mismatch_count,
    maximum_absolute_difference = maximum_difference,
    maximum_coordinate = maximum_coordinate,
    candidate_at_maximum = candidate_at_maximum,
    baseline_at_maximum = baseline_at_maximum,
    first_mismatch_coordinate = first_mismatch_coordinate,
    first_candidate_state = first_candidate_state,
    first_baseline_state = first_baseline_state,
    first_candidate_value = first_candidate_value,
    first_baseline_value = first_baseline_value,
    stringsAsFactors = FALSE
  )
  list(comparison = comparison, transitions = transition_table)
}

compare_indicators <- function(candidate, baseline, artifact) {
  candidate_ids <- dimnames(candidate)[[2L]]
  baseline_ids <- dimnames(baseline)[[2L]]
  rows <- lapply(candidate_ids, function(indicator) {
    candidate_index <- match(indicator, candidate_ids)
    baseline_index <- match(indicator, baseline_ids)
    if (is.na(baseline_index)) {
      return(data.frame(
        artifact = artifact, indicator = indicator,
        mismatch_count = NA_real_, maximum_absolute_difference = NA_real_,
        stringsAsFactors = FALSE
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
    candidate_state <- value_state(candidate_value)
    baseline_state <- value_state(baseline_value)
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

comparisons <- list()
transitions <- list()
indicator_comparisons <- list()
for (artifact in names(candidate_paths)) {
  phase(paste0("comparing ", artifact))
  candidate <- runtime$read_fst_array(candidate_paths[[artifact]])
  baseline <- runtime$read_fst_array(baseline_paths[[artifact]])
  result <- compare_array(candidate, baseline, artifact)
  comparisons[[artifact]] <- result$comparison
  transitions[[artifact]] <- result$transitions
  if (artifact %in% c("sea_sectors", "sea_countries")) {
    indicator_comparisons[[artifact]] <- compare_indicators(
      candidate,
      baseline,
      artifact
    )
  }
  rm(candidate, baseline, result)
  gc(FALSE)
}

comparisons <- do.call(rbind, comparisons)
transitions <- do.call(rbind, transitions)
indicator_comparisons <- do.call(rbind, indicator_comparisons)
indicator_comparisons <- indicator_comparisons[
  is.na(indicator_comparisons$mismatch_count) |
    indicator_comparisons$mismatch_count > 0,
  ,
  drop = FALSE
]
utils::write.csv(
  comparisons,
  file.path(candidate_dir, "array_comparison.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)
utils::write.csv(
  transitions,
  file.path(candidate_dir, "state_transitions.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)
utils::write.csv(
  indicator_comparisons,
  file.path(candidate_dir, "indicator_comparison.csv"),
  row.names = FALSE,
  fileEncoding = "UTF-8"
)
print(comparisons, row.names = FALSE)
print(indicator_comparisons, row.names = FALSE)

candidate_metadata <- readRDS(file.path(candidate_dir, "meta_indicators.RDS"))
baseline_metadata <- readRDS(file.path(baseline_dir, "meta_indicators.RDS"))
metadata_identical <- identical(candidate_metadata, baseline_metadata)
phase(sprintf("indicator metadata identical: %s", metadata_identical))
wlv_assert_issue13_parity(
  comparisons,
  indicator_comparisons,
  metadata_identical
)
phase("persistent native comparison finished")
