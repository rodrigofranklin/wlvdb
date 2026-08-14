# The official WIOD16 SEA has no separate employee labour-input data for China.
# Annual hours per person engaged are therefore inferred from WIOD13 H_EMP/EMP,
# mapped from ISIC Rev.3 to the 56 WIOD16 sectors. The coefficients are stored in
# thousands of hours per person; 2009-2014 repeat the WIOD13 2009 observation
# (whose published value is already equal to 2008).
parameters$description <- 
  paste0(
    "China: annual hours per person engaged were inferred from WIOD13 ",
    "H_EMP/EMP, mapped to the WIOD16 sectors; the 2009 observation was ",
    "replicated through 2014. Because WIOD16 provides no separate employee ",
    "labour input for China, all persons engaged were treated as employees. ",
    parameters$description
  )

hours_per_worker_china <- wlv_read_wiodr16_china_hours_per_worker(
  file.path("complementar", "wiodr16", "china_hours_per_worker.csv"),
  expected_codes = sectors$sector.source,
  expected_names = sectors$sector,
  expected_years = lists$years
)

persons_engaged_china <- sea_sectors[, "emp.s.un", , "CHN"]
if (anyNA(persons_engaged_china) || any(!is.finite(persons_engaged_china))) {
  stop("WIOD16 China employment must be finite before applying hours.", call. = FALSE)
}

sea_sectors[,"hours_worked.emp.s.hr",,"CHN"] <-
  persons_engaged_china * hours_per_worker_china * 1000

# Como a informação sobre salários (COMP) é igual à da renda do trabalho (LAB),
# duplicamos as informações sobre EMP e H_EMPE em EMPE e H_EMPE
sea_sectors[,"empe.s.un",,"CHN"] <- 
  sea_sectors[,"emp.s.un",,"CHN"]

sea_sectors[,"hours_worked.empe.s.hr",,"CHN"] <- 
  sea_sectors[,"hours_worked.emp.s.hr",,"CHN"]

# clear variables
rm(hours_per_worker_china, persons_engaged_china)
