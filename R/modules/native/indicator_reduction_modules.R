# Native reduction-problem indicator modules ------------------------------

wlv_native_reduction_metadata <- function(indicator, observation) {
  employee <- grepl("[.]empe[.]", indicator)
  wlv_native_indicator_metadata_row(
    indicator,
    if (employee) "Complex labour multiplier (employees only)" else "Complex labour multiplier",
    if (employee) {
      "Multiplier of labour of emplyees accordingly it's complexty and intensity."
    } else {
      "Multiplier of labour accordingly it's complexty and intensity."
    },
    observation,
    "Others", "index"
  )
}

wlv_native_reduction_output <- function(indicator) {
  wlv_native_indicator_output(indicator)
}

wlv_native_reduction_skill_refs <- function() {
  c(
    wlv_native_indicator_ref(
      "hours_worked.empe_hs.r.pc", "hours_hs",
      producer = "assumption.row"
    ),
    wlv_native_indicator_ref(
      "hours_worked.empe_ms.r.pc", "hours_ms",
      producer = "assumption.row"
    ),
    wlv_native_indicator_ref(
      "hours_worked.empe_ls.r.pc", "hours_ls",
      producer = "assumption.row"
    )
  )
}

wlv_native_reduction_skill_outputs <- function() {
  c(
    wlv_native_indicator_output(
      "hours_worked.empe_hs.r.pc", "hours_hs",
      action = "replace", predecessor = "assumption.row"
    ),
    wlv_native_indicator_output(
      "hours_worked.empe_ms.r.pc", "hours_ms",
      action = "replace", predecessor = "assumption.row"
    ),
    wlv_native_indicator_output(
      "hours_worked.empe_ls.r.pc", "hours_ls",
      action = "replace", predecessor = "assumption.row"
    )
  )
}

wlv_native_ochoa_average_wage <- function(ctx, indicator, module) {
  wlv_resolve_profiled_zero_denominator(
    ctx$service("contract_runtime"),
    numerator = ctx$input("compensation"),
    denominator = ctx$input("hours"),
    binding = if (grepl("[.]empe[.]", indicator)) "empe" else "emp",
    indicator = indicator,
    artifact = "sea_sectors",
    checkpoint = "after_stage_2",
    stage = 2L,
    module = module,
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
}

wlv_native_reduction_ones_spec <- function(id, indicator, employee = FALSE) {
  wlv_native_indicator_spec(
    id,
    checkpoint = 2L,
    requires = wlv_native_run_ref("dimensions/lists", "lists", "list"),
    provides = wlv_native_reduction_output(indicator),
    metadata = wlv_native_reduction_metadata(
      indicator,
      "Reduction Problem: Alternative 1: all labour are treated as equal."
    ),
    run = function(ctx) {
      lists <- ctx$input("lists")
      value <- array(
        1,
        dim = c(length(lists$years), length(lists$sectors), length(lists$countries)),
        dimnames = list(
          year = lists$years,
          sector = lists$sectors,
          country = lists$countries
        )
      )
      wlv_module_result(outputs = list(value = value))
    }
  )
}

wlv_indicator_complex_emp_alternative_1_spec <- function() {
  wlv_native_reduction_ones_spec(
  "indicator.complex_labour_multiplier.emp.r.un.alternative_1",
  "complex_labour_multiplier.emp.r.un"
)
}
wlv_indicator_complex_empe_alternative_1_spec <- function() {
  wlv_native_reduction_ones_spec(
  "indicator.complex_labour_multiplier.empe.r.un.alternative_1",
  "complex_labour_multiplier.empe.r.un",
  TRUE
)
}

wlv_indicator_complex_emp_alternative_2_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.complex_labour_multiplier.emp.r.un.alternative_2",
  checkpoint = 2L,
  requires = wlv_native_reduction_skill_refs(),
  provides = wlv_native_reduction_output("complex_labour_multiplier.emp.r.un"),
  metadata = wlv_native_reduction_metadata(
    "complex_labour_multiplier.emp.r.un",
    paste0("Reduction Problem: Alternative 2: considers a feasible, but arbitrary, ",
      "scale of multipliers of high and medium skilled labour regarding low skilled ",
      "labour (6.25x for high skilled and 2.5x for medium skilled labour).")
  ),
  run = function(ctx) {
    value <- (6.25 * ctx$input("hours_hs")) +
      (2.5 * ctx$input("hours_ms")) + ctx$input("hours_ls")
    value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
    wlv_module_result(outputs = list(value = value))
  }
)
}

