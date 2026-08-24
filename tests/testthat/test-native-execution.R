native_execution_bootstrap <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "bootstrap.R"),
  envir = native_execution_bootstrap
)
native_execution_runtime <- native_execution_bootstrap$wlv_load_runtime(
  wlv_test_root
)

test_that("all executable methods resolve only typed native execution inputs", {
  runtime <- native_execution_runtime
  catalog <- runtime$wlv_runtime_catalog()
  methods <- runtime$wlv_catalog_method_table(catalog)
  methods <- methods$method[methods$can_calculate | methods$can_recalculate]
  plan <- runtime$wlv_validate_request(
    methods,
    root = wlv_test_root,
    allow_experimental = TRUE,
    catalog = catalog
  )

  expect_s3_class(plan, "wlv_run_plan")
  expect_identical(plan$method_names, methods)
  expect_true(all(vapply(
    plan$configuration,
    inherits,
    logical(1L),
    "wlv_module_config"
  )))
  expect_true(all(vapply(plan$configuration, function(configuration) {
    all(configuration$module_id %in% names(plan$native_registry$specs))
  }, logical(1L))))
  expect_true(all(vapply(plan$aggregation_registries, function(registry) {
    !"legacy" %in% names(registry) &&
      all(vapply(registry$bindings, function(binding) {
        !"legacy" %in% names(binding)
      }, logical(1L)))
  }, logical(1L))))
  expect_true(all(vapply(plan$method_names, function(method) {
    identical(
      unname(plan$indicators[[method]]),
      unname(runtime$wlv_native_output_indicators(
        wlv_test_root,
        catalog,
        method,
        plan$aggregation_registries[[method]]
      ))
    )
  }, logical(1L))))
})

test_that("alternative 2 preserves the legacy scientific observation metadata", {
  expected <- paste0(
    "Reduction Problem: Alternative 2: considers a feasible, but arbitrary, ",
    "scale of multipliers of high and medium skilled labour regarding low skilled ",
    "labour (6.25x for high skilled and 2.5x for medium skilled labour)."
  )
  registry <- native_execution_runtime$wlv_runtime_catalog()
  plan <- native_execution_runtime$wlv_validate_request(
    "alternative_2",
    root = wlv_test_root,
    allow_experimental = TRUE,
    catalog = registry
  )
  module_ids <- c(
    "indicator.complex_labour_multiplier.emp.r.un.alternative_2",
    "indicator.complex_labour_multiplier.empe.r.un.alternative_2"
  )
  observations <- vapply(module_ids, function(module_id) {
    metadata <- attr(
      plan$native_registry$specs[[module_id]],
      "wlv_indicator_metadata"
    )
    metadata$observation[[1L]]
  }, character(1L))
  expect_identical(unname(observations), rep(expected, 2L))
})

test_that("run plans reject an in-memory scientific profile substitution", {
  runtime <- native_execution_runtime
  catalog <- runtime$wlv_runtime_catalog()
  plan <- runtime$wlv_validate_request(
    "alternative_1",
    root = wlv_test_root,
    allow_experimental = TRUE,
    catalog = catalog
  )
  original <- plan$scientific_profiles$alternative_1
  forged <- runtime$wlv_scientific_profile_contract(
    id = "forged_reduction_v1",
    method = original$method,
    source = original$source,
    output_profile = original$output_profile,
    leontief_zero = original$leontief_zero,
    leontief_signed = original$leontief_signed,
    nonfinite_resolution = original$nonfinite_resolution
  )
  expect_invisible(runtime$wlv_assert_scientific_profile(
    forged,
    "alternative_1",
    "wiodr13"
  ))
  plan$scientific_profiles$alternative_1 <- forged
  expect_error(
    runtime$wlv_assert_plan_scientific_profile_inventory(
      plan,
      "alternative_1"
    ),
    "no longer matches the authenticated contract inventory",
    fixed = TRUE
  )
})

