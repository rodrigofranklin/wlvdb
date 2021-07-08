if (versao == 'July14') {
  sea$h_empe_hs = sea$h_emp_hs <- sea$h_hs
  sea$h_empe_ms = sea$h_emp_ms <- sea$h_ms
  sea$h_empe_ls = sea$h_emp_ls <- sea$h_ls
}
if (variavel_trabalho == "sea$h_emp") {
} else if (variavel_trabalho == "sea$emp") {
  sea$trabalho <- sea$emp
  sea$trabalho_assalariado <- sea$empe
} else if (variavel_trabalho == "Tciz") {
  # Pessoas engajadas
  remuneracao_media <- sea$lab_usd/sea$emp
  remuneracao_media[is.na(remuneracao_media)] <- 0
  remuneracao_media[is.infinite(remuneracao_media)] <- 0
  sea$trabalho <- sea$h_emp * remuneracao_media/min(remuneracao_media[remuneracao_media>0])
  # Pessoas assalariadas
  salario_medio <- sea$comp_usd/sea$empe
  salario_medio[is.na(salario_medio)] <- 0
  salario_medio[is.infinite(salario_medio)] <- 0
  sea$trabalho_assalariado <- sea$h_empe * salario_medio/min(salario_medio[salario_medio>0])
} else if (variavel_trabalho == "Tciz_hora") {
  # Pessoas engajadas
  remuneracao_media <- sea$lab_usd/sea$h_emp
  remuneracao_media[is.na(remuneracao_media)] <- 0
  remuneracao_media[is.infinite(remuneracao_media)] <- 0
  sea$trabalho <- sea$h_emp * remuneracao_media/min(remuneracao_media[remuneracao_media>0])
  # Pessoas assalariadas
  salario_medio <- sea$comp_usd/sea$h_empe
  salario_medio[is.na(salario_medio)] <- 0
  salario_medio[is.infinite(salario_medio)] <- 0
  sea$trabalho_assalariado <- sea$h_empe * salario_medio/min(salario_medio[salario_medio>0])
} else if (variavel_trabalho == "Tciz_n") {
  # Pessoas engajadas
  remuneracao_media <- sea$lab_usd/sea$h_emp
  remuneracao_media[is.na(remuneracao_media)] <- Inf
  remuneracao_media[remuneracao_media==0] <- Inf
  remuneracao_minima_nacional <- tapply(remuneracao_media, pais_lins, min, na.rn = TRUE)
  remuneracao_media[is.infinite(remuneracao_media)] <- 0
  sea$trabalho <- sea$h_emp * remuneracao_media/rep(remuneracao_minima_nacional, each = num_setores)
  # Pessoas assalariadas
  salario_medio <- sea$comp_usd/sea$h_empe
  salario_medio[is.na(salario_medio)] <- Inf
  salario_medio[salario_medio==0] <- Inf
  salario_minimo_nacional <- tapply(salario_medio, pais_lins, min, na.rn = TRUE)
  salario_medio[is.infinite(salario_medio)] <- 0
  sea$trabalho_assalariado <- sea$h_empe * salario_medio/rep(salario_minimo_nacional, each = num_setores)
} else if (variavel_trabalho == "sea$h_emp_ponderado") {
  sea$trabalho <- sea$h_emp * ((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  sea$trabalho_assalariado <- sea$h_empe * ((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  sea$h_empe_hs = sea$h_emp_hs <- (potencia_h * sea$h_hs)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  sea$h_empe_ms = sea$h_emp_ms <- (potencia_m * sea$h_ms)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  sea$h_empe_ls = sea$h_emp_ls <- (sea$h_ls)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
} else if (variavel_trabalho == "h_emp_ponderado_salario") {
  # Pessoas engajadas
  potencia_h <- (sum(sea$labhs*sea$lab_usd)/sum(sea$h_hs*sea$h_emp))/(sum(sea$labls*sea$lab_usd)/sum(sea$h_ls*sea$h_emp))
  potencia_m <- (sum(sea$labms*sea$lab_usd)/sum(sea$h_ms*sea$h_emp))/(sum(sea$labls*sea$lab_usd)/sum(sea$h_ls*sea$h_emp))
  sea$trabalho <- sea$h_emp * ((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  sea$h_emp_hs <- (potencia_h * sea$h_hs)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  sea$h_emp_ms <- (potencia_m * sea$h_ms)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  sea$h_emp_ls <- (sea$h_ls)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  # Pessoas assalariadas
  potencia_h <- (sum(sea$labhs*sea$comp_usd)/sum(sea$h_hs*sea$h_empe))/(sum(sea$labls*sea$comp_usd)/sum(sea$h_ls*sea$h_empe))
  potencia_m <- (sum(sea$labms*sea$comp_usd)/sum(sea$h_ms*sea$h_empe))/(sum(sea$labls*sea$comp_usd)/sum(sea$h_ls*sea$h_empe))
  sea$trabalho_assalariado <- sea$h_empe * ((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  sea$h_empe_hs <- (potencia_h * sea$h_hs)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  sea$h_empe_ms <- (potencia_m * sea$h_ms)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
  sea$h_empe_ls <- (sea$h_ls)/((potencia_h * sea$h_hs) + (potencia_m * sea$h_ms) + sea$h_ls)
} else {
  sea$trabalho <- sea$h_empe/sea$empe*sea$emp
  sea$trabalho_assalariado <- sea$h_empe
}
sea$trabalho[is.na(sea$trabalho)] <- 0
sea$trabalho[is.infinite(sea$trabalho)] <- 0
sea$trabalho_assalariado[is.na(sea$trabalho_assalariado)] <- 0
sea$trabalho_assalariado[is.infinite(sea$trabalho_assalariado)] <- 0
