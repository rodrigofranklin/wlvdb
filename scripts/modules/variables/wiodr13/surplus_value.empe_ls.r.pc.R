# exploitation rate of low skilled employees
code <- "surplus_value.empe_ls.r.pc"

meta_indicators[code,"name"] <- "Rate of surplus value (low skilled)"
meta_indicators[code,"description"] <- 
  paste0("Rate of surplus value low skilled employees. It is a measure of ",
         "exploitation of labour in a capitalist relation of production.")
meta_indicators[code,"observation"] <- 
  paste0("Obtained by dividing the sum of abstract labour of low skilled ",
         "employees by the sum of labour force value of low skilled employees, ",
         "minus one.")
meta_indicators[code,"type"] <- "percent"
meta_indicators[code,"group"] <- "Rate of surplus value"
meta_indicators[code,"reverted"] <- TRUE

skill_code <- "ls"
source("scripts/modules/variables/wiodr13/surplus_value.empe_skill.r.pc.R")


