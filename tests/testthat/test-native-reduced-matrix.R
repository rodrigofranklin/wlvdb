wlv_native_reduced_matrix_fixture <- function() {
  nums <- list(
    years = 3L,
    input = 4L,
    output = 6L,
    countries = 2L,
    sectors = 2L
  )
  filters <- array(
    0,
    dim = c(2L, nums$input, nums$output),
    dimnames = list(
      filter = c("countries", "productive_sectors"),
      input = c("AAA.S1", "AAA.S2", "BBB.S1", "BBB.S2"),
      output = c(
        "AAA.S1", "AAA.S2", "BBB.S1", "BBB.S2", "AAA.c41", "BBB.c41"
      )
    )
  )
  input_countries <- c(1, 1, 2, 2)
  output_countries <- c(1, 1, 2, 2, 1, 2)
  filters["countries", , ] <-
    matrix(rep(output_countries, each = nums$input), nrow = nums$input) +
    matrix(rep(input_countries, times = nums$output), nrow = nums$input) / 1000
  filters["productive_sectors", c(TRUE, FALSE, TRUE, FALSE), ] <- 1

  value <- array(
    as.double(seq_len(nums$years * nums$input * nums$output)),
    dim = c(nums$years, nums$input, nums$output)
  )
  value[1L, 1L, 1L] <- NA_real_
  value[2L, 4L, 6L] <- NaN
  list(value = value, filters = filters, nums = nums)
}

wlv_reference_reduce_country_matrix <- function(
    runtime,
    value,
    filters,
    nums,
    productive) {
  if (productive) {
    value <- value * rep(
      filters["productive_sectors", , ],
      each = nums$years
    )
  }
  grouped <- base::apply(
    runtime$newDim(value, c(nums$years, nums$input, nums$output)),
    1L,
    base::tapply,
    filters["countries", , ],
    base::sum,
    na.rm = TRUE
  )
  base::aperm(grouped, c(2L, 1L)) *
    rep(1 - base::diag(nums$countries), each = nums$years)
}

test_that("cached country groups preserve the historical reduction exactly", {
  runtime <- wlv_test_load_runtime()
  fixture <- wlv_native_reduced_matrix_fixture()

  for (productive in c(FALSE, TRUE)) {
    expected <- wlv_reference_reduce_country_matrix(
      runtime,
      fixture$value,
      fixture$filters,
      fixture$nums,
      productive
    )
    actual <- runtime$wlv_native_reduce_country_matrix(
      fixture$value,
      fixture$filters,
      fixture$nums,
      productive = productive
    )

    expect_identical(actual, expected)
  }
})

test_that("country groups reach every yearly reduction as a precomputed factor", {
  runtime <- wlv_test_load_runtime()
  fixture <- wlv_native_reduced_matrix_fixture()
  observed <- new.env(parent = emptyenv())
  observed$calls <- 0L
  year_apply <- function(X, MARGIN, FUN, ...) {
    dots <- list(...)
    observed$calls <- observed$calls + 1L
    observed$index <- dots[[1L]]
    observed$fun <- FUN
    base::apply(X, MARGIN, FUN, ...)
  }

  actual <- runtime$wlv_native_reduce_country_matrix(
    fixture$value,
    fixture$filters,
    fixture$nums,
    year_apply = year_apply
  )
  expected <- wlv_reference_reduce_country_matrix(
    runtime,
    fixture$value,
    fixture$filters,
    fixture$nums,
    FALSE
  )

  expect_identical(actual, expected)
  expect_identical(observed$calls, 1L)
  expect_identical(observed$fun, base::tapply)
  expect_s3_class(observed$index, "factor")
  expect_identical(
    observed$index,
    base::as.factor(fixture$filters["countries", , ])
  )
})
