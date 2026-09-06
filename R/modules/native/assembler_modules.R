# Native result assemblers -------------------------------------------------

# Montagem temporal: apenas concatena blocos já calculados na ordem dos anos,
# verificando cobertura e eixos. Não soma anos nem preenche lacunas da fonte.
# As funções de estado abaixo fazem a mesma montagem para as causas de ausência.
# Guias: docs/guide-pt.md e docs/guide-en.md.
wlv_native_collect_partitioned_resource <- function(
    partitions,
    expected_years,
    trailing_dimnames,
    label) {
  if (!length(partitions)) {
    stop(sprintf("Assembler has no partitions for `%s`.", label), call. = FALSE)
  }
  observed_years <- unlist(lapply(partitions, function(value) {
    dimnames(value)[[1L]]
  }), use.names = FALSE)
  duplicates <- unique(observed_years[duplicated(observed_years)])
  missing <- setdiff(expected_years, observed_years)
  unexpected <- setdiff(observed_years, expected_years)
  if (length(duplicates) || length(missing) || length(unexpected)) {
    stop(
      sprintf(
        "Assembler coverage for `%s` is not exact (duplicate=%s; missing=%s; unexpected=%s).",
        label,
        paste(duplicates, collapse = ","),
        paste(missing, collapse = ","),
        paste(unexpected, collapse = ",")
      ),
      call. = FALSE
    )
  }
  for (value in partitions) {
    if (!identical(dimnames(value)[-1L], trailing_dimnames)) {
      stop(sprintf("Assembler labels disagree for `%s`.", label), call. = FALSE)
    }
  }
  if (
    length(partitions) == 1L &&
      identical(dimnames(partitions[[1L]])[[1L]], expected_years)
  ) {
    return(partitions[[1L]])
  }
  dimensions <- c(length(expected_years), vapply(trailing_dimnames, length, integer(1L)))
  result <- array(
    NA_real_,
    dim = dimensions,
    dimnames = c(list(year = expected_years), trailing_dimnames)
  )
  for (value in partitions) {
    indices <- c(
      list(dimnames(value)[[1L]]),
      rep(list(TRUE), length(trailing_dimnames)),
      list(value = value)
    )
    result <- do.call("[<-", c(list(result), indices))
  }
  result
}

wlv_native_collect_partitioned_state <- function(
    states,
    values,
    combined_value) {
  if (
    length(states) == 1L && length(values) == 1L &&
      identical(dim(values[[1L]]), dim(combined_value)) &&
      identical(dimnames(values[[1L]]), dimnames(combined_value))
  ) {
    wlv_semantic_state_resource_validate(
      states[[1L]],
      value = combined_value
    )
    return(states[[1L]])
  }
  state <- wlv_semantic_state_merge(
    resources = states,
    values = values,
    partition_axis = "year"
  )
  wlv_semantic_state_validate(state, value = combined_value)
  state
}

