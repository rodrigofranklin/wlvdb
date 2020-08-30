#Carrega a matriz insumo-produto multirregional
if (versao == "July14") {
  m_wio <- readRDS(paste0(getwd(),"/sourcedata/",versao,"/WIOT_",as.character(ano),".rds"))
  lin_produto_total <- nrow(m_wio)
  lin_va <- 1441
} else {
  load(paste0(getwd(),"/sourcedata/Nov16/WIOT",as.character(ano),"_October16_ROW.RData"))
  m_wio <- as.matrix(wiot[,6:ncol(wiot)])
  lin_produto_total <- which(wiot[,'IndustryCode'] == 'GO')
  lin_va <- which(wiot[,'IndustryCode'] == 'VA')
}

tamanho_completo <- ncol(m_wio)