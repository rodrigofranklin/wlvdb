native_indicator_environment <- new.env(parent = baseenv())
for (path in c(
  "R/lib/module_runtime.R",
  "R/lib/semantic_resources.R",
  "R/modules/native/contracts.R",
  "R/modules/native/source_modules.R",
  "R/modules/native/matrix_modules.R",
  "R/modules/native/indicator_helpers.R",
  "R/modules/native/indicator_common_modules.R",
  "R/modules/native/indicator_source_derived_modules.R",
  "R/modules/native/indicator_stage4_collector.R",
  "R/modules/native/indicator_reduction_modules.R",
  "R/modules/native/zz_indicator_registry.R"
)) {
  sys.source(file.path(wlv_test_root, path), envir = native_indicator_environment)
}

wlv_test_native_indicator_specs <- function() {
  specs <- native_indicator_environment$wlv_native_indicator_specs()
  ids <- vapply(specs, function(spec) spec$id, character(1L))
  specs[!duplicated(ids)]
}

test_that("every configured native indicator module has a co-located spec", {
  paths <- list.files(
    file.path(wlv_test_root, "config", "modules"),
    pattern = "[.]csv$",
    recursive = TRUE,
    full.names = TRUE
  )
  configured <- unique(unlist(lapply(paths, function(path) {
    value <- utils::read.csv2(
      path,
      stringsAsFactors = FALSE,
      colClasses = "character",
      check.names = FALSE,
      na.strings = NULL,
      fileEncoding = "UTF-8"
    )
    value$module_id[grepl("^indicator[.]", value$module_id)]
  }), use.names = FALSE))
  specs <- wlv_test_native_indicator_specs()
  observed <- vapply(specs, function(spec) spec$id, character(1L))
  expect_setequal(intersect(observed, configured), configured)

  selected_specs <- specs[observed %in% configured]
  expect_true(all(vapply(
    selected_specs,
    function(spec) {
      metadata <- attr(spec, "wlv_indicator_metadata", exact = TRUE)
      is.data.frame(metadata) && nrow(metadata) == 1L
    },
    logical(1L)
  )))

  explicit <- native_indicator_environment$wlv_native_indicator_specs()
  explicit_ids <- vapply(explicit, function(spec) spec$id, character(1L))
  expect_identical(anyDuplicated(explicit_ids), 0L)
  expect_setequal(explicit_ids, c(configured, "source_indicator", c(
    "indicator.basket_zero.collector",
    "indicator.price_index.normalize",
    "indicator.stage4_collector"
  )))
})

