if (!exists("wlv_aggregation_registry", inherits = FALSE)) {
  stop(
    "Country aggregation requires a validated typed aggregation registry.",
    call. = FALSE
  )
}
wlv_validate_aggregation_registry(wlv_aggregation_registry)

wlv_sea_aggregation_input <- function(value, indicator, level) {
  indicator_axis <- dimnames(value)[[2L]]
  if (!indicator %in% indicator_axis) {
    stop(
      sprintf("Aggregation dependency `%s` is absent from the SEA array.", indicator),
      call. = FALSE
    )
  }
  if (identical(level, "sector_to_country")) {
    selected <- value[, indicator, , , drop = FALSE]
    return(array(
      selected,
      dim = dim(value)[c(1L, 3L, 4L)],
      dimnames = stats::setNames(
        dimnames(value)[c(1L, 3L, 4L)],
        c("year", "sector", "country")
      )
    ))
  }
  selected <- value[, indicator, lists$countries, drop = FALSE]
  array(
    selected,
    dim = c(dim(value)[[1L]], length(lists$countries)),
    dimnames = stats::setNames(
      list(dimnames(value)[[1L]], lists$countries),
      c("year", "country")
    )
  )
}

wlv_sea_aggregation_values <- function(value, binding) {
  inputs <- wlv_aggregation_binding_inputs(binding)
  stats::setNames(
    lapply(inputs, function(indicator) {
      wlv_sea_aggregation_input(value, indicator, binding$level)
    }),
    inputs
  )
}

wlv_sea_aggregation_states <- function(
    runtime,
    artifact,
    values,
    checkpoint) {
  if (is.null(runtime)) {
    return(NULL)
  }
  stats::setNames(
    lapply(names(values), function(indicator) {
      wlv_contract_declared_states(
        runtime,
        artifact,
        indicator,
        values[[indicator]],
        checkpoint
      )
    }),
    names(values)
  )
}

country_bindings <- lapply(sea_variables$names, function(indicator) {
  wlv_aggregation_registry_binding(
    wlv_aggregation_registry,
    indicator,
    "sector_to_country"
  )
})
world_bindings <- lapply(sea_variables$names, function(indicator) {
  wlv_aggregation_registry_binding(
    wlv_aggregation_registry,
    indicator,
    "country_to_world"
  )
})
formula <- vapply(
  country_bindings,
  function(binding) identical(binding$contract_strategy, "formula"),
  logical(1L)
)
world_formula <- vapply(
  world_bindings,
  function(binding) identical(binding$contract_strategy, "formula"),
  logical(1L)
)
formula_mismatch <- formula != world_formula | vapply(
  seq_along(country_bindings),
  function(index) {
    formula[[index]] && !identical(
      country_bindings[[index]]$module,
      world_bindings[[index]]$module
    )
  },
  logical(1L)
)
if (any(formula_mismatch)) {
  stop(
    sprintf(
      "Country aggregation formula bindings disagree for: %s.",
      paste(sea_variables$names[formula_mismatch], collapse = ", ")
    ),
    call. = FALSE
  )
}

# Direct aggregations use an independent typed specification at each level.
country_state_values <- list()
for (loop in which(!formula)) {
  indicator <- sea_variables$names[[loop]]
  country_binding <- country_bindings[[loop]]
  world_binding <- world_bindings[[loop]]
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_contract_clear_states(wlv_contract_runtime, "sea_countries", indicator)
  }
  cat(
    "Aggregating variable ", indicator,
    " (", country_binding$spec$strategy,
    " -> ", world_binding$spec$strategy, ")... \n",
    sep = ""
  )

  country_values <- wlv_sea_aggregation_values(sea_sectors, country_binding)
  country_allowed <- wlv_sea_aggregation_states(
    if (exists("wlv_contract_runtime", inherits = FALSE)) {
      wlv_contract_runtime
    } else {
      NULL
    },
    "sea_sectors",
    country_values,
    "after_country_aggregation"
  )
  country_value <- if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_contract_aggregate_spec_runtime(
      wlv_contract_runtime,
      country_binding,
      country_values,
      margin = c(1L, 3L),
      artifact = "sea_countries",
      indicator = indicator,
      checkpoint = "after_country_aggregation",
      stage = 5L,
      module = "sea_countries.R",
      axes = c(year = 1L, sector = 2L, country = 3L),
      allowed_missing = country_allowed
    )
  } else {
    wlv_aggregate_binding(country_binding, country_values, axis = 2L)
  }
  sea_countries[, indicator, lists$countries] <- country_value
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    country_state_values[[indicator]] <- attr(
      country_value,
      "wlv_state",
      exact = TRUE
    )
  }
}

