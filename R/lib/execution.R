wlv_validate_workers <- function(workers) {
  if (
    length(workers) != 1L ||
    !is.numeric(workers) ||
    is.na(workers) ||
    !is.finite(workers) ||
    workers < 1 ||
    workers != floor(workers) ||
    workers > .Machine$integer.max
  ) {
    stop("`workers` must be one positive integer.", call. = FALSE)
  }

  as.integer(workers)
}

wlv_validate_flag <- function(value, name) {
  if (length(value) != 1L || !is.logical(value) || is.na(value)) {
    stop(sprintf("`%s` must be TRUE or FALSE.", name), call. = FALSE)
  }
  value
}

wlv_validate_integer <- function(value, name, minimum = 0L, maximum = Inf) {
  if (
    length(value) != 1L ||
    !is.numeric(value) ||
    is.na(value) ||
    !is.finite(value) ||
    value != floor(value) ||
    value > .Machine$integer.max ||
    value < minimum ||
    value > maximum
  ) {
    stop(
      sprintf("`%s` must be one integer between %s and %s.", name, minimum, maximum),
      call. = FALSE
    )
  }
  as.integer(value)
}

wlv_safe_name <- function(value) {
  is.character(value) &&
    length(value) == 1L &&
    !is.na(value) &&
    grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", value)
}

