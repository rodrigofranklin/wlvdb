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

if (file.exists("results/indicators_en.csv")) {
  temp_indicators <- read.csv2("results/indicators_en.csv")
  
  # preserve old labels for which we currently do not have information 
  indicators_en[indicators_en$label |> is.na(), "label"] <- 
    temp_indicators$label[
      match(indicators_en$cod_label[indicators_en$label |> is.na()],
            temp_indicators$cod_label)]
  
  # merge labels
  temp_indicators <- 
    temp_indicators[
      temp_indicators$cod_label %in% indicators_en$cod_label |> not(),]
  
  indicators_en <- rbind(temp_indicators, indicators_en)
}

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

if (file.exists("results/meta_indicators.csv")) {
  temp_meta <- read.csv2("results/meta_indicators.csv")
  if (!all(c("value", "groups", "type", "reverted") %in% names(temp_meta))) {
    stop(
      "Legacy panel metadata lacks its required identity columns.",
      call. = FALSE
    )
  }
  temp_meta <- temp_meta[, c(
    "value", "groups", "type", "reverted"
  ), drop = FALSE]
  
  # preserve old metadata for which we currently do not have information 
  meta_indicators_panel[meta_indicators_panel$groups |> is.na(), "groups"] <- 
    temp_meta$groups[
      match(meta_indicators_panel$value[meta_indicators_panel$groups |> is.na()],
            temp_meta$value)]

  meta_indicators_panel[meta_indicators_panel$type |> is.na(), "type"] <- 
    temp_meta$type[
      match(meta_indicators_panel$value[meta_indicators_panel$type |> is.na()],
            temp_meta$value)]

  meta_indicators_panel[meta_indicators_panel$reverted |> is.na(), "reverted"] <- 
    temp_meta$reverted[
      match(meta_indicators_panel$value[meta_indicators_panel$reverted |> is.na()],
            temp_meta$value)]
  
  # merge labels
  temp_meta <- temp_meta[
    temp_meta$value %in% meta_indicators_panel$value |> not(),
    names(meta_indicators_panel),
    drop = FALSE
  ]
  
  meta_indicators_panel <- rbind(temp_meta, meta_indicators_panel)
}

wlv_pending_indicators_en <- indicators_en
wlv_pending_meta_indicators <- meta_indicators_panel
wlv_write_method_result_metadata(
  wlv_result_dir,
  wlv_method_result_metadata(
    parameters = parameters,
    assumptions = assumptions,
    matrices = matrices,
    solutions = sea_variables,
    sectors = sectors,
    meta_indicators = meta_indicators,
    extra_csv = if (
      exists("wlv_scientific_diagnostics", inherits = FALSE)
    ) {
      wlv_scientific_diagnostics
    } else {
      list()
    }
  )
)
