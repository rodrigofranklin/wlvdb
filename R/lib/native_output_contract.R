# Public panel ordering contract -------------------------------------------
#
# DAG order is computational, not presentational.  These data-only profiles
# preserve the indicator dimension of wlvpanel-output/1.0.0 without letting
# CSV row order influence dependency resolution.

wlv_native_output_read_csv <- function(path, columns, label) {
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(sprintf("%s does not exist: `%s`.", label, path), call. = FALSE)
  }
  value <- utils::read.csv2(
    path,
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL,
    fileEncoding = "UTF-8"
  )
  if (!identical(names(value), columns) || anyNA(value)) {
    stop(sprintf("%s has an invalid schema.", label), call. = FALSE)
  }
  value
}

wlv_native_output_identifier <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !grepl("^[a-z][a-z0-9_]*$", value)) {
    stop(sprintf("`%s` must be one valid identifier.", name), call. = FALSE)
  }
  value
}

wlv_native_output_profile_map <- function(root) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "outputs", "method_profiles.csv"),
    c("method", "profile"),
    "Output profile map"
  )
  if (!nrow(value) || any(!nzchar(as.matrix(value))) ||
      anyDuplicated(value$method) ||
      any(!vapply(value$method, function(item) {
        grepl("^[a-z][a-z0-9_]*$", item)
      }, logical(1L))) ||
      any(!vapply(value$profile, function(item) {
        grepl("^[a-z][a-z0-9_]*$", item)
      }, logical(1L)))) {
    stop("Output profile map contains invalid declarations.", call. = FALSE)
  }
  value
}

wlv_native_output_profiles <- function(root) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "outputs", "profiles.csv"),
    c("profile", "source"),
    "Output profiles"
  )
  if (!nrow(value) || any(!nzchar(value$profile)) ||
      any(!nzchar(value$source)) || anyDuplicated(value$profile)) {
    stop("Output profiles contain invalid declarations.", call. = FALSE)
  }
  value
}

wlv_native_scientific_profile_map <- function(root) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "contracts", "scientific_method_profiles.csv"),
    c("method", "output_profile", "scientific_profile"),
    "Scientific profile map"
  )
  if (!nrow(value) || any(!nzchar(as.matrix(value))) ||
      anyDuplicated(value$method) ||
      any(!vapply(unlist(value, use.names = FALSE), function(item) {
        grepl("^[a-z][a-z0-9_]*$", item)
      }, logical(1L)))) {
    stop("Scientific profile map contains invalid declarations.", call. = FALSE)
  }
  value
}

wlv_native_scientific_profile_declarations <- function(root) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "contracts", "scientific_profiles.csv"),
    c(
      "scientific_profile", "source", "leontief_zero_profile",
      "leontief_signed_profile", "nonfinite_resolution_profile"
    ),
    "Scientific profiles"
  )
  required <- value[c(
    "scientific_profile", "source", "leontief_zero_profile",
    "leontief_signed_profile", "nonfinite_resolution_profile"
  )]
  identifiers <- unlist(required, use.names = FALSE)
  if (!nrow(value) || any(!nzchar(as.matrix(required))) ||
      anyDuplicated(value$scientific_profile) ||
      any(!grepl("^[a-z][a-z0-9_]*$", identifiers))) {
    stop("Scientific profiles contain invalid declarations.", call. = FALSE)
  }
  value
}

wlv_native_scientific_integer <- function(value, name, minimum = 0L) {
  parsed <- suppressWarnings(as.integer(value))
  if (anyNA(parsed) || any(value != as.character(parsed)) ||
      any(parsed < minimum)) {
    stop(sprintf("`%s` must contain canonical integers.", name), call. = FALSE)
  }
  parsed
}

