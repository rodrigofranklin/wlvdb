# WIOD price levels are consumed by the stage-4 basket calculations before
# published indices are rebased to 2000. A selective recalculation must never
# rewrite an index that the caller did not select.
price_indices <- c("basket_price.r.pc", "go_price.r.id")
selected_price_indices <- if (
  exists("sea_vars", inherits = FALSE) && !is.null(sea_vars)
) {
  intersect(price_indices, sea_vars)
} else {
  price_indices
}

for (price_indicator in selected_price_indices) {
  price_current <- sea_sectors[, price_indicator, , ]
  price_base <- sea_sectors["2000", price_indicator, , ] %>%
    rep(times = nums$years) %>%
    newDim(c(nums$sectors, nums$countries, nums$years)) %>%
    aperm(c(3, 1, 2))
  dimnames(price_base) <- dimnames(price_current)

  normalized_price <- if (
    exists("wlv_contract_runtime", inherits = FALSE)
  ) {
    wlv_ratio_runtime(
      wlv_contract_runtime,
      price_current,
      price_base,
      zero = "not_applicable",
      artifact = "sea_sectors",
      indicator = price_indicator,
      checkpoint = "after_price_normalization",
      stage = 4L,
      module = "wiodr13/normalize_price_indices.R",
      axes = c(year = 1L, sector = 2L, country = 3L)
    )
  } else {
    price_current / price_base
  }
  sea_sectors[, price_indicator, , ] <- normalized_price
}

rm(
  list = intersect(
    c(
      "price_indices", "selected_price_indices", "price_indicator",
      "price_current", "price_base", "normalized_price"
    ),
    ls(envir = environment(), all.names = TRUE)
  ),
  envir = environment()
)