test_that("profiled non-finite coordinates close against normalized source labels", {
  runtime <- native_execution_runtime
  catalog <- runtime$wlv_runtime_catalog()
  plan <- runtime$wlv_validate_request(
    c(
      "alternative_2", "petrovic", "ochoa_1", "ochoa_2",
      "alternative_1"
    ),
    root = wlv_test_root,
    allow_experimental = TRUE,
    catalog = catalog
  )
  profile <- plan$scientific_profiles$alternative_2
  rules <- profile$nonfinite_resolution$rules
  validation <- list(
    countries = unique(rules$country),
    sectors = unique(rules$sector)
  )
  expect_invisible(runtime$wlv_native_validate_nonfinite_source_coordinates(
    profile,
    validation,
    "alternative_2"
  ))

  partitions <- "1995-2009"
  instances <- runtime$wlv_native_plan_instances(
    registry = plan$native_registry,
    config = plan$configuration$alternative_2,
    aggregation_registry = plan$aggregation_registries$alternative_2,
    indicators = plan$indicators$alternative_2,
    partitions = partitions,
    mode = "calculate"
  )
  module_plan <- runtime$wlv_native_preflight_plan(
    plan$native_registry,
    instances,
    partitions,
    mode = "calculate",
    source = "wiodr13",
    indicators = plan$indicators$alternative_2
  )
  expect_invisible(runtime$wlv_native_validate_nonfinite_module_bindings(
    profile,
    module_plan,
    "alternative_2"
  ))
  wrong_producer <- profile
  wrong_producer$nonfinite_resolution$groups$module[] <-
    "indicator.complex_labour_multiplier.emp.r.un.alternative_2"
  expect_error(
    runtime$wlv_native_validate_nonfinite_module_bindings(
      wrong_producer,
      module_plan,
      "alternative_2"
    ),
    "is not produced by declared module",
    fixed = TRUE
  )
  contract_runtime <- runtime$wlv_new_contract_runtime(
    method = "alternative_2",
    source = "wiodr13",
    policy = runtime$wlv_strict_missingness_policy(
      source = "wiodr13",
      policy_id = "test_strict"
    ),
    scientific_profile = profile
  )
  selective_instances <- runtime$wlv_native_plan_instances(
    registry = plan$native_registry,
    config = plan$configuration$alternative_2,
    aggregation_registry = plan$aggregation_registries$alternative_2,
    indicators = plan$indicators$alternative_2,
    partitions = partitions,
    mode = "recalculate",
    at_stage = 5L,
    sea_vars = "surplus_value.empe.r.pc"
  )
  selective_plan <- runtime$wlv_native_preflight_plan(
    plan$native_registry,
    selective_instances,
    partitions,
    mode = "recalculate",
    source = "wiodr13",
    at_stage = 5L,
    indicators = plan$indicators$alternative_2
  )
  selective_targets <- runtime$wlv_native_recalculated_anomaly_targets(
    selective_plan
  )
  target_scope <- selective_targets[
    selective_targets$artifact == "sea_countries" &
      selective_targets$indicator == "surplus_value.empe.r.pc",
    ,
    drop = FALSE
  ]
  expect_identical(nrow(target_scope), 1L)

  anomaly <- function(
      indicator,
      artifact = target_scope$artifact[[1L]],
      stage = target_scope$stage[[1L]],
      module = target_scope$module[[1L]],
      year = "2000") {
    data.frame(
      artifact = artifact,
      indicator = indicator,
      checkpoint = "after_stage_2",
      stage = stage,
      module = module,
      year = year,
      country = "AAA",
      sector = "S1",
      output = NA_character_,
      original_value = "NaN",
      policy_id = "test_policy",
      action = "test_action",
      stringsAsFactors = FALSE
    )[runtime$wlv_contract_anomaly_columns]
  }
  target_indicator <- target_scope$indicator[[1L]]
  nonfinite_group <- profile$nonfinite_resolution$groups[1L, , drop = FALSE]
  kept_duplicate <- anomaly(
    "kept.indicator",
    artifact = "sea_sectors",
    stage = "1",
    module = "source.raw"
  )
  contract_runtime$anomalies <- rbind(
    anomaly(target_indicator),
    anomaly(paste0(target_indicator, ".numerator")),
    anomaly(paste0(target_indicator, ".denominator")),
    anomaly(
      target_indicator,
      stage = "1",
      module = "source.raw"
    ),
    anomaly(
      nonfinite_group$indicator[[1L]],
      artifact = "sea_sectors",
      stage = "2",
      module = nonfinite_group$module[[1L]]
    ),
    anomaly(
      "labour_requirements",
      artifact = "m_io",
      stage = "3",
      module = "matrix.transformation"
    ),
    kept_duplicate,
    kept_duplicate
  )
  targets <- runtime$wlv_native_reset_recalculated_anomalies(
    contract_runtime,
    selective_plan
  )
  expect_true(any(
    targets$artifact == "sea_countries" &
      targets$indicator == target_indicator
  ))
  expect_false(any(contract_runtime$anomalies$indicator %in% c(
    target_indicator,
    paste0(target_indicator, c(".numerator", ".denominator"))
  ) & contract_runtime$anomalies$module == target_scope$module[[1L]]))
  expect_identical(
    sum(contract_runtime$anomalies$indicator == "kept.indicator"),
    2L
  )
  expect_true(any(
    contract_runtime$anomalies$indicator == target_indicator &
      contract_runtime$anomalies$module == "source.raw"
  ))
  expect_true(any(
    contract_runtime$anomalies$indicator == nonfinite_group$indicator[[1L]] &
      contract_runtime$anomalies$stage == "2"
  ))
  expect_true(any(
    contract_runtime$anomalies$artifact == "m_io" &
      contract_runtime$anomalies$stage == "3"
  ))
  runtime$wlv_contract_record(contract_runtime, anomaly(target_indicator))
  runtime$wlv_contract_record(contract_runtime, anomaly(target_indicator))
  expect_identical(
    sum(contract_runtime$anomalies$indicator == target_indicator &
      contract_runtime$anomalies$module == target_scope$module[[1L]]),
    2L
  )
  for (current_method in c(
    "alternative_2", "petrovic", "ochoa_1", "ochoa_2"
  )) {
    current_plan <- runtime$wlv_native_scientific_binding_preflight(
      registry = plan$native_registry,
      configuration = plan$configuration[[current_method]],
      aggregation_registry = plan$aggregation_registries[[current_method]],
      indicators = plan$indicators[[current_method]],
      partitions = partitions,
      source = "wiodr13"
    )
    current_profile <- plan$scientific_profiles[[current_method]]
    expect_invisible(
      runtime$wlv_native_validate_nonfinite_module_bindings(
        current_profile,
        current_plan,
        current_method
      )
    )
    for (checkpoint in c(1L, 4L, 5L)) {
      recalculation_instances <- runtime$wlv_native_plan_instances(
        registry = plan$native_registry,
        config = plan$configuration[[current_method]],
        aggregation_registry = plan$aggregation_registries[[current_method]],
        indicators = plan$indicators[[current_method]],
        partitions = partitions,
        mode = "recalculate",
        at_stage = checkpoint
      )
      recalculation_plan <- runtime$wlv_native_preflight_plan(
        plan$native_registry,
        recalculation_instances,
        partitions,
        mode = "recalculate",
        source = "wiodr13",
        at_stage = checkpoint,
        indicators = plan$indicators[[current_method]]
      )
      expect_error(
        runtime$wlv_native_validate_nonfinite_module_bindings(
          current_profile,
          recalculation_plan,
          current_method
        ),
        "is not produced by declared module",
        fixed = TRUE,
        info = paste(current_method, checkpoint)
      )
    }
    swapped <- current_profile
    swapped$nonfinite_resolution$groups$module <- vapply(
      swapped$nonfinite_resolution$groups$module,
      function(module) {
        if (grepl("[.]empe[.]", module)) {
          sub("[.]empe[.]", ".emp.", module)
        } else {
          sub("[.]emp[.]", ".empe.", module)
        }
      },
      character(1L)
    )
    expect_error(
      runtime$wlv_native_validate_nonfinite_module_bindings(
        swapped,
        current_plan,
        current_method
      ),
      "is not produced by declared module",
      fixed = TRUE,
      info = current_method
    )
  }

  missing_country <- validation
  missing_country$countries <- setdiff(missing_country$countries, "AUS")
  expect_error(
    runtime$wlv_native_validate_nonfinite_source_coordinates(
      profile,
      missing_country,
      "alternative_2"
    ),
    "countries=AUS",
    fixed = TRUE
  )
  missing_sector <- validation
  missing_sector$sectors <- setdiff(missing_sector$sectors, "50")
  expect_error(
    runtime$wlv_native_validate_nonfinite_source_coordinates(
      profile,
      missing_sector,
      "alternative_2"
    ),
    "sectors=50",
    fixed = TRUE
  )
  expect_invisible(runtime$wlv_native_validate_nonfinite_source_coordinates(
    plan$scientific_profiles$alternative_1,
    list(),
    "alternative_1"
  ))
})