wlv_native_leontief_zero_profiles <- function(root) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "contracts", "leontief_zero_profiles.csv"),
    c("leontief_zero_profile", "exception_count", "coordinate_md5"),
    "Leontief zero-output profiles"
  )
  value$exception_count <- wlv_native_scientific_integer(
    value$exception_count,
    "exception_count"
  )
  if (!nrow(value) || anyDuplicated(value$leontief_zero_profile) ||
      any(!grepl("^[a-z][a-z0-9_]*$", value$leontief_zero_profile)) ||
      any(!grepl("^[0-9a-f]{32}$", value$coordinate_md5))) {
    stop("Leontief zero-output profiles are invalid.", call. = FALSE)
  }
  value
}

wlv_native_leontief_zero_counts <- function(root, profiles) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "contracts", "leontief_zero_counts.csv"),
    c("leontief_zero_profile", "year", "output", "exception_count"),
    "Leontief zero-output grouped counts"
  )
  value$exception_count <- wlv_native_scientific_integer(
    value$exception_count,
    "exception_count",
    minimum = 1L
  )
  keys <- paste(value$leontief_zero_profile, value$year, value$output,
    sep = "\034")
  if (any(!value$leontief_zero_profile %in%
      profiles$leontief_zero_profile) ||
      any(!grepl("^[0-9]{4}$", value$year)) ||
      any(!nzchar(value$output)) || anyDuplicated(keys)) {
    stop("Leontief zero-output grouped counts are invalid.", call. = FALSE)
  }
  totals <- vapply(profiles$leontief_zero_profile, function(profile) {
    sum(value$exception_count[value$leontief_zero_profile == profile])
  }, integer(1L))
  if (!identical(unname(totals), as.integer(profiles$exception_count))) {
    stop("Leontief zero-output grouped counts do not match their totals.",
      call. = FALSE
    )
  }
  value
}

wlv_native_leontief_signed_profiles <- function(root) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "contracts", "leontief_signed_profiles.csv"),
    c(
      "leontief_signed_profile", "year", "coefficient_negative_count",
      "certificate_type"
    ),
    "Signed Leontief profiles"
  )
  value$coefficient_negative_count <- wlv_native_scientific_integer(
    value$coefficient_negative_count,
    "coefficient_negative_count"
  )
  keys <- paste(value$leontief_signed_profile, value$year, sep = "\034")
  certificates <- c(
    "productivity_nonnegative", "absolute_convergence_signed"
  )
  if (!nrow(value) || anyDuplicated(keys) ||
      any(!grepl("^[a-z][a-z0-9_]*$", value$leontief_signed_profile)) ||
      any(!grepl("^[0-9]{4}$", value$year)) ||
      any(!value$certificate_type %in% certificates) ||
      any((value$coefficient_negative_count == 0L) !=
        (value$certificate_type == "productivity_nonnegative"))) {
    stop("Signed Leontief profiles are invalid.", call. = FALSE)
  }
  value
}

wlv_native_nonfinite_resolution_rules <- function(root) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "contracts", "nonfinite_resolution_rules.csv"),
    c(
      "nonfinite_resolution_profile", "artifact", "indicator", "year",
      "country", "sector", "from", "to"
    ),
    "Non-finite resolution rules"
  )
  keys <- do.call(paste, c(value, sep = "\034"))
  valid <-
    grepl("^[a-z][a-z0-9_]*$", value$nonfinite_resolution_profile) &
    value$artifact == "sea_sectors" &
    grepl("^[a-z][a-z0-9_.]*$", value$indicator) &
    (value$year == "*" | grepl("^[0-9]{4}$", value$year)) &
    grepl("^[A-Z0-9._-]+$", value$country) &
    nzchar(value$sector) & value$sector != "*" &
    value$from == "NaN" & value$to == "0"
  if (any(!valid) || anyDuplicated(keys)) {
    stop("Non-finite resolution rules are invalid.", call. = FALSE)
  }
  value
}