wlv_indicator_complex_empe_alternative_2_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.complex_labour_multiplier.empe.r.un.alternative_2",
  checkpoint = 2L,
  requires = c(
    wlv_native_indicator_ref(
      "complex_labour_multiplier.emp.r.un", "multiplier",
      producer = "indicator.complex_labour_multiplier.emp.r.un"
    ),
    wlv_native_reduction_skill_refs()
  ),
  provides = c(
    wlv_native_reduction_output("complex_labour_multiplier.empe.r.un"),
    wlv_native_reduction_skill_outputs()
  ),
  metadata = wlv_native_reduction_metadata(
    "complex_labour_multiplier.empe.r.un",
    paste0("Reduction Problem: Alternative 2: considers a feasible, but arbitrary, ",
      "scale of multipliers of high and medium skilled labour regarding low skilled ",
      "labour (6.25x for high skilled and 2.5x for medium skilled labour).")
  ),
  services = "contract_runtime",
  run = function(ctx) {
    multiplier <- wlv_native_with_named_axes(
      ctx$input("multiplier"),
      c("year", "sector", "country")
    )
    value <- multiplier
    resolved_indicators <- c(
      "hours_worked.empe_hs.r.pc",
      "hours_worked.empe_ms.r.pc",
      "hours_worked.empe_ls.r.pc"
    )
    numerators <- list(
      6.25 * ctx$input("hours_hs"),
      2.5 * ctx$input("hours_ms"),
      ctx$input("hours_ls")
    )
    names(numerators) <- resolved_indicators
    raw <- lapply(numerators, function(numerator) {
      wlv_native_with_named_axes(
        numerator / multiplier,
        c("year", "sector", "country")
      )
    })
    runtime <- ctx$service("contract_runtime")
    resolved <- wlv_resolve_profiled_nonfinite(
      runtime,
      values = raw,
      numerators = numerators,
      denominator = multiplier,
      artifact = "sea_sectors",
      checkpoint = "after_stage_2",
      stage = 2L,
      module = "indicator.complex_labour_multiplier.empe.r.un.alternative_2",
      axes = c(year = 1L, sector = 2L, country = 3L)
    )
    wlv_module_result(outputs = list(
      value = value,
      hours_hs = resolved$values[[1L]],
      hours_ms = resolved$values[[2L]],
      hours_ls = resolved$values[[3L]]
    ), diagnostics = resolved$diagnostics)
  }
)
}

wlv_native_ochoa_1_spec <- function(id, employee = FALSE) {
  indicator <- paste0(
    "complex_labour_multiplier.", if (employee) "empe" else "emp", ".r.un"
  )
  compensation <- paste0("compensation.", if (employee) "empe" else "emp", ".s.us")
  hours <- paste0("hours_worked.", if (employee) "empe" else "emp", ".s.hr")
  wlv_native_indicator_spec(
    id,
    checkpoint = 2L,
    requires = c(
      wlv_native_indicator_ref(compensation, "compensation"),
      wlv_native_indicator_ref(hours, "hours"),
      wlv_native_run_ref("dimensions/lists", "lists", "list")
    ),
    provides = wlv_native_reduction_output(indicator),
    services = "contract_runtime",
    metadata = wlv_native_reduction_metadata(
      indicator,
      paste0("Reduction Problem: Ochoa 1: uses market wages as an index of skill ",
        "and intensity of labour in a world wide process of equalization of rate of surplus value.")
    ),
    run = function(ctx) {
      resolved <- wlv_native_ochoa_average_wage(ctx, indicator, id)
      w_average <- resolved$value
      w_min <- w_average
      w_min[w_min == 0] <- Inf
      w_min <- rep(
        apply(w_min, 1L, min, na.rm = TRUE),
        times = length(ctx$input("lists")$sectors) *
          length(ctx$input("lists")$countries)
      )
      value <- w_average / w_min
      value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
      wlv_module_result(
        outputs = list(value = value),
        diagnostics = resolved$diagnostics
      )
    }
  )
}

