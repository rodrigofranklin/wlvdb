# Stage-4 indicator collector ----------------------------------------------
#
# Convention: each io-period instance writes `sea/sector/<indicator>` in its
# own partition.  A run-scoped instance named
# `collector.indicator.<indicator>` uses this spec to create the resource with
# the same key at run scope.  The collector requires exact, non-overlapping
# coverage of `dimensions/lists$years` and preserves all values and NA states.

wlv_indicator_stage4_collector_spec <- function() {
  wlv_native_module_spec(
  id = "indicator.stage4_collector",
  scope = "run",
  checkpoint = "after_stage_4",
  operations = c("calculate", "recalculate"),
  parameters = list(
    indicator = wlv_module_parameter("character")
  ),
  requires = function(args) {
    c(
      wlv_native_indicator_ref(
        args$indicator,
        alias = "partitions",
        scope = "io_period",
        partition = "*",
        collect = TRUE
      ),
      wlv_native_run_ref("dimensions/lists", "lists", "list")
    )
  },
  provides = function(args) {
    wlv_native_indicator_output(args$indicator, scope = "run")
  },
  run = function(ctx) {
    partitions <- ctx$input("partitions")
    lists <- ctx$input("lists")
    if (!length(partitions)) {
      stop("A stage-4 collector requires at least one partition.", call. = FALSE)
    }
    expected_years <- as.character(lists$years)
    observed_years <- unlist(
      lapply(partitions, function(value) dimnames(value)[[1L]]),
      use.names = FALSE
    )
    duplicates <- unique(observed_years[duplicated(observed_years)])
    missing <- setdiff(expected_years, observed_years)
    unexpected <- setdiff(observed_years, expected_years)
    if (length(duplicates) || length(missing) || length(unexpected)) {
      details <- c(
        if (length(duplicates)) paste0("duplicate years: ", paste(duplicates, collapse = ", ")),
        if (length(missing)) paste0("missing years: ", paste(missing, collapse = ", ")),
        if (length(unexpected)) paste0("unexpected years: ", paste(unexpected, collapse = ", "))
      )
      stop(
        sprintf("Incomplete stage-4 indicator coverage (%s).", paste(details, collapse = "; ")),
        call. = FALSE
      )
    }
    for (value in partitions) {
      if (!identical(dimnames(value)[[2L]], lists$sectors) ||
          !identical(dimnames(value)[[3L]], lists$countries)) {
        stop("Stage-4 partitions have incompatible sector/country labels.", call. = FALSE)
      }
    }
    result <- array(
      NA_real_,
      dim = c(length(expected_years), length(lists$sectors), length(lists$countries)),
      dimnames = list(
        year = expected_years,
        sector = lists$sectors,
        country = lists$countries
      )
    )
    for (value in partitions) {
      result[dimnames(value)[[1L]], , ] <- value
    }
    state <- wlv_semantic_state_merge(
      resources = ctx$input("semantic_state__partitions"),
      values = partitions,
      partition_axis = "year"
    )
    wlv_module_result(outputs = list(
      value = result,
      semantic_state__value = state
    ))
  }
)
}