test_that("source indicators project the selected variable's sparse states", {
  runtime <- native_indicator_environment
  source <- array(
    seq_len(12L),
    dim = c(1L, 3L, 2L, 2L),
    dimnames = list(
      year = "2000",
      variable = c("EMP", "COMP", "FINITE"),
      sector = c("S1", "S2"),
      country = c("AAA", "BBB")
    )
  )
  source["2000", "EMP", "S1", "AAA"] <- NA_real_
  source["2000", "COMP", "S2", "BBB"] <- NA_real_
  source_states <- array(
    "finite",
    dim = dim(source),
    dimnames = dimnames(source)
  )
  source_states["2000", "EMP", "S1", "AAA"] <- "source_missing"
  source_states["2000", "COMP", "S2", "BBB"] <- "not_applicable"
  source_contract <- runtime$wlv_native_source_sea_contract()
  state <- runtime$wlv_semantic_state_encode(
    source,
    source_states,
    "source/sea",
    source_contract$axes
  )
  control_seeds <- list(
    runtime$wlv_seed_resource(
      "request/method", "test", runtime$wlv_native_control_contract("character")
    ),
    runtime$wlv_seed_resource(
      "request/source", "wiodr13",
      runtime$wlv_native_control_contract("character")
    ),
    runtime$wlv_seed_resource(
      "configuration/missingness_policy",
      list(id = "test"),
      runtime$wlv_native_control_contract("list")
    ),
    runtime$wlv_seed_resource(
      "configuration/scientific_profile",
      list(id = "test"),
      runtime$wlv_native_control_contract("list")
    )
  )
  store <- runtime$wlv_new_resource_store(c(
    list(
      runtime$wlv_seed_resource("source/sea", source, source_contract),
      runtime$wlv_seed_resource(
        "semantic_state/source/sea",
        state,
        runtime$wlv_native_semantic_state_contract(source_contract)
      )
    ),
    control_seeds
  ))
  instance <- runtime$wlv_module_instance(
    "source_indicator.EMP.test",
    "source_indicator",
    args = list(indicator = "EMP.test", source_variable = "EMP")
  )
  finite_instance <- runtime$wlv_module_instance(
    "source_indicator.FINITE.test",
    "source_indicator",
    args = list(indicator = "FINITE.test", source_variable = "FINITE")
  )
  plan <- runtime$wlv_compile_module_plan(
    runtime$wlv_module_registry(list(runtime$wlv_source_indicator_spec())),
    list(instance, finite_instance),
    store
  )
  result <- runtime$wlv_run_module_plan(plan, store)
  value_contract <- runtime$wlv_native_indicator_contract("EMP.test")
  value <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "sea/sector/EMP.test",
      value_contract,
      producer = instance$instance_id
    )
  )
  projected <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "semantic_state/sea/sector/EMP.test",
      runtime$wlv_native_semantic_state_contract(value_contract),
      producer = instance$instance_id
    )
  )
  finite_contract <- runtime$wlv_native_indicator_contract("FINITE.test")
  finite_state <- runtime$wlv_store_read(
    result$store,
    runtime$wlv_resource_ref(
      "semantic_state/sea/sector/FINITE.test",
      runtime$wlv_native_semantic_state_contract(finite_contract),
      producer = finite_instance$instance_id
    )
  )

  expected <- array(
    source[, "EMP", , , drop = FALSE],
    dim = dim(source)[c(1L, 3L, 4L)],
    dimnames = dimnames(source)[c(1L, 3L, 4L)]
  )
  expect_identical(value, expected)
  expect_identical(names(projected), c("year", "sector", "country", "state"))
  expect_identical(nrow(projected), 1L)
  expect_identical(projected$year, "2000")
  expect_identical(projected$sector, "S1")
  expect_identical(projected$country, "AAA")
  expect_identical(projected$state, "source_missing")
  expect_identical(
    attr(projected, "target_key", exact = TRUE),
    "sea/sector/EMP.test"
  )
  expect_identical(
    attr(projected, "axes", exact = TRUE),
    c("year", "sector", "country")
  )
  expect_silent(runtime$wlv_semantic_state_validate(
    projected,
    value = value,
    target_key = "sea/sector/EMP.test",
    axes = value_contract$axes,
    state_key = "semantic_state/sea/sector/EMP.test"
  ))
  expect_s3_class(finite_state, "wlv_semantic_state")
  expect_identical(nrow(finite_state), 0L)
  expect_identical(
    attr(finite_state, "target_key", exact = TRUE),
    "sea/sector/FINITE.test"
  )
})

