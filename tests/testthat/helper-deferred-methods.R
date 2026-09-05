# Retained scientific definitions may be exercised by isolated unit tests.
# This changes only the supplied in-memory catalog, never the public catalog.
wlv_test_enable_deferred_methods <- function(catalog, methods) {
  stopifnot(
    inherits(catalog, "wlv_catalog"), is.character(methods),
    length(methods) > 0L, !anyNA(methods), !anyDuplicated(methods),
    all(methods %in% catalog$methods$method)
  )
  selected <- match(methods, catalog$methods$method)
  stopifnot(all(catalog$methods$status[selected] != "disabled"))
  catalog$methods$can_calculate[selected] <- TRUE
  catalog$methods$can_recalculate[selected] <- TRUE
  catalog
}
