wlv_analysis_example_env <- function() {
  env <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "scripts", "examples", "analysis_review.R"), env)
  env
}

wlv_analysis_example_fixture <- function() {
  indicator <- "surplus_value.empe_p.r.pc"
  countries <- array(c(1.5, 1.6, NA_real_, 2, NA_real_),
    dim = c(5L, 1L, 1L),
    dimnames = list(year = c("1995", "1996", "1997", "2008", "2009"),
                    indicator = indicator, country = "BRA"))
  units <- data.frame(indicator = rep(indicator, 2L),
    canonical_unit = "ratio", display_unit = "percent", display_multiplier = 100,
    stringsAsFactors = FALSE)
  states <- data.frame(artifact = "sea_countries", indicator = indicator,
    year = c(1997, 2009), country = "BRA",
    state = c("source_missing", "not_applicable"), stringsAsFactors = FALSE)
  anomalies <- data.frame(artifact = "sea_sectors", indicator = "capital_stock.s.us",
    year = c("1995", "1996", ""), country = c("CHN", "BRA", "ROW"),
    action = "synthetic_review_event", stringsAsFactors = FALSE)
  list(countries = countries, units = units, states = states, anomalies = anomalies,
       method = "wiodr13", country = "BRA", indicator = indicator,
       years = 1995:1997)
}

test_that("analysis review preserves values, states, coverage and pending decisions", {
  env <- wlv_analysis_example_env()
  fixture <- wlv_analysis_example_fixture()
  original <- fixture$countries
  report <- do.call(env$wlv_example_review_series, fixture)
  expect_identical(fixture$countries, original)
  expect_equal(report$series$display_value, c(150, 160, NA, 200, NA))
  expect_equal(report$series$state,
    c("finite", "finite", "source_missing", "finite", "not_applicable"))
  expect_equal(report$series$in_requested_period, c(TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_equal(report$series$wiodr13_coverage_alert, c(FALSE, FALSE, FALSE, TRUE, TRUE))
  expect_equal(report$series$decision, c("pending", "pending", "exclude", "exclude", "exclude"))
  expect_equal(report$series$global_year_events, c(2L, 2L, 1L, 1L, 1L))
  expect_equal(report$series$selected_country_events, c(0L, 1L, 0L, 0L, 0L))
  expect_equal(nrow(report$anomalies), 3L)
  expect_equal(nrow(report$series), 5L)
})

test_that("analysis review rejects unsupported or inconsistent inputs", {
  env <- wlv_analysis_example_env()
  fixture <- wlv_analysis_example_fixture()
  bad <- fixture; bad$states <- bad$states[0, , drop = FALSE]
  expect_error(do.call(env$wlv_example_review_series, bad), "Every selected NA")
  bad <- fixture; bad$states <- rbind(bad$states, bad$states[1L, ])
  expect_error(do.call(env$wlv_example_review_series, bad), "Ambiguous")
  bad <- fixture; bad$countries[3L, 1L, 1L] <- 0
  expect_error(do.call(env$wlv_example_review_series, bad), "finite cells")
  bad <- fixture; bad$states$state[1L] <- "uncomputed"
  expect_error(do.call(env$wlv_example_review_series, bad), "invalid state")
  bad <- fixture; bad$countries[1L, 1L, 1L] <- NaN
  expect_error(do.call(env$wlv_example_review_series, bad), "NaN")
  bad <- fixture; bad$countries[1L, 1L, 1L] <- Inf
  expect_error(do.call(env$wlv_example_review_series, bad), "infinity")
  bad <- fixture; bad$units$display_multiplier[2L] <- 1
  expect_error(do.call(env$wlv_example_review_series, bad), "consistent")
  bad <- fixture; bad$country <- "ZZZ"
  expect_error(do.call(env$wlv_example_review_series, bad), "labelled")
  bad <- fixture; bad$years <- 2010
  expect_error(do.call(env$wlv_example_review_series, bad), "present")
  bad <- fixture; bad$years <- c(1995, 1995)
  expect_error(do.call(env$wlv_example_review_series, bad), "distinct")
})

test_that("an empty diagnostic table is distinct from missing semantic states", {
  env <- wlv_analysis_example_env()
  fixture <- wlv_analysis_example_fixture()
  fixture$anomalies <- fixture$anomalies[0, , drop = FALSE]
  report <- do.call(env$wlv_example_review_series, fixture)
  expect_equal(report$series$global_year_events, rep(0L, 5L))
  expect_equal(report$series$decision[1:2], rep("pending", 2L))
  fixture$method <- "wiodr16"
  report <- do.call(env$wlv_example_review_series, fixture)
  expect_false(any(report$series$wiodr13_coverage_alert))
})

test_that("common coverage preserves exclusions and avoids fabricated zero rates", {
  env <- wlv_analysis_example_env()
  result <- env$wlv_example_common_coverage(c(100, 100), c(50, NA_real_))
  expect_equal(result$rate, 1)
  expect_identical(result$included, 1L)
  expect_identical(result$excluded, 2L)
  expect_equal(result$n_complete, 1L)
  expect_equal(result$n_total, 2L)
  expect_true(is.na(env$wlv_example_common_coverage(c(NA_real_), 50)$rate))
  expect_true(is.na(env$wlv_example_common_coverage(0, 0)$rate))
  expect_error(env$wlv_example_common_coverage(Inf, 1), "finite")
  expect_error(env$wlv_example_common_coverage(c(1, 2), 1), "equally sized")
})

test_that("new bilingual workflows have identical code and public access addresses", {
  root <- file.path(wlv_test_root, "docs")
  blocks <- function(path) {
    text <- readLines(path, encoding = "UTF-8")
    starts <- grep("^```[a-z]+$", text)
    lapply(starts, function(start) {
      end <- which(seq_along(text) > start & text == "```")[[1L]]
      list(language = sub("^```", "", text[start]),
           text = text[seq.int(start + 1L, end - 1L)])
    })
  }
  for (name in c("use-results", "indicator-families", "citation")) {
    pt <- file.path(root, paste0(name, "-pt.md"))
    en <- file.path(root, paste0(name, "-en.md"))
    expect_identical(blocks(pt), blocks(en))
    for (block in blocks(pt)) {
      if (block$language == "r") expect_no_error(parse(text = block$text))
    }
  }
  for (language in c("pt", "en")) {
    lines <- readLines(file.path(root, paste0("use-results-", language, ".md")),
                       encoding = "UTF-8")
    expect_true(any(grepl("https://panel.worldlabourvalues.org/", lines, fixed = TRUE)))
    expect_true(any(grepl("http://labcidades.ufes.br/worldlabourvalues/", lines, fixed = TRUE)))
  }
  toy <- Filter(function(x) x$language == "r" &&
    any(grepl("independent_rate <-", x$text, fixed = TRUE)),
    blocks(file.path(root, "use-results-en.md")))
  expect_length(toy, 1L)
  local({
    previous <- getwd()
    on.exit(setwd(previous), add = TRUE)
    setwd(wlv_test_root)
    expect_no_error(capture.output(eval(parse(text = toy[[1L]]$text),
      envir = new.env(parent = baseenv()))))
  })
})
