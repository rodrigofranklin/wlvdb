# Soma dos preços do produto total
sea_setores[,"produto_total_pm",,] <-
  m_io_fonte[,"TOT.GO",1:num_paises_setores]
