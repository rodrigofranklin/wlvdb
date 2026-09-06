# Native module runtime -----------------------------------------------------
#
# This file contains definitions only. Loading it must not execute a task or
# mutate the process search path. The runtime deliberately has no compatibility
# path for scripts that exchange objects through a shared environment.

wlv_runtime_abort <- function(message, class = "wlv_runtime_error") {
  condition <- structure(
    list(message = as.character(message), call = NULL),
    class = c(class, "wlv_runtime_error", "error", "condition")
  )
  stop(condition)
}

wlv_runtime_module_execution_condition <- function(error, node_id, runtime = NULL) {
  anomalies <- NULL
  if (is.environment(runtime) && is.data.frame(runtime$anomalies) &&
      identical(names(runtime$anomalies), wlv_semantic_anomaly_columns()) &&
      nrow(runtime$anomalies)) {
    anomalies <- runtime$anomalies
  } else if (inherits(error, "wlv_contract_error") &&
      is.data.frame(error$anomalies) &&
      identical(names(error$anomalies), wlv_semantic_anomaly_columns()) &&
      nrow(error$anomalies)) {
    anomalies <- error$anomalies
  }
  fields <- list(
    message = sprintf(
      "Module instance `%s` failed: %s",
      node_id,
      conditionMessage(error)
    ),
    call = NULL,
    node_id = node_id,
    cause_class = class(error)
  )
  classes <- c("wlv_module_execution_error", "wlv_runtime_error")
  if (!is.null(anomalies)) {
    row.names(anomalies) <- NULL
    fields$anomalies <- anomalies
    classes <- c("wlv_module_contract_error", "wlv_contract_error", classes)
  }
  structure(fields, class = c(classes, "error", "condition"))
}

wlv_runtime_scalar_character <- function(value, name, pattern = NULL) {
  if (
    !is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value) || (!is.null(pattern) && !grepl(pattern, value))
  ) {
    suffix <- if (is.null(pattern)) "" else sprintf(" matching `%s`", pattern)
    wlv_runtime_abort(
      sprintf("`%s` must be one non-empty string%s.", name, suffix),
      "wlv_contract_error"
    )
  }
  value
}

wlv_runtime_scalar_logical <- function(value, name) {
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    wlv_runtime_abort(
      sprintf("`%s` must be TRUE or FALSE.", name),
      "wlv_contract_error"
    )
  }
  value
}

wlv_runtime_identifier_pattern <- function() {
  "^[a-z][A-Za-z0-9_.-]*$"
}
wlv_runtime_module_pattern <- function() {
  "^[a-z][A-Za-z0-9_.-]*(/[a-z][A-Za-z0-9_.-]*)*$"
}
wlv_runtime_resource_pattern <- function() {
  "^[A-Za-z0-9][A-Za-z0-9_.-]*(/[A-Za-z0-9][A-Za-z0-9_.-]*)*$"
}
wlv_runtime_seed_producer <- function() {
  ".seed"
}

wlv_runtime_validate_names <- function(value, name, allow_empty = TRUE) {
  if (!is.character(value) || anyNA(value) || any(!nzchar(value)) || anyDuplicated(value)) {
    wlv_runtime_abort(
      sprintf("`%s` must be a character vector of unique non-empty names.", name),
      "wlv_contract_error"
    )
  }
  if (!allow_empty && !length(value)) {
    wlv_runtime_abort(
      sprintf("`%s` cannot be empty.", name),
      "wlv_contract_error"
    )
  }
  value
}

wlv_runtime_contains_reference <- function(value, seen = list()) {
  type <- typeof(value)
  if (type %in% c(
    "environment", "externalptr", "weakref", "closure", "builtin", "special"
  ) || inherits(value, "connection")) {
    return(TRUE)
  }
  if (inherits(value, "data.table") || isS4(value)) {
    return(TRUE)
  }
  if (is.pairlist(value) || is.list(value)) {
    if (any(vapply(value, wlv_runtime_contains_reference, logical(1L)))) {
      return(TRUE)
    }
  }
  value_attributes <- attributes(value)
  if (
    length(value_attributes) &&
      any(vapply(value_attributes, wlv_runtime_contains_reference, logical(1L)))
  ) {
    return(TRUE)
  }
  FALSE
}

wlv_resource_contract <- function(
    scope = c("run", "io_period"),
    axes = NULL,
    value_type = c(
      "any", "numeric", "integer", "double", "logical", "character",
      "list", "data.frame", "array"
    ),
    unit = NULL,
    missingness = NULL,
    role = c(
      "value", "semantic_state", "anomaly", "diagnostic", "metadata",
      "control"
    ),
    semantic_state = FALSE,
    validator = NULL) {
  scope <- match.arg(scope)
  value_type <- match.arg(value_type)
  role <- match.arg(role)
  semantic_state <- wlv_runtime_scalar_logical(
    semantic_state,
    "semantic_state"
  )
  if (semantic_state && !identical(role, "value")) {
    wlv_runtime_abort(
      "Only value resources can declare a semantic-state companion.",
      "wlv_contract_error"
    )
  }
  if (!is.null(axes)) {
    axes <- wlv_runtime_validate_names(axes, "axes")
  }
  if (!is.null(validator) && !is.function(validator)) {
    wlv_runtime_abort(
      "`validator` must be NULL or a function.",
      "wlv_contract_error"
    )
  }
  structure(
    list(
      scope = scope,
      axes = axes,
      value_type = value_type,
      unit = unit,
      missingness = missingness,
      role = role,
      semantic_state = semantic_state,
      validator = validator
    ),
    class = "wlv_resource_contract"
  )
}

wlv_resource_contract_assert <- function(value, name = "contract") {
  if (!inherits(value, "wlv_resource_contract") || !is.list(value)) {
    wlv_runtime_abort(
      sprintf("`%s` must be a `wlv_resource_contract`.", name),
      "wlv_contract_error"
    )
  }
  expected <- c(
    "scope", "axes", "value_type", "unit", "missingness", "role",
    "semantic_state", "validator"
  )
  if (!identical(names(value), expected)) {
    wlv_runtime_abort(
      sprintf("`%s` is not a canonical resource contract.", name),
      "wlv_contract_error"
    )
  }
  invisible(value)
}

wlv_resource_ref <- function(
    key,
    contract = wlv_resource_contract(),
    producer = NULL,
    partition = NULL,
    optional = FALSE,
    collect = FALSE) {
  key <- wlv_runtime_scalar_character(
    key,
    "key",
    wlv_runtime_resource_pattern()
  )
  wlv_resource_contract_assert(contract)
  if (!is.null(producer)) {
    producer <- wlv_runtime_scalar_character(producer, "producer")
    if (
      !identical(producer, wlv_runtime_seed_producer()) &&
        !grepl(wlv_runtime_identifier_pattern(), producer)
    ) {
      wlv_runtime_abort(
        "`producer` must be an instance identifier or `.seed`.",
        "wlv_contract_error"
      )
    }
  }
  if (!is.null(partition)) {
    partition <- wlv_runtime_scalar_character(partition, "partition")
    if (!identical(partition, "*") && grepl("[[:cntrl:]]", partition)) {
      wlv_runtime_abort(
        "`partition` cannot contain control characters.",
        "wlv_contract_error"
      )
    }
  }
  optional <- wlv_runtime_scalar_logical(optional, "optional")
  collect <- wlv_runtime_scalar_logical(collect, "collect")
  if (collect && !identical(contract$scope, "io_period")) {
    wlv_runtime_abort(
      "Only `io_period` resource references can be collected.",
      "wlv_contract_error"
    )
  }
  if (collect && !is.null(producer)) {
    wlv_runtime_abort(
      "A collection reference cannot select one `producer`.",
      "wlv_contract_error"
    )
  }
  if (collect && optional) {
    wlv_runtime_abort(
      "A collection reference cannot be optional; partition coverage is exact.",
      "wlv_contract_error"
    )
  }
  structure(
    list(
      key = key,
      contract = contract,
      producer = producer,
      partition = partition,
      optional = optional,
      collect = collect
    ),
    class = "wlv_resource_ref"
  )
}

wlv_resource_ref_assert <- function(value, name = "resource reference") {
  if (!inherits(value, "wlv_resource_ref") || !is.list(value)) {
    wlv_runtime_abort(
      sprintf("`%s` must be a `wlv_resource_ref`.", name),
      "wlv_contract_error"
    )
  }
  invisible(value)
}

wlv_resource_output <- function(
    ref,
    action = c("create", "patch", "replace"),
    predecessor = NULL) {
  wlv_resource_ref_assert(ref, "ref")
  action <- match.arg(action)
  if (!is.null(ref$producer) || ref$optional || ref$collect) {
    wlv_runtime_abort(
      "An output reference cannot set `producer`, `optional`, or `collect`.",
      "wlv_contract_error"
    )
  }
  if (identical(action, "create")) {
    if (!is.null(predecessor)) {
      wlv_runtime_abort(
        "A `create` output cannot declare a predecessor.",
        "wlv_contract_error"
      )
    }
  } else {
    wlv_resource_ref_assert(predecessor, "predecessor")
    if (is.null(predecessor$producer)) {
      wlv_runtime_abort(
        sprintf("A `%s` output requires an explicit predecessor producer.", action),
        "wlv_contract_error"
      )
    }
    if (
      !identical(predecessor$key, ref$key) || predecessor$optional ||
        predecessor$collect
    ) {
      wlv_runtime_abort(
        "An output predecessor must identify the same single resource.",
        "wlv_contract_error"
      )
    }
  }
  structure(
    list(ref = ref, action = action, predecessor = predecessor),
    class = "wlv_resource_output"
  )
}

wlv_resource_patch <- function(indices, value) {
  if (!is.list(indices) || !length(indices)) {
    wlv_runtime_abort(
      "`indices` must be a non-empty list.",
      "wlv_result_error"
    )
  }
  if (!is.null(names(indices))) {
    wlv_runtime_validate_names(names(indices), "names(indices)", allow_empty = FALSE)
  }
  structure(list(indices = indices, value = value), class = "wlv_resource_patch")
}

wlv_module_parameter <- function(
    type = c("character", "integer", "double", "logical", "list", "any"),
    required = TRUE,
    default = NULL,
    scalar = TRUE,
    allow_na = FALSE,
    choices = NULL,
    validator = NULL) {
  type <- match.arg(type)
  required <- wlv_runtime_scalar_logical(required, "required")
  scalar <- wlv_runtime_scalar_logical(scalar, "scalar")
  allow_na <- wlv_runtime_scalar_logical(allow_na, "allow_na")
  if (!is.null(choices) && (!is.atomic(choices) || !length(choices) || anyNA(choices))) {
    wlv_runtime_abort(
      "`choices` must be NULL or a non-empty atomic vector without NA.",
      "wlv_contract_error"
    )
  }
  if (!is.null(validator) && !is.function(validator)) {
    wlv_runtime_abort(
      "A parameter `validator` must be NULL or a function.",
      "wlv_contract_error"
    )
  }
  has_default <- !missing(default)
  if (required && has_default) {
    required <- FALSE
  }
  structure(
    list(
      type = type,
      required = required,
      has_default = has_default,
      default = default,
      scalar = scalar,
      allow_na = allow_na,
      choices = choices,
      validator = validator
    ),
    class = "wlv_module_parameter"
  )
}

