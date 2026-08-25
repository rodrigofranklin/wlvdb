native_capital_environment <- new.env(parent = globalenv())
for (native_capital_file in c(
  "R/lib/module_runtime.R",
  "R/lib/semantic_resources.R",
  "R/lib/missingness.R",
  "R/lib/result_contracts.R",
  "R/lib/functions.R",
  "R/lib/wiodr16_allocation.R",
  "R/lib/gfcf_contracts.R",
  "R/lib/gfcf_diagnostics.R",
  "R/modules/native/contracts.R",
  "R/modules/native/capital_matrix_modules.R"
)) {
  sys.source(
    file.path(wlv_test_root, native_capital_file),
    envir = native_capital_environment
  )
}
rm(native_capital_file)

wlv_test_native_capital_fixture <- function(method = c("wiodr13", "wiodr16")) {
  method <- match.arg(method)
  years <- "2000"
  countries <- c("USA", "ROW")
  sectors <- c("S1", "S2")
  rows <- data.frame(
    country = rep(countries, each = length(sectors)),
    sector = rep(sectors, times = length(countries)),
    stringsAsFactors = FALSE
  )
  input <- paste(rows$country, rows$sector, sep = ".")
  demand <- if (identical(method, "wiodr16")) "c60" else "c41"
  output <- c(input, paste(countries, demand, sep = "."))
  columns <- data.frame(
    country = c(rows$country, countries),
    sector = c(rows$sector, rep(demand, length(countries))),
    stringsAsFactors = FALSE
  )
  columns$country_sector <- paste(columns$country, columns$sector, sep = ".")
  sector_configuration <- data.frame(
    euklems.sector = c("A", "A"),
    euklems.capital = c("K1", "K2"),
    stringsAsFactors = FALSE
  )
  lists <- list(
    years = years,
    countries = countries,
    sectors = sectors,
    input = input,
    output = output
  )
  nums <- list(
    years = length(years),
    countries = length(countries),
    sectors = length(sectors),
    input = length(input),
    output = length(output)
  )
  source_io <- array(
    0,
    dim = c(length(years), length(input), length(output)),
    dimnames = list(year = years, input = input, output = output)
  )
  source_io["2000", , paste("USA", demand, sep = ".")] <- c(10, 20, 30, 40)
  source_io["2000", , paste("ROW", demand, sep = ".")] <- c(5, 10, 15, 20)
  gdp <- array(
    c(30, 70, 40, 60),
    dim = c(1L, 2L, 2L),
    dimnames = list(year = years, sector = sectors, country = countries)
  )
  capital_stock <- array(
    c(100, 200, 150, 250),
    dim = c(1L, 2L, 2L),
    dimnames = dimnames(gdp)
  )
  capital_weights <- list(`2000` = data.frame(
    country = c("US", "MD"),
    sector = c("A", "A"),
    K1 = c(0.75, 0.25),
    K2 = c(0.25, 0.75),
    stringsAsFactors = FALSE
  ))
  depreciation_rates <- list(
    `2000` = data.frame(
      country = c("US", "MD"),
      sector = c("A", "A"),
      K1 = c(0.05, 0.10),
      K2 = c(0.15, 0.20),
      stringsAsFactors = FALSE
    ),
    `2001` = data.frame(
      country = c("US", "MD"),
      sector = c("A", "A"),
      K1 = c(0.10, 0.20),
      K2 = c(0.30, 0.40),
      stringsAsFactors = FALSE
    )
  )
  observations <- data.frame(
    year = "2000",
    input = "USA.S1",
    output = paste("USA", demand, sep = "."),
    value = -1,
    policy_id = paste0(method, "_negative_gfcf_v1"),
    action = "truncate_allowlisted_negative_gfcf",
    stringsAsFactors = FALSE
  )
  list(
    source_io = source_io,
    gdp = gdp,
    capital_stock = capital_stock,
    lists = lists,
    nums = nums,
    rows = rows,
    columns = columns,
    sectors = sector_configuration,
    capital_weights = capital_weights,
    depreciation_rates = depreciation_rates,
    gfcf_observations = observations
  )
}

