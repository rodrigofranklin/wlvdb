# WIOD13 price levels are consumed by the stage-4 basket calculations before
# both published indices are rebased to 2000. Keeping this checkpoint outside
# compensation modules makes selective recalculation deterministic.
basket_current <- sea_sectors[, "basket_price.r.pc", , ]
basket_base <- sea_sectors["2000", "basket_price.r.pc", , ] %>%
  rep(times = nums$years) %>%
  newDim(c(nums$sectors, nums$countries, nums$years)) %>%
  aperm(c(3, 1, 2))
dimnames(basket_base) <- dimnames(basket_current)

go_price_current <- sea_sectors[, "go_price.r.id", , ]
go_price_base <- sea_sectors["2000", "go_price.r.id", , ] %>%
  rep(times = nums$years) %>%
  newDim(c(nums$sectors, nums$countries, nums$years)) %>%
  aperm(c(3, 1, 2))
dimnames(go_price_base) <- dimnames(go_price_current)

if (exists("wlv_contract_runtime", inherits = FALSE)) {
  sea_sectors[, "basket_price.r.pc", , ] <- wlv_ratio_runtime(
    wlv_contract_runtime,
    basket_current,
    basket_base,
    zero = "not_applicable",
    artifact = "sea_sectors",
    indicator = "basket_price.r.pc",
    checkpoint = "after_price_normalization",
    stage = 4L,
    module = "wiodr13/normalize_price_indices.R",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
  sea_sectors[, "go_price.r.id", , ] <- wlv_ratio_runtime(
    wlv_contract_runtime,
    go_price_current,
    go_price_base,
    zero = "not_applicable",
    artifact = "sea_sectors",
    indicator = "go_price.r.id",
    checkpoint = "after_price_normalization",
    stage = 4L,
    module = "wiodr13/normalize_price_indices.R",
    axes = c(year = 1L, sector = 2L, country = 3L)
  )
} else {
  sea_sectors[, "basket_price.r.pc", , ] <- basket_current / basket_base
  sea_sectors[, "go_price.r.id", , ] <- go_price_current / go_price_base
}

rm(basket_current, basket_base, go_price_current, go_price_base)
