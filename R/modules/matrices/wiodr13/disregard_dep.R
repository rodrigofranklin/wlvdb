#Disregards depreciation - initially for course/paper n. 3

m_io[year,"k_depreciation",
     1:nums$input,1:nums$input] <- 0


# Calcula as informações setoriais, por país e para o mundo
sea_sectors[year,"depreciation",,] <- 0