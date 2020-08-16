###Brasil

##ano del ejemplo: 2014

#for (x in 1:(num.paises-1)) {
library(pracma)


wiot.bra <- wiot %>% filter(Year == 2014) %>% select(1:5,starts_with("BRA"))
wiot.bra <- wiot.bra %>% filter(Country == "BRA")

wiot.bra <- wiot.bra[,-1:-5]



x <- 5
  col.demanda.final.bra <-  2485

  linhas.pais.h.emp <- linhas.h.emp[which(sea[linhas.h.emp,'country'] == as.character(paises[x,3]))]
  linhas.pais.h.empe <- linhas.h.empe[which(sea[linhas.h.empe,'country'] == as.character(paises[x,3]))]
  linhas.pais.emp <- linhas.emp[which(sea[linhas.emp,'country'] == as.character(paises[x,3]))]
  linhas.pais.empe <- linhas.empe[which(sea[linhas.empe,'country'] == as.character(paises[x,3]))]
  linhas.pais.go <- linhas.go[which(sea[linhas.go,'country'] == as.character(paises[x,3]))]
  linhas.pais.va <- linhas.va[which(sea[linhas.va,'country'] == as.character(paises[x,3]))]
  linhas.pais.va.p <- linhas.va.p[which(sea[linhas.va.p,'country'] == as.character(paises[x,3]))]
  linhas.pais.comp <- linhas.comp[which(sea[linhas.comp,'country'] == as.character(paises[x,3]))]
  linhas.pais.lab <- linhas.lab[which(sea[linhas.lab,'country'] == as.character(paises[x,3]))]
  linhas.pais.cap <- linhas.cap[which(sea[linhas.cap,'country'] == as.character(paises[x,3]))]
  linhas.pais.k.gfcf <- linhas.k.gfcf[which(sea[linhas.k.gfcf,'country'] == as.character(paises[x,3]))]
  linhas.pais.gfcf <- linhas.gfcf[which(sea[linhas.gfcf,'country'] == as.character(paises[x,3]))]
  linhas.pais.gfcf.p <- linhas.gfcf.p[which(sea[linhas.gfcf.p,'country'] == as.character(paises[x,3]))]
  linhas.pais.k <- linhas.k[which(sea[linhas.k,'country'] == as.character(paises[x,3]))]
  
  
  for (y in 1:num.setores) {
    linhas.setor.pais.h.emp <- linhas.pais.h.emp[which(sea[linhas.pais.h.emp,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.h.empe <- linhas.pais.h.empe[which(sea[linhas.pais.h.empe,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.emp <- linhas.pais.emp[which(sea[linhas.pais.emp,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.empe <- linhas.pais.empe[which(sea[linhas.pais.empe,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.go <- linhas.pais.go[which(sea[linhas.pais.go,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.va <- linhas.pais.va[which(sea[linhas.pais.va,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.va.p <- linhas.pais.va.p[which(sea[linhas.pais.va.p,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.comp <- linhas.pais.comp[which(sea[linhas.pais.comp,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.lab <- linhas.pais.lab[which(sea[linhas.pais.lab,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.cap <- linhas.pais.cap[which(sea[linhas.pais.cap,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.k.gfcf <- linhas.pais.k.gfcf[which(sea[linhas.pais.k.gfcf,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.gfcf <- linhas.pais.gfcf[which(sea[linhas.pais.gfcf,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.gfcf.p <- linhas.pais.gfcf.p[which(sea[linhas.pais.gfcf.p,'code'] == as.character(setores[y,1]))]
    linhas.setor.pais.k <- linhas.pais.k[which(sea[linhas.pais.k,'code'] == as.character(setores[y,1]))]
    
    cambio[w] <- ifelse(as.numeric(sea[linhas.setor.pais.va,coluna.sea]) !=0,m.wio[lin.va,w]/as.numeric(sea[linhas.setor.pais.va,coluna.sea]),0)
    h.empe[w]<-as.numeric(sea[linhas.setor.pais.h.empe,coluna.sea])*1000000
    emp[w]<-as.numeric(sea[linhas.setor.pais.emp,coluna.sea])*1000
    empe[w]<-as.numeric(sea[linhas.setor.pais.empe,coluna.sea])*1000
    comp.real[w] <- as.numeric(sea[linhas.setor.pais.comp,coluna.sea])/as.numeric(sea[linhas.setor.pais.va.p,coluna.sea])*100
    lab.real[w] <- as.numeric(sea[linhas.setor.pais.lab,coluna.sea])/as.numeric(sea[linhas.setor.pais.va.p,coluna.sea])*100
    cap.usd[w] <- as.numeric(sea[linhas.setor.pais.cap,coluna.sea])*cambio[w]
    lab.usd[w] <- as.numeric(sea[linhas.setor.pais.lab,coluna.sea])*cambio[w]
    comp.usd[w] <- as.numeric(sea[linhas.setor.pais.comp,coluna.sea])*cambio[w]
    if (versao == 'July14') {
      h.emp[w] <- as.numeric(sea[linhas.setor.pais.h.emp,coluna.sea])*1000000
      k.usd[w] <- as.numeric(sea[linhas.setor.pais.k.gfcf,coluna.sea])*as.numeric(sea[linhas.setor.pais.gfcf.p,coluna.sea])/100*cambio[w]
      #i.usd[w] <- as.numeric(sea[linhas.setor.pais.gfcf,coluna.sea])/100*cambio[w]
      #cambio2[w] <- ifelse(as.numeric(sea[linhas.setor.pais.va,coluna.sea]) !=0,m.wio[lin.va,w]/as.numeric(sea[linhas.setor.pais.va,coluna.sea]),0)
      #k2.usd
    } else {
      k.usd[w] <- as.numeric(sea[linhas.setor.pais.k,coluna.sea])*cambio[w]
    }
    w <- w+1
  }
}



inicio<-4*32+1

seq_inicio<- (4*32+1):(5*32)

a.bra <- coeficientes[inicio:(inicio+31),inicio:(inicio+31)]


d.bra <- depreciacao[seq_inicio,seq_inicio]

seq_completos <- (56*4+1):(56*5)

sec_k_bra <- grepl("BRA",dimnames(k.composicao)[[2]])
k.bra.completa <- k.composicao[sec_k_bra,sec_k_bra]

k.bra.completa <- matrix(k.bra.completa, nrow = 56,ncol = 56)

k.bra <- k.bra.completa[sec_prod, sec_prod]

k.bra[is.na(k.bra)] <- 0


###Vamos a construir B

sec_prod <- as.logical(setores$produtivo)


sea.bra <- sea.tidy %>% filter(country == "BRA", year == 2014)

sal.bra <- sea.bra %>% filter(variable == "LAB") %>% select(value)

##cambio
cambio.bra <- cambio[seq_completos]
sal.bra <- sal.bra*cambio.bra


#sal.bra <- sal.bra[which(sec_prod),]


#sal.bra <- t(sal.bra)
###Consumo de hogares


cons.hog.bra.comp <- wiot.bra$BRA57


cons.hog.bra.prod <- cons.hog.bra.comp[sec_prod]

### proporcion salarios / consumo de hogares

cx <- sum(sal.bra)/sum(cons.hog.bra.comp)


### tcw  h_emp/sum(h_emp)   

h.emp.bra <- h.emp[seq_completos]

tcw.bra <- h.emp.bra/sum(h.emp.bra)

tcw.bra <- tcw.bra[sec_prod]

tcw.bra <- tcw.bra/sum(tcw.bra)
#### consumo de trabajadores
c <- cx*cons.hog.bra.prod

#### Matriz E - matriz de bienes salarios 

E <- c%*%t(tcw.bra)

### B - coeficientes de bienes salarios (E) por unidad de producción bruta

wiot.bra.go <-  wiot %>% filter(IndustryCode == "GO") %>% select(-1:-5)

wiot.bra.go <- wiot.bra.go[seq_completos]

wiot.bra.go <- wiot.bra.go[sec_prod]

B <- E%*%pinv(diag(wiot.bra.go))

k.bra <- lapply(e)

M <- coeficientes.bra+k.bra+B


N <- coeficientes.bra+B+d.bra

H <- M*solve(diag(1,32)-N)

prec_prod <- eigen(t(H))


