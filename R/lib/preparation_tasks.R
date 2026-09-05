# Native source-preparation task runtime -----------------------------------
#
# This file defines the preparation contract and its transactional runner.
# It does not execute preparation while it is loaded.

wlv_preparation_abort <- function(message, class = "wlv_preparation_error") {
  condition <- structure(
    list(message = as.character(message), call = NULL),
    class = c(class, "wlv_preparation_error", "error", "condition")
  )
  stop(condition)
}

wlv_preparation_scalar_character <- function(value, name) {
  if (
    !is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value)
  ) {
    wlv_preparation_abort(
      sprintf("`%s` must be one non-empty string.", name),
      "wlv_preparation_contract_error"
    )
  }
  value
}

wlv_preparation_safe_id <- function(value, name = "source") {
  value <- wlv_preparation_scalar_character(value, name)
  if (!grepl("^[a-z][a-z0-9_.-]*$", value)) {
    wlv_preparation_abort(
      sprintf("`%s` must be a safe lower-case identifier.", name),
      "wlv_preparation_contract_error"
    )
  }
  value
}

wlv_preparation_named_functions <- function(value, name = "services") {
  if (
    !is.list(value) || is.null(names(value)) || anyNA(names(value)) ||
      any(!nzchar(names(value))) || anyDuplicated(names(value)) ||
      any(!vapply(value, is.function, logical(1L)))
  ) {
    wlv_preparation_abort(
      sprintf("`%s` must be a named list of functions.", name),
      "wlv_preparation_contract_error"
    )
  }
  value
}

wlv_preparation_parameter <- function(
    type = c(
      "character", "character_vector", "integer", "integer_vector",
      "numeric", "numeric_vector", "logical"
    ),
    required = FALSE,
    default,
    validator = NULL) {
  type <- match.arg(type)
  if (!is.logical(required) || length(required) != 1L || is.na(required)) {
    wlv_preparation_abort(
      "`required` must be TRUE or FALSE.",
      "wlv_preparation_contract_error"
    )
  }
  if (!is.null(validator) && !is.function(validator)) {
    wlv_preparation_abort(
      "`validator` must be NULL or a function.",
      "wlv_preparation_contract_error"
    )
  }
  has_default <- !missing(default)
  if (required && has_default) {
    wlv_preparation_abort(
      "A required preparation parameter cannot declare a default.",
      "wlv_preparation_contract_error"
    )
  }
  structure(
    list(
      type = type,
      required = required,
      has_default = has_default,
      default = if (has_default) default else NULL,
      validator = validator
    ),
    class = c("wlv_preparation_parameter", "list")
  )
}

wlv_validate_preparation_parameter <- function(value, parameter, name) {
  valid <- switch(
    parameter$type,
    character = is.character(value) && length(value) == 1L && !is.na(value),
    character_vector = is.character(value) && length(value) > 0L && !anyNA(value),
    integer = is.integer(value) && length(value) == 1L && !is.na(value),
    integer_vector = is.integer(value) && length(value) > 0L && !anyNA(value),
    numeric = is.numeric(value) && length(value) == 1L && !is.na(value) &&
      is.finite(value),
    numeric_vector = is.numeric(value) && length(value) > 0L &&
      !anyNA(value) && all(is.finite(value)),
    logical = is.logical(value) && length(value) == 1L && !is.na(value),
    FALSE
  )
  if (!valid) {
    wlv_preparation_abort(
      sprintf(
        "Preparation argument `%s` is incompatible with type `%s`.",
        name,
        parameter$type
      ),
      "wlv_preparation_argument_error"
    )
  }
  if (!is.null(parameter$validator)) {
    validation <- parameter$validator(value)
    if (!isTRUE(validation)) {
      detail <- if (is.character(validation) && length(validation) == 1L) {
        paste0(": ", validation)
      } else {
        ""
      }
      wlv_preparation_abort(
        sprintf("Preparation argument `%s` failed validation%s.", name, detail),
        "wlv_preparation_argument_error"
      )
    }
  }
  value
}

