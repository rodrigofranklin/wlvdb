##estimar o generar matriz y vector de rotación de capital 

rotacion <- function(forma = "diagonal", rotac = 1, ventas_inventario = "", versao = "Nov16") {
  ### Aprovecha el resultado de sectorespaises.R - CUIDADO, actualmente sustituye la versión por la que se especifique
  source("R/sectorespaises.R")
  tamano <- nrow(setores[setores$produtivo == 1,])
  if (ventas_inventario == "") {
    print("Rotación será estimada con número arbitrario")
    }
  rotac <- rep(rotac,tamano)
  if (forma == "diagonal") {
    rotac <- diag(rotac)
  } 
  rotac
}

