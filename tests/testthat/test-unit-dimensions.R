unit_dimensions_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "scripts", "lib", "unit_dimensions.R"),
  envir = unit_dimensions_environment
)

unit <- function(name, ...) {
  unit_dimensions_environment$wlv_unit_base(name, ...)
}

test_that("dimension construction is canonical and deterministic", {
  construct <- unit_dimensions_environment$wlv_unit_dimension
  first <- construct(c(hour = -1, person = 1, USD = 2))
  second <- construct(c(USD = 2, person = 1, hour = -1))

  expect_identical(first, second)
  expect_identical(
    first$exponents,
    c(USD = 2L, LCU = 0L, person = 1L, hour = -1L, labour_value = 0L)
  )
  expect_identical(first$currency_scope, "global")
  expect_identical(first$price_basis, "current")
  expect_identical(
    unit_dimensions_environment$wlv_unit_signature(first),
    "USD^2*person*hour^-1 [currency_scope=global; price_basis=current]"
  )
  expect_error(construct(c(banana = 1)), "using only: USD, LCU, person")
  expect_error(construct(c(USD = 0.5)), "integer vector")
})

test_that("currency and price qualifiers are validated at construction", {
  construct <- unit_dimensions_environment$wlv_unit_dimension

  expect_error(
    construct(c(LCU = 1)),
    "explicit `currency_scope`",
    fixed = TRUE
  )
  expect_error(
    construct(c(LCU = 1), currency_scope = "global"),
    "country-specific currency scope",
    fixed = TRUE
  )
  expect_error(
    construct(c(USD = 1), currency_scope = "BRA"),
    "USD-only dimensions require",
    fixed = TRUE
  )
  expect_error(
    unit("USD", price_basis = "constant"),
    "four-digit `base_year` is required",
    fixed = TRUE
  )
  expect_error(
    unit("USD", price_basis = "current", base_year = 2000),
    "Current-price units cannot declare",
    fixed = TRUE
  )

  constant <- unit("USD", price_basis = "constant", base_year = "2000")
  expect_identical(constant$base_year, 2000L)
  expect_identical(constant$price_basis, "constant")
})

test_that("addition requires identical dimensions and qualifiers", {
  assert_addable <- unit_dimensions_environment$wlv_unit_assert_addable
  current_usd <- unit("USD")
  current_usd_copy <- unit("USD")
  constant_usd <- unit("USD", price_basis = "constant", base_year = 2000)

  expect_invisible(assert_addable(current_usd, current_usd_copy))
  expect_error(
    assert_addable(current_usd, unit("person")),
    "Cannot sum non-identical units",
    fixed = TRUE
  )
  expect_error(
    assert_addable(current_usd, constant_usd),
    "price_basis=current",
    fixed = TRUE
  )
  expect_error(
    assert_addable(
      unit("LCU", currency_scope = "BRA"),
      unit("LCU", currency_scope = "MEX")
    ),
    "currency_scope=BRA",
    fixed = TRUE
  )
})

test_that("multiplication and division obey exponent algebra", {
  multiply <- unit_dimensions_environment$wlv_unit_multiply
  divide <- unit_dimensions_environment$wlv_unit_divide
  usd <- unit("USD")
  person <- unit("person")
  hour <- unit("hour")

  usd_per_person <- divide(usd, person)
  expect_identical(
    usd_per_person$exponents,
    c(USD = 1L, LCU = 0L, person = -1L, hour = 0L, labour_value = 0L)
  )
  expect_identical(multiply(usd_per_person, person), usd)
  expect_identical(multiply(person, hour), multiply(hour, person))

  roundtrip <- divide(multiply(usd, hour), hour)
  expect_identical(roundtrip, usd)
  expect_true(
    unit_dimensions_environment$wlv_unit_is_dimensionless(divide(usd, usd))
  )
  expect_identical(divide(usd, usd)$kind, "ratio")
})

test_that("unit algebra rejects ambiguous price and currency products", {
  multiply <- unit_dimensions_environment$wlv_unit_multiply
  divide <- unit_dimensions_environment$wlv_unit_divide
  current_usd <- unit("USD")
  constant_usd <- unit("USD", price_basis = "constant", base_year = 2000)

  expect_error(
    multiply(current_usd, constant_usd),
    "incompatible price qualifiers",
    fixed = TRUE
  )
  expect_error(
    divide(
      unit("LCU", currency_scope = "BRA"),
      unit("LCU", currency_scope = "MEX")
    ),
    "different currency scopes",
    fixed = TRUE
  )
})

