# Reuse the frozen comparator, with only the strict checkpoint envelope fix.
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 13L) stop("Expected upstream comparator and its 12 arguments.")
upstream <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
wrapper <- normalizePath(sub("^--file=", "", grep("^--file=",
  commandArgs(FALSE), value = TRUE)[[1L]]), winslash = "/", mustWork = TRUE)
auth <- file.path(dirname(wrapper), "issue13-main-preparation-auth.R")
hash <- function(path) {
  connection <- file(path, "rb")
  on.exit(close(connection))
  paste0(tolower(as.character(openssl::sha256(connection))), collapse = "")
}
stopifnot(identical(hash(upstream),
  "c7205469ab13024a62cb881bc385b5eb7dfded262f0b5e5894e1c656e40d99e2"))
upstream_auth <- file.path(dirname(upstream), "issue13-preparation-auth-lib.R")
stopifnot(identical(hash(upstream_auth),
  "887f7bacfe7582f026861cdb1023a648bfb6757a652f6f87eeac49f333674369"))
namespace <- new.env(parent = globalenv())
namespace$commandArgs <- local({
  cli <- arguments[-1L]
  file_arg <- paste0("--file=", upstream)
  function(trailingOnly = FALSE) if (trailingOnly) cli else file_arg
})
sys.source(auth, envir = environment())
installed <- FALSE
for (expression in parse(upstream, keep.source = FALSE)) {
  eval(expression, envir = namespace)
  if (!installed && exists("wlv_gate_prep_authenticate_execution", namespace,
      inherits = FALSE)) {
    wlv13_main_install_preparation_auth(namespace)
    installed <- TRUE
  }
  if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
      identical(expression[[2L]], as.name("request"))) {
    stopifnot(installed)
    namespace$request$upstream_producer_path <- upstream
    namespace$request$upstream_producer_sha256 <- hash(upstream)
    namespace$request$upstream_authentication_path <- upstream_auth
    namespace$request$upstream_authentication_sha256 <- hash(upstream_auth)
    namespace$request$producer_path <- wrapper
    namespace$request$producer_sha256 <- hash(wrapper)
    namespace$request$authentication_revision_path <- auth
    namespace$request$authentication_revision_sha256 <- hash(auth)
  }
}