wlv_indicator_complex_emp_ochoa_1_spec <- function() {
  wlv_native_ochoa_1_spec(
  "indicator.complex_labour_multiplier.emp.r.un.ochoa_1"
)
}
wlv_indicator_complex_empe_ochoa_1_spec <- function() {
  wlv_native_ochoa_1_spec(
  "indicator.complex_labour_multiplier.empe.r.un.ochoa_1", TRUE
)
}

wlv_native_ochoa_2_spec <- function(id, employee = FALSE) {
  indicator <- paste0(
    "complex_labour_multiplier.", if (employee) "empe" else "emp", ".r.un"
  )
  compensation <- paste0("compensation.", if (employee) "empe" else "emp", ".s.us")
  hours <- paste0("hours_worked.", if (employee) "empe" else "emp", ".s.hr")
  wlv_native_indicator_spec(
    id,
    checkpoint = 2L,
    requires = c(
      wlv_native_indicator_ref(compensation, "compensation"),
      wlv_native_indicator_ref(hours, "hours"),
      wlv_native_run_ref("dimensions/rows", "rows", "data.frame"),
      wlv_native_run_ref("dimensions/lists", "lists", "list")
    ),
    provides = wlv_native_reduction_output(indicator),
    services = "contract_runtime",
    metadata = wlv_native_reduction_metadata(
      indicator,
      paste0("Reduction Problem: Ochoa 2: uses market wages as an index of skill ",
        "and intensity of labour in a national process of equalization of rate of surplus value.")
    ),
    run = function(ctx) {
      lists <- ctx$input("lists")
      resolved <- wlv_native_ochoa_average_wage(ctx, indicator, id)
      w_average <- resolved$value
      excluded <- w_average == 0
      w_average[excluded] <- Inf
      national_min <- apply(
        w_average,
        1L,
        tapply,
        ctx$input("rows")$num_country,
        min,
        na.rm = TRUE
      )
      national_min <- rep(national_min, times = length(lists$sectors))
      dim(national_min) <- c(
        length(lists$countries), length(lists$years), length(lists$sectors)
      )
      national_min <- aperm(national_min, c(2L, 3L, 1L))
      w_average[excluded] <- 0
      value <- w_average / national_min
      value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
      wlv_module_result(
        outputs = list(value = value),
        diagnostics = resolved$diagnostics
      )
    }
  )
}

wlv_indicator_complex_emp_ochoa_2_spec <- function() {
  wlv_native_ochoa_2_spec(
  "indicator.complex_labour_multiplier.emp.r.un.ochoa_2"
)
}
wlv_indicator_complex_empe_ochoa_2_spec <- function() {
  wlv_native_ochoa_2_spec(
  "indicator.complex_labour_multiplier.empe.r.un.ochoa_2", TRUE
)
}

wlv_native_petrovic_requirements <- function(employee = FALSE) {
  person <- if (employee) "empe" else "emp"
  c(
    wlv_native_indicator_ref(
      paste0("compensation.", person, ".s.us"), "compensation"
    ),
    wlv_native_indicator_ref(
      paste0("hours_worked.", person, ".s.hr"), "hours"
    ),
    wlv_native_indicator_ref(
      "compensation.empe_hs.r.pc", "compensation_hs", producer = "assumption.row"
    ),
    wlv_native_indicator_ref(
      "compensation.empe_ms.r.pc", "compensation_ms", producer = "assumption.row"
    ),
    wlv_native_indicator_ref(
      "compensation.empe_ls.r.pc", "compensation_ls", producer = "assumption.row"
    ),
    wlv_native_reduction_skill_refs()
  )
}

