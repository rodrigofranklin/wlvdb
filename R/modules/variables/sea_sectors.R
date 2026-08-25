# calculates sea_sectors data
#
# there are 6 moments of variables computations:
#
# 0 - variables directly obtained from raw data
# 1 - variables obtained by computation over raw data
# 2 - assumption variables
# 3 - assumption matrices # there are no assumption matrices
# 4 - variables obtained from transformed m_io
# 5 - variables obtained by computation over SEA results

if (stage == 1) { # Stage 0 is computed only before computing stage 1 variables
  # Stage 0 variables are copied from the canonical source generation.
  
  # Copy variables from sea_source to sea_sectors (indicated in parameters)
  raw_solutions <- !grepl("\\.[Rr]$", sea_variables$sector_solution)
  legacy_scaled_solutions <- raw_solutions & grepl(
    "*",
    sea_variables$sector_solution,
    fixed = TRUE
  )
  if (any(legacy_scaled_solutions)) {
    stop(
      paste0(
        "Legacy scaled SEA source expressions are not supported for ",
        "normalized source data: ",
        paste(
          unique(sea_variables$sector_solution[legacy_scaled_solutions]),
          collapse = ", "
        )
      ),
      call. = FALSE
    )
  }
  for (loop in which(raw_solutions)) {
    if (exists("wlv_contract_runtime", inherits = FALSE)) {
      wlv_contract_clear_states(
        wlv_contract_runtime,
        "sea_sectors",
        sea_variables$names[[loop]]
      )
    }
    source_variable <- sea_variables$sector_solution[[loop]]
    if (!source_variable %in% dimnames(sea_source)[[2L]]) {
      stop(
        paste0("SEA source variable is unavailable: ", source_variable),
        call. = FALSE
      )
    }
    sea_sectors[, sea_variables$names[loop], lists$sectors, lists$countries] <- 
      sea_source[, source_variable, lists$sectors, lists$countries]
    meta_indicators[sea_variables$names[loop],"observation"] <- paste("Source:", source_version)
  }

  rm(raw_solutions, legacy_scaled_solutions)
  rm(list = intersect(
    "source_variable",
    ls(envir = environment(), all.names = TRUE)
  ))
}

