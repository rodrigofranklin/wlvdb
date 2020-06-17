#K Depreciation - Depreciación de Capit
#version inicial, sin depreciación
#remover ) and -Depreciation)

###Distribui o capital presente nas SEA em seus diversos tipos
#k.composicao <- matrix(rep(t(prop.table(m.wio[1:(tamanho),col.fbcf],2)),each=num.setores), ncol = tamanho, nrow = tamanho, byrow = TRUE)*matrix(k.usd,nrow=tamanho,ncol=tamanho, byrow= TRUE)
#^- essa versão faz a distribuição pela fbcf de cada ano

#v- esta versão faz a distribuiçã com os dados do euklems
ek.k <- readRDS(paste0("sourcedata/euklems/ekk_",z,".rds"))
k.composicao <- matrix(1, nrow = tamanho, ncol = tamanho)

#levanta informações para desagragação dos setores
paises.setores <- data.frame(cbind(p.wiod=rep(paises$Legenda,each=num.setores),p.ek=rep(paises$euklems.paises,each=num.setores)))
paises.setores$p.wiod <- rep(paises$Legenda,each=num.setores)
paises.setores$s.wiod <- setores$WIOD
paises.setores$s.ek <- setores$euklems.setor
paises.setores$k.ek <- setores$euklems.capital

paises.setores$p.ek <- rep(paises$euklems.paises,each=num.setores)
paises.setores[!(paises.setores$p.ek %in% unique(ek.k$country)),"p.ek"] <- ""
paises.setores$ps.ek <- paste0(paises.setores$p.ek, paises.setores$s.ek)
ek.k$ps <- paste0(ek.k$country, ek.k$code)

#fator de desagragacao
filtro1 <- which(paises.setores$p.ek!="")
agregados <- tapply(m.wio[lin.va,filtro1], paises.setores$ps.ek[filtro1], sum, na.rm = FALSE)
k.composicao[,filtro1] <- rep(m.wio[lin.va,filtro1]/agregados[paises.setores$ps.ek[filtro1]], each = tamanho)

##critério de aplicação geral
#Espanha?
filtro1 <- which(paises.setores$p.ek=="")
k.composicao[,filtro1] <- rep(k.composicao[,paises.setores$p.ek=="ES"], times = (num.paises-length(unique(ek.k$country))))
paises.setores[!(paises.setores$p.ek %in% unique(ek.k$country)),"p.ek"] <- factor("ES")
paises.setores$ps.ek <- paste0(paises.setores$p.ek, paises.setores$s.ek)

#desagregar
for (x in 1:tamanho) {
  k.composicao[x,] <- k.composicao[x,]*ek.k[match(paises.setores$ps.ek, ek.k$ps),as.character(paises.setores$k.ek[x])]
}

##Aplicar
k.composicao <- k.composicao * matrix(rep(m.wio[1:(tamanho),col.fbcf],each=num.setores), ncol = tamanho, nrow = tamanho, byrow = TRUE)
k.composicao <- prop.table(k.composicao, margin = 2)*matrix(k.usd,nrow=tamanho,ncol=tamanho, byrow= TRUE)

# ##### Distribuir o investimento
#OBS: NÃO PRECISA DISSO TUDO, POIS O EK.I É IGUAL AO EK.K (CONSTATAÇÃO)
# paises.setores$p.ei <- rep(paises$euklems.paises,each=num.setores)
# paises.setores[!(paises.setores$p.ei %in% unique(ek.i$country)),"p.ei"] <- ""
# paises.setores$ps.ei <- paste0(paises.setores$p.ei, paises.setores$s.ei)
# ek.i$ps <- paste0(ek.i$country, ek.i$code)
# 
# ek.i <- readRDS(paste0("sourcedata/euklems/eki_",z,".rds"))
# i.composicao <- matrix(1, nrow = tamanho, ncol = tamanho)
# 
# filtro1 <- which(paises.setores$p.ei!="")
# agregados <- tapply(m.wio[lin.va,filtro1], paises.setores$ps.ei[filtro1], sum, na.rm = FALSE)
# i.composicao[,filtro1] <- rep(m.wio[lin.va,filtro1]/agregados[paises.setores$ps.ei[filtro1]], each = tamanho)
# 
# filtro1 <- which(paises.setores$p.ei=="")
# i.composicao[,filtro1] <- rep(i.composicao[,paises.setores$p.ei=="ES"], times = (num.paises-length(unique(ek.i$country))))
# paises.setores[!(paises.setores$p.ei %in% unique(ek.i$country)),"p.ei"] <- factor("ES")
# paises.setores$ps.eik <- paste0(paises.setores$p.ei, paises.setores$s.ek)
# 
# for (x in 1:tamanho) {
#   i.composicao[x,] <- i.composicao[x,]*ek.i[match(paises.setores$ps.ei, ek.i$ps),as.character(paises.setores$k.ei[x])]
# }
# 
# i.composicao <- i.composicao * matrix(rep(m.wio[1:(tamanho),col.fbcf],each=num.setores), ncol = tamanho, nrow = tamanho, byrow = TRUE)
# i.composicao <- prop.table(i.composicao, margin = 2)*matrix(i.usd,nrow=tamanho,ncol=tamanho, byrow= TRUE)


#Calcula as taxas de depreciacao
tx.depreciacao <- as.matrix(read.csv2(paste0(getwd(),"/sourcedata/",versao,"/txdepreciacao.csv"),header = FALSE))
tx.depreciacao <- do.call("rbind", replicate(num.paises, tx.depreciacao, simplify=FALSE))
tx.depreciacao <- do.call("cbind", replicate(num.paises, tx.depreciacao, simplify=FALSE))

#Devemos utilizar outro método: distribuir o estoque de capital, distribuir a fbcf e realizar as deduções

#Aplica as taxas de depreciacao ao capital total
m.depreciacao <- k.composicao*tx.depreciacao

#Separa a depreciacao apenas dos capitais provenientes de setores produtivos
depreciacao <- matrix(0, nrow = length(lin.prods), ncol = length(col.prods))
depreciacao[x,x] <- m.depreciacao[col.prods,lin.prods]/matrix(m.wio[lin.produto.total,lin.prods], nrow = cols, ncol=cols, byrow = TRUE)
depreciacao[is.infinite(depreciacao)] <- 0
depreciacao[is.nan(depreciacao)] <- 0

k.dep <- array(colSums(m.depreciacao))
