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

wlv_native_parent_indicator_seeds <- function(
    parent_result_dir,
    indicators,
    resolved) {
  indicators <- as.character(indicators)
  sector_path <- file.path(parent_result_dir, "sea_sectors.fst")
  country_path <- file.path(parent_result_dir, "sea_countries.fst")
  sector_array <- read_fst_array(sector_path)
  country_array <- read_fst_array(country_path)
  parent_indicators <- list(
    sector = dimnames(sector_array)[[2L]],
    country = dimnames(country_array)[[2L]]
  )
  incompatible <- names(parent_indicators)[!vapply(
    parent_indicators,
    identical,
    logical(1L),
    indicators
  )]
  if (length(incompatible)) {
    details <- vapply(incompatible, function(artifact) {
      actual <- parent_indicators[[artifact]]
      missing <- setdiff(indicators, actual)
      unexpected <- setdiff(actual, indicators)
      order <- if (setequal(actual, indicators)) "different" else "n/a"
      sprintf(
        "%s: missing=[%s], unexpected=[%s], order=%s",
        artifact,
        paste(missing, collapse = ","),
        paste(unexpected, collapse = ","),
        order
      )
    }, character(1L))
    stop(
      sprintf(
        paste0(
          "Parent result indicator schema differs from the current method ",
          "configuration (%s)."
        ),
        paste(details, collapse = "; ")
      ),
      call. = FALSE
    )
  }
  seeds <- list()
  for (indicator in indicators) {
    sector_key <- wlv_native_indicator_key(indicator, "sector")
    sector_producer <- wlv_native_inherited_producer(
      resolved,
      sector_key
    )
    if (!is.null(sector_producer)) {
      value <- sector_array[, indicator, , , drop = FALSE]
      value <- array(
        value,
        dim = dim(sector_array)[c(1L, 3L, 4L)],
        dimnames = stats::setNames(
          dimnames(sector_array)[c(1L, 3L, 4L)],
          c("year", "sector", "country")
        )
      )
      seeds[[length(seeds) + 1L]] <- wlv_seed_resource(
        sector_key,
        value,
        wlv_native_indicator_contract(indicator),
        producer = sector_producer
      )
    }
    country_key <- wlv_native_indicator_key(indicator, "country")
    country_producer <- wlv_native_inherited_producer(
      resolved,
      country_key
    )
    if (!is.null(country_producer)) {
      value <- country_array[, indicator, , drop = FALSE]
      value <- array(
        value,
        dim = dim(country_array)[c(1L, 3L)],
        dimnames = stats::setNames(
          dimnames(country_array)[c(1L, 3L)],
          c("year", "country")
        )
      )
      seeds[[length(seeds) + 1L]] <- wlv_seed_resource(
        country_key,
        value,
        wlv_native_indicator_contract(indicator, level = "country"),
        producer = country_producer
      )
    }
  }
  list(seeds = seeds, sector = sector_array, country = country_array)
}

wlv_native_parent_io_seeds <- function(
    parent_result_dir,
    source_io_paths,
    partitions,
    resolved,
    dimensions) {
  result_paths <- sort(list.files(
    parent_result_dir,
    pattern = "^m_io.*[.]fst$",
    full.names = TRUE
  ))
  if (length(result_paths) != length(source_io_paths)) {
    stop("Parent result IO coverage differs from normalized source IO coverage.", call. = FALSE)
  }
  source_years <- lapply(source_io_paths, wlv_native_io_years)
  result_years <- lapply(result_paths, wlv_native_io_years)
  source_keys <- vapply(source_years, function(years) {
    paste(years, collapse = "\034")
  }, character(1L))
  result_keys <- vapply(result_years, function(years) {
    paste(years, collapse = "\034")
  }, character(1L))
  order <- match(source_keys, result_keys)
  if (anyNA(order)) {
    stop("Parent and source IO years do not correspond.", call. = FALSE)
  }
  result_paths <- result_paths[order]
  seeds <- list()
  for (index in seq_along(partitions)) {
    partition <- partitions[[index]]
    value <- read_fst_array(result_paths[[index]])
    value_dimnames <- dimnames(value)
    names(value_dimnames) <- c("year", "variable", "input", "output")
    dimnames(value) <- value_dimnames
    for (resource in dimnames(value)[[2L]]) {
      key <- paste0("io/", resource)
      producer <- wlv_native_inherited_producer(resolved, key, partition)
      if (is.null(producer)) {
        next
      }
      selected <- value[, resource, , , drop = FALSE]
      selected <- array(
        selected,
        dim = dim(value)[c(1L, 3L, 4L)],
        dimnames = stats::setNames(
          dimnames(value)[c(1L, 3L, 4L)],
          c("year", "input", "output")
        )
      )
      seeds[[length(seeds) + 1L]] <- wlv_seed_resource(
        key,
        selected,
        wlv_native_io_contract(resource),
        partition = partition,
        producer = producer
      )
    }
    years <- dimnames(value)[[1L]]
    sector_parent <- read_fst_array(
      file.path(parent_result_dir, "sea_sectors.fst")
    )
    lambda <- sector_parent[years, "value.m.mv", , , drop = FALSE]
    lambda <- array(
      lambda,
      dim = c(length(years), dimensions$nums$input),
      dimnames = list(year = years, input = dimensions$lists$input)
    )
    lambda_producer <- wlv_native_inherited_producer(
      resolved,
      "intermediate/lambda",
      partition
    )
    if (!is.null(lambda_producer)) {
      seeds[[length(seeds) + 1L]] <- wlv_seed_resource(
        "intermediate/lambda",
        lambda,
        wlv_native_intermediate_contract(
          "lambda",
          c("year", "input"),
          "io_period"
        ),
        partition = partition,
        producer = lambda_producer
      )
    }
  }
  seeds
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

wlv_native_build_store <- function(
    plan,
    method_record,
    run_data,
    registry,
    instances,
    indicators,
    unit_definitions,
    partitions) {
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
  parent <- NULL
  if (identical(plan$mode, "calculate")) {
    seeds <- c(seeds, wlv_native_capital_data_seeds(plan$root, run_data))
  } else {
    parent <- wlv_native_parent_indicator_seeds(
      run_data$parent_result_dir,
      indicators,
      resolved
    )
    seeds <- c(seeds, parent$seeds)
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
      seeds <- c(seeds, wlv_native_parent_io_seeds(
        run_data$parent_result_dir,
        run_data$source_io,
        partitions,
        resolved,
        base$dimensions
      ))
    }
  }
  list(
    store = wlv_new_resource_store(seeds),
    dimensions = base$dimensions,
    parameters = base$parameters,
    parent = parent,
    resolved = resolved
  )
}
