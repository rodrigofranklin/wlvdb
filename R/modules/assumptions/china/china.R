# Load employment data from an external source (worldbank)
# was_w => Wage and salaried workers as a percentage of employed population
parameters$description <- 
  paste0("China: data about employee as a percentage of employment obtained ",
         "from World Bank (SL.EMP.WORK.ZS); hours worked by employee ",
         "was projected considering the same working hours of the persons ",
         "engaged. ", parameters$description)

was_w_china <- as.data.frame(
  read.csv2(paste0(getwd(),"/source_data/worldbank/employment_china.csv")))
colnames(was_w_china) <- sub("X","",colnames(was_w_china))

was_w_china <- as.numeric(was_w_china[1,lists$years])/100

# Calculation of employee data, assuming same working day as employed
sea_sectors[,"empe.s.un",,"CHN"] <- 
  sea_sectors[,"emp.s.un",,"CHN"] * was_w_china

sea_sectors[,"hours_worked.empe.s.hr",,"CHN"] <- 
  sea_sectors[,"hours_worked.emp.s.hr",,"CHN"] * was_w_china

# clear variable
rm(was_w_china)
