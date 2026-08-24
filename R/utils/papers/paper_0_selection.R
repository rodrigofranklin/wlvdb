wlv_paper_0_spec <- function() {
  wlv_paper_spec(
    id = 0L,
    title = "Reduction problem",
    run = wlv_paper_0_run,
    required_artifacts = c(
      "m_countries.fst",
      "sea_sectors.fst",
      "sea_countries.fst"
    ),
    packages = "writexl",
    output = "reduction_problem.xlsx"
  )
}

wlv_paper_0_assert_array <- function(value, method, artifact, rank) {
  if (!is.array(value) || length(dim(value)) != rank || !is.numeric(value)) {
    stop(
      sprintf(
        "Paper 0 requires `%s` for `%s` to be one numeric rank-%s array.",
        artifact,
        method,
        rank
      ),
      call. = FALSE
    )
  }
  axes <- dimnames(value)
  if (
    is.null(axes) || length(axes) != rank ||
    any(vapply(axes, is.null, logical(1L))) ||
    any(vapply(axes, anyNA, logical(1L))) ||
    any(vapply(axes, anyDuplicated, integer(1L)) != 0L)
  ) {
    stop(
      sprintf(
        "Paper 0 requires complete, unique dimnames in `%s` for `%s`.",
        artifact,
        method
      ),
      call. = FALSE
    )
  }
  invisible(value)
}

