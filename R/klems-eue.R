#Download and import main EU KLEMS database on capital stocks

###R format available euklems data on capital stock by sector by country by year

kkurl <- "http://euklems.eu/bulk/Statistical_Capital.rds"
klemsk <- tempfile()
download.file(kkurl, klemsk)

klemsk <- readRDS(klemsk)



