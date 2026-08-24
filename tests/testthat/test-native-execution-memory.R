test_that("complete IO periods reuse the assembled artifact", {
  runtime <- wlv_test_load_runtime()
  years <- c("2000", "2001", "2002")
  value <- array(
    as.double(seq_len(3L * 2L * 2L * 2L)),
    dim = c(3L, 2L, 2L, 2L),
    dimnames = list(
      year = years,
      variable = c("a", "b"),
      input = c("i1", "i2"),
      output = c("o1", "o2")
    )
  )

  skip_if_not(capabilities("profmem"))
  original_address <- tracemem(value)
  on.exit(untracemem(value), add = TRUE)
  complete <- runtime$wlv_native_select_io_years(value, years)
  expect_identical(tracemem(complete), original_address)

  subset <- runtime$wlv_native_select_io_years(value, years[c(1L, 3L)])
  expect_false(identical(tracemem(subset), original_address))
  expect_identical(
    subset,
    value[years[c(1L, 3L)], , , , drop = FALSE]
  )
})
