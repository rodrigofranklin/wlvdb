wlv_catalog_schemas <- list(
  sources = c(
    "source", "status", "year_start", "year_end", "parameter_set",
    "data_dir", "can_prepare", "preparer", "validator_script",
    "validator_function", "artifact_profile", "missingness_policy",
    "documentation", "limitations"
  ),
  methods = c(
    "method", "source", "code", "description", "status", "can_calculate",
    "can_recalculate", "test", "documentation", "limitations"
  ),
  artifacts = c("profile", "artifact", "kind", "sidecar", "operations"),
  missingness = c("policy", "script", "factory", "documentation")
)

wlv_catalog_stop <- function(message, ...) {
  stop(sprintf(message, ...), call. = FALSE)
}

wlv_catalog_read_csv <- function(path, schema, name) {
  if (!file.exists(path)) {
    wlv_catalog_stop("Catalog file `%s` does not exist.", path)
  }

  value <- tryCatch(
    utils::read.csv2(
      text = readLines(path, encoding = "UTF-8", warn = FALSE),
      stringsAsFactors = FALSE,
      colClasses = "character",
      check.names = FALSE,
      na.strings = NULL,
      strip.white = FALSE,
      comment.char = ""
    ),
    error = function(error) {
      wlv_catalog_stop(
        "Cannot read the %s catalog `%s`: %s",
        name,
        path,
        conditionMessage(error)
      )
    }
  )

  if (!identical(names(value), schema)) {
    wlv_catalog_stop(
      "The %s catalog must have exactly these columns, in order: %s.",
      name,
      paste(schema, collapse = ", ")
    )
  }
  if (!nrow(value)) {
    wlv_catalog_stop("The %s catalog cannot be empty.", name)
  }
  if (anyNA(value)) {
    wlv_catalog_stop(
      "The %s catalog contains NA. Use an empty field only where the schema allows it.",
      name
    )
  }

  untrimmed <- vapply(
    value,
    function(column) any(column != trimws(column)),
    logical(1)
  )
  if (any(untrimmed)) {
    wlv_catalog_stop(
      "The %s catalog contains leading or trailing whitespace in: %s.",
      name,
      paste(names(value)[untrimmed], collapse = ", ")
    )
  }

  value
}

wlv_catalog_validate_required <- function(value, columns, name) {
  for (column in columns) {
    missing <- !nzchar(value[[column]])
    if (any(missing)) {
      wlv_catalog_stop(
        "The %s catalog contains an empty `%s` at row(s): %s.",
        name,
        column,
        paste(which(missing), collapse = ", ")
      )
    }
  }
  invisible(value)
}

wlv_catalog_validate_ids <- function(values, column, name) {
  invalid <- !grepl("^[a-z][a-z0-9_]*$", values)
  if (any(invalid)) {
    wlv_catalog_stop(
      "The %s catalog contains invalid `%s` identifiers: %s.",
      name,
      column,
      paste(unique(values[invalid]), collapse = ", ")
    )
  }
  invisible(values)
}

wlv_catalog_validate_unique <- function(values, column, name) {
  if (anyDuplicated(values)) {
    duplicates <- unique(values[duplicated(values)])
    wlv_catalog_stop(
      "The %s catalog contains duplicate `%s` values: %s.",
      name,
      column,
      paste(duplicates, collapse = ", ")
    )
  }
  invisible(values)
}

wlv_catalog_validate_enum <- function(values, allowed, column, name) {
  invalid <- !values %in% allowed
  if (any(invalid)) {
    wlv_catalog_stop(
      "The %s catalog has invalid `%s` value(s): %s. Allowed values: %s.",
      name,
      column,
      paste(unique(values[invalid]), collapse = ", "),
      paste(allowed, collapse = ", ")
    )
  }
  invisible(values)
}

wlv_catalog_parse_boolean <- function(values, column, name) {
  wlv_catalog_validate_enum(values, c("TRUE", "FALSE"), column, name)
  values == "TRUE"
}

