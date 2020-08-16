#### Estima los precios de producción según los datos obtenidos de TransformarTudo y tabla de rotación estimada.

#source("R/TransformarTudo.R")
source("R/turnover-rotacion.R")
t <- rotacion()

#### Datos necesarios
# A - matriz de coef. tecnicos - coeficientes
# b - vector de salarios reales - 
## b' <- vector b columna
# D - matriz de depreciación - 
# K - matriz de capital
# ao <- requerimientos directos laborales
# b'.ao <- requerimientos directos laborales de la cesta de consumo obrera

#### El problema es de máximo autovalor para auto-vector con valores todos positivos
#(único que tiene sentido económico, precios >0) de la siguiente matriz:

#[K + (A +b.ao)<t>] (I - A - b'.ao - D)-1

##Ever y César proponen forma de calcular B distinta de b.ao , a falta de b

##Directamente de tablas insumo producto. Pasos
#1) Proporción del consumo de hogares representado por salarios
#del codigo principal
# Estimativa de variáveis para o RoW

#  col.demanda.final <- consumo final de hogares <-retirar completa
salarios <- sea[sea$variable == 'LAB' & sea$code %in% setores[setores$produtivo == 1,"Code"], "2014"]

##Hace falta incluir a ROW
#Repitiendo los supuestos del script
#source(paste0(getwd(),"/R/suposicoes_row.R")) 
#Supongamos el promedio de pago salarial por hora de sectores de
#los paises pobres , como se hizo para estimar la composicion del capital

leg.paises.pobres <- paises[paises[,2] %in% paises.pobres, 3]
leg.paises.pobres <- as.character(leg.paises.pobres)

sea.base.salarios <- sea.tidy %>% filter(year == 2014) %>% pivot_wider(names_from = variable, values_from = value)

sea.base.salarios[sea.base.salarios$H_EMPE == 0,"H_EMPE"] <- 1
sea.base.salarios[sea.base.salarios$EMP == 0,"EMP"] <- 1
sea.base.salarios[sea.base.salarios$EMPE == 0,"EMPE"] <- 1
sea.base.salarios$H_EMP <- (sea.base.salarios$H_EMPE/sea.base.salarios$EMPE)*sea.base.salarios$EMP
sea.base.salarios$wagesh <- sea.base.salarios$LAB/sea.base.salarios$H_EMP

#Una vez contamos con el salario por hora, podemos hacer el promedio ponderado
#considerando el volumen de empleo por sector y país
sea.salp.pobres <- sea.base.salarios %>% 
  filter(country %in% leg.paises.pobres) %>% 
  group_by(code) %>% 
  summarize(salario_promedio = weighted.mean(wagesh,H_EMP))

##Asumiendo la misma ordenación de sectores alfabetica y en h.emp
sal.hor.row <- cbind(sea.salp.pobres,h.emp[posicao.row])
names(sal.hor.row) <- c("sector","salario_promedio_h","H_EMP")

salarios <- c(salarios,salarios.row)
#H transpuesta
#H = [M(I-N)^-1]
#N = A (coeficientes) + D (m.depreciacao) + B
#M = K + A + B
  
#matriz.b <- 
matriz.m <- coeficientes+k.composicao+matriz.b

matriz.n <- m.depreciacao+coeficientes+matriz.b

#matriz.h <- solve(matriz.m*(diag(1,nrow = cols)-matriz.n))

#matriz.ht <- transpose(matriz.h)

#pre_prod <- eigen(matriz.ht)


