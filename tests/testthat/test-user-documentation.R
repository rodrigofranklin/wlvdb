wlv_doc_blocks <- function(lines, language = NULL) {
  starts <- grep("^```[a-z]+$", lines)
  blocks <- lapply(starts, function(start) {
    end <- which(seq_along(lines) > start & lines == "```")[[1L]]
    list(language = sub("^```", "", lines[[start]]), text = lines[seq.int(start + 1L, end - 1L)])
  })
  if (is.null(language)) blocks else Filter(function(x) x$language %in% language, blocks)
}

test_that("beginner documentation stays bilingual and its examples parse", {
  pairs <- list(
    c("README-PT.md", "README.md"),
    c("docs/guide-pt.md", "docs/guide-en.md"),
    c("docs/results-dictionary-pt.md", "docs/results-dictionary-en.md")
  )
  revision <- "<!-- documentation-revision: wiod-consolidation-v1 -->"
  for (pair in pairs) {
    documents <- lapply(file.path(wlv_test_root, pair), readLines, encoding = "UTF-8")
    for (i in seq_along(documents)) {
      expect_true(revision %in% documents[[i]], info = pair[[i]])
      expect_true(any(grepl(basename(pair[[3L - i]]), documents[[i]], fixed = TRUE)), info = pair[[i]])
      expect_false(any(grepl("\ufffd", documents[[i]], fixed = TRUE)), info = pair[[i]])
    }
    expect_identical(wlv_doc_blocks(documents[[1L]]), wlv_doc_blocks(documents[[2L]]), info = paste(pair, collapse = " / "))
    for (block in wlv_doc_blocks(documents[[1L]], "r")) {
      expect_no_error(parse(text = block$text))
    }
  }
})

test_that("the bilingual dictionary covers the executed indicator contracts exactly", {
  renderer <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "scripts", "render_results_dictionary.R"), renderer)
  for (language in c("pt", "en")) {
    expected <- enc2utf8(renderer$wlv_render_results_dictionary(wlv_test_root, language))
    actual <- readLines(file.path(wlv_test_root, "docs", paste0("results-dictionary-", language, ".md")), encoding = "UTF-8")
    expect_identical(actual, expected)
  }
})

test_that("beginner guide local links and anchors resolve", {
  documents <- c("README.md", "README-PT.md", "docs/guide-pt.md", "docs/guide-en.md",
    "docs/results-dictionary-pt.md", "docs/results-dictionary-en.md", "docs/documentation-sync.md")
  slug <- function(value) {
    value <- tolower(sub("^#+ +", "", value))
    value <- gsub("[^\\p{L}\\p{N}_ -]", "", value, perl = TRUE)
    gsub(" ", "-", value, fixed = TRUE)
  }
  for (document in documents) {
    path <- file.path(wlv_test_root, document)
    lines <- readLines(path, encoding = "UTF-8")
    links <- unlist(regmatches(lines, gregexpr("\\[[^]]+\\]\\([^)]+\\)", lines)))
    destinations <- sub("^.*\\]\\(([^)]+)\\)$", "\\1", links)
    for (destination in destinations[!grepl("^[a-z]+://", destinations)]) {
      parts <- strsplit(destination, "#", fixed = TRUE)[[1L]]
      target <- if (!nzchar(parts[[1L]])) path else file.path(dirname(path), parts[[1L]])
      expect_true(file.exists(target), info = paste(document, destination))
      if (file.exists(target) && length(parts) == 2L) {
        headings <- grep("^#+ ", readLines(target, encoding = "UTF-8"), value = TRUE)
        expect_true(parts[[2L]] %in% slug(headings), info = paste(document, destination))
      }
    }
  }
})

test_that("guide examples use actual CLI options and public API arguments", {
  guide <- readLines(file.path(wlv_test_root, "docs", "guide-en.md"), encoding = "UTF-8")
  parser <- new.env(parent = baseenv())
  definitions <- parse(file.path(wlv_test_root, "scripts", "run_wlv.R"))
  eval(definitions[1:2], parser)
  shell <- unlist(lapply(wlv_doc_blocks(guide, "sh"), `[[`, "text"))
  commands <- grep("^Rscript --vanilla scripts/run_wlv[.]R", shell, value = TRUE)
  for (command in commands) {
    args <- strsplit(sub("^Rscript --vanilla scripts/run_wlv[.]R ?", "", command), " ", fixed = TRUE)[[1L]]
    parsed <- parser$parse_cli(args)
    expect_true(all(parsed$methods %in% c("wiodr13", "wiodr16")))
  }
  api <- new.env(parent = baseenv())
  sys.source(file.path(wlv_test_root, "R", "main.R"), api)
  blocks <- wlv_doc_blocks(guide, "r")
  eval(parse(text = blocks[[1L]]$text), new.env(parent = baseenv()))
  for (block in blocks) {
    expressions <- parse(text = block$text)
    for (call in expressions) {
      if (!is.call(call) || !is.call(call[[1L]]) || !identical(call[[1L]][[1L]], as.name("$"))) next
      name <- as.character(call[[1L]][[3L]])
      if (name %in% c("prepare_wlv", "get_wlv", "recalc_wlv")) {
        expect_no_error(match.call(definition = api[[name]], call = call))
      }
    }
  }
})
