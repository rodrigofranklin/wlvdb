# Native graph construction ------------------------------------------------

wlv_native_resolved_spec_contracts <- function(registry, instance) {
  spec <- wlv_registry_module(registry, instance$module_id)
  args <- wlv_runtime_resolve_arguments(spec, instance)
  list(
    spec = spec,
    args = args,
    requires = wlv_runtime_resolve_contract_list(
      spec$requires,
      args,
      "requires",
      "wlv_resource_ref",
      instance
    ),
    provides = wlv_runtime_resolve_contract_list(
      spec$provides,
      args,
      "provides",
      "wlv_resource_output",
      instance
    )
  )
}

wlv_native_config_instances <- function(config) {
  wlv_runtime_instances(config)
}

wlv_native_instance_indicators <- function(registry, instance) {
  contracts <- wlv_native_resolved_spec_contracts(registry, instance)
  keys <- vapply(
    contracts$provides,
    function(output) output$ref$key,
    character(1L)
  )
  prefix <- "sea/sector/"
  unique(substring(keys[startsWith(keys, prefix)], nchar(prefix) + 1L))
}

wlv_native_instance_checkpoint <- function(registry, instance) {
  spec <- wlv_registry_module(registry, instance$module_id)
  wlv_runtime_checkpoint_rank(spec$checkpoint, wlv_default_checkpoint_order())
}

wlv_native_is_matrix_instance <- function(instance) {
  startsWith(instance$module_id, "matrix.") ||
    startsWith(instance$module_id, "reduced_matrix.")
}

wlv_native_select_config_instances <- function(
    registry,
    config,
    mode,
    at_stage = 1L,
    sea_vars = NULL) {
  instances <- wlv_native_config_instances(config)
  if (identical(mode, "calculate")) {
    return(instances)
  }
  keep <- vapply(instances, function(instance) {
    if (wlv_native_is_matrix_instance(instance)) {
      return(FALSE)
    }
    rank <- wlv_native_instance_checkpoint(registry, instance)
    if (identical(at_stage, 1L)) {
      return(rank %in% c(0L, 1L, 4L, 5L))
    }
    if (rank < at_stage) {
      return(FALSE)
    }
    if (is.null(sea_vars)) {
      return(TRUE)
    }
    length(intersect(
      sea_vars,
      wlv_native_instance_indicators(registry, instance)
    )) > 0L
  }, logical(1L))
  instances[keep]
}

wlv_native_expand_io_instances <- function(registry, instances, partitions) {
  result <- list()
  for (instance in instances) {
    spec <- wlv_registry_module(registry, instance$module_id)
    if (identical(spec$scope, "io_period")) {
      for (partition in partitions) {
        result[[length(result) + 1L]] <- wlv_module_instance(
          instance$instance_id,
          instance$module_id,
          args = instance$args,
          partition = partition
        )
      }
    } else {
      result[[length(result) + 1L]] <- instance
    }
  }
  result
}

wlv_native_go_price_normalizer <- function(predecessor) {
  wlv_module_instance(
    "normalize.indicator.go_price.r.id",
    "indicator.price_index.normalize",
    args = list(
      indicator = "go_price.r.id",
      predecessor = predecessor,
      base_year = "2000",
      copy_usa_to_row = TRUE
    )
  )
}

wlv_native_go_price_predecessor <- function(config, mode, at_stage) {
  if (identical(mode, "recalculate") && at_stage >= 4L) {
    return("indicator.go_price.r.id")
  }
  row <- config[config$instance_id == "assumption.row", , drop = FALSE]
  if (nrow(row) == 1L && row$module_id[[1L]] %in% c(
    "assumption.row.standard", "assumption.row.v09",
    "assumption.row.none", "assumption.row.reduction_problem"
  )) {
    return("assumption.row")
  }
  "indicator.go_price.r.id"
}