wlv_native_nonfinite_resolution_groups <- function(root) {
  value <- wlv_native_output_read_csv(
    file.path(
      root,
      "config",
      "contracts",
      "nonfinite_resolution_groups.csv"
    ),
    c(
      "nonfinite_resolution_profile", "binding", "indicator", "kind",
      "module", "expected_count", "coordinate_sha256"
    ),
    "Non-finite resolution groups"
  )
  value$expected_count <- wlv_native_scientific_integer(
    value$expected_count,
    "expected_count",
    minimum = 1L
  )
  keys <- paste(
    value$nonfinite_resolution_profile,
    value$binding,
    value$kind,
    sep = "\034"
  )
  valid <-
    grepl("^[a-z][a-z0-9_]*$", value$nonfinite_resolution_profile) &
    grepl("^[a-z][a-z0-9_.]*$", value$binding) &
    grepl("^[a-z][a-z0-9_.]*$", value$indicator) &
    value$kind %in% c("NaN", "Inf") &
    grepl("^[a-z][a-z0-9_.]*$", value$module) &
    grepl("^[0-9a-f]{64}$", value$coordinate_sha256)
  if (any(!valid) || anyDuplicated(keys)) {
    stop("Non-finite resolution groups are invalid.", call. = FALSE)
  }
  value
}

wlv_native_nonfinite_resolution_profiles <- function(root) {
  value <- wlv_native_output_read_csv(
    file.path(
      root,
      "config",
      "contracts",
      "nonfinite_resolution_profiles.csv"
    ),
    c(
      "nonfinite_resolution_profile", "action", "expected_count"
    ),
    "Non-finite resolution profiles"
  )
  value$expected_count <- wlv_native_scientific_integer(
    value$expected_count,
    "expected_count"
  )
  if (!nrow(value) || anyDuplicated(value$nonfinite_resolution_profile) ||
      any(!grepl(
        "^[a-z][a-z0-9_]*$",
        value$nonfinite_resolution_profile
      )) ||
      any(!value$action %in% c(
        "reject", "replace_nan_with_zero",
        "replace_zero_denominator_with_zero"
      )) ||
      any(value$action == "reject" & value$expected_count != 0L) ||
      any(value$action != "reject" &
        value$expected_count == 0L)) {
    stop("Non-finite resolution profiles are invalid.", call. = FALSE)
  }
  value
}

wlv_native_nonfinite_resolution_keys <- function(rules, years) {
  if (!nrow(rules)) {
    return(character())
  }
  keys <- unlist(lapply(seq_len(nrow(rules)), function(index) {
    selected_years <- if (identical(rules$year[[index]], "*")) {
      years
    } else {
      rules$year[[index]]
    }
    paste(
      selected_years,
      rules$country[[index]],
      rules$sector[[index]],
      sep = "|"
    )
  }), use.names = FALSE)
  keys <- sort(keys, method = "radix")
  if (anyDuplicated(keys)) {
    stop("Non-finite resolution rules overlap after year expansion.",
      call. = FALSE
    )
  }
  keys
}

