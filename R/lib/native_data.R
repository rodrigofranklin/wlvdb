# Native runtime data boundary ---------------------------------------------
#
# These functions turn validated, absolute artifact paths into immutable
# resources.  Scientific modules never receive paths and never read files.

wlv_native_read_semicolon <- function(
    path,
    row.names = NULL,
    encoding = "UTF-8") {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(sprintf("Required native input does not exist: `%s`.", path), call. = FALSE)
  }
  lines <- readLines(path, encoding = encoding, warn = FALSE)
  replacement <- "\uFFFD"
  mojibake_patterns <- c(
    "\u00C3[\u0080-\u00BF]",
    "\u00C2[\u0080-\u00BF]",
    "\u00E2[\u0080-\u00BF]{2}"
  )
  has_replacement <- any(grepl(replacement, lines, fixed = TRUE))
  has_mojibake <- any(vapply(mojibake_patterns, function(pattern) {
    any(grepl(pattern, lines, perl = TRUE))
  }, logical(1L)))
  if (has_replacement || has_mojibake) {
    stop(sprintf("Native input has invalid UTF-8 text: `%s`.", path), call. = FALSE)
  }
  utils::read.csv2(
    text = paste(lines, collapse = "\n"),
    row.names = row.names,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    encoding = encoding
  )
}

wlv_native_method_parameters <- function(root, method) {
  parameters <- wlv_native_read_semicolon(
    file.path(root, "methods", method, "_parameters.csv")
  )
  sectors <- wlv_native_read_semicolon(
    file.path(root, "methods", method, "_sectors.csv")
  )
  required_parameters <- c("name", "source", "description")
  if (any(!required_parameters %in% names(parameters)) || nrow(parameters) != 1L) {
    stop(sprintf("Method `%s` has invalid parameters.", method), call. = FALSE)
  }
  required_sectors <- c("sector", "sector.source", "productive")
  if (any(!required_sectors %in% names(sectors)) || !nrow(sectors)) {
    stop(sprintf("Method `%s` has invalid sectors.", method), call. = FALSE)
  }
  productive <- paste(sectors$sector[sectors$productive == 1], collapse = "; ")
  unproductive <- paste(sectors$sector[sectors$productive != 1], collapse = "; ")
  parameters$description <- paste0(
    parameters$description,
    " The following sectors are deemed as productives: ", productive,
    ". The following sectors are deemed as unproductives: ", unproductive,
    "."
  )
  list(parameters = parameters, sectors = sectors)
}

wlv_native_import_group_indices_validate <- function(indices, import_groups) {
  group_codes <- if (is.factor(import_groups)) {
    base::as.integer(import_groups)
  } else {
    integer()
  }
  canonical <- is.list(indices) && !is.data.frame(indices) &&
    is.factor(import_groups) && !anyNA(import_groups) &&
    identical(names(indices), levels(import_groups)) &&
    length(indices) == length(levels(import_groups)) &&
    sum(lengths(indices)) == length(import_groups)
  if (canonical) {
    canonical <- all(base::vapply(seq_along(indices), function(group) {
      index <- indices[[group]]
      is.integer(index) && length(index) > 0L && !anyNA(index) &&
        all(index >= 1L & index <= length(import_groups)) &&
        !is.unsorted(index, strictly = TRUE) &&
        all(group_codes[index] == group)
    }, logical(1L)))
  }
  if (!canonical) {
    stop("Import-group indices are not an exact canonical partition.",
      call. = FALSE
    )
  }
  invisible(indices)
}

wlv_native_import_group_indices <- function(filters) {
  if (!is.array(filters) || length(dim(filters)) != 3L ||
      is.null(dimnames(filters)) ||
      !"imports" %in% dimnames(filters)[[1L]]) {
    stop("Import-group indices require canonical IO filters.", call. = FALSE)
  }
  import_groups <- base::as.factor(filters["imports", , ])
  indices <- base::split(
    base::seq_along(import_groups),
    import_groups,
    drop = FALSE
  )
  wlv_native_import_group_indices_validate(indices, import_groups)
  structure(indices, class = c("wlv_import_group_indices", "list"))
}