wlv_native_apply_argument_overrides <- function(instances, overrides) {
  if (!length(overrides)) return(instances)
  lapply(instances, function(instance) {
    replacement <- overrides[[instance$instance_id]]
    if (is.null(replacement)) return(instance)
    wlv_module_instance(
      instance$instance_id,
      instance$module_id,
      args = utils::modifyList(instance$args, replacement),
      partition = instance$partition
    )
  })
}

wlv_native_auxiliary_instances <- function(
    registry,
    config,
    active_instances,
    partitions,
    mode,
    at_stage,
    sea_vars,
    indicators) {
  active_ids <- unique(vapply(
    active_instances,
    function(instance) instance$instance_id,
    character(1L)
  ))
  active_config <- config[config$instance_id %in% active_ids, , drop = FALSE]
  go_price_predecessor <- wlv_native_go_price_predecessor(
    config,
    mode,
    at_stage
  )
  auxiliary <- wlv_native_indicator_auxiliary_instances(
    active_config,
    partitions,
    go_price_predecessor = go_price_predecessor
  )
  primary_argument_overrides <- attr(
    auxiliary,
    "primary_argument_overrides",
    exact = TRUE
  )
  if (identical(mode, "recalculate") && at_stage >= 5L) {
    auxiliary <- Filter(function(instance) {
      !startsWith(instance$instance_id, "normalize.") &&
        !identical(instance$instance_id, "indicator.basket_zero.collector")
    }, auxiliary)
  }
  needs_inherited_go_normalization <- identical(mode, "recalculate") &&
    identical(at_stage, 4L) &&
    "go_price.r.id" %in% indicators &&
    (is.null(sea_vars) || "go_price.r.id" %in% sea_vars)
  if (needs_inherited_go_normalization) {
    auxiliary <- Filter(function(instance) {
      !identical(instance$instance_id, "normalize.indicator.go_price.r.id")
    }, auxiliary)
    auxiliary[[length(auxiliary) + 1L]] <-
      wlv_native_go_price_normalizer("indicator.go_price.r.id")
  }
  attr(auxiliary, "primary_argument_overrides") <- primary_argument_overrides
  auxiliary
}

wlv_native_plan_instances <- function(
    registry,
    config,
    aggregation_registry,
    indicators,
    partitions,
    mode = c("calculate", "recalculate"),
    at_stage = 1L,
    sea_vars = NULL) {
  mode <- match.arg(mode)
  wlv_native_assert_registry_covers_config(registry, config)
  active <- wlv_native_select_config_instances(
    registry,
    config,
    mode,
    at_stage,
    sea_vars
  )
  auxiliary <- wlv_native_auxiliary_instances(
    registry,
    config,
    active,
    partitions,
    mode,
    at_stage,
    sea_vars,
    indicators
  )
  active <- wlv_native_apply_argument_overrides(
    active,
    attr(auxiliary, "primary_argument_overrides", exact = TRUE)
  )
  expanded <- wlv_native_expand_io_instances(registry, active, partitions)
  selected_indicators <- if (identical(mode, "calculate") || is.null(sea_vars)) {
    indicators
  } else {
    indicators[indicators %in% sea_vars]
  }
  country_bindings <- lapply(selected_indicators, function(indicator) {
    wlv_aggregation_registry_binding(
      aggregation_registry,
      indicator,
      "sector_to_country"
    )
  })
  direct <- selected_indicators[!vapply(country_bindings, function(binding) {
    identical(binding$contract_strategy, "formula")
  }, logical(1L))]
  aggregation <- if (length(direct)) {
    list(wlv_native_aggregation_instance(
      aggregation_registry,
      selected_indicators,
      all_indicators = indicators
    ))
  } else {
    list()
  }
  assemblers <- list(wlv_module_instance(
    "assembler.panel",
    "assembler.panel",
    args = list(indicators = as.list(indicators))
  ))
  if (identical(mode, "calculate")) {
    assemblers <- c(assemblers, list(wlv_module_instance(
      "assembler.matrices",
      "assembler.matrices",
      args = list(
        io_resources = as.list(c(
          "k_composition", "k_depreciation", "values",
          "transfers_values", "consumption_basket"
        )),
        country_resources = as.list(c(
          "exports_values", "exports_mp", "exports_productive_mp",
          "transfers_values", "transfers_productive_values",
          "transfers_dp", "transfers_productive_dp"
        ))
      )
    )))
  }
  result <- c(expanded, auxiliary, aggregation, assemblers)
  wlv_runtime_instances(result)
}