wlv_native_scientific_profile <- function(
    root,
    catalog,
    method,
    indicators = NULL) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  wlv_catalog_assert(catalog)
  method <- wlv_native_output_identifier(method, "method")
  method_record <- wlv_catalog_method(catalog, method)
  source <- as.character(method_record$source[[1L]])
  source_record <- wlv_catalog_source(catalog, source)

  output_map <- wlv_native_output_profile_map(root)
  scientific_map <- wlv_native_scientific_profile_map(root)
  selected_output <- output_map[output_map$method == method, , drop = FALSE]
  selected_map <- scientific_map[
    scientific_map$method == method,
    ,
    drop = FALSE
  ]
  if (nrow(selected_output) != 1L || nrow(selected_map) != 1L ||
      !identical(
        selected_output$profile[[1L]],
        selected_map$output_profile[[1L]]
      )) {
    stop(sprintf("Scientific/output profile mismatch for method `%s`.", method),
      call. = FALSE
    )
  }

  declarations <- wlv_native_scientific_profile_declarations(root)
  declaration <- declarations[
    declarations$scientific_profile == selected_map$scientific_profile[[1L]],
    ,
    drop = FALSE
  ]
  if (nrow(declaration) != 1L ||
      !identical(declaration$source[[1L]], source)) {
    stop(sprintf("Scientific profile source mismatch for method `%s`.", method),
      call. = FALSE
    )
  }

  zero_profiles <- wlv_native_leontief_zero_profiles(root)
  zero_counts <- wlv_native_leontief_zero_counts(root, zero_profiles)
  zero <- zero_profiles[
    zero_profiles$leontief_zero_profile ==
      declaration$leontief_zero_profile[[1L]],
    ,
    drop = FALSE
  ]
  if (nrow(zero) != 1L) {
    stop(sprintf("Method `%s` lacks one Leontief zero-output profile.", method),
      call. = FALSE
    )
  }
  counts <- zero_counts[
    zero_counts$leontief_zero_profile == zero$leontief_zero_profile[[1L]],
    c("year", "output", "exception_count"),
    drop = FALSE
  ]

  signed_profiles <- wlv_native_leontief_signed_profiles(root)
  signed <- signed_profiles[
    signed_profiles$leontief_signed_profile ==
      declaration$leontief_signed_profile[[1L]],
    c("year", "coefficient_negative_count", "certificate_type"),
    drop = FALSE
  ]
  expected_years <- as.character(seq.int(
    as.integer(source_record$year_start[[1L]]),
    as.integer(source_record$year_end[[1L]])
  ))
  if (!identical(as.character(signed$year), expected_years) ||
      any(!counts$year %in% expected_years)) {
    stop(sprintf("Scientific year coverage is invalid for method `%s`.", method),
      call. = FALSE
    )
  }

  resolution_profiles <- wlv_native_nonfinite_resolution_profiles(root)
  resolution_rules <- wlv_native_nonfinite_resolution_rules(root)
  resolution_groups <- wlv_native_nonfinite_resolution_groups(root)
  resolution_profile <- declaration$nonfinite_resolution_profile[[1L]]
  resolution <- resolution_profiles[
    resolution_profiles$nonfinite_resolution_profile == resolution_profile,
    ,
    drop = FALSE
  ]
  if (nrow(resolution) != 1L) {
    stop(sprintf("Method `%s` lacks one non-finite resolution profile.", method),
      call. = FALSE
    )
  }
  action <- resolution$action[[1L]]
  rules <- if (identical(action, "replace_nan_with_zero")) {
    resolution_rules[
      resolution_rules$nonfinite_resolution_profile == resolution_profile,
      c("artifact", "indicator", "year", "country", "sector", "from", "to"),
      drop = FALSE
    ]
  } else {
    resolution_rules[FALSE, c(
      "artifact", "indicator", "year", "country", "sector", "from", "to"
    ), drop = FALSE]
  }
  rules <- rules[order(
    rules$indicator,
    rules$year,
    rules$country,
    rules$sector,
    method = "radix"
  ), , drop = FALSE]
  row.names(rules) <- NULL
  groups <- resolution_groups[
    resolution_groups$nonfinite_resolution_profile == resolution_profile,
    c(
      "binding", "indicator", "kind", "module", "expected_count",
      "coordinate_sha256"
    ),
    drop = FALSE
  ]
  groups <- groups[order(groups$binding, groups$kind, method = "radix"), , drop = FALSE]
  row.names(groups) <- NULL
  if ((action == "replace_nan_with_zero") != (nrow(rules) > 0L) ||
      (action != "reject") != (nrow(groups) > 0L) ||
      sum(groups$expected_count) != resolution$expected_count[[1L]] ||
      any(rules$year != "*" & !rules$year %in% expected_years)) {
    stop(sprintf("Non-finite resolution coverage is invalid for method `%s`.", method),
      call. = FALSE
    )
  }
  if (is.null(indicators)) {
    indicators <- wlv_native_output_indicators(root, catalog, method)
  }
  if (any(!rules$indicator %in% indicators)) {
    stop(sprintf("Non-finite resolution rules reference an unknown `%s` indicator.",
      method
    ), call. = FALSE)
  }
  if (any(!groups$indicator %in% indicators)) {
    stop(sprintf(
      "Non-finite resolution groups reference an unknown `%s` indicator.",
      method
    ), call. = FALSE)
  }
  configured_modules <- wlv_resolve_module_config(
    root,
    method,
    source
  )$module_id
  if (any(!groups$module %in% configured_modules)) {
    stop(sprintf(
      "Non-finite resolution groups reference an unreachable module for method `%s`.",
      method
    ), call. = FALSE)
  }
  if (action == "replace_nan_with_zero") {
    if (any(groups$kind != "NaN") ||
        any(groups$indicator != groups$binding) ||
        !setequal(groups$binding, unique(rules$indicator)) ||
        length(unique(groups$module)) != 1L) {
      stop(sprintf(
        "Non-finite resolution groups are invalid for method `%s`.",
        method
      ), call. = FALSE)
    }
    for (index in seq_len(nrow(groups))) {
      selected_rules <- rules[
        rules$indicator == groups$binding[[index]],
        ,
        drop = FALSE
      ]
      group_keys <- wlv_native_nonfinite_resolution_keys(
        selected_rules,
        expected_years
      )
      group_hash <- unclass(tolower(as.character(openssl::sha256(
        charToRaw(enc2utf8(paste(group_keys, collapse = "\n")))
      ))))
      if (length(group_keys) != groups$expected_count[[index]] ||
          !identical(group_hash, groups$coordinate_sha256[[index]])) {
        stop(sprintf(
          "Non-finite resolution group hash/count is invalid for method `%s`.",
          method
        ), call. = FALSE)
      }
    }
  } else if (action == "replace_zero_denominator_with_zero") {
    if (!setequal(groups$binding, c("emp", "empe")) ||
        any(!groups$kind %in% c("NaN", "Inf")) ||
        any(vapply(
          split(groups$module, groups$binding),
          function(modules) length(unique(modules)) != 1L,
          logical(1L)
        )) ||
        any(vapply(
          split(groups$indicator, groups$binding),
          function(indicators) length(unique(indicators)) != 1L,
          logical(1L)
        ))) {
      stop(sprintf(
        "Profiled zero-denominator groups are invalid for method `%s`.",
        method
      ), call. = FALSE)
    }
  }

  wlv_scientific_profile_contract(
    id = declaration$scientific_profile[[1L]],
    method = method,
    source = source,
    output_profile = selected_map$output_profile[[1L]],
    leontief_zero = list(
      id = zero$leontief_zero_profile[[1L]],
      exception_count = zero$exception_count[[1L]],
      coordinate_md5 = zero$coordinate_md5[[1L]],
      counts = counts
    ),
    leontief_signed = list(
      id = declaration$leontief_signed_profile[[1L]],
      rows = signed
    ),
    nonfinite_resolution = list(
      id = resolution_profile,
      action = resolution$action[[1L]],
      expected_count = resolution$expected_count[[1L]],
      groups = groups,
      rules = rules
    )
  )
}