wlv_native_petrovic_value <- function(ctx) {
  wage <- function(compensation_share, hours_share) {
    apply(
      ctx$input("compensation") * ctx$input(compensation_share),
      1L, sum, na.rm = TRUE
    ) / apply(
      ctx$input("hours") * ctx$input(hours_share),
      1L, sum, na.rm = TRUE
    )
  }
  wage_hs <- wage("compensation_hs", "hours_hs")
  wage_ms <- wage("compensation_ms", "hours_ms")
  wage_ls <- wage("compensation_ls", "hours_ls")
  multiplier_h <- wage_hs / wage_ls
  multiplier_m <- wage_ms / wage_ls
  value <- (multiplier_h * ctx$input("hours_hs")) +
    (multiplier_m * ctx$input("hours_ms")) + ctx$input("hours_ls")
  list(value = value, multiplier_h = multiplier_h, multiplier_m = multiplier_m)
}

wlv_indicator_complex_emp_petrovic_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.complex_labour_multiplier.emp.r.un.petrovic",
  checkpoint = 2L,
  requires = wlv_native_petrovic_requirements(FALSE),
  provides = wlv_native_reduction_output("complex_labour_multiplier.emp.r.un"),
  metadata = wlv_native_reduction_metadata(
    "complex_labour_multiplier.emp.r.un",
    paste0("Reduction Problem: Petrovic: uses the relationship between average ",
      "wage of each skill level and average wage of the least complex labour as weights.")
  ),
  run = function(ctx) {
    value <- wlv_native_petrovic_value(ctx)$value
    value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
    wlv_module_result(outputs = list(value = value))
  }
)
}

wlv_indicator_complex_empe_petrovic_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.complex_labour_multiplier.empe.r.un.petrovic",
  checkpoint = 2L,
  requires = wlv_native_petrovic_requirements(TRUE),
  provides = c(
    wlv_native_reduction_output("complex_labour_multiplier.empe.r.un"),
    wlv_native_reduction_skill_outputs()
  ),
  services = "contract_runtime",
  metadata = wlv_native_reduction_metadata(
    "complex_labour_multiplier.empe.r.un",
    paste0("Reduction Problem: Petrovic: uses the relationship between average ",
      "wage of each skill level and average wage of the least complex labour as weights.")
  ),
  run = function(ctx) {
    calculated <- wlv_native_petrovic_value(ctx)
    value <- wlv_native_with_named_axes(
      calculated$value,
      c("year", "sector", "country")
    )
    indicators <- c(
      "hours_worked.empe_hs.r.pc",
      "hours_worked.empe_ms.r.pc",
      "hours_worked.empe_ls.r.pc"
    )
    numerators <- list(
      calculated$multiplier_h * ctx$input("hours_hs"),
      calculated$multiplier_m * ctx$input("hours_ms"),
      ctx$input("hours_ls")
    )
    names(numerators) <- indicators
    numerators <- lapply(numerators, wlv_native_with_named_axes,
      axes = c("year", "sector", "country")
    )
    raw <- lapply(numerators, function(numerator) {
      wlv_native_with_named_axes(
        numerator / value,
        c("year", "sector", "country")
      )
    })
    resolved <- wlv_resolve_profiled_nonfinite(
      ctx$service("contract_runtime"),
      values = raw,
      numerators = numerators,
      denominator = value,
      artifact = "sea_sectors",
      checkpoint = "after_stage_2",
      stage = 2L,
      module = "indicator.complex_labour_multiplier.empe.r.un.petrovic",
      axes = c(year = 1L, sector = 2L, country = 3L)
    )
    wlv_module_result(outputs = list(
      value = value,
      hours_hs = resolved$values[[indicators[[1L]]]],
      hours_ms = resolved$values[[indicators[[2L]]]],
      hours_ls = resolved$values[[indicators[[3L]]]]
    ), diagnostics = resolved$diagnostics)
  }
)
}
