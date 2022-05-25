# Load employment data from an external source (worldbank)
# was_w => Wage and salaried workers as a percentage of employed population
was_w_china <- as.data.frame(
  read.csv2(paste0(getwd(),"/source_data/worldbank/employment_china.csv")))
colnames(was_w_china) <- sub("X","",colnames(was_w_china))

was_w_china <- as.numeric(was_w_china[1,lists$years])/100

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

# Calculation of employee data, assuming same working day as employed
sea_sectors[,"empe.s.un",,"CHN"] <- 
  sea_sectors[,"emp.s.un",,"CHN"] * was_w_china

sea_sectors[,"hours_worked.empe.s.hr",,"CHN"] <- 
  sea_sectors[,"hours_worked.emp.s.hr",,"CHN"] * was_w_china


# clear variable
rm(was_w_china, working_day_china)
