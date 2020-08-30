was_w_china <- as.data.frame(read_xlsx(paste0(getwd(),"/sourcedata/china/was_w.xlsx"), sheet = "DATA", col_names = T))
jornada_media_china <- read.csv2(file = paste0(getwd(),"/sourcedata/Nov16/China H_EMPE-EMPE.csv"), row.names = 1)
colnames(jornada_media_china) <- tolower(gsub("X","",colnames(jornada_media_china)))
