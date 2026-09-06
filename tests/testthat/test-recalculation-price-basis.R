test_that("WIOD13 stage-four baskets retain pre-rebasing relative prices", {
  runtime <- wlv_test_load_runtime()
  lists <- list(years = c("2000", "2001"), sectors = c("S1", "S2"),
    countries = c("USA", "ROW"))
  raw <- array(c(2, 3, 5, 10, 99, 99, 99, 99), c(2L, 2L, 2L),
    dimnames = list(year = lists$years, sector = lists$sectors,
      country = lists$countries))
  source <- array(raw, c(2L, 1L, 2L, 2L), dimnames = list(
    year = lists$years, variable = "GO_P", sector = lists$sectors,
    country = lists$countries))
  assumed <- raw
  assumed[, , "ROW"] <- assumed[, , "USA"]
  rebase <- function(x) sweep(x, c(2L, 3L), x["2000", , ], `/`)
  published <- rebase(assumed)
  original_source <- source
  original_published <- published
  inputs <- list(
    lists = lists, nums = list(input = 4L, sectors = 2L, countries = 2L),
    period_source = array(1, c(2L, 4L, 4L), dimnames = list(
      year = lists$years, input = paste0("I", 1:4), output = paste0("I", 1:4))),
    basket_zero = matrix(c(1, 2, 3, 4), 4L, 4L),
    lambda_zero = rep(1, 4L), lambda = matrix(1, 2L, 4L),
    exchange = array(1, dim(raw), dimnames(raw)),
    go_price_source = source
  )
  run_basket <- function(spec, from_source, price) {
    values <- c(inputs, list(go_price = price))
    ctx <- list(input = function(name) values[[name]],
      arg = function(name) switch(name, go_price_from_source = from_source),
      service = function(name) identity)
    rebase(spec$run(ctx)$outputs$value)
  }
  for (spec in list(runtime$wlv_indicator_basket_price_r_pc_spec(),
      runtime$wlv_indicator_basket_value_r_pc_spec())) {
    full <- run_basket(spec, FALSE, assumed)
    historical <- run_basket(spec, FALSE, published)
    recalculated <- run_basket(spec, TRUE, published)
    expect_gt(max(abs(historical - full)), 0.01)
    expect_identical(recalculated, full, info = spec$id)
    expect_identical(run_basket(spec, TRUE, published), full, info = spec$id)
    expect_identical(dimnames(recalculated), dimnames(assumed))
    expect_identical(is.na(recalculated), is.na(full))
  }
  expect_identical(source, original_source)
  expect_identical(published, original_published)
})

test_that("basket source recovery is scoped to valid WIOD13 stage-four selections", {
  runtime <- wlv_test_load_runtime()
  plan <- runtime$wlv_validate_request(c("wiodr13", "wiodr16"), root = wlv_test_root)
  for (method in plan$method_names) {
    for (stage in c(1L, 4L, 5L)) {
      for (selection in list(NULL, "basket_price.r.pc", "gross_output.s.mv")) {
        if (stage != 4L && !is.null(selection)) next
        instances <- runtime$wlv_native_plan_instances(
          plan$native_registry, plan$configuration[[method]],
          plan$aggregation_registries[[method]], plan$indicators[[method]],
          "2000-2001", "recalculate", stage, selection)
        expect_silent(runtime$wlv_native_preflight_plan(
          plan$native_registry, instances, "2000-2001", "recalculate",
          method, stage, plan$indicators[[method]]))
        resolved <- lapply(instances, function(instance) {
          runtime$wlv_native_resolved_spec_contracts(plan$native_registry, instance)
        })
        basket <- Filter(function(x) x$spec$id %in% c(
          "indicator.basket_price.r.pc", "indicator.basket_value.r.pc"), resolved)
        for (module in basket) {
          recovered <- identical(method, "wiodr13") && identical(stage, 4L)
          expect_identical(isTRUE(module$args$go_price_from_source), recovered)
          expect_identical("go_price_source" %in% names(module$requires), recovered)
          expect_identical("go_price" %in% names(module$requires), !recovered)
        }
        if (!is.null(selection)) {
          produced <- runtime$wlv_native_recalculated_indicator_ids(
            lapply(resolved, function(x) list(provides = x$provides)),
            plan$indicators[[method]])
          expect_identical(produced, selection)
        }
      }
    }
  }
})