wlv_native_dummy_value <- function(contract) {
  if (!is.null(contract$axes)) {
    if (!length(contract$axes)) {
      return(switch(
        contract$value_type,
        character = "dummy",
        logical = TRUE,
        integer = 1L,
        double = 1,
        numeric = 1,
        1
      ))
    }
    value <- array(
      1,
      dim = rep(1L, length(contract$axes)),
      dimnames = stats::setNames(
        rep(list("dummy"), length(contract$axes)),
        contract$axes
      )
    )
    return(value)
  }
  switch(
    contract$value_type,
    character = "dummy",
    logical = TRUE,
    integer = 1L,
    double = 1,
    numeric = 1,
    list = list(dummy = 1),
    data.frame = data.frame(dummy = 1),
    array = array(1, dim = 1L, dimnames = list(dummy = "dummy")),
    1
  )
}

wlv_native_preflight_dummy_value <- function(
    key,
    contract,
    seed_contracts) {
  if (!identical(contract$role, "semantic_state")) {
    return(wlv_native_dummy_value(contract))
  }
  target_key <- wlv_semantic_state_target_key(key)
  target_contract <- seed_contracts[[target_key]]
  if (is.null(target_contract) ||
      !identical(target_contract$role, "value") ||
      !isTRUE(target_contract$semantic_state)) {
    stop(
      sprintf(
        "Native preflight semantic seed `%s` lacks its stateful value contract.",
        key
      ),
      call. = FALSE
    )
  }
  value <- wlv_native_dummy_value(target_contract)
  wlv_semantic_capture_value_state(
    value = value,
    target_key = target_key,
    axes = target_contract$axes
  )$state
}

wlv_native_preflight_validate_semantic_seed_pairs <- function(seeds) {
  locators <- vapply(seeds, function(seed) {
    wlv_runtime_locator_id(seed$key, seed$partition, seed$producer)
  }, character(1L))
  if (anyDuplicated(locators)) {
    stop("Native preflight produced duplicate seed locators.", call. = FALSE)
  }
  by_locator <- stats::setNames(seeds, locators)
  values <- Filter(function(seed) {
    identical(seed$contract$role, "value") && isTRUE(seed$contract$semantic_state)
  }, seeds)
  states <- Filter(function(seed) {
    identical(seed$contract$role, "semantic_state")
  }, seeds)
  expected <- vapply(values, function(seed) {
    wlv_runtime_locator_id(
      wlv_semantic_state_key(seed$key),
      seed$partition,
      seed$producer
    )
  }, character(1L))
  observed <- vapply(states, function(seed) {
    wlv_runtime_locator_id(seed$key, seed$partition, seed$producer)
  }, character(1L))
  if (!setequal(expected, observed)) {
    stop("Native preflight produced incomplete semantic seed pairs.", call. = FALSE)
  }
  for (index in seq_along(values)) {
    value_seed <- values[[index]]
    state_seed <- by_locator[[expected[[index]]]]
    wlv_semantic_state_validate(
      state_seed$value,
      value = value_seed$value,
      target_key = value_seed$key,
      axes = value_seed$contract$axes,
      state_key = state_seed$key
    )
  }
  invisible(seeds)
}

