wlv_native_public_e2e_write_csv <- function(path, value) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.table(
    value,
    path,
    sep = ";",
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE,
    na = "",
    fileEncoding = "UTF-8"
  )
  invisible(path)
}

wlv_native_public_e2e_write_definition <- function(path, definition) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(definition, path, useBytes = TRUE)
  invisible(path)
}

wlv_native_public_e2e_unit_rows <- function() {
  data.frame(
    indicator = c(
      "gross_output.s.us",
      "gross_output.s.mv",
      "value.m.mv"
    ),
    quantity_kind = c("monetary", "labour_value", "ratio"),
    source_unit = c(
      "usd",
      "abstract_labour_hour",
      "abstract_labour_hour_per_usd"
    ),
    source_scale = rep("1", 3L),
    canonical_unit = c(
      "usd",
      "abstract_labour_hour",
      "abstract_labour_hour_per_usd"
    ),
    display_unit = c(
      "usd",
      "abstract_labour_hour",
      "abstract_labour_hour_per_usd"
    ),
    display_multiplier = rep("1", 3L),
    currency = c("usd", "none", "mixed"),
    price_basis = c("current", "not_applicable", "current"),
    base_year = rep("", 3L),
    index_base = rep("", 3L),
    labour_concept = c("not_applicable", "employment", "employment"),
    notes = c(
      "Synthetic current-USD gross output.",
      "Synthetic embodied labour.",
      "Synthetic embodied labour per current USD."
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

wlv_native_public_e2e_aggregation_rows <- function(catalog_schema = TRUE) {
  indicators <- rep(
    c("gross_output.s.us", "gross_output.s.mv", "value.m.mv"),
    each = 2L
  )
  value <- data.frame(
    indicator = indicators,
    level = rep(c("sector_to_country", "country_to_world"), 3L),
    strategy = c(rep("sum", 4L), rep("ratio_of_sums", 2L)),
    module_id = rep("", 6L),
    numerator = c(rep("", 4L), rep("gross_output.s.mv", 2L)),
    denominator = c(rep("", 4L), rep("gross_output.s.us", 2L)),
    weight = rep("", 6L),
    zero_denominator = c(rep("", 4L), rep("not_applicable", 2L)),
    notes = c(
      rep("", 4L),
      rep("Embodied labour per current USD of gross output.", 2L)
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (!isTRUE(catalog_schema)) {
    names(value)[names(value) == "module_id"] <- "module"
  }
  value
}

wlv_native_public_e2e_module_rows <- function(instance_id, module_id) {
  data.frame(
    instance_id = instance_id,
    module_id = module_id,
    action = rep("add", length(instance_id)),
    replaces = rep("", length(instance_id)),
    variant = rep("", length(instance_id)),
    source_variable = rep("", length(instance_id)),
    args_json = rep("{}", length(instance_id)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

wlv_native_public_e2e_empty_module_rows <- function() {
  wlv_native_public_e2e_module_rows(character(), character())
}

wlv_native_public_e2e_write_project_contract <- function(root) {
  method <- "native_test"
  source <- "synthetic"
  documentation <- "docs/synthetic.md"

  wlv_native_public_e2e_write_csv(
    file.path(root, "catalog", "sources.csv"),
    data.frame(
      source = source,
      status = "experimental",
      year_start = "2000",
      year_end = "2001",
      parameter_set = source,
      data_dir = "source_data/synthetic",
      can_prepare = "FALSE",
      preparation_task = "",
      validator_id = "synthetic_prepared_v1",
      artifact_profile = "synthetic_core",
      missingness_policy = "synthetic_v1",
      unit_contract = "synthetic_units_v1",
      documentation = documentation,
      limitations = "Synthetic test-only source.",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "catalog", "methods.csv"),
    data.frame(
      method = method,
      source = source,
      code = "SYNTH",
      description = "Synthetic native public API",
      status = "experimental",
      can_calculate = "TRUE",
      can_recalculate = "TRUE",
      validation_id = "",
      documentation = documentation,
      limitations = "Synthetic test-only method.",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )

  artifacts <- c(
    "normalized/m_io*.fst",
    "normalized/sea.fst",
    "normalized/countries.csv",
    "normalized/sectors.csv",
    "normalized/demand.csv",
    "normalized/_source_manifest.csv"
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "catalog", "artifact-profiles.csv"),
    data.frame(
      profile = rep("synthetic_core", length(artifacts)),
      artifact = artifacts,
      kind = c("fst_array_glob", "fst_array", rep("csv", 4L)),
      sidecar = c("TRUE", "TRUE", rep("FALSE", 4L)),
      operations = rep("calculate|recalculate", length(artifacts)),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "catalog", "missingness-policies.csv"),
    data.frame(
      policy = "synthetic_v1",
      documentation = documentation,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "catalog", "unit-contracts.csv"),
    data.frame(
      contract = "synthetic_units_v1",
      schema_version = "2",
      source = source,
      units = "contracts/units/synthetic_v1-units.csv",
      aggregations = "contracts/units/synthetic_v1-aggregations.csv",
      documentation = documentation,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "contracts", "units", "synthetic_v1-units.csv"),
    wlv_native_public_e2e_unit_rows()
  )
  wlv_native_public_e2e_write_csv(
    file.path(
      root,
      "contracts",
      "units",
      "synthetic_v1-aggregations.csv"
    ),
    wlv_native_public_e2e_aggregation_rows()
  )

  dir.create(file.path(root, "parameters", source), recursive = TRUE)
  wlv_native_public_e2e_write_csv(
    file.path(root, "methods", method, "_parameters.csv"),
    data.frame(
      source = source,
      code = "SYNTH",
      name = "Synthetic native public API",
      description = "Synthetic end-to-end calculation.",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "methods", method, "_sectors.csv"),
    data.frame(
      sector.source = c("S1", "S2"),
      sector = c("Synthetic sector 1", "Synthetic sector 2"),
      productive = c("1", "1"),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )

  wlv_native_public_e2e_write_definition(
    file.path(root, documentation),
    "# Synthetic native public API fixture"
  )

  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "modules", "common.csv"),
    wlv_native_public_e2e_empty_module_rows()
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "modules", "sources", "synthetic.csv"),
    wlv_native_public_e2e_module_rows(
      c("indicator.gross_output.s.us", "matrix.synthetic"),
      c("test.gross_us", "matrix.transformation")
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "modules", "methods", "native_test.csv"),
    wlv_native_public_e2e_module_rows(
      c("indicator.gross_output.s.mv", "indicator.value.m.mv"),
      c("test.gross_mv", "test.value")
    )
  )

  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "aggregations", "method_profiles.csv"),
    data.frame(
      method = method,
      source = source,
      profile = "synthetic_profile",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "aggregations", "synthetic_profile.csv"),
    wlv_native_public_e2e_aggregation_rows(catalog_schema = FALSE)
  )

  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "outputs", "method_profiles.csv"),
    data.frame(
      method = method,
      profile = "synthetic_output",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "outputs", "profiles.csv"),
    data.frame(
      profile = "synthetic_output",
      source = source,
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "outputs", "overrides.csv"),
    data.frame(
      profile = character(),
      position = character(),
      indicator = character(),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "outputs", "sources", "synthetic.csv"),
    data.frame(
      indicator = c(
        "gross_output.s.us",
        "gross_output.s.mv",
        "value.m.mv"
      ),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "contracts", "scientific_method_profiles.csv"),
    data.frame(
      method = method,
      output_profile = "synthetic_output",
      scientific_profile = "synthetic_v1",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "contracts", "scientific_profiles.csv"),
    data.frame(
      scientific_profile = "synthetic_v1",
      source = source,
      leontief_zero_profile = "synthetic_zero_v1",
      leontief_signed_profile = "synthetic_signed_v1",
      nonfinite_resolution_profile = "nonfinite_none_v1",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "contracts", "leontief_zero_profiles.csv"),
    data.frame(
      leontief_zero_profile = "synthetic_zero_v1",
      exception_count = "0",
      coordinate_md5 = "d41d8cd98f00b204e9800998ecf8427e",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "contracts", "leontief_zero_counts.csv"),
    data.frame(
      leontief_zero_profile = character(),
      year = character(),
      output = character(),
      exception_count = character(),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "contracts", "leontief_signed_profiles.csv"),
    data.frame(
      leontief_signed_profile = rep("synthetic_signed_v1", 2L),
      year = c("2000", "2001"),
      coefficient_negative_count = rep("0", 2L),
      certificate_type = rep("productivity_nonnegative", 2L),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(
      root,
      "config",
      "contracts",
      "nonfinite_resolution_profiles.csv"
    ),
    data.frame(
      nonfinite_resolution_profile = "nonfinite_none_v1",
      action = "reject",
      expected_count = "0",
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(
      root,
      "config",
      "contracts",
      "nonfinite_resolution_groups.csv"
    ),
    data.frame(
      nonfinite_resolution_profile = character(),
      binding = character(),
      indicator = character(),
      kind = character(),
      module = character(),
      expected_count = character(),
      coordinate_sha256 = character(),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  wlv_native_public_e2e_write_csv(
    file.path(root, "config", "contracts", "nonfinite_resolution_rules.csv"),
    data.frame(
      nonfinite_resolution_profile = character(),
      artifact = character(),
      indicator = character(),
      year = character(),
      country = character(),
      sector = character(),
      from = character(),
      to = character(),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
  )
  invisible(root)
}

wlv_native_public_e2e_write_source <- function(runtime, root) {
  normalized <- file.path(root, "source_data", "synthetic", "normalized")
  dir.create(normalized, recursive = TRUE, showWarnings = FALSE)
  years <- c("2000", "2001")
  sectors <- c("S1", "S2")
  countries <- c("AAA", "BBB")
  demands <- "HH"
  inputs <- as.vector(vapply(
    countries,
    function(country) paste(country, sectors, sep = "."),
    character(length(sectors))
  ))
  outputs <- c(inputs, paste(countries, demands, sep = "."))

  gross <- array(
    c(10, 12, 20, 24, 30, 36, 40, 48),
    dim = c(length(years), length(sectors), length(countries)),
    dimnames = list(year = years, sector = sectors, country = countries)
  )
  sea <- array(
    0,
    dim = c(length(years), 1L, length(sectors), length(countries)),
    dimnames = list(
      year = years,
      variable = "GO_USD",
      sector = sectors,
      country = countries
    )
  )
  sea[, "GO_USD", , ] <- gross
  source_io <- array(
    0,
    dim = c(length(years), length(inputs), length(outputs)),
    dimnames = list(year = years, input = inputs, output = outputs)
  )

  io_path <- file.path(normalized, "m_io2000-2001.fst")
  sea_path <- file.path(normalized, "sea.fst")
  runtime$write_fst_array(source_io, io_path)
  runtime$write_fst_array(sea, sea_path)
  wlv_native_public_e2e_write_csv(
    file.path(normalized, "countries.csv"),
    data.frame(country.source = countries, stringsAsFactors = FALSE)
  )
  wlv_native_public_e2e_write_csv(
    file.path(normalized, "sectors.csv"),
    data.frame(sector.source = sectors, stringsAsFactors = FALSE)
  )
  wlv_native_public_e2e_write_csv(
    file.path(normalized, "demand.csv"),
    data.frame(demand = demands, stringsAsFactors = FALSE)
  )

  artifacts <- c(
    basename(io_path),
    paste0(basename(io_path), ".meta"),
    basename(sea_path),
    paste0(basename(sea_path), ".meta"),
    "countries.csv",
    "sectors.csv",
    "demand.csv"
  )
  manifest <- runtime$wlv_build_source_manifest(
    source_root = normalized,
    artifacts = artifacts,
    artifact_roles = c(
      "input_output",
      "input_output_metadata",
      "socioeconomic",
      "socioeconomic_metadata",
      "country_labels",
      "sector_labels",
      "demand_labels"
    ),
    contract_path = file.path(
      root,
      "contracts",
      "units",
      c("synthetic_v1-units.csv", "synthetic_v1-aggregations.csv")
    ),
    contract_id = "synthetic_units_v1",
    contract_version = "2"
  )
  runtime$wlv_write_source_manifest(
    manifest,
    file.path(normalized, "_source_manifest.csv")
  )

  euklems <- file.path(root, "source_data", "euklems")
  dir.create(euklems, recursive = TRUE, showWarnings = FALSE)
  fst::write_fst(
    data.frame(variable = "synthetic", value = 1),
    file.path(euklems, "ekk_2000.fst")
  )
  fst::write_fst(
    data.frame(variable = "synthetic", value = 0),
    file.path(euklems, "ekdeprate_2000.fst")
  )

  assumptions <- file.path(root, "complementar", "worldbank")
  wlv_native_public_e2e_write_csv(
    file.path(assumptions, "employment_row.new.csv"),
    data.frame(country = "ROW", value = 1, stringsAsFactors = FALSE)
  )
  wlv_native_public_e2e_write_csv(
    file.path(assumptions, "employment_row.csv"),
    data.frame(country = "ROW", value = 1, stringsAsFactors = FALSE)
  )
  wlv_native_public_e2e_write_csv(
    file.path(assumptions, "employment_china.csv"),
    data.frame(country = "CHN", value = 1, stringsAsFactors = FALSE)
  )

  list(
    years = years,
    sectors = sectors,
    countries = countries,
    demands = demands,
    inputs = inputs,
    outputs = outputs,
    gross = gross
  )
}

wlv_native_public_e2e_indicator_metadata <- function(
    runtime,
    code,
    name,
    description,
    type) {
  runtime$wlv_native_indicator_metadata_row(
    code = code,
    name = name,
    description = description,
    observation = "Synthetic public API fixture.",
    group = "Synthetic",
    type = type
  )
}

wlv_native_public_e2e_gross_us_spec <- function(runtime) {
  runtime$wlv_native_indicator_spec(
    id = "test.gross_us",
    checkpoint = 1L,
    requires = runtime$wlv_native_source_requirements(),
    provides = runtime$wlv_native_indicator_output("gross_output.s.us"),
    metadata = wlv_native_public_e2e_indicator_metadata(
      runtime,
      "gross_output.s.us",
      "Gross output (USD)",
      "Synthetic gross output in current USD.",
      "usd"
    ),
    run = function(ctx) {
      value <- runtime$wlv_native_source_variable(
        ctx$input("source"),
        "GO_USD",
        ctx$input("lists")
      )
      runtime$wlv_module_result(outputs = list(value = value))
    }
  )
}

wlv_native_public_e2e_gross_mv_spec <- function(runtime) {
  runtime$wlv_native_indicator_spec(
    id = "test.gross_mv",
    checkpoint = 4L,
    requires = runtime$wlv_native_indicator_ref(
      "gross_output.s.us",
      alias = "gross_us",
      producer = "indicator.gross_output.s.us"
    ),
    provides = runtime$wlv_native_indicator_output("gross_output.s.mv"),
    metadata = wlv_native_public_e2e_indicator_metadata(
      runtime,
      "gross_output.s.mv",
      "Gross output (magnitude of value)",
      "Synthetic embodied labour in gross output.",
      "value"
    ),
    run = function(ctx) {
      value <- 2 * ctx$input("gross_us")
      value <- runtime$wlv_native_with_named_axes(
        value,
        c("year", "sector", "country")
      )
      runtime$wlv_module_result(outputs = list(value = value))
    }
  )
}

wlv_native_public_e2e_value_spec <- function(runtime) {
  runtime$wlv_native_indicator_spec(
    id = "test.value",
    checkpoint = 5L,
    requires = c(
      runtime$wlv_native_indicator_ref(
        "gross_output.s.us",
        alias = "gross_us",
        producer = "indicator.gross_output.s.us"
      ),
      runtime$wlv_native_indicator_ref(
        "gross_output.s.mv",
        alias = "gross_mv",
        producer = "indicator.gross_output.s.mv"
      )
    ),
    provides = runtime$wlv_native_indicator_output("value.m.mv"),
    metadata = wlv_native_public_e2e_indicator_metadata(
      runtime,
      "value.m.mv",
      "Average value per unit of output",
      "Synthetic embodied labour per unit of current-USD output.",
      "value"
    ),
    run = function(ctx) {
      gross_us <- ctx$input("gross_us")
      gross_mv <- ctx$input("gross_mv")
      value <- runtime$wlv_native_with_named_axes(
        gross_mv / gross_us,
        c("year", "sector", "country")
      )
      runtime$wlv_module_result(outputs = list(value = value))
    }
  )
}

wlv_native_public_e2e_matrix_spec <- function(runtime) {
  io_resources <- c(
    "k_composition",
    "k_depreciation",
    "values",
    "transfers_values",
    "consumption_basket"
  )
  country_resources <- c(
    "exports_values",
    "exports_mp",
    "exports_productive_mp",
    "transfers_values",
    "transfers_productive_values",
    "transfers_dp",
    "transfers_productive_dp"
  )
  provides <- c(
    unlist(lapply(io_resources, function(resource) {
      runtime$wlv_native_io_output(
        resource,
        alias = paste0("io.", resource)
      )
    }), recursive = FALSE),
    unlist(lapply(country_resources, function(resource) {
      runtime$wlv_native_country_matrix_output(
        resource,
        alias = paste0("country.", resource)
      )
    }), recursive = FALSE)
  )
  provides <- c(
    provides,
    runtime$wlv_native_intermediate_output(
      "lambda",
      alias = "lambda",
      axes = c("year", "input"),
      scope = "io_period"
    )
  )
  runtime$wlv_native_module_spec(
    id = "matrix.transformation",
    scope = "io_period",
    checkpoint = 4L,
    operations = "calculate",
    requires = c(
      runtime$wlv_native_source_io_ref(),
      runtime$wlv_native_indicator_ref(
        "gross_output.s.mv",
        alias = "gross_mv",
        producer = "indicator.gross_output.s.mv"
      ),
      runtime$wlv_native_indicator_ref(
        "gross_output.s.us",
        alias = "gross_us",
        producer = "indicator.gross_output.s.us"
      ),
      runtime$wlv_native_run_ref("dimensions/lists", "lists", "list")
    ),
    provides = provides,
    run = function(ctx) {
      source_io <- ctx$input("source_io")
      gross_mv <- ctx$input("gross_mv")
      gross_us <- ctx$input("gross_us")
      lists <- ctx$input("lists")
      years <- dimnames(source_io)[[1L]]
      zero_io <- array(
        0,
        dim = dim(source_io),
        dimnames = dimnames(source_io)
      )
      zero_io <- runtime$wlv_native_with_named_axes(
        zero_io,
        c("year", "input", "output")
      )
      values <- zero_io
      for (year in years) {
        values[year, lists$input, tail(lists$output, 1L)] <-
          as.numeric(gross_mv[year, , ])
      }
      country_zero <- array(
        0,
        dim = c(length(years), length(lists$countries), length(lists$countries)),
        dimnames = list(
          year = years,
          origin = lists$countries,
          destination = lists$countries
        )
      )
      outputs <- stats::setNames(
        lapply(io_resources, function(resource) {
          if (identical(resource, "values")) values else zero_io
        }),
        paste0("io.", io_resources)
      )
      outputs <- c(
        outputs,
        stats::setNames(
          rep(list(country_zero), length(country_resources)),
          paste0("country.", country_resources)
        ),
        list(lambda = array(
          1,
          dim = c(length(years), length(lists$input)),
          dimnames = list(year = years, input = lists$input)
        ))
      )
      diagnostics <- lapply(years, function(year) {
        labour <- as.numeric(gross_mv[year, , ] / gross_us[year, , ])
        names(labour) <- lists$input
        gross_output <- as.numeric(gross_mv[year, , ])
        names(gross_output) <- lists$input
        coefficients <- matrix(
          0,
          nrow = length(lists$input),
          ncol = length(lists$input),
          dimnames = list(lists$input, lists$input)
        )
        runtime$wlv_solve_leontief(
          coefficient_matrix = coefficients,
          labour_requirements = labour,
          gross_output = gross_output,
          method = "native_test",
          year = year
        )$diagnostics
      })
      runtime$wlv_module_result(
        outputs = outputs,
        diagnostics = list(
          `_leontief_diagnostics.csv` = do.call(rbind, diagnostics)
        )
      )
    }
  )
}

wlv_native_public_e2e_install_runtime_seams <- function(runtime, root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  assign(".wlv_runtime_root", function() root, envir = runtime)

  registry_factory <- function() {
    runtime$wlv_module_registry(list(
      wlv_native_public_e2e_gross_us_spec(runtime),
      wlv_native_public_e2e_gross_mv_spec(runtime),
      wlv_native_public_e2e_value_spec(runtime),
      wlv_native_public_e2e_matrix_spec(runtime),
      runtime$wlv_native_aggregation_spec(),
      runtime$wlv_native_matrix_assembler_spec(),
      runtime$wlv_native_panel_assembler_spec()
    ))
  }
  assign("wlv_native_registry", registry_factory, envir = runtime)

  original_preflight <- runtime$wlv_native_preflight_seed_contracts
  assign(
    "wlv_native_preflight_seed_contracts",
    function(source, mode, at_stage, indicators) {
      original_preflight(
        source = if (identical(source, "synthetic")) "wiodr13" else source,
        mode = mode,
        at_stage = at_stage,
        indicators = indicators
      )
    },
    envir = runtime
  )

  original_validator <- runtime$wlv_load_catalog_validator
  assign(
    "wlv_load_catalog_validator",
    function(plan, method) {
      if (!identical(method$source[[1L]], "synthetic")) {
        return(original_validator(plan, method))
      }
      list(
        validator_id = "synthetic_prepared_v1",
        source = "synthetic",
        validate = function(normalized_root) {
          sectors <- runtime$wlv_native_read_semicolon(
            file.path(normalized_root, "sectors.csv")
          )
          list(sectors = as.character(sectors$sector.source))
        },
        validate_euklems = function(...) invisible(TRUE)
      )
    },
    envir = runtime
  )

  original_missingness <- runtime$wlv_load_run_missingness_policy
  assign(
    "wlv_load_run_missingness_policy",
    function(plan, method) {
      if (identical(method$source[[1L]], "synthetic")) {
        return(runtime$wlv_strict_missingness_policy(
          source = "synthetic",
          policy_id = "synthetic_v1"
        ))
      }
      original_missingness(plan, method)
    },
    envir = runtime
  )

  executions <- new.env(parent = emptyenv())
  executions$history <- list()
  original_execute <- runtime$wlv_execute_run_plan
  assign(
    "wlv_execute_run_plan",
    function(plan) {
      value <- original_execute(plan)
      executions$history[[length(executions$history) + 1L]] <- value
      value
    },
    envir = runtime
  )
  executions
}

wlv_make_native_public_e2e_fixture <- function() {
  runtime <- wlv_test_clone_runtime()
  root <- tempfile("wlv-native-public-e2e-")
  dir.create(root, recursive = TRUE)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  wlv_native_public_e2e_write_project_contract(root)
  source <- wlv_native_public_e2e_write_source(runtime, root)
  executions <- wlv_native_public_e2e_install_runtime_seams(runtime, root)
  list(
    root = root,
    runtime = runtime,
    executions = executions,
    method = "native_test",
    source = source,
    channel = "synthetic"
  )
}

wlv_native_public_e2e_current_run <- function(fixture) {
  fixture$runtime$wlv_resolve_current_method_run(
    fixture$root,
    fixture$method,
    channel = fixture$channel
  )
}

wlv_native_public_e2e_raw_doubles <- function(value) {
  writeBin(as.double(value), raw(), size = 8L, endian = "little")
}

wlv_native_public_e2e_bitwise_identical <- function(left, right) {
  identical(dim(left), dim(right)) &&
    identical(dimnames(left), dimnames(right)) &&
    identical(
      wlv_native_public_e2e_raw_doubles(left),
      wlv_native_public_e2e_raw_doubles(right)
    )
}

wlv_native_public_e2e_diagnostic_hashes <- function(fixture) {
  runtime <- fixture$runtime
  run <- wlv_native_public_e2e_current_run(fixture)
  names <- c(
    runtime$wlv_native_published_diagnostic_ids(),
    "_scientific_checks.csv"
  )
  paths <- file.path(run$path, names)
  present <- file.exists(paths)
  hashes <- vapply(
    paths[present],
    runtime$wlv_publication_file_sha256,
    character(1L)
  )
  stats::setNames(unname(hashes), names[present])
}

wlv_native_public_e2e_snapshot <- function(fixture) {
  runtime <- fixture$runtime
  run <- wlv_native_public_e2e_current_run(fixture)
  io_paths <- sort(list.files(
    run$path,
    pattern = "^m_io.*[.]fst$",
    full.names = TRUE
  ))
  immutable_paths <- c(
    file.path(run$path, "m_countries.fst"),
    paste0(file.path(run$path, "m_countries.fst"), ".meta"),
    io_paths,
    paste0(io_paths, ".meta")
  )
  hashes <- vapply(
    immutable_paths,
    runtime$wlv_publication_file_sha256,
    character(1L)
  )
  names(hashes) <- basename(immutable_paths)
  list(
    run = run,
    sea_sectors = runtime$read_fst_array(
      file.path(run$path, "sea_sectors.fst")
    ),
    sea_countries = runtime$read_fst_array(
      file.path(run$path, "sea_countries.fst")
    ),
    states = runtime$wlv_read_contract_states(
      file.path(run$path, "_states.csv")
    ),
    anomalies = runtime$wlv_read_contract_report(
      file.path(run$path, "_anomalies.csv")
    ),
    immutable_hashes = hashes
  )
}

wlv_native_public_e2e_indicator_rows <- function(value, indicators) {
  if (!is.data.frame(value) || !"indicator" %in% names(value)) {
    return(value)
  }
  result <- value[value$indicator %in% indicators, , drop = FALSE]
  row.names(result) <- NULL
  result
}

wlv_native_public_e2e_expect_unselected_identical <- function(
    before,
    after,
    indicators) {
  testthat::expect_true(wlv_native_public_e2e_bitwise_identical(
    before$sea_sectors[, indicators, , , drop = FALSE],
    after$sea_sectors[, indicators, , , drop = FALSE]
  ))
  testthat::expect_true(wlv_native_public_e2e_bitwise_identical(
    before$sea_countries[, indicators, , drop = FALSE],
    after$sea_countries[, indicators, , drop = FALSE]
  ))
  testthat::expect_identical(
    wlv_native_public_e2e_indicator_rows(before$states, indicators),
    wlv_native_public_e2e_indicator_rows(after$states, indicators)
  )
  testthat::expect_identical(
    wlv_native_public_e2e_indicator_rows(before$anomalies, indicators),
    wlv_native_public_e2e_indicator_rows(after$anomalies, indicators)
  )
  testthat::expect_identical(
    before$immutable_hashes,
    after$immutable_hashes
  )
  invisible(TRUE)
}