wlv_runtime_contract_list <- function(value, name, class_name) {
  if (is.function(value)) {
    return(value)
  }
  if (!is.list(value)) {
    wlv_runtime_abort(
      sprintf("`%s` must be a named list or a function of resolved arguments.", name),
      "wlv_contract_error"
    )
  }
  if (length(value)) {
    wlv_runtime_validate_names(names(value), name, allow_empty = FALSE)
    valid <- vapply(value, inherits, logical(1L), class_name)
    if (any(!valid)) {
      wlv_runtime_abort(
        sprintf("Every `%s` entry must inherit from `%s`.", name, class_name),
        "wlv_contract_error"
      )
    }
  }
  value
}

wlv_module_spec <- function(
    id,
    scope = c("run", "io_period"),
    checkpoint,
    operations = c("calculate", "recalculate"),
    parameters = list(),
    requires = list(),
    provides = list(),
    services = character(),
    run) {
  id <- wlv_runtime_scalar_character(id, "id", wlv_runtime_module_pattern())
  scope <- match.arg(scope)
  if (
    !((is.numeric(checkpoint) && length(checkpoint) == 1L &&
      !is.na(checkpoint) && is.finite(checkpoint) &&
      checkpoint == as.integer(checkpoint) && checkpoint >= 0L) ||
      (is.character(checkpoint) && length(checkpoint) == 1L &&
        !is.na(checkpoint) && nzchar(checkpoint)))
  ) {
    wlv_runtime_abort(
      "`checkpoint` must be one non-negative integer or a named checkpoint.",
      "wlv_contract_error"
    )
  }
  if (
    !is.character(operations) || !length(operations) || anyNA(operations) ||
      any(!grepl("^[a-z][a-z_]*$", operations)) || anyDuplicated(operations)
  ) {
    wlv_runtime_abort(
      "`operations` must contain unique lowercase operation identifiers.",
      "wlv_contract_error"
    )
  }
  if (!is.list(parameters)) {
    wlv_runtime_abort("`parameters` must be a named list.", "wlv_contract_error")
  }
  if (length(parameters)) {
    wlv_runtime_validate_names(names(parameters), "parameters", allow_empty = FALSE)
    if (any(!vapply(parameters, inherits, logical(1L), "wlv_module_parameter"))) {
      wlv_runtime_abort(
        "Every parameter must be created with `wlv_module_parameter()`.",
        "wlv_contract_error"
      )
    }
  }
  requires <- wlv_runtime_contract_list(requires, "requires", "wlv_resource_ref")
  provides <- wlv_runtime_contract_list(provides, "provides", "wlv_resource_output")
  services <- wlv_runtime_validate_names(services, "services")
  if (!is.function(run)) {
    wlv_runtime_abort("`run` must be a function.", "wlv_contract_error")
  }
  structure(
    list(
      id = id,
      scope = scope,
      checkpoint = checkpoint,
      operations = operations,
      parameters = parameters,
      requires = requires,
      provides = provides,
      services = services,
      run = run
    ),
    class = "wlv_module_spec"
  )
}

wlv_module_result <- function(outputs, diagnostics = list()) {
  if (!is.list(outputs) || (length(outputs) && (
    is.null(names(outputs)) || any(!nzchar(names(outputs))) ||
      anyDuplicated(names(outputs))
  ))) {
    wlv_runtime_abort(
      "`outputs` must be a uniquely named list.",
      "wlv_result_error"
    )
  }
  if (!is.list(diagnostics) || is.data.frame(diagnostics) ||
      (length(diagnostics) && (
        is.null(names(diagnostics)) || any(!nzchar(names(diagnostics))) ||
          anyDuplicated(names(diagnostics))
      ))) {
    wlv_runtime_abort(
      "`diagnostics` must be a uniquely named list.",
      "wlv_result_error"
    )
  }
  structure(
    list(outputs = outputs, diagnostics = diagnostics),
    class = "wlv_module_result"
  )
}

wlv_new_module_registry <- function() {
  registry <- new.env(parent = emptyenv())
  registry$specs <- list()
  registry$sealed <- FALSE
  class(registry) <- "wlv_module_registry"
  registry
}

wlv_register_module <- function(registry, spec) {
  if (!inherits(registry, "wlv_module_registry") || !is.environment(registry)) {
    wlv_runtime_abort(
      "`registry` must be a module registry.",
      "wlv_registry_error"
    )
  }
  if (isTRUE(registry$sealed) || environmentIsLocked(registry)) {
    wlv_runtime_abort("The module registry is sealed.", "wlv_registry_error")
  }
  if (!inherits(spec, "wlv_module_spec")) {
    wlv_runtime_abort("`spec` must be a module specification.", "wlv_registry_error")
  }
  if (spec$id %in% names(registry$specs)) {
    wlv_runtime_abort(
      sprintf("Module `%s` is already registered.", spec$id),
      "wlv_registry_error"
    )
  }
  registry$specs <- c(registry$specs, stats::setNames(list(spec), spec$id))
  invisible(registry)
}

wlv_seal_module_registry <- function(registry) {
  if (!inherits(registry, "wlv_module_registry") || !is.environment(registry)) {
    wlv_runtime_abort("`registry` must be a module registry.", "wlv_registry_error")
  }
  if (!environmentIsLocked(registry)) {
    registry$sealed <- TRUE
    lockEnvironment(registry, bindings = TRUE)
  }
  invisible(registry)
}

wlv_module_registry <- function(specs = list()) {
  if (!is.list(specs)) {
    wlv_runtime_abort("`specs` must be a list.", "wlv_registry_error")
  }
  registry <- wlv_new_module_registry()
  for (spec in specs) {
    wlv_register_module(registry, spec)
  }
  wlv_seal_module_registry(registry)
  registry
}

wlv_registry_module <- function(registry, id) {
  id <- wlv_runtime_scalar_character(id, "id", wlv_runtime_module_pattern())
  if (!inherits(registry, "wlv_module_registry") || !is.environment(registry)) {
    wlv_runtime_abort("`registry` must be a module registry.", "wlv_registry_error")
  }
  spec <- registry$specs[[id]]
  if (is.null(spec)) {
    wlv_runtime_abort(
      sprintf("Module `%s` is not registered.", id),
      "wlv_preflight_error"
    )
  }
  spec
}

# Resource store ------------------------------------------------------------

wlv_seed_resource <- function(
    key = NULL,
    value,
    contract = wlv_resource_contract(),
    partition = NULL,
    producer = wlv_runtime_seed_producer()) {
  if (!is.null(key)) {
    key <- wlv_runtime_scalar_character(key, "key", wlv_runtime_resource_pattern())
  }
  wlv_resource_contract_assert(contract)
  if (!is.null(partition)) {
    partition <- wlv_runtime_scalar_character(partition, "partition")
  }
  producer <- wlv_runtime_scalar_character(producer, "producer")
  if (
    !identical(producer, wlv_runtime_seed_producer()) &&
      !grepl(wlv_runtime_identifier_pattern(), producer)
  ) {
    wlv_runtime_abort(
      "An inherited resource producer must be an instance identifier.",
      "wlv_store_error"
    )
  }
  if (identical(contract$scope, "run") && !is.null(partition)) {
    wlv_runtime_abort(
      "A run-scoped seed cannot declare a partition.",
      "wlv_store_error"
    )
  }
  if (identical(contract$scope, "io_period") && is.null(partition)) {
    wlv_runtime_abort(
      "An io-period seed requires a partition.",
      "wlv_store_error"
    )
  }
  structure(
    list(
      key = key,
      value = value,
      contract = contract,
      partition = partition,
      producer = producer
    ),
    class = "wlv_seed_resource"
  )
}

wlv_runtime_locator_id <- function(key, partition, producer) {
  paste(
    key,
    if (is.null(partition)) "" else partition,
    producer,
    sep = "\034"
  )
}

wlv_runtime_entry_locator <- function(entry) {
  list(
    key = entry$key,
    partition = entry$partition,
    producer = entry$producer
  )
}

wlv_runtime_locator_label <- function(key, partition, producer) {
  partition_label <- if (is.null(partition)) "" else paste0("[", partition, "]")
  paste0(key, partition_label, "@", producer)
}

wlv_runtime_new_entry <- function(
    key,
    partition,
    producer,
    value,
    contract,
    action,
    predecessor = NULL,
    predecessor_contract = NULL) {
  list(
    key = key,
    partition = partition,
    producer = producer,
    value = value,
    contract = contract,
    action = action,
    predecessor = predecessor,
    predecessor_contract = predecessor_contract
  )
}

wlv_runtime_new_store_identity <- function() {
  token <- new.env(parent = emptyenv())
  class(token) <- "wlv_store_identity"
  lockEnvironment(token, bindings = TRUE)
  token
}

wlv_runtime_store_identity_assert <- function(store, error_class) {
  token <- store$identity_token
  if (!inherits(token, "wlv_store_identity") || !is.environment(token) ||
      !environmentIsLocked(token)) {
    wlv_runtime_abort(
      "The resource store has no valid identity token.",
      error_class
    )
  }
  invisible(token)
}

wlv_runtime_validate_value_type <- function(value, value_type) {
  switch(
    value_type,
    any = TRUE,
    numeric = is.numeric(value),
    integer = is.integer(value),
    double = is.double(value),
    logical = is.logical(value),
    character = is.character(value),
    list = is.list(value) && !is.data.frame(value),
    data.frame = is.data.frame(value),
    array = is.array(value),
    FALSE
  )
}

wlv_runtime_validate_resource_value <- function(value, contract, label) {
  wlv_resource_contract_assert(contract)
  if (wlv_runtime_contains_reference(value)) {
    wlv_runtime_abort(
      sprintf("Resource `%s` contains a mutable reference value.", label),
      "wlv_result_error"
    )
  }
  semantic_codec <- identical(contract$role, "semantic_state") &&
    inherits(value, "wlv_runtime_semantic_state_codec")
  if (semantic_codec) {
    tryCatch(
      wlv_runtime_snapshot_state_codec_validate(value),
      error = function(error) {
        wlv_runtime_abort(
          sprintf(
            "Resource `%s` has an invalid semantic-state codec: %s",
            label,
            conditionMessage(error)
          ),
          "wlv_result_error"
        )
      }
    )
  }
  if (!semantic_codec &&
      !wlv_runtime_validate_value_type(value, contract$value_type)) {
    wlv_runtime_abort(
      sprintf(
        "Resource `%s` does not satisfy value type `%s`.",
        label,
        contract$value_type
      ),
      "wlv_result_error"
    )
  }
  if (!is.null(contract$axes)) {
    if (!length(contract$axes)) {
      if (!is.null(dim(value)) || length(value) != 1L) {
        wlv_runtime_abort(
          sprintf("Resource `%s` must be scalar.", label),
          "wlv_result_error"
        )
      }
    } else {
      value_dim <- dim(value)
      value_dimnames <- dimnames(value)
      if (is.null(value_dim) || length(value_dim) != length(contract$axes)) {
        wlv_runtime_abort(
          sprintf(
            "Resource `%s` must have axes: %s.",
            label,
            paste(contract$axes, collapse = ", ")
          ),
          "wlv_result_error"
        )
      }
      if (
        is.null(value_dimnames) || !identical(names(value_dimnames), contract$axes) ||
          any(vapply(value_dimnames, is.null, logical(1L))) ||
          any(vapply(value_dimnames, anyNA, logical(1L))) ||
          any(vapply(value_dimnames, anyDuplicated, integer(1L)) > 0L)
      ) {
        wlv_runtime_abort(
          sprintf(
            "Resource `%s` must have complete, unique dimnames named: %s.",
            label,
            paste(contract$axes, collapse = ", ")
          ),
          "wlv_result_error"
        )
      }
    }
  }
  if (!is.null(contract$validator)) {
    validation <- tryCatch(
      contract$validator(value),
      error = function(error) {
        wlv_runtime_abort(
          sprintf(
            "Resource `%s` failed its validator: %s",
            label,
            conditionMessage(error)
          ),
          "wlv_result_error"
        )
      }
    )
    if (!isTRUE(validation) && !is.null(validation)) {
      wlv_runtime_abort(
        sprintf("Resource `%s` was rejected by its validator.", label),
        "wlv_result_error"
      )
    }
  }
  invisible(value)
}