test_that("auxiliary indicator instances follow deterministic conventions", {
  config_environment <- new.env(parent = baseenv())
  sys.source(
    file.path(wlv_test_root, "R", "lib", "module_config.R"),
    envir = config_environment
  )
  config <- config_environment$wlv_resolve_module_config(
    wlv_test_root, "wiodr13", "wiodr13"
  )
  instances <- native_indicator_environment$wlv_native_indicator_auxiliary_instances(
    config, c("2000", "2001")
  )
  ids <- vapply(instances, function(instance) instance$instance_id, character(1L))
  stage4 <- native_indicator_environment$wlv_native_indicator_stage4_modules()
  configured_stage4 <- config$instance_id[config$module_id %in% names(stage4)]
  expect_true(all(paste0("collector.", configured_stage4) %in% ids))
  expect_true("indicator.basket_zero.collector" %in% ids)
  expect_true("normalize.indicator.basket_price.r.pc" %in% ids)
  expect_true("normalize.indicator.basket_value.r.pc" %in% ids)
  expect_true("normalize.indicator.go_price.r.id" %in% ids)
  expect_identical(attr(instances, "partitions"), c("2000", "2001"))
  basket_collector <- instances[[match("indicator.basket_zero.collector", ids)]]
  expect_identical(basket_collector$args$base_year, "first")
  basket_value_normalizer <- instances[[match(
    "normalize.indicator.basket_value.r.pc", ids
  )]]
  expect_identical(
    basket_value_normalizer$args,
    list(
      indicator = "basket_value.r.pc",
      predecessor = "collector.indicator.basket_value.r.pc",
      base_year = "2000",
      copy_usa_to_row = FALSE
    )
  )
  overrides <- attr(instances, "primary_argument_overrides")
  expect_identical(
    overrides[["indicator.basket_price.r.pc"]]$go_price_producer,
    "assumption.row"
  )
  go_normalizer <- instances[[match("normalize.indicator.go_price.r.id", ids)]]
  expect_identical(go_normalizer$args$predecessor, "assumption.row")
  registry <- native_indicator_environment$wlv_module_registry(
    list(native_indicator_environment$wlv_indicator_price_index_normalize_spec())
  )
  resolved <- native_indicator_environment$wlv_runtime_resolve_instance(
    registry, go_normalizer, "calculate", c("2000", "2001")
  )
  expect_identical(resolved$requires$current$producer, "assumption.row")
  expect_identical(
    resolved$provides$value$predecessor$producer,
    "assumption.row"
  )
  resolved_basket_value <-
    native_indicator_environment$wlv_runtime_resolve_instance(
      registry, basket_value_normalizer, "calculate", c("2000", "2001")
    )
  expect_identical(
    resolved_basket_value$requires$current$producer,
    "collector.indicator.basket_value.r.pc"
  )
  expect_identical(
    resolved_basket_value$provides$value$predecessor$producer,
    "collector.indicator.basket_value.r.pc"
  )

  raw_instances <- native_indicator_environment$wlv_native_indicator_auxiliary_instances(
    config,
    c("2000", "2001"),
    go_price_predecessor = "indicator.go_price.r.id"
  )
  raw_ids <- vapply(raw_instances, function(instance) instance$instance_id, character(1L))
  raw_normalizer <- raw_instances[[match(
    "normalize.indicator.go_price.r.id", raw_ids
  )]]
  expect_identical(raw_normalizer$args$predecessor, "indicator.go_price.r.id")
  raw_overrides <- attr(raw_instances, "primary_argument_overrides")
  expect_identical(
    raw_overrides[["indicator.basket_value.r.pc"]]$go_price_producer,
    "indicator.go_price.r.id"
  )

  basket_registry <- native_indicator_environment$wlv_module_registry(list(
    native_indicator_environment$wlv_indicator_basket_price_r_pc_spec()
  ))
  basket <- native_indicator_environment$wlv_runtime_resolve_instance(
    basket_registry,
    native_indicator_environment$wlv_module_instance(
      "indicator.basket_price.r.pc",
      "indicator.basket_price.r.pc",
      args = list(go_price_producer = "indicator.go_price.r.id"),
      partition = "2000"
    ),
    "calculate",
    c("2000", "2001")
  )
  expect_identical(basket$requires$go_price$producer, "indicator.go_price.r.id")

  reduction <- native_indicator_environment[[
    "wlv_indicator_complex_empe_alternative_2_spec"
  ]]()
  reduction_instance <- native_indicator_environment$wlv_module_instance(
    reduction$id,
    reduction$id
  )
  reduction_requires <- reduction$requires(list(), reduction_instance)
  reduction_provides <- reduction$provides(list(), reduction_instance)
  expect_true(all(vapply(
    reduction_requires[c("hours_hs", "hours_ms", "hours_ls")],
    function(ref) identical(ref$producer, "assumption.row"),
    logical(1L)
  )))
  expect_true(all(vapply(
    reduction_provides[c("hours_hs", "hours_ms", "hours_ls")],
    function(output) identical(output$predecessor$producer, "assumption.row"),
    logical(1L)
  )))

  explicit <- native_indicator_environment$wlv_native_indicator_specs()
  explicit_ids <- vapply(explicit, function(spec) spec$id, character(1L))
  ochoa <- explicit[explicit_ids %in% c(
    "indicator.complex_labour_multiplier.emp.r.un.ochoa_1",
    "indicator.complex_labour_multiplier.empe.r.un.ochoa_1",
    "indicator.complex_labour_multiplier.emp.r.un.ochoa_2",
    "indicator.complex_labour_multiplier.empe.r.un.ochoa_2"
  )]
  expect_true(all(vapply(
    ochoa,
    function(spec) setequal(
      spec$services,
      c("contract_runtime", "module_contract")
    ),
    logical(1L)
  )))
  petrovic <- explicit[[match(
    "indicator.complex_labour_multiplier.empe.r.un.petrovic",
    explicit_ids
  )]]
  expect_setequal(
    petrovic$services,
    c("contract_runtime", "module_contract")
  )
  reduction_source <- readLines(
    file.path(
      wlv_test_root,
      "R",
      "modules",
      "native",
      "indicator_reduction_modules.R"
    ),
    warn = FALSE,
    encoding = "UTF-8"
  )
  expect_false(any(grepl(
    "is[.](nan|infinite)\\(",
    reduction_source,
    perl = TRUE
  )))
})

