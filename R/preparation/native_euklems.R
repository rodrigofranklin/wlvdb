# Native EU KLEMS preparation ---------------------------------------------

wlv_euklems_download_manifest <- function(root) {
  source_dir <- file.path(root, "source_data", "euklems")
  list(
    capital = list(
      url = "https://euklems.eu/bulk/Statistical_Capital.rds",
      destination = file.path(source_dir, "Statistical_Capital.rds"),
      size = 129637707,
      hash_algorithm = "sha256",
      hash = "77bf752a4c79c0e324e6be31164e8f27fdc100c89b08f68c3a227da7c7ab3b44"
    ),
    national_accounts = list(
      url = "https://euklems.eu/bulk/Statistical_National-Accounts.rds",
      destination = file.path(
        source_dir,
        "Statistical_National-Accounts.rds"
      ),
      size = 44200266,
      hash_algorithm = "sha256",
      hash = "c6f7b65eb263839ea824fe223a8cf5fc13fad444db5b7a857b6aa01b29d0a4f2"
    )
  )
}

wlv_euklems_required_services <- function() {
  c(
    "ensure_directory",
    "files_exist",
    "download_verified",
    "read_rds",
    "read_csv2",
    "write_fst",
    "add_synthetic_depreciation_component"
  )
}

wlv_normalize_euklems_years_native <- function(value) {
  if (
    !(is.character(value) || is.numeric(value)) || !length(value) ||
      anyNA(value)
  ) {
    stop(
      "EU KLEMS years must be a non-empty vector of integer years.",
      call. = FALSE
    )
  }
  character_years <- as.character(value)
  numeric_years <- suppressWarnings(as.integer(character_years))
  if (
    anyNA(numeric_years) ||
      any(as.character(numeric_years) != character_years) ||
      anyDuplicated(numeric_years)
  ) {
    stop(
      "EU KLEMS years must contain unique integers in canonical form.",
      call. = FALSE
    )
  }
  as.character(numeric_years)
}

