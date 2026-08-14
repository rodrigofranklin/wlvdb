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
    root = ".") {
  mode <- match.arg(mode)
  repeat_pp <- wlv_validate_flag(repeat_pp, "repeat_pp")
  prepaper <- wlv_validate_flag(prepaper, "prepaper")
  workers <- wlv_validate_workers(workers)
  papern <- wlv_validate_integer(papern, "papern", minimum = 0L)

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
  }

  root <- normalizePath(root, mustWork = TRUE)
  rows <- lapply(methods, function(method) {
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
    sources <- unique(parameters$source)
    sources <- sources[!is.na(sources) & nzchar(sources)]
    if (length(sources) != 1L || !wlv_safe_name(sources[[1]])) {
      stop(sprintf("Method `%s` must declare exactly one safe source.", method), call. = FALSE)
    }
    source <- sources[[1]]
    preparer <- file.path(root, "R", "utils", sprintf("prepare_%s_data.R", source))
    if (repeat_pp && !file.exists(preparer)) {
      stop(
        sprintf("No preparation script exists for source `%s`: %s", source, preparer),
        call. = FALSE
      )
    }

    data.frame(
      method = method,
      source = source,
      method_dir = method_dir,
      source_dir = file.path(root, "source_data", source),
      parameter_file = parameter_file,
      sectors_file = sectors_file,
      preparer = preparer,
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

  paper_script <- file.path(root, "R", "utils", "papers", sprintf("paper_%s_selection.R", papern))
  if (prepaper && !file.exists(paper_script)) {
    stop(sprintf("Paper script does not exist: %s", paper_script), call. = FALSE)
  }

  structure(
    list(
      root = root,
      mode = mode,
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

wlv_wiodr13_euklems_files <- function(root, source_io, matrix_scripts) {
  depreciation_offsets <- c(
    "wiodr13/euklems.R" = 1L,
    "wiodr13/euklems-reduction_problem.R" = 0L
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
        "WIOD13 matrix metadata must use integer years; found: %s",
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

wlv_validate_data <- function(plan, wiodr13_validator = NULL) {
  if (!inherits(plan, "wlv_run_plan")) {
    stop("`plan` must be produced by wlv_validate_request().", call. = FALSE)
  }

  data_plan <- vector("list", nrow(plan$methods))
  names(data_plan) <- plan$method_names
  wiodr13_validation <- NULL

  for (index in seq_len(nrow(plan$methods))) {
    method <- plan$methods[index, ]
    source_required <- file.path(
      method$source_dir,
      c("countries.csv", "demand.csv", "sea.fst", "sea.fst.meta")
    )
    wlv_require_files(source_required, sprintf("source data for method `%s`", method$method))

    needs_io <- plan$mode == "calculate" || plan$at_stage <= 4L
    method_data <- list()
    if (needs_io) {
      source_io <- wlv_list_io_files(method$source_dir)
      if (!length(source_io)) {
        stop(
          sprintf("No source m_io*.fst files exist for method `%s`.", method$method),
          call. = FALSE
        )
      }
      wlv_require_files(
        paste0(source_io, ".meta"),
        sprintf("source matrix metadata for method `%s`", method$method)
      )
      if (identical(method$source, "wiodr13")) {
        if (is.null(wiodr13_validation)) {
          if (is.null(wiodr13_validator)) {
            wiodr13_validator <- get0(
              "wlv_validate_wiodr13_prepared",
              mode = "function",
              inherits = TRUE
            )
          }
          if (!is.function(wiodr13_validator)) {
            stop("The WIOD13 post-preparation validator is not loaded.", call. = FALSE)
          }
          wiodr13_validation <- wiodr13_validator(method$source_dir)
        }

        method_sectors <- utils::read.csv2(
          method$sectors_file,
          stringsAsFactors = FALSE
        )
        if (!"sector.source" %in% names(method_sectors)) {
          stop(
            sprintf("WIOD13 method `%s` does not declare `sector.source`.", method$method),
            call. = FALSE
          )
        }
        method_sector_labels <- as.character(method_sectors$sector.source)
        if (!identical(wiodr13_validation$sectors, method_sector_labels)) {
          stop(
            sprintf(
              paste0(
                "WIOD13 source sectors do not match method `%s`; ",
                "source: %s; method: %s."
              ),
              method$method,
              paste(wiodr13_validation$sectors, collapse = ", "),
              paste(method_sector_labels, collapse = ", ")
            ),
            call. = FALSE
          )
        }
      }
      matrices <- plan$configuration[[method$method]]$matrices$computation
      euklems_files <- if (plan$mode == "calculate") {
        wlv_wiodr13_euklems_files(plan$root, source_io, matrices)
      } else {
        character()
      }
      if (length(euklems_files)) {
        wlv_require_files(
          euklems_files,
          sprintf("WIOD13 EUKLEMS data for method `%s`", method$method)
        )
        if (identical(method$source, "wiodr13")) {
          required_sector_columns <- c("euklems.capital", "euklems.sector")
          missing_sector_columns <- setdiff(required_sector_columns, names(method_sectors))
          if (length(missing_sector_columns)) {
            stop(
              sprintf(
                "WIOD13 method `%s` lacks EU KLEMS sector columns: %s.",
                method$method,
                paste(missing_sector_columns, collapse = ", ")
              ),
              call. = FALSE
            )
          }
          euklems_validator <- get0(
            "wlv_validate_wiodr13_euklems",
            mode = "function",
            inherits = TRUE
          )
          if (!is.function(euklems_validator)) {
            stop("The WIOD13 EU KLEMS validator is not loaded.", call. = FALSE)
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

wlv_run_method <- function(plan, method, cluster = NULL) {
  values <- list(
    method_version = method,
    methods = plan$method_names,
    wlv_data = plan$data[[method]],
    wlv_parameters = plan$configuration[[method]]
  )
  script <- file.path(plan$root, "R", "lib", "computations.R")
  if (plan$mode == "recalculate") {
    values$at_stage <- plan$at_stage
    values["sea_vars"] <- list(plan$sea_vars)
    script <- file.path(plan$root, "R", "lib", "re_computations.R")
  }
  wlv_run_script(
    script,
    values = values,
    cluster = cluster,
    preamble = file.path(plan$root, "R", "lib", "functions.R"),
    root = plan$root
  )
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
