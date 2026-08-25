native_matrix_shape_environment <- new.env(parent = globalenv())
for (native_matrix_shape_file in c(
  "R/lib/module_runtime.R",
  "R/lib/functions.R",
  "R/modules/native/contracts.R",
  "R/modules/native/source_modules.R",
  "R/modules/native/indicator_helpers.R",
  "R/modules/native/matrix_modules.R",
  "R/modules/native/indicator_source_derived_modules.R"
)) {
  sys.source(
    file.path(wlv_test_root, native_matrix_shape_file),
    envir = native_matrix_shape_environment
  )
}
rm(native_matrix_shape_file)

test_that("native basket preserves the complete public output axis", {
  e <- native_matrix_shape_environment
  inputs <- c("USA.S1", "USA.S2", "ROW.S1", "ROW.S2")
  outputs <- c(inputs, "USA.c41", "ROW.c41")
  source_io <- array(
    0,
    dim = c(1L, length(inputs), length(outputs)),
    dimnames = list(year = "2000", input = inputs, output = outputs)
  )
  source_io["2000", , "USA.c41"] <- c(3, 1, 2, 2)
  source_io["2000", , "ROW.c41"] <- c(1, 3, 2, 2)
  values <- list(
    source_io = source_io,
    nums = list(years = 1L, input = 4L, countries = 2L, sectors = 2L),
    columns = data.frame(
      sector = c("S1", "S2", "S1", "S2", "c41", "c41"),
      stringsAsFactors = FALSE
    ),
    demands = data.frame(demand = "c41", stringsAsFactors = FALSE)
  )
  context <- list(input = function(name) values[[name]])
  result <- e$wlv_matrix_basket_national_spec()$run(context)$outputs$value

  expect_identical(dim(result), dim(source_io))
  expect_identical(dimnames(result), dimnames(source_io))
  expect_true(all(is.finite(result[, , seq_along(inputs)])))
  expect_true(all(is.na(result[, , -seq_along(inputs)])))
})

test_that("basket-zero collector extracts the inter-industry block by label", {
  e <- native_matrix_shape_environment
  inputs <- c("USA.S1", "USA.S2", "ROW.S1", "ROW.S2")
  outputs <- c(inputs, "USA.c41", "ROW.c41")
  basket <- array(
    seq_len(24L),
    dim = c(1L, 4L, 6L),
    dimnames = list(year = "2000", input = inputs, output = outputs)
  )
  lambda <- array(
    seq_len(4L),
    dim = c(1L, 4L),
    dimnames = list(year = "2000", input = inputs)
  )
  values <- list(baskets = list(period = basket), lambdas = list(period = lambda))
  context <- list(
    input = function(name) values[[name]],
    arg = function(name) if (identical(name, "base_year")) "2000" else NULL
  )
  result <- e$wlv_indicator_basket_zero_collector_spec()$run(context)$outputs

  expect_identical(dim(result$basket_zero), c(4L, 4L))
  expect_identical(dimnames(result$basket_zero), list(input = inputs, output = inputs))
  expect_identical(as.vector(result$basket_zero), as.vector(basket[1L, , 1:4]))
  expect_identical(as.vector(result$lambda_zero), as.vector(lambda[1L, ]))
})

test_that("basket-zero collector derives the historical first matrix year", {
  e <- native_matrix_shape_environment
  inputs <- c("USA.S1", "ROW.S1")
  basket <- array(
    NA_real_,
    dim = c(2L, 2L, 2L),
    dimnames = list(
      year = c("1995", "2000"),
      input = inputs,
      output = inputs
    )
  )
  basket["1995", , ] <- 1995
  basket["2000", , ] <- 2000
  lambda <- array(
    NA_real_,
    dim = c(2L, 2L),
    dimnames = list(year = c("1995", "2000"), input = inputs)
  )
  lambda["1995", ] <- c(1, 2)
  lambda["2000", ] <- c(10, 20)
  values <- list(baskets = list(period = basket), lambdas = list(period = lambda))
  context <- list(
    input = function(name) values[[name]],
    arg = function(name) if (identical(name, "base_year")) "first" else NULL
  )
  result <- e$wlv_indicator_basket_zero_collector_spec()$run(context)$outputs

  expect_true(all(result$basket_zero == 1995))
  expect_identical(as.vector(result$lambda_zero), c(1, 2))
})

test_that("native country sums preserve an all-missing country", {
  e <- native_matrix_shape_environment
  value <- array(
    NA_real_,
    dim = c(2L, 2L, 2L),
    dimnames = list(
      year = c("2000", "2001"),
      sector = c("S1", "S2"),
      country = c("USA", "ROW")
    )
  )
  value[, , "USA"] <- matrix(c(1, 2, 3, 4), nrow = 2L)
  lists <- list(
    years = c("2000", "2001"),
    sectors = c("S1", "S2"),
    countries = c("USA", "ROW")
  )
  result <- e$wlv_native_sum_country_and_world(value, lists)

  expect_true(all(is.na(result[, "ROW"])))
  expect_identical(result[, "WWW"], result[, "USA"])
})
