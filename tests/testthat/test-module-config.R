module_config_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "scripts", "lib", "module_config.R"),
  envir = module_config_environment
)

wlv_test_write_module_fragment <- function(path, rows = character()) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeLines(
    c(
      "instance_id;module_id;action;replaces;variant;source_variable;args_json",
      rows
    ),
    path,
    useBytes = TRUE
  )
}

test_that("typed module configuration resolves common, source and method layers", {
  root <- tempfile("wlv-module-config-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  wlv_test_write_module_fragment(
    file.path(root, "config", "modules", "common.csv"),
    c(
      "alpha;module.alpha;add;;;;{}",
      "removable;module.removable;add;;;;{}"
    )
  )
  wlv_test_write_module_fragment(
    file.path(root, "config", "modules", "sources", "demo.csv"),
    "alpha;module.alpha.source;replace;alpha;;;\"{\"\"count\"\":2}\""
  )
  wlv_test_write_module_fragment(
    file.path(root, "config", "modules", "methods", "demo.csv"),
    c(
      "removable;;remove;removable;;;{}",
      "beta;module.beta;add;;;;{}"
    )
  )

  value <- module_config_environment$wlv_resolve_module_config(
    root,
    "demo",
    "demo"
  )
  expect_s3_class(value, "wlv_module_config")
  expect_identical(value$instance_id, c("alpha", "beta"))
  expect_identical(value$module_id, c("module.alpha.source", "module.beta"))
  expect_true(is.list(value$args))
  expect_identical(value$args[[1L]]$count, 2L)
  expect_identical(value$declared_layer, c("source", "method"))
  expect_true(all(value$action == "add"))
})

test_that("typed module configuration rejects ambiguous layer mutations", {
  root <- tempfile("wlv-module-config-")
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  common <- file.path(root, "config", "modules", "common.csv")
  source <- file.path(root, "config", "modules", "sources", "demo.csv")
  method <- file.path(root, "config", "modules", "methods", "demo.csv")
  wlv_test_write_module_fragment(
    common,
    c("alpha;module.alpha;add;;;;{}", "alpha;module.other;add;;;;{}")
  )
  wlv_test_write_module_fragment(source)
  wlv_test_write_module_fragment(method)
  expect_error(
    module_config_environment$wlv_resolve_module_config(root, "demo", "demo"),
    "repeats instance"
  )

  wlv_test_write_module_fragment(common, "alpha;module.alpha;add;;;;{}")
  wlv_test_write_module_fragment(
    source,
    "beta;module.beta;replace;missing;;;{}"
  )
  expect_error(
    module_config_environment$wlv_resolve_module_config(root, "demo", "demo"),
    "missing earlier instance"
  )

  wlv_test_write_module_fragment(source, "bad;scripts/modules/bad.R;add;;;;{}")
  expect_error(
    module_config_environment$wlv_resolve_module_config(root, "demo", "demo"),
    "invalid module alias"
  )
})

test_that("all executable methods have a deterministic typed configuration", {
  resolved <- module_config_environment$wlv_validate_executable_module_configs(
    wlv_test_root
  )
  expect_identical(
    names(resolved),
    c("wiodr13", "wiodr16")
  )
  for (method in names(resolved)) {
    value <- resolved[[method]]
    expect_identical(anyDuplicated(value$instance_id), 0L, info = method)
    expect_identical(value$instance_id, sort(value$instance_id), info = method)
    expect_true(is.list(value$args), info = method)
    expect_false(any(vapply(value$args, function(args) {
      "checkpoint" %in% names(args)
    }, logical(1L))), info = method)
    expect_false(any(grepl("[/\\\\]", value$module_id)), info = method)
    expect_false(any(grepl("[.]R$", value$module_id)), info = method)
  }

  wiodr13 <- resolved$wiodr13
  source_row <- wiodr13[wiodr13$instance_id == "indicator.emp.s.un", , drop = FALSE]
  expect_identical(source_row$module_id, "source_indicator")
  expect_identical(source_row$args[[1L]]$source_variable, "EMP")
  expect_identical(source_row$args[[1L]]$indicator, "emp.s.un")
  expect_false("checkpoint" %in% names(source_row$args[[1L]]))

  row_assumption <- wiodr13[
    wiodr13$instance_id == "assumption.row",
    ,
    drop = FALSE
  ]
  expect_identical(row_assumption$args[[1L]]$source, "wiodr13")
  expect_identical(row_assumption$args[[1L]]$variant, "standard")

  runtime <- new.env(parent = baseenv())
  sys.source(
    file.path(wlv_test_root, "scripts", "lib", "module_runtime.R"),
    envir = runtime
  )
  instances <- runtime$wlv_runtime_instances(resolved$wiodr13)
  expect_length(instances, nrow(resolved$wiodr13))
  expect_true(all(vapply(
    instances,
    inherits,
    logical(1L),
    "wlv_module_instance"
  )))
})

