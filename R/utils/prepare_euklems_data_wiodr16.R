# Compatibility entrypoint retained for callers of the former duplicated
# WIOD16 preparer. All EU KLEMS preparation now lives in
# `R/utils/prepare_euklems_data.R` and receives its required period explicitly.

wlv_prepare_euklems_wiodr16_compat <- function(target = parent.frame()) {
  had_years <- exists("wlv_euklems_years", envir = target, inherits = FALSE)
  previous_years <- if (had_years) {
    get("wlv_euklems_years", envir = target, inherits = FALSE)
  } else {
    NULL
  }
  assign("wlv_euklems_years", 2000:2015, envir = target)
  on.exit({
    if (had_years) {
      assign("wlv_euklems_years", previous_years, envir = target)
    } else if (exists("wlv_euklems_years", envir = target, inherits = FALSE)) {
      rm("wlv_euklems_years", envir = target)
    }
  }, add = TRUE)

  sys.source("R/utils/prepare_euklems_data.R", envir = target)
}

message(
  "`prepare_euklems_data_wiodr16.R` is deprecated; ",
  "using the shared EU KLEMS preparer for 2000-2015."
)
wlv_prepare_euklems_wiodr16_compat(environment())
rm(wlv_prepare_euklems_wiodr16_compat)