wlv_resolve_preparation_arguments <- function(parameters, arguments) {
  if (!is.list(parameters) || (length(parameters) &&
      (is.null(names(parameters)) || any(!nzchar(names(parameters))) ||
        anyDuplicated(names(parameters)) ||
        any(!vapply(
          parameters,
          inherits,
          logical(1L),
          "wlv_preparation_parameter"
        ))))) {
    wlv_preparation_abort(
      "Preparation parameters must be a named list of parameter contracts.",
      "wlv_preparation_contract_error"
    )
  }
  if (!is.list(arguments) || (length(arguments) &&
      (is.null(names(arguments)) || any(!nzchar(names(arguments))) ||
        anyDuplicated(names(arguments))))) {
    wlv_preparation_abort(
      "Preparation arguments must be a named list.",
      "wlv_preparation_argument_error"
    )
  }
  unexpected <- setdiff(names(arguments), names(parameters))
  if (length(unexpected)) {
    wlv_preparation_abort(
      sprintf(
        "Unknown preparation argument(s): %s.",
        paste(unexpected, collapse = ", ")
      ),
      "wlv_preparation_argument_error"
    )
  }
  resolved <- vector("list", length(parameters))
  names(resolved) <- names(parameters)
  for (name in names(parameters)) {
    parameter <- parameters[[name]]
    if (name %in% names(arguments)) {
      value <- arguments[[name]]
    } else if (parameter$has_default) {
      value <- parameter$default
    } else if (parameter$required) {
      wlv_preparation_abort(
        sprintf("Required preparation argument `%s` is missing.", name),
        "wlv_preparation_argument_error"
      )
    } else {
      value <- NULL
    }
    if (!is.null(value)) {
      value <- wlv_validate_preparation_parameter(value, parameter, name)
    }
    resolved[name] <- list(value)
  }
  resolved
}

wlv_preparation_task_spec <- function(
    source,
    run,
    services,
    parameters = list(),
    locks = source,
    source_record_required = TRUE) {
  source <- wlv_preparation_safe_id(source)
  if (!is.function(run)) {
    wlv_preparation_abort(
      "A preparation task must provide a `run` function.",
      "wlv_preparation_contract_error"
    )
  }
  if (
    !is.character(services) || anyNA(services) || any(!nzchar(services)) ||
      anyDuplicated(services)
  ) {
    wlv_preparation_abort(
      "Preparation task services must be unique non-empty names.",
      "wlv_preparation_contract_error"
    )
  }
  if (!is.list(parameters) || (length(parameters) &&
      (is.null(names(parameters)) || any(!nzchar(names(parameters))) ||
        anyDuplicated(names(parameters)) ||
        any(!vapply(
          parameters,
          inherits,
          logical(1L),
          "wlv_preparation_parameter"
        ))))) {
    wlv_preparation_abort(
      "Preparation parameters must be a named list of parameter contracts.",
      "wlv_preparation_contract_error"
    )
  }
  for (parameter_name in names(parameters)) {
    parameter <- parameters[[parameter_name]]
    if (parameter$has_default) {
      invisible(wlv_validate_preparation_parameter(
        parameter$default,
        parameter,
        parameter_name
      ))
    }
  }
  if (!is.character(locks) || !length(locks) || anyNA(locks) ||
      anyDuplicated(locks)) {
    wlv_preparation_abort(
      "Preparation task locks must be unique source identifiers.",
      "wlv_preparation_contract_error"
    )
  }
  locks <- unname(vapply(
    locks,
    wlv_preparation_safe_id,
    character(1L),
    name = "lock"
  ))
  if (!is.logical(source_record_required) || length(source_record_required) != 1L ||
      is.na(source_record_required)) {
    wlv_preparation_abort(
      "`source_record_required` must be TRUE or FALSE.",
      "wlv_preparation_contract_error"
    )
  }
  structure(
    list(
      source = source,
      services = services,
      parameters = parameters,
      locks = sort(locks, method = "radix"),
      source_record_required = source_record_required,
      run = run
    ),
    class = c("wlv_preparation_task_spec", "list")
  )
}

