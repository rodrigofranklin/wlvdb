wlv_paper_scalar_character <- function(value, name, allow_empty = FALSE) {
  valid <- is.character(value) && length(value) == 1L && !is.na(value)
  if (!allow_empty) {
    valid <- valid && nzchar(value)
  }
  if (!valid) {
    stop(sprintf("`%s` must be one character value.", name), call. = FALSE)
  }
  value
}

wlv_paper_id <- function(value, name = "paper") {
  if (
    length(value) != 1L || !is.numeric(value) || is.na(value) ||
    !is.finite(value) || value != floor(value) || value < 0L ||
    value > .Machine$integer.max
  ) {
    stop(sprintf("`%s` must be one non-negative integer.", name), call. = FALSE)
  }
  as.integer(value)
}

wlv_paper_spec <- function(
    id,
    title,
    run,
    required_artifacts,
    packages = character(),
    output = character(),
    supported = TRUE,
    reason = "") {
  id <- wlv_paper_id(id, "id")
  title <- wlv_paper_scalar_character(title, "title")
  if (length(supported) != 1L || !is.logical(supported) || is.na(supported)) {
    stop("`supported` must be TRUE or FALSE.", call. = FALSE)
  }
  fields <- list(
    required_artifacts = required_artifacts,
    packages = packages,
    output = output
  )
  invalid <- names(fields)[vapply(fields, function(value) {
    !is.character(value) || anyNA(value) || any(!nzchar(value)) ||
      anyDuplicated(value)
  }, logical(1L))]
  if (length(invalid)) {
    stop(
      sprintf(
        "Paper spec field(s) must contain unique, non-empty strings: %s.",
        paste(invalid, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (isTRUE(supported) && !is.function(run)) {
    stop("A supported paper spec must provide a `run` function.", call. = FALSE)
  }
  if (!isTRUE(supported) && !is.null(run)) {
    stop("An unsupported paper spec cannot provide a `run` function.", call. = FALSE)
  }
  reason <- wlv_paper_scalar_character(
    reason,
    "reason",
    allow_empty = isTRUE(supported)
  )

  structure(
    list(
      id = id,
      title = title,
      supported = supported,
      reason = reason,
      required_artifacts = required_artifacts,
      packages = packages,
      output = output,
      run = run
    ),
    class = c("wlv_paper_spec", "list")
  )
}

wlv_unsupported_paper_spec <- function(id, title, reason) {
  wlv_paper_spec(
    id = id,
    title = title,
    run = NULL,
    required_artifacts = character(),
    supported = FALSE,
    reason = reason
  )
}

wlv_paper_assert_spec <- function(value) {
  if (!inherits(value, "wlv_paper_spec")) {
    stop("Paper definitions must be created by `wlv_paper_spec()`.", call. = FALSE)
  }
  invisible(value)
}

wlv_paper_registry <- function(...) {
  specs <- list(...)
  if (length(specs) == 1L && is.list(specs[[1L]]) &&
      !inherits(specs[[1L]], "wlv_paper_spec")) {
    specs <- specs[[1L]]
  }
  if (!length(specs)) {
    stop("A paper registry cannot be empty.", call. = FALSE)
  }
  invisible(lapply(specs, wlv_paper_assert_spec))
  ids <- vapply(specs, function(spec) as.character(spec$id), character(1L))
  duplicated_ids <- unique(ids[duplicated(ids)])
  if (length(duplicated_ids)) {
    stop(
      sprintf(
        "Duplicate paper id(s): %s.",
        paste(duplicated_ids, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  names(specs) <- ids
  structure(specs, class = c("wlv_paper_registry", "list"))
}

wlv_default_paper_registry <- function() {
  definition_environment <- environment()
  required_factories <- c(
    "wlv_paper_0_spec",
    "wlv_paper_3_spec",
    "wlv_paper_4_spec"
  )
  missing <- required_factories[!vapply(required_factories, function(factory) {
    exists(
      factory,
      envir = definition_environment,
      mode = "function",
      inherits = TRUE
    )
  }, logical(1L))]
  if (length(missing)) {
    stop(
      sprintf(
        "Paper definition(s) were not loaded: %s.",
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  wlv_paper_registry(lapply(required_factories, function(factory) {
    get(
      factory,
      envir = definition_environment,
      mode = "function",
      inherits = TRUE
    )()
  }))
}

wlv_paper_assert_registry <- function(registry) {
  if (!inherits(registry, "wlv_paper_registry") || !length(registry)) {
    stop("`registry` must be created by `wlv_paper_registry()`.", call. = FALSE)
  }
  invisible(registry)
}

wlv_resolve_paper <- function(papern, registry = wlv_default_paper_registry()) {
  papern <- wlv_paper_id(papern, "papern")
  wlv_paper_assert_registry(registry)
  key <- as.character(papern)
  if (!key %in% names(registry)) {
    supported <- vapply(registry, `[[`, logical(1L), "supported")
    supported_ids <- names(registry)[supported]
    stop(
      sprintf(
        "Paper `%s` is not registered. Supported paper(s): %s.",
        key,
        if (length(supported_ids)) paste(supported_ids, collapse = ", ") else "none"
      ),
      call. = FALSE
    )
  }
  spec <- registry[[key]]
  if (!isTRUE(spec$supported)) {
    stop(
      sprintf("Paper `%s` is unsupported: %s", key, spec$reason),
      call. = FALSE
    )
  }
  spec
}

wlv_validate_paper_request <- function(
    papern,
    prepaper,
    registry = wlv_default_paper_registry()) {
  papern <- wlv_paper_id(papern, "papern")
  if (length(prepaper) != 1L || !is.logical(prepaper) || is.na(prepaper)) {
    stop("`prepaper` must be TRUE or FALSE.", call. = FALSE)
  }
  wlv_resolve_paper(papern, registry = registry)
}

wlv_validate_paper_method_compatibility <- function(
    paper,
    prepaper,
    methods,
    indicators) {
  wlv_paper_assert_spec(paper)
  if (!isTRUE(prepaper)) {
    return(invisible(TRUE))
  }
  if (!is.data.frame(methods) ||
      !all(c("method", "source", "year_start", "year_end") %in% names(methods)) ||
      !nrow(methods)) {
    stop("Paper preflight requires a non-empty method plan.", call. = FALSE)
  }
  method_names <- methods$method
  if (!is.list(indicators) ||
      !identical(names(indicators), method_names) ||
      any(!vapply(indicators, is.character, logical(1L)))) {
    stop(
      "Paper preflight requires output indicators for every selected method.",
      call. = FALSE
    )
  }

  if (identical(paper$id, 0L)) {
    required_year <- 2009L
    lacks_year <- is.na(methods$year_start) | is.na(methods$year_end) |
      methods$year_start > required_year | methods$year_end < required_year
    if (any(lacks_year)) {
      stop(
        sprintf(
          "Paper `0` requires year 2009; unavailable for: %s.",
          paste(method_names[lacks_year], collapse = ", ")
        ),
        call. = FALSE
      )
    }
    sources <- unique(methods$source)
    if (length(sources) != 1L) {
      stop(
        sprintf(
          paste0(
            "Paper `0` is incompatible with methods from different source ",
            "contracts: %s."
          ),
          paste(sprintf("%s=%s", method_names, methods$source), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    reference <- indicators[[1L]]
    compatible <- vapply(indicators, function(value) {
      !anyDuplicated(value) && setequal(value, reference)
    }, logical(1L))
    if (anyDuplicated(reference) || !all(compatible)) {
      stop(
        sprintf(
          "Paper `0` requires compatible indicator sets; incompatible: %s.",
          paste(method_names[!compatible], collapse = ", ")
        ),
        call. = FALSE
      )
    }

    required <- c(
      "gross_output.s.us",
      "gross_output.s.du",
      "gdp.s.us",
      "gdp.s.du",
      "surplus_value.empe.r.pc",
      "gdp.s.mv"
    )
    non_ochoa <- !grepl("ochoa", method_names, fixed = TRUE)
    required_by_method <- lapply(seq_along(method_names), function(index) {
      c(
        required,
        if (non_ochoa[[index]]) {
          c(
            "surplus_value.empe_hs.r.pc",
            "surplus_value.empe_ms.r.pc",
            "surplus_value.empe_ls.r.pc"
          )
        } else {
          character()
        }
      )
    })
    missing <- lapply(seq_along(method_names), function(index) {
      setdiff(required_by_method[[index]], indicators[[index]])
    })
    invalid <- lengths(missing) > 0L
    if (any(invalid)) {
      details <- vapply(which(invalid), function(index) {
        sprintf(
          "%s=[%s]",
          method_names[[index]],
          paste(missing[[index]], collapse = ", ")
        )
      }, character(1L))
      stop(
        sprintf(
          "Paper `0` requires missing output indicator(s): %s.",
          paste(details, collapse = "; ")
        ),
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

wlv_paper_safe_component <- function(value, name) {
  value <- wlv_paper_scalar_character(value, name)
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", value)) {
    stop(sprintf("`%s` is not a safe path component.", name), call. = FALSE)
  }
  value
}

wlv_paper_path_within <- function(path, root) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (.Platform$OS.type == "windows") {
    path <- tolower(path)
    root <- tolower(root)
  }
  identical(path, root) || startsWith(path, paste0(root, "/"))
}

wlv_new_paper_context <- function(
    methods,
    result_dirs,
    release_dir,
    output_dir,
    required_artifacts,
    reader,
    workbook_writer) {
  if (
    !is.character(methods) || !length(methods) || anyNA(methods) ||
    any(!nzchar(methods)) || anyDuplicated(methods)
  ) {
    stop("`methods` must contain unique, non-empty method names.", call. = FALSE)
  }
  invisible(lapply(methods, wlv_paper_safe_component, name = "method"))
  if (
    !is.character(result_dirs) || is.null(names(result_dirs)) ||
    anyDuplicated(names(result_dirs)) || !setequal(names(result_dirs), methods)
  ) {
    stop("`result_dirs` must be named exactly by `methods`.", call. = FALSE)
  }
  result_dirs <- result_dirs[methods]
  result_dirs <- vapply(result_dirs, function(path) {
    normalizePath(path, winslash = "/", mustWork = TRUE)
  }, character(1L))
  release_dir <- normalizePath(release_dir, winslash = "/", mustWork = TRUE)
  output_dir <- normalizePath(output_dir, winslash = "/", mustWork = TRUE)
  if (
    !is.character(required_artifacts) || !length(required_artifacts) ||
    anyNA(required_artifacts) || any(!nzchar(required_artifacts)) ||
    anyDuplicated(required_artifacts)
  ) {
    stop("`required_artifacts` must contain unique artifact filenames.", call. = FALSE)
  }
  invisible(lapply(
    required_artifacts,
    wlv_paper_safe_component,
    name = "artifact"
  ))
  if (!is.function(reader)) {
    stop("`reader` must be a function.", call. = FALSE)
  }
  if (!is.function(workbook_writer)) {
    stop("`workbook_writer` must be a function.", call. = FALSE)
  }

  read_result <- local({
    context_methods <- methods
    context_dirs <- result_dirs
    allowed_artifacts <- required_artifacts
    context_reader <- reader
    function(method, artifact) {
      method <- wlv_paper_safe_component(method, "method")
      artifact <- wlv_paper_safe_component(artifact, "artifact")
      if (!method %in% context_methods) {
        stop(sprintf("Paper context has no method `%s`.", method), call. = FALSE)
      }
      if (!artifact %in% allowed_artifacts) {
        stop(
          sprintf("Paper context does not authorize artifact `%s`.", artifact),
          call. = FALSE
        )
      }
      path <- file.path(context_dirs[[method]], artifact)
      if (!file.exists(path)) {
        stop(
          sprintf("Result artifact is missing for `%s`: %s.", method, artifact),
          call. = FALSE
        )
      }
      context_reader(path)
    }
  })

  write_workbook <- local({
    context_output_dir <- output_dir
    context_writer <- workbook_writer
    function(filename, sheets) {
      filename <- wlv_paper_safe_component(filename, "filename")
      if (!is.list(sheets) || !length(sheets)) {
        stop("`sheets` must be a non-empty list.", call. = FALSE)
      }
      path <- file.path(context_output_dir, filename)
      extension <- tools::file_ext(filename)
      staged <- tempfile(
        pattern = paste0(".", tools::file_path_sans_ext(filename), "-"),
        tmpdir = context_output_dir,
        fileext = if (nzchar(extension)) paste0(".", extension) else ""
      )
      staged_open <- TRUE
      backup <- NULL
      backup_open <- FALSE
      on.exit({
        if (staged_open && file.exists(staged)) {
          unlink(staged, force = TRUE)
        }
        if (backup_open && !is.null(backup) && file.exists(backup) &&
            !file.exists(path)) {
          file.rename(backup, path)
        }
      }, add = TRUE)

      context_writer(sheets, staged)
      info <- file.info(staged)
      if (!file.exists(staged) || isTRUE(info$isdir) ||
          is.na(info$size) || info$size <= 0) {
        stop(
          "Workbook writer did not create a non-empty regular output.",
          call. = FALSE
        )
      }

      if (file.exists(path)) {
        backup <- tempfile(
          pattern = paste0(".", filename, "-backup-"),
          tmpdir = context_output_dir
        )
        if (!file.rename(path, backup)) {
          stop("Could not stage the previous workbook for replacement.", call. = FALSE)
        }
        backup_open <- TRUE
      }
      if (!file.rename(staged, path)) {
        if (backup_open && file.exists(backup) && !file.exists(path)) {
          restored <- file.rename(backup, path)
          if (isTRUE(restored)) backup_open <- FALSE
        }
        stop("Could not atomically promote the paper workbook.", call. = FALSE)
      }
      staged_open <- FALSE
      if (backup_open) {
        unlink(backup, force = TRUE)
        if (file.exists(backup)) {
          stop("Could not remove the replaced workbook backup.", call. = FALSE)
        }
        backup_open <- FALSE
      }
      normalizePath(path, winslash = "/", mustWork = TRUE)
    }
  })

  context <- new.env(parent = emptyenv())
  context$methods <- local({
    context_methods <- methods
    function() context_methods
  })
  context$read_result <- read_result
  context$write_workbook <- write_workbook
  context$release_dir <- local({
    context_release_dir <- release_dir
    function() context_release_dir
  })
  class(context) <- c("wlv_paper_context", "environment")
  lockEnvironment(context, bindings = TRUE)
  context
}

wlv_paper_assert_context <- function(context) {
  if (!inherits(context, "wlv_paper_context") || !is.environment(context) ||
      !environmentIsLocked(context)) {
    stop("`context` must be a locked WLV paper context.", call. = FALSE)
  }
  invisible(context)
}

wlv_paper_result_dirs_from_release <- function(
    project_root,
    release,
    selected_methods = NULL) {
  project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  results_root <- normalizePath(
    file.path(project_root, "results"),
    winslash = "/",
    mustWork = TRUE
  )
  if (!is.list(release) || is.null(release$manifest) || is.null(release$root)) {
    stop("`release` must be a committed WLV release.", call. = FALSE)
  }
  release_root <- normalizePath(release$root, winslash = "/", mustWork = TRUE)
  if (!wlv_paper_path_within(release_root, results_root)) {
    stop("Committed release is outside the results root.", call. = FALSE)
  }
  runs <- release$manifest$runs
  if (!is.list(runs) || !length(runs)) {
    stop("Committed release does not contain any method runs.", call. = FALSE)
  }
  methods <- vapply(runs, function(record) {
    wlv_paper_safe_component(record$method, "release method")
  }, character(1L))
  if (anyDuplicated(methods)) {
    stop("Committed release contains duplicate methods.", call. = FALSE)
  }
  result_dirs <- vapply(runs, function(record) {
    manifest_path <- wlv_paper_scalar_character(
      record$manifest_path,
      "manifest_path"
    )
    manifest <- file.path(results_root, manifest_path)
    if (!file.exists(manifest)) {
      stop(sprintf("Committed run manifest is missing: %s.", manifest_path), call. = FALSE)
    }
    result_dir <- normalizePath(dirname(manifest), winslash = "/", mustWork = TRUE)
    if (!wlv_paper_path_within(result_dir, results_root)) {
      stop("Committed run is outside the results root.", call. = FALSE)
    }
    result_dir
  }, character(1L))
  names(result_dirs) <- methods
  if (!is.null(selected_methods)) {
    if (!is.character(selected_methods) || !length(selected_methods) ||
        anyNA(selected_methods) || any(!nzchar(selected_methods)) ||
        anyDuplicated(selected_methods)) {
      stop(
        "`selected_methods` must contain unique, non-empty method names.",
        call. = FALSE
      )
    }
    invisible(lapply(
      selected_methods,
      wlv_paper_safe_component,
      name = "selected method"
    ))
    missing <- setdiff(selected_methods, methods)
    if (length(missing)) {
      stop(
        sprintf(
          "Committed release has no selected method(s): %s.",
          paste(missing, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    methods <- selected_methods
    result_dirs <- result_dirs[methods]
  }
  list(
    methods = methods,
    result_dirs = result_dirs,
    release_dir = release_root,
    output_dir = results_root
  )
}

wlv_new_release_paper_context <- function(
    project_root,
    release,
    paper,
    reader,
    selected_methods = NULL,
    workbook_writer = function(sheets, path) {
      writexl::write_xlsx(sheets, path = path)
    }) {
  wlv_paper_assert_spec(paper)
  if (!isTRUE(paper$supported)) {
    stop(sprintf("Paper `%s` is unsupported: %s", paper$id, paper$reason), call. = FALSE)
  }
  release_context <- wlv_paper_result_dirs_from_release(
    project_root,
    release,
    selected_methods = selected_methods
  )
  do.call(
    wlv_new_paper_context,
    c(
      release_context,
      list(
        required_artifacts = paper$required_artifacts,
        reader = reader,
        workbook_writer = workbook_writer
      )
    )
  )
}

wlv_run_paper_task <- function(
    paper,
    context,
    namespace_checker = function(package) {
      requireNamespace(package, quietly = TRUE)
    }) {
  wlv_paper_assert_spec(paper)
  wlv_paper_assert_context(context)
  if (!isTRUE(paper$supported)) {
    stop(sprintf("Paper `%s` is unsupported: %s", paper$id, paper$reason), call. = FALSE)
  }
  available <- vapply(paper$packages, namespace_checker, logical(1L))
  missing <- paper$packages[!available]
  if (length(missing)) {
    stop(
      sprintf(
        "Paper `%s` requires missing package(s): %s.",
        paper$id,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  tryCatch(
    paper$run(context),
    error = function(error) {
      stop(
        sprintf("Paper `%s` failed: %s", paper$id, conditionMessage(error)),
        call. = FALSE
      )
    }
  )
}

wlv_run_staged_paper <- function(
    plan,
    run_environments,
    release_staging,
    reader = read_fst_array,
    workbook_writer = function(sheets, path) {
      writexl::write_xlsx(sheets, path = path)
    }) {
  if (!isTRUE(plan$prepaper)) {
    return(NULL)
  }
  paper <- if (!is.null(plan$paper_task)) {
    plan$paper_task
  } else {
    wlv_resolve_paper(plan$papern)
  }
  wlv_paper_assert_spec(paper)
  if (!is.list(run_environments) || !length(run_environments)) {
    stop("Paper staging requires the selected immutable method runs.", call. = FALSE)
  }
  methods <- vapply(run_environments, function(run_environment) {
    if (!is.environment(run_environment) ||
        is.null(run_environment$wlv_run_manifest$method) ||
        is.null(run_environment$wlv_run_dir)) {
      stop("Paper staging received an invalid method run.", call. = FALSE)
    }
    wlv_paper_safe_component(
      run_environment$wlv_run_manifest$method,
      "run method"
    )
  }, character(1L))
  if (anyDuplicated(methods) || !identical(sort(methods), sort(plan$method_names))) {
    stop(
      "Paper staging runs must match the selected methods exactly.",
      call. = FALSE
    )
  }
  result_dirs <- vapply(run_environments, function(run_environment) {
    normalizePath(run_environment$wlv_run_dir, winslash = "/", mustWork = TRUE)
  }, character(1L))
  names(result_dirs) <- methods
  result_dirs <- result_dirs[plan$method_names]
  release_staging <- normalizePath(
    release_staging,
    winslash = "/",
    mustWork = TRUE
  )
  context <- wlv_new_paper_context(
    methods = plan$method_names,
    result_dirs = result_dirs,
    release_dir = release_staging,
    output_dir = release_staging,
    required_artifacts = paper$required_artifacts,
    reader = reader,
    workbook_writer = workbook_writer
  )
  result <- wlv_run_paper_task(paper, context)
  if (!inherits(result, "wlv_paper_result") ||
      !is.character(result$output) || length(result$output) != 1L ||
      !basename(result$output) %in% paper$output ||
      !wlv_paper_path_within(result$output, release_staging)) {
    stop("Paper task returned an invalid staged output.", call. = FALSE)
  }
  result
}
