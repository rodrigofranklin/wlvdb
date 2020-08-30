###Brasil

##ano del ejemplo: 2014

#for (x in 1:(num.paises-1)) {
library(pracma)


wiot.bra <- wiot %>% filter(Year == 2014) %>% select(1:5,starts_with("BRA"))
wiot.bra <- wiot.bra %>% filter(Country == "BRA")

#wiot.bra <- wiot.bra[,-1:-5]

##cambio
cambio.bra <- cambio[seq_completos]

  


sec_prod <- as.logical(setores$produtivo)
  
inicio<-4*32+1

seq_inicio<- (4*32+1):(5*32)

a.bra <- coeficientes[inicio:(inicio+31),inicio:(inicio+31)]


d.bra <- depreciacao[seq_inicio,seq_inicio]

seq_completos <- (56*4+1):(56*5)

sec_k_bra <- which(grepl("BRA",dimnames(k.composicao)[[2]]))
k.bra.completa <- k.composicao[sec_k_bra,sec_k_bra]

#k.bra.completa <- matrix(k.bra.completa, nrow = 56,ncol = 56)

k.bra <- k.bra.completa[sec_prod, sec_prod]

k.bra[is.na(k.bra)] <- 1


#SE cambio já está?
k.bra.us <- k.bra
#k.bra.us <- cambio.bra[1]*k.bra

###Vamos a construir B




sea.bra <- sea.tidy %>% filter(country == "BRA", year == 2014)

sal.bra <- sea.bra %>% filter(variable == "LAB") %>% select(value)

price_level <- sea.bra %>% filter(variable == "VA_P"|variable == "VA_PI") %>% select(value)

sal.bra <- sal.bra*100/price_level
sal.bra <- sal.bra*cambio.bra

#sal.bra <- sal.bra[which(sec_prod),]

sal.bra <- lab.usd[seq_completos]

sal.bra <- sal.bra[sec_prod]
#sal.bra <- t(sal.bra)
###Consumo de hogares


cons.hog.bra.comp <- wiot.bra$BRA57


cons.hog.bra.prod <- cons.hog.bra.comp[sec_prod]

### proporcion salarios / consumo de hogares

cx <- sum(sal.bra)/sum(cons.hog.bra.comp)


### tcw  h_emp/sum(h_emp)    <<--metodo CESAR/EVER

#h.emp.bra <- h.emp[seq_completos]

#tcw.bra <- h.emp.bra/sum(h.emp.bra)

#tcw.bra <- tcw.bra[sec_prod]

#tcw.bra <- tcw.bra/sum(tcw.bra)

# tcw sal.bra/sum(sal.bra) <<-- metodo Franklin/Rodrigo
#Utilizar salarios en lugar de horas trabajadas
tcw.bra <- sal.bra/sum(sal.bra)

#Ya está subseleccionado
#tcw.bra.sal <- tcw.bra.sal[sec_prod]

#### consumo de trabajadores
c <- cx*cons.hog.bra.prod

#### Matriz E - matriz de bienes salarios 

E <- c%*%t(tcw.bra)

### B - coeficientes de bienes salarios (E) por unidad de producción bruta
seq_iot <- (61*4+1):(61*5-5)
wiot.bra.go <-  wiot %>% 
  filter(IndustryCode == "GO", Country== "TOT",Year == 2014) 

wiot.bra.go <- as.numeric(t(wiot.bra.go)[which(grepl("BRA",dimnames(wiot.bra.go)[[2]]))])

wiot.bra.go <- wiot.bra.go[1:56]

wiot.bra.go <- wiot.bra.go[which(sec_prod)]

#wiot.bra.go <- as.data.frame(wiot.bra.go)[,sec_prod]

##Evitar división por 0
wiot.bra.go[wiot.bra.go == 0] <- 1

#wiot.bra.go <- as.data.frame(wiot.bra.go)

B <- E%*%solve(diag(wiot.bra.go))

##Matriz de Capital <- dividida por producción bruta

k.bra.go <-(matrix(mapply("/",t(k.bra.us),(wiot.bra.go)),
                  nrow=sum(sec_prod),byrow = T))

M <- a.bra+k.bra.go+B


N <- a.bra+B+d.bra

H <- M*solve(diag(1,32)-N)

prec_prod <- eigen(t(H))

#max(prec_prod$values)

1/as.double(prec_prod$values[1])