wlv_test_run_native_capital <- function(spec, fixture, method) {
  runtime <- native_capital_environment
  instance <- runtime$wlv_module_instance(
    "matrix.capital",
    spec$id,
    partition = "all"
  )
  registry <- runtime$wlv_module_registry(list(spec))
  resolved <- runtime$wlv_runtime_resolve_instance(
    registry,
    instance,
    "calculate",
    "all"
  )
  policy <- if (identical(method, "wiodr16")) {
    runtime$wlv_wiodr16_missingness_policy()
  } else {
    runtime$wlv_wiodr13_missingness_policy()
  }
  contract_runtime <- wlv_test_contract_runtime(
    runtime,
    method = "synthetic",
    source = method,
    policy = policy
  )
  controls <- list(
    "request/method" = contract_runtime$method,
    "request/source" = contract_runtime$source,
    "configuration/missingness_policy" = contract_runtime$policy,
    "configuration/scientific_profile" = contract_runtime$scientific_profile
  )
  seeds <- lapply(names(resolved$requires), function(alias) {
    ref <- resolved$requires[[alias]]
    value <- if (identical(ref$contract$role, "control")) {
      controls[[ref$key]]
    } else if (identical(ref$contract$role, "semantic_state")) {
      target_key <- sub("^semantic_state/", "", ref$key)
      target_alias <- names(resolved$requires)[vapply(
        resolved$requires,
        function(candidate) identical(candidate$key, target_key),
        logical(1L)
      )][[1L]]
      target_ref <- resolved$requires[[target_alias]]
      runtime$wlv_semantic_capture_value_state(
        fixture[[target_alias]],
        target_key,
        target_ref$contract$axes,
        runtime = contract_runtime
      )$state
    } else {
      fixture[[alias]]
    }
    runtime$wlv_seed_resource(
      key = ref$key,
      value = value,
      contract = ref$contract,
      partition = ref$partition,
      producer = if (is.null(ref$producer)) {
        runtime$wlv_runtime_seed_producer()
      } else {
        ref$producer
      }
    )
  })
  store <- runtime$wlv_new_resource_store(seeds)
  plan <- runtime$wlv_compile_module_plan(
    registry,
    list(instance),
    store,
    partitions = "all"
  )
  result <- runtime$wlv_run_module_plan(
    plan,
    store
  )
  read_matrix <- function(resource) {
    runtime$wlv_store_read(
      result$store,
      runtime$wlv_resource_ref(
        key = paste0("io/", resource),
        contract = runtime$wlv_native_io_contract(resource),
        partition = "all"
      )
    )
  }
  list(
    composition = read_matrix("k_composition"),
    depreciation = read_matrix("k_depreciation"),
    diagnostics = runtime$wlv_store_read(
      result$store,
      runtime$wlv_resource_ref(
        "diagnostic/matrix.capital",
        runtime$wlv_resource_contract(
          scope = "io_period",
          value_type = "list",
          role = "diagnostic"
        ),
        producer = "matrix.capital",
        partition = "all"
      )
    ),
    trace = result$trace,
    contract_runtime = contract_runtime
  )
}

test_that("native capital specs declare every external input", {
  runtime <- native_capital_environment
  specs <- runtime$wlv_native_capital_matrix_specs()
  expect_identical(
    names(specs),
    unname(vapply(specs, `[[`, character(1L), "id"))
  )
  expected_inputs <- c(
    "source_io", "gdp", "capital_stock", "lists", "nums", "rows",
    "columns", "sectors", "capital_weights", "depreciation_rates",
    "gfcf_observations"
  )
  expect_identical(
    unname(vapply(specs, `[[`, character(1L), "scope")),
    rep("io_period", 3L)
  )
  expect_identical(
    unname(vapply(specs, `[[`, integer(1L), "checkpoint")),
    rep(3L, 3L)
  )
  expect_true(all(vapply(specs, function(spec) {
    instance <- runtime$wlv_module_instance(
      paste0(spec$id, ".test"),
      spec$id,
      partition = "all"
    )
    requires <- spec$requires(list(), instance)
    provides <- spec$provides(list(), instance)
    scientific_requires <- requires[!vapply(requires, function(ref) {
      ref$contract$role %in% c("semantic_state", "control")
    }, logical(1L))]
    scientific_provides <- provides[vapply(provides, function(output) {
      identical(output$ref$contract$role, "value")
    }, logical(1L))]
    identical(names(scientific_requires), expected_inputs) &&
      identical(names(scientific_provides), c("k_composition", "k_depreciation")) &&
      setequal(spec$services, c("contract_runtime", "module_contract"))
  }, logical(1L))))
  first_instance <- runtime$wlv_module_instance(
    paste0(specs[[1L]]$id, ".test"),
    specs[[1L]]$id,
    partition = "all"
  )
  expect_true(specs[[1L]]$requires(
    list(),
    first_instance
  )$gfcf_observations$optional)
})

