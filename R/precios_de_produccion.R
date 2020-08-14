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

#### El problema es de máximo autovalor para auto-vector positivo (único que tiene sentido económico, precios >0) de la siguiente matriz:

#[K + (A +b.ao)<t>] (I - A - b'.ao - D)-1
