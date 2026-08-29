# Shared constructors for the native scientific modules --------------------
#
# Module contracts stay beside native module definitions.  These helpers only
# remove repetitive syntax; they do not discover dependencies or infer module
# behavior from file names or configuration rows.

wlv_native_array_contract <- function(
    scope = c("run", "io_period"),
    axes,
    unit = NULL,
    missingness = NULL,
    role = c(
      "value", "semantic_state", "anomaly", "diagnostic", "metadata",
      "control"
    ),
    semantic_state = FALSE) {
  wlv_resource_contract(
    scope = match.arg(scope),
    axes = axes,
    value_type = "array",
    unit = unit,
    missingness = missingness,
    role = match.arg(role),
    semantic_state = semantic_state
  )
}

wlv_native_list_contract <- function(scope = c("run", "io_period")) {
  wlv_resource_contract(scope = match.arg(scope), value_type = "list")
}

wlv_native_data_frame_contract <- function(scope = c("run", "io_period")) {
  wlv_resource_contract(scope = match.arg(scope), value_type = "data.frame")
}

wlv_native_semantic_state_contract <- function(target_contract) {
  wlv_resource_contract_assert(target_contract, "target_contract")
  wlv_resource_contract(
    scope = target_contract$scope,
    value_type = "data.frame",
    role = "semantic_state"
  )
}

wlv_native_control_contract <- function(
    value_type = c(
      "list", "any", "numeric", "integer", "double", "logical",
      "character", "data.frame", "array"
    )) {
  wlv_resource_contract(
    scope = "run",
    value_type = match.arg(value_type),
    role = "control"
  )
}

wlv_native_contract_factory_value <- function(value, args, instance) {
  if (!is.function(value)) {
    return(value)
  }
  parameters <- names(formals(value))
  if (!length(parameters)) {
    return(value())
  }
  if (length(parameters) >= 2L || "..." %in% parameters) {
    return(value(args, instance))
  }
  value(args)
}

wlv_native_contract_list_assert <- function(value, name, class_name) {
  if (!is.list(value) || (length(value) && (
    is.null(names(value)) || anyNA(names(value)) || any(!nzchar(names(value))) ||
      anyDuplicated(names(value))
  ))) {
    stop(sprintf("Native `%s` must resolve to a uniquely named list.", name),
      call. = FALSE
    )
  }
  if (length(value) && any(!vapply(value, inherits, logical(1L), class_name))) {
    stop(sprintf("Native `%s` contains an invalid contract.", name),
      call. = FALSE
    )
  }
  invisible(value)
}

wlv_native_anomaly_target_columns <- function() {
  c("artifact", "indicator", "stage", "module", "producer_id", "action")
}

wlv_native_anomaly_binding <- function(
    artifact = c("sea_sectors", "sea_countries", "m_io", "m_countries"),
    indicator,
    action = c("replace", "preserve"),
    record_module = NULL) {
  artifact <- match.arg(artifact)
  action <- match.arg(action)
  indicator <- wlv_runtime_scalar_character(indicator, "indicator")
  if (!grepl("^[A-Za-z][A-Za-z0-9_.]*$", indicator)) {
    stop("Native anomaly indicators must be explicit indicator identifiers.",
      call. = FALSE
    )
  }
  if (!is.null(record_module)) {
    record_module <- wlv_runtime_scalar_character(
      record_module,
      "record_module"
    )
    if (
      !grepl("^[A-Za-z0-9][A-Za-z0-9._/-]*$", record_module) ||
        grepl("(^|/)\\.\\.(/|$)", record_module)
    ) {
      stop("Native anomaly record modules must be explicit scientific labels.",
        call. = FALSE
      )
    }
  }
  structure(
    list(
      artifact = artifact,
      indicator = indicator,
      action = action,
      record_module = record_module
    ),
    class = "wlv_native_anomaly_binding"
  )
}