# Computing stages 1 to 5, as define by "stage" variable
for (loop in sea_variables$sector_solution[which(sea_variables$stage==stage)]) {
  print(paste("Sourcing from stage",stage,"script",gsub(".*/","",loop)))
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_contract_clear_states(
      wlv_contract_runtime,
      "sea_sectors",
      sea_variables$names[
        sea_variables$stage == stage & sea_variables$sector_solution == loop
      ]
    )
  }
  source(paste0("R/modules/variables/",loop))
  issue13_nan_modules <- c(
    alternative_2 = paste0(
      "reduction/alternative_2-",
      "complex_labour_multiplier.empe.r.un.R"
    ),
    petrovic = paste0(
      "reduction/petrovic-",
      "complex_labour_multiplier.empe.r.un.R"
    )
  )
  if (
    exists("wlv_contract_runtime", inherits = FALSE) &&
      stage == 2L &&
      method_version %in% names(issue13_nan_modules) &&
      identical(loop, unname(issue13_nan_modules[[method_version]]))
  ) {
    sea_sectors <- local({
      # Validation-only restoration of the pre-contract `clean()` transition.
      # Both scientific modules are byte-identical to commit 69e0e557. The
      # historical runner converted this exact 405-cell NaN mask to zero after
      # the module; this overlay permits no other special value or coordinate.
      indicators <- c(
        "hours_worked.empe_hs.r.pc",
        "hours_worked.empe_ms.r.pc",
        "hours_worked.empe_ls.r.pc"
      )
      result <- sea_sectors
      values <- result[, indicators, , , drop = FALSE]
      nan_mask <- is.nan(values)
      other_special <-
        (is.na(values) & !nan_mask) | is.infinite(values)
      positions <- which(nan_mask, arr.ind = TRUE)
      coordinate_keys <- sort(
        paste(
          dimnames(values)[[2L]][positions[, 2L]],
          dimnames(values)[[1L]][positions[, 1L]],
          dimnames(values)[[4L]][positions[, 4L]],
          dimnames(values)[[3L]][positions[, 3L]],
          sep = "|"
        ),
        method = "radix"
      )
      expected_pairs <- c(
        "AUS|P", "BRA|P", "CHN|50", "CHN|P", "IDN|50",
        "IDN|P", "JPN|P", "KOR|P", "RUS|P"
      )
      expected_keys <- sort(
        unlist(
          lapply(indicators, function(indicator) {
            unlist(
              lapply(as.character(1995:2009), function(year) {
                paste(indicator, year, expected_pairs, sep = "|")
              }),
              use.names = FALSE
            )
          }),
          use.names = FALSE
        ),
        method = "radix"
      )
      group_counts <- vapply(indicators, function(indicator) {
        indicator_value <- result[, indicator, , , drop = FALSE]
        sum(is.nan(indicator_value))
      }, integer(1L))
      denominator_indicator <- if (
        identical(method_version, "alternative_2")
      ) {
        "complex_labour_multiplier.emp.r.un"
      } else {
        "complex_labour_multiplier.empe.r.un"
      }
      denominator <- result[
        , denominator_indicator, , , drop = FALSE
      ]
      denominator_positions <- cbind(
        positions[, 1L],
        rep.int(1L, nrow(positions)),
        positions[, 3L],
        positions[, 4L]
      )
      denominator_values <- denominator[denominator_positions]
      if (
        any(other_special) ||
          length(coordinate_keys) != 405L ||
          !identical(coordinate_keys, expected_keys) ||
          any(group_counts != 135L) ||
          any(!is.finite(denominator_values)) ||
          any(denominator_values != 0)
      ) {
        stop(
          sprintf(
            paste0(
              "Issue-13 validation overlay rejected the historical NaN ",
              "mask for `%s` (count=%s, exact_coordinate_set=%s)."
            ),
            method_version,
            length(coordinate_keys),
            identical(coordinate_keys, expected_keys)
          ),
          call. = FALSE
        )
      }
      for (indicator in indicators) {
        indicator_value <- result[, indicator, , , drop = FALSE]
        indicator_mask <- is.nan(indicator_value)
        context <- wlv_contract_context_for(
          wlv_contract_runtime,
          artifact = "sea_sectors",
          indicator = indicator,
          checkpoint = "after_stage_2",
          stage = 2L,
          module = loop,
          axes = c(year = 1L, sector = 3L, country = 4L),
          policy_id = "issue13_cc2_historical_nan_clean_v1"
        )
        wlv_contract_record(
          wlv_contract_runtime,
          wlv_contract_table(
            indicator_value,
            indicator_mask,
            context,
            "replace_historical_nan_with_zero"
          )
        )
      }
      values[nan_mask] <- 0
      result[, indicators, , ] <- values
      resolved <- result[, indicators, , , drop = FALSE]
      if (
        any(is.na(resolved)) ||
          any(is.infinite(resolved)) ||
          any(resolved[nan_mask] != 0)
      ) {
        stop(
          "Issue-13 validation overlay did not resolve the exact mask to zero.",
          call. = FALSE
        )
      }
      result
    })
  }
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    checkpoint <- paste0("after_stage_", stage)
    module_indicators <- sea_variables$names[
      sea_variables$stage == stage & sea_variables$sector_solution == loop
    ]
    for (module_indicator in module_indicators) {
      wlv_validate_sea_indicator(
        wlv_contract_runtime,
        sea_sectors,
        module_indicator,
        checkpoint = checkpoint,
        stage = stage,
        module = loop,
        years = lists$years
      )
    }
    wlv_assert_sea_no_special_values(
      wlv_contract_runtime,
      sea_sectors,
      checkpoint = checkpoint,
      stage = stage,
      module = loop
    )
  }
  print(paste("Finished sourcing script",gsub(".*/","",loop),"from stage",stage))
}

if (exists("wlv_contract_runtime", inherits = FALSE)) {
  checkpoint <- paste0("after_stage_", stage)
  wlv_validate_sea_stage(
    wlv_contract_runtime,
    sea_sectors,
    sea_variables,
    stage = stage,
    checkpoint = checkpoint,
    years = lists$years
  )
}

print(paste("Finished stage",stage))
rm(list = intersect(
  c(
    "loop", "checkpoint", "module_indicators", "module_indicator",
    "issue13_nan_modules"
  ),
  ls(envir = environment(), all.names = TRUE)
))