test_that("indicator scopes and checkpoints expose the explicit cutover", {
  specs <- wlv_test_native_indicator_specs()
  by_id <- stats::setNames(specs, vapply(specs, function(spec) spec$id, character(1L)))
  stage4 <- c(
    "indicator.basket_price.r.pc", "indicator.basket_value.r.pc",
    "indicator.capital_depreciation.s.us", "indicator.exports.s.mv",
    "indicator.exports.s.us", "indicator.gross_output.s.mv",
    "indicator.imports.s.mv", "indicator.imports.s.us",
    "indicator.labour_force_value.emp.s.mv",
    "indicator.labour_force_value.s.mv", "indicator.trade_transfers.p.s.mv",
    "indicator.trade_transfers.s.mv", "indicator.value.m.mv"
  )
  expect_true(all(vapply(by_id[stage4], function(spec) {
    identical(spec$scope, "io_period") && identical(spec$checkpoint, 4L)
  }, logical(1L))))

  stage5 <- c(
    "indicator.abstract_labour.emp.m.mv",
    "indicator.abstract_labour.empe.m.mv",
    "indicator.appropriated_profit.r.pc", "indicator.compensation.emp.s.cu",
    "indicator.compensation.empe.s.cu", "indicator.gdp.s.du",
    "indicator.gross_output.s.du", "indicator.labour_force_value.emp.m.mv",
    "indicator.labour_force_value.m.mv", "indicator.surplus_value.emp.r.pc",
    "indicator.surplus_value.emp_p.r.pc", "indicator.surplus_value.empe.r.pc",
    "indicator.surplus_value.empe_hs.r.pc",
    "indicator.surplus_value.empe_ls.r.pc",
    "indicator.surplus_value.empe_ms.r.pc",
    "indicator.surplus_value.empe_p.r.pc", "indicator.trade_balance.s.mv",
    "indicator.trade_balance.s.us", "indicator.trade_transfers.p.m.pc",
    "indicator.trade_transfers.u.s.mv"
  )
  direct <- c(
    "indicator.compensation.emp.s.cu",
    "indicator.compensation.empe.s.cu", "indicator.gdp.s.du",
    "indicator.gross_output.s.du", "indicator.trade_balance.s.mv",
    "indicator.trade_balance.s.us", "indicator.trade_transfers.u.s.mv"
  )
  expect_true(all(vapply(by_id[stage5], function(spec) {
    expected <- if (spec$id %in% direct) "sector" else c("sector", "country")
    provides <- spec$provides(list())
    value_outputs <- provides[vapply(provides, function(output) {
      identical(output$ref$contract$role, "value")
    }, logical(1L))]
    identical(spec$scope, "run") && identical(spec$checkpoint, 5L) &&
      identical(names(value_outputs), expected)
  }, logical(1L))))
})

