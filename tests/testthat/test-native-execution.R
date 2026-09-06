native_execution_bootstrap <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "scripts", "runtime_bootstrap.R"),
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
  compatibility <- lapply(plan$method_names, function(method) {
    record <- plan$methods[plan$methods$method == method, , drop = FALSE]
    runtime$wlv_native_runtime_compatibility(
      plan,
      record,
      runtime$wlv_load_run_missingness_policy(plan, record)
    )
  })
  expect_length(compatibility, 2L)
  hashes <- vapply(compatibility, `[[`, character(1L), "sha256")
  expect_true(all(grepl("^[0-9a-f]{64}$", hashes)))
  expect_identical(anyDuplicated(hashes), 0L)
  hash <- runtime$wlv_runtime_snapshot_value_sha256
  for (index in seq_along(plan$method_names)) {
    method_parameters <- runtime$wlv_native_method_parameters(
      plan$root,
      plan$method_names[[index]]
    )
    expect_identical(
      compatibility[[index]]$method_parameters_sha256,
      hash(method_parameters$parameters)
    )
    expect_identical(
      compatibility[[index]]$method_sectors_sha256,
      hash(method_parameters$sectors)
    )
  }
  repeated <- lapply(plan$method_names, function(method) {
    record <- plan$methods[plan$methods$method == method, , drop = FALSE]
    runtime$wlv_native_runtime_compatibility(
      plan,
      record,
      runtime$wlv_load_run_missingness_policy(plan, record)
    )
  })
  expect_identical(repeated, compatibility)

  expected_assumptions <- list(
    wiodr13 = "assumption/employment_row_current",
    wiodr16 = c(
      "assumption/employment_row_current",
      "assumption/china_hours_per_worker"
    ),
    alternative_1 = c(
      "assumption/employment_china",
      "assumption/employment_row_legacy"
    ),
    alternative_2 = c(
      "assumption/employment_china",
      "assumption/employment_row_legacy"
    ),
    norow_w13 = character(),
    ochoa_1 = c(
      "assumption/employment_china",
      "assumption/employment_row_legacy"
    ),
    ochoa_2 = c(
      "assumption/employment_china",
      "assumption/employment_row_legacy"
    ),
    petrovic = c(
      "assumption/employment_china",
      "assumption/employment_row_legacy"
    ),
    wiodr13v09 = "assumption/employment_row_legacy",
    wiodr16v09 = c(
      "assumption/employment_row_legacy",
      "assumption/china_hours_per_worker"
    ),
    zerodep_1 = "assumption/employment_row_current",
    zerodep_2 = c(
      "assumption/employment_row_current",
      "assumption/china_hours_per_worker"
    )
  )
  expected_assumptions <- expected_assumptions[c("wiodr13", "wiodr16")]
  expect_setequal(names(expected_assumptions), plan$method_names)

  for (method in plan$method_names) {
    record <- plan$methods[plan$methods$method == method, , drop = FALSE]
    partitions <- if (identical(record$source[[1L]], "wiodr13")) {
      "1995-2009"
    } else {
      "2000-2014"
    }
    full_inventories <- lapply(
      list(calculate = "calculate", stage1 = "recalculate"),
      function(mode) {
        instances <- runtime$wlv_native_plan_instances(
          registry = plan$native_registry,
          config = plan$configuration[[method]],
          aggregation_registry = plan$aggregation_registries[[method]],
          indicators = plan$indicators[[method]],
          partitions = partitions,
          mode = mode,
          at_stage = 1L
        )
        runtime$wlv_native_instance_required_keys(
          plan$native_registry,
          instances
        )
      }
    )
    for (inventory_name in names(full_inventories)) {
      inventory <- full_inventories[[inventory_name]]
      assumption_keys <- inventory[startsWith(inventory, "assumption/")]
      expect_true(
        identical(
          sort(assumption_keys),
          sort(expected_assumptions[[method]])
        ),
        info = sprintf("%s %s assumption inventory", method, inventory_name)
      )
      expect_true(all(c(
        "source/sea",
        "source/io",
        "dimensions/lists",
        "dimensions/rows",
        "dimensions/io_filters",
        "dimensions/import_group_indices"
      ) %in% inventory), info = sprintf(
        "%s %s full resource inventory",
        method,
        inventory_name
      ))
    }

    stage5_instances <- runtime$wlv_native_plan_instances(
      registry = plan$native_registry,
      config = plan$configuration[[method]],
      aggregation_registry = plan$aggregation_registries[[method]],
      indicators = plan$indicators[[method]],
      partitions = partitions,
      mode = "recalculate",
      at_stage = 5L
    )
    required_keys <- runtime$wlv_native_instance_required_keys(
      plan$native_registry,
      stage5_instances
    )
    dimension_assumption_keys <- required_keys[
      startsWith(required_keys, "dimensions/") |
        startsWith(required_keys, "assumption/")
    ]
    expect_setequal(
      dimension_assumption_keys,
      c("dimensions/lists", "dimensions/rows")
    )
    expect_true("source/sea" %in% required_keys, info = method)
    expect_false("source/io" %in% required_keys, info = method)

    stage4_instances <- runtime$wlv_native_plan_instances(
      registry = plan$native_registry,
      config = plan$configuration[[method]],
      aggregation_registry = plan$aggregation_registries[[method]],
      indicators = plan$indicators[[method]],
      partitions = partitions,
      mode = "recalculate",
      at_stage = 4L
    )
    stage4_keys <- runtime$wlv_native_instance_required_keys(
      plan$native_registry,
      stage4_instances
    )
    expect_true(all(c(
      "dimensions/io_filters",
      "dimensions/import_group_indices"
    ) %in% stage4_keys), info = method)
    expect_true("source/io" %in% stage4_keys, info = method)

    stage4_selective_instances <- runtime$wlv_native_plan_instances(
      registry = plan$native_registry,
      config = plan$configuration[[method]],
      aggregation_registry = plan$aggregation_registries[[method]],
      indicators = plan$indicators[[method]],
      partitions = partitions,
      mode = "recalculate",
      at_stage = 4L,
      sea_vars = "gross_output.s.mv"
    )
    stage4_selective_keys <- runtime$wlv_native_instance_required_keys(
      plan$native_registry,
      stage4_selective_instances
    )
    expect_true("io/values" %in% stage4_selective_keys, info = method)
    expect_false("source/io" %in% stage4_selective_keys, info = method)

    source_io_indicators <- intersect(
      c(
        "basket_price.r.pc", "basket_value.r.pc",
        "exports.s.us", "imports.s.us"
      ),
      plan$indicators[[method]]
    )
    for (indicator in source_io_indicators) {
      source_io_instances <- runtime$wlv_native_plan_instances(
        registry = plan$native_registry,
        config = plan$configuration[[method]],
        aggregation_registry = plan$aggregation_registries[[method]],
        indicators = plan$indicators[[method]],
        partitions = partitions,
        mode = "recalculate",
        at_stage = 4L,
        sea_vars = indicator
      )
      expect_true(
        runtime$wlv_native_instances_require_resource(
          plan$native_registry,
          source_io_instances,
          "source/io"
        ),
        info = sprintf("%s %s source IO dependency", method, indicator)
      )
    }

    classification_cases <- list(
      calculate = list(
        mode = "calculate", at_stage = 1L, sea_vars = NULL,
        reuse = FALSE, science = FALSE
      ),
      stage1 = list(
        mode = "recalculate", at_stage = 1L, sea_vars = NULL,
        reuse = TRUE, science = FALSE
      ),
      stage4_full = list(
        mode = "recalculate", at_stage = 4L, sea_vars = NULL,
        reuse = TRUE, science = FALSE
      ),
      stage4_selective = list(
        mode = "recalculate", at_stage = 4L,
        sea_vars = "gross_output.s.mv", reuse = TRUE, science = FALSE
      ),
      stage5_full = list(
        mode = "recalculate", at_stage = 5L, sea_vars = NULL,
        reuse = TRUE, science = TRUE
      ),
      stage5_selective = list(
        mode = "recalculate", at_stage = 5L,
        sea_vars = "value.m.mv", reuse = TRUE, science = TRUE
      )
    )
    for (case_name in names(classification_cases)) {
      current <- classification_cases[[case_name]]
      instance_args <- list(
        registry = plan$native_registry,
        config = plan$configuration[[method]],
        aggregation_registry = plan$aggregation_registries[[method]],
        indicators = plan$indicators[[method]],
        partitions = partitions,
        mode = current$mode,
        at_stage = current$at_stage
      )
      if (!is.null(current$sea_vars)) {
        instance_args$sea_vars <- current$sea_vars
      }
      classified_instances <- do.call(
        runtime$wlv_native_plan_instances,
        instance_args
      )
      classified_plan <- runtime$wlv_native_preflight_plan(
        plan$native_registry,
        classified_instances,
        partitions,
        mode = current$mode,
        source = record$source[[1L]],
        at_stage = current$at_stage,
        indicators = plan$indicators[[method]]
      )
      expect_identical(
        runtime$wlv_native_can_reuse_inherited_io_validation(classified_plan),
        current$reuse,
        info = sprintf("%s %s physical I/O inheritance", method, case_name)
      )
      expect_identical(
        runtime$wlv_native_can_inherit_io_scientific_checks(classified_plan),
        current$science,
        info = sprintf("%s %s scientific I/O inheritance", method, case_name)
      )
    }
  }

  method <- plan$method_names[[1L]]
  configuration <- plan$configuration[[method]]
  canonical <- runtime$wlv_native_configuration_descriptor(
    configuration,
    plan$native_registry
  )
  presentation_only <- configuration[rev(seq_len(nrow(configuration))), , drop = FALSE]
  args_index <- which(lengths(presentation_only$args) > 1L)[[1L]]
  presentation_only$args[[args_index]] <-
    presentation_only$args[[args_index]][rev(names(
      presentation_only$args[[args_index]]
    ))]
  presentation_only$args_json <- paste0("  ", presentation_only$args_json, "  ")
  presentation_only$layer <- "presentation-only"
  attr(presentation_only, "history") <- list("presentation-only")
  expect_identical(
    runtime$wlv_native_configuration_descriptor(
      presentation_only,
      plan$native_registry
    ),
    canonical
  )
  changed_configuration <- configuration
  changed_configuration$instance_id[[1L]] <- paste0(
    changed_configuration$instance_id[[1L]],
    ".changed"
  )
  expect_false(identical(
    runtime$wlv_native_configuration_descriptor(
      changed_configuration,
      plan$native_registry
    ),
    canonical
  ))

  aggregation <- plan$aggregation_registries[[method]]
  rebuilt_aggregation <- runtime$wlv_native_aggregation_registry(
    wlv_test_root,
    catalog,
    method
  )
  expect_identical(hash(rebuilt_aggregation), hash(aggregation))
  binding_index <- which(vapply(
    aggregation$bindings,
    function(binding) !is.null(binding$spec),
    logical(1L)
  ))[[1L]]
  changed_missing <- aggregation
  changed_missing$bindings[[binding_index]]$spec$missing <- "strict"
  changed_tolerance <- aggregation
  changed_tolerance$bindings[[binding_index]]$spec$tolerance <-
    changed_tolerance$bindings[[binding_index]]$spec$tolerance * 2
  expect_false(identical(hash(changed_missing), hash(aggregation)))
  expect_false(identical(hash(changed_tolerance), hash(aggregation)))
})

