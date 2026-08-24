# Typed, declarative module configuration.
#
# Module contracts and implementations live together in R.  These CSV files
# only select registered module aliases and supply inert, typed JSON arguments.

wlv_module_config_columns <- function() {
  c(
    "instance_id", "module_id", "action", "replaces", "variant",
    "source_variable", "args_json"
  )
}

wlv_module_config_layers <- function() {
  c("common", "source", "method")
}

wlv_module_config_alias_is_valid <- function(value, allow_empty = FALSE) {
  if (!is.character(value) || anyNA(value)) {
    return(rep(FALSE, length(value)))
  }
  valid <- grepl(
    "^[a-z][a-z0-9]*(?:[._][a-z0-9]+)*$",
    value,
    perl = TRUE
  )
  if (allow_empty) valid | !nzchar(value) else valid
}

wlv_module_config_identifier <- function(value, name) {
  if (
    !is.character(value) || length(value) != 1L || is.na(value) ||
      !wlv_module_config_alias_is_valid(value)
  ) {
    stop(
      sprintf("`%s` must be one lowercase module identifier.", name),
      call. = FALSE
    )
  }
  value
}

wlv_module_config_require_jsonlite <- function() {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package `jsonlite` is required to read module arguments.", call. = FALSE)
  }
  invisible(TRUE)
}

wlv_module_config_parse_args <- function(value, path, instance_id) {
  wlv_module_config_require_jsonlite()
  if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
    stop(
      sprintf("Module `%s` in `%s` requires an `args_json` object.", instance_id, path),
      call. = FALSE
    )
  }
  if (!jsonlite::validate(value)) {
    stop(
      sprintf("Module `%s` in `%s` has invalid JSON arguments.", instance_id, path),
      call. = FALSE
    )
  }
  parsed <- jsonlite::fromJSON(value, simplifyVector = FALSE)
  if (!is.list(parsed) || is.null(names(parsed)) || anyNA(names(parsed)) ||
      any(!nzchar(names(parsed))) || anyDuplicated(names(parsed))) {
    stop(
      sprintf(
        "Module `%s` in `%s` requires a JSON object with unique named fields.",
        instance_id,
        path
      ),
      call. = FALSE
    )
  }
  parsed
}

wlv_module_config_empty <- function() {
  columns <- stats::setNames(
    rep(list(character()), length(wlv_module_config_columns())),
    wlv_module_config_columns()
  )
  value <- as.data.frame(columns, stringsAsFactors = FALSE)
  value$args <- I(list()[FALSE])
  value$layer <- character()
  value
}