wlv_catalog_parse_years <- function(start, end, name) {
  missing_start <- !nzchar(start)
  missing_end <- !nzchar(end)
  incomplete <- xor(missing_start, missing_end)
  if (any(incomplete)) {
    wlv_catalog_stop(
      "The %s catalog must declare both `year_start` and `year_end`, or neither, at row(s): %s.",
      name,
      paste(which(incomplete), collapse = ", ")
    )
  }

  present <- !missing_start
  invalid <- present & (
    !grepl("^[0-9]{4}$", start) |
      !grepl("^[0-9]{4}$", end)
  )
  if (any(invalid)) {
    wlv_catalog_stop(
      "The %s catalog contains a non-canonical four-digit year at row(s): %s.",
      name,
      paste(which(invalid), collapse = ", ")
    )
  }

  start_integer <- rep(NA_integer_, length(start))
  end_integer <- rep(NA_integer_, length(end))
  start_integer[present] <- as.integer(start[present])
  end_integer[present] <- as.integer(end[present])
  reversed <- present & start_integer > end_integer
  if (any(reversed)) {
    wlv_catalog_stop(
      "The %s catalog has `year_start` after `year_end` at row(s): %s.",
      name,
      paste(which(reversed), collapse = ", ")
    )
  }

  list(start = start_integer, end = end_integer)
}

wlv_catalog_safe_relative_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    return(FALSE)
  }
  if (
    grepl("\\\\", path) ||
      grepl("^([A-Za-z]:|/|~)", path) ||
      grepl("//", path, fixed = TRUE) ||
      grepl("[[:cntrl:]]", path)
  ) {
    return(FALSE)
  }

  pieces <- strsplit(path, "/", fixed = TRUE)[[1L]]
  all(
    nzchar(pieces) &
      !pieces %in% c(".", "..") &
      grepl("^[A-Za-z0-9._-]+$", pieces)
  )
}

wlv_catalog_validate_paths <- function(values, column, name, optional = FALSE) {
  present <- nzchar(values)
  if (!optional && any(!present)) {
    wlv_catalog_stop(
      "The %s catalog contains an empty `%s` at row(s): %s.",
      name,
      column,
      paste(which(!present), collapse = ", ")
    )
  }
  invalid <- present & !vapply(values, wlv_catalog_safe_relative_path, logical(1))
  if (any(invalid)) {
    wlv_catalog_stop(
      "The %s catalog contains unsafe relative path(s) in `%s`: %s.",
      name,
      column,
      paste(unique(values[invalid]), collapse = ", ")
    )
  }
  invisible(values)
}

wlv_catalog_require_declared_files <- function(root, values, column, name) {
  values <- unique(values[nzchar(values)])
  missing <- values[!file.exists(file.path(root, values))]
  if (length(missing)) {
    wlv_catalog_stop(
      "The %s catalog declares missing `%s` path(s): %s.",
      name,
      column,
      paste(missing, collapse = ", ")
    )
  }
  invisible(values)
}

wlv_catalog_validator_is_defined <- function(path, function_name) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  definitions <- lines[grepl("<-\\s*function\\s*\\(", lines)]
  if (!length(definitions)) {
    return(FALSE)
  }
  left_hand_side <- trimws(sub("<-.*$", "", definitions))
  function_name %in% left_hand_side
}

wlv_catalog_parse_operations <- function(values) {
  lapply(values, function(value) strsplit(value, "|", fixed = TRUE)[[1L]])
}

