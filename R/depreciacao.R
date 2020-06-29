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
paises.setores[!(paises.setores$p.ek %in% unique(ek.k$country)),"p.ek"] <- "MD"
paises.setores$ps.ek <- paste0(paises.setores$p.ek, paises.setores$s.ek)
paises.setores$pwiod.sek <- paste0(paises.setores$p.wiod, paises.setores$s.ek)
ek.k$ps <- paste0(ek.k$country, ek.k$code)

#fator de desagragacao
# filtro1 <- which(paises.setores$p.ek!="")
# agregados <- tapply(m.wio[lin.va,filtro1], paises.setores$ps.ek[filtro1], sum, na.rm = FALSE)
# k.composicao[,filtro1] <- rep(m.wio[lin.va,filtro1]/agregados[paises.setores$ps.ek[filtro1]], each = tamanho)
agregados <- tapply(m.wio[lin.va,1:tamanho], paises.setores$pwiod.sek, sum, na.rm = FALSE)
k.composicao[,1:tamanho] <- rep(m.wio[lin.va,1:tamanho]/agregados[paises.setores$pwiod.sek], each = tamanho)

##critério de aplicação geral
#Média = MD
# filtro1 <- which(paises.setores$p.ek=="")
# k.composicao[,filtro1] <- rep(k.composicao[,paises.setores$p.ek=="MD"], times = (num.paises-length(unique(ek.k$country))))
# paises.setores[!(paises.setores$p.ek %in% unique(ek.k$country)),"p.ek"] <- factor("MD")
# paises.setores$ps.ek <- paste0(paises.setores$p.ek, paises.setores$s.ek)

#desagregar
for (p in 1:tamanho) {
  k.composicao[p,] <- k.composicao[p,]*ek.k[match(paises.setores$ps.ek, ek.k$ps),as.character(paises.setores$k.ek[p])]
}

##Aplicar

fbcf <- as.data.frame(m.wio[1:tamanho,col.fbcf]) # Cria uma matrix NxN com a fbcf de cada país
fbcf <- as.matrix(fbcf[rep(names(fbcf), each = num.setores)])

k.composicao <- k.composicao * fbcf # primeiro, distribui a fbcf de cada país conforme a composição do capital euklems
k.composicao <- prop.table(k.composicao, margin = 2)*matrix(k.usd,nrow=tamanho,ncol=tamanho, byrow= TRUE) #depois, distribui o estoque de capital pelas proporções da fbcf distribuida

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
