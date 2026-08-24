wlv_paper_4_spec <- function() {
  wlv_unsupported_paper_spec(
    id = 4L,
    title = "Health and dependency",
    reason = paste(
      "its implementation depends on obsolete result shapes and a live,",
      "unversioned external country table; restoring it requires a separately",
      "reviewed scientific migration"
    )
  )
}