wlv_catalog_validate_sources <- function(sources, root) {
  name <- "sources"
  wlv_catalog_validate_required(
    sources,
    c("source", "status", "parameter_set", "data_dir", "can_prepare"),
    name
  )
  wlv_catalog_validate_ids(sources$source, "source", name)
  wlv_catalog_validate_ids(sources$parameter_set, "parameter_set", name)
  wlv_catalog_validate_unique(sources$source, "source", name)
  wlv_catalog_validate_enum(
    sources$status,
    c("stable", "experimental", "disabled"),
    "status",
    name
  )
  years <- wlv_catalog_parse_years(sources$year_start, sources$year_end, name)
  sources$year_start <- years$start
  sources$year_end <- years$end
  sources$can_prepare <- wlv_catalog_parse_boolean(
    sources$can_prepare,
    "can_prepare",
    name
  )

  enabled_disabled <- sources$status == "disabled" & sources$can_prepare
  if (any(enabled_disabled)) {
    wlv_catalog_stop(
      "Disabled source(s) cannot declare preparation capability: %s.",
      paste(sources$source[enabled_disabled], collapse = ", ")
    )
  }

  wlv_catalog_validate_paths(sources$data_dir, "data_dir", name)
  for (column in c("preparer", "validator_script", "documentation")) {
    wlv_catalog_validate_paths(sources[[column]], column, name, optional = TRUE)
    wlv_catalog_require_declared_files(root, sources[[column]], column, name)
  }

  invalid_function <- nzchar(sources$validator_function) &
    !grepl("^[A-Za-z.][A-Za-z0-9._]*$", sources$validator_function)
  if (any(invalid_function)) {
    wlv_catalog_stop(
      "The sources catalog contains invalid `validator_function` names: %s.",
      paste(unique(sources$validator_function[invalid_function]), collapse = ", ")
    )
  }
  incomplete_validator <- xor(
    nzchar(sources$validator_script),
    nzchar(sources$validator_function)
  )
  if (any(incomplete_validator)) {
    wlv_catalog_stop(
      "The sources catalog must declare `validator_script` and `validator_function` together at row(s): %s.",
      paste(which(incomplete_validator), collapse = ", ")
    )
  }
  missing_preparer <- sources$can_prepare & !nzchar(sources$preparer)
  unexpected_preparer <- !sources$can_prepare & nzchar(sources$preparer)
  if (any(missing_preparer | unexpected_preparer)) {
    wlv_catalog_stop(
      "The sources catalog has an inconsistent `can_prepare`/`preparer` contract at row(s): %s.",
      paste(which(missing_preparer | unexpected_preparer), collapse = ", ")
    )
  }

  profile_present <- nzchar(sources$artifact_profile)
  invalid_profile <- profile_present &
    !grepl("^[a-z][a-z0-9_]*$", sources$artifact_profile)
  if (any(invalid_profile)) {
    wlv_catalog_stop(
      "The sources catalog contains invalid `artifact_profile` identifiers: %s.",
      paste(unique(sources$artifact_profile[invalid_profile]), collapse = ", ")
    )
  }

  policy_present <- nzchar(sources$missingness_policy)
  invalid_policy <- policy_present &
    !grepl("^[a-z][a-z0-9_]*$", sources$missingness_policy)
  if (any(invalid_policy)) {
    wlv_catalog_stop(
      "The sources catalog contains invalid `missingness_policy` identifiers: %s.",
      paste(unique(sources$missingness_policy[invalid_policy]), collapse = ", ")
    )
  }

  missing_parameter_sets <- unique(sources$parameter_set[
    !dir.exists(file.path(root, "parameters", sources$parameter_set))
  ])
  if (length(missing_parameter_sets)) {
    wlv_catalog_stop(
      "The sources catalog refers to missing parameter set(s): %s.",
      paste(missing_parameter_sets, collapse = ", ")
    )
  }
  parameter_directories <- basename(list.dirs(
    file.path(root, "parameters"),
    recursive = FALSE,
    full.names = TRUE
  ))
  orphan_parameter_sets <- setdiff(
    parameter_directories,
    c("common_ground", unique(sources$parameter_set))
  )
  if (length(orphan_parameter_sets)) {
    wlv_catalog_stop(
      "Parameter set directory or directories are absent from the sources catalog: %s.",
      paste(orphan_parameter_sets, collapse = ", ")
    )
  }

  stable <- sources$status == "stable"
  incomplete_stable <- stable & (
    !sources$can_prepare |
      !nzchar(sources$preparer) |
      !nzchar(sources$validator_script) |
      !nzchar(sources$validator_function) |
      !nzchar(sources$artifact_profile) |
      !nzchar(sources$missingness_policy) |
      !nzchar(sources$documentation)
  )
  if (any(incomplete_stable)) {
    wlv_catalog_stop(
      "Stable source(s) must declare preparation, validation, artifacts, a missingness policy, and documentation: %s.",
      paste(sources$source[incomplete_stable], collapse = ", ")
    )
  }

  undocumented_nonstable <- !stable & !nzchar(sources$limitations)
  if (any(undocumented_nonstable)) {
    wlv_catalog_stop(
      "Non-stable source(s) must explain their limitations: %s.",
      paste(sources$source[undocumented_nonstable], collapse = ", ")
    )
  }

  for (index in which(nzchar(sources$validator_script))) {
    path <- file.path(root, sources$validator_script[[index]])
    function_name <- sources$validator_function[[index]]
    if (!wlv_catalog_validator_is_defined(path, function_name)) {
      wlv_catalog_stop(
        "Validator `%s` is not defined in `%s` for source `%s`.",
        function_name,
        sources$validator_script[[index]],
        sources$source[[index]]
      )
    }
  }

  sources
}