test_that("stage-4 imports consume exact precomputed group indices", {
  runtime <- native_indicator_environment
  output_countries <- c(1, 1, 2, 2, 1, 2)
  input_sectors <- c(1, 2, 1, 2)
  import_matrix <- matrix(
    rep(output_countries, each = 4L),
    nrow = 4L,
    ncol = 6L
  ) + matrix(rep(input_sectors, times = 6L), nrow = 4L) / 1000
  import_groups <- base::as.factor(import_matrix)
  import_group_indices <- structure(
    base::split(
      base::seq_along(import_groups),
      import_groups,
      drop = FALSE
    ),
    class = c("wlv_import_group_indices", "list")
  )
  values <- c(
    NA_real_, 2, NaN, 4, 5, Inf, 7, 8, 9, -Inf, 11, 12,
    13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24
  )

  expect_identical(
    runtime$wlv_native_sum_import_groups(values, import_group_indices),
    base::tapply(values, import_matrix, base::sum, na.rm = TRUE)
  )
  integer_values <- base::seq_along(values)
  expect_identical(
    runtime$wlv_native_sum_import_groups(
      integer_values,
      import_group_indices
    ),
    base::tapply(integer_values, import_matrix, base::sum, na.rm = TRUE)
  )
  shaped <- array(rep(values, times = 2L), dim = c(2L, 4L, 6L))
  expect_identical(
    base::apply(
      shaped,
      1L,
      runtime$wlv_native_sum_import_groups,
      import_group_indices
    ),
    base::apply(
      shaped,
      1L,
      base::tapply,
      import_matrix,
      base::sum,
      na.rm = TRUE
    )
  )
  nums <- list(
    input = 4L,
    output = 6L,
    countries = 2L,
    sectors = 2L,
    countries_sectors = 4L,
    demands = 1L
  )
  expect_silent(runtime$wlv_native_import_group_indices_assert(
    import_group_indices,
    nums
  ))
  expect_error(
    runtime$wlv_native_import_group_indices_assert(
      unclass(import_group_indices),
      nums
    ),
    "canonical import-group indices"
  )
  duplicated <- import_group_indices
  duplicated[[1L]][[1L]] <- duplicated[[1L]][[2L]]
  expect_error(
    runtime$wlv_native_import_group_indices_assert(duplicated, nums),
    "canonical import-group indices"
  )
  out_of_range <- import_group_indices
  out_of_range[[1L]][[1L]] <- nums$input * nums$output + 1L
  expect_error(
    runtime$wlv_native_import_group_indices_assert(out_of_range, nums),
    "canonical import-group indices"
  )
  permuted <- import_group_indices[c(2L, 1L, 3L, 4L)]
  expect_error(
    runtime$wlv_native_import_group_indices_assert(permuted, nums),
    "canonical import-group indices"
  )
  crossed <- import_group_indices
  temporary <- crossed[[1L]][[2L]]
  crossed[[1L]][[2L]] <- crossed[[2L]][[2L]]
  crossed[[2L]][[2L]] <- temporary
  expect_false(is.unsorted(crossed[[1L]], strictly = TRUE))
  expect_false(is.unsorted(crossed[[2L]], strictly = TRUE))
  expect_error(
    runtime$wlv_native_import_group_indices_assert(crossed, nums),
    "canonical import-group indices"
  )

  specs <- list(
    runtime$wlv_indicator_imports_s_mv_spec(),
    runtime$wlv_indicator_imports_s_us_spec(),
    runtime$wlv_indicator_trade_transfers_s_mv_spec(),
    runtime$wlv_indicator_trade_transfers_p_s_mv_spec()
  )
  for (spec in specs) {
    ref <- spec$requires(list())[["import_group_indices"]]
    expect_identical(ref$key, "dimensions/import_group_indices")
    expect_identical(ref$contract$value_type, "list")
    expect_identical(ref$contract$role, "control")
  }
})