wlv_native_preflight_seed_contracts <- function(
    source,
    mode,
    at_stage,
    indicators) {
  mode <- match.arg(mode, c("calculate", "recalculate"))
  if (!is.character(source) || length(source) != 1L || is.na(source) ||
      !source %in% c("wiodr13", "wiodr16")) {
    stop("Native preflight requires a registered executable source.", call. = FALSE)
  }
  if (!is.numeric(at_stage) || length(at_stage) != 1L || is.na(at_stage) ||
      !at_stage %in% c(1L, 4L, 5L)) {
    stop("Native preflight requires checkpoint 1, 4, or 5.", call. = FALSE)
  }
  if (!is.character(indicators) || !length(indicators) || anyNA(indicators) ||
      any(!nzchar(indicators)) || anyDuplicated(indicators)) {
    stop("Native preflight requires unique declared output indicators.", call. = FALSE)
  }

  run_contract <- function(value_type) {
    wlv_resource_contract(scope = "run", value_type = value_type)
  }
  contracts <- list(
    "request/method" = wlv_native_control_contract("character"),
    "request/source" = wlv_native_control_contract("character"),
    "configuration/missingness_policy" = wlv_native_control_contract("list"),
    "configuration/scientific_profile" = wlv_native_control_contract("list"),
    "configuration/parameters" = run_contract("data.frame"),
    "configuration/sectors" = run_contract("data.frame"),
    "dimensions/lists" = run_contract("list"),
    "dimensions/nums" = run_contract("list"),
    "dimensions/rows" = run_contract("data.frame"),
    "dimensions/columns" = run_contract("data.frame"),
    "dimensions/io_filters" = wlv_native_filters_contract(),
    "labels/countries" = run_contract("data.frame"),
    "labels/demands" = run_contract("data.frame"),
    "source/sea" = wlv_native_source_sea_contract(),
    "metadata/indicators" = wlv_native_indicator_metadata_contract(),
    "assumption/employment_row_current" = run_contract("data.frame"),
    "assumption/employment_row_legacy" = run_contract("data.frame"),
    "assumption/employment_china" = run_contract("data.frame")
  )
  if (identical(source, "wiodr16")) {
    contracts[["assumption/china_hours_per_worker"]] <-
      wlv_native_array_contract(
        scope = "run",
        axes = c("year", "sector"),
        missingness = "none"
      )
  }

  if (identical(mode, "calculate")) {
    contracts[["source/io"]] <- wlv_native_source_io_contract()
    contracts[["source/euklems/capital_weights"]] <-
      wlv_native_euklems_table_list_contract("capital_weights")
    contracts[["source/euklems/depreciation_rates"]] <-
      wlv_native_euklems_table_list_contract("depreciation_rates")
    contracts[["source/gfcf_observations"]] <-
      wlv_native_gfcf_observations_contract()
  } else {
    for (indicator in indicators) {
      contracts[[wlv_native_indicator_key(indicator, "sector")]] <-
        wlv_native_indicator_contract(indicator, level = "sector")
      contracts[[wlv_native_indicator_key(indicator, "country")]] <-
        wlv_native_indicator_contract(indicator, level = "country")
    }
    if (at_stage <= 4L) {
      contracts[["source/io"]] <- wlv_native_source_io_contract()
      for (resource in c(
        "k_composition", "k_depreciation", "values",
        "transfers_values", "consumption_basket"
      )) {
        contracts[[paste0("io/", resource)]] <-
          wlv_native_io_contract(resource)
      }
      contracts[["intermediate/lambda"]] <-
        wlv_native_intermediate_contract(
          "lambda",
          c("year", "input"),
          "io_period"
        )
    }
  }
  stateful_keys <- names(contracts)[vapply(contracts, function(contract) {
    identical(contract$role, "value") && isTRUE(contract$semantic_state)
  }, logical(1L))]
  for (key in stateful_keys) {
    contracts[[wlv_semantic_state_key(key)]] <-
      wlv_native_semantic_state_contract(contracts[[key]])
  }
  contracts
}