wlv_native_lift_cartesian_semantic_states <- function(
    resources,
    labels,
    inserted_axis,
    target_key,
    target_axes) {
  source_axes <- target_axes[target_axes != inserted_axis]
  if (length(source_axes) != length(target_axes) - 1L ||
      sum(target_axes == inserted_axis) != 1L) {
    return(NULL)
  }
  codecs <- vector("list", length(resources))
  nonempty <- logical(length(resources))
  for (index in seq_along(resources)) {
    resource <- resources[[index]]
    count <- wlv_semantic_state_resource_row_count(resource)
    if (!count) {
      next
    }
    codec <- if (inherits(
          resource,
          "wlv_runtime_semantic_state_codec"
        )) {
      wlv_semantic_state_resource_validate(resource)
      if (identical(resource$encoding, "cartesian")) resource else NULL
    } else {
      wlv_runtime_snapshot_state_cartesian_pack(
        resource,
        target_key = wlv_semantic_state_resource_target_key(resource),
        axes = source_axes,
        state_key = wlv_semantic_state_key(
          wlv_semantic_state_resource_target_key(resource)
        ),
        return_commitment = FALSE
      )
    }
    if (is.null(codec) || !identical(codec$axes, source_axes)) {
      return(NULL)
    }
    codecs[[index]] <- codec
    nonempty[[index]] <- TRUE
  }
  if (!any(nonempty)) {
    return(NULL)
  }
  active <- codecs[nonempty]
  first <- active[[1L]]
  compatible <- vapply(active, function(codec) {
    identical(codec$axes, first$axes) &&
      identical(codec$selectors, first$selectors) &&
      identical(codec$state, first$state)
  }, logical(1L))
  if (!all(compatible)) {
    return(NULL)
  }
  inserted_labels <- labels[nonempty]
  if (!is.character(inserted_labels) || anyNA(inserted_labels) ||
      any(!nzchar(inserted_labels)) || anyDuplicated(inserted_labels)) {
    return(NULL)
  }
  selectors <- stats::setNames(vector("list", length(target_axes)), target_axes)
  for (axis in target_axes) {
    selectors[[axis]] <- if (identical(axis, inserted_axis)) {
      sort(enc2utf8(inserted_labels), method = "radix")
    } else {
      first$selectors[[axis]]
    }
  }
  row_count <- prod(vapply(selectors, length, double(1L)))
  codec <- wlv_runtime_snapshot_new_state_codec(
    encoding = "cartesian",
    target_key = target_key,
    axes = target_axes,
    state_version = wlv_semantic_state_version(),
    row_count = row_count,
    selectors = selectors,
    state = first$state
  )
  wlv_runtime_snapshot_state_codec_validate(
    codec,
    target_key = target_key,
    axes = target_axes,
    state_key = wlv_semantic_state_key(target_key)
  )
  codec
}

wlv_native_lift_semantic_states <- function(
    resources,
    labels,
    inserted_axis,
    target_key,
    target_axes,
    prefer_compact = FALSE) {
  if (!is.list(resources) || length(resources) != length(labels)) {
    stop("Assembler semantic-state resources do not match their labels.",
      call. = FALSE
    )
  }
  if (isTRUE(prefer_compact)) {
    compact <- wlv_native_lift_cartesian_semantic_states(
      resources,
      labels,
      inserted_axis,
      target_key,
      target_axes
    )
    if (!is.null(compact)) {
      return(compact)
    }
  }
  rows <- lapply(seq_along(resources), function(index) {
    resource <- resources[[index]]
    wlv_semantic_state_resource_validate(resource)
    if (inherits(resource, "wlv_runtime_semantic_state_codec")) {
      resource <- wlv_runtime_snapshot_state_unpack(resource)
    }
    source_axes <- attr(resource, "axes", exact = TRUE)
    source <- wlv_semantic_plain_data_frame(
      resource,
      c(source_axes, "state")
    )
    result <- stats::setNames(
      rep(list(character(nrow(source))), length(target_axes) + 1L),
      c(target_axes, "state")
    )
    for (axis in target_axes) {
      result[[axis]] <- if (identical(axis, inserted_axis)) {
        rep(labels[[index]], nrow(source))
      } else {
        source[[axis]]
      }
    }
    result$state <- source$state
    as.data.frame(result, stringsAsFactors = FALSE)
  })
  combined <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    as.data.frame(
      stats::setNames(
        rep(list(character()), length(target_axes) + 1L),
        c(target_axes, "state")
      ),
      stringsAsFactors = FALSE
    )
  }
  row.names(combined) <- NULL
  wlv_semantic_new_state_resource(combined, target_key, target_axes)
}

wlv_native_matrix_assembler_requires <- function(args) {
  io <- unlist(lapply(args$io_resources, function(resource) {
    wlv_native_io_ref(
      resource,
      alias = paste0("io.", resource),
      partition = "*",
      collect = TRUE
    )
  }), recursive = FALSE)
  countries <- unlist(lapply(args$country_resources, function(resource) {
    wlv_native_country_matrix_ref(
      resource,
      alias = paste0("country.", resource),
      partition = "*",
      collect = TRUE
    )
  }), recursive = FALSE)
  c(
    wlv_native_run_ref("dimensions/lists", "lists", "list"),
    io,
    countries
  )
}