wlv_native_anomaly_binding_assert <- function(value) {
  if (!inherits(value, "wlv_native_anomaly_binding") ||
      !is.list(value) ||
      !identical(
        names(value),
        c("artifact", "indicator", "action", "record_module")
      )) {
    stop(
      "Native anomaly bindings must be created with wlv_native_anomaly_binding().",
      call. = FALSE
    )
  }
  rebuilt <- wlv_native_anomaly_binding(
    value$artifact,
    value$indicator,
    value$action,
    value$record_module
  )
  if (!identical(value, rebuilt)) {
    stop("Native anomaly binding is not canonical.", call. = FALSE)
  }
  invisible(value)
}

wlv_native_anomaly_binding_list <- function(value, name = "anomaly_bindings") {
  if (is.null(value)) {
    value <- list()
  } else if (inherits(value, "wlv_native_anomaly_binding")) {
    value <- list(value)
  }
  if (!is.list(value) || is.data.frame(value)) {
    stop(sprintf("Native `%s` must be a list of typed anomaly bindings.", name),
      call. = FALSE
    )
  }
  lapply(value, wlv_native_anomaly_binding_assert)
  keys <- vapply(value, function(binding) {
    paste(binding$artifact, binding$indicator, sep = "\034")
  }, character(1L))
  if (anyDuplicated(keys)) {
    stop(sprintf("Native `%s` contains duplicate artifact/indicator bindings.", name),
      call. = FALSE
    )
  }
  value
}

wlv_native_default_anomaly_bindings <- function(provides) {
  wlv_native_contract_list_assert(
    provides,
    "provides",
    "wlv_resource_output"
  )
  prefixes <- c(
    sea_sectors = "sea/sector/",
    sea_countries = "sea/country/"
  )
  bindings <- list()
  for (output in provides) {
    if (!identical(output$ref$contract$role, "value")) {
      next
    }
    for (artifact in names(prefixes)) {
      prefix <- prefixes[[artifact]]
      if (startsWith(output$ref$key, prefix)) {
        bindings[[length(bindings) + 1L]] <- wlv_native_anomaly_binding(
          artifact,
          substring(output$ref$key, nchar(prefix) + 1L)
        )
      }
    }
  }
  wlv_native_anomaly_binding_list(bindings, "default anomaly bindings")
}

wlv_native_merge_anomaly_bindings <- function(defaults, explicit) {
  defaults <- wlv_native_anomaly_binding_list(
    defaults,
    "default anomaly bindings"
  )
  explicit <- wlv_native_anomaly_binding_list(explicit)
  result <- defaults
  result_keys <- vapply(result, function(binding) {
    paste(binding$artifact, binding$indicator, sep = "\034")
  }, character(1L))
  for (binding in explicit) {
    key <- paste(binding$artifact, binding$indicator, sep = "\034")
    matching <- match(key, result_keys)
    if (is.na(matching)) {
      result[[length(result) + 1L]] <- binding
      result_keys <- c(result_keys, key)
    } else {
      result[[matching]] <- binding
    }
  }
  result
}