test_that("alternative 2 preserves the legacy scientific observation metadata", {
  expected <- paste0(
    "Reduction Problem: Alternative 2: considers a feasible, but arbitrary, ",
    "scale of multipliers of high and medium skilled labour regarding low skilled ",
    "labour (6.25x for high skilled and 2.5x for medium skilled labour)."
  )
  registry <- wlv_test_enable_deferred_methods(
    native_execution_runtime$wlv_runtime_catalog(), "alternative_2"
  )
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
  catalog <- wlv_test_enable_deferred_methods(
    runtime$wlv_runtime_catalog(), "alternative_1"
  )
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
  catalog <- wlv_test_enable_deferred_methods(
    runtime$wlv_runtime_catalog(),
    c("alternative_2", "petrovic", "ochoa_1", "ochoa_2", "alternative_1")
  )
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
  expect_false(runtime$wlv_native_can_inherit_io_scientific_checks(
    module_plan
  ))
  expect_false(runtime$wlv_native_can_reuse_inherited_io_validation(
    module_plan
  ))
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
  expect_true(runtime$wlv_native_can_inherit_io_scientific_checks(
    selective_plan
  ))
  expect_true(runtime$wlv_native_can_reuse_inherited_io_validation(
    selective_plan
  ))

  stage4_instances <- runtime$wlv_native_plan_instances(
    registry = plan$native_registry,
    config = plan$configuration$alternative_2,
    aggregation_registry = plan$aggregation_registries$alternative_2,
    indicators = plan$indicators$alternative_2,
    partitions = partitions,
    mode = "recalculate",
    at_stage = 4L,
    sea_vars = "gross_output.s.mv"
  )
  stage4_selective_plan <- runtime$wlv_native_preflight_plan(
    plan$native_registry,
    stage4_instances,
    partitions,
    mode = "recalculate",
    source = "wiodr13",
    at_stage = 4L,
    indicators = plan$indicators$alternative_2
  )
  expect_false(runtime$wlv_native_can_inherit_io_scientific_checks(
    stage4_selective_plan
  ))
  expect_true(runtime$wlv_native_can_reuse_inherited_io_validation(
    stage4_selective_plan
  ))

  stage4_full_instances <- runtime$wlv_native_plan_instances(
    registry = plan$native_registry,
    config = plan$configuration$alternative_2,
    aggregation_registry = plan$aggregation_registries$alternative_2,
    indicators = plan$indicators$alternative_2,
    partitions = partitions,
    mode = "recalculate",
    at_stage = 4L
  )
  stage4_full_plan <- runtime$wlv_native_preflight_plan(
    plan$native_registry,
    stage4_full_instances,
    partitions,
    mode = "recalculate",
    source = "wiodr13",
    at_stage = 4L,
    indicators = plan$indicators$alternative_2
  )
  expect_true(runtime$wlv_native_can_reuse_inherited_io_validation(
    stage4_full_plan
  ))
  for (provided_key in c(
    "intermediate/lambda",
    "semantic_state/io/values",
    "semantic_state/artifact/m_io",
    "semantic_state/intermediate/lambda"
  )) {
    io_provider_plan <- new.env(parent = emptyenv())
    io_provider_plan$modules <- list(list(
      provides = list(list(ref = list(key = provided_key)))
    ))
    class(io_provider_plan) <- "wlv_module_plan"
    lockEnvironment(io_provider_plan, bindings = TRUE)
    expect_false(
      runtime$wlv_native_can_reuse_inherited_io_validation(io_provider_plan),
      info = provided_key
    )
  }
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
    )[runtime$wlv_contract_anomaly_columns()]
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
    selective_plan,
    5L
  )
  expect_true(any(
    targets$artifact == "sea_countries" &
      targets$indicator == target_indicator
  ))
  expect_false(any(
    contract_runtime$anomalies$indicator == target_indicator &
      contract_runtime$anomalies$module == target_scope$module[[1L]]
  ))
  expect_setequal(
    contract_runtime$anomalies$indicator[
      contract_runtime$anomalies$module == target_scope$module[[1L]] &
        contract_runtime$anomalies$indicator %in% paste0(
          target_indicator,
          c(".numerator", ".denominator")
        )
    ],
    paste0(target_indicator, c(".numerator", ".denominator"))
  )
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
  catalog <- wlv_test_enable_deferred_methods(
    runtime$wlv_runtime_catalog(), "wiodr13v09"
  )
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
    )[runtime$wlv_contract_anomaly_columns()]
    runtime$wlv_native_reset_recalculated_anomalies(
      contract_runtime,
      module_plan,
      1L
    )
    expect_identical(nrow(contract_runtime$anomalies), 0L, info = method)
  }
})