wlv_validate_requested_operations <- function(
    requested_operations,
    mode,
    repeat_pp) {
  if (is.null(requested_operations)) {
    requested_operations <- if (mode == "recalculate") {
      "recalculate"
    } else {
      c(if (repeat_pp) "prepare", "calculate")
    }
  }
  if (
    !is.character(requested_operations) ||
    !length(requested_operations) ||
    anyNA(requested_operations)
  ) {
    stop(
      "`requested_operations` must be a non-empty character vector without NA.",
      call. = FALSE
    )
  }
  requested_operations <- unique(requested_operations)
  allowed <- c("prepare", "calculate", "recalculate")
  invalid <- setdiff(requested_operations, allowed)
  if (length(invalid)) {
    stop(
      sprintf(
        "Invalid requested operation(s): %s.",
        paste(invalid, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (
    (mode == "recalculate" && !identical(requested_operations, "recalculate")) ||
    (mode == "calculate" && "recalculate" %in% requested_operations)
  ) {
    stop(
      sprintf(
        "Requested operations are incompatible with `%s` mode: %s.",
        mode,
        paste(requested_operations, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  requested_operations
}

wlv_assert_catalog_access <- function(
    methods,
    requested_operations,
    allow_experimental) {
  for (index in seq_len(nrow(methods))) {
    method <- methods[index, , drop = FALSE]
    limitation <- method$limitations[[1L]]
    detail <- if (nzchar(limitation)) paste0(" ", limitation) else ""

    if (method$source_status[[1L]] == "disabled") {
      stop(
        sprintf(
          "Source `%s` used by method `%s` is disabled.",
          method$source[[1L]],
          method$method[[1L]]
        ),
        call. = FALSE
      )
    }
    if (method$status[[1L]] == "disabled") {
      stop(
        sprintf("Method `%s` is disabled.%s", method$method[[1L]], detail),
        call. = FALSE
      )
    }
    if (method$status[[1L]] == "experimental" && !allow_experimental) {
      stop(
        sprintf(
          paste0(
            "Method `%s` is experimental.%s ",
            "Set `allow_experimental = TRUE` (CLI: `--allow-experimental`) ",
            "to opt in explicitly."
          ),
          method$method[[1L]],
          detail
        ),
        call. = FALSE
      )
    }

    capabilities <- c(
      prepare = method$can_prepare[[1L]],
      calculate = method$can_calculate[[1L]],
      recalculate = method$can_recalculate[[1L]]
    )
    unavailable <- requested_operations[!capabilities[requested_operations]]
    if (length(unavailable)) {
      stop(
        sprintf(
          "Method `%s` does not support operation(s): %s.",
          method$method[[1L]],
          paste(unavailable, collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }
  invisible(methods)
}

wlv_validate_method_references <- function(root, method, source, mode) {
  mode <- match.arg(mode, c("calculate", "recalculate"))
  configuration <- wlv_resolve_module_config(root, method, source)
  registry <- wlv_native_registry()
  wlv_native_assert_registry_covers_config(registry, configuration)
  configuration
}

wlv_validate_recalculation_selection <- function(
    configuration,
    at_stage,
    sea_vars,
    indicators = NULL) {
  if (is.null(sea_vars)) {
    return(invisible(NULL))
  }

  for (method in names(configuration)) {
    available <- if (is.null(indicators)) {
      character()
    } else {
      indicators[[method]]
    }
    unknown <- setdiff(sea_vars, available)
    if (length(unknown)) {
      stop(
        sprintf(
          "Unknown `sea_vars` for method `%s`: %s.",
          method,
          paste(unknown, collapse = ", ")
        ),
        call. = FALSE
      )
    }

  }

  invisible(sea_vars)
}

wlv_validate_release_channel <- function(value) {
  if (exists(
    "wlv_publication_validate_channel",
    mode = "function",
    inherits = TRUE
  )) {
    return(wlv_publication_validate_channel(value))
  }
  valid_scalar <- is.character(value) && length(value) == 1L &&
    !is.na(value) && nzchar(value)
  segments <- if (valid_scalar) {
    strsplit(value, "/", fixed = TRUE)[[1L]]
  } else {
    character()
  }
  if (
    !valid_scalar ||
    nchar(value, type = "chars") > 128L ||
    any(!grepl(
      "^[a-z0-9](?:[a-z0-9._-]*[a-z0-9_-])?$",
      segments,
      perl = TRUE
    ))
  ) {
    stop(
      "`channel` must be a normalized lowercase release-channel identifier.",
      call. = FALSE
    )
  }
  value
}

wlv_assert_loaded_runtime_unchanged <- function() {
  paths <- .wlv_runtime_definition_paths
  expected <- .wlv_runtime_definition_md5
  if (
    !is.character(paths) || !length(paths) || is.null(names(paths)) ||
      !is.character(expected) || !identical(names(expected), names(paths)) ||
      anyNA(paths) || anyNA(expected) || any(!file.exists(paths))
  ) {
    stop("The loaded runtime lacks a valid definition inventory.", call. = FALSE)
  }
  capture <- function() {
    hashes <- unname(tools::md5sum(unname(paths)))
    stats::setNames(hashes, names(paths))
  }
  current <- capture()
  if (!identical(expected, current) || !identical(current, capture())) {
    changed <- names(paths)[vapply(names(paths), function(path) {
      !identical(expected[[path]], current[[path]])
    }, logical(1L))]
    stop(
      sprintf(
        "Runtime definitions changed after bootstrap: %s.",
        paste(changed, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_validate_request <- function(
    methods,
    repeat_pp = FALSE,
    papern = 0L,
    prepaper = FALSE,
    workers = 1L,
    channel = "stable",
    mode = c("calculate", "recalculate"),
    at_stage = 1L,
    sea_vars = NULL,
    root = ".",
    allow_experimental = FALSE,
    requested_operations = NULL,
    catalog = NULL) {
  wlv_assert_loaded_runtime_unchanged()
  mode <- match.arg(mode)
  repeat_pp <- wlv_validate_flag(repeat_pp, "repeat_pp")
  prepaper <- wlv_validate_flag(prepaper, "prepaper")
  allow_experimental <- wlv_validate_flag(
    allow_experimental,
    "allow_experimental"
  )
  workers <- wlv_validate_workers(workers)
  channel <- wlv_validate_release_channel(channel)
  papern <- wlv_validate_integer(papern, "papern", minimum = 0L)
  requested_operations <- wlv_validate_requested_operations(
    requested_operations,
    mode = mode,
    repeat_pp = repeat_pp
  )

  if (!is.character(methods) || !length(methods) || anyNA(methods)) {
    stop("`methods` must be a non-empty character vector.", call. = FALSE)
  }
  methods <- unique(methods)
  unsafe <- methods[!vapply(methods, wlv_safe_name, logical(1))]
  if (length(unsafe)) {
    stop(
      sprintf("Invalid method name: %s", paste(unsafe, collapse = ", ")),
      call. = FALSE
    )
  }

  if (mode == "recalculate") {
    at_stage <- wlv_validate_integer(at_stage, "at_stage", minimum = 1L, maximum = 5L)
    if (!at_stage %in% c(1L, 4L, 5L)) {
      stop(
        "`at_stage` must be one of the implemented checkpoints: 1, 4, or 5.",
        call. = FALSE
      )
    }
    if (!is.null(sea_vars) &&
        (!is.character(sea_vars) || !length(sea_vars) || anyNA(sea_vars) ||
          any(!nzchar(sea_vars)))) {
      stop(
        paste0(
          "`sea_vars` must be NULL or a non-empty character vector ",
          "without NA or empty values."
        ),
        call. = FALSE
      )
    }
    if (at_stage == 1L && !is.null(sea_vars)) {
      stop(
        paste0(
          "Selective `sea_vars` recalculation is unsafe at stage 1 because ",
          "structural assumptions update multiple dependent indicators."
        ),
        call. = FALSE
      )
    }
    sea_vars <- unique(sea_vars)
  }

  root <- normalizePath(root, mustWork = TRUE)
  if (is.null(catalog)) {
    catalog <- wlv_load_catalog(root)
  } else {
    wlv_catalog_assert(catalog)
    if (!identical(normalizePath(catalog$root, mustWork = TRUE), root)) {
      stop("`catalog` belongs to a different project root.", call. = FALSE)
    }
  }
  wlv_catalog_assert_inputs_unchanged(catalog)
  catalog_methods <- wlv_catalog_method_table(catalog)
  unknown <- setdiff(methods, catalog_methods$method)
  if (length(unknown)) {
    stop(
      sprintf("Unknown method: %s", paste(unknown, collapse = ", ")),
      call. = FALSE
    )
  }
  selected_methods <- catalog_methods[
    match(methods, catalog_methods$method),
    ,
    drop = FALSE
  ]
  wlv_assert_catalog_access(
    selected_methods,
    requested_operations = requested_operations,
    allow_experimental = allow_experimental
  )

  rows <- lapply(seq_len(nrow(selected_methods)), function(index) {
    selected <- selected_methods[index, , drop = FALSE]
    method <- selected$method[[1L]]
    source_record <- wlv_catalog_source(catalog, selected$source[[1L]])
    method_dir <- file.path(root, "methods", method)
    parameter_file <- file.path(method_dir, "_parameters.csv")
    sectors_file <- file.path(method_dir, "_sectors.csv")
    required <- c(method_dir, parameter_file, sectors_file)
    missing <- required[!file.exists(required)]
    if (length(missing)) {
      stop(
        sprintf(
          "Method `%s` is incomplete; missing: %s",
          method,
          paste(missing, collapse = ", ")
        ),
        call. = FALSE
      )
    }

    parameters <- tryCatch(
      wlv_native_read_semicolon(parameter_file),
      error = function(error) {
        stop(
          sprintf("Cannot read parameters for method `%s`: %s", method, conditionMessage(error)),
          call. = FALSE
        )
      }
    )
    declared_sources <- unique(parameters$source)
    declared_sources <- declared_sources[
      !is.na(declared_sources) & nzchar(declared_sources)
    ]
    parameter_set <- source_record$parameter_set[[1L]]
    if (
      length(declared_sources) != 1L ||
      !identical(declared_sources[[1L]], parameter_set)
    ) {
      stop(
        sprintf(
          "Method `%s` must declare catalog parameter set `%s`.",
          method,
          parameter_set
        ),
        call. = FALSE
      )
    }
    data.frame(
      method = method,
      source = source_record$source[[1L]],
      year_start = source_record$year_start[[1L]],
      year_end = source_record$year_end[[1L]],
      parameter_set = parameter_set,
      method_dir = method_dir,
      source_dir = file.path(root, source_record$data_dir[[1L]]),
      parameter_file = parameter_file,
      sectors_file = sectors_file,
      validator_script = source_record$validator_script[[1L]],
      validator_function = source_record$validator_function[[1L]],
      artifact_profile = source_record$artifact_profile[[1L]],
      missingness_policy = source_record$missingness_policy[[1L]],
      unit_contract = source_record$unit_contract[[1L]],
      status = selected$status[[1L]],
      source_status = selected$source_status[[1L]],
      can_prepare = selected$can_prepare[[1L]],
      can_calculate = selected$can_calculate[[1L]],
      can_recalculate = selected$can_recalculate[[1L]],
      stringsAsFactors = FALSE
    )
  })
  method_plan <- do.call(rbind, rows)
  rownames(method_plan) <- NULL
  configuration <- lapply(seq_len(nrow(method_plan)), function(index) {
    wlv_validate_method_references(
      root = root,
      method = method_plan$method[[index]],
      source = method_plan$source[[index]],
      mode = mode
    )
  })
  names(configuration) <- method_plan$method
  native_registry <- wlv_native_registry()
  unit_definitions <- lapply(seq_len(nrow(method_plan)), function(index) {
    wlv_catalog_unit_contract(
      catalog,
      method_plan$unit_contract[[index]]
    )$units
  })
  names(unit_definitions) <- method_plan$method
  aggregation_registries <- lapply(method_plan$method, function(method) {
    wlv_native_aggregation_registry(
      root = root,
      catalog = catalog,
      method = method
    )
  })
  names(aggregation_registries) <- method_plan$method
  indicators <- lapply(method_plan$method, function(method) {
    wlv_native_output_indicators(
      root,
      catalog,
      method,
      aggregation_registries[[method]]
    )
  })
  names(indicators) <- method_plan$method
  scientific_profiles <- wlv_validate_native_scientific_profiles(
    root,
    catalog,
    indicators
  )
  if (mode == "recalculate") {
    wlv_validate_recalculation_selection(
      configuration,
      at_stage = at_stage,
      sea_vars = sea_vars,
      indicators = indicators
    )
  }
  paper_task <- wlv_validate_paper_request(papern, prepaper)
  wlv_validate_paper_method_compatibility(
    paper_task,
    prepaper = prepaper,
    methods = method_plan,
    indicators = indicators
  )
  wlv_catalog_assert_inputs_unchanged(catalog)

  plan <- structure(
    list(
      root = root,
      mode = mode,
      requested_operations = requested_operations,
      allow_experimental = allow_experimental,
      catalog = catalog,
      native_registry = native_registry,
      methods = method_plan,
      configuration = configuration,
      unit_definitions = unit_definitions,
      indicators = indicators,
      scientific_profiles = scientific_profiles,
      aggregation_registries = aggregation_registries,
      method_names = method_plan$method,
      repeat_pp = repeat_pp,
      papern = papern,
      prepaper = prepaper,
      paper_task = paper_task,
      workers = workers,
      channel = channel,
      at_stage = at_stage,
      sea_vars = sea_vars
    ),
    class = c("wlv_run_plan", "list")
  )
  plan$publication_inputs <- wlv_capture_plan_publication_inputs(plan)
  wlv_catalog_assert_inputs_unchanged(catalog)
  for (method in plan$method_names) {
    wlv_assert_plan_scientific_profile_inventory(plan, method)
  }
  plan
}

wlv_assert_plan_scientific_profile_inventory <- function(plan, method) {
  if (!inherits(plan, "wlv_run_plan") ||
      !is.character(method) || length(method) != 1L || is.na(method) ||
      !method %in% plan$method_names) {
    stop("Scientific profile verification received an invalid run plan/method.",
      call. = FALSE
    )
  }
  wlv_assert_plan_publication_inputs_unchanged(plan, method)
  wlv_catalog_assert_inputs_unchanged(plan$catalog)
  snapshot_root <- wlv_authenticated_scientific_snapshot(plan, method)
  on.exit(unlink(snapshot_root, recursive = TRUE, force = TRUE), add = TRUE)
  expected <- wlv_native_scientific_profile(
    snapshot_root,
    plan$catalog,
    method,
    plan$indicators[[method]]
  )
  wlv_catalog_assert_inputs_unchanged(plan$catalog)
  wlv_assert_plan_publication_inputs_unchanged(plan, method)
  observed <- plan$scientific_profiles[[method]]
  if (!identical(observed, expected)) {
    stop(sprintf(
      paste0(
        "Run plan scientific profile for method `%s` no longer matches ",
        "the authenticated contract inventory."
      ),
      method
    ), call. = FALSE)
  }
  invisible(observed)
}

wlv_authenticated_scientific_snapshot <- function(plan, method) {
  inventory <- wlv_plan_publication_input_inventory(plan, method)
  relative <- vapply(inventory, `[[`, character(1L), "path")
  selected <- startsWith(relative, "config/")
  inventory <- inventory[selected]
  relative <- relative[selected]
  if (!length(inventory) || anyDuplicated(relative)) {
    stop("Authenticated scientific configuration inventory is incomplete.",
      call. = FALSE
    )
  }
  snapshot_root <- tempfile("wlv-scientific-snapshot-")
  dir.create(snapshot_root, recursive = TRUE)
  complete <- FALSE
  on.exit({
    if (!complete) unlink(snapshot_root, recursive = TRUE, force = TRUE)
  }, add = TRUE)
  for (index in seq_along(inventory)) {
    source <- file.path(plan$root, relative[[index]])
    destination <- file.path(snapshot_root, relative[[index]])
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    copied <- file.copy(source, destination, overwrite = FALSE, copy.mode = TRUE)
    observed <- if (isTRUE(copied)) {
      wlv_publication_file_sha256(destination)
    } else {
      NA_character_
    }
    if (!identical(observed, inventory[[index]]$sha256)) {
      stop(sprintf(
        "Authenticated scientific input changed while snapshotting `%s`.",
        relative[[index]]
      ), call. = FALSE)
    }
  }
  complete <- TRUE
  normalizePath(snapshot_root, winslash = "/", mustWork = TRUE)
}

wlv_require_files <- function(paths, context) {
  missing <- paths[!file.exists(paths)]
  if (length(missing)) {
    stop(
      sprintf("Missing %s file(s): %s", context, paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(paths)
}

wlv_list_io_files <- function(path) {
  sort(list.files(path, pattern = "^m_io.*\\.fst$", full.names = TRUE))
}

wlv_load_catalog_validator <- function(plan, method) {
  script <- method$validator_script[[1L]]
  function_name <- method$validator_function[[1L]]
  if (!nzchar(script) || !nzchar(function_name)) {
    stop(
      sprintf(
        "Source `%s` has no catalog-declared validator.",
        method$source[[1L]]
      ),
      call. = FALSE
    )
  }

  registry <- list(
    wiodr13 = list(
      script = "R/lib/wiodr13_validation.R",
      function_name = "wlv_validate_wiodr13_prepared",
      validate = wlv_validate_wiodr13_prepared,
      validate_euklems = wlv_validate_wiodr13_euklems
    ),
    wiodr16 = list(
      script = "R/lib/wiodr16_validation.R",
      function_name = "wlv_validate_wiodr16_prepared",
      validate = wlv_validate_wiodr16_prepared,
      validate_euklems = wlv_validate_wiodr16_euklems
    )
  )
  source <- method$source[[1L]]
  entry <- registry[[source]]
  if (is.null(entry) || !identical(script, entry$script) ||
      !identical(function_name, entry$function_name)) {
    stop(
      sprintf(
        "Source `%s` does not match the explicit native validator registry.",
        source
      ),
      call. = FALSE
    )
  }
  entry
}

wlv_resolve_source_artifacts <- function(plan, method, needs_io) {
  profile <- method$artifact_profile[[1L]]
  if (!nzchar(profile)) {
    stop(
      sprintf(
        "Source `%s` has no artifact profile for method `%s`.",
        method$source[[1L]],
        method$method[[1L]]
      ),
      call. = FALSE
    )
  }

  specifications <- lapply(plan$requested_operations, function(operation) {
    value <- wlv_catalog_artifacts(
      plan$catalog,
      profile,
      operation = operation
    )
    if (!nrow(value)) {
      stop(
        sprintf(
          "Artifact profile `%s` declares no artifacts for operation `%s`.",
          profile,
          operation
        ),
        call. = FALSE
      )
    }
    value
  })
  specifications <- do.call(rbind, specifications)
  specification_keys <- paste(
    specifications$profile,
    specifications$artifact,
    sep = "/"
  )
  specifications <- specifications[
    !duplicated(specification_keys),
    ,
    drop = FALSE
  ]

  required <- character()
  input_output <- character()
  socioeconomic <- character()
  manifest <- character()
  for (index in seq_len(nrow(specifications))) {
    specification <- specifications[index, , drop = FALSE]
    artifact_name <- basename(specification$artifact[[1L]])
    is_input_output <- startsWith(artifact_name, "m_io")

    artifact_path <- file.path(
      method$source_dir[[1L]],
      specification$artifact[[1L]]
    )
    paths <- if (specification$kind[[1L]] == "fst_array_glob") {
      sort(Sys.glob(artifact_path))
    } else {
      artifact_path
    }
    if (!length(paths)) {
      stop(
        sprintf(
          "Missing source data for method `%s` matching artifact `%s`.",
          method$method[[1L]],
          specification$artifact[[1L]]
        ),
        call. = FALSE
      )
    }

    required <- c(required, paths)
    if (specification$sidecar[[1L]]) {
      required <- c(required, paste0(paths, ".meta"))
    }
    if (is_input_output) {
      input_output <- c(input_output, paths)
    }
    if (identical(artifact_name, "sea.fst")) {
      socioeconomic <- c(socioeconomic, paths)
    }
    if (identical(artifact_name, "_source_manifest.csv")) {
      manifest <- c(manifest, paths)
    }
  }

  wlv_require_files(
    unique(required),
    sprintf("catalog-declared source data for method `%s`", method$method[[1L]])
  )
  if (length(socioeconomic) != 1L || length(manifest) != 1L) {
    stop(
      sprintf(
        "Artifact profile `%s` must resolve one SEA array and one source manifest.",
        profile
      ),
      call. = FALSE
    )
  }
  list(
    required = unique(required),
    input_output = sort(unique(input_output)),
    socioeconomic = socioeconomic[[1L]],
    manifest = manifest[[1L]]
  )
}

wlv_method_unit_contract_paths <- function(plan, method) {
  contract_id <- method$unit_contract[[1L]]
  if (!nzchar(contract_id)) {
    stop(
      sprintf("Source `%s` does not declare a unit contract.", method$source[[1L]]),
      call. = FALSE
    )
  }
  contract <- wlv_catalog_unit_contract(plan$catalog, contract_id)
  metadata <- contract$metadata
  list(
    id = contract_id,
    version = as.character(metadata$schema_version[[1L]]),
    paths = file.path(
      plan$root,
      c(metadata$units[[1L]], metadata$aggregations[[1L]])
    )
  )
}

wlv_method_aggregation_registry <- function(plan, method) {
  wlv_native_aggregation_registry(
    root = plan$root,
    catalog = plan$catalog,
    method = method$method[[1L]]
  )
}

wlv_method_unit_definitions <- function(plan, method) {
  contract_id <- method$unit_contract[[1L]]
  if (!nzchar(contract_id)) {
    return(NULL)
  }
  wlv_catalog_unit_contract(plan$catalog, contract_id)$units
}

wlv_validate_method_source_manifest <- function(plan, method, artifacts) {
  contract <- wlv_method_unit_contract_paths(plan, method)
  normalized_root <- dirname(artifacts$manifest)
  manifest <- wlv_read_source_manifest(artifacts$manifest)
  wlv_verify_source_manifest(
    manifest,
    source_root = normalized_root,
    contract_path = contract$paths,
    expected_contract_id = contract$id,
    expected_contract_version = contract$version
  )
  normalized_root_path <- normalizePath(
    normalized_root,
    winslash = "/",
    mustWork = TRUE
  )
  required_paths <- setdiff(artifacts$required, artifacts$manifest)
  resolved_paths <- normalizePath(
    required_paths,
    winslash = "/",
    mustWork = TRUE
  )
  comparison_root <- normalized_root_path
  comparison_paths <- resolved_paths
  if (.Platform$OS.type == "windows") {
    comparison_root <- tolower(comparison_root)
    comparison_paths <- tolower(comparison_paths)
  }
  prefix <- paste0(sub("/+$", "", comparison_root), "/")
  inside <- startsWith(comparison_paths, prefix)
  if (any(!inside)) {
    stop(
      "Catalog-declared normalized source artifacts must stay inside their generation.",
      call. = FALSE
    )
  }
  relative_paths <- substring(
    resolved_paths,
    nchar(normalized_root_path) + 2L
  )
  undeclared <- setdiff(relative_paths, manifest$artifact)
  if (length(undeclared)) {
    stop(
      sprintf(
        "Normalized source artifact(s) are absent from the generation manifest: %s.",
        paste(undeclared, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  list(
    manifest = manifest,
    provenance = wlv_source_provenance(manifest, method$source[[1L]]),
    normalized_root = normalized_root,
    gfcf_observations = file.path(normalized_root, "_gfcf_canonical.rds")
  )
}

wlv_assert_method_source_inputs_unchanged <- function(plan, method, run_data) {
  if (!is.list(run_data) || is.null(run_data$source_provenance) ||
      is.null(run_data$source_provenance_input_inventory)) {
    stop("The validated run data lack source provenance.", call. = FALSE)
  }
  artifacts <- wlv_resolve_source_artifacts(plan, method, needs_io = TRUE)
  current <- wlv_validate_method_source_manifest(plan, method, artifacts)
  current_provenance <- wlv_source_provenance(
    current$manifest,
    method$source[[1L]],
    additional_paths = run_data$source_provenance_inputs
  )
  wlv_validate_source_provenance(run_data$source_provenance)
  current_inventory <- wlv_publication_source_input_inventory(
    plan$root,
    run_data$source_provenance_inputs
  )
  if (!identical(current_provenance, run_data$source_provenance) ||
      !identical(
        current_inventory,
        run_data$source_provenance_input_inventory
      )) {
    stop(
      paste0(
        "Source inputs changed after preflight validation; the result was not ",
        "published. Run the calculation again from the new source generation."
      ),
      call. = FALSE
    )
  }
  invisible(current_provenance)
}

wlv_assert_run_environments_source_inputs_unchanged <- function(
    plan,
    run_environments) {
  if (!inherits(plan, "wlv_run_plan")) {
    return(invisible(TRUE))
  }
  if (!is.list(run_environments) || !length(run_environments)) {
    stop("Published runs are required for source-input verification.", call. = FALSE)
  }
  records <- lapply(run_environments, function(run_environment) {
    if (!is.environment(run_environment) ||
        is.null(run_environment$wlv_run_manifest$method) ||
        is.null(run_environment$wlv_source_provenance) ||
        is.null(run_environment$wlv_source_provenance_inputs) ||
        is.null(run_environment$wlv_source_provenance_input_inventory)) {
      stop(
        "A promoted run lacks its immutable source-input snapshot.",
        call. = FALSE
      )
    }
    method <- run_environment$wlv_run_manifest$method
    method_index <- match(method, plan$methods$method)
    if (is.na(method_index)) {
      stop("A promoted run is absent from its run plan.", call. = FALSE)
    }
    inventory <- run_environment$wlv_source_provenance_input_inventory
    inventory_key <- if (length(inventory)) {
      paste(vapply(inventory, function(record) {
        paste(record$path, record$sha256, sep = "=")
      }, character(1L)), collapse = "|")
    } else {
      ""
    }
    provenance <- run_environment$wlv_source_provenance
    key <- paste(
      provenance$source,
      provenance$source_generation_id,
      provenance$contract_sha256,
      provenance$manifest_sha256,
      inventory_key,
      sep = "\034"
    )
    list(
      key = key,
      method = plan$methods[method_index, , drop = FALSE],
      run_data = list(
        source_provenance = provenance,
        source_provenance_inputs =
          run_environment$wlv_source_provenance_inputs,
        source_provenance_input_inventory = inventory
      )
    )
  })
  keys <- vapply(records, `[[`, character(1L), "key")
  for (index in which(!duplicated(keys))) {
    wlv_assert_method_source_inputs_unchanged(
      plan,
      records[[index]]$method,
      records[[index]]$run_data
    )
  }
  invisible(TRUE)
}

wlv_io_years <- function(path) {
  metadata_path <- paste0(path, ".meta")
  metadata <- tryCatch(
    readRDS(metadata_path),
    error = function(error) {
      stop(
        sprintf("Cannot read matrix metadata `%s`: %s", metadata_path, conditionMessage(error)),
        call. = FALSE
      )
    }
  )
  years <- metadata[[2L]]
  if (is.null(years) || !length(years) || anyNA(years)) {
    stop(
      sprintf("Matrix metadata `%s` does not declare its years.", metadata_path),
      call. = FALSE
    )
  }
  as.character(years)
}

wlv_io_period_key <- function(path) {
  paste(wlv_io_years(path), collapse = "\034")
}

wlv_euklems_files <- function(root, source_io, matrix_modules) {
  depreciation_offsets <- c(
    "matrix.capital.wiodr13" = 1L,
    "matrix.capital.reduction_problem" = 0L,
    "matrix.capital.wiodr16" = 1L
  )
  depreciation_offsets <- unname(
    depreciation_offsets[intersect(names(depreciation_offsets), matrix_modules)]
  )
  if (!length(depreciation_offsets)) {
    return(character())
  }

  years <- sort(unique(unlist(lapply(source_io, wlv_io_years), use.names = FALSE)))
  numeric_years <- suppressWarnings(as.integer(years))
  if (anyNA(numeric_years) || any(as.character(numeric_years) != years)) {
    stop(
      sprintf(
        "WIOD matrix metadata must use integer years; found: %s",
        paste(years, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  depreciation_years <- sort(unique(unlist(
    lapply(depreciation_offsets, function(offset) numeric_years + offset),
    use.names = FALSE
  )))
  euklems_dir <- file.path(root, "source_data", "euklems")
  c(
    file.path(euklems_dir, sprintf("ekk_%s.fst", years)),
    file.path(euklems_dir, sprintf("ekdeprate_%s.fst", depreciation_years))
  )
}

wlv_wiodr13_euklems_files <- wlv_euklems_files

# Native graph and data preflight. Every graph is resolved before any FST
# payload is deserialized.
wlv_native_metadata_years <- function(path) {
  metadata_path <- paste0(path, ".meta")
  metadata <- tryCatch(
    readRDS(metadata_path),
    error = function(error) {
      stop(
        sprintf(
          "Cannot read array metadata `%s`: %s",
          metadata_path,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  years <- metadata[[2L]]
  if (is.null(years) || !length(years) || anyNA(years) ||
      any(!nzchar(as.character(years)))) {
    stop(
      sprintf("Array metadata `%s` does not declare valid years.", metadata_path),
      call. = FALSE
    )
  }
  as.character(years)
}

wlv_native_metadata_outputs <- function(path) {
  metadata_path <- paste0(path, ".meta")
  metadata <- tryCatch(
    readRDS(metadata_path),
    error = function(error) {
      stop(sprintf(
        "Cannot read array metadata `%s`: %s",
        metadata_path,
        conditionMessage(error)
      ), call. = FALSE)
    }
  )
  dimensions <- metadata[[1L]]
  if (!is.numeric(dimensions) || length(dimensions) != 3L) {
    stop(sprintf(
      "Normalized source IO metadata `%s` must be three-dimensional.",
      metadata_path
    ), call. = FALSE)
  }
  outputs <- metadata[[4L]]
  if (is.null(outputs) || !length(outputs) || anyNA(outputs) ||
      any(!nzchar(as.character(outputs))) || anyDuplicated(outputs)) {
    stop(sprintf(
      "Array metadata `%s` does not declare valid outputs.",
      metadata_path
    ), call. = FALSE)
  }
  as.character(outputs)
}

wlv_native_validate_leontief_zero_source_coordinates <- function(
    scientific_profile,
    source_io,
    method) {
  wlv_assert_scientific_profile(
    scientific_profile,
    method,
    scientific_profile$source
  )
  counts <- scientific_profile$leontief_zero$counts
  if (!nrow(counts)) {
    return(invisible(TRUE))
  }
  metadata <- lapply(source_io, function(path) {
    list(
      years = wlv_native_metadata_years(path),
      outputs = wlv_native_metadata_outputs(path)
    )
  })
  invalid <- vapply(seq_len(nrow(counts)), function(index) {
    matching <- which(vapply(metadata, function(entry) {
      counts$year[[index]] %in% entry$years
    }, logical(1L)))
    length(matching) != 1L ||
      !counts$output[[index]] %in% metadata[[matching[[1L]]]]$outputs
  }, logical(1L))
  if (any(invalid)) {
    coordinates <- paste(
      counts$year[invalid],
      counts$output[invalid],
      sep = "|"
    )
    stop(sprintf(
      paste0(
        "Leontief zero-output profile for method `%s` references unknown ",
        "source coordinates: %s."
      ),
      method,
      paste(utils::head(coordinates, 5L), collapse = ",")
    ), call. = FALSE)
  }
  invisible(TRUE)
}

wlv_native_validate_partition_coverage <- function(source_io, source_sea) {
  period_years <- lapply(source_io, wlv_native_metadata_years)
  observed <- unlist(period_years, use.names = FALSE)
  expected <- wlv_native_metadata_years(source_sea)
  duplicated_years <- unique(observed[duplicated(observed)])
  if (length(duplicated_years) || !identical(observed, expected)) {
    stop(
      sprintf(
        paste0(
          "Input-output periods do not exactly cover the SEA years ",
          "(duplicates=%s; expected=%s; observed=%s)."
        ),
        paste(duplicated_years, collapse = ","),
        paste(expected, collapse = ","),
        paste(observed, collapse = ",")
      ),
      call. = FALSE
    )
  }
  invisible(expected)
}

wlv_native_indicator_stage_map <- function(
    registry,
    configuration,
    aggregation_registry,
    indicators,
    partitions) {
  instances <- wlv_native_plan_instances(
    registry = registry,
    config = configuration,
    aggregation_registry = aggregation_registry,
    indicators = indicators,
    partitions = partitions,
    mode = "calculate"
  )
  resolved <- wlv_native_resolved_instances(
    registry,
    instances,
    partitions,
    operation = "calculate"
  )
  stages <- stats::setNames(rep(NA_integer_, length(indicators)), indicators)
  for (module in resolved) {
    rank <- wlv_runtime_checkpoint_rank(
      module$checkpoint,
      wlv_default_checkpoint_order
    )
    for (output in module$provides) {
      prefix <- "sea/sector/"
      key <- output$ref$key
      if (!startsWith(key, prefix)) next
      indicator <- substring(key, nchar(prefix) + 1L)
      if (indicator %in% indicators &&
          (is.na(stages[[indicator]]) || rank > stages[[indicator]])) {
        stages[[indicator]] <- rank
      }
    }
  }
  if (anyNA(stages)) {
    stop(
      sprintf(
        "Native graph has no sector producer for indicator(s): %s.",
        paste(names(stages)[is.na(stages)], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  stages
}

wlv_native_validate_selected_stages <- function(stages, sea_vars, at_stage, method) {
  if (is.null(sea_vars)) return(invisible(NULL))
  unknown <- setdiff(sea_vars, names(stages))
  if (length(unknown)) {
    stop(
      sprintf(
        "Unknown `sea_vars` for method `%s`: %s.",
        method,
        paste(unknown, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  selected <- stages[sea_vars]
  unavailable <- selected < at_stage
  if (any(unavailable)) {
    details <- paste0(
      names(selected)[unavailable],
      " (stage ",
      unname(selected[unavailable]),
      ")"
    )
    stop(
      sprintf(
        paste0(
          "Selected `sea_vars` cannot be recalculated from checkpoint ",
          "stage %d for method `%s`: %s."
        ),
        at_stage,
        method,
        paste(details, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(selected)
}

wlv_native_validate_parent_scientific_profile <- function(
    plan,
    method_record,
    result_dir,
    source_sea) {
  method <- method_record$method[[1L]]
  source <- method_record$source[[1L]]
  profile <- plan$scientific_profiles[[method]]
  wlv_assert_scientific_profile(profile, method, source)
  runtime <- wlv_new_contract_runtime(
    method = method,
    source = source,
    policy = wlv_load_run_missingness_policy(plan, method_record),
    scientific_profile = profile
  )
  anomalies <- wlv_read_contract_report(
    file.path(result_dir, "_anomalies.csv")
  )
  wlv_validate_leontief_zero_output_anomalies(runtime, anomalies)
  wlv_validate_nonfinite_resolution_anomalies(runtime, anomalies)

  diagnostics <- if (source %in% c("wiodr13", "wiodr16")) {
    wlv_load_gfcf_diagnostic_artifacts(result_dir, method = source)
  } else {
    list()
  }
  diagnostics[["_leontief_diagnostics.csv"]] <-
    wlv_load_leontief_diagnostic_artifact(
      result_dir,
      method = method,
      expected_years = wlv_native_metadata_years(source_sea)
    )
  nonfinite_name <- "_nonfinite_resolution_diagnostics.csv"
  nonfinite_path <- file.path(result_dir, nonfinite_name)
  if (file.exists(nonfinite_path)) {
    diagnostics[[nonfinite_name]] <-
      wlv_read_nonfinite_resolution_diagnostics(nonfinite_path)
  }
  wlv_scientific_validate_leontief_signed_profile(
    diagnostics[["_leontief_diagnostics.csv"]],
    profile,
    method
  )
  wlv_scientific_validate_nonfinite_resolution(
    diagnostics,
    profile,
    method
  )
  diagnostics
}

wlv_native_validate_nonfinite_source_coordinates <- function(
    scientific_profile,
    source_validation,
    method) {
  wlv_assert_scientific_profile(
    scientific_profile,
    method,
    scientific_profile$source
  )
  rules <- scientific_profile$nonfinite_resolution$rules
  if (!nrow(rules)) {
    return(invisible(TRUE))
  }
  countries <- source_validation$countries
  sectors <- source_validation$sectors
  if (is.null(countries) || is.null(sectors)) {
    stop(sprintf(
      "Normalized source dimensions cannot validate method `%s` scientific rules.",
      method
    ), call. = FALSE)
  }
  unknown_countries <- setdiff(
    unique(rules$country),
    as.character(countries)
  )
  unknown_sectors <- setdiff(
    unique(rules$sector),
    as.character(sectors)
  )
  if (length(unknown_countries) || length(unknown_sectors)) {
    stop(sprintf(
      paste0(
        "Scientific non-finite rules for method `%s` reference ",
        "unknown normalized source coordinates (countries=%s; sectors=%s)."
      ),
      method,
      if (length(unknown_countries)) {
        paste(sort(unknown_countries, method = "radix"), collapse = ",")
      } else {
        "none"
      },
      if (length(unknown_sectors)) {
        paste(sort(unknown_sectors, method = "radix"), collapse = ",")
      } else {
        "none"
      }
    ), call. = FALSE)
  }
  invisible(TRUE)
}

wlv_native_validate_nonfinite_module_bindings <- function(
    scientific_profile,
    module_plan,
    method) {
  wlv_assert_scientific_profile(
    scientific_profile,
    method,
    scientific_profile$source
  )
  groups <- scientific_profile$nonfinite_resolution$groups
  if (!nrow(groups)) {
    return(invisible(TRUE))
  }
  if (!inherits(module_plan, "wlv_module_plan") ||
      !is.environment(module_plan)) {
    stop("Scientific module bindings require a compiled native plan.",
      call. = FALSE
    )
  }
  for (index in seq_len(nrow(groups))) {
    group <- groups[index, , drop = FALSE]
    resource_key <- paste0("sea/sector/", group$indicator[[1L]])
    providers <- Filter(function(module) {
      identical(module$module_id, group$module[[1L]]) &&
        any(vapply(module$provides, function(output) {
          identical(output$ref$key, resource_key)
        }, logical(1L)))
    }, module_plan$modules)
    if (!length(providers)) {
      stop(sprintf(
        paste0(
          "Scientific non-finite group `%s/%s` for method `%s` is not ",
          "produced by declared module `%s`."
        ),
        group$binding[[1L]],
        group$kind[[1L]],
        method,
        group$module[[1L]]
      ), call. = FALSE)
    }
  }
  invisible(TRUE)
}

wlv_native_scientific_binding_preflight <- function(
    registry,
    configuration,
    aggregation_registry,
    indicators,
    partitions,
    source) {
  instances <- wlv_native_plan_instances(
    registry = registry,
    config = configuration,
    aggregation_registry = aggregation_registry,
    indicators = indicators,
    partitions = partitions,
    mode = "calculate"
  )
  wlv_native_preflight_plan(
    registry,
    instances,
    partitions,
    mode = "calculate",
    source = source,
    indicators = indicators
  )
}

wlv_validate_data <- function(
    plan,
    wiodr13_validator = NULL,
    wiodr16_validator = NULL) {
  if (!inherits(plan, "wlv_run_plan")) {
    stop("`plan` must be produced by wlv_validate_request().", call. = FALSE)
  }

  data_plan <- vector("list", nrow(plan$methods))
  names(data_plan) <- plan$method_names
  validator_overrides <- list(
    wiodr13 = wiodr13_validator,
    wiodr16 = wiodr16_validator
  )
  scientific_validations <- list()

  for (index in seq_len(nrow(plan$methods))) {
    method_record <- plan$methods[index, , drop = FALSE]
    method <- method_record$method[[1L]]
    source <- method_record$source[[1L]]
    wlv_assert_plan_scientific_profile_inventory(plan, method)
    artifacts <- wlv_resolve_source_artifacts(
      plan,
      method_record,
      needs_io = TRUE
    )
    source_io <- artifacts$input_output
    if (!length(source_io)) {
      stop(
        sprintf("Native method `%s` has no input-output artifact.", method),
        call. = FALSE
      )
    }
    wlv_native_validate_partition_coverage(
      source_io,
      artifacts$socioeconomic
    )
    wlv_native_validate_leontief_zero_source_coordinates(
      plan$scientific_profiles[[method]],
      source_io,
      method
    )
    partitions <- unname(vapply(
      source_io,
      wlv_native_io_partition,
      character(1L)
    ))
    if (anyDuplicated(partitions)) {
      stop(
        sprintf("Native method `%s` has duplicate IO partitions.", method),
        call. = FALSE
      )
    }

    aggregation_registry <- plan$aggregation_registries[[method]]
    indicators <- plan$indicators[[method]]
    configuration <- plan$configuration[[method]]
    stages <- wlv_native_indicator_stage_map(
      plan$native_registry,
      configuration,
      aggregation_registry,
      indicators,
      partitions
    )
    if (identical(plan$mode, "recalculate")) {
      wlv_native_validate_selected_stages(
        stages,
        plan$sea_vars,
        plan$at_stage,
        method
      )
    }
    instances <- wlv_native_plan_instances(
      registry = plan$native_registry,
      config = configuration,
      aggregation_registry = aggregation_registry,
      indicators = indicators,
      partitions = partitions,
      mode = plan$mode,
      at_stage = plan$at_stage,
      sea_vars = plan$sea_vars
    )
    preflight <- wlv_native_preflight_plan(
      plan$native_registry,
      instances,
      partitions,
      plan$mode,
      source = source,
      at_stage = plan$at_stage,
      indicators = indicators
    )
    # Producer declarations describe the effective scientific composition, not
    # the checkpoint-specific recalculation subgraph.  Always prove them
    # against the complete calculation DAG; inherited diagnostics are checked
    # separately against the immutable parent run below.
    scientific_binding_preflight <- if (identical(plan$mode, "calculate")) {
      preflight
    } else {
      wlv_native_scientific_binding_preflight(
        registry = plan$native_registry,
        configuration = configuration,
        aggregation_registry = aggregation_registry,
        indicators = indicators,
        partitions = partitions,
        source = source
      )
    }
    wlv_native_validate_nonfinite_module_bindings(
      plan$scientific_profiles[[method]],
      scientific_binding_preflight,
      method
    )

    # Compile and validate the complete native graph before hashing or reading
    # the normalized scientific payloads.  Source existence and lightweight
    # partition metadata are sufficient to determine the graph.
    manifest <- wlv_validate_method_source_manifest(
      plan,
      method_record,
      artifacts
    )

    method_data <- list(
      source_manifest = manifest$manifest,
      source_provenance = manifest$provenance,
      source_sea = artifacts$socioeconomic,
      source_io = source_io,
      gfcf_observations = if (file.exists(manifest$gfcf_observations)) {
        manifest$gfcf_observations
      } else {
        NULL
      },
      partitions = partitions,
      indicator_stages = stages,
      native_instances = instances,
      native_preflight = preflight
    )

    validator_bundle <- wlv_load_catalog_validator(plan, method_record)
    validator <- validator_overrides[[source]]
    if (!is.function(validator)) validator <- validator_bundle$validate
    if (is.null(scientific_validations[[source]])) {
      scientific_validations[[source]] <- validator(manifest$normalized_root)
    }
    method_sectors <- wlv_native_read_semicolon(method_record$sectors_file[[1L]])
    validated_sectors <- scientific_validations[[source]]$sectors
    if (!is.null(validated_sectors) && !identical(
      as.character(validated_sectors),
      as.character(method_sectors$sector.source)
    )) {
      stop(
        sprintf(
          "Normalized source sectors do not match method `%s`.",
          method
        ),
        call. = FALSE
      )
    }
    wlv_native_validate_nonfinite_source_coordinates(
      plan$scientific_profiles[[method]],
      scientific_validations[[source]],
      method
    )

    capital_modules <- configuration$module_id[
      startsWith(configuration$module_id, "matrix.capital.")
    ]
    euklems_files <- wlv_euklems_files(
      plan$root,
      source_io,
      capital_modules
    )
    if (length(euklems_files)) {
      wlv_require_files(
        euklems_files,
        sprintf("WIOD EU KLEMS data for method `%s`", method)
      )
      required_sector_columns <- c("euklems.capital", "euklems.sector")
      missing_sector_columns <- setdiff(
        required_sector_columns,
        names(method_sectors)
      )
      if (length(missing_sector_columns)) {
        stop(
          sprintf(
            "Method `%s` lacks EU KLEMS sector columns: %s.",
            method,
            paste(missing_sector_columns, collapse = ", ")
          ),
          call. = FALSE
        )
      }
      validator_bundle$validate_euklems(
        euklems_files,
        required_variables = method_sectors$euklems.capital,
        required_sectors = method_sectors$euklems.sector
      )
    }
    first_input_inventory <- wlv_publication_source_input_inventory(
      plan$root,
      euklems_files
    )
    method_data$source_provenance <- wlv_source_provenance(
      manifest$manifest,
      source,
      additional_paths = euklems_files
    )
    second_input_inventory <- wlv_publication_source_input_inventory(
      plan$root,
      euklems_files
    )
    if (!identical(first_input_inventory, second_input_inventory)) {
      stop(
        sprintf(
          "Source inputs changed while method `%s` was being validated.",
          method
        ),
        call. = FALSE
      )
    }
    method_data$source_provenance_inputs <- euklems_files
    method_data$source_provenance_input_inventory <- first_input_inventory

    if (identical(plan$mode, "recalculate")) {
      parent_run <- wlv_resolve_current_method_run(
        plan$root,
        method,
        channel = plan$channel
      )
      result_dir <- parent_run$path
      method_data$parent_result_dir <- result_dir
      method_data$parent_run_id <- parent_run$run_id
      method_data$parent_result_id <- parent_run$result_id
      method_data$parent_release_id <- parent_run$release_id
      method_data$parent_manifest <- parent_run$manifest
      if (!isTRUE(parent_run$manifest$result$provenance$complete)) {
        stop(
          sprintf(
            "Parent run for method `%s` lacks complete provenance.",
            method
          ),
          call. = FALSE
        )
      }
      wlv_assert_recalculation_source_provenance(
        result_dir,
        current_manifest = manifest$manifest,
        source = source,
        additional_paths = euklems_files
      )
      required <- file.path(
        result_dir,
        c(
          "m_countries.fst", "m_countries.fst.meta",
          "sea_sectors.fst", "sea_sectors.fst.meta",
          "sea_countries.fst", "sea_countries.fst.meta",
          "_states.csv", "_anomalies.csv"
        )
      )
      wlv_require_files(required, sprintf("parent results for method `%s`", method))
      method_data$parent_scientific_diagnostics <-
        wlv_native_validate_parent_scientific_profile(
          plan,
          method_record,
          result_dir,
          artifacts$socioeconomic
        )

      if (plan$at_stage <= 4L) {
        result_io <- wlv_list_io_files(result_dir)
        if (!length(result_io)) {
          stop(
            sprintf("No parent m_io files exist for method `%s`.", method),
            call. = FALSE
          )
        }
        wlv_require_files(
          paste0(result_io, ".meta"),
          sprintf("parent matrix metadata for method `%s`", method)
        )
        source_keys <- vapply(source_io, wlv_io_period_key, character(1L))
        result_keys <- vapply(result_io, wlv_io_period_key, character(1L))
        source_order <- match(result_keys, source_keys)
        if (anyDuplicated(source_keys) || anyDuplicated(result_keys) ||
            anyNA(source_order) || length(source_keys) != length(result_keys)) {
          stop(
            sprintf(
              "Source and parent matrix periods do not correspond for method `%s`.",
              method
            ),
            call. = FALSE
          )
        }
        method_data$source_io <- source_io[source_order]
        method_data$result_io <- result_io
        method_data$partitions <- unname(vapply(
          method_data$source_io,
          wlv_native_io_partition,
          character(1L)
        ))
      }
    }
    data_plan[[method]] <- method_data
  }

  plan$data <- data_plan
  plan
}

wlv_with_cluster <- function(
    workers,
    run,
    make_cluster = function(workers) parallel::makeCluster(workers, type = "PSOCK"),
    stop_cluster = parallel::stopCluster) {
  workers <- wlv_validate_workers(workers)
  if (!is.function(run)) {
    stop("`run` must be a function.", call. = FALSE)
  }
  if (workers == 1L) {
    return(run(NULL))
  }

  cluster <- make_cluster(workers)
  cluster_open <- TRUE
  cleanup <- function(silent = FALSE) {
    if (!cluster_open) {
      return(invisible(NULL))
    }
    cluster_open <<- FALSE
    if (silent) {
      try(stop_cluster(cluster), silent = TRUE)
    } else {
      stop_cluster(cluster)
    }
    invisible(NULL)
  }
  on.exit(cleanup(silent = TRUE), add = TRUE)

  result <- tryCatch(
    run(cluster),
    error = function(error) {
      try(cleanup(), silent = TRUE)
      stop(error)
    }
  )
  cleanup()
  result
}

wlv_prepare_sources <- function(plan) {
  if (!inherits(plan, "wlv_run_plan")) {
    stop("`plan` must be produced by wlv_validate_request().", call. = FALSE)
  }
  registry <- wlv_default_preparation_registry()
  services <- wlv_default_preparation_services()
  source_indexes <- which(!duplicated(plan$methods$source))
  executions <- lapply(source_indexes, function(index) {
    method_record <- plan$methods[index, , drop = FALSE]
    source <- method_record$source[[1L]]
    source_record <- wlv_catalog_source(plan$catalog, source)
    preparation_task <- source_record$preparation_task[[1L]]
    if (!identical(preparation_task, source)) {
      stop(
        sprintf(
          "Source `%s` does not match its native preparation task `%s`.",
          source,
          preparation_task
        ),
        call. = FALSE
      )
    }
    wlv_prepare_registered_source(
      registry = registry,
      source = preparation_task,
      root = plan$root,
      catalog = plan$catalog,
      source_record = source_record,
      services = services
    )
  })
  names(executions) <- plan$methods$source[source_indexes]
  invisible(executions)
}

wlv_result_path_is_within <- function(path, parent) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  parent <- normalizePath(parent, winslash = "/", mustWork = TRUE)
  startsWith(path, paste0(sub("/+$", "", parent), "/"))
}

wlv_acquire_result_lock <- function(results_root, method) {
  dir.create(results_root, recursive = TRUE, showWarnings = FALSE)
  results_root <- normalizePath(results_root, winslash = "/", mustWork = TRUE)
  lock <- file.path(results_root, ".lock-results")
  if (!wlv_result_path_is_within(lock, results_root) ||
      !startsWith(basename(lock), ".lock-")) {
    stop("Refusing to create an unsafe result lock path.", call. = FALSE)
  }
  if (!dir.create(lock, recursive = FALSE, showWarnings = FALSE)) {
    stop(
      sprintf(
        paste0(
          "Results are already locked by another method run (requested: `%s`). ",
          "If no run is active, remove `%s` after verifying that it is stale."
        ),
        method,
        lock
      ),
      call. = FALSE
    )
  }
  normalizePath(lock, winslash = "/", mustWork = TRUE)
}

wlv_release_result_lock <- function(lock, results_root) {
  if (is.null(lock) || !dir.exists(lock)) {
    return(invisible(NULL))
  }
  if (!wlv_result_path_is_within(lock, results_root) ||
      !startsWith(basename(lock), ".lock-")) {
    stop(sprintf("Refusing to remove unsafe result lock `%s`.", lock), call. = FALSE)
  }
  unlink(lock, recursive = TRUE, force = TRUE)
  if (dir.exists(lock)) {
    stop(sprintf("Could not remove result lock `%s`.", lock), call. = FALSE)
  }
  invisible(NULL)
}

wlv_create_result_staging <- function(root, method, existing = NULL) {
  results_root <- file.path(root, "results")
  dir.create(results_root, recursive = TRUE, showWarnings = FALSE)
  results_root <- normalizePath(results_root, winslash = "/", mustWork = TRUE)
  staging_root <- file.path(results_root, ".staging")
  if (!dir.exists(staging_root) &&
      !dir.create(staging_root, recursive = FALSE, showWarnings = FALSE)) {
    stop("Could not create the private result staging namespace.", call. = FALSE)
  }
  staging_root <- normalizePath(staging_root, winslash = "/", mustWork = TRUE)
  staging <- tempfile(
    pattern = sprintf(".staging-%s-", method),
    tmpdir = staging_root
  )
  if (!wlv_result_path_is_within(staging, results_root)) {
    stop("Refusing to create result staging outside the results directory.", call. = FALSE)
  }
  if (!dir.create(staging, recursive = FALSE, showWarnings = FALSE)) {
    stop(sprintf("Could not create result staging directory `%s`.", staging), call. = FALSE)
  }

  if (!is.null(existing) && dir.exists(existing)) {
    entries <- list.files(
      existing,
      full.names = TRUE,
      all.files = TRUE,
      no.. = TRUE
    )
    if (length(entries)) {
      copied <- file.copy(
        entries,
        staging,
        recursive = TRUE,
        copy.mode = TRUE,
        copy.date = TRUE
      )
      if (!all(copied)) {
        unlink(staging, recursive = TRUE, force = TRUE)
        stop(
          sprintf(
            "Could not copy existing result file(s) into staging: %s.",
            paste(basename(entries[!copied]), collapse = ", ")
          ),
          call. = FALSE
        )
      }
    }
  }

  normalizePath(staging, winslash = "/", mustWork = TRUE)
}

wlv_remove_result_staging <- function(staging, results_root) {
  if (is.null(staging) || !dir.exists(staging)) {
    return(invisible(NULL))
  }
  if (!wlv_result_path_is_within(staging, results_root) ||
      !startsWith(basename(staging), ".staging-")) {
    stop(sprintf("Refusing to remove unsafe staging path `%s`.", staging), call. = FALSE)
  }
  unlink(staging, recursive = TRUE, force = TRUE)
  if (dir.exists(staging)) {
    stop(sprintf("Could not remove result staging directory `%s`.", staging), call. = FALSE)
  }
  invisible(NULL)
}

wlv_load_run_missingness_policy <- function(plan, method) {
  policy_id <- if ("missingness_policy" %in% names(method)) {
    method$missingness_policy[[1L]]
  } else {
    ""
  }
  if (!nzchar(policy_id)) {
    return(wlv_strict_missingness_policy(
      source = method$source[[1L]],
      policy_id = sprintf("%s_strict", method$source[[1L]])
    ))
  }

  record <- wlv_catalog_missingness_policy(plan$catalog, policy_id)
  factories <- list(
    wiodr13_v1 = wlv_wiodr13_missingness_policy,
    wiodr16_v1 = wlv_wiodr16_missingness_policy
  )
  expected_names <- c(
    wiodr13_v1 = "wlv_wiodr13_missingness_policy",
    wiodr16_v1 = "wlv_wiodr16_missingness_policy"
  )
  factory <- factories[[policy_id]]
  if (is.null(factory) ||
      !identical(record$factory[[1L]], unname(expected_names[[policy_id]])) ||
      !identical(record$script[[1L]], "R/lib/missingness.R")) {
    stop(
      sprintf(
        "Missingness policy `%s` does not match the explicit native registry.",
        policy_id
      ),
      call. = FALSE
    )
  }
  policy <- factory()
  if (!inherits(policy, "wlv_missingness_policy") ||
      !identical(policy$policy_id, policy_id) ||
      !identical(policy$source, method$source[[1L]])) {
    stop(
      sprintf(
        "Missingness policy factory `%s` returned an incompatible policy.",
        record$factory[[1L]]
      ),
      call. = FALSE
    )
  }
  policy
}

wlv_native_year_apply_service <- function(cluster = NULL) {
  if (is.null(cluster)) {
    return(function(X, MARGIN, FUN, ...) {
      base::apply(X, MARGIN, FUN, ...)
    })
  }
  force(cluster)
  function(X, MARGIN, FUN, ...) {
    parallel::parApply(
      cl = cluster,
      X = X,
      MARGIN = MARGIN,
      FUN = FUN,
      ...
    )
  }
}

wlv_native_artifact_value <- function(store, name, axes) {
  wlv_store_read(
    store,
    wlv_resource_ref(
      paste0("artifact/", name),
      wlv_native_artifact_array_contract(name, axes)
    )
  )
}

wlv_native_store_value <- function(store, key, contract) {
  wlv_store_read(store, wlv_resource_ref(key, contract))
}

wlv_native_configuration_sidecars <- function(
    plan,
    method,
    run_data) {
  configuration <- plan$configuration[[method]]
  ordered <- configuration[order(configuration$instance_id, method = "radix"), , drop = FALSE]
  assumptions <- ordered[startsWith(ordered$instance_id, "assumption."), , drop = FALSE]
  matrices <- ordered[startsWith(ordered$instance_id, "matrix."), , drop = FALSE]
  sidecar <- function(value) {
    data.frame(
      names = as.character(value$instance_id),
      computation = as.character(value$module_id),
      order = seq_len(nrow(value)),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  }

  registry <- plan$native_registry
  aggregation_registry <- plan$aggregation_registries[[method]]
  indicators <- plan$indicators[[method]]
  instances <- wlv_native_plan_instances(
    registry = registry,
    config = configuration,
    aggregation_registry = aggregation_registry,
    indicators = indicators,
    partitions = run_data$partitions,
    mode = "calculate"
  )
  resolved <- wlv_native_resolved_instances(
    registry,
    instances,
    run_data$partitions,
    operation = "calculate"
  )
  candidates <- stats::setNames(vector("list", length(indicators)), indicators)
  prefix <- "sea/sector/"
  for (module in resolved) {
    rank <- wlv_runtime_checkpoint_rank(
      module$checkpoint,
      wlv_default_checkpoint_order
    )
    for (output in module$provides) {
      key <- output$ref$key
      if (!startsWith(key, prefix)) next
      indicator <- substring(key, nchar(prefix) + 1L)
      if (!indicator %in% indicators) next
      candidates[[indicator]][[length(candidates[[indicator]]) + 1L]] <- list(
        rank = rank,
        instance_id = module$instance_id,
        module_id = module$module_id
      )
    }
  }
  selected <- lapply(indicators, function(indicator) {
    available <- candidates[[indicator]]
    if (!length(available)) {
      stop(
        sprintf("No native solution metadata exists for `%s`.", indicator),
        call. = FALSE
      )
    }
    ranks <- vapply(available, `[[`, integer(1L), "rank")
    available <- available[ranks == max(ranks)]
    ids <- vapply(available, `[[`, character(1L), "instance_id")
    available[[order(ids, method = "radix")[[length(ids)]]]]
  })
  aggregation <- wlv_native_aggregation_solutions(
    plan$unit_definitions[[method]],
    aggregation_registry$rows
  )
  aggregation <- aggregation[match(indicators, aggregation$names), , drop = FALSE]
  solutions <- data.frame(
    names = indicators,
    sector_solution = vapply(selected, `[[`, character(1L), "module_id"),
    country_solution = as.character(aggregation$country_solution),
    stage = vapply(selected, `[[`, integer(1L), "rank"),
    order = seq_along(indicators),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  list(
    assumptions = sidecar(assumptions),
    matrices = sidecar(matrices),
    solutions = solutions
  )
}

wlv_native_panel_metadata <- function(parameters, metadata) {
  indicator_names <- metadata[, c("code", "name"), drop = FALSE]
  descriptions <- metadata[, c("code", "description"), drop = FALSE]
  descriptions$code <- paste0("desc.", descriptions$code)
  observations <- metadata[, c("code", "observation"), drop = FALSE]
  observations$code <- paste0(
    "obs.",
    parameters$code[[1L]],
    ".",
    observations$code
  )
  observations <- observations[!is.na(observations$observation), , drop = FALSE]
  group_values <- unique(as.character(metadata$group))
  group_values <- group_values[!is.na(group_values)]
  groups <- data.frame(
    code = paste0("group.", group_values),
    label = group_values,
    stringsAsFactors = FALSE
  )
  names(indicator_names) <- names(descriptions) <- names(observations) <-
    names(groups) <- c("cod_label", "label")
  indicators <- rbind(indicator_names, descriptions, observations, groups)
  panel <- metadata[, c("code", "group", "type", "reverted"), drop = FALSE]
  names(panel) <- c("value", "groups", "type", "reverted")
  list(
    `_panel_indicators.csv` = indicators,
    `_panel_meta_indicators.csv` = panel
  )
}

wlv_native_csv_diagnostics <- function(run_result) {
  collected <- list()
  for (node in run_result$diagnostics) {
    if (!is.list(node) || !length(node)) next
    for (name in names(node)) {
      value <- node[[name]]
      if (!endsWith(name, ".csv") || !is.data.frame(value)) next
      collected[[name]] <- c(collected[[name]], list(value))
    }
  }
  result <- lapply(collected, function(values) {
    result <- do.call(rbind, values)
    result <- unique(result)
    row.names(result) <- NULL
    result
  })
  name <- "_nonfinite_resolution_diagnostics.csv"
  if (name %in% names(result)) {
    result[[name]] <- wlv_normalize_nonfinite_resolution_diagnostics(
      result[[name]]
    )
  }
  result
}

wlv_native_recalculation_diagnostics <- function(run_data) {
  diagnostics <- run_data$parent_scientific_diagnostics
  if (!is.list(diagnostics) || is.null(names(diagnostics))) {
    stop("Recalculation lacks preflighted parent scientific diagnostics.",
      call. = FALSE
    )
  }
  diagnostics
}

wlv_native_public_array <- function(value) {
  if (!is.array(value) || is.null(dimnames(value))) {
    stop("A native public artifact must be an array with dimnames.", call. = FALSE)
  }
  labels <- dimnames(value)
  names(labels) <- NULL
  dimnames(value) <- labels
  value
}

wlv_native_write_arrays <- function(
    plan,
    run_data,
    run_result,
    staging) {
  sea_sectors <- wlv_native_artifact_value(
    run_result$store,
    "sea_sectors",
    c("year", "indicator", "sector", "country")
  )
  sea_countries <- wlv_native_artifact_value(
    run_result$store,
    "sea_countries",
    c("year", "indicator", "country")
  )
  sea_sectors <- wlv_native_public_array(sea_sectors)
  sea_countries <- wlv_native_public_array(sea_countries)
  write_fst_array(sea_sectors, file.path(staging, "sea_sectors.fst"))
  write_fst_array(sea_countries, file.path(staging, "sea_countries.fst"))

  artifacts <- list(
    sea_sectors = sea_sectors,
    sea_countries = sea_countries
  )
  if (identical(plan$mode, "calculate")) {
    m_io <- wlv_native_artifact_value(
      run_result$store,
      "m_io",
      c("year", "variable", "input", "output")
    )
    m_countries <- wlv_native_artifact_value(
      run_result$store,
      "m_countries",
      c("year", "variable", "origin", "destination")
    )
    m_io <- wlv_native_public_array(m_io)
    m_countries <- wlv_native_public_array(m_countries)
    write_fst_array(m_countries, file.path(staging, "m_countries.fst"))
    for (source_path in run_data$source_io) {
      years <- wlv_native_metadata_years(source_path)
      selected <- m_io[years, , , , drop = FALSE]
      write_fst_array(
        selected,
        file.path(staging, basename(source_path))
      )
    }
    artifacts$m_io <- m_io
    artifacts$m_countries <- m_countries
  } else {
    artifacts$m_countries <- read_fst_array(
      file.path(staging, "m_countries.fst")
    )
  }
  artifacts
}

wlv_native_clear_recalculated_states <- function(
    runtime,
    run_data,
    at_stage,
    sea_vars) {
  stages <- run_data$indicator_stages
  indicators <- if (!is.null(sea_vars)) {
    sea_vars
  } else if (identical(at_stage, 1L)) {
    names(stages)[stages <= 1L | stages >= 4L]
  } else {
    names(stages)[stages >= at_stage]
  }
  wlv_contract_clear_states(runtime, "sea_sectors", indicators)
  wlv_contract_clear_states(runtime, "sea_countries", indicators)
  invisible(indicators)
}

wlv_native_recalculated_anomaly_targets <- function(module_plan) {
  if (!inherits(module_plan, "wlv_module_plan") ||
      !is.environment(module_plan)) {
    stop("Recalculated anomaly targets require a compiled native plan.",
      call. = FALSE
    )
  }
  prefixes <- c(
    sea_sectors = "sea/sector/",
    sea_countries = "sea/country/"
  )
  rows <- list()
  for (module in module_plan$modules) {
    for (output in module$provides) {
      key <- output$ref$key
      for (artifact in names(prefixes)) {
        prefix <- prefixes[[artifact]]
        if (startsWith(key, prefix)) {
          rows[[length(rows) + 1L]] <- data.frame(
            artifact = artifact,
            indicator = substring(key, nchar(prefix) + 1L),
            stage = as.character(module$checkpoint_rank),
            module = module$module_id,
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  if (!length(rows)) {
    return(data.frame(
      artifact = character(),
      indicator = character(),
      stage = character(),
      module = character(),
      stringsAsFactors = FALSE
    ))
  }
  targets <- unique(do.call(rbind, rows))
  targets <- targets[order(
    targets$artifact,
    targets$indicator,
    targets$stage,
    targets$module,
    method = "radix"
  ), , drop = FALSE]
  row.names(targets) <- NULL
  targets
}

wlv_native_reset_recalculated_anomalies <- function(runtime, module_plan) {
  targets <- wlv_native_recalculated_anomaly_targets(module_plan)
  if (!nrow(targets) || !nrow(runtime$anomalies)) {
    return(invisible(targets))
  }
  target_indicators <- unlist(lapply(targets$indicator, function(indicator) {
    c(indicator, paste0(indicator, c(".numerator", ".denominator")))
  }), use.names = FALSE)
  target_keys <- paste(
    rep(targets$artifact, each = 3L),
    target_indicators,
    rep(targets$stage, each = 3L),
    rep(targets$module, each = 3L),
    sep = "\034"
  )
  anomaly_keys <- paste(
    runtime$anomalies$artifact,
    runtime$anomalies$indicator,
    runtime$anomalies$stage,
    runtime$anomalies$module,
    sep = "\034"
  )
  runtime$anomalies <- runtime$anomalies[
    !anomaly_keys %in% target_keys,
    ,
    drop = FALSE
  ]
  row.names(runtime$anomalies) <- NULL
  invisible(targets)
}

wlv_run_method <- function(plan, method, cluster = NULL) {
  wlv_assert_plan_scientific_profile_inventory(plan, method)
  method_record <- plan$methods[
    match(method, plan$methods$method),
    ,
    drop = FALSE
  ]
  run_data <- plan$data[[method]]
  if (is.null(run_data$native_instances) || is.null(run_data$partitions)) {
    stop("Native execution requires a completed graph/data preflight.", call. = FALSE)
  }
  results_root <- file.path(plan$root, "results")
  run_id <- wlv_new_publication_id("run")
  started_at <- Sys.time()
  warnings <- character()
  staging <- wlv_create_result_staging(
    plan$root,
    method,
    existing = if (identical(plan$mode, "recalculate")) {
      run_data$parent_result_dir
    } else {
      NULL
    }
  )
  if (identical(plan$mode, "recalculate")) {
    if (!is.list(run_data$parent_manifest)) {
      stop("Recalculation lacks the verified parent run manifest.",
        call. = FALSE
      )
    }
    wlv_verify_run_manifest(
      run_data$parent_manifest,
      staging,
      reject_unlisted = TRUE
    )
    inherited_manifest <- file.path(staging, wlv_run_manifest_filename)
    if (file.exists(inherited_manifest)) unlink(inherited_manifest, force = TRUE)
    if (file.exists(inherited_manifest)) {
      stop("Could not remove inherited run manifest from staging.", call. = FALSE)
    }
  }
  staging_open <- TRUE
  on.exit({
    if (staging_open && dir.exists(staging)) {
      try(wlv_remove_result_staging(staging, results_root), silent = TRUE)
    }
  }, add = TRUE)

  policy <- wlv_load_run_missingness_policy(plan, method_record)
  contract_runtime <- wlv_new_contract_runtime(
    method = method,
    source = method_record$source[[1L]],
    policy = policy,
    scientific_profile = plan$scientific_profiles[[method]]
  )
  if (identical(plan$mode, "recalculate")) {
    parent_values <- list(
      sea_sectors = read_fst_array(file.path(staging, "sea_sectors.fst")),
      sea_countries = read_fst_array(file.path(staging, "sea_countries.fst"))
    )
    wlv_load_contract_report(
      contract_runtime,
      file.path(staging, "_anomalies.csv")
    )
    wlv_load_contract_states(
      contract_runtime,
      file.path(staging, "_states.csv"),
      parent_values
    )
    wlv_native_clear_recalculated_states(
      contract_runtime,
      run_data,
      plan$at_stage,
      plan$sea_vars
    )
    rm(parent_values)
  }

  run_environment <- tryCatch(
    withCallingHandlers({
      built <- wlv_native_build_store(
        plan = plan,
        method_record = method_record,
        run_data = run_data,
        registry = plan$native_registry,
        instances = run_data$native_instances,
        indicators = plan$indicators[[method]],
        unit_definitions = plan$unit_definitions[[method]],
        partitions = run_data$partitions
      )
      module_plan <- wlv_compile_module_plan(
        registry = plan$native_registry,
        instances = run_data$native_instances,
        store = built$store,
        operation = plan$mode,
        partitions = run_data$partitions
      )
      if (identical(plan$mode, "recalculate")) {
        wlv_native_reset_recalculated_anomalies(
          contract_runtime,
          module_plan
        )
      }
      module_result <- wlv_run_module_plan(
        module_plan,
        built$store,
        services = list(
          contract_runtime = contract_runtime,
          year_apply = wlv_native_year_apply_service(cluster)
        )
      )
      arrays <- wlv_native_write_arrays(
        plan,
        run_data,
        module_result,
        staging
      )
      sidecars <- wlv_native_configuration_sidecars(
        plan,
        method,
        run_data
      )
      parameters <- wlv_native_store_value(
        module_result$store,
        "configuration/parameters",
        wlv_resource_contract(scope = "run", value_type = "data.frame")
      )
      sectors <- wlv_native_store_value(
        module_result$store,
        "configuration/sectors",
        wlv_resource_contract(scope = "run", value_type = "data.frame")
      )
      metadata <- wlv_native_store_value(
        module_result$store,
        "metadata/indicators",
        wlv_native_indicator_metadata_contract()
      )

      wlv_validate_sea_stage(
        contract_runtime,
        arrays$sea_sectors,
        sidecars$solutions,
        stage = 5L,
        checkpoint = "pre_publish"
      )
      wlv_validate_sea_countries_contract(
        contract_runtime,
        arrays$sea_countries,
        checkpoint = "pre_publish"
      )
      wlv_validate_m_countries_contract(
        contract_runtime,
        arrays$m_countries,
        checkpoint = "pre_publish"
      )
      if (!is.null(arrays$m_io)) {
        wlv_validate_m_io_contract(
          contract_runtime,
          arrays$m_io,
          checkpoint = "pre_publish"
        )
      }

      diagnostics <- wlv_native_csv_diagnostics(module_result)
      if (identical(plan$mode, "recalculate")) {
        inherited <- wlv_native_recalculation_diagnostics(run_data)
        diagnostics <- utils::modifyList(inherited, diagnostics)
      }
      for (name in names(diagnostics)) {
        wlv_write_result_csv(diagnostics[[name]], file.path(staging, name))
      }
      wlv_assert_method_source_inputs_unchanged(plan, method_record, run_data)
      wlv_write_result_csv(
        run_data$source_provenance,
        file.path(staging, wlv_source_provenance_filename)
      )
      source_sidecar <- stats::setNames(
        list(run_data$source_provenance),
        wlv_source_provenance_filename
      )
      unit_sidecar <- wlv_catalog_unit_contract_sidecar(
        plan$catalog,
        method_record$unit_contract[[1L]],
        indicators = plan$indicators[[method]],
        resolved_aggregations = plan$aggregation_registries[[method]]$rows
      )
      wlv_write_result_csv(
        unit_sidecar,
        file.path(staging, "_unit_contract.csv")
      )
      panel <- wlv_native_panel_metadata(parameters, metadata)
      expected_metadata <- wlv_method_result_metadata(
        parameters = parameters,
        assumptions = sidecars$assumptions,
        matrices = sidecars$matrices,
        solutions = sidecars$solutions,
        sectors = sectors,
        meta_indicators = metadata,
        extra_csv = c(
          diagnostics,
          list(`_unit_contract.csv` = unit_sidecar),
          source_sidecar,
          panel
        )
      )
      wlv_write_method_result_metadata(staging, expected_metadata)
      wlv_write_contract_states(
        contract_runtime,
        staging,
        reader = read_fst_array
      )
      wlv_write_contract_report(
        contract_runtime,
        file.path(staging, "_anomalies.csv")
      )
      scientific_checks <- wlv_validate_staged_results(
        staging,
        method = method,
        mode = plan$mode,
        runtime = contract_runtime,
        expected_metadata = expected_metadata,
        aggregation_registry = plan$aggregation_registries[[method]],
        expected_io_artifacts = basename(run_data$source_io),
        at_stage = if (identical(plan$mode, "recalculate")) {
          plan$at_stage
        } else {
          NULL
        },
        reader = read_fst_array
      )
      validated_artifacts <- attr(
        scientific_checks,
        "wlv_validated_run_artifacts",
        exact = TRUE
      )
      if (is.null(validated_artifacts)) {
        stop(
          "Staged result validation did not return an artifact snapshot.",
          call. = FALSE
        )
      }
      attr(scientific_checks, "wlv_validated_run_artifacts") <- NULL
      environment <- new.env(parent = emptyenv())
      environment$wlv_native_trace <- module_result$trace
      environment$wlv_validated_run_artifacts <- validated_artifacts
      environment$wlv_scientific_diagnostics <- c(
        diagnostics,
        list(`_scientific_checks.csv` = scientific_checks)
      )
      environment
    }, warning = function(condition) {
      warnings <<- c(warnings, conditionMessage(condition))
    }),
    error = function(error) {
      wlv_write_failed_contract_report(
        contract_runtime,
        results_root = results_root,
        error = error
      )
      stop(error)
    }
  )
  run_environment <- wlv_promote_method_run(
    plan = plan,
    method = method,
    staging = staging,
    run_environment = run_environment,
    run_data = run_data,
    run_id = run_id,
    parent_run_id = if (identical(plan$mode, "recalculate")) {
      run_data$parent_run_id
    } else {
      NULL
    },
    started_at = started_at,
    warnings = unique(warnings)
  )
  staging_open <- FALSE
  run_environment
}