# Acrescenta o eixo variable às matrizes anuais: m_io torna-se ano × variável ×
# fornecedor × usuário; m_countries, ano × variável × origem × destino.
# Um eixo variable reúne medidas com unidades distintas, que não podem ser
# somadas entre si. A montagem preserva valores, rótulos e estados por recurso.
wlv_native_matrix_assembler_spec <- function() {
  wlv_native_module_spec(
  id = "assembler.matrices",
  scope = "run",
  checkpoint = "pre_publish",
  operations = "calculate",
  parameters = list(
    io_resources = wlv_module_parameter("list", scalar = FALSE),
    country_resources = wlv_module_parameter("list", scalar = FALSE)
  ),
  requires = wlv_native_matrix_assembler_requires,
  provides = c(
    wlv_native_artifact_output(
      "m_io",
      c("year", "variable", "input", "output")
    ),
    wlv_native_artifact_output(
      "m_countries",
      c("year", "variable", "origin", "destination")
    )
  ),
  semantic_input_mode = "explicit",
  run = function(ctx) {
    lists <- ctx$input("lists")
    io_resources <- unlist(ctx$arg("io_resources"), use.names = FALSE)
    country_resources <- unlist(ctx$arg("country_resources"), use.names = FALSE)
    io_trailing_dimnames <- dimnames(
      ctx$input(paste0("io.", io_resources[[1L]]))[[1L]]
    )[-1L]
    m_io <- array(
      NA_real_,
      dim = c(
        length(lists$years), length(io_resources),
        length(lists$input), length(lists$output)
      ),
      dimnames = list(
        year = lists$years,
        variable = io_resources,
        input = lists$input,
        output = lists$output
      )
    )
    io_states <- vector("list", length(io_resources))
    for (index in seq_along(io_resources)) {
      resource <- io_resources[[index]]
      alias <- paste0("io.", resource)
      values <- ctx$input(alias)
      combined <- wlv_native_collect_partitioned_resource(
        values,
        lists$years,
        io_trailing_dimnames,
        paste0("io/", resource)
      )
      m_io[, index, , ] <- combined
      io_states[[index]] <- wlv_native_collect_partitioned_state(
        ctx$input(wlv_native_semantic_state_alias(alias)),
        values,
        combined
      )
      rm(values, combined)
      invisible(gc(full = FALSE))
    }
    invisible(gc(full = TRUE))
    country_trailing_dimnames <- dimnames(ctx$input(
      paste0("country.", country_resources[[1L]])
    )[[1L]])[-1L]
    m_countries <- array(
      NA_real_,
      dim = c(
        length(lists$years), length(country_resources),
        length(lists$countries), length(lists$countries)
      ),
      dimnames = list(
        year = lists$years,
        variable = country_resources,
        origin = lists$countries,
        destination = lists$countries
      )
    )
    country_states <- vector("list", length(country_resources))
    for (index in seq_along(country_resources)) {
      resource <- country_resources[[index]]
      alias <- paste0("country.", resource)
      values <- ctx$input(alias)
      combined <- wlv_native_collect_partitioned_resource(
        values,
        lists$years,
        country_trailing_dimnames,
        paste0("country_matrix/", resource)
      )
      m_countries[, index, , ] <- combined
      country_states[[index]] <-
        wlv_native_collect_partitioned_state(
          ctx$input(wlv_native_semantic_state_alias(alias)),
          values,
          combined
        )
      rm(values, combined)
    }
    m_io_state <- wlv_native_lift_semantic_states(
      io_states,
      io_resources,
      "variable",
      "artifact/m_io",
      c("year", "variable", "input", "output"),
      prefer_compact = TRUE
    )
    m_countries_state <- wlv_native_lift_semantic_states(
      country_states,
      country_resources,
      "variable",
      "artifact/m_countries",
      c("year", "variable", "origin", "destination")
    )
    wlv_module_result(outputs = list(
      m_io = m_io,
      m_countries = m_countries,
      semantic_state__m_io = m_io_state,
      semantic_state__m_countries = m_countries_state
    ))
  }
)
}

