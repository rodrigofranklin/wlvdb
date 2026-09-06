# Prevent the GitHub rendering failure reported for the methodology pages.
# This is a targeted source guard, not a replacement for viewing rendered math.
# No runtime, source data, network connection or new package is required.
wlv_math_markdown_prose <- function(lines) {
  output <- rep("", length(lines))
  fence <- ""
  fence_length <- 0L
  mathematical_fence <- FALSE
  for (i in seq_along(lines)) {
    line <- lines[[i]]
    if (nzchar(fence)) {
      closing <- paste0("^ {0,3}", fence, "{", fence_length, ",}[ \\t]*$")
      if (grepl(closing, line, perl = TRUE)) {
        fence <- ""
        mathematical_fence <- FALSE
      } else if (mathematical_fence) {
        output[[i]] <- line
      }
      next
    }
    marker <- regmatches(line, regexpr("^ {0,3}(`{3,}|~{3,})", line, perl = TRUE))
    if (length(marker) && nzchar(marker)) {
      marker <- trimws(marker)
      fence <- substr(marker, 1L, 1L)
      fence_length <- nchar(marker)
      language <- trimws(sub("^ {0,3}(`{3,}|~{3,})", "", line, perl = TRUE))
      mathematical_fence <- identical(tolower(language), "math")
      next
    }
    # Preserve GitHub's alternative inline math syntax before stripping code.
    line <- gsub("\\$`([^`]*)`\\$", "$\\1$", line, perl = TRUE)
    output[[i]] <- gsub("(`+)[^`]*\\1", "", line, perl = TRUE)
  }
  output
}

test_that("active Markdown avoids the blocked operatorname macro", {
  # Historical validation records are intentionally not rewritten or scanned.
  documents <- c(
    list.files(wlv_test_root, pattern = "^README.*[.]md$", full.names = TRUE),
    list.files(file.path(wlv_test_root, "docs"), pattern = "[.]md$",
      full.names = TRUE, recursive = FALSE)
  )
  expect_true(length(documents) > 0L)
  blocked <- paste0("\\\\", "operatorname", "(?=[^A-Za-z]|$)")
  for (path in documents) {
    lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
    visible <- wlv_math_markdown_prose(lines)
    hits <- which(grepl(blocked, visible, perl = TRUE))
    expect_identical(hits, integer(), info = paste(path, paste(hits, collapse = ",")))
  }
  for (language in c("pt", "en")) {
    path <- file.path(wlv_test_root, "docs", paste0("methodology-", language, ".md"))
    lines <- readLines(path, encoding = "UTF-8", warn = FALSE)
    expect_true(any(grepl("\\mathrm{diag}", lines, fixed = TRUE)), info = path)
  }
})

test_that("the math guard distinguishes math from literal code examples", {
  macro <- paste0("\\", "operatorname", "{diag}")
  input <- c(
    paste0("$", macro, "(x)$"),
    paste0("`", macro, "`"),
    "```r", paste0('example <- "', macro, '"'), "```",
    "```math", paste0(macro, "(x)"), "```",
    paste0("$`", macro, "(x)`$"),
    paste0("`", macro, "$`")
  )
  visible <- wlv_math_markdown_prose(input)
  expect_identical(which(grepl(macro, visible, fixed = TRUE)), c(1L, 7L, 9L))
})
