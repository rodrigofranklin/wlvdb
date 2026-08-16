wlv_gfcf_diagnostic_artifacts <- function(
    observed,
    method,
    input_unit = c("usd", "million_usd")) {
  input_unit <- match.arg(input_unit)
  required <- c("year", "input", "output", "value", "policy_id", "action")
  if (
    !is.data.frame(observed) ||
    !all(required %in% names(observed)) ||
    anyNA(observed[required]) ||
    any(!vapply(observed[required], function(value) {
      is.atomic(value) && !is.list(value)
    }, logical(1L))) ||
    !is.character(method) ||
    length(method) != 1L ||
    is.na(method) ||
    !nzchar(method)
  ) {
    stop("Invalid negative-GFCF diagnostic input.", call. = FALSE)
  }
  if (
    nrow(observed) &&
    (!is.numeric(observed$value) ||
      any(!is.finite(observed$value)) ||
      any(observed$value >= 0))
  ) {
    stop("Negative-GFCF diagnostics require finite negative values.", call. = FALSE)
  }

  divisor <- if (identical(input_unit, "usd")) 1000000 else 1
  cells <- data.frame(
    method = rep(method, nrow(observed)),
    year = as.character(observed$year),
    supplying_country = sub("[.].*$", "", as.character(observed$input)),
    supplying_sector = sub("^[^.]+[.]", "", as.character(observed$input)),
    investing_country = sub("[.](c41|c60)$", "", as.character(observed$output)),
    final_demand = sub("^.*[.]", "", as.character(observed$output)),
    input = as.character(observed$input),
    output = as.character(observed$output),
    original_million_usd = as.numeric(observed$value) / divisor,
    original_canonical_million_usd = sprintf(
      "%.17g",
      as.numeric(observed$value) / divisor
    ),
    applied_million_usd = rep(0, nrow(observed)),
    delta_million_usd = -as.numeric(observed$value) / divisor,
    policy_id = as.character(observed$policy_id),
    action = as.character(observed$action),
    stringsAsFactors = FALSE
  )
  if (nrow(cells)) {
    invalid_labels <-
      cells$supplying_country == cells$input |
      cells$supplying_sector == cells$input |
      cells$investing_country == cells$output |
      !cells$final_demand %in% c("c41", "c60")
    if (any(invalid_labels)) {
      stop("Negative-GFCF diagnostics contain invalid WIOD labels.", call. = FALSE)
    }
    cells <- cells[
      order(
        abs(cells$original_million_usd),
        cells$year,
        cells$input,
        cells$output,
        decreasing = c(TRUE, FALSE, FALSE, FALSE),
        method = "radix"
      ),
      ,
      drop = FALSE
    ]
  }
  cells$absolute_rank <- seq_len(nrow(cells))
  cells <- cells[c(
    "method", "absolute_rank", "year", "supplying_country",
    "supplying_sector", "investing_country", "final_demand", "input",
    "output", "original_million_usd", "applied_million_usd",
    "original_canonical_million_usd", "delta_million_usd", "policy_id",
    "action"
  )]
  row.names(cells) <- NULL

  summarize <- function(scope, year = NULL, country_role = NULL,
                        country = NULL, sector = NULL) {
    if (!nrow(cells)) {
      return(data.frame())
    }
    keys <- data.frame(
      year = if (is.null(year)) rep("", nrow(cells)) else as.character(year),
      country_role = if (is.null(country_role)) {
        rep("", nrow(cells))
      } else {
        rep(as.character(country_role), nrow(cells))
      },
      country = if (is.null(country)) {
        rep("", nrow(cells))
      } else {
        as.character(country)
      },
      sector = if (is.null(sector)) {
        rep("", nrow(cells))
      } else {
        as.character(sector)
      },
      stringsAsFactors = FALSE
    )
    split_key <- interaction(keys, drop = TRUE, lex.order = TRUE)
    groups <- split(seq_len(nrow(cells)), split_key)
    do.call(rbind, lapply(groups, function(index) {
      data.frame(
        method = method,
        scope = scope,
        year = keys$year[[index[[1L]]]],
        country_role = keys$country_role[[index[[1L]]]],
        country = keys$country[[index[[1L]]]],
        sector = keys$sector[[index[[1L]]]],
        cell_count = length(index),
        original_total_million_usd = sum(cells$original_million_usd[index]),
        removed_mass_million_usd = sum(cells$delta_million_usd[index]),
        largest_negative_cell_million_usd = min(
          cells$original_million_usd[index]
        ),
        stringsAsFactors = FALSE
      )
    }))
  }

  summary <- if (nrow(cells)) {
    rbind(
      summarize("total"),
      summarize("year", year = cells$year),
      summarize(
        "investing_country",
        country_role = "investing",
        country = cells$investing_country
      ),
      summarize(
        "supplying_country",
        country_role = "supplying",
        country = cells$supplying_country
      ),
      summarize("supplying_sector", sector = cells$supplying_sector)
    )
  } else {
    data.frame(
      method = character(), scope = character(), year = character(),
      country_role = character(), country = character(), sector = character(),
      cell_count = integer(), original_total_million_usd = numeric(),
      removed_mass_million_usd = numeric(),
      largest_negative_cell_million_usd = numeric(),
      stringsAsFactors = FALSE
    )
  }
  row.names(summary) <- NULL

  stats::setNames(
    list(cells, summary),
    c("_gfcf_negative_cells.csv", "_gfcf_negative_summary.csv")
  )
}