wlv_catalog_validate_artifacts <- function(artifacts) {
  name <- "artifact profiles"
  wlv_catalog_validate_required(
    artifacts,
    c("profile", "artifact", "kind", "sidecar", "operations"),
    name
  )
  wlv_catalog_validate_ids(artifacts$profile, "profile", name)
  wlv_catalog_validate_enum(
    artifacts$kind,
    c("csv", "fst_array", "fst_array_glob"),
    "kind",
    name
  )
  is_glob <- grepl("*", artifacts$artifact, fixed = TRUE)
  invalid_glob_kind <- xor(is_glob, artifacts$kind == "fst_array_glob")
  if (any(invalid_glob_kind)) {
    wlv_catalog_stop(
      "The artifact profiles catalog must use `fst_array_glob` exactly for artifacts containing `*`, at row(s): %s.",
      paste(which(invalid_glob_kind), collapse = ", ")
    )
  }
  safe_artifacts <- artifacts$artifact
  safe_artifacts[is_glob] <- sub("*", "x", safe_artifacts[is_glob], fixed = TRUE)
  invalid_glob <- is_glob & (
    lengths(regmatches(artifacts$artifact, gregexpr("*", artifacts$artifact, fixed = TRUE))) != 1L |
      !grepl("\\.fst$", artifacts$artifact)
  )
  if (any(invalid_glob)) {
    wlv_catalog_stop(
      "The artifact profiles catalog contains an invalid FST glob at row(s): %s.",
      paste(which(invalid_glob), collapse = ", ")
    )
  }
  wlv_catalog_validate_paths(safe_artifacts, "artifact", name)
  artifacts$sidecar <- wlv_catalog_parse_boolean(
    artifacts$sidecar,
    "sidecar",
    name
  )

  keys <- paste(artifacts$profile, artifacts$artifact, sep = "/")
  wlv_catalog_validate_unique(keys, "profile/artifact", name)
  operations <- wlv_catalog_parse_operations(artifacts$operations)
  allowed_operations <- c("prepare", "calculate", "recalculate")
  invalid_operations <- vapply(
    operations,
    function(value) {
      !length(value) ||
        any(!nzchar(value)) ||
        any(!value %in% allowed_operations) ||
        anyDuplicated(value) > 0L
    },
    logical(1)
  )
  if (any(invalid_operations)) {
    wlv_catalog_stop(
      "The artifact profiles catalog contains invalid `operations` at row(s): %s. Use unique values from %s separated by `|`.",
      paste(which(invalid_operations), collapse = ", "),
      paste(allowed_operations, collapse = ", ")
    )
  }

  artifacts
}

wlv_catalog_validate_missingness_policies <- function(policies, root) {
  name <- "missingness policies"
  wlv_catalog_validate_required(
    policies,
    c("policy", "script", "factory", "documentation"),
    name
  )
  wlv_catalog_validate_ids(policies$policy, "policy", name)
  wlv_catalog_validate_unique(policies$policy, "policy", name)
  for (column in c("script", "documentation")) {
    wlv_catalog_validate_paths(policies[[column]], column, name)
    wlv_catalog_require_declared_files(root, policies[[column]], column, name)
  }

  invalid_factory <- !grepl(
    "^[A-Za-z.][A-Za-z0-9._]*$",
    policies$factory
  )
  if (any(invalid_factory)) {
    wlv_catalog_stop(
      "The missingness policies catalog contains invalid `factory` names: %s.",
      paste(unique(policies$factory[invalid_factory]), collapse = ", ")
    )
  }

  for (index in seq_len(nrow(policies))) {
    path <- file.path(root, policies$script[[index]])
    factory <- policies$factory[[index]]
    if (!wlv_catalog_validator_is_defined(path, factory)) {
      wlv_catalog_stop(
        "Missingness policy factory `%s` is not defined in `%s` for policy `%s`.",
        factory,
        policies$script[[index]],
        policies$policy[[index]]
      )
    }
  }

  policies
}