test_that("WIOD13 native capital allocation conserves stock and preserves NA slices", {
  runtime <- native_capital_environment
  fixture <- wlv_test_native_capital_fixture("wiodr13")
  result <- wlv_test_run_native_capital(
    runtime$wlv_matrix_capital_wiodr13_spec(),
    fixture,
    "wiodr13"
  )
  productive <- seq_along(fixture$lists$input)
  composition <- result$composition[1L, productive, productive]
  depreciation <- result$depreciation[1L, productive, productive]
  expect_equal(unname(colSums(composition)), as.numeric(fixture$capital_stock))
  expected_rates <- rbind(
    c(0.10, 0.10, 0.20, 0.20),
    c(0.30, 0.30, 0.40, 0.40),
    c(0.10, 0.10, 0.20, 0.20),
    c(0.30, 0.30, 0.40, 0.40)
  )
  expect_equal(depreciation, composition * expected_rates)
  expect_true(all(is.na(result$composition[, , -productive, drop = FALSE])))
  expect_identical(
    names(result$diagnostics),
    c("_gfcf_negative_cells.csv", "_gfcf_negative_summary.csv")
  )
  expect_equal(
    result$diagnostics[["_gfcf_negative_cells.csv"]]$original_million_usd,
    -1
  )
})

test_that("reduction-problem capital uses the contemporaneous depreciation table", {
  runtime <- native_capital_environment
  fixture <- wlv_test_native_capital_fixture("wiodr13")
  standard <- wlv_test_run_native_capital(
    runtime$wlv_matrix_capital_wiodr13_spec(),
    fixture,
    "wiodr13"
  )
  reduction <- wlv_test_run_native_capital(
    runtime$wlv_matrix_capital_reduction_problem_spec(),
    fixture,
    "wiodr13"
  )
  productive <- seq_along(fixture$lists$input)
  expect_equal(reduction$composition, standard$composition)
  expect_equal(
    reduction$depreciation[1L, productive, productive],
    standard$depreciation[1L, productive, productive] / 2
  )
})

test_that("WIOD16 native capital uses c60 and the validated allocation path", {
  runtime <- native_capital_environment
  fixture <- wlv_test_native_capital_fixture("wiodr16")
  result <- wlv_test_run_native_capital(
    runtime$wlv_matrix_capital_wiodr16_spec(),
    fixture,
    "wiodr16"
  )
  productive <- seq_along(fixture$lists$input)
  composition <- result$composition[1L, productive, productive]
  depreciation <- result$depreciation[1L, productive, productive]
  expect_equal(unname(colSums(composition)), as.numeric(fixture$capital_stock))
  expected_rates <- rbind(
    c(0.10, 0.10, 0.20, 0.20),
    c(0.30, 0.30, 0.40, 0.40),
    c(0.10, 0.10, 0.20, 0.20),
    c(0.30, 0.30, 0.40, 0.40)
  )
  expect_equal(depreciation, composition * expected_rates)
  expect_identical(result$trace$instance_id, "matrix.capital")
  expect_identical(result$trace$module_id, "matrix.capital.wiodr16")
  expect_identical(
    result$diagnostics[["_gfcf_negative_cells.csv"]]$final_demand,
    "c60"
  )
})

test_that("capital execution fails before publication when an EU KLEMS year is absent", {
  runtime <- native_capital_environment
  fixture <- wlv_test_native_capital_fixture("wiodr13")
  fixture$depreciation_rates[["2001"]] <- NULL
  expect_error(
    wlv_test_run_native_capital(
      runtime$wlv_matrix_capital_wiodr13_spec(),
      fixture,
      "wiodr13"
    ),
    "depreciation_rates.*2001",
    class = "wlv_module_execution_error"
  )
})
