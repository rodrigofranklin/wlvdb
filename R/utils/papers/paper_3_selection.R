wlv_paper_3_spec <- function() {
  wlv_unsupported_paper_spec(
    id = 3L,
    title = "Market/direct-price deviations",
    reason = paste(
      "its implementation consumes obsolete RDS result names and indicator",
      "identifiers that are not part of wlvpanel-output/1.0.0; restoring it",
      "requires a separately reviewed scientific migration"
    )
  )
}
