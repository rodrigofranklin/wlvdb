# gross output in direct price

k <- 
  (sea_sectors[lists$years,"gross_output.s.us",,] %>%
     newDim(c(nums$years, nums$sectors, nums$countries)) %>%
     apply(1, sum, na.rm = TRUE)) /
  (sea_sectors[lists$years,"gross_output.s.mv",,] %>%
     newDim(c(nums$years, nums$sectors, nums$countries)) %>%
     apply(1, sum, na.rm = TRUE))

sea_sectors[lists$years,"gross_output.s.du",,] <- 
  sea_sectors[lists$years,"gross_output.s.mv",,] * rep(k, times = nums$input)