wlv_preparation_registry <- function(...) {
  specs <- list(...)
  if (length(specs) == 1L && is.list(specs[[1L]]) &&
      !inherits(specs[[1L]], "wlv_preparation_task_spec")) {
    specs <- specs[[1L]]
  }
  if (!length(specs) ||
      any(!vapply(specs, inherits, logical(1L), "wlv_preparation_task_spec"))) {
    wlv_preparation_abort(
      "A preparation registry requires task specifications.",
      "wlv_preparation_contract_error"
    )
  }
  sources <- vapply(specs, `[[`, character(1L), "source")
  if (anyDuplicated(sources)) {
    wlv_preparation_abort(
      sprintf(
        "Duplicate preparation source(s): %s.",
        paste(unique(sources[duplicated(sources)]), collapse = ", ")
      ),
      "wlv_preparation_contract_error"
    )
  }
  order_index <- order(sources, method = "radix")
  specs <- specs[order_index]
  names(specs) <- sources[order_index]
  structure(specs, class = c("wlv_preparation_registry", "list"))
}

wlv_resolve_preparation_task <- function(registry, source) {
  if (!inherits(registry, "wlv_preparation_registry")) {
    wlv_preparation_abort(
      "`registry` must be a preparation registry.",
      "wlv_preparation_contract_error"
    )
  }
  source <- wlv_preparation_safe_id(source)
  if (!source %in% names(registry)) {
    wlv_preparation_abort(
      sprintf(
        "Source `%s` has no native preparation task. Registered sources: %s.",
        source,
        paste(names(registry), collapse = ", ")
      ),
      "wlv_preparation_contract_error"
    )
  }
  registry[[source]]
}

wlv_preparation_promotion <- function(staged, destination) {
  staged <- wlv_preparation_scalar_character(staged, "staged")
  destination <- wlv_preparation_scalar_character(destination, "destination")
  structure(
    list(staged = staged, destination = destination),
    class = c("wlv_preparation_promotion", "list")
  )
}

wlv_preparation_result <- function(promotions, diagnostics = list()) {
  if (!is.list(promotions) || is.null(names(promotions)) ||
      any(!nzchar(names(promotions))) || anyDuplicated(names(promotions)) ||
      any(!vapply(promotions, inherits, logical(1L), "wlv_preparation_promotion"))) {
    wlv_preparation_abort(
      "Preparation promotions must be a uniquely named list.",
      "wlv_preparation_result_error"
    )
  }
  if (!is.list(diagnostics)) {
    wlv_preparation_abort(
      "Preparation diagnostics must be a list.",
      "wlv_preparation_result_error"
    )
  }
  structure(
    list(promotions = promotions, diagnostics = diagnostics),
    class = c("wlv_preparation_result", "list")
  )
}

wlv_preparation_path_key <- function(path, must_work = FALSE) {
  normalized <- normalizePath(
    path,
    winslash = "/",
    mustWork = must_work
  )
  normalized <- sub("/+$", "", normalized)
  if (.Platform$OS.type == "windows") tolower(normalized) else normalized
}

wlv_preparation_path_is_within <- function(path, parent, must_work = FALSE) {
  path_key <- wlv_preparation_path_key(path, must_work = must_work)
  parent_key <- wlv_preparation_path_key(parent, must_work = TRUE)
  startsWith(path_key, paste0(parent_key, "/"))
}

