# Verifica que uma revisão explicativa preservou todas as expressões R.
# Uso: Rscript --vanilla tests/manual/verify-comment-ast.R BASE OUTPUT FILE...
# BASE: revisão Git ou diretório contendo os arquivos nos caminhos relativos.
# OUTPUT e TMPDIR devem ficar na campanha temp/<id>/ criada pelo gerenciador.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L) {
  stop("Usage: verify-comment-ast.R BASE OUTPUT FILE...", call. = FALSE)
}
baseline <- args[[1L]]
output <- args[[2L]]
files <- args[-c(1L, 2L)]
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
campaign_root <- paste0(root, "/temp/")
assert_campaign_path <- function(path) {
  resolved <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (!startsWith(tolower(resolved), tolower(campaign_root))) {
    stop("Generated files must remain in the repository campaign.", call. = FALSE)
  }
  resolved
}
output <- assert_campaign_path(output)
scratch <- assert_campaign_path(Sys.getenv("TMPDIR"))
if (!dir.exists(scratch) || !dir.exists(dirname(output))) {
  stop("Create the campaign scratch/results directories first.", call. = FALSE)
}
if (any(grepl("(^|/)\\.\\.(/|$)|^[A-Za-z]:|^/", files))) {
  stop("Input files must use repository-relative paths.", call. = FALSE)
}
compare_file <- function(relative) {
  current <- file.path(root, relative)
  staged_base <- NULL
  if (dir.exists(baseline)) {
    before <- file.path(baseline, relative)
  } else {
    staged_base <- tempfile("comment-base-", tmpdir = scratch, fileext = ".R")
    on.exit(unlink(staged_base), add = TRUE)
    status <- system2("git", c("show", shQuote(paste0(baseline, ":", relative))),
      stdout = staged_base)
    if (status != 0L) stop("Cannot read baseline: ", relative, call. = FALSE)
    before <- staged_base
  }
  old_ast <- parse(before, keep.source = FALSE, encoding = "UTF-8")
  new_ast <- parse(current, keep.source = FALSE, encoding = "UTF-8")
  data.frame(
    file = relative,
    expressions = length(new_ast),
    identical_ast = identical(old_ast, new_ast),
    baseline_md5 = unname(tools::md5sum(before)),
    current_md5 = unname(tools::md5sum(current)),
    stringsAsFactors = FALSE
  )
}
result <- do.call(rbind, lapply(files, compare_file))
utils::write.csv(result, output, row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("AST equality: %d/%d files; %d top-level expressions\n",
  sum(result$identical_ast), nrow(result), sum(result$expressions)))
if (!all(result$identical_ast)) {
  stop("Executable expressions differ: ",
    paste(result$file[!result$identical_ast], collapse = ", "), call. = FALSE)
}