wlv_new_resource_store <- function(seeds = list(), seal = TRUE) {
  if (!is.list(seeds)) {
    wlv_runtime_abort("`seeds` must be a list.", "wlv_store_error")
  }
  seal <- wlv_runtime_scalar_logical(seal, "seal")
  store <- new.env(parent = emptyenv())
  store$identity_token <- wlv_runtime_new_store_identity()
  store$entries <- list()
  store$sealed <- FALSE
  class(store) <- "wlv_resource_store"

  if (length(seeds)) {
    seed_names <- names(seeds)
    if (is.null(seed_names)) {
      seed_names <- rep("", length(seeds))
    }
    for (index in seq_along(seeds)) {
      seed <- seeds[[index]]
      supplied_name <- seed_names[[index]]
      if (!inherits(seed, "wlv_seed_resource")) {
        if (!nzchar(supplied_name)) {
          wlv_runtime_abort(
            "Raw seed values must be named by resource key.",
            "wlv_store_error"
          )
        }
        seed <- wlv_seed_resource(key = supplied_name, value = seed)
      } else if (is.null(seed$key)) {
        if (!nzchar(supplied_name)) {
          wlv_runtime_abort(
            "A seed must declare `key` or have a resource-key list name.",
            "wlv_store_error"
          )
        }
        seed$key <- wlv_runtime_scalar_character(
          supplied_name,
          "seed name",
          wlv_runtime_resource_pattern()
        )
      } else if (nzchar(supplied_name) && !identical(supplied_name, seed$key)) {
        wlv_runtime_abort(
          sprintf(
            "Seed list name `%s` disagrees with resource key `%s`.",
            supplied_name,
            seed$key
          ),
          "wlv_store_error"
        )
      }
      label <- wlv_runtime_locator_label(
        seed$key,
        seed$partition,
        seed$producer
      )
      wlv_runtime_validate_resource_value(seed$value, seed$contract, label)
      locator_id <- wlv_runtime_locator_id(
        seed$key,
        seed$partition,
        seed$producer
      )
      if (locator_id %in% names(store$entries)) {
        wlv_runtime_abort(
          sprintf("Duplicate seed resource `%s`.", label),
          "wlv_store_error"
        )
      }
      store$entries[[locator_id]] <- wlv_runtime_new_entry(
        key = seed$key,
        partition = seed$partition,
        producer = seed$producer,
        value = seed$value,
        contract = seed$contract,
        action = if (identical(seed$producer, wlv_runtime_seed_producer())) {
          "seed"
        } else {
          "inherited"
        }
      )
    }
  }
  if (seal) {
    wlv_seal_resource_store(store)
  }
  store
}

wlv_seal_resource_store <- function(store) {
  if (!inherits(store, "wlv_resource_store") || !is.environment(store)) {
    wlv_runtime_abort("`store` must be a resource store.", "wlv_store_error")
  }
  if (!environmentIsLocked(store)) {
    store$sealed <- TRUE
    lockEnvironment(store, bindings = TRUE)
  }
  invisible(store)
}

wlv_runtime_fork_store <- function(store, retain_locator_ids = NULL) {
  if (!inherits(store, "wlv_resource_store") || !is.environment(store)) {
    wlv_runtime_abort("`store` must be a resource store.", "wlv_store_error")
  }
  wlv_runtime_store_identity_assert(store, "wlv_store_error")
  if (!is.null(retain_locator_ids)) {
    if (!is.character(retain_locator_ids) || anyNA(retain_locator_ids) ||
        any(!nzchar(retain_locator_ids)) || anyDuplicated(retain_locator_ids)) {
      wlv_runtime_abort(
        "Retained fork locators must be unique non-empty character IDs.",
        "wlv_store_error"
      )
    }
    unknown <- setdiff(retain_locator_ids, names(store$entries))
    if (length(unknown)) {
      wlv_runtime_abort(
        sprintf("Cannot retain unknown fork locator `%s`.", unknown[[1L]]),
        "wlv_store_error"
      )
    }
  }
  fork <- new.env(parent = emptyenv())
  fork$identity_token <- wlv_runtime_new_store_identity()
  fork$entries <- if (is.null(retain_locator_ids)) {
    store$entries
  } else {
    store$entries[retain_locator_ids]
  }
  fork$sealed <- FALSE
  class(fork) <- "wlv_resource_store"
  fork
}

