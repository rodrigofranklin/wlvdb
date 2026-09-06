# Native country/world aggregation ----------------------------------------

wlv_native_aggregation_alias <- function(prefix, indicator) {
  paste(prefix, indicator, sep = ".")
}

wlv_native_aggregation_parameters <- function() {
  list(
  indicators = wlv_module_parameter("list", scalar = FALSE),
  direct = wlv_module_parameter("list", scalar = FALSE),
  formula = wlv_module_parameter("list", scalar = FALSE),
  country_bindings = wlv_module_parameter("list", scalar = FALSE),
  world_bindings = wlv_module_parameter("list", scalar = FALSE)
)
}

wlv_native_aggregation_requires <- function(args) {
  direct <- unlist(args$direct, use.names = FALSE)
  country_inputs <- unique(unlist(lapply(
    args$country_bindings[direct],
    wlv_aggregation_binding_inputs
  ), use.names = FALSE))
  world_inputs <- unique(unlist(lapply(
    args$world_bindings[direct],
    wlv_aggregation_binding_inputs
  ), use.names = FALSE))
  sector_refs <- unlist(lapply(country_inputs, function(indicator) {
    wlv_native_indicator_ref(
      indicator,
      alias = wlv_native_aggregation_alias("sector", indicator)
    )
  }), recursive = FALSE)
  inherited_country_inputs <- setdiff(world_inputs, direct)
  country_refs <- unlist(lapply(inherited_country_inputs, function(indicator) {
    wlv_native_indicator_ref(
      indicator,
      alias = wlv_native_aggregation_alias("country", indicator),
      level = "country"
    )
  }), recursive = FALSE)
  c(
    wlv_native_run_ref("dimensions/lists", "lists", "list"),
    sector_refs,
    country_refs
  )
}

wlv_native_aggregation_provides <- function(args) {
  direct <- unlist(args$direct, use.names = FALSE)
  unlist(lapply(direct, function(indicator) {
    wlv_native_indicator_output(
      indicator,
      alias = wlv_native_aggregation_alias("result", indicator),
      level = "country"
    )
  }), recursive = FALSE)
}

# WWW já representa o mundo: removê-lo antes da agregação impede contar o total
# duas vezes. ROW permanece, pois é uma região efetiva da tabela mundial.
wlv_native_aggregation_values <- function(ctx, binding, level, local_country) {
  inputs <- wlv_aggregation_binding_inputs(binding)
  stats::setNames(lapply(inputs, function(indicator) {
    if (identical(level, "sector_to_country")) {
      return(ctx$input(wlv_native_aggregation_alias("sector", indicator)))
    }
    value <- local_country[[indicator]]
    if (is.null(value)) {
      value <- ctx$input(wlv_native_aggregation_alias("country", indicator))
    }
    countries <- setdiff(dimnames(value)[[2L]], "WWW")
    value[, countries, drop = FALSE]
  }), inputs)
}

wlv_native_aggregation_allowed_states <- function(
    runtime,
    artifact,
    values,
    checkpoint) {
  stats::setNames(lapply(names(values), function(indicator) {
    wlv_contract_declared_states(
      runtime,
      artifact,
      indicator,
      values[[indicator]],
      checkpoint
    )
  }), names(values))
}

