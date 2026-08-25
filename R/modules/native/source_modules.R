# Canonical normalized-source modules --------------------------------------

wlv_native_source_sea_contract <- function() {
  wlv_native_array_contract(
    scope = "run",
    axes = c("year", "variable", "sector", "country"),
    unit = "normalized_source_sea",
    missingness = "source_contract"
  )
}

wlv_source_indicator_spec <- function() {
  wlv_module_spec(
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
    value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
    wlv_module_result(outputs = list(value = value))
  }
)
}
