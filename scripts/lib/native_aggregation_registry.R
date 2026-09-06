# Native aggregation registry resolution ----------------------------------
#
# Stable methods retain their versioned unit contracts, whose formula rows
# carry native module IDs directly. Experimental methods use their versioned
# historical native profiles. No script path or secondary routing map is
# interpreted by the runtime.

wlv_native_formula_aggregation_id <- function(indicator) {
  if (!is.character(indicator) || length(indicator) != 1L ||
      is.na(indicator) ||
      !grepl("^[a-z][a-z0-9_.]*$", indicator)) {
    stop("A native formula aggregation requires one valid indicator ID.",
      call. = FALSE
    )
  }
  paste0("aggregation.", indicator)
}

wlv_native_aggregation_rows <- function(value, label) {
  columns <- wlv_aggregation_contract_columns()
  if (!is.data.frame(value) || any(!columns %in% names(value))) {
    stop(
      sprintf("%s does not contain complete typed aggregation rows.", label),
      call. = FALSE
    )
  }
  value <- as.data.frame(
    lapply(value[, columns, drop = FALSE], as.character),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  row.names(value) <- NULL
  if (!nrow(value) || anyNA(value)) {
    stop(
      sprintf("%s must contain non-missing typed aggregation rows.", label),
      call. = FALSE
    )
  }
  formula <- value$strategy == "formula"
  if (any(formula != nzchar(value$module))) {
    stop(
      sprintf("%s has invalid formula module declarations.", label),
      call. = FALSE
    )
  }
  if (any(!value$strategy %in% wlv_aggregation_contract_strategies())) {
    stop(sprintf("%s has an unsupported aggregation strategy.", label),
      call. = FALSE
    )
  }
  value
}

wlv_native_catalog_aggregation_rows <- function(value, label) {
  columns <- wlv_aggregation_contract_columns()
  catalog_columns <- columns
  catalog_columns[catalog_columns == "module"] <- "module_id"
  if (!is.data.frame(value) || !identical(names(value), catalog_columns)) {
    stop(
      sprintf(
        "%s must contain the exact catalog aggregation schema with `module_id`.",
        label
      ),
      call. = FALSE
    )
  }
  value <- value[catalog_columns]
  names(value)[names(value) == "module_id"] <- "module"
  wlv_native_aggregation_rows(value, label)
}

wlv_native_aggregation_canonical_rows <- function(value, units, label) {
  value <- wlv_native_aggregation_rows(value, label)
  if (!is.data.frame(units) || !"indicator" %in% names(units)) {
    stop("Unit definitions must contain an `indicator` column.", call. = FALSE)
  }
  indicators <- as.character(units$indicator)
  if (!length(indicators) || anyNA(indicators) || any(!nzchar(indicators)) ||
      anyDuplicated(indicators)) {
    stop("Unit definitions must contain ordered unique indicator IDs.",
      call. = FALSE
    )
  }
  levels <- wlv_aggregation_levels()
  expected_indicator <- rep(indicators, each = length(levels))
  expected_level <- rep(levels, times = length(indicators))
  expected_keys <- wlv_aggregation_binding_key(
    expected_indicator,
    expected_level
  )
  keys <- wlv_aggregation_binding_key(value$indicator, value$level)
  if (anyDuplicated(keys)) {
    stop(sprintf("%s contains duplicate aggregation bindings.", label),
      call. = FALSE
    )
  }
  missing <- setdiff(expected_keys, keys)
  extra <- setdiff(keys, expected_keys)
  if (length(missing) || length(extra) ||
      length(keys) != length(expected_keys)) {
    stop(
      sprintf(
        "%s does not exactly cover the ordered unit indicators.",
        label
      ),
      call. = FALSE
    )
  }
  value <- value[match(expected_keys, keys), , drop = FALSE]
  row.names(value) <- NULL
  value
}

wlv_native_validate_formula_module_ids <- function(rows, label) {
  formula <- rows$strategy == "formula"
  expected <- vapply(
    rows$indicator[formula],
    wlv_native_formula_aggregation_id,
    character(1L)
  )
  if (any(rows$module[formula] != expected)) {
    stop(
      sprintf(
        paste0(
          "%s must use explicit native formula module IDs."
        ),
        label
      ),
      call. = FALSE
    )
  }
  invisible(rows)
}

wlv_native_aggregation_solutions <- function(units, rows) {
  rows <- wlv_native_aggregation_canonical_rows(
    rows,
    units,
    "Native aggregation solution metadata"
  )
  country <- rows$level == "country_to_world"
  selected <- rows[country, , drop = FALSE]
  solution <- ifelse(
    selected$strategy == "formula",
    selected$module,
    selected$strategy
  )
  if (anyNA(solution) || any(!nzchar(solution))) {
    stop("Native country aggregation solutions must be explicit.", call. = FALSE)
  }
  data.frame(
    names = selected$indicator,
    country_solution = solution,
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

wlv_native_typed_aggregation_registry <- function(
    method,
    rows,
    missing = "available") {
  bindings <- lapply(seq_len(nrow(rows)), function(index) {
    wlv_aggregation_binding_from_row(
      rows[index, , drop = FALSE],
      missing = missing
    )
  })
  names(bindings) <- wlv_aggregation_binding_key(rows$indicator, rows$level)
  if (anyDuplicated(names(bindings))) {
    stop("Native aggregation bindings are not unique.", call. = FALSE)
  }
  indicators <- unique(rows$indicator)
  for (indicator in indicators) {
    country <- bindings[[wlv_aggregation_binding_key(
      indicator,
      "sector_to_country"
    )]]
    world <- bindings[[wlv_aggregation_binding_key(
      indicator,
      "country_to_world"
    )]]
    country_formula <- identical(country$contract_strategy, "formula")
    world_formula <- identical(world$contract_strategy, "formula")
    if (country_formula != world_formula ||
        (country_formula && !identical(country$module, world$module))) {
      stop(
        sprintf(
          "Aggregation formula bindings disagree for `%s` across levels.",
          indicator
        ),
        call. = FALSE
      )
    }
    if (!world_formula) {
      dependencies <- wlv_aggregation_binding_inputs(world)
      formula_dependencies <- dependencies[vapply(
        dependencies,
        function(dependency) {
          binding <- bindings[[wlv_aggregation_binding_key(
            dependency,
            "sector_to_country"
          )]]
          !is.null(binding) &&
            identical(binding$contract_strategy, "formula")
        },
        logical(1L)
      )]
      if (length(formula_dependencies)) {
        stop(
          sprintf(
            paste0(
              "Direct country-to-world aggregation `%s` depends on ",
              "formula-produced country indicator(s): %s."
            ),
            indicator,
            paste(formula_dependencies, collapse = ", ")
          ),
          call. = FALSE
        )
      }
    }
  }
  registry <- structure(
    list(
      method = method,
      bindings = bindings,
      rows = rows
    ),
    class = "wlv_aggregation_registry"
  )
  wlv_validate_aggregation_registry(registry)
  registry
}

wlv_native_aggregation_registry_from_rows <- function(
    method,
    units,
    rows,
    stable,
    schema_version = "2",
    missing = "available",
    label = "Aggregation contract") {
  if (!is.character(method) || length(method) != 1L || is.na(method) ||
      !grepl("^[a-z][a-z0-9_]*$", method)) {
    stop("`method` must be one valid method identifier.", call. = FALSE)
  }
  if (!is.logical(stable) || length(stable) != 1L || is.na(stable)) {
    stop("`stable` must be one explicit flag.", call. = FALSE)
  }
  if (!is.character(schema_version) || length(schema_version) != 1L ||
      is.na(schema_version) || !nzchar(schema_version)) {
    stop("`schema_version` must be one non-empty string.", call. = FALSE)
  }
  rows <- wlv_native_aggregation_canonical_rows(rows, units, label)
  if (stable) {
    wlv_native_validate_formula_module_ids(rows, label)
    wlv_validate_aggregation_dimensions(
      units,
      rows,
      strict_cross_country = !identical(schema_version, "1")
    )
  }
  registry <- wlv_native_typed_aggregation_registry(
    method = method,
    rows = rows,
    missing = missing
  )
  registry
}

wlv_native_aggregation_registry <- function(
    root,
    catalog,
    method,
    missing = "available") {
  if (!is.character(root) || length(root) != 1L || is.na(root) ||
      !dir.exists(root)) {
    stop("`root` must be one existing repository directory.", call. = FALSE)
  }
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  wlv_catalog_assert(catalog)
  if (!is.null(catalog$root)) {
    catalog_root <- normalizePath(
      catalog$root,
      winslash = "/",
      mustWork = TRUE
    )
    if (!identical(root, catalog_root)) {
      stop("`root` must match the repository used to load `catalog`.",
        call. = FALSE
      )
    }
  }

  method_record <- wlv_catalog_method(catalog, method)
  enabled_flag <- function(value) {
    isTRUE(value) || identical(as.character(value), "TRUE")
  }
  enabled <- enabled_flag(method_record$can_calculate[[1L]]) ||
    enabled_flag(method_record$can_recalculate[[1L]])
  status <- as.character(method_record$status[[1L]])
  if (!enabled || !status %in% c("stable", "experimental")) {
    stop(sprintf("Method `%s` is not executable.", method), call. = FALSE)
  }
  source <- as.character(method_record$source[[1L]])
  source_record <- wlv_catalog_source(catalog, source)
  contract_id <- as.character(source_record$unit_contract[[1L]])
  if (!nzchar(contract_id)) {
    stop(sprintf("Source `%s` has no unit contract.", source), call. = FALSE)
  }
  contract <- wlv_catalog_unit_contract(catalog, contract_id)
  stable <- identical(status, "stable")
  mapping <- wlv_read_aggregation_profile_map(root)
  selected_profile <- mapping[mapping$method == method, , drop = FALSE]

  if (stable) {
    if (nrow(selected_profile)) {
      stop(
        sprintf("Stable method `%s` must not select a historical profile.", method),
        call. = FALSE
      )
    }
    label <- sprintf("Stable unit contract `%s`", contract_id)
    rows <- wlv_native_catalog_aggregation_rows(contract$aggregations, label)
  } else {
    if (nrow(selected_profile) != 1L) {
      stop(
        sprintf(
          "Experimental method `%s` requires exactly one historical aggregation profile.",
          method
        ),
        call. = FALSE
      )
    }
    if (!identical(selected_profile$source[[1L]], source)) {
      stop(
        sprintf("Aggregation profile source mismatch for method `%s`.", method),
        call. = FALSE
      )
    }
    rows <- wlv_read_method_aggregation_profile(root, method, source)
    profile <- as.character(selected_profile$profile[[1L]])
    label <- sprintf("Historical aggregation profile `%s`", profile)
    rows <- wlv_native_aggregation_canonical_rows(rows, contract$units, label)
    wlv_native_validate_formula_module_ids(
      rows,
      sprintf("Historical aggregation profile `%s`", profile)
    )
  }

  metadata <- contract$metadata
  schema_version <- as.character(metadata$schema_version[[1L]])
  wlv_native_aggregation_registry_from_rows(
    method = method,
    units = contract$units,
    rows = rows,
    stable = stable,
    schema_version = schema_version,
    missing = missing,
    label = label
  )
}
