m_io[,"k_depreciation",1:nums$input,1:nums$input] <- 0
print("Finished computation of capital depreciation")


# # Distribui a depreciação do capital pela estrutura da formação bruta de capital
# m_io[,"k_depreciation",1:nums$input,1:nums$input] <- 
#   sea_sectors[,"capital_depreciation.s.us",,] %>%
#   rep(each = nums$sectors) %>%
#   rep(times = nums$years) %>%
#   newDim(c(nums$sectors, nums$countries, nums$years)) %>%
#   aperm(c(3,1,2))
# 
#   teste <- m_io_source[,1:nums$input,grep("capital", colnames(m_io_source[1,,]))] %>%
#   prop.table(2) %>%
#   t() %>%
#   rep(each = nums$sectors) %>%
#   rep(times = nums$years) %>%
#   newDim(c(nums$sectors, nums$countries, nums$years)) %>%
#   aperm(c(3,1,2))



