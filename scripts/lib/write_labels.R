# Writing meta_data for panel

# create indicators_en file with labels for indicators, descriptions, 
# observations and groups
indicators_names <- meta_indicators[,c("code","name")]

descriptions <- meta_indicators[,c("code","description")]
descriptions$code <- paste0("desc.", descriptions$code)

observations <- meta_indicators[,c("code","observation")]
observations$code <- paste0("obs.",parameters$code,".", observations$code)
observations <- observations[observations$observation |> is.na() |> not(),]

groups <- NULL
groups$label <- meta_indicators$group |> unique()
groups$code <- paste0("group.",groups$label)
groups <- groups |> as.data.frame()
groups <- groups[groups$label |> is.na() |> not(),c(2,1)]

names(indicators_names) = names(descriptions) = names(observations) = 
  names(groups) <- c("cod_label","label")

indicators_en <- rbind(indicators_names, descriptions, observations, groups)

# Keep canonical storage and presentation semantics in the method-specific
# metadata. The global panel table is shared by methods whose display rules can
# differ for the same indicator code, so it retains its legacy four-column
# schema.
meta_indicators <- wlv_complete_indicator_metadata(
  meta_indicators,
  units = if (exists("wlv_unit_definitions", inherits = FALSE)) {
    wlv_unit_definitions
  } else {
    NULL
  },
  warn_legacy = !exists("wlv_unit_definitions", inherits = FALSE)
)
meta_indicators_panel <- meta_indicators[, c(
  "code", "group", "type", "reverted"
)]
names(meta_indicators_panel) <- c(
  "value", "groups", "type", "reverted"
)

wlv_pending_indicators_en <- indicators_en
wlv_pending_meta_indicators <- meta_indicators_panel
wlv_panel_result_metadata <- list(
  `_panel_indicators.csv` = indicators_en,
  `_panel_meta_indicators.csv` = meta_indicators_panel
)
wlv_write_method_result_metadata(
  wlv_result_dir,
  wlv_method_result_metadata(
    parameters = parameters,
    assumptions = assumptions,
    matrices = matrices,
    solutions = sea_variables,
    sectors = sectors,
    meta_indicators = meta_indicators,
    extra_csv = c(
      if (exists("wlv_scientific_diagnostics", inherits = FALSE)) {
        wlv_scientific_diagnostics
      } else {
        list()
      },
      wlv_panel_result_metadata
    )
  )
)