test_that("stage-one anomaly owners match their native module generations", {
  runtime <- native_execution_runtime
  catalog <- runtime$wlv_runtime_catalog()
  cases <- data.frame(
    method = c("wiodr13v09", "wiodr16"),
    source = c("wiodr13", "wiodr16"),
    indicator = c("exchange.r.us", "hours_worked.emp.s.hr"),
    module = c(
      "indicator.exchange.r.us.v09",
      "indicator.hours_worked.emp.s.hr.wiodr16"
    ),
    partition = c("1995-2009", "2000-2014"),
    stringsAsFactors = FALSE
  )
  request <- runtime$wlv_validate_request(
    cases$method,
    mode = "recalculate",
    at_stage = 1L,
    root = wlv_test_root,
    allow_experimental = TRUE,
    catalog = catalog
  )

  for (index in seq_len(nrow(cases))) {
    current <- cases[index, , drop = FALSE]
    method <- current$method[[1L]]
    instances <- runtime$wlv_native_plan_instances(
      registry = request$native_registry,
      config = request$configuration[[method]],
      aggregation_registry = request$aggregation_registries[[method]],
      indicators = request$indicators[[method]],
      partitions = current$partition[[1L]],
      mode = "recalculate",
      at_stage = 1L
    )
    module_plan <- runtime$wlv_native_preflight_plan(
      request$native_registry,
      instances,
      current$partition[[1L]],
      mode = "recalculate",
      source = current$source[[1L]],
      at_stage = 1L,
      indicators = request$indicators[[method]]
    )
    targets <- runtime$wlv_native_recalculated_anomaly_targets(module_plan)
    owner <- targets[
      targets$artifact == "sea_sectors" &
        targets$indicator == current$indicator[[1L]] &
        targets$stage == "1" &
        targets$module == current$module[[1L]],
      ,
      drop = FALSE
    ]
    expect_identical(nrow(owner), 1L, info = method)

    contract_runtime <- runtime$wlv_new_contract_runtime(
      method = method,
      source = current$source[[1L]],
      policy = runtime$wlv_strict_missingness_policy(
        source = current$source[[1L]],
        policy_id = paste0(method, "_test")
      ),
      scientific_profile = request$scientific_profiles[[method]]
    )
    contract_runtime$anomalies <- data.frame(
      artifact = "sea_sectors",
      indicator = current$indicator[[1L]],
      checkpoint = "after_stage_1",
      stage = "1",
      module = current$module[[1L]],
      year = "2000",
      country = "AAA",
      sector = "S1",
      output = NA_character_,
      original_value = "0",
      policy_id = "test_policy",
      action = "test_action",
      stringsAsFactors = FALSE
    )[runtime$wlv_contract_anomaly_columns]
    runtime$wlv_native_reset_recalculated_anomalies(
      contract_runtime,
      module_plan
    )
    expect_identical(nrow(contract_runtime$anomalies), 0L, info = method)
  }
})