wlv_validate_native_scientific_profiles <- function(
    root,
    catalog,
    indicators = NULL) {
  methods <- wlv_catalog_method_table(catalog)
  executable <- methods$can_calculate | methods$can_recalculate
  methods <- methods[executable, , drop = FALSE]
  mapping <- wlv_native_scientific_profile_map(root)
  if (!setequal(mapping$method, methods$method) ||
      nrow(mapping) != nrow(methods)) {
    stop("Scientific profile coverage does not exactly match executable methods.",
      call. = FALSE
    )
  }
  mapped_sources <- methods$source[match(mapping$method, methods$method)]
  profile_bindings <- paste(
    mapped_sources,
    mapping$output_profile,
    sep = "\034"
  )
  ambiguous_profiles <- names(Filter(function(bindings) {
    length(unique(bindings)) != 1L
  }, split(profile_bindings, mapping$scientific_profile)))
  if (length(ambiguous_profiles)) {
    stop(sprintf(
      "Scientific profile IDs map to incompatible source/output contracts: %s.",
      paste(sort(ambiguous_profiles, method = "radix"), collapse = ", ")
    ), call. = FALSE)
  }
  declarations <- wlv_native_scientific_profile_declarations(root)
  if (!setequal(
      unique(mapping$scientific_profile),
      declarations$scientific_profile
    )) {
    stop("Scientific profile declarations are missing or unreachable.",
      call. = FALSE
    )
  }
  zero_profiles <- wlv_native_leontief_zero_profiles(root)
  zero_counts <- wlv_native_leontief_zero_counts(root, zero_profiles)
  declared_zero <- unique(declarations$leontief_zero_profile)
  counted_zero <- unique(zero_counts$leontief_zero_profile)
  expected_counted_zero <- zero_profiles$leontief_zero_profile[
    zero_profiles$exception_count > 0L
  ]
  if (!setequal(zero_profiles$leontief_zero_profile, declared_zero) ||
      !setequal(counted_zero, expected_counted_zero)) {
    stop("Leontief zero-output profiles are missing or unreachable.",
      call. = FALSE
    )
  }
  signed_profiles <- wlv_native_leontief_signed_profiles(root)
  if (!setequal(
      unique(signed_profiles$leontief_signed_profile),
      unique(declarations$leontief_signed_profile)
    )) {
    stop("Signed Leontief profiles are missing or unreachable.",
      call. = FALSE
    )
  }
  resolution_profiles <- wlv_native_nonfinite_resolution_profiles(root)
  resolution_rules <- wlv_native_nonfinite_resolution_rules(root)
  resolution_groups <- wlv_native_nonfinite_resolution_groups(root)
  declared_resolution <- unique(declarations$nonfinite_resolution_profile)
  exact_rule_profiles <- resolution_profiles$nonfinite_resolution_profile[
    resolution_profiles$action == "replace_nan_with_zero"
  ]
  replacement_profiles <- resolution_profiles$nonfinite_resolution_profile[
    resolution_profiles$action != "reject"
  ]
  if (!setequal(
      resolution_profiles$nonfinite_resolution_profile,
      declared_resolution
    ) ||
      !setequal(
        unique(resolution_rules$nonfinite_resolution_profile),
        exact_rule_profiles
      ) ||
      !setequal(
        unique(resolution_groups$nonfinite_resolution_profile),
        replacement_profiles
      )) {
    stop("Non-finite resolution profiles are missing or unreachable.",
      call. = FALSE
    )
  }
  profiles <- lapply(methods$method, function(method) {
    wlv_native_scientific_profile(
      root,
      catalog,
      method,
      if (is.null(indicators)) NULL else indicators[[method]]
    )
  })
  names(profiles) <- methods$method
  profiles
}

