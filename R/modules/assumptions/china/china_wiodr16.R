# Load working day data from previous version of WIOD (r13)
# The working day of the last year (2009) was extended to the
# last ones (2010-2014)
working_day_china <- 
  read.csv2(file = paste0(getwd(),"/source_data/wiodr16/China H_EMPE-EMPE.csv"),
            row.names = 1)
colnames(working_day_china) <- 
  tolower(gsub("X","",colnames(working_day_china)))

sea_sectors[,"hours_worked.emp.s.hr",,"CHN"] <- 
  sea_sectors[,"emp.s.un",,"CHN"] *
  t(working_day_china)*1000

sea_sectors[,"hours_worked.emp.s.hr",,"CHN"][
  is.na(sea_sectors[,"hours_worked.emp.s.hr",,"CHN"])] <- 0

# Como a informação sobre salários (COMP) é igual à da renda do trabalho (LAB),
# duplicamos as informações sobre EMP e H_EMPE em EMPE e H_EMPE
sea_sectors[,"empe.s.un",,"CHN"] <- 
  sea_sectors[,"emp.s.un",,"CHN"]

sea_sectors[,"hours_worked.empe.s.hr",,"CHN"] <- 
  sea_sectors[,"hours_worked.emp.s.hr",,"CHN"]

# clear variable
rm(working_day_china)
