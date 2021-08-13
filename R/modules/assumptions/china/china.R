# Load employment data from an external source (worldbank)
# was_w => Wage and salaried workers as a percentage of employed population

was_w_china <- as.data.frame(
  read.csv2(paste0(getwd(),"/source_data/worldbank/employment_china.csv")))
colnames(was_w_china) <- sub("X","",colnames(was_w_china))

was_w_china <- as.numeric(was_w_china[1,lists$years])/100

# Calculation of employee data, assuming same working day as employed
sea_sectors[,"employees",,"CHN"] <- 
  sea_sectors[,"employed_persons",,"CHN"] * was_w_china

sea_sectors[,"hours_employees",,"CHN"] <- 
  sea_sectors[,"hours_employed",,"CHN"] * was_w_china

# clear variable
rm(was_w_china)
