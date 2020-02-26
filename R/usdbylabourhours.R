##genera vector de las horas totales y año indicado
if(exists(laborvector)) laborvector <- as.numeric(laborvector)
else
  ##Importa SEA de la WIOD v1
  urlseav1 <- "http://www.wiod.org/protected3/data13/SEA/WIOD_SEA_July14.xlsx"
seav1 <- tempfile()
download.file(urlseav1,seav1)
sea95legend <- read_xlsx(seav1, range = "A7:F55", col_names = T)
sea95 <- read_xlsx(seav1, sheet = "DATA", col_names = T)
seaano <- sea95[c("Country","Variable","Code",paste0("_",ano))]
seaano <- data.table(seaano)
laborvector <- as.matrix(seaano[Variable == "H_EMP" & Code != "TOT", 4])
laborvector <- as.double(laborvector)
#Preparar el vector - completar información ausente - 1400 x 1435
#seaano[Variable == "H_EMP" & Code != "TOT", ] <- selecciona indonesia