test_that("stage-four anomaly reset preserves inherited go-price normalization", {
  runtime <- native_execution_runtime
  catalog <- wlv_test_enable_deferred_methods(
    runtime$wlv_runtime_catalog(), "ochoa_1"
  )
  request <- runtime$wlv_validate_request(
    "ochoa_1",
    mode = "recalculate",
    at_stage = 4L,
    root = wlv_test_root,
    allow_experimental = TRUE,
    catalog = catalog
  )
  instances <- runtime$wlv_native_plan_instances(
    registry = request$native_registry,
    config = request$configuration$ochoa_1,
    aggregation_registry = request$aggregation_registries$ochoa_1,
    indicators = request$indicators$ochoa_1,
    partitions = "1995-2009",
    mode = "recalculate",
    at_stage = 4L,
    sea_vars = "go_price.r.id"
  )
  module_plan <- runtime$wlv_native_preflight_plan(
    request$native_registry,
    instances,
    "1995-2009",
    mode = "recalculate",
    source = "wiodr13",
    at_stage = 4L,
    indicators = request$indicators$ochoa_1
  )
  targets <- runtime$wlv_native_recalculated_anomaly_targets(module_plan)
  normalization_targets <- targets[
    targets$artifact == "sea_sectors" &
      targets$module == "indicator.price_index.normalize",
    ,
    drop = FALSE
  ]
  expect_setequal(
    normalization_targets$indicator,
    c(
      "go_price.r.id",
      "go_price.r.id.numerator",
      "go_price.r.id.denominator"
    )
  )
  expect_true(all(normalization_targets$action == "preserve"))
  go_targets <- targets[
    targets$indicator == "go_price.r.id" &
      targets$artifact %in% c("sea_sectors", "sea_countries"),
    ,
    drop = FALSE
  ]
  inherited <- go_targets[
    go_targets$artifact == "sea_sectors" &
      go_targets$module == "indicator.price_index.normalize",
    ,
    drop = FALSE
  ]
  reset_candidates <- go_targets[
    !(go_targets$artifact == "sea_sectors" &
      go_targets$module == "indicator.price_index.normalize"),
    ,
    drop = FALSE
  ]
  expect_identical(nrow(inherited), 1L)
  expect_gt(nrow(reset_candidates), 0L)
  reset <- reset_candidates[1L, , drop = FALSE]

  contract_runtime <- runtime$wlv_new_contract_runtime(
    method = "ochoa_1",
    source = "wiodr13",
    policy = runtime$wlv_strict_missingness_policy(
      source = "wiodr13",
      policy_id = "stage4_inherited_anomaly_test"
    ),
    scientific_profile = request$scientific_profiles$ochoa_1
  )
  anomaly <- function(target) {
    data.frame(
      artifact = target$artifact,
      indicator = target$indicator,
      checkpoint = "after_price_normalization",
      stage = target$stage,
      module = target$module,
      year = "2000",
      country = "USA",
      sector = "S1",
      output = NA_character_,
      original_value = "NaN",
      policy_id = "wiodr13_v1",
      action = "mark_not_applicable",
      stringsAsFactors = FALSE
    )[runtime$wlv_contract_anomaly_columns()]
  }
  contract_runtime$anomalies <- rbind(anomaly(inherited), anomaly(reset))

  reset_targets <- runtime$wlv_native_reset_recalculated_anomalies(
    contract_runtime,
    module_plan,
    4L
  )
  expect_false(any(
    reset_targets$artifact == "sea_sectors" &
      reset_targets$indicator == "go_price.r.id" &
      reset_targets$module == "indicator.price_index.normalize"
  ))
  expect_identical(nrow(contract_runtime$anomalies), 1L)
  expect_identical(
    contract_runtime$anomalies$module,
    "indicator.price_index.normalize"
  )

  stage1_instances <- runtime$wlv_native_plan_instances(
    registry = request$native_registry,
    config = request$configuration$ochoa_1,
    aggregation_registry = request$aggregation_registries$ochoa_1,
    indicators = request$indicators$ochoa_1,
    partitions = "1995-2009",
    mode = "recalculate",
    at_stage = 1L
  )
  stage1_plan <- runtime$wlv_native_preflight_plan(
    request$native_registry,
    stage1_instances,
    "1995-2009",
    mode = "recalculate",
    source = "wiodr13",
    at_stage = 1L,
    indicators = request$indicators$ochoa_1
  )
  stage1_target <- runtime$wlv_native_recalculated_anomaly_targets(stage1_plan)
  stage1_target <- stage1_target[
    stage1_target$artifact == "sea_sectors" &
      stage1_target$indicator == "go_price.r.id" &
      stage1_target$module == "indicator.price_index.normalize",
    ,
    drop = FALSE
  ]
  expect_identical(nrow(stage1_target), 1L)
  stale <- do.call(rbind, lapply(
    c("go_price.r.id", "go_price.r.id.numerator", "go_price.r.id.denominator"),
    function(indicator) {
      value <- anomaly(stage1_target)
      value$indicator <- indicator
      value
    }
  ))
  row.names(stale) <- NULL
  contract_runtime$anomalies <- stale
  reset_stage1 <- runtime$wlv_native_reset_recalculated_anomalies(
    contract_runtime,
    stage1_plan,
    1L
  )
  normalized <- reset_stage1[
    reset_stage1$artifact == "sea_sectors" &
      reset_stage1$indicator == "go_price.r.id" &
      reset_stage1$module == "indicator.price_index.normalize",
    ,
    drop = FALSE
  ]
  expect_identical(normalized$action, "replace")
  expect_identical(nrow(contract_runtime$anomalies), 0L)
})

