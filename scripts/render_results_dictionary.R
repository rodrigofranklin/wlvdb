# ASCII entry point: Rscript/sys.source may parse files in the native locale.
# Load the readable bilingual definitions explicitly as UTF-8 instead of
# converting their literals through that locale. Economic output is unchanged.
wlv_render_results_dictionary <- function(root, language = "en") {
  definitions <- new.env(parent = baseenv())
  eval(parse(
    file = file.path(root, "scripts", "lib", "results_dictionary.R"),
    encoding = "UTF-8", keep.source = FALSE
  ), envir = definitions)
  definitions$wlv_render_results_dictionary(root, language)
}

if (sys.nframe() == 0L) {
  argument <- grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
  root <- dirname(dirname(normalizePath(sub("^--file=", "", argument))))
  check <- "--check" %in% commandArgs(TRUE)
  for (language in c("pt", "en")) {
    path <- file.path(root, "docs", paste0("results-dictionary-", language, ".md"))
    expected <- enc2utf8(wlv_render_results_dictionary(root, language))
    if (check) {
      if (!file.exists(path) || !identical(readLines(path, encoding = "UTF-8"), expected)) {
        stop("Results dictionary is out of sync: ", path, call. = FALSE)
      }
    } else {
      writeLines(expected, path, useBytes = TRUE)
    }
  }
  cat(if (check) "Bilingual results dictionaries are synchronized.\n" else "Bilingual results dictionaries generated.\n")
}
