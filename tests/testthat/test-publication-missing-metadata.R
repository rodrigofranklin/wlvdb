test_that("panel CSV reading restores absent metadata written by publication", {
  runtime <- wlv_test_load_runtime()
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  original <- data.frame(
    cod_label = c("absent", "empty", "legacy", "quoted", "zero"),
    label = c(NA_character_, "", "NA", "Compensation; output", "0"),
    stringsAsFactors = FALSE
  )
  runtime$wlv_write_result_csv(original, path)
  hash <- runtime$wlv_publication_file_sha256(path)
  observed <- runtime$wlv_read_panel_result_csv(
    path, c("cod_label", "label"), expected_sha256 = hash
  )
  expect_identical(observed$cod_label, original$cod_label)
  expect_identical(observed$label,
    c(NA_character_, NA_character_, NA_character_, original$label[4:5]))
  expect_identical(runtime$wlv_publication_file_sha256(path), hash)
  expect_identical(original$label[1:3], c(NA_character_, "", "NA"))
  expect_error(runtime$wlv_read_panel_result_csv(
    path, c("cod_label", "label"), expected_sha256 = strrep("0", 64)
  ), "SHA-256 mismatch", fixed = TRUE)
})

test_that("release metadata fills omissions identically in either method order", {
  runtime <- wlv_test_load_runtime()
  paths <- c(tempfile(fileext = ".csv"), tempfile(fileext = ".csv"))
  on.exit(unlink(paths), add = TRUE)
  first <- data.frame(
    value = c("go_price.r.id", "hours_worked.emp.s.hr", "unfilled"),
    groups = c("", "Labour", NA_character_),
    type = c(NA_character_, "hours", ""),
    reverted = c(NA, FALSE, NA), stringsAsFactors = FALSE
  )
  second <- data.frame(
    value = c("go_price.r.id", "hours_worked.emp.s.hr", "unfilled"),
    groups = c("Prices", "", NA_character_),
    type = c("index", NA_character_, ""),
    reverted = c(FALSE, NA, NA), stringsAsFactors = FALSE
  )
  runtime$wlv_write_result_csv(first, paths[[1L]])
  runtime$wlv_write_result_csv(second, paths[[2L]])
  hashes <- vapply(paths, runtime$wlv_publication_file_sha256, character(1L))
  expected <- first
  expected$groups <- c("Prices", "Labour", NA_character_)
  expected$type <- c("index", "hours", NA_character_)
  expected$reverted <- c(FALSE, FALSE, NA)
  for (order in list(1:2, 2:1)) {
    observed <- runtime$wlv_merge_panel_result_tables(
      paths[order], "value", names(first), expected_sha256 = hashes[order]
    )
    expect_identical(observed, expected)
  }
  expect_identical(vapply(paths, runtime$wlv_publication_file_sha256,
    character(1L)), hashes)
})

test_that("shared labels coalesce legacy NA and empty CSV fields", {
  runtime <- wlv_test_load_runtime()
  paths <- c(tempfile(fileext = ".csv"), tempfile(fileext = ".csv"))
  on.exit(unlink(paths), add = TRUE)
  first <- data.frame(cod_label = c("desc.go_price.r.id", "other"),
    label = c(NA_character_, "NA"), stringsAsFactors = FALSE)
  second <- data.frame(cod_label = first$cod_label,
    label = c("Gross output price index", ""), stringsAsFactors = FALSE)
  runtime$wlv_write_result_csv(first, paths[[1L]])
  runtime$wlv_write_result_csv(second, paths[[2L]])
  expected <- second
  expected$label[[2L]] <- NA_character_
  for (order in list(1:2, 2:1)) {
    expect_identical(runtime$wlv_merge_panel_result_tables(
      paths[order], "cod_label", names(first)
    ), expected)
  }
})

test_that("release metadata still rejects distinct nonempty values", {
  runtime <- wlv_test_load_runtime()
  paths <- c(tempfile(fileext = ".csv"), tempfile(fileext = ".csv"))
  on.exit(unlink(paths), add = TRUE)
  examples <- list(
    label = c("Price", "Other price"), groups = c("Prices", "Labour"),
    type = c("index", "usd"), reverted = c(TRUE, FALSE)
  )
  for (field in names(examples)) {
    for (index in 1:2) {
      table <- data.frame(value = "go_price.r.id", stringsAsFactors = FALSE)
      table[[field]] <- examples[[field]][[index]]
      runtime$wlv_write_result_csv(table, paths[[index]])
    }
    for (order in list(1:2, 2:1)) {
      expect_error(runtime$wlv_merge_panel_result_tables(
        paths[order], "value", c("value", field)
      ), paste0("Conflicting panel metadata for `go_price.r.id` field `",
        field, "`."), fixed = TRUE)
    }
  }
})

test_that("release metadata rejects missing keys instead of dropping their rows", {
  runtime <- wlv_test_load_runtime()
  paths <- c(tempfile(fileext = ".csv"), tempfile(fileext = ".csv"))
  on.exit(unlink(paths), add = TRUE)
  for (key in c("cod_label", "value")) {
    columns <- c(key, "label")
    valid <- data.frame(code = "valid", label = "Known", stringsAsFactors = FALSE)
    names(valid) <- columns
    runtime$wlv_write_result_csv(valid, paths[[1L]])
    for (absent in c(NA_character_, "", "NA", " ")) {
      invalid <- valid[c(1L, 1L), , drop = FALSE]
      invalid[[key]][[2L]] <- absent
      runtime$wlv_write_result_csv(invalid, paths[[2L]])
      for (order in list(1:2, 2:1)) {
        expect_error(runtime$wlv_merge_panel_result_tables(
          paths[order], key, columns
        ), paste0("Panel metadata key `", key, "` must not be missing or empty."),
          fixed = TRUE)
      }
    }
  }
})