wlv_new_preparation_context <- function(
    source,
    root,
    staging,
    catalog,
    source_record,
    services,
    allowed_services,
    arguments,
    fail_at = character()) {
  source <- wlv_preparation_safe_id(source)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  staging <- normalizePath(staging, winslash = "/", mustWork = TRUE)
  if (!wlv_preparation_path_is_within(staging, root, must_work = TRUE)) {
    wlv_preparation_abort(
      "Preparation staging must be inside the project root.",
      "wlv_preparation_contract_error"
    )
  }
  services <- wlv_preparation_named_functions(services)
  if (!all(allowed_services %in% names(services))) {
    wlv_preparation_abort(
      sprintf(
        "Preparation services are missing: %s.",
        paste(setdiff(allowed_services, names(services)), collapse = ", ")
      ),
      "wlv_preparation_contract_error"
    )
  }
  fail_at <- as.character(fail_at)
  if (anyNA(fail_at) || any(!nzchar(fail_at))) {
    wlv_preparation_abort(
      "Injected failure checkpoints must be non-empty strings.",
      "wlv_preparation_contract_error"
    )
  }

  context <- new.env(parent = emptyenv())
  context$source <- source
  context$root <- root
  context$staging <- staging
  context$path <- local({
    project_root <- root
    function(...) {
      components <- list(...)
      if (!length(components) || any(!vapply(components, function(value) {
        is.character(value) && length(value) == 1L && !is.na(value) &&
          nzchar(value)
      }, logical(1L)))) {
        wlv_preparation_abort(
          "Preparation path components must be non-empty strings.",
          "wlv_preparation_contract_error"
        )
      }
      path <- do.call(file.path, c(list(project_root), components))
      if (!wlv_preparation_path_is_within(path, project_root)) {
        wlv_preparation_abort(
          "Preparation path escapes the project root.",
          "wlv_preparation_contract_error"
        )
      }
      normalizePath(path, winslash = "/", mustWork = FALSE)
    }
  })
  context$stage_path <- local({
    staging_root <- staging
    function(...) {
      components <- list(...)
      if (!length(components) || any(!vapply(components, function(value) {
        is.character(value) && length(value) == 1L && !is.na(value) &&
          nzchar(value)
      }, logical(1L)))) {
        wlv_preparation_abort(
          "Preparation staging path components must be non-empty strings.",
          "wlv_preparation_contract_error"
        )
      }
      path <- do.call(file.path, c(list(staging_root), components))
      if (!wlv_preparation_path_is_within(path, staging_root)) {
        wlv_preparation_abort(
          "Preparation staging path escapes its transaction.",
          "wlv_preparation_contract_error"
        )
      }
      normalizePath(path, winslash = "/", mustWork = FALSE)
    }
  })
  context$service <- local({
    service_values <- services[allowed_services]
    function(name) {
      name <- wlv_preparation_scalar_character(name, "service")
      if (!name %in% names(service_values)) {
        wlv_preparation_abort(
          sprintf("Preparation service `%s` was not declared.", name),
          "wlv_preparation_contract_error"
        )
      }
      service_values[[name]]
    }
  })
  context$arg <- local({
    argument_values <- arguments
    function(name) {
      name <- wlv_preparation_scalar_character(name, "argument")
      if (!name %in% names(argument_values)) {
        wlv_preparation_abort(
          sprintf("Preparation argument `%s` was not declared.", name),
          "wlv_preparation_argument_error"
        )
      }
      argument_values[[name]]
    }
  })
  context$catalog <- local({
    value <- catalog
    function() value
  })
  context$source_record <- local({
    value <- source_record
    function() value
  })
  context$checkpoint <- local({
    failures <- fail_at
    function(label) {
      label <- wlv_preparation_scalar_character(label, "checkpoint")
      if (label %in% failures) {
        wlv_preparation_abort(
          sprintf("Injected preparation failure at `%s`.", label),
          "wlv_preparation_injected_error"
        )
      }
      invisible(label)
    }
  })
  lockEnvironment(context, bindings = TRUE)
  context
}

wlv_preparation_acquire_locks <- function(root, locks) {
  source_data <- file.path(root, "source_data")
  if (!dir.exists(source_data) &&
      !dir.create(source_data, recursive = TRUE, showWarnings = FALSE)) {
    wlv_preparation_abort("Could not create the source-data directory.")
  }
  source_data <- normalizePath(source_data, winslash = "/", mustWork = TRUE)
  acquired <- character()
  for (lock_id in sort(locks, method = "radix")) {
    path <- file.path(source_data, paste0(".prepare-lock-", lock_id))
    if (!wlv_preparation_path_is_within(path, source_data) ||
        !startsWith(basename(path), ".prepare-lock-")) {
      wlv_preparation_abort("Refusing to create an unsafe preparation lock.")
    }
    if (!dir.create(path, recursive = FALSE, showWarnings = FALSE)) {
      if (length(acquired)) {
        for (held in rev(acquired)) unlink(held, recursive = TRUE, force = TRUE)
      }
      wlv_preparation_abort(
        sprintf("Source preparation is already locked by `%s`.", lock_id),
        "wlv_preparation_lock_error"
      )
    }
    acquired <- c(acquired, normalizePath(path, winslash = "/", mustWork = TRUE))
  }
  acquired
}