wlv_native_output_overrides <- function(root, profiles) {
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "outputs", "overrides.csv"),
    c("profile", "position", "indicator"),
    "Output profile overrides"
  )
  positions <- suppressWarnings(as.integer(value$position))
  valid <- nzchar(value$profile) & nzchar(value$indicator) &
    !is.na(positions) & positions > 0L &
    value$position == as.character(positions) &
    value$profile %in% profiles$profile &
    grepl("^[a-z][a-z0-9_.]*$", value$indicator)
  keys <- paste(value$profile, value$position, sep = "\034")
  indicators <- paste(value$profile, value$indicator, sep = "\034")
  if (any(!valid) || anyDuplicated(keys) || anyDuplicated(indicators)) {
    stop("Output profile overrides contain invalid declarations.", call. = FALSE)
  }
  value$position <- positions
  value
}

wlv_native_output_source_indicators <- function(root, source) {
  source <- wlv_native_output_identifier(source, "source")
  value <- wlv_native_output_read_csv(
    file.path(root, "config", "outputs", "sources", paste0(source, ".csv")),
    "indicator",
    sprintf("Output source profile `%s`", source)
  )
  indicators <- value$indicator
  if (!length(indicators) || any(!nzchar(indicators)) ||
      anyDuplicated(indicators) || any(!grepl("^[a-z][a-z0-9_.]*$", indicators))) {
    stop(sprintf("Output source profile `%s` is invalid.", source), call. = FALSE)
  }
  indicators
}