# Consolidação dos indicadores segundo regras versionadas, não uma soma cega.
# Setorial: ano × setor × país -> nacional: ano × país -> mundial: ano.
# Grandezas extensivas podem ser somadas; índices/médias exigem seus pesos e
# taxas exigem a fórmula dos totais. As funções de fórmula próprias produzem
# seus agregados; este módulo executa os bindings diretos do registro.
# Ex.: salários 10+90 e ocupados 1+3 dão média 25, não média simples de 10 e 30.
# Guias: docs/guide-pt.md, docs/guide-en.md e dicionários de resultados bilíngues.
wlv_native_aggregation_spec <- function() {
  wlv_native_module_spec(
  id = "aggregation.direct",
  scope = "run",
  checkpoint = "after_world_aggregation",
  operations = c("calculate", "recalculate"),
  parameters = wlv_native_aggregation_parameters(),
  requires = wlv_native_aggregation_requires,
  provides = wlv_native_aggregation_provides,
  services = "contract_runtime",
  run = function(ctx) {
    indicators <- unlist(ctx$arg("indicators"), use.names = FALSE)
    direct <- unlist(ctx$arg("direct"), use.names = FALSE)
    country_bindings <- ctx$arg("country_bindings")
    world_bindings <- ctx$arg("world_bindings")
    lists <- ctx$input("lists")
    runtime <- ctx$service("contract_runtime")
    country_values <- list()
    country_states <- list()
    for (indicator in direct) {
      binding <- country_bindings[[indicator]]
      values <- wlv_native_aggregation_values(
        ctx,
        binding,
        "sector_to_country",
        country_values
      )
      # Antes de reduzir, a política contratual decide quais ausências podem
      # participar. O resultado carrega estado próprio: um total não ganha
      # validade apenas porque sum(..., na.rm=TRUE) conseguiu produzir um número.
      allowed <- wlv_native_aggregation_allowed_states(
        runtime,
        "sea_sectors",
        values,
        "after_country_aggregation"
      )
      value <- wlv_contract_aggregate_spec_runtime(
        runtime,
        binding,
        values,
        margin = c(1L, 3L),
        artifact = "sea_countries",
        indicator = indicator,
        checkpoint = "after_country_aggregation",
        stage = 5L,
        module = "aggregation.direct",
        axes = c(year = 1L, sector = 2L, country = 3L),
        allowed_missing = allowed
      )
      state <- attr(value, "wlv_state", exact = TRUE)
      value <- array(
        as.numeric(value),
        dim = c(length(lists$years), length(lists$countries)),
        dimnames = list(year = lists$years, country = lists$countries)
      )
      country_values[[indicator]] <- value
      country_states[[indicator]] <- state
    }
    world_values <- list()
    world_states <- list()
    for (indicator in direct) {
      binding <- world_bindings[[indicator]]
      values <- wlv_native_aggregation_values(
        ctx,
        binding,
        "country_to_world",
        country_values
      )
      allowed <- wlv_native_aggregation_allowed_states(
        runtime,
        "sea_countries",
        values,
        "after_world_aggregation"
      )
      value <- wlv_contract_aggregate_spec_runtime(
        runtime,
        binding,
        values,
        margin = 1L,
        artifact = "sea_countries",
        indicator = indicator,
        checkpoint = "after_world_aggregation",
        stage = 5L,
        module = "aggregation.direct",
        axes = c(year = 1L, country = 2L),
        allowed_missing = allowed
      )
      state <- attr(value, "wlv_state", exact = TRUE)
      world_values[[indicator]] <- as.numeric(value)
      world_states[[indicator]] <- state
      wlv_contract_register_states(
        runtime,
        "sea_countries",
        indicator,
        country_states[[indicator]]
      )
    }
    outputs <- list()
    for (indicator in direct) {
      result <- wlv_native_country_array(
        country_values[[indicator]],
        world_values[[indicator]],
        lists
      )
      complete_states <- array(
        "finite",
        dim = c(length(lists$years), 1L, length(lists$countries) + 1L),
        dimnames = list(
          year = lists$years,
          indicator = indicator,
          country = c(lists$countries, "WWW")
        )
      )
      complete_states[, 1L, lists$countries] <- country_states[[indicator]]
      complete_states[, 1L, "WWW"] <- world_states[[indicator]]
      wlv_contract_register_states(
        runtime,
        "sea_countries",
        indicator,
        complete_states
      )
      outputs[[wlv_native_aggregation_alias("result", indicator)]] <- result
    }
    wlv_module_result(
      outputs = outputs,
      diagnostics = list(
        indicator_count = length(indicators),
        direct_count = length(direct),
        formula_count = length(setdiff(indicators, direct))
      )
    )
  }
)
}

wlv_native_aggregation_instance <- function(
    registry,
    indicators,
    all_indicators = indicators) {
  country_bindings <- stats::setNames(lapply(indicators, function(indicator) {
    wlv_aggregation_registry_binding(
      registry,
      indicator,
      "sector_to_country"
    )
  }), indicators)
  world_bindings <- stats::setNames(lapply(indicators, function(indicator) {
    wlv_aggregation_registry_binding(
      registry,
      indicator,
      "country_to_world"
    )
  }), indicators)
  all_country_bindings <- stats::setNames(lapply(all_indicators, function(indicator) {
    wlv_aggregation_registry_binding(
      registry,
      indicator,
      "sector_to_country"
    )
  }), all_indicators)
  all_world_bindings <- stats::setNames(lapply(all_indicators, function(indicator) {
    wlv_aggregation_registry_binding(
      registry,
      indicator,
      "country_to_world"
    )
  }), all_indicators)
  formula <- all_indicators[vapply(all_country_bindings, function(binding) {
    identical(binding$contract_strategy, "formula")
  }, logical(1L))]
  formula_world <- all_indicators[vapply(all_world_bindings, function(binding) {
    identical(binding$contract_strategy, "formula")
  }, logical(1L))]
  if (!identical(formula, formula_world)) {
    stop("Country and world formula aggregation bindings disagree.", call. = FALSE)
  }
  wlv_module_instance(
    "aggregation.direct",
    "aggregation.direct",
    args = list(
      indicators = as.list(indicators),
      direct = as.list(setdiff(indicators, formula)),
      formula = as.list(formula),
      country_bindings = country_bindings,
      world_bindings = world_bindings
    )
  )
}