test_that("stage-4 collector preserves values and enforces exact year coverage", {
  e <- native_indicator_environment
  lists <- list(
    years = c("2000", "2001"), sectors = c("s1", "s2"), countries = "AAA"
  )
  make_value <- function(year, offset) {
    array(
      offset + seq_len(2L),
      dim = c(1L, 2L, 1L),
      dimnames = list(year = year, sector = lists$sectors, country = lists$countries)
    )
  }
  contract <- e$wlv_native_indicator_contract(
    "demo", scope = "io_period", level = "sector"
  )
  semantic_seed <- function(value, partition) {
    state <- e$wlv_semantic_capture_value_state(
      value,
      "sea/sector/demo",
      contract$axes
    )$state
    e$wlv_seed_resource(
      "semantic_state/sea/sector/demo",
      state,
      e$wlv_native_semantic_state_contract(contract),
      partition
    )
  }
  control_seeds <- list(
    e$wlv_seed_resource(
      "request/method", "test", e$wlv_native_control_contract("character")
    ),
    e$wlv_seed_resource(
      "request/source", "wiodr13", e$wlv_native_control_contract("character")
    ),
    e$wlv_seed_resource(
      "configuration/missingness_policy",
      list(id = "test"),
      e$wlv_native_control_contract("list")
    ),
    e$wlv_seed_resource(
      "configuration/scientific_profile",
      list(id = "test"),
      e$wlv_native_control_contract("list")
    )
  )
  first <- make_value("2000", 0)
  second <- make_value("2001", 10)
  store <- e$wlv_new_resource_store(list(
    e$wlv_seed_resource("sea/sector/demo", first, contract, "p1"),
    semantic_seed(first, "p1"),
    e$wlv_seed_resource("sea/sector/demo", second, contract, "p2"),
    semantic_seed(second, "p2"),
    e$wlv_seed_resource(
      "dimensions/lists", lists,
      e$wlv_resource_contract(scope = "run", value_type = "list")
    ),
    control_seeds[[1L]],
    control_seeds[[2L]],
    control_seeds[[3L]],
    control_seeds[[4L]]
  ))
  registry <- e$wlv_module_registry(list(e$wlv_indicator_stage4_collector_spec()))
  plan <- e$wlv_compile_module_plan(
    registry,
    list(e$wlv_module_instance(
      "collector.indicator.demo",
      "indicator.stage4_collector",
      args = list(indicator = "demo")
    )),
    store = store,
    partitions = c("p1", "p2")
  )
  result <- e$wlv_run_module_plan(plan, store)
  value <- e$wlv_store_read(
    result$store,
    e$wlv_resource_ref(
      "sea/sector/demo",
      e$wlv_native_indicator_contract("demo"),
      producer = "collector.indicator.demo"
    )
  )
  expect_identical(dimnames(value)[[1L]], lists$years)
  expect_equal(as.numeric(value[, "s1", ]), c(1, 11))
  expect_equal(as.numeric(value[, "s2", ]), c(2, 12))

  duplicate_first <- make_value("2000", 0)
  duplicate_second <- make_value("2000", 10)
  duplicate_store <- e$wlv_new_resource_store(list(
    e$wlv_seed_resource("sea/sector/demo", duplicate_first, contract, "p1"),
    semantic_seed(duplicate_first, "p1"),
    e$wlv_seed_resource("sea/sector/demo", duplicate_second, contract, "p2"),
    semantic_seed(duplicate_second, "p2"),
    e$wlv_seed_resource(
      "dimensions/lists", lists,
      e$wlv_resource_contract(scope = "run", value_type = "list")
    ),
    control_seeds[[1L]],
    control_seeds[[2L]],
    control_seeds[[3L]],
    control_seeds[[4L]]
  ))
  duplicate_plan <- e$wlv_compile_module_plan(
    registry,
    list(e$wlv_module_instance(
      "collector.indicator.demo",
      "indicator.stage4_collector",
      args = list(indicator = "demo")
    )),
    store = duplicate_store,
    partitions = c("p1", "p2")
  )
  expect_error(
    e$wlv_run_module_plan(duplicate_plan, duplicate_store),
    "duplicate years"
  )
})

test_that("native reduction and stage-5 formulas preserve legacy arithmetic", {
  e <- native_indicator_environment
  axes <- list(
    year = c("2000", "2001"), sector = c("s1", "s2"), country = "AAA"
  )
  hs <- array(c(0.2, 0.1, 0.3, 0.4), dim = c(2, 2, 1), dimnames = axes)
  ms <- array(c(0.3, 0.4, 0.2, 0.1), dim = c(2, 2, 1), dimnames = axes)
  ls <- 1 - hs - ms
  ctx <- e$wlv_runtime_context(
    inputs = list(hours_hs = hs, hours_ms = ms, hours_ls = ls),
    input_names = c("hours_hs", "hours_ms", "hours_ls"),
    args = list(), argument_names = character(),
    services = list(module_contract = function(result) result),
    service_names = "module_contract",
    partition = NULL, instance_id = "alternative-2-test"
  )
  result <- e$wlv_indicator_complex_emp_alternative_2_spec()$run(ctx)
  expect_equal(result$outputs$value, (6.25 * hs) + (2.5 * ms) + ls)

  lists <- list(years = axes$year, sectors = axes$sector, countries = axes$country)
  exports <- array(seq_len(4), dim = c(2, 2, 1), dimnames = axes)
  imports <- array(c(1, 1, 1, 1), dim = c(2, 2, 1), dimnames = axes)
  ctx <- e$wlv_runtime_context(
    inputs = list(exports = exports, imports = imports, lists = lists),
    input_names = c("exports", "imports", "lists"),
    args = list(), argument_names = character(),
    services = list(module_contract = function(result) result),
    service_names = "module_contract",
    partition = NULL, instance_id = "trade-balance-test"
  )
  result <- e$wlv_indicator_trade_balance_s_us_spec()$run(ctx)
  expect_equal(result$outputs$sector, exports - imports)
  expect_identical(names(result$outputs), "sector")
})