wlv_native_anomaly_target_contract <- function(bindings, checkpoint, module_id) {
  bindings <- wlv_native_anomaly_binding_list(bindings)
  stage <- wlv_runtime_checkpoint_rank(
    checkpoint,
    wlv_default_checkpoint_order()
  )
  module_id <- wlv_runtime_scalar_character(
    module_id,
    "module_id",
    wlv_runtime_module_pattern()
  )
  value <- data.frame(
    artifact = vapply(bindings, `[[`, character(1L), "artifact"),
    indicator = vapply(bindings, `[[`, character(1L), "indicator"),
    stage = rep(as.integer(stage), length(bindings)),
    module = vapply(bindings, function(binding) {
      if (is.null(binding$record_module)) module_id else binding$record_module
    }, character(1L)),
    producer_id = rep(module_id, length(bindings)),
    action = vapply(bindings, `[[`, character(1L), "action"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )[wlv_native_anomaly_target_columns()]
  if (nrow(value)) {
    value <- value[order(
      value$artifact,
      value$indicator,
      value$module,
      value$action,
      method = "radix"
    ), , drop = FALSE]
  }
  row.names(value) <- NULL
  class(value) <- c("wlv_native_anomaly_target_contract", "data.frame")
  attr(value, "version") <- "wlv-native-anomaly-targets/2.0.0"
  value
}

wlv_native_anomaly_target_contract_assert <- function(
    value,
    checkpoint = NULL,
    module_id = NULL) {
  columns <- wlv_native_anomaly_target_columns()
  if (!inherits(value, "wlv_native_anomaly_target_contract") ||
      !is.data.frame(value) ||
      !identical(names(value), columns) ||
      !identical(
        attr(value, "version", exact = TRUE),
        "wlv-native-anomaly-targets/2.0.0"
      ) ||
      anyNA(value) ||
      !is.character(value$artifact) ||
      !is.character(value$indicator) ||
      !is.integer(value$stage) ||
      !is.character(value$module) ||
      !is.character(value$producer_id) ||
      !is.character(value$action) ||
      any(!value$artifact %in% c(
        "sea_sectors", "sea_countries", "m_io", "m_countries"
      )) ||
      any(!grepl("^[A-Za-z][A-Za-z0-9_.]*$", value$indicator)) ||
      any(value$stage < 0L) ||
      any(!grepl("^[A-Za-z0-9][A-Za-z0-9._/-]*$", value$module)) ||
      any(grepl("(^|/)\\.\\.(/|$)", value$module)) ||
      any(!grepl(wlv_runtime_module_pattern(), value$producer_id)) ||
      any(!value$action %in% c("replace", "preserve")) ||
      anyDuplicated(paste(
        value$artifact,
        value$indicator,
        value$module,
        sep = "\034"
      )) ||
      wlv_runtime_contains_reference(value)) {
    stop("Native anomaly target contract is invalid.", call. = FALSE)
  }
  if (!is.null(checkpoint)) {
    expected_stage <- wlv_runtime_checkpoint_rank(
      checkpoint,
      wlv_default_checkpoint_order()
    )
    if (any(value$stage != expected_stage)) {
      stop("Native anomaly target stage differs from the resolved checkpoint.",
        call. = FALSE
      )
    }
  }
  if (!is.null(module_id) && any(value$producer_id != module_id)) {
    stop("Native anomaly target producer differs from the resolved module.",
      call. = FALSE
    )
  }
  invisible(value)
}

wlv_native_anomaly_targets <- function(output) {
  if (!inherits(output, "wlv_resource_output") ||
      !identical(output$ref$contract$role, "anomaly")) {
    stop("Native anomaly targets require an anomaly resource output.",
      call. = FALSE
    )
  }
  value <- attr(output, "wlv_native_anomaly_targets", exact = TRUE)
  wlv_native_anomaly_target_contract_assert(value)
  value
}

wlv_native_semantic_state_alias <- function(alias) {
  paste0("semantic_state__", alias)
}

wlv_native_semantic_state_ref <- function(ref) {
  wlv_resource_ref(
    key = paste0("semantic_state/", ref$key),
    contract = wlv_native_semantic_state_contract(ref$contract),
    producer = ref$producer,
    partition = ref$partition,
    optional = ref$optional,
    collect = ref$collect
  )
}

wlv_native_semantic_state_output <- function(output) {
  ref <- output$ref
  state_contract <- wlv_native_semantic_state_contract(ref$contract)
  state_ref <- wlv_resource_ref(
    key = paste0("semantic_state/", ref$key),
    contract = state_contract,
    partition = ref$partition
  )
  predecessor <- if (is.null(output$predecessor)) {
    NULL
  } else {
    wlv_resource_ref(
      key = paste0("semantic_state/", output$predecessor$key),
      contract = state_contract,
      producer = output$predecessor$producer,
      partition = output$predecessor$partition
    )
  }
  wlv_resource_output(
    state_ref,
    action = output$action,
    predecessor = predecessor
  )
}

wlv_native_add_semantic_requires <- function(requires) {
  stateful <- names(requires)[vapply(requires, function(ref) {
    identical(ref$contract$role, "value") && isTRUE(ref$contract$semantic_state)
  }, logical(1L))]
  for (alias in stateful) {
    value_ref <- requires[[alias]]
    expected <- wlv_native_semantic_state_ref(value_ref)
    matches <- vapply(requires, function(candidate) {
      identical(candidate$contract$role, "semantic_state") &&
        identical(candidate$key, expected$key) &&
        identical(candidate$partition, expected$partition) &&
        identical(candidate$producer, expected$producer) &&
        identical(candidate$optional, expected$optional) &&
        identical(candidate$collect, expected$collect)
    }, logical(1L))
    if (sum(matches) == 1L) {
      next
    }
    if (sum(matches) > 1L) {
      stop(sprintf("Native input `%s` has duplicate semantic-state pairs.", alias),
        call. = FALSE
      )
    }
    state_alias <- wlv_native_semantic_state_alias(alias)
    if (state_alias %in% names(requires)) {
      stop(sprintf("Native input alias `%s` is reserved.", state_alias),
        call. = FALSE
      )
    }
    requires[[state_alias]] <- expected
  }
  requires
}

wlv_native_add_semantic_provides <- function(provides) {
  stateful <- names(provides)[vapply(provides, function(output) {
    identical(output$ref$contract$role, "value") &&
      isTRUE(output$ref$contract$semantic_state)
  }, logical(1L))]
  for (alias in stateful) {
    value_output <- provides[[alias]]
    expected <- wlv_native_semantic_state_output(value_output)
    matches <- vapply(provides, function(candidate) {
      identical(candidate$ref$contract$role, "semantic_state") &&
        identical(candidate$ref$key, expected$ref$key) &&
        identical(candidate$ref$partition, expected$ref$partition) &&
        identical(candidate$action, expected$action) &&
        identical(candidate$predecessor, expected$predecessor)
    }, logical(1L))
    if (sum(matches) == 1L) {
      next
    }
    if (sum(matches) > 1L) {
      stop(sprintf("Native output `%s` has duplicate semantic-state pairs.", alias),
        call. = FALSE
      )
    }
    state_alias <- wlv_native_semantic_state_alias(alias)
    if (state_alias %in% names(provides)) {
      stop(sprintf("Native output alias `%s` is reserved.", state_alias),
        call. = FALSE
      )
    }
    provides[[state_alias]] <- expected
  }
  provides
}

wlv_native_semantic_controls <- function() {
  list(
    semantic_control_method = list(
      key = "request/method",
      value_type = "character"
    ),
    semantic_control_source = list(
      key = "request/source",
      value_type = "character"
    ),
    semantic_control_missingness_policy = list(
      key = "configuration/missingness_policy",
      value_type = "list"
    ),
    semantic_control_scientific_profile = list(
      key = "configuration/scientific_profile",
      value_type = "list"
    )
  )
}

wlv_native_add_semantic_controls <- function(requires) {
  controls <- wlv_native_semantic_controls()
  for (control_alias in names(controls)) {
    definition <- controls[[control_alias]]
    matching_aliases <- names(requires)[vapply(requires, function(ref) {
      identical(ref$key, definition$key)
    }, logical(1L))]
    if (length(matching_aliases)) {
      for (alias in matching_aliases) {
        ref <- requires[[alias]]
        requires[[alias]] <- wlv_resource_ref(
          key = ref$key,
          contract = wlv_native_control_contract(definition$value_type),
          producer = ref$producer,
          partition = ref$partition,
          optional = ref$optional,
          collect = ref$collect
        )
      }
      next
    }
    if (control_alias %in% names(requires)) {
      stop(sprintf("Native input alias `%s` is reserved.", control_alias),
        call. = FALSE
      )
    }
    requires[[control_alias]] <- wlv_resource_ref(
      key = definition$key,
      contract = wlv_native_control_contract(definition$value_type),
      producer = wlv_runtime_seed_producer()
    )
  }
  requires
}

wlv_native_instance_id <- function(instance, module_id) {
  if (is.null(instance)) {
    return(module_id)
  }
  if (!is.list(instance) || is.null(instance$instance_id)) {
    stop("Native contract factories require instance metadata.", call. = FALSE)
  }
  wlv_runtime_scalar_character(
    instance$instance_id,
    "instance_id",
    wlv_runtime_identifier_pattern()
  )
}

wlv_native_add_semantic_bundles <- function(
    provides,
    scope,
    instance,
    module_id,
    anomaly_targets) {
  instance_id <- wlv_native_instance_id(instance, module_id)
  definitions <- list(
    semantic_anomaly = list(
      key = paste0("anomaly/", instance_id),
      value_type = "data.frame",
      role = "anomaly"
    ),
    semantic_diagnostic = list(
      key = paste0("diagnostic/", instance_id),
      value_type = "list",
      role = "diagnostic"
    )
  )
  for (alias in names(definitions)) {
    definition <- definitions[[alias]]
    existing <- names(provides)[vapply(provides, function(output) {
      identical(output$ref$contract$role, definition$role)
    }, logical(1L))]
    if (length(existing) > 1L) {
      stop(sprintf("Native module `%s` declares duplicate `%s` outputs.",
        module_id, definition$role
      ), call. = FALSE)
    }
    if (length(existing) == 1L) {
      if (!grepl(instance_id, provides[[existing]]$ref$key, fixed = TRUE)) {
        stop(sprintf("Native `%s` output key must contain its instance_id.",
          definition$role
        ), call. = FALSE)
      }
      next
    }
    if (alias %in% names(provides)) {
      stop(sprintf("Native output alias `%s` is reserved.", alias), call. = FALSE)
    }
    contract <- wlv_resource_contract(
      scope = scope,
      value_type = definition$value_type,
      role = definition$role
    )
    provides[[alias]] <- wlv_resource_output(wlv_resource_ref(
      key = definition$key,
      contract = contract
    ))
  }
  anomaly_alias <- names(provides)[vapply(provides, function(output) {
    identical(output$ref$contract$role, "anomaly")
  }, logical(1L))]
  if (length(anomaly_alias) != 1L) {
    stop(sprintf("Native module `%s` lacks one anomaly output.", module_id),
      call. = FALSE
    )
  }
  wlv_native_anomaly_target_contract_assert(anomaly_targets)
  attr(
    provides[[anomaly_alias]],
    "wlv_native_anomaly_targets"
  ) <- anomaly_targets
  provides
}

wlv_native_module_spec <- function(
    id,
    scope = c("run", "io_period"),
    checkpoint,
    operations = c("calculate", "recalculate"),
    parameters = list(),
    requires = list(),
    provides = list(),
    services = character(),
    run,
    anomaly_bindings = list(),
    semantic_input_mode = c("hydrated", "explicit")) {
  scope <- match.arg(scope)
  semantic_input_mode <- match.arg(semantic_input_mode)
  if (
    identical(semantic_input_mode, "explicit") &&
      "contract_runtime" %in% services
  ) {
    stop(
      "Explicit semantic-input modules cannot consume `contract_runtime`.",
      call. = FALSE
    )
  }
  original_requires <- requires
  original_provides <- provides
  original_anomaly_bindings <- anomaly_bindings
  original_run <- run
  module_id <- id
  requires_factory <- function(args, instance = NULL) {
    resolved <- wlv_native_contract_factory_value(
      original_requires,
      args,
      instance
    )
    wlv_native_contract_list_assert(
      resolved,
      "requires",
      "wlv_resource_ref"
    )
    resolved <- wlv_native_add_semantic_requires(resolved)
    wlv_native_add_semantic_controls(resolved)
  }
  provides_factory <- function(args, instance = NULL) {
    resolved <- wlv_native_contract_factory_value(
      original_provides,
      args,
      instance
    )
    wlv_native_contract_list_assert(
      resolved,
      "provides",
      "wlv_resource_output"
    )
    defaults <- wlv_native_default_anomaly_bindings(resolved)
    explicit <- wlv_native_contract_factory_value(
      original_anomaly_bindings,
      args,
      instance
    )
    bindings <- wlv_native_merge_anomaly_bindings(defaults, explicit)
    anomaly_targets <- wlv_native_anomaly_target_contract(
      bindings,
      checkpoint,
      module_id
    )
    wlv_native_anomaly_target_contract_assert(
      anomaly_targets,
      checkpoint = checkpoint,
      module_id = module_id
    )
    resolved <- wlv_native_add_semantic_provides(resolved)
    wlv_native_add_semantic_bundles(
      resolved,
      scope,
      instance,
      module_id,
      anomaly_targets
    )
  }
  wrapped_run <- function(ctx) {
    result <- original_run(ctx)
    ctx$service("module_contract")(result)
  }
  spec <- wlv_module_spec(
    id = id,
    scope = scope,
    checkpoint = checkpoint,
    operations = operations,
    parameters = parameters,
    requires = requires_factory,
    provides = provides_factory,
    services = unique(c(
      services,
      "contract_runtime",
      "module_contract"
    )),
    run = wrapped_run
  )
  attr(spec, "wlv_semantic_input_mode") <- semantic_input_mode
  spec
}

wlv_native_run_ref <- function(
    key,
    alias,
    value_type = c(
      "any", "numeric", "integer", "double", "logical", "character",
      "list", "data.frame", "array"
    ),
    producer = wlv_runtime_seed_producer(),
    optional = FALSE) {
  value_type <- match.arg(value_type)
  stats::setNames(
    list(wlv_resource_ref(
      key,
      wlv_resource_contract(scope = "run", value_type = value_type),
      producer = producer,
      optional = optional
    )),
    alias
  )
}

wlv_native_run_output <- function(
    key,
    alias = "value",
    value_type = c(
      "any", "numeric", "integer", "double", "logical", "character",
      "list", "data.frame", "array"
    ),
    action = c("create", "patch", "replace"),
    predecessor = NULL) {
  value_type <- match.arg(value_type)
  action <- match.arg(action)
  contract <- wlv_resource_contract(scope = "run", value_type = value_type)
  ref <- wlv_resource_ref(key, contract)
  previous <- if (identical(action, "create")) {
    NULL
  } else {
    wlv_resource_ref(key, contract, producer = predecessor)
  }
  stats::setNames(
    list(wlv_resource_output(ref, action = action, predecessor = previous)),
    alias
  )
}

wlv_native_indicator_key <- function(indicator, level = c("sector", "country")) {
  level <- match.arg(level)
  paste("sea", level, indicator, sep = "/")
}

wlv_native_indicator_contract <- function(
    indicator,
    scope = c("run", "io_period"),
    level = c("sector", "country")) {
  scope <- match.arg(scope)
  level <- match.arg(level)
  wlv_native_array_contract(
    scope = scope,
    axes = if (identical(level, "sector")) {
      c("year", "sector", "country")
    } else {
      c("year", "country")
    },
    unit = paste0("indicator:", indicator),
    missingness = paste0("indicator:", indicator),
    semantic_state = TRUE
  )
}

wlv_native_indicator_ref <- function(
    indicator,
    alias = indicator,
    scope = c("run", "io_period"),
    level = c("sector", "country"),
    producer = NULL,
    partition = NULL,
    optional = FALSE,
    collect = FALSE) {
  scope <- match.arg(scope)
  level <- match.arg(level)
  stats::setNames(
    list(wlv_resource_ref(
      key = wlv_native_indicator_key(indicator, level),
      contract = wlv_native_indicator_contract(indicator, scope, level),
      producer = producer,
      partition = partition,
      optional = optional,
      collect = collect
    )),
    alias
  )
}

wlv_native_indicator_output <- function(
    indicator,
    alias = "value",
    scope = c("run", "io_period"),
    level = c("sector", "country"),
    action = c("create", "patch", "replace"),
    predecessor = NULL) {
  scope <- match.arg(scope)
  level <- match.arg(level)
  action <- match.arg(action)
  ref <- wlv_resource_ref(
    key = wlv_native_indicator_key(indicator, level),
    contract = wlv_native_indicator_contract(indicator, scope, level)
  )
  previous <- if (identical(action, "create")) {
    NULL
  } else {
    wlv_resource_ref(
      key = ref$key,
      contract = ref$contract,
      producer = predecessor
    )
  }
  stats::setNames(
    list(wlv_resource_output(ref, action = action, predecessor = previous)),
    alias
  )
}

wlv_native_io_contract <- function(resource = NULL) {
  wlv_native_array_contract(
    scope = "io_period",
    axes = c("year", "input", "output"),
    unit = if (is.null(resource)) NULL else paste0("matrix:", resource),
    missingness = "matrix",
    semantic_state = TRUE
  )
}

wlv_native_source_io_contract <- function() {
  wlv_native_array_contract(
    scope = "io_period",
    axes = c("year", "input", "output"),
    unit = "normalized_source_io",
    missingness = "source_contract",
    semantic_state = TRUE
  )
}

wlv_native_source_io_ref <- function(alias = "source_io") {
  stats::setNames(
    list(wlv_resource_ref(
      "source/io",
      wlv_native_source_io_contract(),
      producer = wlv_runtime_seed_producer()
    )),
    alias
  )
}

wlv_native_intermediate_contract <- function(
    resource,
    axes,
    scope = c("io_period", "run")) {
  wlv_native_array_contract(
    scope = match.arg(scope),
    axes = axes,
    unit = paste0("intermediate:", resource),
    missingness = "intermediate",
    semantic_state = resource %in% c(
      "lambda", "balance_factor", "basket_zero", "lambda_zero"
    )
  )
}

wlv_native_intermediate_ref <- function(
    resource,
    alias = resource,
    axes,
    scope = c("io_period", "run"),
    producer = NULL,
    collect = FALSE) {
  scope <- match.arg(scope)
  stats::setNames(
    list(wlv_resource_ref(
      paste0("intermediate/", resource),
      wlv_native_intermediate_contract(resource, axes, scope),
      producer = producer,
      collect = collect
    )),
    alias
  )
}

wlv_native_intermediate_output <- function(
    resource,
    alias = resource,
    axes,
    scope = c("io_period", "run")) {
  scope <- match.arg(scope)
  stats::setNames(
    list(wlv_resource_output(wlv_resource_ref(
      paste0("intermediate/", resource),
      wlv_native_intermediate_contract(resource, axes, scope)
    ))),
    alias
  )
}

wlv_native_io_ref <- function(
    resource,
    alias = resource,
    producer = NULL,
    partition = NULL,
    optional = FALSE,
    collect = FALSE) {
  stats::setNames(
    list(wlv_resource_ref(
      key = paste0("io/", resource),
      contract = wlv_native_io_contract(resource),
      producer = producer,
      partition = partition,
      optional = optional,
      collect = collect
    )),
    alias
  )
}

wlv_native_io_output <- function(
    resource,
    alias = "value",
    action = c("create", "patch", "replace"),
    predecessor = NULL) {
  action <- match.arg(action)
  ref <- wlv_resource_ref(
    key = paste0("io/", resource),
    contract = wlv_native_io_contract(resource)
  )
  previous <- if (identical(action, "create")) {
    NULL
  } else {
    wlv_resource_ref(
      key = ref$key,
      contract = ref$contract,
      producer = predecessor
    )
  }
  stats::setNames(
    list(wlv_resource_output(ref, action = action, predecessor = previous)),
    alias
  )
}

wlv_native_country_matrix_contract <- function(resource) {
  wlv_native_array_contract(
    scope = "io_period",
    axes = c("year", "origin", "destination"),
    unit = paste0("country_matrix:", resource),
    missingness = "matrix",
    semantic_state = TRUE
  )
}

wlv_native_country_matrix_ref <- function(
    resource,
    alias = resource,
    producer = NULL,
    partition = NULL,
    collect = FALSE) {
  stats::setNames(
    list(wlv_resource_ref(
      key = paste0("country_matrix/", resource),
      contract = wlv_native_country_matrix_contract(resource),
      producer = producer,
      partition = partition,
      collect = collect
    )),
    alias
  )
}

wlv_native_country_matrix_output <- function(resource, alias = "value") {
  stats::setNames(
    list(wlv_resource_output(wlv_resource_ref(
      key = paste0("country_matrix/", resource),
      contract = wlv_native_country_matrix_contract(resource)
    ))),
    alias
  )
}

wlv_native_artifact_array_contract <- function(name, axes) {
  wlv_native_array_contract(
    scope = "run",
    axes = axes,
    unit = paste0("artifact:", name),
    missingness = "published_contract",
    semantic_state = name %in% c(
      "m_io", "m_countries", "sea_sectors", "sea_countries"
    )
  )
}

wlv_native_artifact_ref <- function(name, axes, alias = name, producer = NULL) {
  stats::setNames(
    list(wlv_resource_ref(
      paste0("artifact/", name),
      wlv_native_artifact_array_contract(name, axes),
      producer = producer
    )),
    alias
  )
}

wlv_native_artifact_output <- function(name, axes, alias = name) {
  stats::setNames(
    list(wlv_resource_output(wlv_resource_ref(
      paste0("artifact/", name),
      wlv_native_artifact_array_contract(name, axes)
    ))),
    alias
  )
}

wlv_native_with_named_axes <- function(value, axes) {
  if (is.null(dim(value)) || length(dim(value)) != length(axes)) {
    stop(
      sprintf("Value does not have the expected %d axes.", length(axes)),
      call. = FALSE
    )
  }
  value_dimnames <- dimnames(value)
  if (is.null(value_dimnames) || any(vapply(value_dimnames, is.null, logical(1L)))) {
    stop("Native resource values require complete dimnames.", call. = FALSE)
  }
  names(value_dimnames) <- axes
  dimnames(value) <- value_dimnames
  value
}

wlv_native_indicator_metadata <- function(
    code,
    name,
    description,
    observation = NA_character_,
    group,
    type,
    reverted = FALSE) {
  data.frame(
    code = code,
    name = name,
    description = description,
    observation = observation,
    group = group,
    type = type,
    reverted = as.logical(reverted),
    stringsAsFactors = FALSE,
    row.names = code
  )
}

wlv_native_attach_indicator_metadata <- function(spec, metadata) {
  if (!inherits(spec, "wlv_module_spec") || !is.data.frame(metadata) ||
      nrow(metadata) != 1L) {
    stop("Indicator metadata must accompany one native module spec.", call. = FALSE)
  }
  attr(spec, "wlv_indicator_metadata") <- metadata
  spec
}

wlv_native_indicator_metadata_contract <- function() {
  wlv_resource_contract(
    scope = "run",
    value_type = "data.frame",
    role = "metadata"
  )
}

wlv_native_indicator_metadata_ref <- function(
    alias = "indicator_metadata",
    producer = wlv_runtime_seed_producer()) {
  stats::setNames(
    list(wlv_resource_ref(
      "metadata/indicators",
      wlv_native_indicator_metadata_contract(),
      producer = producer
    )),
    alias
  )
}

wlv_native_indicator_metadata_output <- function(
    predecessor,
    alias = "indicator_metadata") {
  contract <- wlv_native_indicator_metadata_contract()
  stats::setNames(
    list(wlv_resource_output(
      wlv_resource_ref("metadata/indicators", contract),
      action = "replace",
      predecessor = wlv_resource_ref(
        "metadata/indicators",
        contract,
        producer = predecessor
      )
    )),
    alias
  )
}
