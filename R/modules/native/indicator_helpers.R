# Shared helpers for native indicator modules ------------------------------
#
# These functions reshape values without changing their storage order.  The
# legacy engine stored sector indicators as year x sector x country arrays,
# while input-output computations commonly expose year x input matrices.

wlv_native_sector_array <- function(value, lists) {
  dimensions <- c(
    length(lists$years),
    length(lists$sectors),
    length(lists$countries)
  )
  if (length(value) != prod(dimensions)) {
    stop("Indicator value is incompatible with the declared SEA dimensions.", call. = FALSE)
  }
  array(
    as.numeric(value),
    dim = dimensions,
    dimnames = list(
      year = lists$years,
      sector = lists$sectors,
      country = lists$countries
    )
  )
}

wlv_native_partition_lists <- function(value, lists) {
  years <- dimnames(value)[[1L]]
  if (is.null(years) || anyNA(years) || anyDuplicated(years)) {
    stop("An io-period indicator input requires unique year labels.", call. = FALSE)
  }
  result <- lists
  result$years <- years
  result
}

wlv_native_country_array <- function(country, world, lists) {
  country <- array(
    as.numeric(country),
    dim = c(length(lists$years), length(lists$countries)),
    dimnames = list(year = lists$years, country = lists$countries)
  )
  world <- as.numeric(world)
  if (length(world) != length(lists$years)) {
    stop("World indicator must contain one value per year.", call. = FALSE)
  }
  result <- array(
    NA_real_,
    dim = c(length(lists$years), length(lists$countries) + 1L),
    dimnames = list(
      year = lists$years,
      country = c(lists$countries, "WWW")
    )
  )
  result[, lists$countries] <- country
  result[, "WWW"] <- world
  result
}

wlv_native_sum_country_and_world <- function(value, lists) {
  country <- apply(value, c(1L, 3L), sum, na.rm = TRUE)
  country_all_missing <- apply(is.na(value), c(1L, 3L), all)
  country[country_all_missing] <- NA_real_
  # The legacy country pipeline aggregated sectors first and then countries.
  # Keeping that order also preserves floating-point reduction behavior.
  world <- apply(country, 1L, sum, na.rm = TRUE)
  world[apply(is.na(country), 1L, all)] <- NA_real_
  wlv_native_country_array(country, world, lists)
}

wlv_native_country_and_world_ratio <- function(
    runtime,
    numerator,
    denominator,
    indicator,
    numerator_indicator,
    denominator_indicator,
    module,
    lists,
    subtract_one = FALSE) {
  ratio <- wlv_country_and_world_ratio_runtime(
    runtime,
    numerator,
    denominator,
    indicator = indicator,
    numerator_indicator = numerator_indicator,
    denominator_indicator = denominator_indicator,
    checkpoint = "after_country_module",
    module = module,
    zero = "not_applicable"
  )
  country <- ratio$country
  world <- ratio$world
  country_states <- attr(country, "wlv_state", exact = TRUE)
  world_states <- attr(world, "wlv_state", exact = TRUE)
  if (subtract_one) {
    country <- country - 1
    world <- world - 1
  }
  result <- wlv_native_country_array(country, world, lists)
  if (!is.null(country_states) && !is.null(world_states)) {
    states <- array(
      "finite",
      dim = c(length(lists$years), 1L, length(lists$countries) + 1L),
      dimnames = list(
        year = lists$years,
        indicator = indicator,
        country = c(lists$countries, "WWW")
      )
    )
    states[, 1L, lists$countries] <- country_states
    states[, 1L, "WWW"] <- world_states
    wlv_contract_register_states(runtime, "sea_countries", indicator, states)
  }
  result
}

wlv_native_independent_country_ratio <- function(
    runtime,
    numerator,
    denominator,
    indicator,
    module,
    lists,
    subtract_one = FALSE) {
  numerator_country <- wlv_native_sum_country_and_world(numerator, lists)
  denominator_country <- wlv_native_sum_country_and_world(denominator, lists)
  result <- wlv_ratio_runtime(
    runtime,
    numerator_country,
    denominator_country,
    zero = "not_applicable",
    artifact = "sea_countries",
    indicator = indicator,
    checkpoint = "after_country_module",
    stage = 5L,
    module = module,
    axes = c(year = 1L, country = 2L)
  )
  if (subtract_one) result <- result - 1
  wlv_native_with_named_axes(result, c("year", "country"))
}

wlv_native_indicator_metadata_row <- function(
    code,
    name,
    description,
    observation = NA_character_,
    group,
    type,
    reverted = FALSE) {
  wlv_native_indicator_metadata(
    code = code,
    name = name,
    description = description,
    observation = observation,
    group = group,
    type = type,
    reverted = reverted
  )
}

wlv_native_indicator_spec <- function(
    id,
    checkpoint,
    requires,
    run,
    metadata,
    scope = c("run", "io_period"),
    provides = NULL,
    parameters = list(),
    services = character(),
    anomaly_bindings = list()) {
  scope <- match.arg(scope)
  indicator <- sub("^indicator[.]", "", id)
  if (is.null(provides)) {
    provides <- wlv_native_indicator_output(indicator, scope = scope)
  }
  wlv_native_attach_indicator_metadata(
    wlv_native_module_spec(
      id = id,
      scope = scope,
      checkpoint = checkpoint,
      operations = c("calculate", "recalculate"),
      parameters = parameters,
      requires = requires,
      provides = provides,
      anomaly_bindings = anomaly_bindings,
      services = services,
      run = run
    ),
    metadata
  )
}

wlv_native_stage5_provides <- function(indicator) {
  c(
    wlv_native_indicator_output(indicator, alias = "sector"),
    wlv_native_indicator_output(
      indicator,
      alias = "country",
      level = "country"
    )
  )
}

wlv_native_source_variable <- function(source, variable, lists) {
  if (!variable %in% dimnames(source)[[2L]]) {
    stop(sprintf("Normalized SEA variable `%s` is unavailable.", variable), call. = FALSE)
  }
  value <- source[, variable, lists$sectors, lists$countries, drop = FALSE]
  wlv_native_sector_array(value, lists)
}

wlv_native_source_requirements <- function(extra = list()) {
  c(
    list(source = wlv_resource_ref(
      "source/sea",
      wlv_native_source_sea_contract(),
      producer = wlv_runtime_seed_producer()
    )),
    wlv_native_run_ref("dimensions/lists", "lists", "list"),
    extra
  )
}