wlv_preparation_release_locks <- function(locks, root) {
  source_data <- normalizePath(
    file.path(root, "source_data"),
    winslash = "/",
    mustWork = TRUE
  )
  for (path in rev(locks)) {
    if (!wlv_preparation_path_is_within(path, source_data, must_work = TRUE) ||
        !startsWith(basename(path), ".prepare-lock-")) {
      wlv_preparation_abort("Refusing to remove an unsafe preparation lock.")
    }
    unlink(path, recursive = TRUE, force = TRUE)
    if (dir.exists(path)) {
      wlv_preparation_abort(sprintf("Could not release preparation lock `%s`.", path))
    }
  }
  invisible(NULL)
}

wlv_validate_preparation_result <- function(result, staging, root) {
  if (!inherits(result, "wlv_preparation_result")) {
    wlv_preparation_abort(
      "Preparation tasks must return `wlv_preparation_result()`.",
      "wlv_preparation_result_error"
    )
  }
  staged <- vapply(result$promotions, `[[`, character(1L), "staged")
  destinations <- vapply(result$promotions, `[[`, character(1L), "destination")
  missing <- staged[!file.exists(staged) & !dir.exists(staged)]
  if (length(missing)) {
    wlv_preparation_abort(
      sprintf(
        "Preparation result lacks staged artifact(s): %s.",
        paste(missing, collapse = ", ")
      ),
      "wlv_preparation_result_error"
    )
  }
  if (any(!vapply(staged, wlv_preparation_path_is_within, logical(1L),
    parent = staging, must_work = TRUE))) {
    wlv_preparation_abort(
      "A staged preparation artifact escapes its transaction.",
      "wlv_preparation_result_error"
    )
  }
  if (any(!vapply(destinations, wlv_preparation_path_is_within, logical(1L),
    parent = root, must_work = FALSE))) {
    wlv_preparation_abort(
      "A preparation destination escapes the project root.",
      "wlv_preparation_result_error"
    )
  }
  destination_keys <- vapply(destinations, wlv_preparation_path_key, character(1L))
  if (anyDuplicated(destination_keys)) {
    wlv_preparation_abort(
      "Preparation destinations must be unique.",
      "wlv_preparation_result_error"
    )
  }
  for (index in seq_along(destination_keys)) {
    others <- destination_keys[-index]
    if (any(startsWith(others, paste0(destination_keys[[index]], "/")))) {
      wlv_preparation_abort(
        "Preparation destinations cannot contain one another.",
        "wlv_preparation_result_error"
      )
    }
  }
  invisible(result)
}

wlv_preparation_staged_path <- function(result, destination) {
  if (!inherits(result, "wlv_preparation_result")) {
    wlv_preparation_abort(
      "Staged path resolution requires a preparation result.",
      "wlv_preparation_result_error"
    )
  }
  destination <- wlv_preparation_scalar_character(destination, "destination")
  requested <- normalizePath(
    destination,
    winslash = "/",
    mustWork = FALSE
  )
  requested_key <- wlv_preparation_path_key(requested)
  promotion_destinations <- vapply(
    result$promotions,
    `[[`,
    character(1L),
    "destination"
  )
  promotion_keys <- vapply(
    promotion_destinations,
    wlv_preparation_path_key,
    character(1L)
  )
  matches <- requested_key == promotion_keys |
    startsWith(requested_key, paste0(promotion_keys, "/"))
  if (sum(matches) != 1L) {
    wlv_preparation_abort(
      sprintf(
        "Prepared path `%s` must resolve through exactly one staged promotion.",
        destination
      ),
      "wlv_preparation_result_error"
    )
  }

  index <- which(matches)[[1L]]
  promotion_destination <- normalizePath(
    promotion_destinations[[index]],
    winslash = "/",
    mustWork = FALSE
  )
  staged_root <- result$promotions[[index]]$staged
  staged <- if (identical(requested_key, promotion_keys[[index]])) {
    staged_root
  } else {
    relative <- substring(requested, nchar(promotion_destination) + 2L)
    file.path(staged_root, relative)
  }
  staged_key <- if (file.exists(staged) || dir.exists(staged)) {
    wlv_preparation_path_key(staged, must_work = TRUE)
  } else {
    ""
  }
  staged_root_key <- wlv_preparation_path_key(staged_root, must_work = TRUE)
  if ((!file.exists(staged) && !dir.exists(staged)) ||
      !(identical(staged_key, staged_root_key) ||
        startsWith(staged_key, paste0(staged_root_key, "/")))) {
    wlv_preparation_abort(
      sprintf("Prepared staged path `%s` is missing or unsafe.", staged),
      "wlv_preparation_result_error"
    )
  }
  normalizePath(staged, winslash = "/", mustWork = TRUE)
}

