# Native store construction ------------------------------------------------

wlv_native_resolved_instances <- function(
    registry,
    instances,
    partitions,
    operation) {
  lapply(instances, function(instance) {
    wlv_runtime_resolve_instance(
      registry,
      instance,
      operation = operation,
      partitions = partitions
    )
  })
}

wlv_native_output_group <- function(resolved, key, partition = NULL) {
  result <- list()
  for (module in resolved) {
    for (output in module$provides) {
      if (identical(output$ref$key, key) &&
          identical(output$ref$partition, partition)) {
        result[[length(result) + 1L]] <- list(module = module, output = output)
      }
    }
  }
  result
}

wlv_native_inherited_producer <- function(
    resolved,
    key,
    partition = NULL) {
  outputs <- wlv_native_output_group(resolved, key, partition)
  roots <- Filter(function(item) identical(item$output$action, "create"), outputs)
  if (length(roots)) {
    return(NULL)
  }
  produced_ids <- vapply(outputs, function(item) {
    item$module$instance_id
  }, character(1L))
  predecessors <- unique(unlist(lapply(outputs, function(item) {
    predecessor <- item$output$predecessor
    if (is.null(predecessor) || predecessor$producer %in% produced_ids) {
      character()
    } else {
      predecessor$producer
    }
  }), use.names = FALSE))
  if (length(predecessors) > 1L) {
    stop(
      sprintf(
        "Inherited resource `%s` has ambiguous predecessors: %s.",
        key,
        paste(predecessors, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (length(predecessors) == 1L) {
    return(predecessors[[1L]])
  }
  requested <- character()
  for (module in resolved) {
    for (ref in module$requires) {
      if (!ref$collect && identical(ref$key, key) &&
          identical(ref$partition, partition) && !is.null(ref$producer)) {
        requested <- c(requested, ref$producer)
      }
    }
  }
  requested <- unique(requested)
  requested <- setdiff(requested, produced_ids)
  if (length(requested) > 1L) {
    stop(
      sprintf(
        "Inherited resource `%s` is requested from incompatible producers: %s.",
        key,
        paste(requested, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (length(requested)) requested[[1L]] else wlv_runtime_seed_producer()
}

wlv_native_inherited_resource_needed <- function(
    resolved,
    key,
    partition = NULL) {
  outputs <- wlv_native_output_group(resolved, key, partition)
  if (any(vapply(outputs, function(item) {
    identical(item$output$action, "create")
  }, logical(1L)))) {
    return(FALSE)
  }
  if (length(outputs)) {
    return(TRUE)
  }
  any(vapply(resolved, function(module) {
    any(vapply(module$requires, function(ref) {
      identical(ref$key, key) && (
        isTRUE(ref$collect) || identical(ref$partition, partition)
      )
    }, logical(1L)))
  }, logical(1L)))
}

wlv_parent_source_terminal <- function() {
  structure(list(kind = "terminal"), class = "wlv_parent_source")
}

wlv_parent_source_exact <- function(producer) {
  producer <- wlv_runtime_scalar_character(producer, "parent producer")
  if (!grepl(wlv_runtime_identifier_pattern(), producer)) {
    stop("An exact parent producer must be an instance identifier.", call. = FALSE)
  }
  structure(
    list(kind = "exact", producer = producer),
    class = "wlv_parent_source"
  )
}

wlv_parent_source_assert <- function(source) {
  valid_terminal <- inherits(source, "wlv_parent_source") &&
    is.list(source) && identical(names(source), "kind") &&
    identical(source$kind, "terminal")
  valid_exact <- inherits(source, "wlv_parent_source") &&
    is.list(source) && identical(names(source), c("kind", "producer")) &&
    identical(source$kind, "exact") &&
    is.character(source$producer) && length(source$producer) == 1L &&
    !is.na(source$producer) && nzchar(source$producer) &&
    grepl(wlv_runtime_identifier_pattern(), source$producer)
  if (!valid_terminal && !valid_exact) {
    stop(
      "A parent source must explicitly select `terminal` or one exact producer.",
      call. = FALSE
    )
  }
  invisible(source)
}

wlv_parent_seed_request <- function(
    key,
    partition = NULL,
    source,
    child_producer,
    contract) {
  key <- wlv_runtime_scalar_character(
    key,
    "parent seed key",
    wlv_runtime_resource_pattern()
  )
  if (!is.null(partition)) {
    partition <- wlv_runtime_scalar_character(partition, "parent seed partition")
  }
  if (missing(source)) {
    stop("A parent seed request must declare its source selector.", call. = FALSE)
  }
  wlv_parent_source_assert(source)
  child_producer <- wlv_runtime_scalar_character(
    child_producer,
    "child seed producer"
  )
  if (!identical(child_producer, wlv_runtime_seed_producer()) &&
      !grepl(wlv_runtime_identifier_pattern(), child_producer)) {
    stop("A child seed producer must be `__seed__` or an instance identifier.",
      call. = FALSE
    )
  }
  wlv_resource_contract_assert(contract)
  if (identical(contract$scope, "run") && !is.null(partition)) {
    stop("A run-scoped parent seed request cannot declare a partition.",
      call. = FALSE
    )
  }
  if (identical(contract$scope, "io_period") && is.null(partition)) {
    stop("An io-period parent seed request requires a partition.",
      call. = FALSE
    )
  }
  structure(
    list(
      key = key,
      partition = partition,
      source = source,
      child_producer = child_producer,
      contract = contract
    ),
    class = "wlv_parent_seed_request"
  )
}

wlv_parent_seed_request_assert <- function(request) {
  if (!inherits(request, "wlv_parent_seed_request") || !is.list(request) ||
      !identical(
        names(request),
        c("key", "partition", "source", "child_producer", "contract")
      )) {
    stop("A parent seed request is invalid.", call. = FALSE)
  }
  wlv_parent_seed_request(
    key = request$key,
    partition = request$partition,
    source = request$source,
    child_producer = request$child_producer,
    contract = request$contract
  )
  invisible(request)
}

wlv_parent_seed_resolution_columns <- function() {
  c(
    "key", "partition", "source_mode", "source_producer",
    "child_producer", "origin_producer", "origin_state_producer",
    "contract_sha256", "axes_sha256", "value_sha256", "state_sha256",
    "snapshot_sha256"
  )
}

wlv_parent_seed_empty_resolutions <- function() {
  result <- as.data.frame(
    stats::setNames(
      rep(list(character()), length(wlv_parent_seed_resolution_columns())),
      wlv_parent_seed_resolution_columns()
    ),
    stringsAsFactors = FALSE
  )
  row.names(result) <- NULL
  result
}

wlv_parent_seed_resolutions_assert <- function(value) {
  columns <- wlv_parent_seed_resolution_columns()
  if (!is.data.frame(value) || !identical(names(value), columns) ||
      any(!vapply(value, is.character, logical(1L))) || anyNA(value)) {
    stop("Parent seed resolutions have an invalid schema.", call. = FALSE)
  }
  if (!nrow(value)) {
    return(invisible(value))
  }
  hash_columns <- c(
    "contract_sha256", "axes_sha256", "value_sha256", "state_sha256",
    "snapshot_sha256"
  )
  required <- setdiff(columns, c("partition", "source_producer"))
  exact <- value$source_mode == "exact"
  terminal <- value$source_mode == "terminal"
  ids <- paste(value$key, value$partition, value$child_producer, sep = "\034")
  canonical <- order(
    value$key,
    value$partition,
    value$child_producer,
    method = "radix"
  )
  if (any(!value$source_mode %in% c("terminal", "exact")) ||
      any(!nzchar(as.matrix(value[required]))) ||
      any(!grepl("^[0-9a-f]{64}$", as.matrix(value[hash_columns]))) ||
      any(terminal & nzchar(value$source_producer)) ||
      any(exact & !nzchar(value$source_producer)) ||
      any(exact & value$source_producer != value$origin_producer) ||
      any(value$origin_producer != value$origin_state_producer) ||
      anyDuplicated(ids) || !identical(canonical, seq_len(nrow(value)))) {
    stop("Parent seed resolutions are invalid or non-canonical.", call. = FALSE)
  }
  invisible(value)
}

wlv_parent_seed_resolution <- function(
    request,
    origin_producer,
    origin_state_producer,
    value,
    state,
    snapshot_sha256,
    authenticated_value_sha256 = NULL) {
  wlv_parent_seed_request_assert(request)
  origin_producer <- wlv_runtime_scalar_character(
    origin_producer,
    "origin producer"
  )
  origin_state_producer <- wlv_runtime_scalar_character(
    origin_state_producer,
    "origin state producer"
  )
  if (!identical(origin_producer, origin_state_producer)) {
    stop("A parent value and its semantic state have different origins.",
      call. = FALSE
    )
  }
  if (!is.character(snapshot_sha256) || length(snapshot_sha256) != 1L ||
      is.na(snapshot_sha256) || !grepl("^[0-9a-f]{64}$", snapshot_sha256)) {
    stop("A parent seed resolution requires an authenticated snapshot hash.",
      call. = FALSE
    )
  }
  wlv_runtime_validate_resource_value(value, request$contract, request$key)
  wlv_semantic_state_validate(
    state,
    value = value,
    target_key = request$key,
    axes = request$contract$axes,
    state_key = wlv_semantic_state_key(request$key)
  )
  if (is.null(authenticated_value_sha256)) {
    authenticated_value_sha256 <- wlv_runtime_snapshot_value_sha256(value)
  } else if (!is.character(authenticated_value_sha256) ||
      length(authenticated_value_sha256) != 1L ||
      is.na(authenticated_value_sha256) ||
      !grepl("^[0-9a-f]{64}$", authenticated_value_sha256)) {
    stop("A parent seed resolution received an invalid authenticated value hash.",
      call. = FALSE
    )
  }
  if (identical(request$source$kind, "exact") &&
      !identical(request$source$producer, origin_producer)) {
    stop(
      sprintf(
        paste0(
          "Parent terminal resource `%s` originates from `%s`; the exact ",
          "generation `%s` is not retained by this snapshot."
        ),
        request$key,
        origin_producer,
        request$source$producer
      ),
      call. = FALSE
    )
  }
  result <- data.frame(
    key = request$key,
    partition = if (is.null(request$partition)) "" else request$partition,
    source_mode = request$source$kind,
    source_producer = if (identical(request$source$kind, "exact")) {
      request$source$producer
    } else {
      ""
    },
    child_producer = request$child_producer,
    origin_producer = origin_producer,
    origin_state_producer = origin_state_producer,
    contract_sha256 = wlv_runtime_snapshot_contract_sha256(request$contract),
    axes_sha256 = wlv_runtime_snapshot_axes_sha256(
      value,
      request$contract$axes
    ),
    value_sha256 = authenticated_value_sha256,
    state_sha256 = wlv_runtime_snapshot_value_sha256(state),
    snapshot_sha256 = snapshot_sha256,
    stringsAsFactors = FALSE
  )
  wlv_parent_seed_resolutions_assert(result)
  result
}

wlv_parent_seed_bind_resolutions <- function(...) {
  values <- list(...)
  values <- unlist(lapply(values, function(value) {
    if (is.null(value)) list() else list(value)
  }), recursive = FALSE)
  if (!length(values)) {
    return(wlv_parent_seed_empty_resolutions())
  }
  for (value in values) {
    wlv_parent_seed_resolutions_assert(value)
  }
  result <- do.call(rbind, values)
  row.names(result) <- NULL
  result <- result[
    order(result$key, result$partition, result$child_producer, method = "radix"),
    ,
    drop = FALSE
  ]
  row.names(result) <- NULL
  wlv_parent_seed_resolutions_assert(result)
  result
}

wlv_native_parent_seed_request <- function(
    resolved,
    key,
    contract,
    partition = NULL,
    source) {
  if (missing(source)) {
    stop("Native parent imports must declare their source selector.",
      call. = FALSE
    )
  }
  wlv_parent_source_assert(source)
  if (!wlv_native_inherited_resource_needed(resolved, key, partition)) {
    return(NULL)
  }
  child_producer <- wlv_native_inherited_producer(resolved, key, partition)
  if (is.null(child_producer)) {
    return(NULL)
  }
  wlv_parent_seed_request(
    key = key,
    partition = partition,
    source = source,
    child_producer = child_producer,
    contract = contract
  )
}

wlv_native_replace_seed <- function(seeds, replacement) {
  id <- wlv_runtime_locator_id(
    replacement$key,
    replacement$partition,
    replacement$producer
  )
  retained <- Filter(function(seed) {
    !identical(
      wlv_runtime_locator_id(seed$key, seed$partition, seed$producer),
      id
    )
  }, seeds)
  c(retained, list(replacement))
}

wlv_native_parent_indicator_state_records <- function(
    parent_result_dir,
    indicators) {
  path <- file.path(parent_result_dir, "_states.csv")
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(
      "Parent result lacks the required persisted `_states.csv` provenance.",
      call. = FALSE
    )
  }
  records <- wlv_read_contract_states(path)
  if (nrow(records)) {
    if (any(!records$artifact %in% c("sea_sectors", "sea_countries")) ||
        any(!records$indicator %in% indicators) ||
        any(!records$state %in% c("source_missing", "not_applicable"))) {
      stop(
        "Parent persisted states contain an unknown artifact, indicator, or state.",
        call. = FALSE
      )
    }
    coordinate_columns <- setdiff(
      wlv_contract_state_columns(),
      "state"
    )
    coordinate_keys <- do.call(
      paste,
      c(records[coordinate_columns], sep = "\034")
    )
    if (anyDuplicated(coordinate_keys)) {
      stop("Parent persisted states contain duplicate coordinates.", call. = FALSE)
    }
  }
  records
}

wlv_native_parent_indicator_state_array <- function(
    records,
    artifact,
    indicator,
    value) {
  expected_axes <- switch(
    artifact,
    sea_sectors = c("year", "sector", "country"),
    sea_countries = c("year", "country"),
    stop(sprintf("Unsupported parent state artifact `%s`.", artifact),
      call. = FALSE
    )
  )
  if (!is.numeric(value) || is.null(dim(value)) ||
      !identical(names(dimnames(value)), expected_axes) ||
      any(is.nan(value)) || any(is.infinite(value))) {
    stop(
      sprintf(
        "Parent `%s/%s` value is incompatible with semantic-state import.",
        artifact,
        indicator
      ),
      call. = FALSE
    )
  }
  current <- records[
    records$artifact == artifact & records$indicator == indicator,
    ,
    drop = FALSE
  ]
  states <- wlv_semantic_state_array(value, expected_axes)
  ordinary_na <- which(is.na(value) & !is.nan(value))
  if (!nrow(current)) {
    if (length(ordinary_na)) {
      stop(
        sprintf(
          "Parent `%s/%s` has ordinary NAs without persisted semantic states.",
          artifact,
          indicator
        ),
        call. = FALSE
      )
    }
    return(states)
  }
  unused <- setdiff(c("year", "country", "sector", "output"), expected_axes)
  if (any(vapply(current[unused], function(column) {
    any(nzchar(column))
  }, logical(1L)))) {
    stop(
      sprintf(
        "Parent `%s/%s` states declare coordinates outside their artifact axes.",
        artifact,
        indicator
      ),
      call. = FALSE
    )
  }
  coordinates <- vapply(seq_along(expected_axes), function(index) {
    match(current[[expected_axes[[index]]]], dimnames(value)[[index]])
  }, integer(nrow(current)))
  if (is.null(dim(coordinates))) {
    coordinates <- matrix(coordinates, ncol = length(expected_axes))
  }
  if (anyNA(coordinates)) {
    stop(
      sprintf(
        "Parent `%s/%s` states reference unknown coordinates.",
        artifact,
        indicator
      ),
      call. = FALSE
    )
  }
  dimensions <- dim(value)
  multipliers <- if (length(dimensions) == 1L) {
    1
  } else {
    cumprod(c(1, dimensions[seq_len(length(dimensions) - 1L)]))
  }
  positions <- as.integer(
    1 + rowSums(sweep(coordinates - 1L, 2L, multipliers, `*`))
  )
  if (anyDuplicated(positions) ||
      !identical(sort(positions), sort(ordinary_na)) ||
      any(!is.na(value[positions]) | is.nan(value[positions]))) {
    stop(
      sprintf(
        "Parent `%s/%s` persisted states do not exactly cover ordinary NAs.",
        artifact,
        indicator
      ),
      call. = FALSE
    )
  }
  states[positions] <- current$state
  states
}

wlv_native_crosscheck_parent_indicator_states <- function(
    persisted,
    authoritative,
    value,
    artifact,
    indicator) {
  authoritative_states <- wlv_semantic_state_expand(authoritative, value)
  ordinary_na <- which(is.na(value) & !is.nan(value))
  if (length(ordinary_na) && !identical(
    as.vector(persisted)[ordinary_na],
    as.vector(authoritative_states)[ordinary_na]
  )) {
    stop(
      sprintf(
        paste0(
          "Parent `%s/%s` `_states.csv` records disagree with the ",
          "authoritative runtime snapshot."
        ),
        artifact,
        indicator
      ),
      call. = FALSE
    )
  }
  invisible(authoritative)
}

wlv_native_validate_parent_indicator_schema <- function(
    value,
    indicators,
    artifact) {
  indicators <- as.character(indicators)
  actual <- if (is.array(value) && !is.null(dimnames(value))) {
    dimnames(value)$indicator
  } else {
    NULL
  }
  if (identical(actual, indicators)) {
    return(invisible(TRUE))
  }
  missing <- setdiff(indicators, actual)
  unexpected <- setdiff(actual, indicators)
  order <- if (setequal(actual, indicators)) "different" else "n/a"
  stop(
    sprintf(
      paste0(
        "Parent result indicator schema differs from the current method ",
        "configuration (%s: missing=[%s], unexpected=[%s], order=%s)."
      ),
      artifact,
      paste(missing, collapse = ","),
      paste(unexpected, collapse = ","),
      order
    ),
    call. = FALSE
  )
}

wlv_native_parent_snapshot_identity <- function(
    parent_result_dir,
    snapshot,
    snapshot_sha256 = NULL) {
  path <- file.path(parent_result_dir, wlv_runtime_snapshot_filename())
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(
      sprintf("Parent run lacks `%s`.", wlv_runtime_snapshot_filename()),
      call. = FALSE
    )
  }
  before <- wlv_publication_file_sha256(path)
  if (!is.null(snapshot_sha256) && !identical(before, snapshot_sha256)) {
    stop("Parent runtime snapshot no longer matches its authenticated hash.",
      call. = FALSE
    )
  }
  observed <- readRDS(path)
  after <- wlv_publication_file_sha256(path)
  if (!identical(after, before) || !identical(observed, snapshot)) {
    stop("Supplied parent runtime snapshot differs from its immutable file.",
      call. = FALSE
    )
  }
  before
}

wlv_native_parent_indicator_seeds <- function(
    parent_result_dir,
    indicators,
    resolved,
    method = NULL,
    source = NULL,
    partitions = NULL,
    snapshot = NULL,
    snapshot_sha256 = NULL) {
  indicators <- as.character(indicators)
  if (is.null(snapshot)) {
    snapshot <- wlv_runtime_snapshot_read_envelope(
      parent_result_dir,
      method = method,
      source = source,
      partitions = partitions
    )
  }
  snapshot_sha256 <- wlv_native_parent_snapshot_identity(
    parent_result_dir,
    snapshot,
    snapshot_sha256
  )
  records <- wlv_native_parent_indicator_state_records(
    parent_result_dir,
    indicators
  )
  seeds <- list()
  resolutions <- list()

  sector_array <- wlv_runtime_snapshot_panel_array(
    snapshot,
    parent_result_dir,
    "sea_sectors"
  )
  wlv_native_validate_parent_indicator_schema(
    sector_array,
    indicators,
    "sea_sectors"
  )
  for (indicator in indicators) {
    sector_key <- wlv_native_indicator_key(indicator, "sector")
    sector_contract <- wlv_native_indicator_contract(indicator)
    sector_request <- wlv_native_parent_seed_request(
      resolved,
      sector_key,
      sector_contract,
      source = wlv_parent_source_terminal()
    )
    if (is.null(sector_request)) {
      next
    }
    sector_value <- sector_array[, indicator, , , drop = FALSE]
    sector_value <- array(
      sector_value,
      dim = dim(sector_array)[c(1L, 3L, 4L)],
      dimnames = stats::setNames(
        dimnames(sector_array)[c(1L, 3L, 4L)],
        c("year", "sector", "country")
      )
    )
    sector_provenance <- wlv_runtime_snapshot_indicator_provenance_validated(
      snapshot,
      "sea_sectors",
      indicator,
      sector_value,
      sector_contract
    )
    persisted_sector_states <- wlv_native_parent_indicator_state_array(
      records,
      "sea_sectors",
      indicator,
      sector_value
    )
    sector_states <- wlv_runtime_snapshot_indicator_state_validated(
      snapshot,
      "sea_sectors",
      indicator,
      sector_value
    )
    wlv_native_crosscheck_parent_indicator_states(
      persisted_sector_states,
      sector_states,
      sector_value,
      "sea_sectors",
      indicator
    )
    resolutions[[length(resolutions) + 1L]] <- wlv_parent_seed_resolution(
      sector_request,
      origin_producer = sector_provenance$producer[[1L]],
      origin_state_producer = sector_provenance$state_producer[[1L]],
      value = sector_value,
      state = sector_states,
      snapshot_sha256 = snapshot_sha256
    )
    pair <- wlv_native_stateful_seed_pair(wlv_seed_resource(
      sector_key,
      sector_value,
      sector_contract,
      producer = sector_request$child_producer
    ), states = sector_states)
    seeds <- c(seeds, pair)
    rm(sector_value, sector_states, persisted_sector_states)
  }
  rm(sector_array)
  invisible(gc(full = FALSE))

  country_array <- wlv_runtime_snapshot_panel_array(
    snapshot,
    parent_result_dir,
    "sea_countries"
  )
  wlv_native_validate_parent_indicator_schema(
    country_array,
    indicators,
    "sea_countries"
  )
  for (indicator in indicators) {
    country_key <- wlv_native_indicator_key(indicator, "country")
    country_contract <- wlv_native_indicator_contract(
      indicator,
      level = "country"
    )
    country_request <- wlv_native_parent_seed_request(
      resolved,
      country_key,
      country_contract,
      source = wlv_parent_source_terminal()
    )
    if (is.null(country_request)) {
      next
    }
    country_value <- country_array[, indicator, , drop = FALSE]
    country_value <- array(
      country_value,
      dim = dim(country_array)[c(1L, 3L)],
      dimnames = stats::setNames(
        dimnames(country_array)[c(1L, 3L)],
        c("year", "country")
      )
    )
    country_provenance <- wlv_runtime_snapshot_indicator_provenance_validated(
      snapshot,
      "sea_countries",
      indicator,
      country_value,
      country_contract
    )
    persisted_country_states <- wlv_native_parent_indicator_state_array(
      records,
      "sea_countries",
      indicator,
      country_value
    )
    country_states <- wlv_runtime_snapshot_indicator_state_validated(
      snapshot,
      "sea_countries",
      indicator,
      country_value
    )
    wlv_native_crosscheck_parent_indicator_states(
      persisted_country_states,
      country_states,
      country_value,
      "sea_countries",
      indicator
    )
    resolutions[[length(resolutions) + 1L]] <- wlv_parent_seed_resolution(
      country_request,
      origin_producer = country_provenance$producer[[1L]],
      origin_state_producer = country_provenance$state_producer[[1L]],
      value = country_value,
      state = country_states,
      snapshot_sha256 = snapshot_sha256
    )
    pair <- wlv_native_stateful_seed_pair(wlv_seed_resource(
      country_key,
      country_value,
      country_contract,
      producer = country_request$child_producer
    ), states = country_states)
    seeds <- c(seeds, pair)
    rm(country_value, country_states, persisted_country_states)
  }
  rm(country_array)
  invisible(gc(full = FALSE))
  wlv_native_validate_seed_semantic_pairs(seeds)
  list(
    seeds = seeds,
    resolutions = do.call(
      wlv_parent_seed_bind_resolutions,
      resolutions
    )
  )
}

wlv_native_parent_io_seeds <- function(
    parent_result_dir,
    source_io_paths,
    partitions,
    resolved,
    dimensions,
    method = NULL,
    source = NULL,
    snapshot = NULL,
    snapshot_sha256 = NULL) {
  if (is.null(snapshot)) {
    snapshot <- wlv_runtime_snapshot_read_envelope(
      parent_result_dir,
      method = method,
      source = source,
      partitions = partitions
    )
  }
  snapshot_sha256 <- wlv_native_parent_snapshot_identity(
    parent_result_dir,
    snapshot,
    snapshot_sha256
  )
  if (nrow(snapshot$io_artifacts) != length(source_io_paths) ||
      length(partitions) != length(source_io_paths)) {
    stop("Parent result IO coverage differs from normalized source IO coverage.", call. = FALSE)
  }
  source_partitions <- vapply(
    source_io_paths,
    wlv_native_io_partition,
    character(1L)
  )
  if (anyDuplicated(source_partitions) ||
      !setequal(source_partitions, partitions)) {
    stop("Parent and source IO period coverage does not correspond.", call. = FALSE)
  }
  source_paths <- stats::setNames(source_io_paths, source_partitions)
  if (!is.list(dimensions) || !is.list(dimensions$lists) ||
      !is.character(dimensions$lists$input) ||
      !is.character(dimensions$lists$output) ||
      anyNA(dimensions$lists$input) || anyNA(dimensions$lists$output) ||
      anyDuplicated(dimensions$lists$input) ||
      anyDuplicated(dimensions$lists$output)) {
    stop("Current IO dimensions are incomplete or invalid.", call. = FALSE)
  }
  expected_input <- dimensions$lists$input
  expected_output <- dimensions$lists$output
  seeds <- list()
  resolutions <- list()
  for (index in seq_along(partitions)) {
    partition <- partitions[[index]]
    resources <- wlv_runtime_snapshot_io_resources()
    resource_requests <- lapply(resources, function(resource) {
      key <- paste0("io/", resource)
      wlv_native_parent_seed_request(
        resolved,
        key,
        wlv_native_io_contract(resource),
        partition,
        source = wlv_parent_source_terminal()
      )
    })
    names(resource_requests) <- resources
    inherited_resources <- resources[vapply(
      resource_requests,
      function(value) !is.null(value),
      logical(1L)
    )]
    source_years <- wlv_native_io_years(source_paths[[partition]])
    if (length(inherited_resources)) {
      inherited <- wlv_runtime_snapshot_io_slices(
        snapshot,
        parent_result_dir,
        partition,
        inherited_resources
      )
      if (!identical(inherited$dimnames$variable, resources)) {
        stop(
          sprintf("Parent IO resources differ for `%s`.", partition),
          call. = FALSE
        )
      }
      if (!identical(inherited$dimnames$year, source_years)) {
        stop(
          sprintf("Parent and source IO years differ for `%s`.", partition),
          call. = FALSE
        )
      }
      if (!identical(inherited$dimnames$input, expected_input) ||
          !identical(inherited$dimnames$output, expected_output)) {
        stop(
          sprintf("Parent IO dimensions differ for `%s`.", partition),
          call. = FALSE
        )
      }
    } else {
      inherited <- NULL
    }
    for (resource in inherited_resources) {
      key <- paste0("io/", resource)
      entry <- wlv_runtime_snapshot_resource_validated(
        snapshot,
        key,
        partition
      )
      request <- resource_requests[[resource]]
      selected <- inherited$values[[resource]]
      if (!identical(
        entry$value_sha256,
        inherited$value_sha256[[resource]]
      )) {
        stop(
          sprintf(
            "Parent IO value provenance differs for `%s[%s]`.",
            key,
            partition
          ),
          call. = FALSE
        )
      }
      wlv_semantic_state_validate(
        entry$state,
        value = selected,
        target_key = key,
        axes = c("year", "input", "output"),
        state_key = wlv_semantic_state_key(key)
      )
      resolutions[[length(resolutions) + 1L]] <- wlv_parent_seed_resolution(
        request,
        origin_producer = entry$producer,
        origin_state_producer = entry$state_producer,
        value = selected,
        state = entry$state,
        snapshot_sha256 = snapshot_sha256,
        authenticated_value_sha256 = inherited$value_sha256[[resource]]
      )
      pair <- wlv_native_stateful_seed_pair(wlv_seed_resource(
        key,
        selected,
        request$contract,
        partition = partition,
        producer = request$child_producer
      ), states = entry$state)
      seeds <- c(seeds, pair)
      rm(selected)
    }
    lambda_contract <- wlv_native_intermediate_contract(
      "lambda",
      c("year", "input"),
      "io_period"
    )
    lambda_request <- wlv_native_parent_seed_request(
      resolved,
      "intermediate/lambda",
      lambda_contract,
      partition,
      source = wlv_parent_source_terminal()
    )
    if (!is.null(lambda_request)) {
      lambda_entry <- wlv_runtime_snapshot_resource_validated(
        snapshot,
        "intermediate/lambda",
        partition
      )
      if (!identical(dimnames(lambda_entry$value)$year, source_years) ||
          !identical(dimnames(lambda_entry$value)$input, expected_input)) {
        stop(
          sprintf("Parent lambda dimensions differ for `%s`.", partition),
          call. = FALSE
        )
      }
      resolutions[[length(resolutions) + 1L]] <- wlv_parent_seed_resolution(
        lambda_request,
        origin_producer = lambda_entry$producer,
        origin_state_producer = lambda_entry$state_producer,
        value = lambda_entry$value,
        state = lambda_entry$state,
        snapshot_sha256 = snapshot_sha256
      )
      pair <- wlv_native_stateful_seed_pair(wlv_seed_resource(
        "intermediate/lambda",
        lambda_entry$value,
        lambda_request$contract,
        partition = partition,
        producer = lambda_request$child_producer
      ), states = lambda_entry$state)
      seeds <- c(seeds, pair)
    }
    if (!is.null(inherited)) {
      rm(inherited)
      invisible(gc(full = FALSE))
    }
  }
  wlv_native_validate_seed_semantic_pairs(seeds)
  list(
    seeds = seeds,
    resolutions = do.call(
      wlv_parent_seed_bind_resolutions,
      resolutions
    )
  )
}

wlv_native_parent_parameters <- function(parent_result_dir, current, at_stage) {
  if (identical(at_stage, 1L)) {
    return(current)
  }
  path <- file.path(parent_result_dir, "_parameters.csv")
  persisted <- wlv_native_read_semicolon(path)
  comparable <- setdiff(names(current), "description")
  same <- identical(names(persisted), names(current)) &&
    identical(nrow(persisted), nrow(current)) &&
    identical(persisted[comparable], current[comparable]) &&
    all(endsWith(
      as.character(persisted$description),
      as.character(current$description)
    ))
  if (!same) {
    stop(
      "Current method parameters differ from the parent run; recalculate from stage 1.",
      call. = FALSE
    )
  }
  persisted
}

wlv_native_recalculated_indicator_ids <- function(resolved, indicators) {
  prefix <- "sea/sector/"
  produced <- unique(unlist(lapply(resolved, function(module) {
    keys <- vapply(module$provides, function(output) {
      output$ref$key
    }, character(1L))
    substring(
      keys[startsWith(keys, prefix)],
      nchar(prefix) + 1L
    )
  }), use.names = FALSE))
  indicators[indicators %in% produced]
}

wlv_native_merge_recalculation_metadata <- function(
    parent,
    current,
    resolved,
    indicators) {
  valid <- function(value) {
    is.data.frame(value) && "code" %in% names(value) &&
      identical(as.character(value$code), indicators) &&
      !anyDuplicated(value$code)
  }
  if (!valid(parent) || !valid(current) || !identical(names(parent), names(current))) {
    stop(
      "Parent indicator metadata schema differs from the current method configuration.",
      call. = FALSE
    )
  }
  refreshed <- wlv_native_recalculated_indicator_ids(resolved, indicators)
  result <- parent
  if (length(refreshed)) {
    rows <- match(refreshed, indicators)
    current_rows <- current[rows, , drop = FALSE]
    for (column in setdiff(names(result), "code")) {
      declared <- !is.na(current_rows[[column]])
      if (any(declared)) {
        result[[column]][rows[declared]] <- current_rows[[column]][declared]
      }
    }
  }
  row.names(result) <- result$code
  result
}

wlv_native_parent_snapshot_sha256 <- function(manifest) {
  if (!is.list(manifest) || !is.list(manifest$artifacts) ||
      !length(manifest$artifacts)) {
    stop("Parent manifest lacks its authenticated artifact inventory.",
      call. = FALSE
    )
  }
  paths <- vapply(manifest$artifacts, function(record) {
    if (!is.list(record) || !is.character(record$path) ||
        length(record$path) != 1L || is.na(record$path)) {
      return(NA_character_)
    }
    record$path
  }, character(1L))
  index <- which(paths == wlv_runtime_snapshot_filename())
  if (length(index) != 1L) {
    stop("Parent manifest lacks one unique runtime snapshot artifact.",
      call. = FALSE
    )
  }
  sha256 <- manifest$artifacts[[index]]$sha256
  if (!is.character(sha256) || length(sha256) != 1L || is.na(sha256) ||
      !grepl("^[0-9a-f]{64}$", sha256)) {
    stop("Parent manifest runtime snapshot hash is invalid.", call. = FALSE)
  }
  sha256
}

wlv_native_build_store <- function(
    plan,
    method_record,
    run_data,
    registry,
    instances,
    indicators,
    unit_definitions,
    partitions,
    compatibility) {
  wlv_runtime_compatibility_assert(compatibility)
  base <- wlv_native_base_seeds(
    plan,
    method_record,
    run_data,
    registry,
    instances,
    indicators,
    unit_definitions
  )
  source_io <- if (plan$mode == "calculate" || plan$at_stage <= 4L) {
    wlv_native_source_io_seeds(run_data$source_io)
  } else {
    list()
  }
  seeds <- c(base$seeds, unname(source_io))
  operation <- if (identical(plan$mode, "calculate")) {
    "calculate"
  } else {
    "recalculate"
  }
  resolved <- wlv_native_resolved_instances(
    registry,
    instances,
    partitions,
    operation
  )
  parent_snapshot <- NULL
  parent_imports <- wlv_parent_seed_empty_resolutions()
  if (identical(plan$mode, "calculate")) {
    seeds <- c(seeds, wlv_native_capital_data_seeds(plan$root, run_data))
  } else {
    parent_snapshot_sha256 <- wlv_native_parent_snapshot_sha256(
      run_data$parent_manifest
    )
    parent_snapshot <- wlv_runtime_snapshot_read_envelope(
      run_data$parent_result_dir,
      method = method_record$method[[1L]],
      source = method_record$source[[1L]],
      partitions = partitions,
      expected_sha256 = parent_snapshot_sha256
    )
    # This comparison deliberately precedes every parent value/state import.
    # A selective recalculation may only combine resources produced under the
    # exact same concrete scientific contracts.
    wlv_runtime_snapshot_assert_compatible(
      parent_snapshot,
      compatibility
    )
    parent <- wlv_native_parent_indicator_seeds(
      run_data$parent_result_dir,
      indicators,
      resolved,
      method = method_record$method[[1L]],
      source = method_record$source[[1L]],
      partitions = partitions,
      snapshot = parent_snapshot,
      snapshot_sha256 = parent_snapshot_sha256
    )
    seeds <- c(seeds, parent$seeds)
    parent_imports <- parent$resolutions
    parameters <- wlv_native_parent_parameters(
      run_data$parent_result_dir,
      base$parameters$parameters,
      plan$at_stage
    )
    seeds <- wlv_native_replace_seed(seeds, wlv_seed_resource(
      "configuration/parameters",
      parameters,
      wlv_resource_contract(scope = "run", value_type = "data.frame")
    ))
    metadata_path <- file.path(run_data$parent_result_dir, "meta_indicators.RDS")
    if (file.exists(metadata_path)) {
      metadata <- wlv_native_merge_recalculation_metadata(
        parent = readRDS(metadata_path),
        current = base$metadata,
        resolved = resolved,
        indicators = indicators
      )
      seeds <- wlv_native_replace_seed(seeds, wlv_seed_resource(
        "metadata/indicators",
        metadata,
        wlv_native_indicator_metadata_contract()
      ))
    }
    if (plan$at_stage <= 4L) {
      parent_io <- wlv_native_parent_io_seeds(
        run_data$parent_result_dir,
        run_data$source_io,
        partitions,
        resolved,
        base$dimensions,
        method = method_record$method[[1L]],
        source = method_record$source[[1L]],
        snapshot = parent_snapshot,
        snapshot_sha256 = parent_snapshot_sha256
      )
      seeds <- c(seeds, parent_io$seeds)
      parent_imports <- wlv_parent_seed_bind_resolutions(
        parent_imports,
        parent_io$resolutions
      )
      rm(parent_io)
    }
    rm(parent)
  }
  wlv_native_validate_seed_semantic_pairs(seeds)
  list(
    store = wlv_new_resource_store(seeds),
    dimensions = base$dimensions,
    parameters = base$parameters,
    resolved = resolved,
    parent_snapshot = parent_snapshot,
    parent_imports = parent_imports
  )
}
