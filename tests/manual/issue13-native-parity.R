wlv_issue13_parity_boolean_fields <- c(
  "same_dim",
  "same_dimnames",
  "same_axis_labels",
  "same_axis_names",
  "same_na",
  "same_nan",
  "identical_values"
)

wlv_issue13_parity_passed <- function(
    comparisons,
    indicator_differences,
    metadata_identical) {
  required <- c(
    "artifact",
    wlv_issue13_parity_boolean_fields,
    "mismatch_count",
    "maximum_absolute_difference"
  )
  if (!is.data.frame(comparisons) || !nrow(comparisons) ||
      !all(required %in% names(comparisons)) ||
      !is.data.frame(indicator_differences) ||
      !is.logical(metadata_identical) || length(metadata_identical) != 1L ||
      is.na(metadata_identical)) {
    return(FALSE)
  }
  booleans <- comparisons[wlv_issue13_parity_boolean_fields]
  valid_booleans <- all(vapply(booleans, is.logical, logical(1L))) &&
    !anyNA(booleans) && all(unlist(booleans, use.names = FALSE))
  valid_numbers <- is.numeric(comparisons$mismatch_count) &&
    is.numeric(comparisons$maximum_absolute_difference) &&
    !anyNA(comparisons$mismatch_count) &&
    !anyNA(comparisons$maximum_absolute_difference) &&
    all(is.finite(comparisons$mismatch_count)) &&
    all(is.finite(comparisons$maximum_absolute_difference)) &&
    all(comparisons$mismatch_count == 0) &&
    all(comparisons$maximum_absolute_difference == 0)
  isTRUE(valid_booleans) && isTRUE(valid_numbers) &&
    isTRUE(metadata_identical) && nrow(indicator_differences) == 0L
}

wlv_assert_issue13_parity <- function(
    comparisons,
    indicator_differences,
    metadata_identical) {
  if (!wlv_issue13_parity_passed(
      comparisons,
      indicator_differences,
      metadata_identical
    )) {
    stop(
      paste0(
        "Issue #13 scientific parity failed; inspect array_comparison.csv, ",
        "state_transitions.csv, and indicator_comparison.csv."
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}