test_that("ratios and dimensionless units are explicit", {
  dimensionless <- unit_dimensions_environment$wlv_unit_dimensionless()
  ratio <- unit_dimensions_environment$wlv_unit_ratio(
    unit("labour_value"),
    unit("hour")
  )

  expect_true(unit_dimensions_environment$wlv_unit_is_dimensionless(dimensionless))
  expect_identical(dimensionless$kind, "ratio")
  expect_false(unit_dimensions_environment$wlv_unit_is_dimensionless(ratio))
  expect_identical(
    ratio$exponents,
    c(USD = 0L, LCU = 0L, person = 0L, hour = -1L, labour_value = 1L)
  )
})

test_that("only indices can be rebased", {
  index <- unit_dimensions_environment$wlv_unit_index(2000, 100)
  rebased <- unit_dimensions_environment$wlv_unit_rebase(index, 2010, 1)

  expect_identical(index$kind, "index")
  expect_true(unit_dimensions_environment$wlv_unit_is_dimensionless(index))
  expect_identical(rebased$base_year, 2010L)
  expect_identical(rebased$index_base, 1)
  expect_error(
    unit_dimensions_environment$wlv_unit_rebase(unit("USD"), 2010),
    "Only index units can be rebased",
    fixed = TRUE
  )
  expect_error(
    unit_dimensions_environment$wlv_unit_index(2000, 0),
    "positive finite `index_base`",
    fixed = TRUE
  )
})

test_that("index algebra preserves only unambiguous semantics", {
  multiply <- unit_dimensions_environment$wlv_unit_multiply
  divide <- unit_dimensions_environment$wlv_unit_divide
  dimensionless <- unit_dimensions_environment$wlv_unit_dimensionless()
  index <- unit_dimensions_environment$wlv_unit_index(2000, 100)

  expect_identical(multiply(index, dimensionless), index)
  expect_identical(divide(index, dimensionless), index)
  expect_identical(divide(dimensionless, index), dimensionless)
  expect_identical(divide(index, index), dimensionless)
  expect_error(
    multiply(index, index),
    "explicit output contract",
    fixed = TRUE
  )
  expect_error(
    divide(index, unit_dimensions_environment$wlv_unit_index(2010, 100)),
    "different base qualifiers",
    fixed = TRUE
  )
})

test_that("LCU aggregation cannot cross country currency scopes", {
  assert_country <-
    unit_dimensions_environment$wlv_unit_assert_country_aggregation
  brazil_lcu <- unit("LCU", currency_scope = "BRA")
  generic_lcu <- unit("LCU", currency_scope = "country")

  expect_invisible(assert_country(brazil_lcu, rep("BRA", 3L)))
  expect_invisible(assert_country(generic_lcu, "MEX"))
  expect_invisible(assert_country(unit("USD"), c("BRA", "MEX")))
  expect_error(
    assert_country(brazil_lcu, c("BRA", "MEX")),
    "Cannot aggregate LCU units across countries",
    fixed = TRUE
  )
  expect_error(
    assert_country(brazil_lcu, "MEX"),
    "does not match aggregation country `MEX`",
    fixed = TRUE
  )
})

test_that("multiplication properties hold across every compatible base pair", {
  multiply <- unit_dimensions_environment$wlv_unit_multiply
  divide <- unit_dimensions_environment$wlv_unit_divide
  quantities <- list(
    unit("USD"),
    unit("LCU", currency_scope = "BRA"),
    unit("person"),
    unit("hour"),
    unit("labour_value")
  )

  for (left in quantities) {
    for (right in quantities) {
      product <- multiply(left, right)
      expect_identical(product, multiply(right, left))
      expect_identical(divide(product, right), left)
    }
  }

  left <- multiply(multiply(quantities[[1L]], quantities[[2L]]), quantities[[3L]])
  right <- multiply(quantities[[1L]], multiply(quantities[[2L]], quantities[[3L]]))
  expect_identical(left, right)
})