wlv_store_catalog <- function(store) {
  if (!inherits(store, "wlv_resource_store") || !is.environment(store)) {
    wlv_runtime_abort("`store` must be a resource store.", "wlv_store_error")
  }
  if (!length(store$entries)) {
    return(data.frame(
      key = character(),
      partition = character(),
      producer = character(),
      action = character(),
      predecessor = character(),
      role = character(),
      semantic_state = logical(),
      stringsAsFactors = FALSE
    ))
  }
  rows <- lapply(store$entries, function(entry) {
    predecessor <- entry$predecessor
    data.frame(
      key = entry$key,
      partition = if (is.null(entry$partition)) "" else entry$partition,
      producer = entry$producer,
      action = entry$action,
      predecessor = if (is.null(predecessor)) "" else wlv_runtime_locator_label(
        predecessor$key,
        predecessor$partition,
        predecessor$producer
      ),
      role = entry$contract$role,
      semantic_state = entry$contract$semantic_state,
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result[
    order(
      result$key,
      result$partition,
      result$producer,
      method = "radix"
    ),
    ,
    drop = FALSE
  ]
}

wlv_runtime_entry <- function(store, locator, optional = FALSE) {
  locator_id <- wlv_runtime_locator_id(
    locator$key,
    locator$partition,
    locator$producer
  )
  entry <- store$entries[[locator_id]]
  if (is.null(entry) && !optional) {
    wlv_runtime_abort(
      sprintf(
        "Resource `%s` is not available.",
        wlv_runtime_locator_label(
          locator$key,
          locator$partition,
          locator$producer
        )
      ),
      "wlv_store_error"
    )
  }
  entry
}

wlv_runtime_terminal_entries <- function(store, key, partition = NULL) {
  candidates <- Filter(
    function(entry) {
      identical(entry$key, key) && identical(entry$partition, partition)
    },
    store$entries
  )
  if (!length(candidates)) {
    return(list())
  }
  predecessor_ids <- vapply(
    candidates,
    function(entry) {
      predecessor <- entry$predecessor
      if (is.null(predecessor)) "" else wlv_runtime_locator_id(
        predecessor$key,
        predecessor$partition,
        predecessor$producer
      )
    },
    character(1L)
  )
  terminal <- candidates[
    !vapply(
      candidates,
      function(entry) {
        wlv_runtime_locator_id(entry$key, entry$partition, entry$producer) %in%
          predecessor_ids
      },
      logical(1L)
    )
  ]
  terminal
}

wlv_store_read <- function(store, ref) {
  wlv_resource_ref_assert(ref, "ref")
  if (ref$collect) {
    partitions <- sort(unique(vapply(
      Filter(
        function(entry) identical(entry$key, ref$key) && !is.null(entry$partition),
        store$entries
      ),
      function(entry) entry$partition,
      character(1L)
    )), method = "radix")
    values <- lapply(partitions, function(partition) {
      terminal <- wlv_runtime_terminal_entries(store, ref$key, partition)
      if (length(terminal) != 1L) {
        wlv_runtime_abort(
          sprintf(
            "Resource `%s[%s]` has %d terminal generations.",
            ref$key,
            partition,
            length(terminal)
          ),
          "wlv_store_error"
        )
      }
      if (!wlv_runtime_contract_compatible(ref$contract, terminal[[1L]]$contract)) {
        wlv_runtime_abort(
          sprintf(
            "Resource `%s[%s]` does not satisfy the requested contract.",
            ref$key,
            partition
          ),
          "wlv_store_error"
        )
      }
      terminal[[1L]]$value
    })
    names(values) <- partitions
    return(values)
  }
  if (!is.null(ref$producer)) {
    entry <- wlv_runtime_entry(
      store,
      list(key = ref$key, partition = ref$partition, producer = ref$producer),
      optional = ref$optional
    )
  } else {
    terminal <- wlv_runtime_terminal_entries(store, ref$key, ref$partition)
    if (!length(terminal) && ref$optional) {
      return(NULL)
    }
    if (length(terminal) != 1L) {
      wlv_runtime_abort(
        sprintf(
          "Resource `%s` has %d terminal generations.",
          ref$key,
          length(terminal)
        ),
        "wlv_store_error"
      )
    }
    entry <- terminal[[1L]]
  }
  if (!is.null(entry) && !wlv_runtime_contract_compatible(
    ref$contract,
    entry$contract
  )) {
    wlv_runtime_abort(
      sprintf("Resource `%s` does not satisfy the requested contract.", ref$key),
      "wlv_store_error"
    )
  }
  if (is.null(entry)) NULL else entry$value
}

# Instances and graph compilation ------------------------------------------

wlv_module_instance <- function(
    instance_id,
    module_id,
    args = list(),
    partition = NULL) {
  instance_id <- wlv_runtime_scalar_character(
    instance_id,
    "instance_id",
    wlv_runtime_identifier_pattern()
  )
  module_id <- wlv_runtime_scalar_character(
    module_id,
    "module_id",
    wlv_runtime_module_pattern()
  )
  if (!is.list(args) || (length(args) && (
    is.null(names(args)) || any(!nzchar(names(args))) || anyDuplicated(names(args))
  ))) {
    wlv_runtime_abort(
      "`args` must be a uniquely named list.",
      "wlv_contract_error"
    )
  }
  if (wlv_runtime_contains_reference(args)) {
    wlv_runtime_abort(
      "Module arguments cannot contain mutable reference values.",
      "wlv_contract_error"
    )
  }
  if (!is.null(partition)) {
    partition <- wlv_runtime_scalar_character(partition, "partition")
  }
  structure(
    list(
      instance_id = instance_id,
      module_id = module_id,
      args = args,
      partition = partition
    ),
    class = "wlv_module_instance"
  )
}

wlv_runtime_node_id <- function(instance_id, partition = NULL) {
  if (is.null(partition)) instance_id else paste(instance_id, partition, sep = "@")
}

wlv_runtime_instances <- function(instances) {
  if (is.data.frame(instances)) {
    required <- c("instance_id", "module_id", "args")
    missing_columns <- setdiff(required, names(instances))
    if (length(missing_columns)) {
      wlv_runtime_abort(
        sprintf(
          "The effective module configuration is missing column(s): %s.",
          paste(missing_columns, collapse = ", ")
        ),
        "wlv_preflight_error"
      )
    }
    if (!is.list(instances$args)) {
      wlv_runtime_abort(
        "The effective configuration column `args` must be a list-column.",
        "wlv_preflight_error"
      )
    }
    result <- lapply(seq_len(nrow(instances)), function(index) {
      partition <- NULL
      if ("partition" %in% names(instances)) {
        candidate <- instances$partition[[index]]
        if (!(is.null(candidate) || length(candidate) == 0L ||
          (length(candidate) == 1L && is.na(candidate)) ||
          identical(candidate, ""))) {
          partition <- as.character(candidate)
        }
      }
      wlv_module_instance(
        instance_id = as.character(instances$instance_id[[index]]),
        module_id = as.character(instances$module_id[[index]]),
        args = instances$args[[index]],
        partition = partition
      )
    })
  } else {
    if (!is.list(instances) || any(!vapply(
      instances,
      inherits,
      logical(1L),
      "wlv_module_instance"
    ))) {
      wlv_runtime_abort(
        "`instances` must be module instances or an effective configuration data frame.",
        "wlv_preflight_error"
      )
    }
    result <- instances
  }
  node_ids <- vapply(
    result,
    function(instance) {
      wlv_runtime_node_id(instance$instance_id, instance$partition)
    },
    character(1L)
  )
  if (anyDuplicated(node_ids)) {
    duplicates <- sort(
      unique(node_ids[duplicated(node_ids)]),
      method = "radix"
    )
    wlv_runtime_abort(
      sprintf(
        "Duplicate module instance and partition pair(s): %s.",
        paste(duplicates, collapse = ", ")
      ),
      "wlv_preflight_error"
    )
  }
  result
}

wlv_runtime_parameter_type_ok <- function(value, type) {
  switch(
    type,
    character = is.character(value),
    integer = is.integer(value),
    double = is.double(value),
    logical = is.logical(value),
    list = is.list(value),
    any = TRUE,
    FALSE
  )
}

wlv_runtime_validate_parameter_value <- function(value, parameter, name, instance_id) {
  if (!wlv_runtime_parameter_type_ok(value, parameter$type)) {
    wlv_runtime_abort(
      sprintf(
        "Argument `%s` of instance `%s` must have type `%s`.",
        name,
        instance_id,
        parameter$type
      ),
      "wlv_preflight_error"
    )
  }
  if (parameter$scalar && length(value) != 1L) {
    wlv_runtime_abort(
      sprintf("Argument `%s` of instance `%s` must be scalar.", name, instance_id),
      "wlv_preflight_error"
    )
  }
  if (!parameter$allow_na && anyNA(value)) {
    wlv_runtime_abort(
      sprintf("Argument `%s` of instance `%s` cannot contain NA.", name, instance_id),
      "wlv_preflight_error"
    )
  }
  if (!is.null(parameter$choices) && any(!value %in% parameter$choices)) {
    wlv_runtime_abort(
      sprintf(
        "Argument `%s` of instance `%s` must be one of: %s.",
        name,
        instance_id,
        paste(parameter$choices, collapse = ", ")
      ),
      "wlv_preflight_error"
    )
  }
  if (!is.null(parameter$validator)) {
    validation <- tryCatch(
      parameter$validator(value),
      error = function(error) {
        wlv_runtime_abort(
          sprintf(
            "Argument `%s` of instance `%s` failed validation: %s",
            name,
            instance_id,
            conditionMessage(error)
          ),
          "wlv_preflight_error"
        )
      }
    )
    if (!isTRUE(validation) && !is.null(validation)) {
      wlv_runtime_abort(
        sprintf("Argument `%s` of instance `%s` was rejected.", name, instance_id),
        "wlv_preflight_error"
      )
    }
  }
  invisible(value)
}

wlv_runtime_resolve_arguments <- function(spec, instance) {
  unknown <- setdiff(names(instance$args), names(spec$parameters))
  if (length(unknown)) {
    wlv_runtime_abort(
      sprintf(
        "Instance `%s` has unknown argument(s): %s.",
        instance$instance_id,
        paste(unknown, collapse = ", ")
      ),
      "wlv_preflight_error"
    )
  }
  resolved <- list()
  for (name in names(spec$parameters)) {
    parameter <- spec$parameters[[name]]
    if (name %in% names(instance$args)) {
      value <- instance$args[[name]]
    } else if (parameter$has_default) {
      value <- parameter$default
    } else if (parameter$required) {
      wlv_runtime_abort(
        sprintf(
          "Instance `%s` is missing required argument `%s`.",
          instance$instance_id,
          name
        ),
        "wlv_preflight_error"
      )
    } else {
      value <- NULL
    }
    if (is.null(value) && !parameter$required && !parameter$has_default) {
      next
    }
    wlv_runtime_validate_parameter_value(value, parameter, name, instance$instance_id)
    resolved[[name]] <- value
  }
  resolved
}

wlv_runtime_resolve_contract_list <- function(
    value,
    args,
    name,
    class_name,
    instance) {
  instance_id <- instance$instance_id
  if (is.function(value)) {
    value <- tryCatch(
      {
        parameters <- names(formals(value))
        if (length(parameters) >= 2L || "..." %in% parameters) {
          value(args, instance)
        } else {
          value(args)
        }
      },
      error = function(error) {
        wlv_runtime_abort(
          sprintf(
            "Cannot resolve `%s` for instance `%s`: %s",
            name,
            instance_id,
            conditionMessage(error)
          ),
          "wlv_preflight_error"
        )
      }
    )
  }
  if (!is.list(value) || (length(value) && (
    is.null(names(value)) || any(!nzchar(names(value))) || anyDuplicated(names(value))
  ))) {
    wlv_runtime_abort(
      sprintf("Resolved `%s` for instance `%s` must be a named list.", name, instance_id),
      "wlv_preflight_error"
    )
  }
  if (length(value) && any(!vapply(value, inherits, logical(1L), class_name))) {
    wlv_runtime_abort(
      sprintf(
        "Resolved `%s` for instance `%s` contains an invalid contract.",
        name,
        instance_id
      ),
      "wlv_preflight_error"
    )
  }
  value
}

wlv_runtime_bind_input_partition <- function(ref, spec, instance) {
  if (identical(ref$contract$scope, "run")) {
    if (!is.null(ref$partition) || ref$collect) {
      wlv_runtime_abort(
        sprintf("Run resource `%s` cannot declare a partition.", ref$key),
        "wlv_preflight_error"
      )
    }
    return(ref)
  }
  if (ref$collect) {
    if (!identical(spec$scope, "run")) {
      wlv_runtime_abort(
        sprintf("Instance `%s` cannot collect from io periods.", instance$instance_id),
        "wlv_preflight_error"
      )
    }
    if (is.null(ref$partition)) {
      ref$partition <- "*"
    }
    if (!identical(ref$partition, "*")) {
      wlv_runtime_abort(
        "A collection reference must use partition `*`.",
        "wlv_preflight_error"
      )
    }
    return(ref)
  }
  if (identical(spec$scope, "run")) {
    wlv_runtime_abort(
      sprintf(
        "Run-scoped instance `%s` must collect io resource `%s` across all partitions.",
        instance$instance_id,
        ref$key
      ),
      "wlv_preflight_error"
    )
  }
  if (is.null(ref$partition)) {
    ref$partition <- instance$partition
  }
  if (
    identical(spec$scope, "io_period") &&
      !identical(ref$partition, instance$partition)
  ) {
    wlv_runtime_abort(
      sprintf(
        "Instance `%s` cannot read io partition `%s` while running partition `%s`.",
        instance$instance_id,
        ref$partition,
        instance$partition
      ),
      "wlv_preflight_error"
    )
  }
  ref
}

wlv_runtime_bind_output_partition <- function(output, spec, instance) {
  ref <- output$ref
  if (!identical(ref$contract$scope, spec$scope)) {
    wlv_runtime_abort(
      sprintf(
        "Instance `%s` cannot provide a `%s` resource from `%s` scope.",
        instance$instance_id,
        ref$contract$scope,
        spec$scope
      ),
      "wlv_preflight_error"
    )
  }
  if (identical(spec$scope, "run")) {
    if (!is.null(ref$partition)) {
      wlv_runtime_abort(
        sprintf("Run output `%s` cannot declare a partition.", ref$key),
        "wlv_preflight_error"
      )
    }
  } else {
    if (is.null(ref$partition)) {
      ref$partition <- instance$partition
    }
    if (!identical(ref$partition, instance$partition)) {
      wlv_runtime_abort(
        sprintf(
          "Instance `%s` cannot write io partition `%s`.",
          instance$instance_id,
          ref$partition
        ),
        "wlv_preflight_error"
      )
    }
  }
  output$ref <- ref
  if (!is.null(output$predecessor)) {
    predecessor <- output$predecessor
    if (is.null(predecessor$partition)) {
      predecessor$partition <- ref$partition
    }
    if (!identical(predecessor$partition, ref$partition)) {
      wlv_runtime_abort(
        sprintf(
          "Output `%s` and its predecessor must use the same partition.",
          ref$key
        ),
        "wlv_preflight_error"
      )
    }
    output$predecessor <- predecessor
  }
  output
}

wlv_runtime_contract_compatible <- function(required, provided) {
  wlv_resource_contract_assert(required)
  wlv_resource_contract_assert(provided)
  if (!identical(required$scope, provided$scope)) {
    return(FALSE)
  }
  if (!is.null(required$axes) && !identical(required$axes, provided$axes)) {
    return(FALSE)
  }
  if (
    !identical(required$value_type, "any") &&
      !identical(required$value_type, provided$value_type) &&
      !(identical(required$value_type, "numeric") &&
        provided$value_type %in% c("numeric", "integer", "double"))
  ) {
    return(FALSE)
  }
  if (!is.null(required$unit) && !identical(required$unit, provided$unit)) {
    return(FALSE)
  }
  if (
    !is.null(required$missingness) &&
      !identical(required$missingness, provided$missingness)
  ) {
    return(FALSE)
  }
  if (!identical(required$role, provided$role)) {
    return(FALSE)
  }
  if (!identical(required$semantic_state, provided$semantic_state)) {
    return(FALSE)
  }
  TRUE
}

wlv_runtime_contract_same <- function(first, second) {
  identical(first$scope, second$scope) &&
    identical(first$axes, second$axes) &&
    identical(first$value_type, second$value_type) &&
    identical(first$unit, second$unit) &&
    identical(first$missingness, second$missingness) &&
    identical(first$role, second$role) &&
    identical(first$semantic_state, second$semantic_state)
}

wlv_runtime_semantic_ref_same_target <- function(value_ref, state_ref) {
  identical(
    state_ref$key,
    paste0("semantic_state/", value_ref$key)
  ) &&
    identical(state_ref$partition, value_ref$partition) &&
    identical(state_ref$producer, value_ref$producer) &&
    identical(state_ref$optional, value_ref$optional) &&
    identical(state_ref$collect, value_ref$collect)
}

wlv_runtime_validate_semantic_contract_pairs <- function(
    requires,
    provides,
    instance_id) {
  state_requires <- Filter(
    function(ref) identical(ref$contract$role, "semantic_state"),
    requires
  )
  value_requires <- Filter(
    function(ref) isTRUE(ref$contract$semantic_state),
    requires
  )
  for (ref in value_requires) {
    matched <- vapply(
      state_requires,
      function(state_ref) {
        wlv_runtime_semantic_ref_same_target(ref, state_ref)
      },
      logical(1L)
    )
    if (sum(matched) != 1L) {
      wlv_runtime_abort(
        sprintf(
          "Instance `%s` requires `%s` without one exact semantic-state pair.",
          instance_id,
          ref$key
        ),
        "wlv_preflight_error"
      )
    }
  }
  for (state_ref in state_requires) {
    matched <- vapply(
      value_requires,
      function(value_ref) {
        wlv_runtime_semantic_ref_same_target(value_ref, state_ref)
      },
      logical(1L)
    )
    if (sum(matched) < 1L) {
      wlv_runtime_abort(
        sprintf(
          "Instance `%s` declares orphan semantic-state input `%s`.",
          instance_id,
          state_ref$key
        ),
        "wlv_preflight_error"
      )
    }
  }

  state_outputs <- Filter(
    function(output) identical(output$ref$contract$role, "semantic_state"),
    provides
  )
  value_outputs <- Filter(
    function(output) isTRUE(output$ref$contract$semantic_state),
    provides
  )
  for (value_output in value_outputs) {
    expected_key <- paste0("semantic_state/", value_output$ref$key)
    matched <- Filter(function(state_output) {
      identical(state_output$ref$key, expected_key) &&
        identical(state_output$ref$partition, value_output$ref$partition)
    }, state_outputs)
    valid <- length(matched) == 1L
    if (valid) {
      state_output <- matched[[1L]]
      valid <- identical(state_output$action, value_output$action)
      value_predecessor <- value_output$predecessor
      state_predecessor <- state_output$predecessor
      valid <- valid && identical(
        is.null(value_predecessor),
        is.null(state_predecessor)
      )
      if (valid && !is.null(value_predecessor)) {
        valid <- identical(
          state_predecessor$key,
          paste0("semantic_state/", value_predecessor$key)
        ) &&
          identical(
            state_predecessor$partition,
            value_predecessor$partition
          ) &&
          identical(
            state_predecessor$producer,
            value_predecessor$producer
          )
      }
    }
    if (!valid) {
      wlv_runtime_abort(
        sprintf(
          paste0(
            "Instance `%s` provides `%s` without a semantic-state pair ",
            "using the same action and predecessor generation."
          ),
          instance_id,
          value_output$ref$key
        ),
        "wlv_preflight_error"
      )
    }
  }
  for (state_output in state_outputs) {
    target_key <- sub("^semantic_state/", "", state_output$ref$key)
    matched <- Filter(function(value_output) {
      identical(value_output$ref$key, target_key) &&
        identical(value_output$ref$partition, state_output$ref$partition)
    }, value_outputs)
    if (length(matched) != 1L) {
      wlv_runtime_abort(
        sprintf(
          "Instance `%s` declares orphan semantic-state output `%s`.",
          instance_id,
          state_output$ref$key
        ),
        "wlv_preflight_error"
      )
    }
  }
  invisible(TRUE)
}

wlv_runtime_checkpoint_rank <- function(checkpoint, checkpoint_order) {
  if (is.numeric(checkpoint)) {
    return(as.integer(checkpoint))
  }
  if (is.null(names(checkpoint_order)) || !checkpoint %in% names(checkpoint_order)) {
    wlv_runtime_abort(
      sprintf("Unknown checkpoint `%s`.", checkpoint),
      "wlv_preflight_error"
    )
  }
  as.integer(checkpoint_order[[checkpoint]])
}

wlv_default_checkpoint_order <- function() {
  c(
  source_preflight = 0L,
  recalc_input = 0L,
  after_assumptions = 1L,
  after_stage_1 = 1L,
  after_stage_2 = 2L,
  after_matrices = 3L,
  after_reduced_matrices = 4L,
  after_price_normalization = 4L,
  after_stage_4 = 4L,
  after_stage_5 = 5L,
  after_country_module = 5L,
  after_country_aggregation = 5L,
  after_world_aggregation = 5L,
  pre_publish = 6L,
  post_roundtrip = 7L,
  post_roundtrip_persisted = 8L
)
}

wlv_runtime_resolve_instance <- function(registry, instance, operation, partitions) {
  spec <- wlv_registry_module(registry, instance$module_id)
  if (!operation %in% spec$operations) {
    wlv_runtime_abort(
      sprintf(
        "Module `%s` does not support operation `%s`.",
        spec$id,
        operation
      ),
      "wlv_preflight_error"
    )
  }
  if (identical(spec$scope, "io_period")) {
    if (is.null(instance$partition)) {
      wlv_runtime_abort(
        sprintf("Instance `%s` requires an io partition.", instance$instance_id),
        "wlv_preflight_error"
      )
    }
    if (!length(partitions)) {
      wlv_runtime_abort(
        sprintf(
          "Instance `%s` requires an explicit set of io partitions.",
          instance$instance_id
        ),
        "wlv_preflight_error"
      )
    }
    if (!instance$partition %in% partitions) {
      wlv_runtime_abort(
        sprintf(
          "Instance `%s` uses undeclared partition `%s`.",
          instance$instance_id,
          instance$partition
        ),
        "wlv_preflight_error"
      )
    }
  } else if (!is.null(instance$partition)) {
    wlv_runtime_abort(
      sprintf("Run-scoped instance `%s` cannot declare a partition.", instance$instance_id),
      "wlv_preflight_error"
    )
  }
  args <- wlv_runtime_resolve_arguments(spec, instance)
  requires <- wlv_runtime_resolve_contract_list(
    spec$requires,
    args,
    "requires",
    "wlv_resource_ref",
    instance
  )
  requires <- lapply(
    requires,
    wlv_runtime_bind_input_partition,
    spec = spec,
    instance = instance
  )
  provides <- wlv_runtime_resolve_contract_list(
    spec$provides,
    args,
    "provides",
    "wlv_resource_output",
    instance
  )
  provides <- lapply(
    provides,
    wlv_runtime_bind_output_partition,
    spec = spec,
    instance = instance
  )
  wlv_runtime_validate_semantic_contract_pairs(
    requires,
    provides,
    instance$instance_id
  )
  output_keys <- vapply(
    provides,
    function(output) paste(output$ref$key, output$ref$partition, sep = "\034"),
    character(1L)
  )
  if (anyDuplicated(output_keys)) {
    wlv_runtime_abort(
      sprintf("Instance `%s` provides the same resource twice.", instance$instance_id),
      "wlv_preflight_error"
    )
  }
  semantic_input_mode <- attr(
    spec,
    "wlv_semantic_input_mode",
    exact = TRUE
  )
  if (is.null(semantic_input_mode)) {
    semantic_input_mode <- "hydrated"
  }
  if (
    !is.character(semantic_input_mode) || length(semantic_input_mode) != 1L ||
      is.na(semantic_input_mode) ||
      !semantic_input_mode %in% c("hydrated", "explicit")
  ) {
    wlv_runtime_abort(
      sprintf("Module `%s` has an invalid semantic input mode.", spec$id),
      "wlv_preflight_error"
    )
  }
  list(
    node_id = wlv_runtime_node_id(instance$instance_id, instance$partition),
    instance_id = instance$instance_id,
    module_id = instance$module_id,
    partition = instance$partition,
    args = args,
    parameter_names = names(spec$parameters),
    requires = requires,
    provides = provides,
    services = spec$services,
    semantic_input_mode = semantic_input_mode,
    checkpoint = spec$checkpoint,
    scope = spec$scope,
    run = spec$run
  )
}

wlv_runtime_provider_entries <- function(store, resolved) {
  entries <- store$entries
  for (module in resolved) {
    for (output in module$provides) {
      ref <- output$ref
      locator_id <- wlv_runtime_locator_id(
        ref$key,
        ref$partition,
        module$instance_id
      )
      if (locator_id %in% names(entries)) {
        wlv_runtime_abort(
          sprintf(
            "Provider `%s` already exists for resource `%s`.",
            module$instance_id,
            ref$key
          ),
          "wlv_preflight_error"
        )
      }
      predecessor <- if (is.null(output$predecessor)) NULL else list(
        key = output$predecessor$key,
        partition = output$predecessor$partition,
        producer = output$predecessor$producer
      )
      entries[[locator_id]] <- wlv_runtime_new_entry(
        key = ref$key,
        partition = ref$partition,
        producer = module$instance_id,
        value = NULL,
        contract = ref$contract,
        action = output$action,
        predecessor = predecessor,
        predecessor_contract = if (is.null(output$predecessor)) {
          NULL
        } else {
          output$predecessor$contract
        }
      )
    }
  }
  entries
}

wlv_runtime_provider_nodes <- function(resolved) {
  result <- list()
  for (module in resolved) {
    for (output in module$provides) {
      ref <- output$ref
      locator_id <- wlv_runtime_locator_id(
        ref$key,
        ref$partition,
        module$instance_id
      )
      result[[locator_id]] <- module$node_id
    }
  }
  result
}

wlv_runtime_resource_group_id <- function(key, partition) {
  paste(key, if (is.null(partition)) "" else partition, sep = "\034")
}

wlv_runtime_validate_provider_chains <- function(entries) {
  group_ids <- vapply(
    entries,
    function(entry) wlv_runtime_resource_group_id(entry$key, entry$partition),
    character(1L)
  )
  groups <- split(entries, group_ids)
  groups <- groups[sort(names(groups), method = "radix")]
  terminals <- list()
  for (group in groups) {
    locator_ids <- vapply(
      group,
      function(entry) {
        wlv_runtime_locator_id(entry$key, entry$partition, entry$producer)
      },
      character(1L)
    )
    locator_order <- order(locator_ids, method = "radix")
    locator_ids <- locator_ids[locator_order]
    group <- group[locator_order]
    names(group) <- locator_ids
    roots <- vapply(group, function(entry) is.null(entry$predecessor), logical(1L))
    if (sum(roots) != 1L) {
      first <- group[[1L]]
      wlv_runtime_abort(
        sprintf(
          "Resource `%s` in partition `%s` has %d root providers; exactly one is required.",
          first$key,
          if (is.null(first$partition)) "run" else first$partition,
          sum(roots)
        ),
        "wlv_preflight_error"
      )
    }
    predecessor_ids <- character()
    for (entry in group[!roots]) {
      predecessor <- entry$predecessor
      predecessor_id <- wlv_runtime_locator_id(
        predecessor$key,
        predecessor$partition,
        predecessor$producer
      )
      if (!predecessor_id %in% locator_ids) {
        wlv_runtime_abort(
          sprintf(
            "Provider `%s` declares missing predecessor `%s`.",
            entry$producer,
            wlv_runtime_locator_label(
              predecessor$key,
              predecessor$partition,
              predecessor$producer
            )
          ),
          "wlv_preflight_error"
        )
      }
      predecessor_entry <- group[[predecessor_id]]
      if (
        !is.null(entry$predecessor_contract) &&
          !wlv_runtime_contract_compatible(
            entry$predecessor_contract,
            predecessor_entry$contract
          )
      ) {
        wlv_runtime_abort(
          sprintf(
            "Provider `%s` declares an incompatible predecessor contract for `%s`.",
            entry$producer,
            entry$key
          ),
          "wlv_preflight_error"
        )
      }
      if (!wlv_runtime_contract_same(entry$contract, predecessor_entry$contract)) {
        wlv_runtime_abort(
          sprintf(
            "Provider `%s` changes the contract of `%s` while applying `%s`.",
            entry$producer,
            entry$key,
            entry$action
          ),
          "wlv_preflight_error"
        )
      }
      predecessor_ids <- c(predecessor_ids, predecessor_id)
    }
    duplicated_predecessors <- unique(predecessor_ids[duplicated(predecessor_ids)])
    if (length(duplicated_predecessors)) {
      predecessor <- group[[duplicated_predecessors[[1L]]]]
      wlv_runtime_abort(
        sprintf(
          "Resource `%s` forks after provider `%s`; replacement chains must be linear.",
          predecessor$key,
          predecessor$producer
        ),
        "wlv_preflight_error"
      )
    }
    for (locator_id in locator_ids) {
      seen <- character()
      current <- locator_id
      while (nzchar(current)) {
        if (current %in% seen) {
          cycle <- c(seen[match(current, seen):length(seen)], current)
          labels <- vapply(cycle, function(id) {
            entry <- group[[id]]
            wlv_runtime_locator_label(entry$key, entry$partition, entry$producer)
          }, character(1L))
          wlv_runtime_abort(
            sprintf("Resource replacement cycle: %s.", paste(labels, collapse = " -> ")),
            "wlv_preflight_error"
          )
        }
        seen <- c(seen, current)
        predecessor <- group[[current]]$predecessor
        current <- if (is.null(predecessor)) "" else wlv_runtime_locator_id(
          predecessor$key,
          predecessor$partition,
          predecessor$producer
        )
      }
    }
    terminal_ids <- setdiff(locator_ids, predecessor_ids)
    if (length(terminal_ids) != 1L) {
      first <- group[[1L]]
      wlv_runtime_abort(
        sprintf(
          "Resource `%s` has %d terminal providers.",
          first$key,
          length(terminal_ids)
        ),
        "wlv_preflight_error"
      )
    }
    terminal <- group[[terminal_ids[[1L]]]]
    terminals[[wlv_runtime_resource_group_id(
      terminal$key,
      terminal$partition
    )]] <- terminal
  }
  terminals
}

wlv_runtime_resolve_input <- function(
    ref,
    entries,
    terminals,
    partitions,
    instance_id) {
  if (ref$collect) {
    if (!length(partitions)) {
      wlv_runtime_abort(
        sprintf(
          "Collector input `%s` of instance `%s` requires declared partitions.",
          ref$key,
          instance_id
        ),
        "wlv_preflight_error"
      )
    }
    locators <- lapply(partitions, function(partition) {
      terminal <- terminals[[wlv_runtime_resource_group_id(ref$key, partition)]]
      if (is.null(terminal)) {
        wlv_runtime_abort(
          sprintf(
            "Collector `%s` is missing resource `%s` for partition `%s`.",
            instance_id,
            ref$key,
            partition
          ),
          "wlv_preflight_error"
        )
      }
      if (!wlv_runtime_contract_compatible(ref$contract, terminal$contract)) {
        wlv_runtime_abort(
          sprintf(
            "Collector `%s` has an incompatible contract for `%s[%s]`.",
            instance_id,
            ref$key,
            partition
          ),
          "wlv_preflight_error"
        )
      }
      wlv_runtime_entry_locator(terminal)
    })
    names(locators) <- partitions
    return(locators)
  }
  entry <- NULL
  if (!is.null(ref$producer)) {
    locator_id <- wlv_runtime_locator_id(ref$key, ref$partition, ref$producer)
    entry <- entries[[locator_id]]
  } else {
    entry <- terminals[[wlv_runtime_resource_group_id(ref$key, ref$partition)]]
  }
  if (is.null(entry)) {
    if (ref$optional) {
      return(list())
    }
    producer <- if (is.null(ref$producer)) "terminal" else ref$producer
    wlv_runtime_abort(
      sprintf(
        "Instance `%s` requires missing resource `%s` from `%s`.",
        instance_id,
        ref$key,
        producer
      ),
      "wlv_preflight_error"
    )
  }
  if (!wlv_runtime_contract_compatible(ref$contract, entry$contract)) {
    wlv_runtime_abort(
      sprintf(
        "Instance `%s` requires an incompatible contract for resource `%s`.",
        instance_id,
        ref$key
      ),
      "wlv_preflight_error"
    )
  }
  list(wlv_runtime_entry_locator(entry))
}

wlv_runtime_cycle_path <- function(ids, edges) {
  adjacency <- stats::setNames(rep(list(character()), length(ids)), ids)
  if (nrow(edges)) {
    for (index in seq_len(nrow(edges))) {
      adjacency[[edges$from[[index]]]] <- unique(c(
        adjacency[[edges$from[[index]]]],
        edges$to[[index]]
      ))
    }
  }
  state <- stats::setNames(integer(length(ids)), ids)
  stack <- character()
  answer <- NULL
  visit <- function(node) {
    state[[node]] <<- 1L
    stack <<- c(stack, node)
    for (next_node in sort(adjacency[[node]], method = "radix")) {
      if (state[[next_node]] == 0L) {
        if (visit(next_node)) {
          return(TRUE)
        }
      } else if (state[[next_node]] == 1L) {
        start <- match(next_node, stack)
        answer <<- c(stack[start:length(stack)], next_node)
        return(TRUE)
      }
    }
    stack <<- stack[-length(stack)]
    state[[node]] <<- 2L
    FALSE
  }
  for (id in sort(ids, method = "radix")) {
    if (state[[id]] == 0L && visit(id)) {
      break
    }
  }
  answer
}

wlv_runtime_topological_order <- function(ids, edges) {
  indegree <- stats::setNames(integer(length(ids)), ids)
  outgoing <- stats::setNames(rep(list(character()), length(ids)), ids)
  if (nrow(edges)) {
    pairs <- unique(edges[c("from", "to")])
    for (index in seq_len(nrow(pairs))) {
      from <- pairs$from[[index]]
      to <- pairs$to[[index]]
      outgoing[[from]] <- unique(c(outgoing[[from]], to))
      indegree[[to]] <- indegree[[to]] + 1L
    }
  }
  available <- sort(names(indegree)[indegree == 0L], method = "radix")
  order <- character()
  while (length(available)) {
    current <- available[[1L]]
    available <- available[-1L]
    order <- c(order, current)
    for (next_node in sort(outgoing[[current]], method = "radix")) {
      indegree[[next_node]] <- indegree[[next_node]] - 1L
      if (indegree[[next_node]] == 0L) {
        available <- sort(
          unique(c(available, next_node)),
          method = "radix"
        )
      }
    }
  }
  if (length(order) != length(ids)) {
    cycle <- wlv_runtime_cycle_path(ids, edges)
    wlv_runtime_abort(
      sprintf("Module dependency cycle: %s.", paste(cycle, collapse = " -> ")),
      "wlv_preflight_error"
    )
  }
  order
}

wlv_runtime_terminal_catalog <- function(terminals) {
  if (!length(terminals)) {
    return(data.frame(
      locator_id = character(),
      key = character(),
      partition = character(),
      producer = character(),
      role = character(),
      semantic_state = logical(),
      stringsAsFactors = FALSE
    ))
  }
  rows <- lapply(terminals, function(entry) {
    data.frame(
      locator_id = wlv_runtime_locator_id(
        entry$key,
        entry$partition,
        entry$producer
      ),
      key = entry$key,
      partition = if (is.null(entry$partition)) "" else entry$partition,
      producer = entry$producer,
      role = entry$contract$role,
      semantic_state = entry$contract$semantic_state,
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result[order(result$locator_id, method = "radix"), , drop = FALSE]
}

wlv_runtime_liveness_schedule <- function(entries, modules, order) {
  locator_ids <- names(entries)
  produced_at <- stats::setNames(integer(length(locator_ids)), locator_ids)
  last_use <- stats::setNames(rep(NA_integer_, length(locator_ids)), locator_ids)
  locator_lookup <- new.env(
    hash = TRUE,
    parent = emptyenv(),
    size = max(29L, length(locator_ids))
  )
  for (index in seq_along(locator_ids)) {
    locator_lookup[[locator_ids[[index]]]] <- as.integer(index)
  }

  for (sequence in seq_along(order)) {
    module <- modules[[order[[sequence]]]]
    for (output in module$provides) {
      ref <- output$ref
      locator_id <- wlv_runtime_locator_id(
        ref$key,
        ref$partition,
        module$instance_id
      )
      locator_index <- locator_lookup[[locator_id]]
      if (is.null(locator_index)) {
        wlv_runtime_abort(
          sprintf("Liveness schedule lacks output `%s`.", locator_id),
          "wlv_preflight_error"
        )
      }
      produced_at[[locator_index]] <- as.integer(sequence)
    }
    used <- wlv_runtime_module_live_locator_ids(module)
    if (length(used)) {
      used_indices <- vapply(used, function(locator_id) {
        locator_index <- locator_lookup[[locator_id]]
        if (is.null(locator_index)) NA_integer_ else locator_index
      }, integer(1L))
      unknown <- which(is.na(used_indices))
      if (length(unknown)) {
        wlv_runtime_abort(
          sprintf(
            "Liveness schedule lacks locator `%s`.",
            used[[unknown[[1L]]]]
          ),
          "wlv_preflight_error"
        )
      }
      last_use[used_indices] <- as.integer(sequence)
    }
  }

  release_at <- produced_at
  consumed <- !is.na(last_use)
  release_at[consumed] <- pmax(
    produced_at[consumed],
    last_use[consumed]
  )
  release_initial <- locator_ids[release_at == 0L]
  release_after <- vector("list", length(order))
  positive <- release_at > 0L
  if (any(positive)) {
    groups <- split(locator_ids[positive], release_at[positive])
    for (sequence in names(groups)) {
      release_after[[as.integer(sequence)]] <- unname(groups[[sequence]])
    }
  }
  structure(
    list(
      produced_at = produced_at,
      last_use = last_use,
      release_initial = unname(release_initial),
      release_after = release_after
    ),
    class = "wlv_liveness_schedule"
  )
}

wlv_compile_module_plan <- function(
    registry,
    instances,
    store = wlv_new_resource_store(),
    operation = c("calculate", "recalculate"),
    partitions = character(),
    checkpoint_order = wlv_default_checkpoint_order()) {
  operation <- match.arg(operation)
  if (!inherits(registry, "wlv_module_registry") || !is.environment(registry)) {
    wlv_runtime_abort("`registry` must be a module registry.", "wlv_preflight_error")
  }
  if (!environmentIsLocked(registry) || !isTRUE(registry$sealed)) {
    wlv_runtime_abort(
      "The module registry must be sealed before compilation.",
      "wlv_preflight_error"
    )
  }
  if (!inherits(store, "wlv_resource_store") || !is.environment(store) ||
      !environmentIsLocked(store) || !isTRUE(store$sealed)) {
    wlv_runtime_abort(
      "The input resource store must be sealed before compilation.",
      "wlv_preflight_error"
    )
  }
  wlv_runtime_store_identity_assert(store, "wlv_preflight_error")
  partitions <- sort(
    wlv_runtime_validate_names(partitions, "partitions"),
    method = "radix"
  )
  if (
    !is.numeric(checkpoint_order) || anyNA(checkpoint_order) ||
      any(!is.finite(checkpoint_order)) || any(checkpoint_order < 0) ||
      any(checkpoint_order != as.integer(checkpoint_order)) ||
      is.null(names(checkpoint_order)) || any(!nzchar(names(checkpoint_order))) ||
      anyDuplicated(names(checkpoint_order))
  ) {
    wlv_runtime_abort(
      "`checkpoint_order` must be a uniquely named vector of non-negative integers.",
      "wlv_preflight_error"
    )
  }
  instances <- wlv_runtime_instances(instances)
  instance_node_ids <- vapply(
    instances,
    function(instance) {
      wlv_runtime_node_id(instance$instance_id, instance$partition)
    },
    character(1L)
  )
  instances <- instances[order(instance_node_ids, method = "radix")]
  resolved <- lapply(
    instances,
    wlv_runtime_resolve_instance,
    registry = registry,
    operation = operation,
    partitions = partitions
  )
  ids <- vapply(resolved, function(module) module$node_id, character(1L))
  names(resolved) <- ids
  entries <- wlv_runtime_provider_entries(store, resolved)
  provider_nodes <- wlv_runtime_provider_nodes(resolved)
  if (length(partitions)) {
    invalid_store_partitions <- unique(vapply(
      Filter(
        function(entry) {
          identical(entry$contract$scope, "io_period") &&
            !entry$partition %in% partitions
        },
        entries
      ),
      function(entry) entry$partition,
      character(1L)
    ))
    if (length(invalid_store_partitions)) {
      wlv_runtime_abort(
        sprintf(
          "The resource graph contains undeclared io partition(s): %s.",
          paste(
            sort(invalid_store_partitions, method = "radix"),
            collapse = ", "
          )
        ),
        "wlv_preflight_error"
      )
    }
  }
  terminals <- wlv_runtime_validate_provider_chains(entries)

  edge_rows <- list()
  add_edge <- function(locator, to, resource) {
    locator_id <- wlv_runtime_locator_id(
      locator$key,
      locator$partition,
      locator$producer
    )
    from <- provider_nodes[[locator_id]]
    if (is.null(from)) {
      return(invisible(NULL))
    }
    edge_rows[[length(edge_rows) + 1L]] <<- data.frame(
      from = from,
      to = to,
      resource = resource,
      stringsAsFactors = FALSE
    )
    invisible(NULL)
  }

  for (id in ids) {
    module <- resolved[[id]]
    input_locators <- list()
    for (alias in names(module$requires)) {
      ref <- module$requires[[alias]]
      locators <- wlv_runtime_resolve_input(
        ref,
        entries,
        terminals,
        partitions,
        id
      )
      if (length(locators)) {
        for (locator in locators) {
          producer_node <- provider_nodes[[wlv_runtime_locator_id(
            locator$key,
            locator$partition,
            locator$producer
          )]]
          if (!is.null(producer_node) && identical(producer_node, id)) {
            wlv_runtime_abort(
              sprintf(
                "Instance `%s` reads its own output `%s`; select its predecessor explicitly.",
                id,
                ref$key
              ),
              "wlv_preflight_error"
            )
          }
          add_edge(locator, id, ref$key)
        }
      }
      input_locators[[alias]] <- locators
    }
    for (output in module$provides) {
      if (!is.null(output$predecessor)) {
        add_edge(
          list(
            key = output$predecessor$key,
            partition = output$predecessor$partition,
            producer = output$predecessor$producer
          ),
          id,
          output$ref$key
        )
      }
    }
    resolved[[id]]$input_locators <- input_locators
    resolved[[id]]$checkpoint_rank <- wlv_runtime_checkpoint_rank(
      module$checkpoint,
      checkpoint_order
    )
  }
  edges <- if (length(edge_rows)) {
    unique(do.call(rbind, edge_rows))
  } else {
    data.frame(
      from = character(),
      to = character(),
      resource = character(),
      stringsAsFactors = FALSE
    )
  }
  if (nrow(edges)) {
    edges <- edges[
      order(edges$from, edges$to, edges$resource, method = "radix"),
      ,
      drop = FALSE
    ]
    rownames(edges) <- NULL
    for (index in seq_len(nrow(edges))) {
      from <- edges$from[[index]]
      to <- edges$to[[index]]
      if (resolved[[from]]$checkpoint_rank > resolved[[to]]$checkpoint_rank) {
        wlv_runtime_abort(
          sprintf(
            "Checkpoint violation on `%s`: `%s` runs after consumer `%s`.",
            edges$resource[[index]],
            from,
            to
          ),
          "wlv_preflight_error"
        )
      }
    }
  }
  order <- wlv_runtime_topological_order(ids, edges)
  terminal_catalog <- wlv_runtime_terminal_catalog(terminals)
  liveness <- wlv_runtime_liveness_schedule(entries, resolved, order)
  plan <- new.env(parent = emptyenv())
  plan$operation <- operation
  plan$partitions <- partitions
  plan$modules <- resolved
  plan$order <- order
  plan$edges <- edges
  plan$base_store_token <- store$identity_token
  plan$base_catalog <- wlv_store_catalog(store)
  plan$terminals <- lapply(terminals, wlv_runtime_entry_locator)
  plan$terminal_catalog <- terminal_catalog
  plan$liveness <- liveness
  class(plan) <- "wlv_module_plan"
  lockEnvironment(plan, bindings = TRUE)
  plan
}

# Read-only contexts and atomic execution -----------------------------------

wlv_runtime_context <- function(
    inputs,
    input_names,
    args,
    argument_names,
    services,
    service_names,
    partition,
    instance_id) {
  input <- function(name) {
    name <- wlv_runtime_scalar_character(name, "name")
    if (!name %in% input_names) {
      wlv_runtime_abort(
        sprintf(
          "Module instance `%s` attempted undeclared input `%s`.",
          instance_id,
          name
        ),
        "wlv_context_error"
      )
    }
    inputs[[name]]
  }
  arg <- function(name) {
    name <- wlv_runtime_scalar_character(name, "name")
    if (!name %in% argument_names) {
      wlv_runtime_abort(
        sprintf(
          "Module instance `%s` attempted undeclared argument `%s`.",
          instance_id,
          name
        ),
        "wlv_context_error"
      )
    }
    args[[name]]
  }
  service <- function(name) {
    name <- wlv_runtime_scalar_character(name, "name")
    if (!name %in% service_names) {
      wlv_runtime_abort(
        sprintf(
          "Module instance `%s` attempted undeclared service `%s`.",
          instance_id,
          name
        ),
        "wlv_context_error"
      )
    }
    services[[name]]
  }
  current_partition <- function() partition

  context <- new.env(parent = emptyenv())
  context$input <- input
  context$arg <- arg
  context$service <- service
  context$partition <- current_partition
  class(context) <- "wlv_module_context"
  lockEnvironment(context, bindings = TRUE)
  context
}

wlv_runtime_apply_patch <- function(base, patch, contract, label) {
  if (!inherits(patch, "wlv_resource_patch")) {
    wlv_runtime_abort(
      sprintf("Patch output `%s` must use `wlv_resource_patch()`.", label),
      "wlv_result_error"
    )
  }
  dimensions <- dim(base)
  expected_count <- if (is.null(dimensions)) 1L else length(dimensions)
  indices <- patch$indices
  if (length(indices) != expected_count) {
    wlv_runtime_abort(
      sprintf("Patch output `%s` must index every dimension.", label),
      "wlv_result_error"
    )
  }
  if (!is.null(names(indices))) {
    expected_names <- if (!is.null(contract$axes)) {
      contract$axes
    } else if (!is.null(dimnames(base))) {
      names(dimnames(base))
    } else {
      NULL
    }
    if (is.null(expected_names) || !identical(names(indices), expected_names)) {
      wlv_runtime_abort(
        sprintf("Patch output `%s` has incompatible index names.", label),
        "wlv_result_error"
      )
    }
  }
  tryCatch(
    do.call("[<-", c(list(base), unname(indices), list(value = patch$value))),
    error = function(error) {
      wlv_runtime_abort(
        sprintf("Cannot apply patch output `%s`: %s", label, conditionMessage(error)),
        "wlv_result_error"
      )
    }
  )
}

wlv_runtime_read_locator <- function(locator, store) {
  entry <- wlv_runtime_entry(store, locator)
  entry$value
}

wlv_runtime_module_inputs <- function(store, module) {
  inputs <- list()
  for (alias in names(module$input_locators)) {
    locators <- module$input_locators[[alias]]
    ref <- module$requires[[alias]]
    value <- if (!length(locators)) {
      NULL
    } else if (ref$collect) {
      result <- lapply(locators, wlv_runtime_read_locator, store = store)
      names(result) <- names(locators)
      result
    } else {
      wlv_runtime_read_locator(locators[[1L]], store)
    }
    inputs[alias] <- list(value)
  }
  inputs
}

wlv_runtime_intrinsic_service_names <- function() {
  c("contract_runtime", "module_contract")
}

wlv_runtime_module_services <- function(module, inputs, store, services) {
  intrinsic <- intersect(
    module$services,
    wlv_runtime_intrinsic_service_names()
  )
  external <- setdiff(module$services, intrinsic)
  result <- services[external]
  if (!length(intrinsic)) {
    return(result)
  }
  if (!setequal(intrinsic, wlv_runtime_intrinsic_service_names())) {
    wlv_runtime_abort(
      sprintf(
        paste0(
          "Module instance `%s` must declare both intrinsic semantic ",
          "services together."
        ),
        module$node_id
      ),
      "wlv_runner_error"
    )
  }
  runtime <- wlv_semantic_module_runtime(
    inputs,
    module,
    semantic_input_mode = module$semantic_input_mode
  )
  result$contract_runtime <- runtime
  resolved_module <- module
  module_runtime <- runtime
  module_inputs <- inputs
  # The semantic finalizer needs declared inputs and predecessor values, but a
  # module must never receive a closure over the runner's complete mutable
  # working store. Retain only locators named by this module's contract, then
  # seal the physically distinct fork before exposing the finalizer service.
  input_store <- wlv_runtime_fork_store(
    store,
    retain_locator_ids = wlv_runtime_module_live_locator_ids(resolved_module)
  )
  wlv_seal_resource_store(input_store)
  finalizer_environment <- new.env(parent = emptyenv())
  finalizer_environment$resolved_module <- resolved_module
  finalizer_environment$module_runtime <- module_runtime
  finalizer_environment$module_inputs <- module_inputs
  finalizer_environment$input_store <- input_store
  finalizer_environment$wlv_semantic_finalize_module_result <-
    wlv_semantic_finalize_module_result
  finalizer <- function(module_result) wlv_semantic_finalize_module_result(
    resolved_module,
    module_result,
    module_runtime,
    module_inputs,
    input_store
  )
  environment(finalizer) <- finalizer_environment
  lockEnvironment(finalizer_environment, bindings = TRUE)
  result$module_contract <- finalizer
  result[module$services]
}

wlv_runtime_prepare_module_outputs <- function(store, module, result) {
  if (!inherits(result, "wlv_module_result")) {
    wlv_runtime_abort(
      sprintf(
        "Module instance `%s` did not return `wlv_module_result()`.",
        module$instance_id
      ),
      "wlv_result_error"
    )
  }
  expected <- names(module$provides)
  observed <- names(result$outputs)
  if (!setequal(expected, observed)) {
    missing <- setdiff(expected, observed)
    extra <- setdiff(observed, expected)
    details <- c(
      if (length(missing)) paste0("missing: ", paste(missing, collapse = ", ")),
      if (length(extra)) paste0("extra: ", paste(extra, collapse = ", "))
    )
    wlv_runtime_abort(
      sprintf(
        "Module instance `%s` returned invalid outputs (%s).",
        module$instance_id,
        paste(details, collapse = "; ")
      ),
      "wlv_result_error"
    )
  }
  if (wlv_runtime_contains_reference(result$diagnostics)) {
    wlv_runtime_abort(
      sprintf("Diagnostics from `%s` contain mutable references.", module$instance_id),
      "wlv_result_error"
    )
  }
  if (length(result$diagnostics)) {
    wlv_runtime_abort(
      sprintf(
        paste0(
          "Module instance `%s` returned lateral diagnostics; diagnostics ",
          "must be published through a declared diagnostic resource."
        ),
        module$instance_id
      ),
      "wlv_result_error"
    )
  }
  prepared <- list()
  for (alias in expected) {
    output <- module$provides[[alias]]
    ref <- output$ref
    value <- result$outputs[[alias]]
    label <- wlv_runtime_locator_label(ref$key, ref$partition, module$instance_id)
    if (
      identical(output$action, "patch") &&
        !identical(ref$contract$role, "semantic_state")
    ) {
      predecessor <- list(
        key = output$predecessor$key,
        partition = output$predecessor$partition,
        producer = output$predecessor$producer
      )
      base <- wlv_runtime_entry(store, predecessor)$value
      value <- wlv_runtime_apply_patch(base, value, ref$contract, label)
    } else if (inherits(value, "wlv_resource_patch")) {
      wlv_runtime_abort(
        sprintf(
          "Output `%s` returned a patch value that cannot be published directly.",
          label
        ),
        "wlv_result_error"
      )
    }
    wlv_runtime_validate_resource_value(value, ref$contract, label)
    locator_id <- wlv_runtime_locator_id(ref$key, ref$partition, module$instance_id)
    if (locator_id %in% names(store$entries)) {
      wlv_runtime_abort(
        sprintf("Output `%s` already exists.", label),
        "wlv_store_error"
      )
    }
    predecessor <- if (is.null(output$predecessor)) NULL else list(
      key = output$predecessor$key,
      partition = output$predecessor$partition,
      producer = output$predecessor$producer
    )
    prepared[[locator_id]] <- wlv_runtime_new_entry(
      key = ref$key,
      partition = ref$partition,
      producer = module$instance_id,
      value = value,
      contract = ref$contract,
      action = output$action,
      predecessor = predecessor,
      predecessor_contract = if (is.null(output$predecessor)) {
        NULL
      } else {
        output$predecessor$contract
      }
    )
  }
  prepared
}

wlv_runtime_locator_ids <- function(locators) {
  if (!length(locators)) {
    return(character())
  }
  unname(vapply(
    locators,
    function(locator) {
      wlv_runtime_locator_id(
        locator$key,
        locator$partition,
        locator$producer
      )
    },
    character(1L)
  ))
}

wlv_runtime_module_live_locator_ids <- function(module) {
  input_ids <- unlist(
    lapply(module$input_locators, wlv_runtime_locator_ids),
    use.names = FALSE
  )
  predecessors <- Filter(
    Negate(is.null),
    lapply(module$provides, `[[`, "predecessor")
  )
  predecessor_ids <- if (length(predecessors)) {
    vapply(predecessors, function(predecessor) {
      wlv_runtime_locator_id(
        predecessor$key,
        predecessor$partition,
        predecessor$producer
      )
    }, character(1L))
  } else {
    character()
  }
  unique(c(input_ids, unname(predecessor_ids)))
}

wlv_runtime_retained_locator_ids <- function(plan, retain_locator_ids) {
  terminal_ids <- plan$terminal_catalog$locator_id
  if (is.null(retain_locator_ids)) {
    return(terminal_ids)
  }
  if (!is.character(retain_locator_ids) || anyNA(retain_locator_ids) ||
      any(!nzchar(retain_locator_ids)) || anyDuplicated(retain_locator_ids)) {
    wlv_runtime_abort(
      "`retain_locator_ids` must be a character vector of unique terminal locator IDs.",
      "wlv_runner_error"
    )
  }
  unknown <- setdiff(retain_locator_ids, terminal_ids)
  if (length(unknown)) {
    wlv_runtime_abort(
      sprintf(
        "Retained locator `%s` is not a terminal of the compiled plan.",
        unknown[[1L]]
      ),
      "wlv_runner_error"
    )
  }
  unname(retain_locator_ids)
}

wlv_runtime_release_entries <- function(entries, release_ids, retained_lookup) {
  if (!length(entries) || !length(release_ids)) {
    return(list(entries = entries, pruned = FALSE))
  }
  retained <- vapply(release_ids, function(locator_id) {
    exists(locator_id, envir = retained_lookup, inherits = FALSE)
  }, logical(1L))
  release_ids <- release_ids[!retained]
  if (!length(release_ids)) {
    return(list(entries = entries, pruned = FALSE))
  }
  previous_length <- length(entries)
  entries[release_ids] <- NULL
  list(
    entries = entries,
    pruned = length(entries) < previous_length
  )
}

# A compact store is a final execution product: generations not selected for
# retention may have been removed. Use `retain_history = TRUE` when the returned
# store must remain a reusable input to a later module-plan compilation.
wlv_run_module_plan <- function(
    plan,
    store,
    services = list(),
    retain_history = FALSE,
    retain_locator_ids = NULL) {
  if (!inherits(plan, "wlv_module_plan") || !is.environment(plan) ||
      !environmentIsLocked(plan)) {
    wlv_runtime_abort("`plan` must be a compiled module plan.", "wlv_runner_error")
  }
  if (!inherits(store, "wlv_resource_store") || !is.environment(store) ||
      !environmentIsLocked(store) || !isTRUE(store$sealed)) {
    wlv_runtime_abort("`store` must be a sealed resource store.", "wlv_runner_error")
  }
  wlv_runtime_store_identity_assert(store, "wlv_runner_error")
  if (!identical(store$identity_token, plan$base_store_token) ||
      !identical(wlv_store_catalog(store), plan$base_catalog)) {
    wlv_runtime_abort(
      "The resource store identity or catalog no longer matches the plan's preflight snapshot.",
      "wlv_runner_error"
    )
  }
  if (!is.list(services) || (length(services) && (
    is.null(names(services)) || any(!nzchar(names(services))) ||
      anyDuplicated(names(services))
  ))) {
    wlv_runtime_abort("`services` must be a uniquely named list.", "wlv_runner_error")
  }
  retain_history <- wlv_runtime_scalar_logical(
    retain_history,
    "retain_history"
  )
  retained_locator_ids <- wlv_runtime_retained_locator_ids(
    plan,
    retain_locator_ids
  )
  retained_lookup <- new.env(
    hash = TRUE,
    parent = emptyenv(),
    size = max(29L, length(retained_locator_ids))
  )
  for (locator_id in retained_locator_ids) {
    retained_lookup[[locator_id]] <- TRUE
  }
  required_services <- unique(unlist(lapply(
    plan$modules,
    function(module) module$services
  ), use.names = FALSE))
  required_services <- setdiff(
    required_services,
    wlv_runtime_intrinsic_service_names()
  )
  missing_services <- setdiff(required_services, names(services))
  if (length(missing_services)) {
    wlv_runtime_abort(
      sprintf("Missing runtime service(s): %s.", paste(missing_services, collapse = ", ")),
      "wlv_runner_error"
    )
  }

  working <- wlv_runtime_fork_store(store)
  rm(store)
  pruned_since_gc <- FALSE
  if (!retain_history) {
    released <- wlv_runtime_release_entries(
      working$entries,
      plan$liveness$release_initial,
      retained_lookup
    )
    working$entries <- released$entries
    pruned_since_gc <- released$pruned
    rm(released)
  }
  trace_rows <- list()
  for (sequence in seq_along(plan$order)) {
    id <- plan$order[[sequence]]
    module <- plan$modules[[id]]
    inputs <- wlv_runtime_module_inputs(working, module)
    module_services <- wlv_runtime_module_services(
      module,
      inputs,
      working,
      services
    )
    context <- wlv_runtime_context(
      inputs = inputs,
      input_names = names(module$requires),
      args = module$args,
      argument_names = module$parameter_names,
      services = module_services,
      service_names = module$services,
      partition = module$partition,
      instance_id = module$node_id
    )
    prepared <- tryCatch(
      {
        result <- module$run(context)
        wlv_runtime_prepare_module_outputs(working, module, result)
      },
      error = function(error) {
        module_runtime <- module_services$contract_runtime
        has_anomalies <- is.environment(module_runtime) &&
          is.data.frame(module_runtime$anomalies) &&
          nrow(module_runtime$anomalies)
        if (inherits(error, "wlv_runtime_error") && !has_anomalies &&
            !inherits(error, "wlv_contract_error")) {
          stop(error)
        }
        stop(wlv_runtime_module_execution_condition(
          error,
          id,
          module_runtime
        ))
      }
    )
    next_entries <- working$entries
    for (locator_id in names(prepared)) {
      next_entries[[locator_id]] <- prepared[[locator_id]]
    }
    pruned <- FALSE
    if (!retain_history) {
      released <- wlv_runtime_release_entries(
        next_entries,
        plan$liveness$release_after[[sequence]],
        retained_lookup
      )
      next_entries <- released$entries
      pruned <- released$pruned
    }
    working$entries <- next_entries
    trace_rows[[length(trace_rows) + 1L]] <- data.frame(
      sequence = length(trace_rows) + 1L,
      node_id = id,
      instance_id = module$instance_id,
      module_id = module$module_id,
      checkpoint = as.character(module$checkpoint),
      partition = if (is.null(module$partition)) "" else module$partition,
      output_count = length(prepared),
      stringsAsFactors = FALSE
    )
    pruned_since_gc <- pruned_since_gc || pruned
    rm(inputs, module_services, context, prepared, next_entries)
    if (exists("result", inherits = FALSE)) {
      rm(result)
    }
    if (exists("released", inherits = FALSE)) {
      rm(released)
    }
    checkpoint_boundary <- sequence < length(plan$order) && !identical(
      module$checkpoint_rank,
      plan$modules[[plan$order[[sequence + 1L]]]]$checkpoint_rank
    )
    if (checkpoint_boundary && pruned_since_gc) {
      invisible(gc(full = FALSE))
      pruned_since_gc <- FALSE
    }
  }
  wlv_seal_resource_store(working)
  trace <- if (length(trace_rows)) {
    do.call(rbind, trace_rows)
  } else {
    data.frame(
      sequence = integer(),
      node_id = character(),
      instance_id = character(),
      module_id = character(),
      checkpoint = character(),
      partition = character(),
      output_count = integer(),
      stringsAsFactors = FALSE
    )
  }
  rm(trace_rows)
  invisible(gc(full = FALSE))
  result <- new.env(parent = emptyenv())
  result$store <- working
  result$trace <- trace
  class(result) <- "wlv_run_result"
  lockEnvironment(result, bindings = TRUE)
  result
}