wlv_native_panel_assembler_requires <- function(args) {
  indicators <- unlist(args$indicators, use.names = FALSE)
  sectors <- unlist(lapply(indicators, function(indicator) {
    wlv_native_indicator_ref(
      indicator,
      alias = paste0("sector.", indicator)
    )
  }), recursive = FALSE)
  countries <- unlist(lapply(indicators, function(indicator) {
    wlv_native_indicator_ref(
      indicator,
      alias = paste0("country.", indicator),
      level = "country"
    )
  }), recursive = FALSE)
  c(
    wlv_native_run_ref("dimensions/lists", "lists", "list"),
    sectors,
    countries
  )
}

# Prepara o contrato consumido pelo painel, após indicadores e agregações.
# sea_sectors = ano × indicador × setor × país; sea_countries = ano × indicador
# × país, incluindo WWW. O painel não deve reconstruir taxas a partir de médias:
# recebe o agregado calculado. Rótulos e estados devem concordar exatamente com
# cada recurso terminal, tanto no cálculo completo quanto no recálculo.
wlv_native_panel_assembler_spec <- function() {
  wlv_native_module_spec(
  id = "assembler.panel",
  scope = "run",
  checkpoint = "pre_publish",
  operations = c("calculate", "recalculate"),
  parameters = list(
    indicators = wlv_module_parameter("list", scalar = FALSE)
  ),
  requires = wlv_native_panel_assembler_requires,
  provides = c(
    wlv_native_artifact_output(
      "sea_sectors",
      c("year", "indicator", "sector", "country")
    ),
    wlv_native_artifact_output(
      "sea_countries",
      c("year", "indicator", "country")
    )
  ),
  run = function(ctx) {
    lists <- ctx$input("lists")
    indicators <- unlist(ctx$arg("indicators"), use.names = FALSE)
    sea_sectors <- array(
      NA_real_,
      dim = c(
        length(lists$years), length(indicators),
        length(lists$sectors), length(lists$countries)
      ),
      dimnames = list(
        year = lists$years,
        indicator = indicators,
        sector = lists$sectors,
        country = lists$countries
      )
    )
    sea_countries <- array(
      NA_real_,
      dim = c(
        length(lists$years), length(indicators),
        length(lists$countries) + 1L
      ),
      dimnames = list(
        year = lists$years,
        indicator = indicators,
        country = c(lists$countries, "WWW")
      )
    )
    sector_states <- vector("list", length(indicators))
    country_states <- vector("list", length(indicators))
    for (indicator in indicators) {
      sector_alias <- paste0("sector.", indicator)
      country_alias <- paste0("country.", indicator)
      sector <- ctx$input(sector_alias)
      country <- ctx$input(country_alias)
      if (!identical(dimnames(sector), dimnames(sea_sectors)[c(1L, 3L, 4L)]) ||
          !identical(dimnames(country), dimnames(sea_countries)[c(1L, 3L)])) {
        stop(
          sprintf("Indicator `%s` has incompatible assembler labels.", indicator),
          call. = FALSE
        )
      }
      sea_sectors[, indicator, , ] <- sector
      sea_countries[, indicator, ] <- country
      sector_states[[match(indicator, indicators)]] <- ctx$input(
        wlv_native_semantic_state_alias(sector_alias)
      )
      country_states[[match(indicator, indicators)]] <- ctx$input(
        wlv_native_semantic_state_alias(country_alias)
      )
    }
    sea_sectors_state <- wlv_native_lift_semantic_states(
      sector_states,
      indicators,
      "indicator",
      "artifact/sea_sectors",
      c("year", "indicator", "sector", "country")
    )
    sea_countries_state <- wlv_native_lift_semantic_states(
      country_states,
      indicators,
      "indicator",
      "artifact/sea_countries",
      c("year", "indicator", "country")
    )
    wlv_module_result(outputs = list(
      sea_sectors = sea_sectors,
      sea_countries = sea_countries,
      semantic_state__sea_sectors = sea_sectors_state,
      semantic_state__sea_countries = sea_countries_state
    ))
  }
)
}
