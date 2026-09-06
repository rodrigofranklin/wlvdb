# Como a informação sobre salários (COMP) é igual à da renda do trabalho (LAB),
# duplicamos as informações sobre EMP e H_EMPE em EMPE e H_EMPE
parameters$description <- 
  paste0("China: all persons engaged was considered employee. ",
         parameters$description)

sea_sectors[,"empe.s.un",,"CHN"] <- 
  sea_sectors[,"emp.s.un",,"CHN"]

sea_sectors[,"hours_worked.empe.s.hr",,"CHN"] <- 
  sea_sectors[,"hours_worked.emp.s.hr",,"CHN"]
