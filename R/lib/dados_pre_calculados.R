# Carrega dados anuais pré-calculados

print(paste0("Carregando dados pre-calculados do ano ",as.character(ano)))

m_t <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/wiod_horas_",as.character(ano), " - ", versao_resultado, ".rds"))
k_composicao <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/k_composicao_",as.character(ano), " - ", versao_resultado, ".rds"))
m_depreciacao <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/m_depreciacao_",as.character(ano), " - ", versao_resultado, ".rds"))
sea <- readRDS(paste0(getwd(),"/resultados/",versao_resultado,"/socioeconomicas_",as.character(ano), " - ", versao_resultado, ".rds"))

print("Fim da leitura")