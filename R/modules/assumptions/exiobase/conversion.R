# Converte os dados do Exiobase para USD

# Converte os dados da fonte
sea_source[,-(10:21),,] <- 
  sea_source[,-(10:21),,] *
  rep(sea_sectors[,"exchange.r.us",,], each = 10)

# Converte os dados já calculados
# Antes, salva as taxas de câmbio para recuperar depois
euro <- sea_sectors[,"exchange.r.us",,]
var_in_usd <- grep(".us", sea_variables$names, fixed = TRUE)

sea_sectors[,var_in_usd,,] <- 
  sea_sectors[,var_in_usd,,] *
  rep(euro, each = length(var_in_usd))

sea_sectors[,"exchange.r.us",,] <- euro
