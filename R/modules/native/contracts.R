# Shared constructors for the native scientific modules --------------------
#
# Module contracts stay beside native module definitions.  These helpers only
# remove repetitive syntax; they do not discover dependencies or infer module
# behavior from file names or configuration rows.

wlv_native_array_contract <- function(
    scope = c("run", "io_period"),
    axes,
    unit = NULL,
    missingness = NULL) {
  wlv_resource_contract(
    scope = match.arg(scope),
    axes = axes,
    value_type = "array",
    unit = unit,
    missingness = missingness
  )
}

wlv_native_list_contract <- function(scope = c("run", "io_period")) {
  wlv_resource_contract(scope = match.arg(scope), value_type = "list")
}

wlv_native_data_frame_contract <- function(scope = c("run", "io_period")) {
  wlv_resource_contract(scope = match.arg(scope), value_type = "data.frame")
}

wlv_native_run_ref <- function(
    key,
    alias,
    value_type = c(
      "any", "numeric", "integer", "double", "logical", "character",
      "list", "data.frame", "array"
    ),
    producer = wlv_runtime_seed_producer,
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
    missingness = paste0("indicator:", indicator)
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
    missingness = "matrix"
  )
}

wlv_native_source_io_contract <- function() {
  wlv_native_array_contract(
    scope = "io_period",
    axes = c("year", "input", "output"),
    unit = "normalized_source_io",
    missingness = "source_contract"
  )
}

wlv_native_source_io_ref <- function(alias = "source_io") {
  stats::setNames(
    list(wlv_resource_ref(
      "source/io",
      wlv_native_source_io_contract(),
      producer = wlv_runtime_seed_producer
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
    missingness = "intermediate"
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
    missingness = "matrix"
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
    missingness = "published_contract"
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
  wlv_resource_contract(scope = "run", value_type = "data.frame")
}

wlv_native_indicator_metadata_ref <- function(
    alias = "indicator_metadata",
    producer = wlv_runtime_seed_producer) {
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