wlv_read_module_config_fragment <- function(path, layer) {
  layer <- match.arg(layer, wlv_module_config_layers())
  if (!file.exists(path)) {
    stop(sprintf("Module configuration fragment does not exist: `%s`.", path), call. = FALSE)
  }
  value <- tryCatch(
    utils::read.csv2(
      path,
      stringsAsFactors = FALSE,
      colClasses = "character",
      check.names = FALSE,
      na.strings = NULL,
      fileEncoding = "UTF-8"
    ),
    error = function(error) {
      stop(
        sprintf("Cannot read module configuration `%s`: %s", path, conditionMessage(error)),
        call. = FALSE
      )
    }
  )
  expected <- wlv_module_config_columns()
  if (!identical(names(value), expected)) {
    stop(
      sprintf(
        "Module configuration `%s` must contain exactly: %s.",
        path,
        paste(expected, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (!nrow(value)) {
    value$args <- I(list()[FALSE])
    value$layer <- character()
    return(value)
  }
  if (anyDuplicated(value$instance_id)) {
    duplicates <- unique(value$instance_id[duplicated(value$instance_id)])
    stop(
      sprintf(
        "Module configuration `%s` repeats instance(s) in one layer: %s.",
        path,
        paste(duplicates, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (any(!wlv_module_config_alias_is_valid(value$instance_id))) {
    stop(sprintf("Module configuration `%s` has an invalid instance alias.", path), call. = FALSE)
  }
  if (any(!value$action %in% c("add", "replace", "remove"))) {
    stop(sprintf("Module configuration `%s` has an invalid action.", path), call. = FALSE)
  }
  needs_module <- value$action != "remove"
  if (any(!wlv_module_config_alias_is_valid(value$module_id[needs_module]))) {
    stop(sprintf("Module configuration `%s` has an invalid module alias.", path), call. = FALSE)
  }
  if (any(nzchar(value$module_id[!needs_module]))) {
    stop(sprintf("Removed instances in `%s` must not declare a module.", path), call. = FALSE)
  }
  replaces <- value$action %in% c("replace", "remove")
  if (any(!wlv_module_config_alias_is_valid(value$replaces[replaces])) ||
      any(nzchar(value$replaces[!replaces]))) {
    stop(
      sprintf("Only `replace` and `remove` actions in `%s` must declare `replaces`.", path),
      call. = FALSE
    )
  }
  if (any(!wlv_module_config_alias_is_valid(value$variant, allow_empty = TRUE))) {
    stop(sprintf("Module configuration `%s` has an invalid variant alias.", path), call. = FALSE)
  }
  source_pattern <- "^[A-Za-z][A-Za-z0-9_.]*$"
  invalid_source <- nzchar(value$source_variable) &
    !grepl(source_pattern, value$source_variable, perl = TRUE)
  if (any(invalid_source)) {
    stop(sprintf("Module configuration `%s` has an invalid source variable.", path), call. = FALSE)
  }
  if (any(value$action == "remove" &
      (nzchar(value$variant) | nzchar(value$source_variable) |
        value$args_json != "{}"))) {
    stop(sprintf("Removed instances in `%s` cannot supply arguments.", path), call. = FALSE)
  }
  args <- lapply(seq_len(nrow(value)), function(index) {
    parsed <- wlv_module_config_parse_args(
      value$args_json[[index]],
      path,
      value$instance_id[[index]]
    )
    supplied <- c(
      if (nzchar(value$variant[[index]])) "variant" else character(),
      if (nzchar(value$source_variable[[index]])) "source_variable" else character()
    )
    duplicate <- intersect(names(parsed), supplied)
    if (length(duplicate)) {
      stop(
        sprintf(
          "Module `%s` in `%s` repeats typed column(s) in `args_json`: %s.",
          value$instance_id[[index]],
          path,
          paste(duplicate, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    if (nzchar(value$variant[[index]])) parsed$variant <- value$variant[[index]]
    if (nzchar(value$source_variable[[index]])) {
      parsed$source_variable <- value$source_variable[[index]]
    }
    parsed
  })
  value$args <- I(args)
  value$layer <- rep(layer, nrow(value))
  value
}

wlv_module_config_paths <- function(root, method, source) {
  method <- wlv_module_config_identifier(method, "method")
  source <- wlv_module_config_identifier(source, "source")
  base <- file.path(root, "config", "modules")
  c(
    common = file.path(base, "common.csv"),
    source = file.path(base, "sources", paste0(source, ".csv")),
    method = file.path(base, "methods", paste0(method, ".csv"))
  )
}

wlv_read_module_config <- function(root, method, source) {
  paths <- wlv_module_config_paths(root, method, source)
  fragments <- Map(
    function(path, layer) wlv_read_module_config_fragment(path, layer),
    unname(paths),
    names(paths)
  )
  names(fragments) <- names(paths)
  fragments
}

wlv_resolve_module_config <- function(root, method, source) {
  fragments <- wlv_read_module_config(root, method, source)
  active <- list()
  history <- list()
  for (layer in wlv_module_config_layers()) {
    fragment <- fragments[[layer]]
    if (!nrow(fragment)) next
    fragment <- fragment[order(fragment$instance_id, method = "radix"), , drop = FALSE]
    available_before_layer <- names(active)
    for (index in seq_len(nrow(fragment))) {
      row <- fragment[index, , drop = FALSE]
      action <- row$action[[1L]]
      instance_id <- row$instance_id[[1L]]
      target <- row$replaces[[1L]]
      if (identical(action, "add")) {
        if (instance_id %in% names(active)) {
          stop(
            sprintf("Layer `%s` adds existing module instance `%s`.", layer, instance_id),
            call. = FALSE
          )
        }
      } else {
        if (!target %in% available_before_layer || !target %in% names(active)) {
          stop(
            sprintf(
              "Layer `%s` cannot %s missing earlier instance `%s`.",
              layer,
              action,
              target
            ),
            call. = FALSE
          )
        }
        active[[target]] <- NULL
        if (identical(action, "remove")) {
          history[[length(history) + 1L]] <- row
          next
        }
        if (instance_id %in% names(active)) {
          stop(
            sprintf("Layer `%s` replaces `%s` with existing instance `%s`.", layer, target, instance_id),
            call. = FALSE
          )
        }
      }
      row$declared_action <- action
      row$declared_layer <- layer
      row$action <- "add"
      row$replaces <- ""
      active[[instance_id]] <- row
      history[[length(history) + 1L]] <- fragment[index, , drop = FALSE]
    }
  }
  if (!length(active)) {
    result <- wlv_module_config_empty()
  } else {
    result <- do.call(rbind, active)
    row.names(result) <- NULL
    result <- result[order(result$instance_id, method = "radix"), , drop = FALSE]
  }
  class(result) <- c("wlv_module_config", class(result))
  attr(result, "method") <- method
  attr(result, "source") <- source
  attr(result, "history") <- history
  result
}

wlv_aggregation_profile_columns <- function() {
  c(
    "indicator", "level", "strategy", "module", "numerator",
    "denominator", "weight", "zero_denominator", "notes"
  )
}

wlv_read_aggregation_profile_map <- function(root) {
  path <- file.path(root, "config", "aggregations", "method_profiles.csv")
  value <- utils::read.csv2(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL,
    fileEncoding = "UTF-8"
  )
  expected <- c("method", "source", "profile")
  if (!identical(names(value), expected) || anyNA(value) ||
      any(!nzchar(as.matrix(value))) || anyDuplicated(value$method) ||
      any(!wlv_module_config_alias_is_valid(value$method)) ||
      any(!wlv_module_config_alias_is_valid(value$source)) ||
      any(!wlv_module_config_alias_is_valid(value$profile))) {
    stop("Invalid explicit aggregation profile map.", call. = FALSE)
  }
  value
}

wlv_validate_aggregation_profile <- function(value, profile, path = profile) {
  expected <- wlv_aggregation_profile_columns()
  if (!is.data.frame(value) || !identical(names(value), expected) || anyNA(value)) {
    stop(sprintf("Aggregation profile `%s` has an invalid schema.", path), call. = FALSE)
  }
  if (!nrow(value) || any(!nzchar(value$indicator)) ||
      any(!value$level %in% c("sector_to_country", "country_to_world")) ||
      any(!value$strategy %in% c(
        "sum", "mean", "ratio_of_sums", "weighted_mean", "invariant",
        "not_applicable", "formula"
      ))) {
    stop(sprintf("Aggregation profile `%s` has invalid typed rows.", path), call. = FALSE)
  }
  keys <- paste(value$indicator, value$level, sep = "\034")
  if (anyDuplicated(keys)) {
    stop(sprintf("Aggregation profile `%s` has duplicate bindings.", path), call. = FALSE)
  }
  expected_levels <- c("country_to_world", "sector_to_country")
  coverage <- split(value$level, value$indicator)
  complete <- vapply(
    coverage,
    function(levels) identical(sort(levels), expected_levels),
    logical(1L)
  )
  if (any(!complete)) {
    stop(sprintf("Aggregation profile `%s` must bind both aggregation levels.", path), call. = FALSE)
  }
  formula <- value$strategy == "formula"
  if (any(!wlv_module_config_alias_is_valid(value$module[formula])) ||
      any(nzchar(value$module[!formula]))) {
    stop(sprintf("Aggregation profile `%s` has invalid formula aliases.", path), call. = FALSE)
  }
  ratio <- value$strategy == "ratio_of_sums"
  weighted <- value$strategy == "weighted_mean"
  ratio_or_weighted <- ratio | weighted
  valid_zero <- value$zero_denominator %in% c(
    "error", "not_applicable", "zero"
  )
  if (any((ratio_or_weighted & !valid_zero) |
      (!ratio_or_weighted & nzchar(value$zero_denominator)))) {
    stop(sprintf("Aggregation profile `%s` has invalid zero policies.", path), call. = FALSE)
  }
  dependencies <- cbind(
    numerator = nzchar(value$numerator),
    denominator = nzchar(value$denominator),
    weight = nzchar(value$weight)
  )
  valid_dependencies <-
    (ratio & dependencies[, "numerator"] & dependencies[, "denominator"] &
      !dependencies[, "weight"]) |
    (weighted & !dependencies[, "numerator"] & !dependencies[, "denominator"] &
      dependencies[, "weight"]) |
    (!ratio & !weighted & rowSums(dependencies) == 0L)
  if (any(!valid_dependencies)) {
    stop(sprintf("Aggregation profile `%s` has invalid dependencies.", path), call. = FALSE)
  }
  references <- c(value$numerator, value$denominator, value$weight)
  references <- references[nzchar(references)]
  if (any(!references %in% value$indicator)) {
    stop(sprintf("Aggregation profile `%s` references an unknown indicator.", path), call. = FALSE)
  }
  for (indicator in names(coverage)) {
    rows <- value[value$indicator == indicator, , drop = FALSE]
    if (
      any(rows$strategy == "formula") &&
        (!all(rows$strategy == "formula") || length(unique(rows$module)) != 1L)
    ) {
      stop(
        sprintf("Aggregation formula bindings disagree for `%s` in `%s`.", indicator, path),
        call. = FALSE
      )
    }
  }
  class(value) <- c("wlv_aggregation_profile", class(value))
  attr(value, "profile") <- profile
  value
}

wlv_read_aggregation_profile <- function(root, profile) {
  profile <- wlv_module_config_identifier(profile, "profile")
  path <- file.path(root, "config", "aggregations", paste0(profile, ".csv"))
  if (!file.exists(path)) {
    stop(sprintf("Aggregation profile does not exist: `%s`.", path), call. = FALSE)
  }
  value <- utils::read.csv2(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL,
    fileEncoding = "UTF-8"
  )
  wlv_validate_aggregation_profile(value, profile, path)
}

wlv_read_method_aggregation_profile <- function(root, method, source = NULL) {
  method <- wlv_module_config_identifier(method, "method")
  mapping <- wlv_read_aggregation_profile_map(root)
  selected <- mapping[mapping$method == method, , drop = FALSE]
  if (!nrow(selected)) return(NULL)
  if (!is.null(source)) {
    source <- wlv_module_config_identifier(source, "source")
    if (!identical(selected$source[[1L]], source)) {
      stop(
        sprintf("Aggregation profile for `%s` belongs to source `%s`, not `%s`.", method, selected$source[[1L]], source),
        call. = FALSE
      )
    }
  }
  value <- wlv_read_aggregation_profile(root, selected$profile[[1L]])
  attr(value, "method") <- method
  attr(value, "source") <- selected$source[[1L]]
  value
}

wlv_validate_executable_module_configs <- function(root) {
  methods_path <- file.path(root, "catalog", "methods.csv")
  methods <- utils::read.csv2(
    methods_path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
  required <- c(
    "method", "source", "status", "can_calculate", "can_recalculate"
  )
  if (any(!required %in% names(methods))) {
    stop("Method catalog lacks fields required by typed module configuration.", call. = FALSE)
  }
  executable <- methods$can_calculate == "TRUE" | methods$can_recalculate == "TRUE"
  methods <- methods[executable, , drop = FALSE]
  resolved <- lapply(seq_len(nrow(methods)), function(index) {
    wlv_resolve_module_config(root, methods$method[[index]], methods$source[[index]])
  })
  names(resolved) <- methods$method

  mapping <- wlv_read_aggregation_profile_map(root)
  experimental <- methods$method[methods$status == "experimental"]
  stable <- methods$method[methods$status == "stable"]
  if (!setequal(mapping$method, experimental) || any(mapping$method %in% stable)) {
    stop(
      "Every executable experimental method, and no stable method, must select one explicit historical aggregation profile.",
      call. = FALSE
    )
  }
  for (index in seq_len(nrow(mapping))) {
    catalog_source <- methods$source[match(mapping$method[[index]], methods$method)]
    if (!identical(mapping$source[[index]], catalog_source)) {
      stop(sprintf("Aggregation source mismatch for method `%s`.", mapping$method[[index]]), call. = FALSE)
    }
    wlv_read_method_aggregation_profile(
      root,
      mapping$method[[index]],
      mapping$source[[index]]
    )
  }
  invisible(resolved)
}
