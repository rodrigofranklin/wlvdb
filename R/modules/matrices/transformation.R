print("Transforming...")

if (!exists("wlv_solve_leontief", mode = "function")) {
  source("R/lib/leontief_diagnostics.R")
}
if (!exists("wlv_scan_leontief_zero_output_year", mode = "function")) {
  source("R/lib/result_contracts.R")
}

a <- nums$years
d <- nums$input
n <- seq_len(d)
productive <- as.logical(rows$productive)
productive_indices <- which(productive)
productive_labels <- lists$input[productive_indices]

# The Leontief coefficients are filtered on both axes. Build only the
# productive p x p block for one year at a time; no years x inputs x inputs
# intermediate is retained.
leontief_numerator_for_year <- function(year_index) {
  intermediate_consumption <- matrix(
    m_io_source[
      year_index,
      productive_indices,
      productive_indices,
      drop = FALSE
    ],
    nrow = length(productive_indices),
    ncol = length(productive_indices),
    dimnames = list(productive_labels, productive_labels)
  )
  depreciation <- matrix(
    m_io[
      year_index,
      "k_depreciation",
      productive_indices,
      productive_indices,
      drop = FALSE
    ],
    nrow = length(productive_indices),
    ncol = length(productive_indices),
    dimnames = list(productive_labels, productive_labels)
  )
  wlv_sum_input_flows(intermediate_consumption, depreciation)
}

labour_denominator <- sea_sectors[
  lists$years,
  "gross_output.s.us",
  ,
]
gross_output <- labour_denominator %>% newDim(c(a, d))
dimnames(gross_output) <- list(lists$years, lists$input)

# Pass 1: scan every year before recording or replacing anything. The complete
# WIOD13 exception profile is hash-validated atomically. No annual numeric block
# is retained; only coordinates required by the audit trail survive the pass.
leontief_zero_output_scans <- vector("list", a)
for (year_index in seq_len(a)) {
  annual_numerator <- leontief_numerator_for_year(year_index)
  leontief_zero_output_scans[[year_index]] <-
    wlv_scan_leontief_zero_output_year(
      numerator_block = annual_numerator,
      gross_output = gross_output[year_index, ],
      productive = productive,
      year_index = year_index,
      year_count = a,
      inputs = lists$input,
      outputs = lists$input
    )
  rm(annual_numerator)
}
leontief_zero_output_profile <- wlv_combine_leontief_zero_output_scans(
  leontief_zero_output_scans,
  years = lists$years,
  inputs = lists$input,
  outputs = lists$input
)
leontief_zero_output_profile <- wlv_validate_leontief_zero_output_profile(
  if (exists("wlv_contract_runtime", inherits = FALSE)) {
    wlv_contract_runtime
  } else {
    NULL
  },
  leontief_zero_output_profile
)
if (exists("wlv_contract_runtime", inherits = FALSE)) {
  wlv_record_leontief_zero_output_profile(
    wlv_contract_runtime,
    leontief_zero_output_profile,
    include_both_zero = TRUE
  )
}
rm(leontief_zero_output_scans, leontief_zero_output_profile)
gc()
print("Validated the streaming Leontief zero-output profile")

#############################.
# Calculates the labour value per unit of output
#############################.

# labour_requirements represent the amount of direct labour
# required per unit of output
labour_numerator <-
  sea_sectors[lists$years, "abstract_labour.emp.s.mv", , ] *
  rep(rows$productive, each = a)
if (exists("wlv_contract_runtime", inherits = FALSE)) {
  labour_requirements <- wlv_safe_divide_runtime(
    wlv_contract_runtime,
    labour_numerator,
    labour_denominator,
    zero = "zero_if_both_zero",
    artifact = "sea_sectors",
    indicator = "labour_requirements",
    checkpoint = "after_matrices",
    stage = 3L,
    module = "transformation.R",
    axes = c(year = 1L, sector = 2L)
  ) %>% newDim(c(a, d))
} else {
  invalid <- labour_denominator == 0 & labour_numerator != 0
  if (any(invalid)) {
    stop("Labour requirements contain nonzero labour over zero output.", call. = FALSE)
  }
  both_zero <- labour_denominator == 0 & labour_numerator == 0
  labour_requirements <- labour_numerator / labour_denominator
  labour_requirements[both_zero] <- 0
  labour_requirements <- labour_requirements %>% newDim(c(a, d))
}
dimnames(labour_requirements) <- list(lists$years, lists$input)

