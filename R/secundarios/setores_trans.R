#Junta info setores wiod
library(googlesheets4)
setores_trans <- read_csv2("sourcedata/July14/setores.csv")

setores_trans <- bind_rows(setores_trans,read_csv2("sourcedata/Nov16/setores.csv",col_types = "cccdcc"))


setores_trans <- setores_trans%>%select(Code,sector=Setor)

setores_trans <- setores_trans[!duplicated(setores_trans$Code),]

setores_trans$pt <- '=googletranslate(B:B;"en";"pt")'

setores_trans$es <- '=googletranslate(B:B;"en";"es")'

setores_trans$fr <- '=googletranslate(B:B;"en";"fr")'

setores_trans <- setores_trans %>%mutate(across(3:5,.fns=gs4_formula))

gs4_create("setores_trans",sheets = setores_trans)

setores_trans <- gs4_get(gs4_find("setores_trans")) %>% read_sheet()

write_csv2(setores_trans,"R/utils/painel/dados/setores_t.csv")