wlv_catalog_validate_methods <- function(methods, sources, root) {
  name <- "methods"
  wlv_catalog_validate_required(
    methods,
    c(
      "method", "source", "code", "description", "status",
      "can_calculate", "can_recalculate"
    ),
    name
  )
  wlv_catalog_validate_ids(methods$method, "method", name)
  wlv_catalog_validate_ids(methods$source, "source", name)
  wlv_catalog_validate_unique(methods$method, "method", name)
  wlv_catalog_validate_unique(methods$code, "code", name)
  invalid_code <- !grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", methods$code)
  if (any(invalid_code)) {
    wlv_catalog_stop(
      "The methods catalog contains invalid `code` values: %s.",
      paste(unique(methods$code[invalid_code]), collapse = ", ")
    )
  }
  wlv_catalog_validate_enum(
    methods$status,
    c("stable", "experimental", "disabled"),
    "status",
    name
  )
  methods$can_calculate <- wlv_catalog_parse_boolean(
    methods$can_calculate,
    "can_calculate",
    name
  )
  methods$can_recalculate <- wlv_catalog_parse_boolean(
    methods$can_recalculate,
    "can_recalculate",
    name
  )
  for (column in c("test", "documentation")) {
    wlv_catalog_validate_paths(
      methods[[column]],
      column,
      name,
      optional = TRUE
    )
    wlv_catalog_require_declared_files(
      root,
      methods[[column]],
      column,
      name
    )
  }

  missing_sources <- setdiff(unique(methods$source), sources$source)
  if (length(missing_sources)) {
    wlv_catalog_stop(
      "The methods catalog refers to unknown source(s): %s.",
      paste(missing_sources, collapse = ", ")
    )
  }

  disabled <- methods$status == "disabled"
  enabled_disabled <- disabled & (methods$can_calculate | methods$can_recalculate)
  if (any(enabled_disabled)) {
    wlv_catalog_stop(
      "Disabled method(s) cannot declare calculation capabilities: %s.",
      paste(methods$method[enabled_disabled], collapse = ", ")
    )
  }

  source_rows <- match(methods$source, sources$source)
  has_runtime_capability <- methods$can_calculate | methods$can_recalculate
  missing_artifact_profile <- has_runtime_capability &
    !nzchar(sources$artifact_profile[source_rows])
  if (any(missing_artifact_profile)) {
    wlv_catalog_stop(
      "Method(s) with calculation capabilities require a source artifact profile: %s.",
      paste(methods$method[missing_artifact_profile], collapse = ", ")
    )
  }

  stable <- methods$status == "stable"
  invalid_stable <- stable & (
    sources$status[source_rows] != "stable" |
      !methods$can_calculate |
      !methods$can_recalculate |
      !nzchar(methods$test) |
      !nzchar(methods$documentation)
  )
  if (any(invalid_stable)) {
    wlv_catalog_stop(
      "Stable method(s) require a stable source, calculate/recalculate capabilities, a test, and documentation: %s.",
      paste(methods$method[invalid_stable], collapse = ", ")
    )
  }

  undocumented_nonstable <- !stable & !nzchar(methods$limitations)
  if (any(undocumented_nonstable)) {
    wlv_catalog_stop(
      "Non-stable method(s) must explain their limitations: %s.",
      paste(methods$method[undocumented_nonstable], collapse = ", ")
    )
  }

  method_root <- file.path(root, "methods")
  if (!dir.exists(method_root)) {
    wlv_catalog_stop("Methods directory does not exist: `%s`.", method_root)
  }
  directories <- sort(list.dirs(method_root, recursive = FALSE, full.names = FALSE))
  registered <- sort(methods$method)
  if (!identical(directories, registered)) {
    missing_from_catalog <- setdiff(directories, registered)
    missing_from_tree <- setdiff(registered, directories)
    details <- c(
      if (length(missing_from_catalog)) {
        sprintf("unregistered directories: %s", paste(missing_from_catalog, collapse = ", "))
      },
      if (length(missing_from_tree)) {
        sprintf("missing directories: %s", paste(missing_from_tree, collapse = ", "))
      }
    )
    wlv_catalog_stop(
      "The methods catalog and `methods/` directory differ (%s).",
      paste(details, collapse = "; ")
    )
  }

  for (index in seq_len(nrow(methods))) {
    method <- methods$method[[index]]
    parameter_file <- file.path(root, "methods", method, "_parameters.csv")
    if (!file.exists(parameter_file)) {
      wlv_catalog_stop(
        "Method `%s` is missing `_parameters.csv`.",
        method
      )
    }
    parameters <- tryCatch(
      utils::read.csv2(
        text = readLines(
          parameter_file,
          encoding = "latin1",
          warn = FALSE
        ),
        stringsAsFactors = FALSE,
        colClasses = "character",
        check.names = FALSE,
        na.strings = NULL
      ),
      error = function(error) {
        wlv_catalog_stop(
          "Cannot read `_parameters.csv` for method `%s`: %s",
          method,
          conditionMessage(error)
        )
      }
    )
    required_parameter_columns <- c("source", "code", "name")
    missing_parameter_columns <- setdiff(
      required_parameter_columns,
      names(parameters)
    )
    if (length(missing_parameter_columns)) {
      wlv_catalog_stop(
        "Method `%s` `_parameters.csv` lacks: %s.",
        method,
        paste(missing_parameter_columns, collapse = ", ")
      )
    }
    declared <- unique(parameters$source[nzchar(parameters$source)])
    expected <- sources$parameter_set[[source_rows[[index]]]]
    if (length(declared) != 1L || !identical(declared, expected)) {
      wlv_catalog_stop(
        "Method `%s` `_parameters.csv` must declare source parameter set `%s`; found: %s.",
        method,
        expected,
        if (length(declared)) paste(declared, collapse = ", ") else "<empty>"
      )
    }
    declared_code <- unique(parameters$code[nzchar(parameters$code)])
    if (
      length(declared_code) != 1L ||
      !identical(declared_code, methods$code[[index]])
    ) {
      wlv_catalog_stop(
        "Method `%s` `_parameters.csv` code must match catalog code `%s`.",
        method,
        methods$code[[index]]
      )
    }
    declared_name <- unique(parameters$name[nzchar(parameters$name)])
    if (
      length(declared_name) != 1L ||
      !identical(declared_name, methods$description[[index]])
    ) {
      wlv_catalog_stop(
        "Method `%s` `_parameters.csv` name must match catalog description `%s`.",
        method,
        methods$description[[index]]
      )
    }
  }

  methods
}