wlv_native_preflight_store <- function(
    registry,
    instances,
    partitions,
    mode,
    source,
    at_stage,
    indicators) {
  seed_contracts <- wlv_native_preflight_seed_contracts(
    source,
    mode,
    at_stage,
    indicators
  )
  resolved <- lapply(instances, function(instance) {
    wlv_runtime_resolve_instance(
      registry,
      instance,
      operation = if (identical(mode, "calculate")) "calculate" else "recalculate",
      partitions = partitions
    )
  })
  provided <- list()
  for (module in resolved) {
    for (output in module$provides) {
      ref <- output$ref
      id <- wlv_runtime_locator_id(ref$key, ref$partition, module$instance_id)
      provided[[id]] <- TRUE
    }
  }
  requests <- list()
  add_request <- function(ref, partition) {
    producer <- if (is.null(ref$producer)) {
      wlv_runtime_seed_producer()
    } else {
      ref$producer
    }
    id <- wlv_runtime_locator_id(ref$key, partition, producer)
    group_provided <- any(vapply(resolved, function(module) {
      any(vapply(module$provides, function(output) {
        identical(output$ref$key, ref$key) &&
          identical(output$ref$partition, partition)
      }, logical(1L)))
    }, logical(1L)))
    exact_provided <- id %in% names(provided)
    if (exact_provided || (is.null(ref$producer) && group_provided)) {
      return(invisible(NULL))
    }
    seed_contract <- seed_contracts[[ref$key]]
    if (is.null(seed_contract)) {
      stop(
        sprintf("Native preflight found undeclared dependency `%s`.", ref$key),
        call. = FALSE
      )
    }
    if (!wlv_runtime_contract_compatible(ref$contract, seed_contract)) {
      stop(
        sprintf(
          "Native preflight found an incompatible contract for seed `%s`.",
          ref$key
        ),
        call. = FALSE
      )
    }
    group <- wlv_runtime_resource_group_id(ref$key, partition)
    requests[[group]] <<- c(
      requests[[group]],
      list(list(
        ref = ref,
        partition = partition,
        producer = producer,
        seed_contract = seed_contract
      ))
    )
    invisible(NULL)
  }
  for (module in resolved) {
    for (ref in module$requires) {
      if (ref$collect) {
        for (partition in partitions) {
          add_request(ref, partition)
        }
      } else {
        add_request(ref, ref$partition)
      }
    }
  }
  seeds <- lapply(requests, function(group) {
    explicit <- unique(vapply(group, function(request) {
      request$producer
    }, character(1L)))
    explicit <- setdiff(explicit, wlv_runtime_seed_producer())
    if (length(explicit) > 1L) {
      stop(
        sprintf(
          "Inherited resource `%s` has incompatible expected producers: %s.",
          group[[1L]]$ref$key,
          paste(sort(explicit), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    producer <- if (length(explicit)) explicit[[1L]] else wlv_runtime_seed_producer()
    contracts <- lapply(group, function(request) request$ref$contract)
    compatible <- vapply(contracts[-1L], function(contract) {
      wlv_runtime_contract_compatible(contracts[[1L]], contract) &&
        wlv_runtime_contract_compatible(contract, contracts[[1L]])
    }, logical(1L))
    if (length(compatible) && any(!compatible)) {
      stop(
        sprintf(
          "Inherited resource `%s` has incompatible requested contracts.",
          group[[1L]]$ref$key
        ),
        call. = FALSE
      )
    }
    wlv_seed_resource(
      group[[1L]]$ref$key,
      wlv_native_preflight_dummy_value(
        group[[1L]]$ref$key,
        group[[1L]]$seed_contract,
        seed_contracts
      ),
      group[[1L]]$seed_contract,
      partition = group[[1L]]$partition,
      producer = producer
    )
  })
  wlv_native_preflight_validate_semantic_seed_pairs(unname(seeds))
  wlv_new_resource_store(unname(seeds))
}

wlv_native_preflight_plan <- function(
    registry,
    instances,
    partitions,
    mode,
    source,
    at_stage = 1L,
    indicators) {
  store <- wlv_native_preflight_store(
    registry,
    instances,
    partitions,
    mode,
    source,
    at_stage,
    indicators
  )
  wlv_compile_module_plan(
    registry,
    instances,
    store = store,
    operation = if (identical(mode, "calculate")) "calculate" else "recalculate",
    partitions = partitions
  )
}