wlv_native_dimensions <- function(source_sea, sectors, normalized_dir) {
  if (!is.array(source_sea) || length(dim(source_sea)) != 4L ||
      is.null(dimnames(source_sea)) ||
      any(vapply(dimnames(source_sea), is.null, logical(1L)))) {
    stop("Normalized SEA must be a fully labelled four-dimensional array.", call. = FALSE)
  }
  countries <- wlv_native_read_semicolon(
    file.path(normalized_dir, "countries.csv")
  )
  demands <- wlv_native_read_semicolon(file.path(normalized_dir, "demand.csv"))
  if (!"country.source" %in% names(countries) ||
      !"demand" %in% names(demands)) {
    stop("Normalized label tables have an invalid schema.", call. = FALSE)
  }
  lists <- list(
    countries = as.character(countries$country.source),
    sectors = as.character(sectors$sector.source),
    years = as.character(dimnames(source_sea)[[1L]])
  )
  nums <- list(
    countries = length(lists$countries),
    sectors = length(lists$sectors),
    years = length(lists$years)
  )
  rows <- data.frame(
    country = rep(lists$countries, each = nums$sectors),
    sector = rep(lists$sectors, times = nums$countries),
    stringsAsFactors = FALSE
  )
  rows$productive <- rep(sectors$productive, times = nums$countries)
  rows$num_country <- match(rows$country, lists$countries)
  rows$num_sector <- match(rows$sector, lists$sectors)
  rows$country_sector <- paste0(rows$country, ".", rows$sector)
  nums$countries_sectors <- nums$countries * nums$sectors
  nums$demands <- nrow(demands)
  columns <- data.frame(
    country = c(
      rows$country,
      rep(lists$countries, each = nums$demands)
    ),
    sector = c(
      rows$sector,
      rep(as.character(demands$demand), times = nums$countries)
    ),
    stringsAsFactors = FALSE
  )
  columns$num_country <- match(columns$country, lists$countries)
  columns$country_sector <- paste0(columns$country, ".", columns$sector)
  lists$input <- rows$country_sector
  lists$output <- columns$country_sector
  nums$input <- length(lists$input)
  nums$output <- length(lists$output)
  filters <- wlv_native_io_filters(lists, nums, rows, columns)
  import_group_indices <- wlv_native_import_group_indices(filters)
  list(
    lists = lists,
    nums = nums,
    rows = rows,
    columns = columns,
    countries = countries,
    demands = demands,
    io_filters = filters,
    import_group_indices = import_group_indices
  )
}

wlv_native_io_filters <- function(lists, nums, rows, columns) {
  filter_names <- c("countries", "productive_sectors", "trade", "imports")
  result <- array(
    0,
    dim = c(length(filter_names), nums$input, nums$output),
    dimnames = list(
      filter = filter_names,
      input = lists$input,
      output = lists$output
    )
  )
  country_columns <- matrix(
    rep(columns$num_country, each = nums$input),
    nrow = nums$input,
    ncol = nums$output
  )
  country_rows <- matrix(
    rep(rows$num_country, times = nums$output),
    nrow = nums$input,
    ncol = nums$output
  )
  result["countries", , ] <- country_columns + country_rows / 1000
  result["productive_sectors", rows$productive == 1, ] <- 1
  trade <- country_columns != country_rows
  result["trade", , ][trade] <- 1
  sector_rows <- matrix(
    rep(rows$num_sector, times = nums$output),
    nrow = nums$input,
    ncol = nums$output
  )
  result["imports", , ] <- country_columns + sector_rows / 1000
  result
}