wlv_catalog_validate_cross_references <- function(
    sources,
    methods,
    artifacts,
    missingness_policies) {
  profiles <- unique(artifacts$profile)
  missing_profiles <- setdiff(
    unique(sources$artifact_profile[nzchar(sources$artifact_profile)]),
    profiles
  )
  if (length(missing_profiles)) {
    wlv_catalog_stop(
      "The sources catalog refers to unknown artifact profile(s): %s.",
      paste(missing_profiles, collapse = ", ")
    )
  }

  missing_policies <- setdiff(
    unique(sources$missingness_policy[nzchar(sources$missingness_policy)]),
    missingness_policies$policy
  )
  if (length(missing_policies)) {
    wlv_catalog_stop(
      "The sources catalog refers to unknown missingness policy or policies: %s.",
      paste(missing_policies, collapse = ", ")
    )
  }

  stable <- sources$status == "stable"
  for (index in which(stable)) {
    profile <- sources$artifact_profile[[index]]
    rows <- artifacts$profile == profile
    operations <- unlist(
      wlv_catalog_parse_operations(artifacts$operations[rows]),
      use.names = FALSE
    )
    if (!any(rows) || !"prepare" %in% operations) {
      wlv_catalog_stop(
        "Stable source `%s` requires a non-empty artifact profile with preparation artifacts.",
        sources$source[[index]]
      )
    }
  }

  for (index in seq_len(nrow(sources))) {
    source <- sources$source[[index]]
    source_methods <- methods$source == source
    required_operations <- c(
      if (sources$can_prepare[[index]]) "prepare",
      if (any(methods$can_calculate[source_methods])) "calculate",
      if (any(methods$can_recalculate[source_methods])) "recalculate"
    )
    if (!length(required_operations)) {
      next
    }

    profile <- sources$artifact_profile[[index]]
    rows <- artifacts$profile == profile
    declared_operations <- unique(unlist(
      wlv_catalog_parse_operations(artifacts$operations[rows]),
      use.names = FALSE
    ))
    missing_operations <- setdiff(required_operations, declared_operations)
    if (length(missing_operations)) {
      wlv_catalog_stop(
        "Source `%s` artifact profile `%s` lacks required operation(s): %s.",
        source,
        profile,
        paste(missing_operations, collapse = ", ")
      )
    }
  }

  invisible(TRUE)
}