wlv_paper_0_assert_common_axes <- function(results, artifact) {
  reference <- dimnames(results[[1L]][[artifact]])
  compatible <- vapply(results, function(result) {
    identical(dimnames(result[[artifact]]), reference)
  }, logical(1L))
  if (!all(compatible)) {
    stop(
      sprintf(
        "Paper 0 requires compatible `%s` axes for every selected method; incompatible: %s.",
        artifact,
        paste(names(results)[!compatible], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(reference)
}

wlv_paper_0_align_axes <- function(value, reference, method, artifact) {
  current <- dimnames(value)
  compatible <- length(current) == length(reference) &&
    all(vapply(seq_along(reference), function(axis) {
      setequal(current[[axis]], reference[[axis]])
    }, logical(1L)))
  if (!compatible) {
    stop(
      sprintf(
        "Paper 0 requires compatible `%s` axes for every selected method; incompatible: %s.",
        artifact,
        method
      ),
      call. = FALSE
    )
  }
  indices <- lapply(seq_along(reference), function(axis) {
    match(reference[[axis]], current[[axis]])
  })
  aligned <- do.call("[", c(list(value), indices, list(drop = FALSE)))
  dimnames(aligned) <- reference
  aligned
}

wlv_paper_0_require_axis_values <- function(values, required, axis) {
  missing <- setdiff(required, values)
  if (length(missing)) {
    stop(
      sprintf(
        "Paper 0 requires %s value(s): %s.",
        axis,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invisible(required)
}

wlv_paper_0_load_results <- function(context) {
  methods <- context$methods()
  results <- lapply(methods, function(method) {
    result <- list(
      m_countries = context$read_result(method, "m_countries.fst"),
      sea_sectors = context$read_result(method, "sea_sectors.fst"),
      sea_countries = context$read_result(method, "sea_countries.fst")
    )
    wlv_paper_0_assert_array(result$m_countries, method, "m_countries.fst", 4L)
    wlv_paper_0_assert_array(result$sea_sectors, method, "sea_sectors.fst", 4L)
    wlv_paper_0_assert_array(result$sea_countries, method, "sea_countries.fst", 3L)
    result
  })
  names(results) <- methods
  reference <- results[[1L]]
  if (length(results) > 1L) {
    for (index in 2:length(results)) {
      for (artifact in c("m_countries", "sea_sectors", "sea_countries")) {
        results[[index]][[artifact]] <- wlv_paper_0_align_axes(
          results[[index]][[artifact]],
          dimnames(reference[[artifact]]),
          methods[[index]],
          artifact
        )
      }
    }
  }
  invisible(lapply(
    c("m_countries", "sea_sectors", "sea_countries"),
    function(artifact) {
      wlv_paper_0_assert_common_axes(results, artifact)
    }
  ))

  m_axes <- dimnames(results[[1L]]$m_countries)
  sector_axes <- dimnames(results[[1L]]$sea_sectors)
  country_axes <- dimnames(results[[1L]]$sea_countries)
  if (!identical(m_axes[[1L]], sector_axes[[1L]]) ||
      !identical(m_axes[[1L]], country_axes[[1L]])) {
    stop("Paper 0 requires identical year axes in all result artifacts.", call. = FALSE)
  }
  if (!identical(m_axes[[3L]], m_axes[[4L]]) ||
      !identical(m_axes[[3L]], sector_axes[[4L]]) ||
      !identical(country_axes[[3L]], c(m_axes[[3L]], "WWW"))) {
    stop("Paper 0 requires aligned country axes and a final `WWW` aggregate.", call. = FALSE)
  }

  list(methods = methods, results = results)
}

wlv_paper_0_stack_results <- function(loaded) {
  methods <- loaded$methods
  results <- loaded$results
  first <- results[[1L]]

  m_countries <- array(
    NA_real_,
    dim = c(length(methods), dim(first$m_countries)),
    dimnames = c(list(methods), dimnames(first$m_countries))
  )
  sea_sectors <- array(
    NA_real_,
    dim = c(length(methods), dim(first$sea_sectors)),
    dimnames = c(list(methods), dimnames(first$sea_sectors))
  )
  sea_countries <- array(
    NA_real_,
    dim = c(length(methods), dim(first$sea_countries)),
    dimnames = c(list(methods), dimnames(first$sea_countries))
  )
  for (index in seq_along(methods)) {
    m_countries[index, , , , ] <- results[[index]]$m_countries
    sea_sectors[index, , , , ] <- results[[index]]$sea_sectors
    sea_countries[index, , , ] <- results[[index]]$sea_countries
  }
  list(
    methods = methods,
    m_countries = m_countries,
    sea_sectors = sea_sectors,
    sea_countries = sea_countries
  )
}

wlv_paper_0_method_country_matrix <- function(
    value,
    year,
    variable,
    countries) {
  selected <- value[, year, variable, countries, drop = FALSE]
  dim(selected) <- c(dim(value)[[1L]], length(countries))
  dimnames(selected) <- list(dimnames(value)[[1L]], countries)
  selected
}

wlv_paper_0_country_transfer_array <- function(
    value,
    year,
    variable,
    origin,
    destination) {
  selected <- value[, year, variable, origin, destination, drop = FALSE]
  dim(selected) <- c(dim(value)[[1L]], length(origin), length(destination))
  dimnames(selected) <- list(dimnames(value)[[1L]], origin, destination)
  selected
}

wlv_paper_0_tables <- function(stacked) {
  methods <- stacked$methods
  m_countries <- stacked$m_countries
  sea_sectors <- stacked$sea_sectors
  sea_countries <- stacked$sea_countries
  country_selection <- c("BRA", "USA", "JPN", "MEX")
  year <- "2009"

  sector_axes <- dimnames(sea_sectors)
  country_axes <- dimnames(sea_countries)
  matrix_axes <- dimnames(m_countries)
  wlv_paper_0_require_axis_values(sector_axes[[2L]], year, "year")
  wlv_paper_0_require_axis_values(
    sector_axes[[3L]],
    c("gross_output.s.us", "gross_output.s.du"),
    "sector indicator"
  )
  wlv_paper_0_require_axis_values(
    country_axes[[3L]],
    c(
      "gross_output.s.us",
      "gross_output.s.du",
      "gdp.s.us",
      "gdp.s.du",
      "surplus_value.empe.r.pc",
      "gdp.s.mv"
    ),
    "country indicator"
  )
  wlv_paper_0_require_axis_values(
    matrix_axes[[3L]],
    "transfers_productive_values",
    "country-matrix indicator"
  )
  wlv_paper_0_require_axis_values(matrix_axes[[4L]], country_selection, "country")
  wlv_paper_0_require_axis_values(
    country_axes[[4L]],
    c(country_selection, "WWW"),
    "country"
  )

  method_count <- length(methods)
  country_count <- length(matrix_axes[[4L]])
  country_sector_count <- length(sector_axes[[4L]]) * country_count
  percent_columns <- (method_count + 2L):(method_count * 2L + 1L)
  result_columns <- c(
    1L,
    c(rbind(
      seq_len(method_count) + 1L,
      (method_count + 2L):(method_count * 2L + 1L)
    ))
  )

  market_prices <- sea_sectors[
    1L,
    year,
    "gross_output.s.us",
    ,
    ,
    drop = TRUE
  ]
  dim(market_prices) <- country_sector_count
  direct_prices <- sea_sectors[
    ,
    year,
    "gross_output.s.du",
    ,
    ,
    drop = FALSE
  ]
  dim(direct_prices) <- c(method_count, country_sector_count)
  table_0 <- cbind(market_prices, t(direct_prices))
  colnames(table_0) <- c("market_prices", methods)

  gross_output_us <- wlv_paper_0_method_country_matrix(
    sea_countries,
    year,
    "gross_output.s.us",
    country_selection
  )
  gross_output_du <- wlv_paper_0_method_country_matrix(
    sea_countries,
    year,
    "gross_output.s.du",
    country_selection
  )
  table_1 <- cbind(
    gross_output_us[1L, ] / 1000000,
    t(gross_output_du) / 1000000,
    t(gross_output_du / gross_output_us)
  )
  colnames(table_1)[percent_columns] <- "%"
  table_1 <- table_1[, result_columns, drop = FALSE]

  gdp_us <- wlv_paper_0_method_country_matrix(
    sea_countries,
    year,
    "gdp.s.us",
    country_selection
  )
  gdp_du <- wlv_paper_0_method_country_matrix(
    sea_countries,
    year,
    "gdp.s.du",
    country_selection
  )
  table_2 <- cbind(
    gdp_us[1L, ] / 1000000,
    t(gdp_du) / 1000000,
    t(gdp_du / gdp_us)
  )
  colnames(table_2)[percent_columns] <- "%"
  table_2 <- table_2[, result_columns, drop = FALSE]

  exploitation_rate <- wlv_paper_0_method_country_matrix(
    sea_countries,
    year,
    "surplus_value.empe.r.pc",
    c(country_selection, "WWW")
  )
  table_3 <- t(exploitation_rate)

  non_ochoa <- which(!grepl("ochoa", methods))
  if (length(non_ochoa)) {
    skill_variables <- grep(
      "surplus_value.empe_",
      country_axes[[3L]],
      value = TRUE
    )
    if (!length(skill_variables)) {
      stop(
        "Paper 0 requires skill-level surplus-value indicators for non-Ochoa methods.",
        call. = FALSE
      )
    }
    skill_slice <- sea_countries[
      non_ochoa,
      year,
      skill_variables,
      c(country_selection, "WWW"),
      drop = FALSE
    ]
    dim(skill_slice) <- c(
      length(non_ochoa),
      length(skill_variables),
      length(c(country_selection, "WWW"))
    )
    dimnames(skill_slice) <- list(
      methods[non_ochoa],
      skill_variables,
      c(country_selection, "WWW")
    )
    if (length(non_ochoa) > 1L) {
      table_4 <- aperm(skill_slice, c(3L, 2L, 1L))
      dim(table_4) <- c(dim(table_4)[[1L]], prod(dim(table_4)[-1L]))
    } else {
      table_4 <- t(skill_slice[1L, , , drop = TRUE])
    }
  } else {
    table_4 <- "only if methods other than ochoa's selected"
  }

  f1_bra_exploitation_rate <- sea_countries[
    ,
    ,
    "surplus_value.empe.r.pc",
    "BRA",
    drop = TRUE
  ]
  f1_usa_exploitation_rate <- sea_countries[
    ,
    ,
    "surplus_value.empe.r.pc",
    "USA",
    drop = TRUE
  ]
  f1_world_exploitation_rate <- sea_countries[
    ,
    ,
    "surplus_value.empe.r.pc",
    "WWW",
    drop = TRUE
  ]

  outgoing <- wlv_paper_0_country_transfer_array(
    m_countries,
    year,
    "transfers_productive_values",
    country_selection,
    matrix_axes[[5L]]
  )
  incoming <- wlv_paper_0_country_transfer_array(
    m_countries,
    year,
    "transfers_productive_values",
    matrix_axes[[4L]],
    country_selection
  )
  net_transfers <- outgoing - aperm(incoming, c(1L, 3L, 2L))
  net_transfer_sums <- vapply(seq_len(method_count), function(index) {
    rowSums(net_transfers[index, , , drop = TRUE])
  }, numeric(length(country_selection)))
  dimnames(net_transfer_sums) <- list(country_selection, methods)
  gdp_mv <- wlv_paper_0_method_country_matrix(
    sea_countries,
    year,
    "gdp.s.mv",
    country_selection
  )
  table_5 <- net_transfer_sums / t(gdp_mv)

  f2_bra_usa_unequal <- (
    m_countries[, , "transfers_productive_values", "BRA", "USA"] -
      m_countries[, , "transfers_productive_values", "USA", "BRA"]
  ) / sea_countries[, , "gdp.s.mv", "BRA"]
  f2_mex_usa_unequal <- (
    m_countries[, , "transfers_productive_values", "MEX", "USA"] -
      m_countries[, , "transfers_productive_values", "USA", "MEX"]
  ) / sea_countries[, , "gdp.s.mv", "MEX"]

  list(
    data.frame(table_0),
    data.frame(table_1),
    data.frame(table_2),
    data.frame(table_3),
    data.frame(table_4),
    data.frame(f1_bra_exploitation_rate),
    data.frame(f1_usa_exploitation_rate),
    data.frame(f1_world_exploitation_rate),
    data.frame(table_5),
    data.frame(f2_bra_usa_unequal),
    data.frame(f2_mex_usa_unequal)
  )
}

wlv_paper_0_run <- function(context) {
  wlv_paper_assert_context(context)
  loaded <- wlv_paper_0_load_results(context)
  sheets <- wlv_paper_0_tables(wlv_paper_0_stack_results(loaded))
  output <- context$write_workbook("reduction_problem.xlsx", sheets)
  structure(
    list(output = output, sheets = sheets),
    class = c("wlv_paper_result", "list")
  )
}