test_that("Leontief exception outputs close against lightweight IO metadata", {
  runtime <- native_execution_runtime
  catalog <- wlv_test_enable_deferred_methods(
    runtime$wlv_runtime_catalog(), "alternative_1"
  )
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

test_that("removed paper options fail before calculation starts", {
  runtime <- native_execution_runtime
  catalog <- runtime$wlv_runtime_catalog()
  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      papern = 0L,
      prepaper = TRUE,
      root = wlv_test_root,
      catalog = catalog
    ),
    "Paper tooling has been removed"
  )
  expect_error(
    runtime$wlv_validate_request(
      "wiodr13",
      papern = 1L,
      prepaper = FALSE,
      root = wlv_test_root,
      catalog = catalog
    ),
    "Paper tooling has been removed"
  )
})

test_that("recalculation refreshes only explicitly supplied metadata cells", {
  runtime <- native_execution_runtime
  indicators <- c("kept", "target")
  parent <- data.frame(
    code = indicators,
    name = c("parent kept", "parent target"),
    observation = c("parent kept source", "parent target source"),
    stringsAsFactors = FALSE,
    row.names = indicators
  )
  current <- data.frame(
    code = indicators,
    name = c("current kept", "current target"),
    observation = c("current kept source", NA_character_),
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
  expect_identical(merged["target", "observation"], "parent target source")
  expect_identical(row.names(merged), indicators)
})

test_that("recalculation rejects a parent with a contracted indicator schema", {
  runtime <- native_execution_runtime
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
  expect_error(
    runtime$wlv_native_validate_parent_indicator_schema(
      sector,
      indicators = "kept",
      artifact = "sea_sectors"
    ),
    "indicator schema differs",
    fixed = TRUE
  )
})

test_that("public FST sidecars omit axis names without mutating arrays", {
  skip_if_not_installed("fst")
  runtime <- native_execution_runtime
  value <- array(
    seq_len(4L),
    dim = c(2L, 2L),
    dimnames = list(year = c("2000", "2001"), country = c("A", "B"))
  )

  root <- tempfile("wlv-public-sidecar-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  path <- file.path(root, "public.fst")
  runtime$write_fst_array(value, path, drop_axis_names = TRUE)
  public <- runtime$read_fst_array(path)

  expect_identical(unname(dimnames(public)), unname(dimnames(value)))
  expect_null(names(dimnames(public)))
  expect_identical(names(dimnames(value)), c("year", "country"))
})

test_that("execution definition has no legacy executor or dynamic escape", {
  path <- file.path(wlv_test_root, "scripts", "lib", "execution.R")
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