test_that("deferred configurations retain their native declarations", {
  resolve <- function(method, source) {
    module_config_environment$wlv_resolve_module_config(
      wlv_test_root, method, source
    )
  }
  legacy <- resolve("wiodr16v09", "wiodr16")
  row <- legacy[legacy$instance_id == "assumption.row", , drop = FALSE]
  expect_identical(row$args[[1L]]$source, "wiodr16")
  expect_identical(row$args[[1L]]$variant, "v09")
  alternative <- resolve("alternative_1", "wiodr13")
  expect_identical(
    alternative$module_id[alternative$instance_id == "matrix.capital"],
    "matrix.capital.reduction_problem"
  )
  expect_true("matrix.depreciation_override" %in%
    resolve("zerodep_1", "wiodr13")$instance_id)
  expect_true("matrix.depreciation_override" %in%
    resolve("zerodep_2", "wiodr16")$instance_id)
})

wlv_test_historical_aggregation <- function(source) {
  utils::read.csv2(
    file.path(
      wlv_test_root,
      "contracts",
      "units",
      paste0(source, "_v1-aggregations.csv")
    ),
    stringsAsFactors = FALSE,
    colClasses = "character",
    check.names = FALSE,
    na.strings = NULL
  )
}

test_that("experimental methods select two shared explicit historical profiles", {
  mapping <- module_config_environment$wlv_read_aggregation_profile_map(
    wlv_test_root
  )
  expect_equal(nrow(mapping), 10L)
  expect_setequal(
    unique(mapping$profile),
    c("wiodr13_historical_v1", "wiodr16_historical_v1")
  )
  expect_equal(sum(mapping$profile == "wiodr13_historical_v1"), 8L)
  expect_equal(sum(mapping$profile == "wiodr16_historical_v1"), 2L)

  for (source in c("wiodr13", "wiodr16")) {
    profile <- module_config_environment$wlv_read_aggregation_profile(
      wlv_test_root,
      paste0(source, "_historical_v1")
    )
    historical <- wlv_test_historical_aggregation(source)
    names(profile)[names(profile) == "module"] <- "module_id"
    compared <- setdiff(names(profile), "notes")
    expect_identical(
      as.data.frame(profile)[compared],
      historical[compared],
      info = source
    )
    expect_false(any(grepl("[/\\\\]", profile$module_id)), info = source)
    expect_false(any(grepl("[.]R$", profile$module_id)), info = source)
    expect_false("legacy" %in% names(profile), info = source)
  }
})

test_that("aggregation profiles reject incomplete and path-based bindings", {
  profile <- data.frame(
    indicator = rep("demo", 2L),
    level = c("sector_to_country", "country_to_world"),
    strategy = rep("sum", 2L),
    module = rep("", 2L),
    numerator = rep("", 2L),
    denominator = rep("", 2L),
    weight = rep("", 2L),
    zero_denominator = rep("", 2L),
    notes = rep("", 2L),
    stringsAsFactors = FALSE
  )
  expect_no_error(module_config_environment$wlv_validate_aggregation_profile(
    profile,
    "demo"
  ))
  expect_error(
    module_config_environment$wlv_validate_aggregation_profile(
      profile[1L, , drop = FALSE],
      "demo"
    ),
    "both aggregation levels"
  )
  formula <- profile
  formula$strategy <- "formula"
  formula$module <- c("aggregation.demo", "scripts/modules/demo.R")
  expect_error(
    module_config_environment$wlv_validate_aggregation_profile(
      formula,
      "demo"
    ),
    "invalid formula aliases"
  )
})

test_that("norow method parameters are valid UTF-8 without semantic drift", {
  path <- file.path(
    wlv_test_root,
    "methods",
    "norow_w13",
    "_parameters.csv"
  )
  catalog_path <- file.path(wlv_test_root, "catalog", "methods.csv")
  for (utf8_path in c(path, catalog_path)) {
    bytes <- readBin(utf8_path, "raw", n = file.info(utf8_path)$size)
    text <- rawToChar(bytes)
    decoded <- iconv(text, from = "UTF-8", to = "UTF-8", sub = NA_character_)
    expect_false(is.na(decoded), info = utf8_path)
    expect_false(grepl("\uFFFD", decoded, fixed = TRUE), info = utf8_path)
  }
  value <- utils::read.csv2(
    path,
    stringsAsFactors = FALSE,
    encoding = "UTF-8"
  )
  catalog <- utils::read.csv2(
    text = readLines(catalog_path, encoding = "UTF-8", warn = FALSE),
    stringsAsFactors = FALSE
  )
  description <- catalog$description[catalog$method == "norow_w13"]
  expect_identical(
    value$name,
    "Teste sem suposi\u00e7\u00f5es para resto do mundo"
  )
  expect_identical(description, value$name)
  expect_true(all(c(0x00e7L, 0x00f5L) %in% utf8ToInt(value$name)))
})