test_that("Leontief exception outputs close against lightweight IO metadata", {
  runtime <- native_execution_runtime
  catalog <- runtime$wlv_runtime_catalog()
  plan <- runtime$wlv_validate_request(
    "alternative_1",
    root = wlv_test_root,
    allow_experimental = TRUE,
    catalog = catalog
  )
  profile <- plan$scientific_profiles$alternative_1
  counts <- profile$leontief_zero$counts
  io_path <- tempfile("wlv-leontief-metadata-", fileext = ".fst")
  metadata_path <- paste0(io_path, ".meta")
  on.exit(unlink(metadata_path), add = TRUE)
  outputs <- unique(c(counts$output, "AAA.S1"))
  saveRDS(
    list(
      c(length(unique(counts$year)), 1L, length(outputs)),
      unique(counts$year),
      "AAA.S1",
      outputs
    ),
    metadata_path
  )
  expect_invisible(
    runtime$wlv_native_validate_leontief_zero_source_coordinates(
      profile,
      io_path,
      "alternative_1"
    )
  )

  typo <- profile
  typo$leontief_zero$counts$output[[1L]] <- "CYP.XX"
  expect_error(
    runtime$wlv_native_validate_leontief_zero_source_coordinates(
      typo,
      io_path,
      "alternative_1"
    ),
    "references unknown source coordinates"
  )
})