wlv_assert_euklems_table_native <- function(value, label) {
  required_columns <- c("country", "code", "var", "year", "value")
  if (!is.data.frame(value) || !nrow(value)) {
    stop(sprintf("%s is not a non-empty data frame.", label), call. = FALSE)
  }
  missing <- setdiff(required_columns, names(value))
  if (length(missing)) {
    stop(
      sprintf("%s lacks columns: %s", label, paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_prepare_euklems_outputs <- function(ctx, years) {
  requested_euklems_years <- wlv_normalize_euklems_years_native(years)
  ensure_directory <- ctx$service("ensure_directory")
  cache_dir <- ensure_directory(ctx$path("source_data", "euklems"))
  stage_dir <- ensure_directory(ctx$stage_path("source_data", "euklems"))

  manifest <- wlv_euklems_download_manifest(ctx$root)
  download_verified <- ctx$service("download_verified")
  for (entry in manifest) {
    download_verified(
      url = entry$url,
      destination = normalizePath(
        entry$destination,
        winslash = "/",
        mustWork = FALSE
      ),
      expected_size = entry$size,
      expected_hash = entry$hash,
      hash_algorithm = entry$hash_algorithm
    )
  }
  ctx$checkpoint("euklems_after_downloads")

  read_rds <- ctx$service("read_rds")
  euklems <- read_rds(manifest$capital$destination)
  euklems_na <- read_rds(manifest$national_accounts$destination)
  wlv_assert_euklems_table_native(euklems, "EU KLEMS capital data")
  wlv_assert_euklems_table_native(
    euklems_na,
    "EU KLEMS national-accounts data"
  )

  capital_years <- unique(as.character(euklems$year))
  national_accounts_years <- unique(as.character(euklems_na$year))
  missing_capital_years <- setdiff(requested_euklems_years, capital_years)
  missing_national_accounts_years <- setdiff(
    requested_euklems_years,
    national_accounts_years
  )
  if (length(missing_capital_years) || length(missing_national_accounts_years)) {
    stop(
      sprintf(
        paste0(
          "EU KLEMS does not cover every requested year; capital missing: %s; ",
          "national accounts missing: %s."
        ),
        if (length(missing_capital_years)) {
          paste(missing_capital_years, collapse = ", ")
        } else {
          "none"
        },
        if (length(missing_national_accounts_years)) {
          paste(missing_national_accounts_years, collapse = ", ")
        } else {
          "none"
        }
      ),
      call. = FALSE
    )
  }

  read_csv2 <- ctx$service("read_csv2")
  dep_rates <- read_csv2(
    ctx$path("complementar", "euklems", "dep_rates.csv"),
    header = TRUE
  )
  aggregation <- read_csv2(
    ctx$path("complementar", "euklems", "aggregation.csv")
  )
  add_synthetic_depreciation_component <-
    ctx$service("add_synthetic_depreciation_component")
  write_fst <- ctx$service("write_fst")
  promotions <- list()

  for (year in requested_euklems_years) {
    message(sprintf("Obtaining capital composition data for %s...", year))

    lists <- list()
    lists$countries <- as.character(unique(euklems$country))
    lists$sectors <- as.character(unique(euklems$code))
    lists$ek_variables <- c(
      "K_GFCF", "K_IT", "K_CT", "K_Soft_DB", "K_TraEq", "K_OMach",
      "K_OCon", "K_RStruc", "K_OIPP", "K_Cult", "K_RD"
    )
    nums <- list(
      countries = length(lists$countries),
      sectors = length(lists$sectors),
      ek_variables = length(lists$ek_variables)
    )

    ek_k <- data.frame(
      country = rep(lists$countries, each = nums$sectors),
      stringsAsFactors = FALSE
    )
    ek_k$sector <- lists$sectors
    ek_va <- ek_dep_rate <- ek_k

    filter_na <-
      euklems_na$var == "VA" & euklems_na$year == as.numeric(year)
    ek_va$va <- dplyr::left_join(
      ek_va,
      euklems_na[filter_na, ],
      by = c("country", "sector" = "code")
    )$value
    ek_dep_rate <- dplyr::left_join(
      ek_dep_rate,
      dep_rates,
      by = c("sector" = "code")
    )

    for (variable in lists$ek_variables) {
      filter_ek <- euklems$var == variable & euklems$year == as.numeric(year)
      ek_k$temp <- dplyr::left_join(
        ek_k,
        euklems[filter_ek, ],
        by = c("country", "sector" = "code")
      )$value
      names(ek_k)[names(ek_k) == "temp"] <- variable
    }
    ek_k$control <- ek_k$K_GFCF

    ek_k$sum <- rowSums(ek_k[, lists$ek_variables], na.rm = FALSE)
    countries_to_exclude <- ek_k[
      ek_k$sector == "TOT_IND" & is.na(ek_k$sum),
      1L
    ]
    countries_to_exclude <- c(
      as.character(countries_to_exclude),
      "LU",
      "SE"
    )
    ek_k <- ek_k[!(ek_k$country %in% countries_to_exclude), ]
    ek_dep_rate <- ek_dep_rate[
      !(ek_dep_rate$country %in% countries_to_exclude),
    ]
    ek_va <- ek_va[!(ek_va$country %in% countries_to_exclude), ]

    ek_va$prop <- 0
    ek_va$prop2 <- 0
    for (aggregate in unique(
      aggregation[aggregation$level == "prop", 2L]
    )) {
      sectors <- unique(
        aggregation$disaggregated[aggregation$aggregated == aggregate]
      )
      ek_va$prop[ek_va$sector %in% sectors] <-
        ek_va$va[ek_va$sector %in% sectors] /
        rep(ek_va$va[ek_va$sector == aggregate], each = length(sectors))
    }
    for (aggregate in unique(
      aggregation[aggregation$level == "prop2", 2L]
    )) {
      sectors <- unique(
        aggregation$disaggregated[aggregation$aggregated == aggregate]
      )
      ek_va$prop2[ek_va$sector %in% sectors] <-
        ek_va$va[ek_va$sector %in% sectors] /
        rep(ek_va$va[ek_va$sector == aggregate], each = length(sectors))
    }

    ek_va_prop <- do.call(
      cbind,
      replicate(nums$ek_variables, ek_va$prop, simplify = FALSE)
    )
    ek_va_prop2 <- do.call(
      cbind,
      replicate(nums$ek_variables, ek_va$prop2, simplify = FALSE)
    )

    for (index in which(aggregation[, 3L] == "prop2")) {
      filter1 <-
        ek_k$sector == aggregation$disaggregated[index] & is.na(ek_k$sum)
      filter2 <-
        ek_k$country %in% ek_k$country[filter1] &
        ek_k$sector == aggregation$aggregated[index]
      ek_k[filter1, lists$ek_variables] <-
        ek_k[filter2, lists$ek_variables] * ek_va_prop2[filter1, ]
    }
    ek_k$sum <- rowSums(ek_k[, lists$ek_variables], na.rm = TRUE)
    for (index in which(aggregation[, 3L] == "prop")) {
      filter1 <-
        ek_k$sector == aggregation$disaggregated[index] & ek_k$sum == 0
      filter2 <-
        ek_k$country %in% ek_k$country[filter1] &
        ek_k$sector == aggregation$aggregated[index]
      ek_k[filter1, lists$ek_variables] <-
        ek_k[filter2, lists$ek_variables] * ek_va_prop[filter1, ]
    }

    ek_k[is.na(ek_k)] <- 0
    for (index in which(aggregation[, 3L] == "needed")) {
      filter1 <-
        ek_k$sector == aggregation$aggregated[index] & ek_k$control == 0
      filter2 <-
        ek_k$country %in% ek_k$country[filter1] &
        ek_k[, 2L] == aggregation$disaggregated[index]
      ek_k[filter1, lists$ek_variables] <-
        ek_k[filter1, lists$ek_variables] + ek_k[filter2, lists$ek_variables]
    }
    ek_k <- ek_k[, c("country", "sector", lists$ek_variables)]

    for (aggregate in unique(
      aggregation[aggregation[, 3L] == "new", 2L]
    )) {
      ek_temp <- ek_k[ek_k$sector == "TOT", ]
      ek_temp$sector <- aggregate
      ek_temp[, lists$ek_variables] <- 0
      ek_k <- rbind(ek_k, ek_temp)

      ek_dep_temp <- ek_dep_rate[ek_dep_rate$sector == "TOT", ]
      ek_dep_temp$sector <- aggregate
      ek_dep_temp[, lists$ek_variables] <- NA_real_
      ek_dep_rate <- rbind(ek_dep_rate, ek_dep_temp)
    }
    for (index in which(aggregation[, 3L] == "new")) {
      filter1 <- which(ek_k$sector == aggregation$aggregated[index])
      filter2 <- which(ek_k$sector == aggregation$disaggregated[index])
      ek_k[filter1, lists$ek_variables] <-
        ek_k[filter1, lists$ek_variables] + ek_k[filter2, lists$ek_variables]
    }

    direct_dep_rate_provided <- !is.na(as.matrix(
      ek_dep_rate[, lists$ek_variables, drop = FALSE]
    ))
    ek_dep_rate[is.na(ek_dep_rate)] <- 0
    for (index in which(aggregation[, 3L] %in% c("needed", "new"))) {
      filter1 <- ek_k$sector == aggregation$aggregated[index]
      filter2 <-
        ek_k$country %in% ek_k$country[filter1] &
        ek_k[, 2L] == aggregation$disaggregated[index]
      ek_dep_rate[filter1, lists$ek_variables] <-
        add_synthetic_depreciation_component(
          aggregate_rate = as.matrix(
            ek_dep_rate[filter1, lists$ek_variables, drop = FALSE]
          ),
          component_rate = as.matrix(
            ek_dep_rate[filter2, lists$ek_variables, drop = FALSE]
          ),
          component_stock = as.matrix(
            ek_k[filter2, lists$ek_variables, drop = FALSE]
          ),
          aggregate_stock = as.matrix(
            ek_k[filter1, lists$ek_variables, drop = FALSE]
          ),
          direct_rate_provided = direct_dep_rate_provided[
            filter1,
            ,
            drop = FALSE
          ]
        )
    }
    ek_dep_rate[is.na(ek_dep_rate)] <- 0

    for (aggregate in unique(
      aggregation[aggregation[, 3L] == "category", 2L]
    )) {
      ek_k$temp <- 0
      names(ek_k)[names(ek_k) == "temp"] <- aggregate
      ek_dep_rate$temp <- 0
      names(ek_dep_rate)[names(ek_dep_rate) == "temp"] <- aggregate
    }
    lists$ek_variables <- c(
      lists$ek_variables,
      unique(aggregation[aggregation[, 3L] == "category", 2L])
    )
    nums$ek_variables <- length(lists$ek_variables)
    for (index in which(aggregation$level == "category")) {
      ek_k[, aggregation$aggregated[index]] <-
        ek_k[, aggregation$aggregated[index]] +
        ek_k[, aggregation$disaggregated[index]]
    }
    for (index in which(aggregation$level == "category")) {
      ek_dep_rate[, aggregation$aggregated[index]] <-
        ek_dep_rate[, aggregation$aggregated[index]] +
        (
          ek_dep_rate[, aggregation$disaggregated[index]] *
            ek_k[, aggregation$disaggregated[index]] /
            ek_k[, aggregation$aggregated[index]]
        )
    }
    ek_dep_rate[is.na(ek_dep_rate)] <- 0

    for (variable in lists$ek_variables) {
      totals <- ek_k[ek_k$sector == "TOT", c("country", variable)]
      totals <- totals[match(ek_k$country, totals$country), variable]
      ek_k[, variable] <- ek_k[, variable] / totals
    }

    ek_k_md <- ek_k[ek_k$country == "AT", ]
    ek_k_md$country <- "MD"
    ek_dep_rate_md <- ek_k_md
    for (variable in lists$ek_variables) {
      ek_k_md[, variable] <- tapply(
        ek_k[, variable],
        match(ek_k[, 2L], ek_k_md[, 2L]),
        mean,
        na.rm = TRUE
      )
      ek_dep_rate_md[, variable] <- tapply(
        ek_dep_rate[, variable],
        match(ek_dep_rate[, 2L], ek_dep_rate_md[, 2L]),
        mean,
        na.rm = TRUE
      )
    }
    ek_k <- rbind(ek_k, ek_k_md)
    ek_dep_rate <- rbind(ek_dep_rate, ek_dep_rate_md)

    staged_capital <- file.path(stage_dir, paste0("ekk_", year, ".fst"))
    staged_depreciation <- file.path(
      stage_dir,
      paste0("ekdeprate_", year, ".fst")
    )
    write_fst(ek_k, staged_capital)
    write_fst(ek_dep_rate, staged_depreciation)
    promotions[[paste0("euklems.capital.", year)]] <-
      wlv_preparation_promotion(
        staged_capital,
        file.path(cache_dir, basename(staged_capital))
      )
    promotions[[paste0("euklems.depreciation.", year)]] <-
      wlv_preparation_promotion(
        staged_depreciation,
        file.path(cache_dir, basename(staged_depreciation))
      )
    ctx$checkpoint(paste0("euklems_after_year:", year))
  }

  list(
    promotions = promotions,
    diagnostics = list(
      years = requested_euklems_years,
      annual_artifact_count = length(promotions),
      download_manifest = manifest
    )
  )
}

wlv_prepare_euklems_task <- function(ctx) {
  result <- wlv_prepare_euklems_outputs(ctx, ctx$arg("euklems_years"))
  wlv_preparation_result(
    promotions = result$promotions,
    diagnostics = list(euklems = result$diagnostics)
  )
}

wlv_euklems_preparation_spec <- function() {
  wlv_preparation_task_spec(
    source = "euklems",
    run = wlv_prepare_euklems_task,
    services = wlv_euklems_required_services(),
    parameters = list(
      euklems_years = wlv_preparation_parameter(
        type = "integer_vector",
        default = as.integer(1995:2010),
        validator = function(value) {
          !anyDuplicated(value) && all(value >= 1900L & value <= 2200L)
        }
      )
    ),
    locks = "euklems",
    source_record_required = FALSE
  )
}
