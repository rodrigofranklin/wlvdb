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
salarios <- sea[sea$variable == 'LAB' & sea$code %in% setores[setores$produtivo ==1,"Code"], "2014"]
##Hace falta incluir a ROW
#source(paste0(getwd(),"/R/suposicoes_row.R"))


#H transpuesta
#H = [M(I-N)^-1]
#M = A (coeficientes) + D (m.depreciacao) + B
#M = K + A + B
  
#matriz.b <- 
#matriz.m <- coeficientes+m.depreciacao+matriz.b

#matriz.n <- k.composicao+coeficientes+matriz.b

#matriz.h <- solve(matriz.m*(diag(1,nrow = cols)-matriz.n))

#matriz.ht <- transpose(matriz.h)

#pre_prod <- eigen(matriz.ht)

unique(sea$country)