# Load and validate the complete, repository-backed method/source catalog.
wlv_load_catalog <- function(root = ".") {
  if (!is.character(root) || length(root) != 1L || is.na(root)) {
    wlv_catalog_stop("`root` must be one existing directory path.")
  }
  root <- normalizePath(root, mustWork = TRUE)
  catalog_dir <- file.path(root, "catalog")

  sources <- wlv_catalog_read_csv(
    file.path(catalog_dir, "sources.csv"),
    wlv_catalog_schemas$sources,
    "sources"
  )
  methods <- wlv_catalog_read_csv(
    file.path(catalog_dir, "methods.csv"),
    wlv_catalog_schemas$methods,
    "methods"
  )
  artifacts <- wlv_catalog_read_csv(
    file.path(catalog_dir, "artifact-profiles.csv"),
    wlv_catalog_schemas$artifacts,
    "artifact profiles"
  )
  missingness_policies <- wlv_catalog_read_csv(
    file.path(catalog_dir, "missingness-policies.csv"),
    wlv_catalog_schemas$missingness,
    "missingness policies"
  )

  sources <- wlv_catalog_validate_sources(sources, root)
  artifacts <- wlv_catalog_validate_artifacts(artifacts)
  missingness_policies <- wlv_catalog_validate_missingness_policies(
    missingness_policies,
    root
  )
  methods <- wlv_catalog_validate_methods(methods, sources, root)
  wlv_catalog_validate_cross_references(
    sources,
    methods,
    artifacts,
    missingness_policies
  )

  structure(
    list(
      root = root,
      sources = sources,
      methods = methods,
      artifacts = artifacts,
      missingness_policies = missingness_policies
    ),
    class = c("wlv_catalog", "list")
  )
}

wlv_catalog_assert <- function(catalog) {
  if (!inherits(catalog, "wlv_catalog")) {
    wlv_catalog_stop("`catalog` must be returned by `wlv_load_catalog()`.")
  }
  invisible(catalog)
}

wlv_catalog_method <- function(catalog, method) {
  wlv_catalog_assert(catalog)
  if (
    !is.character(method) || length(method) != 1L || is.na(method) ||
      !grepl("^[a-z][a-z0-9_]*$", method)
  ) {
    wlv_catalog_stop("`method` must be one valid method identifier.")
  }
  row <- catalog$methods$method == method
  if (!any(row)) {
    wlv_catalog_stop("Unknown method `%s`.", method)
  }
  catalog$methods[row, , drop = FALSE]
}

wlv_catalog_source <- function(catalog, source) {
  wlv_catalog_assert(catalog)
  if (
    !is.character(source) || length(source) != 1L || is.na(source) ||
      !grepl("^[a-z][a-z0-9_]*$", source)
  ) {
    wlv_catalog_stop("`source` must be one valid source identifier.")
  }
  row <- catalog$sources$source == source
  if (!any(row)) {
    wlv_catalog_stop("Unknown source `%s`.", source)
  }
  catalog$sources[row, , drop = FALSE]
}

wlv_catalog_missingness_policy <- function(catalog, policy) {
  wlv_catalog_assert(catalog)
  if (
    !is.character(policy) || length(policy) != 1L || is.na(policy) ||
      !grepl("^[a-z][a-z0-9_]*$", policy)
  ) {
    wlv_catalog_stop("`policy` must be one valid missingness policy identifier.")
  }
  row <- catalog$missingness_policies$policy == policy
  if (!any(row)) {
    wlv_catalog_stop("Unknown missingness policy `%s`.", policy)
  }
  catalog$missingness_policies[row, , drop = FALSE]
}

wlv_catalog_artifacts <- function(catalog, profile, operation = NULL) {
  wlv_catalog_assert(catalog)
  if (
    !is.character(profile) || length(profile) != 1L || is.na(profile) ||
      !grepl("^[a-z][a-z0-9_]*$", profile)
  ) {
    wlv_catalog_stop("`profile` must be one valid artifact profile identifier.")
  }
  rows <- catalog$artifacts$profile == profile
  if (!any(rows)) {
    wlv_catalog_stop("Unknown artifact profile `%s`.", profile)
  }
  value <- catalog$artifacts[rows, , drop = FALSE]

  if (!is.null(operation)) {
    if (
      !is.character(operation) || length(operation) != 1L || is.na(operation) ||
        !operation %in% c("prepare", "calculate", "recalculate")
    ) {
      wlv_catalog_stop(
        "`operation` must be NULL, `prepare`, `calculate`, or `recalculate`."
      )
    }
    applies <- vapply(
      wlv_catalog_parse_operations(value$operations),
      function(operations) operation %in% operations,
      logical(1)
    )
    value <- value[applies, , drop = FALSE]
  }

  rownames(value) <- NULL
  value
}

