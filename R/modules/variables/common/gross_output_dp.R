# gross output in direct price

k <- 
  (sea_sectors[lists$years,"gross_output_mp",,] %>%
     newDim(c(nums$years, nums$sectors, nums$countries)) %>%
     apply(1, sum, na.rm = TRUE)) /
  (sea_sectors[lists$years,"gross_output_values",,] %>%
     newDim(c(nums$years, nums$sectors, nums$countries)) %>%
     apply(1, sum, na.rm = TRUE))

sea_sectors[lists$years,"gross_output_dp",,] <- 
  sea_sectors[lists$years,"gross_output_values",,] * rep(k, times = nums$input)
