native_output_environment <- new.env(parent = globalenv())
for (path in c(
  "R/lib/catalog.R",
  "R/lib/unit_dimensions.R",
  "R/lib/aggregation_specs.R",
  "R/lib/module_config.R",
  "R/lib/native_aggregation_registry.R",
  "R/lib/native_output_contract.R"
)) {
  sys.source(file.path(wlv_test_root, path), envir = native_output_environment)
}

test_that("public output profiles preserve the five historical panel orders", {
  e <- native_output_environment
  catalog <- e$wlv_load_catalog(wlv_test_root)
  profiles <- e$wlv_validate_native_output_profiles(wlv_test_root, catalog)
  expect_length(profiles, 12L)

  hashes <- vapply(profiles, function(indicators) {
    as.character(openssl::sha256(charToRaw(paste(indicators, collapse = "\n"))))
  }, character(1L))
  expect_identical(
    unname(hashes[c("wiodr13", "norow_w13", "zerodep_1")]),
    rep("68848ddbba1a0935d84ff8394d7b2eae33b13b2e14eb71d8753f6f0d7c77be55", 3L)
  )
  expect_identical(
    unname(hashes[c("wiodr16", "zerodep_2")]),
    rep("f4663edee461ee20f7313bb8371bf2ef57ddae3871703f7b4c0f2891307880df", 2L)
  )
  expect_identical(
    unname(hashes[c(
      "alternative_1", "alternative_2", "ochoa_1", "ochoa_2", "petrovic"
    )]),
    rep("cce4b63b7c821afd77d79bcbf05f0d8a6cc0e00c98b63d5cf3945d6b302e03c4", 5L)
  )
  expect_identical(
    unname(hashes[["wiodr13v09"]]),
    "c4e2f6d47dfbe1e28e1e995d28f31b74de98e702c37b59ceb9e908011005a06f"
  )
  expect_identical(
    unname(hashes[["wiodr16v09"]]),
    "46cd1a1bb12a1f7b4d3271e82aed0d5a5d66653707bbdff2f2357e028a9aec19"
  )
})

test_that("output order is separate from DAG and unit-contract row order", {
  e <- native_output_environment
  catalog <- e$wlv_load_catalog(wlv_test_root)
  aggregation <- e$wlv_native_aggregation_registry(
    wlv_test_root,
    catalog,
    "wiodr13"
  )
  output <- e$wlv_native_output_indicators(
    wlv_test_root,
    catalog,
    "wiodr13",
    aggregation
  )
  expect_null(attributes(output))
  source <- e$wlv_catalog_source(catalog, "wiodr13")
  units <- e$wlv_catalog_unit_contract(
    catalog,
    source$unit_contract[[1L]]
  )$units$indicator
  expect_setequal(output, units)
  expect_false(identical(unname(output), unname(units)))
  expect_identical(
    output[11:13],
    c("gross_output.s.us", "gdp.s.us", "go_price.r.id")
  )

  reduction <- e$wlv_native_output_indicators(
    wlv_test_root,
    catalog,
    "alternative_1"
  )
  expect_identical(
    reduction[20:21],
    c(
      "complex_labour_multiplier.emp.r.un",
      "complex_labour_multiplier.empe.r.un"
    )
  )
  legacy <- e$wlv_native_output_indicators(
    wlv_test_root,
    catalog,
    "wiodr13v09"
  )
  expect_identical(legacy[14:15], c("exchange.r.us", "exchange.r.id"))
})
