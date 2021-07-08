####
#
# Calcula os dados ausentes para a China:
# - Pessoas assalariadas
# - Horas assalariadas
# - Horas ocupadas (apenas para nov16)
#
####

# Apenas para a versão Nov16: Carrega dados sobre jornada média da China.
# Esses dados foram colhidos da versão July14, sendo o último ano (2009) 
# extendido para os demais (2010-2014).
if (versao == "Nov16") {
  jornada_media_china <- t(read.csv2(
    file = paste0(getwd(),"/sourcedata/Nov16/China H_EMPE-EMPE.csv"))[,3:17])
  sea_setores[,"horas_ocupadas",,"CHN"] <- 
    sea_setores[,"pessoas_ocupadas",,"CHN"] * jornada_media_china * 1000
  rm(jornada_media_china)
}

# Carrega dados sobre emprego provenientes de fonte externa
# was_w => Wage and salaried workers como percentual da população ocupada
was_w_china <-  as.numeric(read_xlsx(paste0(getwd(),"/sourcedata/china/was_w.xlsx"), 
                          sheet = "DATA", col_names = TRUE)[,lista_anos]/100)

sea_setores[,"assalariados",,"CHN"] <- 
  sea_setores[,"pessoas_ocupadas",,"CHN"] * was_w_china

sea_setores[,"horas_assalariadas",,"CHN"] <- 
  sea_setores[,"horas_ocupadas",,"CHN"] * was_w_china

# Limpa todas as variáveis que não serão mais utilizadas
rm(was_w_china)
