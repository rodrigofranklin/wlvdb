####
#
# Calcula os dados ausentes para o resto do mundo (RoW):
# - Emprego
# - Horas trabalhadas
# - Salários
# - Capital
#
# VERSÃO DESCONTINUADA: MANTENDO ERRO DE SELEÇÃO DE PAÍSES POBRES PARA VERSÃO 16
# COM O OBJETIVO DE PERMITIR REPRODUÇÃO E COMPARAÇÃO COM AS VERSÕES ANTERIORES
#
####

# Carrega dados sobre emprego provenientes de fonte externa
# emp_row_total => total das pessoas ocupadas ocupadas
# was_w => Wage and salaried workers como percentual da população ocupada
row_emp_dados <- as.data.frame(
  read_xlsx(paste0(getwd(),"/sourcedata/row_emp/emprego_row.xlsx"),
            sheet = "DATA", col_names = T))
emp_row_total <- row_emp_dados[which(row_emp_dados==versao),lista_anos]
was_w_row <- as.numeric(row_emp_dados[which(row_emp_dados=='was_w'),
                                      lista_anos])/100

# posição do RoW em paises_setores (inicial e lista de posições)
pre_row <- num_paises_setores-num_setores
posicao_row <- grep("ROW",lista_paises_setores)

# Cálculo do emprego e das horas trabalhadas
# Para maior detalhe: conferir issue #2 no gitlab
soma_emp_setor <- 
  sea_setores[,"pessoas_ocupadas",,which(lista_paises!="ROW")] %>%
  apply(2, rowSums)
soma_h_emp_setor <- 
  sea_setores[,"horas_ocupadas",, which(lista_paises!="ROW")] %>%
  apply(2, rowSums)
soma_va_setor <- 
  m_io_fonte[,"TOT.VA",1:pre_row] %>%
  apply(1, tapply, linhas$num_setor[1:pre_row], sum) %>%
  t

sea_setores[,"pessoas_ocupadas",,"ROW"] <- 
  as.numeric(emp_row_total) * 
  prop.table(m_io_fonte[,"TOT.VA", posicao_row]*
               soma_emp_setor/soma_va_setor, margin = 1)

sea_setores[,"horas_ocupadas",,"ROW"] <- 
  sea_setores[,"pessoas_ocupadas",,"ROW"] * 
  soma_h_emp_setor/soma_emp_setor

# Cálculo dos dados de assalariamento. Supondo mesma jornada de trabalho que 
# ocupados.
sea_setores[,"assalariados",,"ROW"] <- 
  sea_setores[,"pessoas_ocupadas",,"ROW"] * was_w_row

sea_setores[,"horas_assalariadas",,"ROW"] <- 
  sea_setores[,"horas_ocupadas",,"ROW"] * was_w_row


## Extratos de qualificação para a versão July14
## Calculado como média dos demais países
if (versao == "July14") {
  sea_setores[,"horas_taxa_alta_q",,"ROW"] <- 
    sea_setores[,"horas_taxa_alta_q",,which(lista_paises!="ROW")] %>%
    apply(2, rowMeans)
  
  sea_setores[,"horas_taxa_media_q",,"ROW"] <- 
    sea_setores[,"horas_taxa_media_q",,which(lista_paises!="ROW")] %>%
    apply(2, rowMeans)
  
  sea_setores[,"horas_taxa_baixa_q",,"ROW"] <- 
    1 - sea_setores[,"horas_taxa_alta_q",,"ROW"] - 
    sea_setores[,"horas_taxa_media_q",,"ROW"]
  
  sea_setores[,"remuneracao_taxa_alta_q",,"ROW"] <- 
    sea_setores[,"remuneracao_taxa_alta_q",,which(lista_paises!="ROW")] %>%
    apply(2, rowMeans)
  
  sea_setores[,"remuneracao_taxa_media_q",,"ROW"] <- 
    sea_setores[,"remuneracao_taxa_media_q",,which(lista_paises!="ROW")] %>%
    apply(2, rowMeans)
  
  sea_setores[,"remuneracao_taxa_baixa_q",,"ROW"] <- 
    1 - sea_setores[,"remuneracao_taxa_alta_q",,"ROW"] - 
    sea_setores[,"remuneracao_taxa_media_q",,"ROW"]
}


# Cálculo da compensação do trabalho e da compensação do emprego.
# Considerando mesma relação de distribuição do Valor Agregado

soma_va_paises <- apply(m_io_fonte[,"TOT.VA",1:pre_row], 1, sum)
soma_va_row <- apply(m_io_fonte[,"TOT.VA",posicao_row], 1, sum)
soma_empe_setor <- 
  sea_setores[,"assalariados",,which(lista_paises!="ROW")] %>% 
  apply(2, rowSums)

lab_row_total <- 
  sea_setores[,"renda_trabalho",,which(lista_paises!="ROW")] %>% 
  apply(1, sum) /
  soma_va_paises * soma_va_row

soma_lab_setor <- 
  sea_setores[,"renda_trabalho",,which(lista_paises!="ROW")] %>%
  apply(2, rowSums)

sea_setores[,"renda_trabalho",,"ROW"] <- 
  as.numeric(lab_row_total) * 
  prop.table(m_io_fonte[,"TOT.VA", posicao_row] *
               soma_lab_setor/soma_emp_setor, margin = 1)

comp_row_total <- 
  apply(sea_setores[,"salarios",,which(lista_paises!="ROW")], 1, sum)/
  soma_va_paises * soma_va_row

soma_comp_setor <- 
  sea_setores[,"pessoas_ocupadas",,which(lista_paises!="ROW")] %>%
  apply(2, rowSums)

sea_setores[,"salarios",,"ROW"] <- 
  as.numeric(comp_row_total) * 
  prop.table(m_io_fonte[,"TOT.VA", posicao_row] *
               soma_comp_setor/soma_emp_setor, margin = 1)
#obs: dividido por emp para manter o mesmo resultado de antes.


# Cálculo do estoque de capital.
# Considera a mesma relação de necessidade de capital por valor agregado
# de um conjunto de países pré-selecionados.

paises_pobres <- 
  paises$Legenda[c(17, 18, 4, 5, 37, 27, 7, 32, 31, 29, 16, 23, 24, 33, 11, 9)]

soma_k_usd_setor_pobres <- apply(sea_setores[,"estoque_capital",,paises_pobres],
                                 2, rowSums)

soma_va_setor_pobres <- 
  t(apply(m_io_fonte[,"TOT.VA", which(linhas$pais %in% paises_pobres)], 1,
          tapply, linhas$num_setores[linhas$pais %in% paises_pobres],sum))

sea_setores[,"estoque_capital",,"ROW"] <- 
  m_io_fonte[,"TOT.VA",posicao_row] * 
  soma_k_usd_setor_pobres / soma_va_setor_pobres

# Limpa todas as variáveis que não serão mais utilizadas
rm(row_emp_dados, emp_row_total, was_w_row, pre_row, posicao_row, soma_emp_setor, 
   soma_h_emp_setor, soma_va_setor, soma_empe_setor, lab_row_total, 
   soma_lab_setor, comp_row_total, soma_comp_setor, soma_va_paises, soma_va_row, 
   paises_pobres, soma_k_usd_setor_pobres, soma_va_setor_pobres)