wlv_validate_gfcf_diagnostic_artifacts <- function(
    artifacts,
    method,
    tolerance = 1e-12,
    profile_validator = NULL) {
  expected_names <- c(
    "_gfcf_negative_cells.csv",
    "_gfcf_negative_summary.csv"
  )
  if (
    !is.list(artifacts) ||
    !setequal(names(artifacts), expected_names) ||
    any(!vapply(artifacts, is.data.frame, logical(1L))) ||
    !is.character(method) || length(method) != 1L || is.na(method) ||
    !nzchar(method) ||
    !is.numeric(tolerance) || length(tolerance) != 1L ||
    is.na(tolerance) || !is.finite(tolerance) || tolerance < 0 ||
    (!is.null(profile_validator) && !is.function(profile_validator))
  ) {
    stop("Invalid published negative-GFCF diagnostics.", call. = FALSE)
  }
  if (is.null(profile_validator)) {
    if (!exists("wlv_wiodr_assert_negative_gfcf_profile", mode = "function")) {
      stop("The negative-GFCF source contract is not loaded.", call. = FALSE)
    }
    profile_validator <- get(
      "wlv_wiodr_assert_negative_gfcf_profile",
      mode = "function"
    )
  }

  cells <- artifacts[["_gfcf_negative_cells.csv"]]
  required_cells <- c(
    "method", "absolute_rank", "year", "supplying_country",
    "supplying_sector", "investing_country", "final_demand", "input",
    "output", "original_million_usd", "applied_million_usd",
    "original_canonical_million_usd", "delta_million_usd", "policy_id",
    "action"
  )
  required_summary <- c(
    "method", "scope", "year", "country_role", "country", "sector",
    "cell_count", "original_total_million_usd", "removed_mass_million_usd",
    "largest_negative_cell_million_usd"
  )
  if (
    !identical(names(cells), required_cells) ||
    !identical(
      names(artifacts[["_gfcf_negative_summary.csv"]]),
      required_summary
    ) ||
    anyNA(cells) ||
    !is.numeric(cells$original_million_usd) ||
    any(!is.finite(cells$original_million_usd)) ||
    any(cells$original_million_usd >= 0) ||
    !is.character(cells$original_canonical_million_usd) ||
    anyNA(cells$original_canonical_million_usd) ||
    any(!nzchar(cells$original_canonical_million_usd))
  ) {
    stop("Published negative-GFCF diagnostics have an invalid schema.", call. = FALSE)
  }

  expected_policy <- paste0(method, "_negative_gfcf_v1")
  expected_action <- "truncate_allowlisted_negative_gfcf"
  canonical_values <- suppressWarnings(as.numeric(
    cells$original_canonical_million_usd
  ))
  canonical_text <- sprintf("%.17g", canonical_values)
  if (
    anyNA(canonical_values) || any(!is.finite(canonical_values)) ||
    any(canonical_values >= 0) ||
    !identical(canonical_text, cells$original_canonical_million_usd) ||
    !isTRUE(all.equal(
      as.numeric(cells$original_million_usd),
      canonical_values,
      tolerance = tolerance,
      check.attributes = FALSE
    ))
  ) {
    stop(
      "Published negative-GFCF canonical magnitudes are invalid.",
      call. = FALSE
    )
  }
  canonical_observed <- data.frame(
    year = as.character(cells$year),
    input = as.character(cells$input),
    output = as.character(cells$output),
    value = canonical_values,
    value_million_usd = canonical_values,
    policy_id = rep(expected_policy, nrow(cells)),
    action = rep(expected_action, nrow(cells)),
    stringsAsFactors = FALSE
  )
  profile_validator(canonical_observed, method)
  expected <- wlv_gfcf_diagnostic_artifacts(
    canonical_observed,
    method = method,
    input_unit = "million_usd"
  )

  equal_column <- function(observed, reference) {
    if (is.numeric(reference)) {
      is.numeric(observed) && isTRUE(all.equal(
        as.numeric(observed),
        as.numeric(reference),
        tolerance = tolerance,
        check.attributes = FALSE
      ))
    } else {
      identical(as.character(observed), as.character(reference))
    }
  }
  valid <- vapply(expected_names, function(name) {
    observed <- artifacts[[name]]
    reference <- expected[[name]]
    identical(names(observed), names(reference)) &&
      identical(nrow(observed), nrow(reference)) &&
      all(vapply(
        names(reference),
        function(column) equal_column(observed[[column]], reference[[column]]),
        logical(1L)
      ))
  }, logical(1L))
  if (!all(valid)) {
    stop(
      "Published negative-GFCF diagnostics differ from the pinned profile.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_load_gfcf_diagnostic_artifacts <- function(result_dir, method) {
  names <- c(
    "_gfcf_negative_cells.csv",
    "_gfcf_negative_summary.csv"
  )
  paths <- file.path(result_dir, names)
  missing <- names[!file.exists(paths)]
  if (length(missing)) {
    stop(
      sprintf(
        paste0(
          "Cannot recalculate `%s`: published scientific sidecar(s) are ",
          "missing (%s). Run a full calculation first."
        ),
        method,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  artifacts <- stats::setNames(lapply(seq_along(paths), function(index) {
    utils::read.csv2(
      paths[[index]],
      stringsAsFactors = FALSE,
      check.names = FALSE,
      fileEncoding = "UTF-8",
      colClasses = if (identical(names[[index]], names[[1L]])) {
        c(
          method = "character", year = "character",
          supplying_country = "character", supplying_sector = "character",
          investing_country = "character", final_demand = "character",
          input = "character", output = "character",
          original_canonical_million_usd = "character",
          policy_id = "character", action = "character"
        )
      } else {
        c(
          method = "character", scope = "character", year = "character",
          country_role = "character", country = "character",
          sector = "character"
        )
      }
    )
  }), names)
  wlv_validate_gfcf_diagnostic_artifacts(artifacts, method)
  artifacts
}
