#Download and import main EU KLEMS database on capital stocks

###R format available euklems data on capital stock by sector by country by year
library(magrittr)
library(dplyr)
#library(tidyr)

### Instruções de download
# kkurl <- "http://euklems.eu/bulk/Statistical_Capital.rds"
# f <- paste0(getwd(),'/sourcedata/euklems.rds')
# download.file(kkurl, f)
# euklems <- readRDS(f)

# kkurl <- "http://euklems.eu/bulk/Statistical_National-Accounts.rds"
# f <- paste0(getwd(),'/sourcedata/euklems-na.rds')
# download.file(kkurl, f)
# euklems.na <- readRDS(f)

## Instruções para leitura de dados já baixados
euklems <- readRDS(paste0(getwd(),'/sourcedata/euklems.rds'))
euklems.na <- readRDS(paste0(getwd(),'/sourcedata/euklems-na.rds'))

paises.euklems <- unique(euklems[,1])
setores.euklems <- unique(euklems[,c(5,6)])
paises.setores <- data.frame(cbind(country=rep(paises.euklems,each=length(setores.euklems[,2])),code=setores.euklems[,2],agg=setores.euklems[,1]))
ek.va = ek.i = ek.k <- paises.setores[,c(1,2)]

ek.va$va <- left_join(paises.setores[,c(1,2)],euklems.na[which(euklems.na[,3]=="VA" & euklems.na[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]

ek.k$gfcf <- left_join(paises.setores[,c(1,2)],euklems[which(euklems[,3]=="K_GFCF" & euklems[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]

ek.k$it <- left_join(paises.setores[,c(1,2)],euklems[which(euklems[,3]=="K_IT"& euklems[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]
ek.k$ct <- left_join(paises.setores[,c(1,2)],euklems[which(euklems[,3]=="K_CT"& euklems[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]
ek.k$soft <- left_join(paises.setores[,c(1,2)],euklems[which(euklems[,3]=="K_Soft_DB"& euklems[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]
ek.k$traeq <- left_join(paises.setores[,c(1,2)],euklems[which(euklems[,3]=="K_TraEq"& euklems[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]
ek.k$omach <- left_join(paises.setores[,c(1,2)],euklems[which(euklems[,3]=="K_OMach"& euklems[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]
ek.k$ocon <- left_join(paises.setores[,c(1,2)],euklems[which(euklems[,3]=="K_OCon"& euklems[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]
ek.k$rstruc <- left_join(paises.setores[,c(1,2)],euklems[which(euklems[,3]=="K_RStruc"& euklems[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]
ek.k$oipp <- left_join(paises.setores[,c(1,2)],euklems[which(euklems[,3]=="K_OIPP"& euklems[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]
ek.k$rd <- left_join(paises.setores[,c(1,2)],euklems[which(euklems[,3]=="K_RD"& euklems[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]
ek.k$cult <- left_join(paises.setores[,c(1,2)],euklems[which(euklems[,3]=="K_Cult"& euklems[,7]==ano),c(1,6,8)], by = c("country", "code"))[,3]
ek.k$soma <- rowSums(ek.k[,4:13], na.rm = TRUE)


##Resolver desagregações

#Primeiro, preciso estabelecer as ponderações do valor agregado
ek.va$prop <- 0
ek.va$prop2 <- 0
ek.va$prop[grep("C.", ek.va[,2])] <- ek.va[grep("C.", ek.va[,2]),3]/rep(ek.va[ek.va[,2]=="C",3], each = length(grep("C.", setores.euklems[,2])))
ek.va$prop2[ek.va[,2] %in% c("C20", "C21")] <- ek.va[ek.va[,2] %in% c("C20", "C21"),3]/rep(ek.va[ek.va[,2]=="C20_C21",3], each = 2)
ek.va$prop2[ek.va[,2] %in% c("C26", "C27")] <- ek.va[ek.va[,2] %in% c("C26", "C27"),3]/rep(ek.va[ek.va[,2]=="C26_C27",3], each = 2)
ek.va$prop[grep("H.", ek.va[,2])] <- ek.va[grep("H.", ek.va[,2]),3]/rep(ek.va[ek.va[,2]=="H",3], each = length(grep("H.", setores.euklems[,2])))
ek.va$prop[grep("J.", ek.va[,2])] <- ek.va[grep("J.", ek.va[,2]),3]/rep(ek.va[ek.va[,2]=="J",3], each = length(grep("J.", setores.euklems[,2])))
ek.va$prop[grep("G.", ek.va[,2])] <- ek.va[grep("G.", ek.va[,2]),3]/rep(ek.va[ek.va[,2]=="G",3], each = length(grep("G.", setores.euklems[,2])))
ek.va$prop[ek.va[,2] %in% c("D", "E")] <- ek.va[ek.va[,2] %in% c("D", "E"),3]/rep(ek.va[ek.va[,2]=="D_E",3], each = 2)
ek.va$prop[ek.va[,2] %in% c("R", "S")] <- ek.va[ek.va[,2] %in% c("R", "S"),3]/rep(ek.va[ek.va[,2]=="R_S",3], each = 2)
ek.va$prop[ek.va[,2] %in% c("O", "P", "Q")] <- ek.va[ek.va[,2] %in% c("O", "P", "Q"),3]/rep(ek.va[ek.va[,2]=="O-Q",3], each = 3)
ek.va.prop <- do.call("cbind", replicate(10, ek.va$prop, simplify=FALSE))
ek.va.prop2 <- do.call("cbind", replicate(10, ek.va$prop2, simplify=FALSE))

#Em seguida, desagregar

agregacao.setores <- read.csv2(paste0(getwd(),'/sourcedata/agregacao-euklems.csv'))

for (x in 1:nrow(agregacao.setores)) {
  filtro1 <- ek.k[,2]==as.character(agregacao.setores[x,1]) & ek.k[,14]==0
  filtro2 <- ek.k[,1] %in% ek.k[filtro1,1] & ek.k[,2]==as.character(agregacao.setores[x,2])
  ek.k[filtro1,4:13] <- ek.k[filtro2,4:13] * ek.va.prop2[filtro1,]
  #ek.k[filtro1,14] <- rowSums(ek.k[filtro1,4:13], na.rm = TRUE)
}

ek.k$soma <- rowSums(ek.k[,4:13], na.rm = TRUE) #soma os dados disponíveis para saber quais foram alterados

for (x in 1:nrow(agregacao.setores)) {
  filtro1 <- ek.k[,2]==as.character(agregacao.setores[x,1]) & ek.k[,14]==0
  filtro2 <- ek.k[,1] %in% ek.k[filtro1,1] & ek.k[,2]==as.character(agregacao.setores[x,2])
  ek.k[filtro1,4:13] <- ek.k[filtro2,4:13] * ek.va.prop[filtro1,]
}

##Preparar proporções

#Criar colunas de tipos de capital faltando
ek.k$itct <- ek.k$it + ek.k$ct
ek.k$rsoc <- ek.k$rstruc + ek.k$ocon
ek.k$softipp <- ek.k$soft + ek.k$oipp
ek.k$rdetc <- ek.k$rd + ek.k$softipp

#Calcula as proporções
for (x in 4:18) {
  ek.k[,x] <- ek.k[,x]/rep(ek.k[ek.k[,2]=="TOT",x], each=length(setores.euklems[,2]))
}

##Eliminar países sem dados adequados
ek.k$soma <- rowSums(ek.k[,4:13], na.rm = FALSE)
paises.para.excluir <- (ek.k[ek.k[,2]=="TOT_IND" & is.na(ek.k[,14]),1]) #como vou retirar as agregações agora, registro quais países devem ser mantidos (para excluir os demais futuramente)
ek.k <- ek.k[!(ek.k[,1] %in% paises.para.excluir),]

##Resolver a falta de agregações
ek.k[is.na(ek.k)] <- 0

filtro1 = ek.k[,2]=="C20_C21" & ek.k[,3]==0
ek.k[filtro1, 4:13] <- ek.k[ek.k[,1] %in% ek.k[filtro1,1] & ek.k[,2]=="C20",4:13]+ek.k[ek.k[,1] %in% ek.k[filtro1,1] & ek.k[,2]=="C21",4:13]

filtro1 = ek.k[,2]=="C26_C27" & ek.k[,3]==0
ek.k[filtro1, 4:13] <- ek.k[ek.k[,1] %in% ek.k[filtro1,1] & ek.k[,2]=="C26",4:13]+ek.k[ek.k[,1] %in% ek.k[filtro1,1] & ek.k[,2]=="C27",4:13]

filtro1 = ek.k[,2]=="D_E" & ek.k[,3]==0
ek.k[filtro1, 4:13] <- ek.k[ek.k[,1] %in% ek.k[filtro1,1] & ek.k[,2]=="D",4:13]+ek.k[ek.k[,1] %in% ek.k[filtro1,1] & ek.k[,2]=="E",4:13]

ek.k.rsu = ek.k.53_63 <- ek.k[ek.k[,2]=="R",]

ek.k.rsu$code <- "R_S_U"
filtro1 = ek.k[,2]=="R_S" & ek.k[,3]==0
ek.k[filtro1, 4:13] <- ek.k[ek.k[,1] %in% ek.k[filtro1,1] & ek.k[,2]=="R",4:13]+ek.k[ek.k[,1] %in% ek.k[filtro1,1] & ek.k[,2]=="S",4:13]
ek.k.rsu[4:13] <- ek.k[ek.k[,2]=="R_S",4:13] + ek.k[ek.k[,2]=="U",4:13]

ek.k.53_63$code <- "H53-J63"
ek.k.53_63[4:13] <- ek.k[ek.k[,2]=="H53",4:13] + ek.k[ek.k[,2]=="J58-J60",4:13] + ek.k[ek.k[,2]=="J61",4:13] + ek.k[ek.k[,2]=="J62_J63",4:13]

ek.k <- rbind(ek.k, ek.k.rsu, ek.k.53_63)

ek.k <- ek.k[,c(1,2,4:13,15:18)]