test_that("selective recalculation is checked against native checkpoint ranks", {
  runtime <- native_execution_runtime
  catalog <- runtime$wlv_runtime_catalog()
  plan <- runtime$wlv_validate_request(
    "wiodr13",
    mode = "recalculate",
    at_stage = 4L,
    root = wlv_test_root,
    catalog = catalog
  )
  method <- "wiodr13"
  partitions <- "1995-2009"
  stages <- runtime$wlv_native_indicator_stage_map(
    plan$native_registry,
    plan$configuration[[method]],
    plan$aggregation_registries[[method]],
    plan$indicators[[method]],
    partitions
  )

  expect_error(
    runtime$wlv_native_validate_selected_stages(
      stages,
      "emp.s.un",
      4L,
      method
    ),
    "cannot be recalculated from checkpoint stage 4"
  )
  expect_no_error(runtime$wlv_native_validate_selected_stages(
    stages,
    "value.m.mv",
    4L,
    method
  ))
})

test_that("unsupported papers fail before calculation starts", {
  runtime <- native_execution_runtime
  catalog <- runtime$wlv_runtime_catalog()
  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      papern = 3L,
      prepaper = TRUE,
      root = wlv_test_root,
      catalog = catalog
    ),
    "Paper `3` is unsupported"
  )
  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      papern = 4L,
      prepaper = FALSE,
      root = wlv_test_root,
      catalog = catalog
    ),
    "Paper `4` is unsupported"
  )
})

test_that("selective recalculation refreshes only recomputed indicator metadata", {
  runtime <- native_execution_runtime
  indicators <- c("kept", "target")
  parent <- data.frame(
    code = indicators,
    name = c("parent kept", "parent target"),
    stringsAsFactors = FALSE,
    row.names = indicators
  )
  current <- data.frame(
    code = indicators,
    name = c("current kept", "current target"),
    stringsAsFactors = FALSE,
    row.names = indicators
  )
  contract <- runtime$wlv_resource_contract(
    scope = "run",
    value_type = "double"
  )
  resolved <- list(list(provides = list(runtime$wlv_resource_output(
    runtime$wlv_resource_ref("sea/sector/target", contract),
    action = "create"
  ))))

  merged <- runtime$wlv_native_merge_recalculation_metadata(
    parent,
    current,
    resolved,
    indicators
  )

  expect_identical(merged["kept", "name"], "parent kept")
  expect_identical(merged["target", "name"], "current target")
  expect_identical(row.names(merged), indicators)
})

test_that("recalculation rejects a parent with a contracted indicator schema", {
  skip_if_not_installed("fst")
  runtime <- native_execution_runtime
  parent <- tempfile("wlv-parent-schema-")
  dir.create(parent)
  on.exit(unlink(parent, recursive = TRUE, force = TRUE), add = TRUE)

  sector <- array(
    seq_len(2L),
    dim = c(1L, 2L, 1L, 1L),
    dimnames = list(
      year = "2000",
      indicator = c("kept", "removed"),
      sector = "S1",
      country = "A"
    )
  )
  country <- array(
    seq_len(2L),
    dim = c(1L, 2L, 1L),
    dimnames = list(
      year = "2000",
      indicator = c("kept", "removed"),
      country = "A"
    )
  )
  runtime$write_fst_array(sector, file.path(parent, "sea_sectors.fst"))
  runtime$write_fst_array(country, file.path(parent, "sea_countries.fst"))

  expect_error(
    runtime$wlv_native_parent_indicator_seeds(
      parent,
      indicators = "kept",
      resolved = list()
    ),
    "indicator schema differs",
    fixed = TRUE
  )
})

test_that("public arrays preserve labels while omitting internal axis names", {
  runtime <- native_execution_runtime
  value <- array(
    seq_len(4L),
    dim = c(2L, 2L),
    dimnames = list(year = c("2000", "2001"), country = c("A", "B"))
  )

  public <- runtime$wlv_native_public_array(value)

  expect_identical(unname(dimnames(public)), unname(dimnames(value)))
  expect_null(names(dimnames(public)))
  expect_identical(names(dimnames(value)), c("year", "country"))
})

test_that("execution definition has no legacy executor or dynamic escape", {
  path <- file.path(wlv_test_root, "R", "lib", "execution.R")
  violations <- native_execution_runtime$wlv_runtime_static_scan_file(
    path,
    root = wlv_test_root
  )
  text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  expect_identical(nrow(violations), 0L)
  expect_false(grepl("computations[.]R|re_computations[.]R", text))
  expect_false(grepl("_method_(assumptions|matrices|solutions)[.]csv", text))
  expect_false(grepl("_source_(assumptions|matrices|solutions)[.]csv", text))
  expect_false(grepl("_common_(assumptions|matrices|solutions)[.]csv", text))
})
