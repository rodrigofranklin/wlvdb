wlv_test_root <- normalizePath(
  file.path(testthat::test_path(), "..", ".."),
  mustWork = TRUE
)

wlv_test_load_runtime <- function(root = wlv_test_root) {
  bootstrap <- new.env(parent = baseenv())
  sys.source(file.path(root, "scripts", "runtime_bootstrap.R"), envir = bootstrap)
  bootstrap$wlv_load_runtime(root)
}
