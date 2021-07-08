print(paste0("carregando dados brutos da versao ",versao,"..."))

# Carrega as informações das contas socioeconômicas
sea_fonte <- readRDS(file = paste0("sourcedata/",versao,"/sea.rds"))

# Carrega matrizes input-output
m_io_fonte <- readRDS(file = paste0("sourcedata/",versao,"/m_io.rds"))
