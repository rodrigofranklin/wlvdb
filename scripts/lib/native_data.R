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

# Constrói a ordem canônica de leitura: setores variam dentro de cada país;
# input combina país.setor e output acrescenta demandas finais após indústrias.
# Essa ordem dá significado econômico a rep(), array() e newDim(): mudar rótulos
# sem permutar números troca fornecedores e compradores silenciosamente.
# Guias: docs/guide-pt.md e docs/guide-en.md.
wlv_native_dimensions_from_years <- function(
    years,
    sectors,
    normalized_dir,
    required_keys = NULL) {
  years <- as.character(years)
  if (!length(years) || anyNA(years) || any(!nzchar(years)) ||
      anyDuplicated(years)) {
    stop("Normalized SEA years must be non-missing and unique.", call. = FALSE)
  }
  if (is.null(required_keys)) {
    required_keys <- c(
      "dimensions/io_filters",
      "dimensions/import_group_indices"
    )
  } else if (!is.character(required_keys) || anyNA(required_keys) ||
      any(!nzchar(required_keys)) || anyDuplicated(required_keys)) {
    stop("Required dimension keys must be unique non-empty strings.",
      call. = FALSE
    )
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
    years = years
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
  filters_required <- any(c(
    "dimensions/io_filters",
    "dimensions/import_group_indices"
  ) %in% required_keys)
  filters_working <- if (filters_required) {
    wlv_native_io_filters(lists, nums, rows, columns)
  } else {
    NULL
  }
  filters <- if ("dimensions/io_filters" %in% required_keys) {
    filters_working
  } else {
    NULL
  }
  import_group_indices <- if (
    "dimensions/import_group_indices" %in% required_keys
  ) {
    wlv_native_import_group_indices(filters_working)
  } else {
    NULL
  }
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

wlv_native_dimensions <- function(source_sea, sectors, normalized_dir) {
  if (!is.array(source_sea) || length(dim(source_sea)) != 4L ||
      is.null(dimnames(source_sea)) ||
      any(vapply(dimnames(source_sea), is.null, logical(1L)))) {
    stop("Normalized SEA must be a fully labelled four-dimensional array.", call. = FALSE)
  }
  wlv_native_dimensions_from_years(
    dimnames(source_sea)[[1L]],
    sectors,
    normalized_dir
  )
}

wlv_native_instance_required_keys <- function(registry, instances) {
  keys <- as.character(unique(unlist(lapply(instances, function(instance) {
    spec <- wlv_registry_module(registry, instance$module_id)
    args <- wlv_runtime_resolve_arguments(spec, instance)
    requires <- wlv_runtime_resolve_contract_list(
      spec$requires,
      args,
      "requires",
      "wlv_resource_ref",
      instance
    )
    vapply(requires, function(ref) ref$key, character(1L))
  }), use.names = FALSE)))
  if (anyNA(keys) || any(!nzchar(keys))) {
    stop("Native instances resolved invalid required resource keys.",
      call. = FALSE
    )
  }
  keys
}

wlv_native_instances_require_resource <- function(registry, instances, key) {
  if (!is.character(key) || length(key) != 1L || is.na(key) || !nzchar(key)) {
    stop("Required native resource key must be one non-empty string.",
      call. = FALSE
    )
  }
  key %in% wlv_native_instance_required_keys(registry, instances)
}

# Máscaras não são fluxos econômicos: trade separa países, productive_sectors
# aplica a classificação metodológica e countries/imports codificam grupos.
# A parte decimal identifica um grupo de setor/país; não é uma proporção de valor.
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

wlv_native_assumption_seeds <- function(
    root,
    source,
    dimensions,
    sectors,
    required_keys = NULL) {
  available <- c(
    "assumption/employment_row_current",
    "assumption/employment_row_legacy",
    "assumption/employment_china",
    if (identical(source, "wiodr16")) {
      "assumption/china_hours_per_worker"
    }
  )
  if (is.null(required_keys)) {
    required_keys <- available
  } else if (!is.character(required_keys) || anyNA(required_keys) ||
      any(!nzchar(required_keys)) || anyDuplicated(required_keys)) {
    stop("Required assumption keys must be unique non-empty strings.",
      call. = FALSE
    )
  }
  requested <- required_keys[startsWith(required_keys, "assumption/")]
  unavailable <- setdiff(requested, available)
  if (length(unavailable)) {
    stop(
      sprintf(
        "Native instances require unavailable assumptions: %s.",
        paste(sort(unavailable), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (!length(requested)) return(list())

  result <- list()
  add_data_frame <- function(key, path, row.names = NULL) {
    value <- wlv_native_read_semicolon(path, row.names = row.names)
    result[[length(result) + 1L]] <<- wlv_seed_resource(
      key,
      value,
      wlv_resource_contract(scope = "run", value_type = "data.frame")
    )
  }
  if ("assumption/employment_row_current" %in% requested) {
    add_data_frame(
      "assumption/employment_row_current",
      file.path(root, "complementar", "worldbank", "employment_row.new.csv"),
      row.names = 1L
    )
  }
  if ("assumption/employment_row_legacy" %in% requested) {
    add_data_frame(
      "assumption/employment_row_legacy",
      file.path(root, "complementar", "worldbank", "employment_row.csv"),
      row.names = 1L
    )
  }
  if ("assumption/employment_china" %in% requested) {
    add_data_frame(
      "assumption/employment_china",
      file.path(root, "complementar", "worldbank", "employment_china.csv")
    )
  }
  if ("assumption/china_hours_per_worker" %in% requested) {
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

# Fronteira entre arquivos autenticados e recursos do cálculo. Aqui os dados
# ganham eixos, unidades e estados semânticos explícitos; os módulos recebem
# valores prontos via ctx$input, sem abrir caminhos ou alterar a fonte.
# O conjunto solicitado depende do grafo, inclusive no recálculo parcial.
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
  required_keys <- wlv_native_instance_required_keys(registry, instances)
  source_instances <- Filter(
    function(instance) identical(instance$module_id, "source_indicator"),
    instances
  )
  source_sea_required <- "source/sea" %in% required_keys
  source_sea <- if (isTRUE(source_sea_required)) {
    value <- read_fst_array(run_data$source_sea)
    wlv_native_with_named_axes(
      value,
      c("year", "variable", "sector", "country")
    )
  } else {
    NULL
  }
  source_years <- if (is.null(source_sea)) {
    wlv_native_metadata_years(run_data$source_sea)
  } else {
    dimnames(source_sea)[[1L]]
  }
  dimensions <- wlv_native_dimensions_from_years(
    source_years,
    parameters$sectors,
    dirname(run_data$source_sea),
    required_keys = required_keys
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
  source_seeds <- if (is.null(source_sea)) {
    list()
  } else {
    wlv_native_stateful_seed_pair(wlv_seed_resource(
      "source/sea",
      source_sea,
      wlv_native_source_sea_contract()
    ))
  }
  dimension_values <- list(
    "dimensions/lists" = dimensions$lists,
    "dimensions/nums" = dimensions$nums,
    "dimensions/rows" = dimensions$rows,
    "dimensions/columns" = dimensions$columns,
    "dimensions/io_filters" = dimensions$io_filters,
    "dimensions/import_group_indices" = dimensions$import_group_indices,
    "labels/countries" = dimensions$countries,
    "labels/demands" = dimensions$demands
  )
  dimension_contracts <- list(
    "dimensions/lists" = wlv_resource_contract(
      scope = "run", value_type = "list"
    ),
    "dimensions/nums" = wlv_resource_contract(
      scope = "run", value_type = "list"
    ),
    "dimensions/rows" = wlv_resource_contract(
      scope = "run", value_type = "data.frame"
    ),
    "dimensions/columns" = wlv_resource_contract(
      scope = "run", value_type = "data.frame"
    ),
    "dimensions/io_filters" = wlv_native_filters_contract(),
    "dimensions/import_group_indices" = wlv_native_control_contract("list"),
    "labels/countries" = wlv_resource_contract(
      scope = "run", value_type = "data.frame"
    ),
    "labels/demands" = wlv_resource_contract(
      scope = "run", value_type = "data.frame"
    )
  )
  dimension_keys <- names(dimension_values)[
    names(dimension_values) %in% required_keys
  ]
  dimension_seeds <- lapply(dimension_keys, function(key) {
    wlv_seed_resource(
      key,
      dimension_values[[key]],
      dimension_contracts[[key]]
    )
  })

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
    )
  ), dimension_seeds, source_seeds, list(
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
      parameters$sectors,
      required_keys = required_keys
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