# Every country value is now available, so world dependencies do not depend on
# the textual solution order (for example, a weight may be declared later).
for (loop in which(!formula)) {
  indicator <- sea_variables$names[[loop]]
  world_binding <- world_bindings[[loop]]
  world_values <- wlv_sea_aggregation_values(sea_countries, world_binding)
  world_allowed <- wlv_sea_aggregation_states(
    if (exists("wlv_contract_runtime", inherits = FALSE)) {
      wlv_contract_runtime
    } else {
      NULL
    },
    "sea_countries",
    world_values,
    "after_world_aggregation"
  )
  world_value <- if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_contract_aggregate_spec_runtime(
      wlv_contract_runtime,
      world_binding,
      world_values,
      margin = 1L,
      artifact = "sea_countries",
      indicator = indicator,
      checkpoint = "after_world_aggregation",
      stage = 5L,
      module = "sea_countries.R",
      axes = c(year = 1L, country = 2L),
      allowed_missing = world_allowed
    )
  } else {
    wlv_aggregate_binding(world_binding, world_values, axis = 2L)
  }
  sea_countries[, indicator, "WWW"] <- world_value

  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    world_states <- attr(world_value, "wlv_state", exact = TRUE)
    complete_states <- array(
      "finite",
      dim = dim(sea_countries[, indicator, , drop = FALSE]),
      dimnames = dimnames(sea_countries[, indicator, , drop = FALSE])
    )
    complete_states[, 1L, lists$countries] <-
      country_state_values[[indicator]]
    complete_states[, 1L, "WWW"] <- world_states
    wlv_contract_register_states(
      wlv_contract_runtime,
      "sea_countries",
      indicator,
      complete_states
    )
  }
}

# Formula bindings retain their dedicated country modules in this PR. They run
# after direct WWW values because legacy modules may consume those values.
for (loop in which(formula)) {
  indicator <- sea_variables$names[[loop]]
  module <- country_bindings[[loop]]$module
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_contract_clear_states(wlv_contract_runtime, "sea_countries", indicator)
  }
  source(paste0("R/modules/variables/", module))
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    value <- sea_countries[, indicator, , drop = FALSE]
    wlv_assert_no_special_values(
      wlv_contract_runtime,
      value,
      artifact = "sea_countries",
      indicator = indicator,
      checkpoint = "after_country_module",
      stage = 5L,
      module = module,
      axes = c(year = 1L, country = 3L)
    )
  }
}

if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_validate_sea_countries_contract(
    wlv_contract_runtime,
    sea_countries,
    checkpoint = "after_country_aggregation"
  )
}

rm(list = intersect(
  c(
    "loop", "indicator", "country_binding", "world_binding",
    "country_values", "country_allowed", "country_value", "country_states",
    "world_values", "world_allowed", "world_value", "world_states",
    "complete_states", "module", "value", "country_bindings",
    "world_bindings", "formula", "world_formula", "formula_mismatch",
    "country_state_values",
    "wlv_sea_aggregation_input", "wlv_sea_aggregation_values",
    "wlv_sea_aggregation_states"
  ),
  ls(envir = environment(), all.names = TRUE)
), envir = environment())