wlv_native_output_indicators <- function(
    root,
    catalog,
    method,
    aggregation_registry = NULL) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  wlv_catalog_assert(catalog)
  method <- wlv_native_output_identifier(method, "method")
  record <- wlv_catalog_method(catalog, method)
  source <- as.character(record$source[[1L]])
  mapping <- wlv_native_output_profile_map(root)
  selected <- mapping[mapping$method == method, , drop = FALSE]
  if (nrow(selected) != 1L) {
    stop(sprintf("Method `%s` requires exactly one output profile.", method), call. = FALSE)
  }
  profiles <- wlv_native_output_profiles(root)
  profile <- profiles[
    profiles$profile == selected$profile[[1L]],
    ,
    drop = FALSE
  ]
  if (nrow(profile) != 1L || !identical(profile$source[[1L]], source)) {
    stop(sprintf("Output profile source mismatch for method `%s`.", method), call. = FALSE)
  }
  base <- wlv_native_output_source_indicators(root, source)
  overrides <- wlv_native_output_overrides(root, profiles)
  overrides <- overrides[
    overrides$profile == profile$profile[[1L]],
    ,
    drop = FALSE
  ]
  if (any(!overrides$indicator %in% base) ||
      any(overrides$position > length(base))) {
    stop(
      sprintf("Output profile `%s` has an invalid ordered override.", profile$profile[[1L]]),
      call. = FALSE
    )
  }
  indicators <- rep(NA_character_, length(base))
  if (nrow(overrides)) {
    indicators[overrides$position] <- overrides$indicator
  }
  retained <- base[!base %in% overrides$indicator]
  indicators[is.na(indicators)] <- retained

  source_record <- wlv_catalog_source(catalog, source)
  unit_contract <- wlv_catalog_unit_contract(
    catalog,
    as.character(source_record$unit_contract[[1L]])
  )
  if (!setequal(indicators, as.character(unit_contract$units$indicator))) {
    stop(
      sprintf("Output profile for `%s` differs from its unit contract.", method),
      call. = FALSE
    )
  }
  if (!is.null(aggregation_registry)) {
    wlv_validate_aggregation_registry(aggregation_registry)
    aggregation_indicators <- unique(aggregation_registry$rows$indicator)
    if (!setequal(indicators, aggregation_indicators)) {
      stop(
        sprintf("Output and aggregation profiles disagree for `%s`.", method),
        call. = FALSE
      )
    }
  }
  as.character(indicators)
}

wlv_validate_native_output_profiles <- function(root, catalog) {
  methods <- wlv_catalog_method_table(catalog)
  executable <- methods$can_calculate | methods$can_recalculate
  methods <- methods[executable, , drop = FALSE]
  mapping <- wlv_native_output_profile_map(root)
  missing <- setdiff(methods$method, mapping$method)
  extra <- setdiff(mapping$method, methods$method)
  if (length(missing) || length(extra)) {
    stop(
      sprintf(
        "Output profile coverage is invalid (missing=%s; extra=%s).",
        paste(missing, collapse = ","),
        paste(extra, collapse = ",")
      ),
      call. = FALSE
    )
  }
  result <- lapply(methods$method, function(method) {
    registry <- wlv_native_aggregation_registry(root, catalog, method)
    wlv_native_output_indicators(root, catalog, method, registry)
  })
  names(result) <- methods$method
  result
}
