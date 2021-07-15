library(readODS)
library(googlesheets4)

varst <- read_ods("R/utils/painel/dados/vars.ods")

varst$pt <- '=googletranslate(C:C;"en";"pt")'
varst$es <- '=googletranslate(C:C;"en";"es")'
varst$fr <- '=googletranslate(C:C;"en";"fr")'



varst <- varst%>%mutate(across(4:6,.fns = gs4_formula))

gs4_create("vars_trans",sheets = varst)

varst <- gs4_get(gs4_find("vars_trans")) %>% read_sheet()

write_csv2(varst,"R/utils/painel/dados/vars.csv")
