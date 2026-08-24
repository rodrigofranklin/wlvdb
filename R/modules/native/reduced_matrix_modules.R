# Native country-matrix reductions ----------------------------------------

wlv_native_reduce_country_matrix <- function(
    value,
    filters,
    nums,
    productive = FALSE,
    year_apply = base::apply) {
  if (productive) {
    value <- value * rep(
      filters["productive_sectors", , ],
      each = nums$years
    )
  }
  country_groups <- base::as.factor(filters["countries", , ])
  grouped <- year_apply(
    newDim(value, c(nums$years, nums$input, nums$output)),
    1L,
    base::tapply,
    country_groups,
    base::sum,
    na.rm = TRUE
  )
  result <- aperm(grouped, c(2L, 1L)) *
    rep(1 - diag(nums$countries), each = nums$years)
  result
}

wlv_reduced_matrix_spec <- function(
    id,
    output,
    input,
    source = c("result", "source"),
    productive = FALSE) {
  source <- match.arg(source)
  input_ref <- if (identical(source, "source")) {
    wlv_native_source_io_ref("matrix")
  } else {
    wlv_native_io_ref(input, "matrix")
  }
  wlv_module_spec(
    id = id,
    scope = "io_period",
    checkpoint = 4L,
    operations = "calculate",
    requires = c(
      input_ref,
      list(filters = wlv_resource_ref(
        "dimensions/io_filters",
        wlv_native_filters_contract(),
        producer = wlv_runtime_seed_producer
      )),
      wlv_native_run_ref("dimensions/nums", "nums", "list")
    ),
    provides = wlv_native_country_matrix_output(output),
    services = "year_apply",
    run = local({
      is_productive <- productive
      function(ctx) {
        value <- wlv_native_reduce_country_matrix(
          ctx$input("matrix"),
          ctx$input("filters"),
          ctx$input("nums"),
          productive = is_productive,
          year_apply = ctx$service("year_apply")
        )
        source_value <- ctx$input("matrix")
        input_labels <- dimnames(ctx$input("filters"))[[2L]]
        country_labels <- sub(
          "[.].*$",
          "",
          input_labels[seq.int(
            1L,
            ctx$input("nums")$input,
            by = ctx$input("nums")$sectors
          )]
        )
        value <- array(
          value,
          dim = c(
            dim(source_value)[[1L]],
            ctx$input("nums")$countries,
            ctx$input("nums")$countries
          ),
          dimnames = list(
            year = dimnames(source_value)[[1L]],
            origin = country_labels,
            destination = country_labels
          )
        )
        wlv_module_result(outputs = list(value = value))
      }
    })
  )
}

wlv_reduced_exports_values_spec <- wlv_reduced_matrix_spec(
  "reduced_matrix.exports_values",
  "exports_values",
  "values"
)
wlv_reduced_exports_mp_spec <- wlv_reduced_matrix_spec(
  "reduced_matrix.exports_mp",
  "exports_mp",
  "source_io",
  source = "source"
)
wlv_reduced_exports_productive_mp_spec <- wlv_reduced_matrix_spec(
  "reduced_matrix.exports_productive_mp",
  "exports_productive_mp",
  "source_io",
  source = "source",
  productive = TRUE
)
wlv_reduced_transfers_values_spec <- wlv_reduced_matrix_spec(
  "reduced_matrix.transfers_values",
  "transfers_values",
  "transfers_values"
)
wlv_reduced_transfers_productive_values_spec <- wlv_reduced_matrix_spec(
  "reduced_matrix.transfers_productive_values",
  "transfers_productive_values",
  "transfers_values",
  productive = TRUE
)

wlv_reduced_direct_price_spec <- function(id, output, input) {
  wlv_module_spec(
    id = id,
    scope = "io_period",
    checkpoint = 4L,
    operations = "calculate",
    requires = c(
      wlv_native_country_matrix_ref(input, "matrix"),
      wlv_native_intermediate_ref(
        "balance_factor",
        axes = "year",
        producer = "matrix.transfers_values"
      )
    ),
    provides = wlv_native_country_matrix_output(output),
    run = function(ctx) {
      value <- ctx$input("matrix") / as.numeric(ctx$input("balance_factor"))
      value <- wlv_native_with_named_axes(
        value,
        c("year", "origin", "destination")
      )
      wlv_module_result(outputs = list(value = value))
    }
  )
}

wlv_reduced_transfers_dp_spec <- wlv_reduced_direct_price_spec(
  "reduced_matrix.transfers_dp",
  "transfers_dp",
  "transfers_values"
)
wlv_reduced_transfers_productive_dp_spec <- wlv_reduced_direct_price_spec(
  "reduced_matrix.transfers_productive_dp",
  "transfers_productive_dp",
  "transfers_productive_values"
)