wlv_native_collect_indicator_metadata <- function(
    registry,
    indicators,
    units = NULL,
    active_module_ids = names(registry$specs)) {
  if (!is.character(active_module_ids) || anyNA(active_module_ids) ||
      any(!nzchar(active_module_ids))) {
    stop("Active metadata module IDs must be non-missing strings.", call. = FALSE)
  }
  missing_modules <- setdiff(unique(active_module_ids), names(registry$specs))
  if (length(missing_modules)) {
    stop(
      sprintf(
        "Cannot collect metadata from unregistered module(s): %s.",
        paste(sort(missing_modules), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  active_specs <- registry$specs[unique(active_module_ids)]
  metadata_rows <- lapply(active_specs, function(spec) {
    attr(spec, "wlv_indicator_metadata", exact = TRUE)
  })
  metadata_rows <- Filter(Negate(is.null), metadata_rows)
  metadata <- if (length(metadata_rows)) {
    do.call(rbind, metadata_rows)
  } else {
    data.frame(
      code = character(), name = character(), description = character(),
      observation = character(), group = character(), type = character(),
      reverted = logical(), stringsAsFactors = FALSE
    )
  }
  duplicated_codes <- unique(metadata$code[duplicated(metadata$code)])
  if (length(duplicated_codes)) {
    consistent <- vapply(split(metadata, metadata$code), function(rows) {
      row.names(rows) <- NULL
      nrow(unique(rows)) == 1L
    }, logical(1L))
    if (any(!consistent)) {
      stop(
        sprintf(
          "Native indicator metadata conflicts for: %s.",
          paste(names(consistent)[!consistent], collapse = ", ")
        ),
        call. = FALSE
      )
    }
    metadata <- metadata[!duplicated(metadata$code), , drop = FALSE]
  }
  missing <- setdiff(indicators, metadata$code)
  if (length(missing)) {
    additions <- data.frame(
      code = missing,
      name = NA_character_,
      description = NA_character_,
      observation = NA_character_,
      group = NA_character_,
      type = NA_character_,
      reverted = NA,
      stringsAsFactors = FALSE
    )
    metadata <- rbind(metadata, additions)
  }
  metadata <- metadata[match(indicators, metadata$code), , drop = FALSE]
  row.names(metadata) <- metadata$code
  wlv_complete_indicator_metadata(metadata, units = units)
}

wlv_native_assumption_seeds <- function(root, source, dimensions, sectors) {
  current <- wlv_native_read_semicolon(
    file.path(root, "complementar", "worldbank", "employment_row.new.csv"),
    row.names = 1L
  )
  legacy <- wlv_native_read_semicolon(
    file.path(root, "complementar", "worldbank", "employment_row.csv"),
    row.names = 1L
  )
  china <- wlv_native_read_semicolon(
    file.path(root, "complementar", "worldbank", "employment_china.csv")
  )
  result <- list(
    wlv_seed_resource(
      "assumption/employment_row_current",
      current,
      wlv_resource_contract(scope = "run", value_type = "data.frame")
    ),
    wlv_seed_resource(
      "assumption/employment_row_legacy",
      legacy,
      wlv_resource_contract(scope = "run", value_type = "data.frame")
    ),
    wlv_seed_resource(
      "assumption/employment_china",
      china,
      wlv_resource_contract(scope = "run", value_type = "data.frame")
    )
  )
  if (identical(source, "wiodr16")) {
    hours <- wlv_read_wiodr16_china_hours_per_worker(
      file.path(root, "complementar", "wiodr16", "china_hours_per_worker.csv"),
      expected_codes = dimensions$lists$sectors,
      expected_names = as.character(sectors$sector),
      expected_years = dimensions$lists$years
    )
    dimnames(hours) <- stats::setNames(
      dimnames(hours),
      c("year", "sector")
    )
    result[[length(result) + 1L]] <- wlv_seed_resource(
      "assumption/china_hours_per_worker",
      hours,
      wlv_native_array_contract(
        scope = "run",
        axes = c("year", "sector"),
        missingness = "none"
      )
    )
  }
  result
}

wlv_native_stateful_seed_pair <- function(seed, states = NULL) {
  if (!inherits(seed, "wlv_seed_resource") || is.null(seed$key)) {
    stop("A semantic seed pair requires one keyed seed resource.", call. = FALSE)
  }
  contract <- seed$contract
  if (!identical(contract$role, "value") || !isTRUE(contract$semantic_state)) {
    stop(
      sprintf("Seed `%s` is not declared as a stateful value.", seed$key),
      call. = FALSE
    )
  }
  embedded <- attr(seed$value, "wlv_state", exact = TRUE)
  if (is.null(states) && is.null(embedded) &&
      !seed$key %in% c("source/sea", "source/io")) {
    stop(
      sprintf(
        "Stateful inherited seed `%s` lacks explicit semantic-state provenance.",
        seed$key
      ),
      call. = FALSE
    )
  }
  captured <- wlv_semantic_capture_value_state(
    value = seed$value,
    target_key = seed$key,
    axes = contract$axes,
    states = states
  )
  list(
    wlv_seed_resource(
      key = seed$key,
      value = captured$value,
      contract = contract,
      partition = seed$partition,
      producer = seed$producer
    ),
    wlv_seed_resource(
      key = wlv_semantic_state_key(seed$key),
      value = captured$state,
      contract = wlv_native_semantic_state_contract(contract),
      partition = seed$partition,
      producer = seed$producer
    )
  )
}

wlv_native_validate_seed_semantic_pairs <- function(seeds) {
  if (!is.list(seeds) || any(!vapply(
    seeds,
    inherits,
    logical(1L),
    "wlv_seed_resource"
  ))) {
    stop("Semantic seed validation requires seed resources.", call. = FALSE)
  }
  locators <- vapply(seeds, function(seed) {
    if (is.null(seed$key)) {
      stop("Semantic seed validation found an unkeyed seed.", call. = FALSE)
    }
    wlv_runtime_locator_id(seed$key, seed$partition, seed$producer)
  }, character(1L))
  if (anyDuplicated(locators)) {
    stop("Semantic seed validation found duplicate resource locators.", call. = FALSE)
  }
  by_locator <- stats::setNames(seeds, locators)
  stateful <- Filter(function(seed) {
    identical(seed$contract$role, "value") && isTRUE(seed$contract$semantic_state)
  }, seeds)
  states <- Filter(function(seed) {
    identical(seed$contract$role, "semantic_state")
  }, seeds)
  expected_state_locators <- vapply(stateful, function(seed) {
    wlv_runtime_locator_id(
      wlv_semantic_state_key(seed$key),
      seed$partition,
      seed$producer
    )
  }, character(1L))
  observed_state_locators <- vapply(states, function(seed) {
    wlv_runtime_locator_id(seed$key, seed$partition, seed$producer)
  }, character(1L))
  missing <- setdiff(expected_state_locators, observed_state_locators)
  orphan <- setdiff(observed_state_locators, expected_state_locators)
  if (length(missing) || length(orphan)) {
    stop(
      sprintf(
        "Semantic seed pairs are incomplete (missing=%s; orphan=%s).",
        paste(missing, collapse = ", "),
        paste(orphan, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  for (index in seq_along(stateful)) {
    value_seed <- stateful[[index]]
    state_seed <- by_locator[[expected_state_locators[[index]]]]
    expected_contract <- wlv_native_semantic_state_contract(
      value_seed$contract
    )
    if (!wlv_runtime_contract_same(state_seed$contract, expected_contract)) {
      stop(
        sprintf(
          "Semantic-state seed for `%s` has an incompatible contract.",
          value_seed$key
        ),
        call. = FALSE
      )
    }
    wlv_semantic_state_resource_validate(
      state_seed$value,
      value = value_seed$value,
      target_key = value_seed$key,
      axes = value_seed$contract$axes,
      state_key = state_seed$key
    )
  }
  invisible(seeds)
}

wlv_native_base_seeds <- function(
    plan,
    method_record,
    run_data,
    registry,
    instances,
    indicators,
    unit_definitions) {
  method <- method_record$method[[1L]]
  source <- method_record$source[[1L]]
  parameters <- wlv_native_method_parameters(plan$root, method)
  source_sea <- read_fst_array(run_data$source_sea)
  source_sea <- wlv_native_with_named_axes(
    source_sea,
    c("year", "variable", "sector", "country")
  )
  dimensions <- wlv_native_dimensions(
    source_sea,
    parameters$sectors,
    dirname(run_data$source_sea)
  )
  metadata <- wlv_native_collect_indicator_metadata(
    registry,
    indicators,
    units = unit_definitions,
    active_module_ids = unique(vapply(
      instances,
      function(instance) instance$module_id,
      character(1L)
    ))
  )
  source_instances <- Filter(
    function(instance) identical(instance$module_id, "source_indicator"),
    instances
  )
  if (length(source_instances)) {
    source_indicators <- vapply(source_instances, function(instance) {
      value <- instance$args$indicator
      if (!is.character(value) || length(value) != 1L || is.na(value) ||
          !nzchar(value)) {
        stop("A source indicator instance lacks its typed indicator argument.",
          call. = FALSE
        )
      }
      value
    }, character(1L))
    source_indicators <- unique(source_indicators)
    missing_source_metadata <- setdiff(source_indicators, row.names(metadata))
    if (length(missing_source_metadata)) {
      stop(
        sprintf(
          "Source indicator metadata is absent for: %s.",
          paste(sort(missing_source_metadata), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    metadata[source_indicators, "observation"] <- paste("Source:", source)
  }
  missingness_policy <- wlv_load_run_missingness_policy(plan, method_record)
  scientific_profile <- plan$scientific_profiles[[method]]
  if (!is.list(scientific_profile)) {
    stop(
      sprintf("Method `%s` lacks its explicit scientific profile.", method),
      call. = FALSE
    )
  }
  source_seeds <- wlv_native_stateful_seed_pair(wlv_seed_resource(
    "source/sea",
    source_sea,
    wlv_native_source_sea_contract()
  ))
  seeds <- c(list(
    wlv_seed_resource(
      "request/method",
      method,
      wlv_native_control_contract("character")
    ),
    wlv_seed_resource(
      "request/source",
      source,
      wlv_native_control_contract("character")
    ),
    wlv_seed_resource(
      "configuration/missingness_policy",
      missingness_policy,
      wlv_native_control_contract("list")
    ),
    wlv_seed_resource(
      "configuration/scientific_profile",
      scientific_profile,
      wlv_native_control_contract("list")
    ),
    wlv_seed_resource(
      "configuration/parameters",
      parameters$parameters,
      wlv_resource_contract(scope = "run", value_type = "data.frame")
    ),
    wlv_seed_resource(
      "configuration/sectors",
      parameters$sectors,
      wlv_resource_contract(scope = "run", value_type = "data.frame")
    ),
    wlv_seed_resource(
      "dimensions/lists",
      dimensions$lists,
      wlv_resource_contract(scope = "run", value_type = "list")
    ),
    wlv_seed_resource(
      "dimensions/nums",
      dimensions$nums,
      wlv_resource_contract(scope = "run", value_type = "list")
    ),
    wlv_seed_resource(
      "dimensions/rows",
      dimensions$rows,
      wlv_resource_contract(scope = "run", value_type = "data.frame")
    ),
    wlv_seed_resource(
      "dimensions/columns",
      dimensions$columns,
      wlv_resource_contract(scope = "run", value_type = "data.frame")
    ),
    wlv_seed_resource(
      "dimensions/io_filters",
      dimensions$io_filters,
      wlv_native_filters_contract()
    ),
    wlv_seed_resource(
      "dimensions/import_group_indices",
      dimensions$import_group_indices,
      wlv_native_control_contract("list")
    ),
    wlv_seed_resource(
      "labels/countries",
      dimensions$countries,
      wlv_resource_contract(scope = "run", value_type = "data.frame")
    ),
    wlv_seed_resource(
      "labels/demands",
      dimensions$demands,
      wlv_resource_contract(scope = "run", value_type = "data.frame")
    )
  ), source_seeds, list(
    wlv_seed_resource(
      "metadata/indicators",
      metadata,
      wlv_native_indicator_metadata_contract()
    )
  ))
  seeds <- c(
    seeds,
    wlv_native_assumption_seeds(
      plan$root,
      source,
      dimensions,
      parameters$sectors
    )
  )
  wlv_native_validate_seed_semantic_pairs(seeds)
  list(
    seeds = seeds,
    dimensions = dimensions,
    parameters = parameters,
    metadata = metadata
  )
}

wlv_native_io_seed <- function(path, partition) {
  value <- read_fst_array(path)
  value <- wlv_native_with_named_axes(value, c("year", "input", "output"))
  wlv_native_stateful_seed_pair(wlv_seed_resource(
    "source/io",
    value,
    wlv_native_source_io_contract(),
    partition = partition
  ))
}

wlv_native_io_years <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(sprintf("Input-output artifact does not exist: `%s`.", path), call. = FALSE)
  }
  metadata_path <- paste0(path, ".meta")
  metadata <- tryCatch(
    readRDS(metadata_path),
    error = function(error) {
      stop(
        sprintf(
          "Cannot read input-output metadata `%s`: %s",
          metadata_path,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  years <- metadata[[2L]]
  if (is.null(years) || !length(years) || anyNA(years) || anyDuplicated(years)) {
    stop(
      sprintf("Input-output metadata `%s` does not declare unique years.", metadata_path),
      call. = FALSE
    )
  }
  as.character(years)
}

wlv_native_io_partition <- function(path) {
  years <- wlv_native_io_years(path)
  if (!length(years) || anyNA(years) || anyDuplicated(years)) {
    stop(sprintf("Input-output artifact `%s` has invalid years.", path), call. = FALSE)
  }
  paste0(min(years), "-", max(years))
}

wlv_native_source_io_seeds <- function(paths) {
  partitions <- vapply(paths, wlv_native_io_partition, character(1L))
  if (anyDuplicated(partitions)) {
    stop("Normalized input-output artifacts have duplicate periods.", call. = FALSE)
  }
  grouped <- Map(wlv_native_io_seed, paths, partitions)
  seeds <- unlist(grouped, recursive = FALSE, use.names = FALSE)
  wlv_native_validate_seed_semantic_pairs(seeds)
  seeds
}

wlv_native_read_euklems_tables <- function(root, prefix) {
  directory <- file.path(root, "source_data", "euklems")
  paths <- sort(list.files(
    directory,
    pattern = paste0("^", prefix, "_[0-9]{4}[.]fst$"),
    full.names = TRUE
  ))
  if (!length(paths)) {
    stop(sprintf("No EU KLEMS `%s` tables are available.", prefix), call. = FALSE)
  }
  years <- sub(
    paste0("^", prefix, "_([0-9]{4})[.]fst$"),
    "\\1",
    basename(paths)
  )
  values <- lapply(paths, function(path) {
    value <- fst::read_fst(path, as.data.table = FALSE)
    if (!is.data.frame(value)) {
      stop(sprintf("EU KLEMS table `%s` is invalid.", path), call. = FALSE)
    }
    value
  })
  stats::setNames(values, years)
}

wlv_native_capital_data_seeds <- function(root, run_data) {
  observations <- if (is.null(run_data$gfcf_observations)) {
    data.frame()
  } else if (is.character(run_data$gfcf_observations)) {
    readRDS(run_data$gfcf_observations)
  } else {
    run_data$gfcf_observations
  }
  if (!is.data.frame(observations)) {
    stop("Canonical GFCF observations must be a data frame.", call. = FALSE)
  }
  list(
    wlv_seed_resource(
      "source/euklems/capital_weights",
      wlv_native_read_euklems_tables(root, "ekk"),
      wlv_native_euklems_table_list_contract("capital_weights")
    ),
    wlv_seed_resource(
      "source/euklems/depreciation_rates",
      wlv_native_read_euklems_tables(root, "ekdeprate"),
      wlv_native_euklems_table_list_contract("depreciation_rates")
    ),
    wlv_seed_resource(
      "source/gfcf_observations",
      observations,
      wlv_native_gfcf_observations_contract()
    )
  )
}