wlv_catalog_format_years <- function(year_start, year_end) {
  if (length(year_start) != length(year_end)) {
    wlv_catalog_stop("`year_start` and `year_end` must have equal lengths.")
  }
  result <- rep("", length(year_start))
  present <- !is.na(year_start) & !is.na(year_end)
  same <- present & year_start == year_end
  result[same] <- as.character(year_start[same])
  range <- present & !same
  result[range] <- paste(year_start[range], year_end[range], sep = "-")
  result
}

wlv_catalog_method_table <- function(catalog) {
  wlv_catalog_assert(catalog)
  source_rows <- match(catalog$methods$source, catalog$sources$source)
  sources <- catalog$sources[source_rows, , drop = FALSE]
  value <- data.frame(
    method = catalog$methods$method,
    code = catalog$methods$code,
    description = catalog$methods$description,
    source = catalog$methods$source,
    status = catalog$methods$status,
    source_status = sources$status,
    missingness_policy = sources$missingness_policy,
    year_start = sources$year_start,
    year_end = sources$year_end,
    years = wlv_catalog_format_years(sources$year_start, sources$year_end),
    can_prepare = sources$can_prepare,
    can_calculate = catalog$methods$can_calculate,
    can_recalculate = catalog$methods$can_recalculate,
    test = catalog$methods$test,
    documentation = catalog$methods$documentation,
    limitations = catalog$methods$limitations,
    stringsAsFactors = FALSE
  )
  value <- value[order(value$method), , drop = FALSE]
  rownames(value) <- NULL
  value
}

wlv_catalog_render_fixed_width <- function(table) {
  display <- data.frame(
    METHOD = table$method,
    SOURCE = table$source,
    STATUS = table$status,
    SOURCE_STATUS = if ("source_status" %in% names(table)) {
      table$source_status
    } else {
      rep("-", nrow(table))
    },
    YEARS = ifelse(nzchar(table$years), table$years, "-"),
    PREPARE = ifelse(table$can_prepare, "yes", "no"),
    CALCULATE = ifelse(table$can_calculate, "yes", "no"),
    RECALCULATE = ifelse(table$can_recalculate, "yes", "no"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  widths <- vapply(
    seq_along(display),
    function(index) max(nchar(c(names(display)[[index]], display[[index]]))),
    integer(1)
  )
  render_row <- function(values) {
    paste(
      vapply(
        seq_along(values),
        function(index) {
          format(values[[index]], width = widths[[index]], justify = "left")
        },
        character(1)
      ),
      collapse = "  "
    )
  }
  paste(
    c(render_row(names(display)), apply(display, 1L, render_row)),
    collapse = "\n"
  )
}

# Return catalog output ready for cat(): a fixed table, legacy names, or CSV2.
wlv_format_catalog_table <- function(
    catalog_or_table,
    format = c("table", "names", "csv")) {
  format <- match.arg(format)
  table <- if (inherits(catalog_or_table, "wlv_catalog")) {
    wlv_catalog_method_table(catalog_or_table)
  } else {
    catalog_or_table
  }
  required <- c(
    "method", "source", "status", "years", "can_prepare",
    "can_calculate", "can_recalculate"
  )
  if (!is.data.frame(table) || !all(required %in% names(table))) {
    wlv_catalog_stop(
      "`catalog_or_table` must be a catalog or a method table with: %s.",
      paste(required, collapse = ", ")
    )
  }

  if (format == "names") {
    return(paste(table$method, collapse = "\n"))
  }
  if (format == "table") {
    return(wlv_catalog_render_fixed_width(table))
  }

  lines <- character()
  connection <- textConnection("lines", open = "w", local = TRUE)
  on.exit(close(connection), add = TRUE)
  utils::write.table(
    table,
    file = connection,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = TRUE,
    na = "",
    qmethod = "double"
  )
  close(connection)
  on.exit(NULL, add = FALSE)
  paste(lines, collapse = "\n")
}