# lambda represents labour values per unit of output
# (i.e., per $ 1.00 of each sector)
lambda <- labour_requirements
leontief_diagnostic_rows <- vector("list", a)
diagnostic_method <- if (
  exists("method_version", inherits = TRUE) &&
  is.character(method_version) && length(method_version) == 1L &&
  !is.na(method_version) && nzchar(method_version)
) {
  method_version
} else if (
  exists("source_version", inherits = TRUE) &&
  is.character(source_version) && length(source_version) == 1L &&
  !is.na(source_version) && nzchar(source_version)
) {
  source_version
} else {
  stop("Cannot identify the method for Leontief diagnostics.", call. = FALSE)
}

# Pass 2: recreate, divide, solve, and discard one productive block per year.
print("Solving and diagnosing streaming Leontief systems...")
for (year_index in seq_len(a)) {
  annual_numerator <- leontief_numerator_for_year(year_index)
  annual_output <- gross_output[year_index, productive_indices]
  zero_output <- annual_output == 0
  invalid <-
    matrix(
      zero_output,
      nrow = nrow(annual_numerator),
      ncol = length(zero_output),
      byrow = TRUE
    ) & annual_numerator != 0
  if (any(invalid)) {
    # Every such coordinate was approved by the atomic profile validation.
    annual_numerator[invalid] <- 0
  }
  leontief_coefficients <- annual_numerator
  if (any(!zero_output)) {
    leontief_coefficients[, !zero_output] <- sweep(
      annual_numerator[, !zero_output, drop = FALSE],
      2L,
      annual_output[!zero_output],
      "/"
    )
  }
  if (any(zero_output)) {
    leontief_coefficients[, zero_output] <- 0
  }
  dimnames(leontief_coefficients) <- list(
    productive_labels,
    productive_labels
  )

  current_labour <- stats::setNames(
    as.numeric(labour_requirements[year_index, ]),
    lists$input
  )
  current_gross_output <- stats::setNames(
    as.numeric(gross_output[year_index, ]),
    lists$input
  )
  leontief_result <- wlv_solve_leontief(
    coefficient_matrix = leontief_coefficients,
    labour_requirements = current_labour,
    productive = productive,
    gross_output = current_gross_output,
    method = diagnostic_method,
    year = lists$years[[year_index]]
  )
  lambda[year_index, ] <- leontief_result$lambda
  leontief_diagnostic_rows[[year_index]] <- leontief_result$diagnostics
  rm(
    annual_numerator,
    annual_output,
    zero_output,
    leontief_coefficients,
    current_labour,
    current_gross_output,
    leontief_result
  )
}
leontief_diagnostics <- do.call(rbind, leontief_diagnostic_rows)
row.names(leontief_diagnostics) <- NULL
wlv_scientific_diagnostics <- wlv_append_leontief_diagnostics(
  if (exists("wlv_scientific_diagnostics", inherits = FALSE)) {
    wlv_scientific_diagnostics
  } else {
    list()
  },
  leontief_diagnostics
)
print("Finished solving and diagnosing streaming Leontief systems.")

m_io[, "values", n, seq_len(nums$output)] <-
  m_io_source[, n, seq_len(nums$output)] *
  rep(lambda, times = nums$output)

print("End of transformation.")

# clear environment
rm(
  year_index, a, d, n, productive, productive_indices, productive_labels,
  leontief_numerator_for_year, gross_output,
  labour_requirements, labour_numerator, labour_denominator,
  diagnostic_method, leontief_diagnostic_rows, leontief_diagnostics
)
rm(list = intersect(
  c("invalid", "both_zero"),
  ls(envir = environment(), all.names = TRUE)
), envir = environment())
gc()
