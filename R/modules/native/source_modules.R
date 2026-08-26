# Canonical normalized-source modules --------------------------------------

wlv_native_source_sea_contract <- function() {
  wlv_native_array_contract(
    scope = "run",
    axes = c("year", "variable", "sector", "country"),
    unit = "normalized_source_sea",
    missingness = "source_contract",
    semantic_state = TRUE
  )
}

wlv_source_indicator_spec <- function() {
  wlv_native_module_spec(
  id = "source_indicator",
  scope = "run",
  checkpoint = 0L,
  operations = c("calculate", "recalculate"),
  parameters = list(
    indicator = wlv_module_parameter("character"),
    source_variable = wlv_module_parameter("character")
  ),
  requires = list(
    source = wlv_resource_ref(
      "source/sea",
      wlv_native_source_sea_contract(),
      producer = wlv_runtime_seed_producer()
    )
  ),
  provides = function(args) {
    wlv_native_indicator_output(args$indicator, scope = "run")
  },
  run = function(ctx) {
    source <- ctx$input("source")
    source_state <- ctx$input("semantic_state__source")
    indicator <- ctx$arg("indicator")
    source_variable <- ctx$arg("source_variable")
    available <- dimnames(source)[[2L]]
    if (!source_variable %in% available) {
      stop(
        sprintf(
          "SEA source variable `%s` required by `%s` is unavailable.",
          source_variable,
          indicator
        ),
        call. = FALSE
      )
    }
    value <- source[, source_variable, , , drop = FALSE]
    value <- array(
      value,
      dim = dim(source)[c(1L, 3L, 4L)],
      dimnames = dimnames(source)[c(1L, 3L, 4L)]
    )
    output_axes <- c("year", "sector", "country")
    value <- wlv_native_with_named_axes(value, output_axes)
    state_rows <- source_state[
      source_state$variable == source_variable,
      c(output_axes, "state"),
      drop = FALSE
    ]
    state <- wlv_semantic_new_state_resource(
      state_rows,
      target_key = wlv_native_indicator_key(indicator, "sector"),
      axes = output_axes
    )
    wlv_module_result(outputs = list(
      value = value,
      semantic_state__value = state
    ))
  }
)
}