wlv_commit_preparation_result <- function(result, context) {
  promotions <- result$promotions
  names_vector <- names(promotions)
  staging <- context$staging
  root <- context$root
  backup_root <- file.path(staging, ".backups")
  if (!dir.create(backup_root, recursive = FALSE, showWarnings = FALSE)) {
    wlv_preparation_abort("Could not create preparation backup staging.")
  }
  backups <- file.path(
    backup_root,
    sprintf("%04d-%s", seq_along(promotions), basename(names_vector))
  )
  had_destination <- logical(length(promotions))
  installed <- logical(length(promotions))

  commit_error <- tryCatch({
    context$checkpoint("before_commit")
    for (index in seq_along(promotions)) {
      destination <- promotions[[index]]$destination
      parent <- dirname(destination)
      if (!dir.exists(parent) &&
          !dir.create(parent, recursive = TRUE, showWarnings = FALSE)) {
        wlv_preparation_abort(
          sprintf("Could not create preparation destination `%s`.", parent)
        )
      }
      had_destination[[index]] <- file.exists(destination) || dir.exists(destination)
      if (had_destination[[index]] && !file.rename(destination, backups[[index]])) {
        wlv_preparation_abort(
          sprintf("Could not preserve preparation artifact `%s`.", destination)
        )
      }
      context$checkpoint(paste0("after_backup:", names_vector[[index]]))
    }
    for (index in seq_along(promotions)) {
      staged <- promotions[[index]]$staged
      destination <- promotions[[index]]$destination
      if (!file.rename(staged, destination)) {
        wlv_preparation_abort(
          sprintf("Could not promote preparation artifact `%s`.", destination)
        )
      }
      installed[[index]] <- TRUE
      context$checkpoint(paste0("after_install:", names_vector[[index]]))
    }
    NULL
  }, error = identity)

  if (inherits(commit_error, "error")) {
    recovery_failures <- character()
    for (index in rev(seq_along(promotions))) {
      destination <- promotions[[index]]$destination
      staged <- promotions[[index]]$staged
      if (installed[[index]] && (file.exists(destination) || dir.exists(destination))) {
        if ((file.exists(staged) || dir.exists(staged)) ||
            !file.rename(destination, staged)) {
          recovery_failures <- c(
            recovery_failures,
            sprintf("new artifact remains at `%s`", destination)
          )
        }
      }
    }
    for (index in rev(seq_along(promotions))) {
      destination <- promotions[[index]]$destination
      if (had_destination[[index]] &&
          (file.exists(backups[[index]]) || dir.exists(backups[[index]]))) {
        if ((file.exists(destination) || dir.exists(destination)) ||
            !file.rename(backups[[index]], destination)) {
          recovery_failures <- c(
            recovery_failures,
            sprintf("prior artifact remains at `%s`", backups[[index]])
          )
        }
      }
    }
    if (length(recovery_failures)) {
      wlv_preparation_abort(
        sprintf(
          "Preparation failed and rollback was incomplete: %s.",
          paste(recovery_failures, collapse = "; ")
        ),
        "wlv_preparation_recovery_error"
      )
    }
    stop(commit_error)
  }

  if (dir.exists(backup_root)) {
    unlink(backup_root, recursive = TRUE, force = TRUE)
  }
  if (dir.exists(backup_root)) {
    warning("Preparation committed, but its backup staging remains.", call. = FALSE)
  }
  stats::setNames(
    lapply(promotions, `[[`, "destination"),
    names_vector
  )
}

