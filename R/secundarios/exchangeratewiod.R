source("R/seaimport.R")

####OBTENER EL TIPO DE CAMBIO UTILIZADO POR EL EQUIPO DE WIOD
##### COMPARANDO EL VALOR AGREGADO EN MONEDA LOCAL Y EL VALOR AGREGADO EN DÓLARES DISPONIBLE EN LAS WIOT
#http://www.wiod.org/protected3/data13/update_sep12/EXR_WIOD_Sep12.xlsx




#va en moneda local
vavector <- sea[Variable == "VA" & Code != "TOT"]


paiseswiod <- countrycode(unique(sealegend$Name[1:40]), origin = "country.name",destination = "iso2c")



#### A FUTURO COMPARAR CON EL TIPO DE CAMBIO MEDIO DEL FMI
# eratevector <- imf_data('IFS','ENDA_XDC_USD_RATE', start = 1995, end = 2011, country = paiseswiod )
#   #ENDA_XDC_USD_RATE
# 
# #convertir a iso3c - base de la wiod
# eratevector$Country <- countrycode(eratevector$iso2c, origin = "iso2c", destination = "iso3c")
# 
# eratevector$year <- as.integer(eratevector$year)


vavector <- vavector %>% left_join(eratevector[,2:4], by = c("Country", "year"))

#mantener en millon de dólares
vavector$vausd <- vavector$value/vavector$ENDA_XDC_USD_RATE
