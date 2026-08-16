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

wlv_effective_parameter_group <- function(
    root,
    method,
    source,
    group,
    required_columns) {
  paths <- c(
    file.path(root, "methods", method, sprintf("_method_%s.csv", group)),
    file.path(root, "parameters", source, sprintf("_source_%s.csv", group)),
    file.path(root, "parameters", "common_ground", sprintf("_common_%s.csv", group))
  )
  paths <- paths[file.exists(paths)]
  if (!length(paths)) {
    stop(
      sprintf("No `%s` parameter fragments exist for method `%s`.", group, method),
      call. = FALSE
    )
  }

  pieces <- lapply(paths, function(path) {
    value <- tryCatch(
      utils::read.csv2(path, stringsAsFactors = FALSE),
      error = function(error) {
        stop(
          sprintf("Cannot read parameter fragment `%s`: %s", path, conditionMessage(error)),
          call. = FALSE
        )
      }
    )
    missing_columns <- setdiff(required_columns, names(value))
    if (length(missing_columns)) {
      stop(
        sprintf(
          "Parameter fragment `%s` lacks: %s",
          path,
          paste(missing_columns, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    value[required_columns]
  })

  value <- do.call(rbind, pieces)
  invalid_names <- is.na(value$names) | !nzchar(value$names)
  if (any(invalid_names)) {
    stop(
      sprintf("The `%s` parameters for method `%s` contain an empty name.", group, method),
      call. = FALSE
    )
  }
  value[!duplicated(value$names), , drop = FALSE]
}

wlv_safe_module_reference <- function(reference) {
  is.character(reference) &&
    length(reference) == 1L &&
    !is.na(reference) &&
    nzchar(reference) &&
    !grepl("^([A-Za-z]:|[/\\\\])", reference) &&
    !grepl("(^|[/\\\\])\\.\\.($|[/\\\\])", reference)
}

wlv_validate_method_references <- function(root, method, source, mode) {
  specifications <- list(
    assumptions = c("names", "computation", "order"),
    matrices = c("names", "computation", "order"),
    reduced_matrices = c("names", "computation"),
    solutions = c("names", "sector_solution", "country_solution", "stage", "order")
  )
  groups <- lapply(names(specifications), function(group) {
    wlv_effective_parameter_group(
      root = root,
      method = method,
      source = source,
      group = group,
      required_columns = specifications[[group]]
    )
  })
  names(groups) <- names(specifications)

  references <- character()
  if (mode == "calculate") {
    references <- c(
      file.path("R", "modules", "assumptions", groups$assumptions$computation),
      file.path("R", "modules", "matrices", groups$matrices$computation),
      file.path(
        "R", "modules", "reduced_matrices", groups$reduced_matrices$computation
      )
    )
  }

  solution_references <- c(
    groups$solutions$sector_solution,
    groups$solutions$country_solution
  )
  solution_references <- solution_references[
    grepl("\\.[Rr]$", solution_references)
  ]
  references <- c(references, file.path("R", "modules", "variables", solution_references))
  references <- unique(unlist(references, use.names = FALSE))

  unsafe <- references[!vapply(references, wlv_safe_module_reference, logical(1))]
  if (length(unsafe)) {
    stop(
      sprintf(
        "Method `%s` contains unsafe module references: %s",
        method,
        paste(unsafe, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  wlv_require_files(
    file.path(root, references),
    sprintf("parameter-referenced scripts for method `%s`", method)
  )
  groups
}

wlv_validate_request <- function(
    methods,
    repeat_pp = FALSE,
    papern = 0L,
    prepaper = FALSE,
    workers = 1L,
    mode = c("calculate", "recalculate"),
    at_stage = 1L,
    sea_vars = NULL,
    root = ".",
    allow_experimental = FALSE,
    requested_operations = NULL,
    catalog = NULL) {
  mode <- match.arg(mode)
  repeat_pp <- wlv_validate_flag(repeat_pp, "repeat_pp")
  prepaper <- wlv_validate_flag(prepaper, "prepaper")
  allow_experimental <- wlv_validate_flag(
    allow_experimental,
    "allow_experimental"
  )
  workers <- wlv_validate_workers(workers)
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
    if (!is.null(sea_vars) && (!is.character(sea_vars) || anyNA(sea_vars))) {
      stop("`sea_vars` must be NULL or a character vector without NA.", call. = FALSE)
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
      utils::read.csv2(parameter_file, stringsAsFactors = FALSE),
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
    preparer <- source_record$preparer[[1L]]
    preparer <- if (nzchar(preparer)) file.path(root, preparer) else ""

    data.frame(
      method = method,
      source = source_record$source[[1L]],
      parameter_set = parameter_set,
      method_dir = method_dir,
      source_dir = file.path(root, source_record$data_dir[[1L]]),
      parameter_file = parameter_file,
      sectors_file = sectors_file,
      preparer = preparer,
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
      source = method_plan$parameter_set[[index]],
      mode = mode
    )
  })
  names(configuration) <- method_plan$method

  paper_script <- file.path(root, "R", "utils", "papers", sprintf("paper_%s_selection.R", papern))
  if (prepaper && !file.exists(paper_script)) {
    stop(sprintf("Paper script does not exist: %s", paper_script), call. = FALSE)
  }

  structure(
    list(
      root = root,
      mode = mode,
      requested_operations = requested_operations,
      allow_experimental = allow_experimental,
      catalog = catalog,
      methods = method_plan,
      configuration = configuration,
      method_names = method_plan$method,
      repeat_pp = repeat_pp,
      papern = papern,
      prepaper = prepaper,
      paper_script = paper_script,
      workers = workers,
      at_stage = at_stage,
      sea_vars = sea_vars
    ),
    class = c("wlv_run_plan", "list")
  )
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

  validator_environment <- new.env(
    parent = baseenv()
  )
  previous_directory <- getwd()
  on.exit(setwd(previous_directory), add = TRUE)
  setwd(plan$root)
  tryCatch(
    sys.source(
      file.path(plan$root, script),
      envir = validator_environment,
      chdir = FALSE
    ),
    error = function(error) {
      stop(
        sprintf(
          "Cannot load validator `%s` for source `%s`: %s",
          script,
          method$source[[1L]],
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  validator <- get0(
    function_name,
    envir = validator_environment,
    mode = "function",
    inherits = FALSE
  )
  if (!is.function(validator)) {
    stop(
      sprintf(
        "Validator `%s` does not define catalog function `%s`.",
        script,
        function_name
      ),
      call. = FALSE
    )
  }

  list(validate = validator, environment = validator_environment)
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
  for (index in seq_len(nrow(specifications))) {
    specification <- specifications[index, , drop = FALSE]
    is_input_output <- startsWith(specification$artifact[[1L]], "m_io")
    if (is_input_output && !needs_io) {
      next
    }

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
  }

  wlv_require_files(
    unique(required),
    sprintf("catalog-declared source data for method `%s`", method$method[[1L]])
  )
  list(
    required = unique(required),
    input_output = sort(unique(input_output))
  )
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

wlv_euklems_files <- function(root, source_io, matrix_scripts) {
  depreciation_offsets <- c(
    "wiodr13/euklems.R" = 1L,
    "wiodr13/euklems-reduction_problem.R" = 0L,
    "wiodr16/euklems.R" = 1L
  )
  depreciation_offsets <- unname(
    depreciation_offsets[intersect(names(depreciation_offsets), matrix_scripts)]
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

wlv_validate_data <- function(
    plan,
    wiodr13_validator = NULL,
    wiodr16_validator = NULL) {
  if (!inherits(plan, "wlv_run_plan")) {
    stop("`plan` must be produced by wlv_validate_request().", call. = FALSE)
  }

  data_plan <- vector("list", nrow(plan$methods))
  names(data_plan) <- plan$method_names
  source_names <- unique(plan$methods$source)
  scientific_validations <- stats::setNames(
    vector("list", length(source_names)),
    source_names
  )
  validator_overrides <- list(
    wiodr13 = wiodr13_validator,
    wiodr16 = wiodr16_validator
  )
  validator_environments <- stats::setNames(
    vector("list", length(source_names)),
    source_names
  )

  for (index in seq_len(nrow(plan$methods))) {
    method <- plan$methods[index, , drop = FALSE]
    needs_io <- plan$mode == "calculate" || plan$at_stage <= 4L
    source_artifacts <- wlv_resolve_source_artifacts(
      plan,
      method,
      needs_io = needs_io
    )
    method_data <- list()
    if (needs_io) {
      source_io <- source_artifacts$input_output
      if (!length(source_io)) {
        stop(
          sprintf(
            "Artifact profile `%s` declares no input-output array for method `%s`.",
            method$artifact_profile[[1L]],
            method$method[[1L]]
          ),
          call. = FALSE
        )
      }
      source_name <- method$source
      scientific_validator <- validator_overrides[[source_name]]
      validator_function <- method$validator_function
      has_scientific_validator <- is.function(scientific_validator) ||
        nzchar(validator_function)
      if (has_scientific_validator) {
        source_label <- toupper(sub("r", "", source_name, fixed = TRUE))
        if (is.null(scientific_validations[[source_name]])) {
          validator_bundle <- if (is.function(scientific_validator)) {
            list(
              validate = scientific_validator,
              environment = environment(scientific_validator)
            )
          } else {
            wlv_load_catalog_validator(plan, method)
          }
          scientific_validator <- validator_bundle$validate
          validator_environments[[source_name]] <- validator_bundle$environment
          scientific_validations[[source_name]] <- scientific_validator(method$source_dir)
        }

        method_sectors <- utils::read.csv2(
          method$sectors_file,
          stringsAsFactors = FALSE
        )
        if (!"sector.source" %in% names(method_sectors)) {
          stop(
            sprintf("%s method `%s` does not declare `sector.source`.", source_label, method$method),
            call. = FALSE
          )
        }
        method_sector_labels <- as.character(method_sectors$sector.source)
        validated_sectors <- scientific_validations[[source_name]]$sectors
        if (
          !is.null(validated_sectors) &&
          !identical(validated_sectors, method_sector_labels)
        ) {
          stop(
            sprintf(
              paste0(
                "%s source sectors do not match method `%s`; ",
                "source: %s; method: %s."
              ),
              source_label,
              method$method,
              paste(validated_sectors, collapse = ", "),
              paste(method_sector_labels, collapse = ", ")
            ),
            call. = FALSE
          )
        }
      }
      matrices <- plan$configuration[[method$method]]$matrices$computation
      euklems_files <- if (plan$mode == "calculate") {
        wlv_euklems_files(plan$root, source_io, matrices)
      } else {
        character()
      }
      if (length(euklems_files)) {
        wlv_require_files(
          euklems_files,
          sprintf("WIOD EUKLEMS data for method `%s`", method$method)
        )
        if (!is.null(scientific_validations[[source_name]])) {
          source_label <- toupper(sub("r", "", source_name, fixed = TRUE))
          required_sector_columns <- c("euklems.capital", "euklems.sector")
          missing_sector_columns <- setdiff(required_sector_columns, names(method_sectors))
          if (length(missing_sector_columns)) {
            stop(
              sprintf(
                "%s method `%s` lacks EU KLEMS sector columns: %s.",
                source_label,
                method$method,
                paste(missing_sector_columns, collapse = ", ")
              ),
              call. = FALSE
            )
          }
          euklems_validator <- get0(
            sprintf("wlv_validate_%s_euklems", method$source),
            envir = validator_environments[[source_name]],
            mode = "function",
            inherits = TRUE
          )
          if (!is.function(euklems_validator)) {
            euklems_validator <- get0(
              sprintf("wlv_validate_%s_euklems", method$source),
              mode = "function",
              inherits = TRUE
            )
          }
          if (!is.function(euklems_validator)) {
            stop(
              sprintf("The %s EU KLEMS validator is not loaded.", source_label),
              call. = FALSE
            )
          }
          euklems_validator(
            euklems_files,
            required_variables = method_sectors$euklems.capital,
            required_sectors = method_sectors$euklems.sector
          )
        }
      }
      method_data$source_io <- source_io
    }

    if (plan$mode == "recalculate") {
      result_dir <- file.path(plan$root, "results", method$method)
      result_required <- file.path(
        result_dir,
        c(
          "m_countries.fst", "m_countries.fst.meta",
          "sea_sectors.fst", "sea_sectors.fst.meta"
        )
      )
      wlv_require_files(result_required, sprintf("results for method `%s`", method$method))

      optional_country <- file.path(result_dir, "sea_countries.fst")
      if (file.exists(optional_country)) {
        wlv_require_files(
          paste0(optional_country, ".meta"),
          sprintf("country result metadata for method `%s`", method$method)
        )
      }

      if (plan$at_stage <= 4L) {
        result_io <- wlv_list_io_files(result_dir)
        if (!length(result_io)) {
          stop(
            sprintf("No result m_io*.fst files exist for method `%s`.", method$method),
            call. = FALSE
          )
        }
        wlv_require_files(
          paste0(result_io, ".meta"),
          sprintf("result matrix metadata for method `%s`", method$method)
        )
        source_keys <- vapply(source_io, wlv_io_period_key, character(1))
        result_keys <- vapply(result_io, wlv_io_period_key, character(1))
        if (anyDuplicated(source_keys) || anyDuplicated(result_keys)) {
          stop(
            sprintf("Matrix periods are duplicated for method `%s`.", method$method),
            call. = FALSE
          )
        }
        source_order <- match(result_keys, source_keys)
        if (anyNA(source_order) || length(source_keys) != length(result_keys)) {
          stop(
            sprintf("Source and result matrix years do not correspond for method `%s`.", method$method),
            call. = FALSE
          )
        }
        method_data$source_io <- source_io[source_order]
        method_data$result_io <- result_io
      }
    }

    data_plan[[index]] <- method_data
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

wlv_new_run_environment <- function(
    values = list(),
    parent = parent.env(globalenv())) {
  if (!is.list(values) || (length(values) && is.null(names(values)))) {
    stop("`values` must be a named list.", call. = FALSE)
  }

  run_environment <- new.env(parent = parent)
  if (length(values)) {
    list2env(values, envir = run_environment)
  }
  run_environment$source <- local({
    target <- run_environment
    function(file, ...) {
      arguments <- list(...)
      arguments$local <- target
      do.call(base::source, c(list(file = file), arguments))
    }
  })
  run_environment
}

wlv_run_script <- function(
    script,
    values = list(),
    cluster = NULL,
    runner = sys.source,
    preamble = character(),
    root = NULL) {
  # Preserve the binding on the sequential path: `$<- NULL` would remove it.
  values["my.cluster"] <- list(cluster)
  run_environment <- wlv_new_run_environment(values)
  label <- if (!is.null(values$method_version)) {
    sprintf("Method `%s`", values$method_version)
  } else {
    sprintf("Script `%s`", script)
  }

  tryCatch(
    {
      if (!is.null(root)) {
        old_working_directory <- setwd(root)
        on.exit(setwd(old_working_directory), add = TRUE)
      }
      for (preamble_script in preamble) {
        sys.source(preamble_script, envir = run_environment)
      }
      runner(script, envir = run_environment)
      run_environment
    },
    error = function(error) {
      if (inherits(error, "wlv_contract_error")) {
        stop(error)
      }
      wrapped <- simpleError(
        sprintf("%s failed: %s", label, conditionMessage(error)),
        call = conditionCall(error)
      )
      attr(wrapped, "parent") <- error
      stop(wrapped)
    }
  )
}

wlv_prepare_sources <- function(plan) {
  unique_sources <- !duplicated(plan$methods$source)
  preparers <- plan$methods$preparer[unique_sources]
  functions_script <- file.path(plan$root, "R", "lib", "functions.R")
  invisible(lapply(preparers, function(preparer) {
    wlv_run_script(
      preparer,
      preamble = functions_script,
      root = plan$root
    )
  }))
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
  staging <- tempfile(
    pattern = sprintf(".staging-%s-", method),
    tmpdir = results_root
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

wlv_publish_result_staging <- function(staging, final, results_root) {
  if (!dir.exists(staging) || !wlv_result_path_is_within(staging, results_root)) {
    stop("Result staging directory is missing or unsafe.", call. = FALSE)
  }
  final_parent <- dirname(final)
  if (!identical(
    normalizePath(final_parent, winslash = "/", mustWork = TRUE),
    normalizePath(results_root, winslash = "/", mustWork = TRUE)
  )) {
    stop("Refusing to publish results outside the results directory.", call. = FALSE)
  }

  backup <- tempfile(
    pattern = sprintf(".backup-%s-", basename(final)),
    tmpdir = results_root
  )
  had_final <- dir.exists(final)
  if (had_final && !file.rename(final, backup)) {
    stop(sprintf("Could not move existing results `%s` to a backup.", final), call. = FALSE)
  }

  installed <- FALSE
  complete <- FALSE
  on.exit({
    if (!complete) {
      recovery_failures <- character()
      if (installed && dir.exists(final) && !dir.exists(staging)) {
        if (!file.rename(final, staging)) {
          recovery_failures <- c(
            recovery_failures,
            sprintf("new result remains at `%s`", final)
          )
        }
      }
      if (had_final && dir.exists(backup) && !dir.exists(final)) {
        if (!file.rename(backup, final)) {
          recovery_failures <- c(
            recovery_failures,
            sprintf("prior result remains at `%s`", backup)
          )
        }
      }
      if (length(recovery_failures)) {
        stop(
          sprintf(
            paste0(
              "Result promotion failed and automatic restoration did not ",
              "complete; manual recovery required: %s."
            ),
            paste(recovery_failures, collapse = "; ")
          ),
          call. = FALSE
        )
      }
    }
  }, add = TRUE)
  if (!file.rename(staging, final)) {
    restored <- !had_final ||
      (dir.exists(backup) && !dir.exists(final) && file.rename(backup, final))
    complete <- TRUE
    if (!restored) {
      stop(
        sprintf(
          paste0(
            "Result promotion failed and automatic restoration did not ",
            "complete; manual recovery required: prior result remains at `%s`."
          ),
          backup
        ),
        call. = FALSE
      )
    }
    stop(sprintf("Could not promote staged results to `%s`.", final), call. = FALSE)
  }
  installed <- TRUE
  transaction <- list(
    staging = staging,
    final = final,
    backup = backup,
    had_final = had_final,
    installed = installed,
    results_root = results_root
  )
  complete <- TRUE
  transaction
}

wlv_rollback_result_staging <- function(transaction) {
  if (is.null(transaction)) {
    return(invisible(NULL))
  }
  staging <- transaction$staging
  final <- transaction$final
  backup <- transaction$backup
  results_root <- transaction$results_root
  if (!wlv_result_path_is_within(final, results_root) ||
      !wlv_result_path_is_within(staging, results_root) ||
      !wlv_result_path_is_within(backup, results_root)) {
    stop("Refusing to roll back unsafe result paths.", call. = FALSE)
  }
  if (isTRUE(transaction$installed) && dir.exists(final)) {
    if (dir.exists(staging) || !file.rename(final, staging)) {
      stop(
        sprintf(
          "Could not move new results `%s` back to staging; the new results remain published.",
          final
        ),
        call. = FALSE
      )
    }
  }
  if (isTRUE(transaction$had_final) && dir.exists(backup)) {
    if (dir.exists(final) || !file.rename(backup, final)) {
      recovered_new <- !dir.exists(final) && dir.exists(staging) &&
        file.rename(staging, final)
      stop(
        sprintf(
          paste0(
            "Could not restore prior results `%s`; %s."
          ),
          final,
          if (recovered_new) {
            "the new results were restored to keep the published generation coherent"
          } else {
            "manual recovery is required before another run"
          }
        ),
        call. = FALSE
      )
    }
  }
  invisible(transaction)
}

wlv_reinstate_new_result_staging <- function(transaction) {
  if (is.null(transaction)) {
    return(invisible(NULL))
  }
  staging <- transaction$staging
  final <- transaction$final
  backup <- transaction$backup
  results_root <- transaction$results_root
  if (!wlv_result_path_is_within(final, results_root) ||
      !wlv_result_path_is_within(staging, results_root) ||
      !wlv_result_path_is_within(backup, results_root)) {
    stop("Refusing to reinstate unsafe result paths.", call. = FALSE)
  }
  if (!dir.exists(staging)) {
    stop("The new result staging directory is unavailable for recovery.", call. = FALSE)
  }
  moved_prior <- FALSE
  complete <- FALSE
  on.exit({
    if (!complete && moved_prior && dir.exists(backup) && !dir.exists(final)) {
      file.rename(backup, final)
    }
  }, add = TRUE)
  if (dir.exists(final)) {
    if (dir.exists(backup) || !file.rename(final, backup)) {
      stop("Could not retain prior results while reinstating the new generation.", call. = FALSE)
    }
    moved_prior <- TRUE
  }
  if (!file.rename(staging, final)) {
    stop("Could not reinstate the new result generation.", call. = FALSE)
  }
  complete <- TRUE
  invisible(transaction)
}

wlv_finalize_result_staging <- function(transaction) {
  if (is.null(transaction) || !isTRUE(transaction$had_final)) {
    return(invisible(transaction))
  }
  backup <- transaction$backup
  results_root <- transaction$results_root
  if (dir.exists(backup)) {
    if (!wlv_result_path_is_within(backup, results_root) ||
        !startsWith(basename(backup), ".backup-")) {
      stop(sprintf("Refusing to remove unsafe backup path `%s`.", backup), call. = FALSE)
    }
    unlink(backup, recursive = TRUE, force = TRUE)
    if (dir.exists(backup)) {
      warning(sprintf("Could not remove old result backup `%s`.", backup), call. = FALSE)
    }
  }
  invisible(transaction)
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
  script <- file.path(plan$root, record$script[[1L]])
  factory_name <- record$factory[[1L]]
  policy_environment <- new.env(parent = environment(wlv_load_run_missingness_policy))
  sys.source(script, envir = policy_environment)
  factory <- get0(factory_name, envir = policy_environment, mode = "function", inherits = TRUE)
  if (!is.function(factory)) {
    stop(
      sprintf("Missingness policy `%s` factory `%s` is unavailable.", policy_id, factory_name),
      call. = FALSE
    )
  }
  policy <- factory()
  if (!inherits(policy, "wlv_missingness_policy") ||
      !identical(policy$policy_id, policy_id) ||
      !identical(policy$source, method$source[[1L]])) {
    stop(
      sprintf("Missingness policy factory `%s` returned an incompatible policy.", factory_name),
      call. = FALSE
    )
  }
  policy
}

wlv_run_method <- function(plan, method, cluster = NULL) {
  method_record <- plan$methods[match(method, plan$methods$method), , drop = FALSE]
  final_result_dir <- file.path(plan$root, "results", method)
  results_root <- file.path(plan$root, "results")
  result_lock <- wlv_acquire_result_lock(results_root, method)
  lock_open <- TRUE
  on.exit({
    if (lock_open) {
      try(wlv_release_result_lock(result_lock, results_root), silent = TRUE)
    }
  }, add = TRUE)
  existing_result_dir <- if (dir.exists(final_result_dir)) {
    normalizePath(final_result_dir, winslash = "/", mustWork = TRUE)
  } else {
    normalizePath(final_result_dir, winslash = "/", mustWork = FALSE)
  }
  staging <- wlv_create_result_staging(
    plan$root,
    method,
    existing = if (plan$mode == "recalculate") existing_result_dir else NULL
  )
  staging_open <- TRUE
  on.exit({
    if (staging_open && dir.exists(staging)) {
      try(wlv_remove_result_staging(staging, results_root), silent = TRUE)
    }
  }, add = TRUE)

  missingness_policy <- wlv_load_run_missingness_policy(plan, method_record)
  contract_runtime <- wlv_new_contract_runtime(
    method = method,
    source = method_record$source[[1L]],
    policy = missingness_policy
  )
  run_data <- plan$data[[method]]
  if (plan$mode == "recalculate") {
    wlv_load_contract_report(
      contract_runtime,
      file.path(staging, "_anomalies.csv")
    )
    if (length(run_data$result_io)) {
      run_data$result_io <- file.path(staging, basename(run_data$result_io))
      missing_snapshot_io <- run_data$result_io[!file.exists(run_data$result_io)]
      if (length(missing_snapshot_io)) {
        stop(
          sprintf(
            "The recalculation snapshot lacks result matrix file(s): %s.",
            paste(basename(missing_snapshot_io), collapse = ", ")
          ),
          call. = FALSE
        )
      }
    }
  }
  values <- list(
    method_version = method,
    methods = plan$method_names,
    wlv_data = run_data,
    wlv_parameters = plan$configuration[[method]],
    wlv_result_dir = staging,
    wlv_existing_result_dir = if (plan$mode == "recalculate") {
      staging
    } else {
      existing_result_dir
    },
    wlv_missingness_policy = missingness_policy,
    wlv_contract_runtime = contract_runtime
  )
  script <- file.path(plan$root, "R", "lib", "computations.R")
  if (plan$mode == "recalculate") {
    values$at_stage <- plan$at_stage
    values["sea_vars"] <- list(plan$sea_vars)
    script <- file.path(plan$root, "R", "lib", "re_computations.R")
  }
  run_environment <- tryCatch(
    {
      run_environment <- wlv_run_script(
        script,
        values = values,
        cluster = cluster,
        preamble = file.path(
          plan$root,
          "R",
          "lib",
          c(
            "functions.R", "missingness.R", "leontief_diagnostics.R",
            "scientific_validation.R", "result_contracts.R"
          )
        ),
        root = plan$root
      )
      wlv_write_contract_states(
        contract_runtime,
        staging,
        reader = run_environment$read_fst_array
      )
      wlv_write_contract_report(
        contract_runtime,
        file.path(staging, "_anomalies.csv")
      )
      unit_contract_csv <- list()
      unit_contract_id <- method_record$unit_contract[[1L]]
      if (nzchar(unit_contract_id)) {
        effective_unit_contract <- wlv_catalog_unit_contract_sidecar(
          plan$catalog,
          unit_contract_id,
          indicators = as.character(run_environment$sea_variables$names),
          require_exact = identical(
            method_record$status[[1L]],
            "stable"
          )
        )
        wlv_write_result_csv(
          effective_unit_contract,
          file.path(staging, "_unit_contract.csv")
        )
        unit_contract_csv <- list(
          `_unit_contract.csv` = effective_unit_contract
        )
      }
      scientific_csv <- if (
        exists(
          "wlv_scientific_diagnostics",
          envir = run_environment,
          inherits = FALSE
        )
      ) {
        get(
          "wlv_scientific_diagnostics",
          envir = run_environment,
          inherits = FALSE
        )
      } else {
        list()
      }
      expected_metadata <- wlv_method_result_metadata(
        parameters = run_environment$parameters,
        assumptions = run_environment$assumptions,
        matrices = run_environment$matrices,
        solutions = run_environment$sea_variables,
        sectors = run_environment$sectors,
        meta_indicators = run_environment$meta_indicators,
        extra_csv = c(scientific_csv, unit_contract_csv)
      )
      scientific_checks <- wlv_validate_staged_results(
        staging,
        method = method,
        mode = plan$mode,
        runtime = contract_runtime,
        expected_metadata = expected_metadata,
        at_stage = if (plan$mode == "recalculate") plan$at_stage else NULL,
        reader = run_environment$read_fst_array
      )
      scientific_diagnostics <- get0(
        "wlv_scientific_diagnostics",
        envir = run_environment,
        inherits = FALSE,
        ifnotfound = list()
      )
      scientific_diagnostics[["_scientific_checks.csv"]] <- scientific_checks
      assign(
        "wlv_scientific_diagnostics",
        scientific_diagnostics,
        envir = run_environment
      )
      run_environment
    },
    error = function(error) {
      wlv_write_failed_contract_report(
        contract_runtime,
        results_root = results_root,
        error = error
      )
      stop(error)
    }
  )
  metadata_transaction <- NULL
  result_transaction <- NULL
  publication_committed <- FALSE
  on.exit({
    if (!publication_committed) {
      result_rolled_back <- tryCatch(
        {
          wlv_rollback_result_staging(result_transaction)
          TRUE
        },
        error = function(error) {
          message("Result rollback warning: ", conditionMessage(error))
          FALSE
        }
      )
      if (result_rolled_back) {
        metadata_rolled_back <- tryCatch(
          {
            wlv_rollback_global_metadata(metadata_transaction)
            TRUE
          },
          error = function(error) {
            message("Global metadata rollback warning: ", conditionMessage(error))
            FALSE
          }
        )
        if (!metadata_rolled_back && !is.null(result_transaction)) {
          reinstated <- tryCatch(
            {
              wlv_reinstate_new_result_staging(result_transaction)
              staging_open <- FALSE
              wlv_finalize_result_staging(result_transaction)
              TRUE
            },
            error = function(error) {
              message("Result recovery warning: ", conditionMessage(error))
              FALSE
            }
          )
          if (reinstated) {
            message(
              paste0(
                "The new result generation was retained because global ",
                "metadata rollback did not complete."
              )
            )
          } else {
            message("Manual result/metadata recovery is required before another run.")
          }
        }
      } else {
        message(
          paste0(
            "Global metadata was left on the new generation because result ",
            "rollback did not complete."
          )
        )
      }
    }
  }, add = TRUE)
  cleanup_warnings <- character()
  suspendInterrupts({
    metadata_transaction <- wlv_begin_global_metadata_transaction(
      run_environment,
      results_root
    )
    result_transaction <- wlv_publish_result_staging(
      staging,
      final_result_dir,
      results_root
    )
    staging_open <- FALSE
    publication_committed <- TRUE
    withCallingHandlers(
      {
        wlv_finalize_result_staging(result_transaction)
        wlv_finalize_global_metadata(metadata_transaction)
      },
      warning = function(warning) {
        cleanup_warnings <<- c(cleanup_warnings, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    )
  })
  if (length(cleanup_warnings)) {
    message(
      "Published successfully; cleanup warning(s): ",
      paste(unique(cleanup_warnings), collapse = " ")
    )
  }
  lock_released <- tryCatch(
    {
      wlv_release_result_lock(result_lock, results_root)
      TRUE
    },
    error = function(error) {
      message(
        paste0(
          "Published successfully; result lock cleanup warning: ",
          conditionMessage(error),
          " Verify and remove the stale lock before the next run."
        )
      )
      FALSE
    }
  )
  if (lock_released) {
    lock_open <- FALSE
  }
  run_environment
}

wlv_run_paper <- function(plan, run_environment) {
  old_working_directory <- setwd(plan$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  tryCatch(
    sys.source(plan$paper_script, envir = run_environment),
    error = function(error) {
      stop(
        sprintf("Paper `%s` failed: %s", plan$papern, conditionMessage(error)),
        call. = FALSE
      )
    }
  )
}