wlv_run_preparation_task <- function(
    spec,
    root,
    catalog = NULL,
    source_record = NULL,
    services,
    arguments = list(),
    fail_at = character(),
    validate_staged = NULL) {
  if (!inherits(spec, "wlv_preparation_task_spec")) {
    wlv_preparation_abort(
      "`spec` must be a native preparation task specification.",
      "wlv_preparation_contract_error"
    )
  }
  if (!is.null(validate_staged) && !is.function(validate_staged)) {
    wlv_preparation_abort(
      "`validate_staged` must be NULL or a function.",
      "wlv_preparation_contract_error"
    )
  }
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (spec$source_record_required) {
    if (!is.data.frame(source_record) || nrow(source_record) != 1L ||
        !"source" %in% names(source_record) ||
        !identical(as.character(source_record$source[[1L]]), spec$source)) {
      wlv_preparation_abort(
        sprintf(
          "Preparation for `%s` requires its one-row catalog source record.",
          spec$source
        ),
        "wlv_preparation_contract_error"
      )
    }
  }
  services <- wlv_preparation_named_functions(services)
  arguments <- wlv_resolve_preparation_arguments(spec$parameters, arguments)
  locks <- wlv_preparation_acquire_locks(root, spec$locks)
  on.exit(wlv_preparation_release_locks(locks, root), add = TRUE)

  staging_root <- file.path(root, "source_data", ".preparation-staging")
  if (!dir.exists(staging_root) &&
      !dir.create(staging_root, recursive = FALSE, showWarnings = FALSE)) {
    wlv_preparation_abort("Could not create preparation staging root.")
  }
  staging <- tempfile(
    pattern = paste0(".task-", spec$source, "-"),
    tmpdir = staging_root
  )
  if (!wlv_preparation_path_is_within(staging, staging_root) ||
      !dir.create(staging, recursive = FALSE, showWarnings = FALSE)) {
    wlv_preparation_abort("Could not create private preparation staging.")
  }
  staging <- normalizePath(staging, winslash = "/", mustWork = TRUE)
  staging_open <- TRUE
  on.exit({
    if (staging_open && dir.exists(staging) &&
        wlv_preparation_path_is_within(staging, staging_root, must_work = TRUE) &&
        startsWith(basename(staging), ".task-")) {
      unlink(staging, recursive = TRUE, force = TRUE)
    }
  }, add = TRUE)

  context <- wlv_new_preparation_context(
    source = spec$source,
    root = root,
    staging = staging,
    catalog = catalog,
    source_record = source_record,
    services = services,
    allowed_services = spec$services,
    arguments = arguments,
    fail_at = fail_at
  )
  warnings <- character()
  result <- withCallingHandlers(
    spec$run(context),
    warning = function(condition) {
      warnings <<- c(warnings, conditionMessage(condition))
    }
  )
  wlv_validate_preparation_result(result, staging, root)
  if (!is.null(validate_staged)) {
    validate_staged(result, context)
  }
  artifacts <- wlv_commit_preparation_result(result, context)
  staging_open <- FALSE
  if (dir.exists(staging)) unlink(staging, recursive = TRUE, force = TRUE)

  structure(
    list(
      source = spec$source,
      artifacts = artifacts,
      diagnostics = result$diagnostics,
      warnings = unique(warnings)
    ),
    class = c("wlv_preparation_execution", "list")
  )
}

wlv_prepare_registered_source <- function(
    registry,
    source,
    root,
    catalog = NULL,
    source_record = NULL,
    services,
    arguments = list(),
    fail_at = character(),
    validate_staged = NULL) {
  spec <- wlv_resolve_preparation_task(registry, source)
  wlv_run_preparation_task(
    spec = spec,
    root = root,
    catalog = catalog,
    source_record = source_record,
    services = services,
    arguments = arguments,
    fail_at = fail_at,
    validate_staged = validate_staged
  )
}
