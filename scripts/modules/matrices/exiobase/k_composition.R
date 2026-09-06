
# Converte toda a matriz para USD
m_io_source <- sea_sectors[lists$years,"exchange.r.us",1,1] * m_io_source

m_io[,"k_composition",1:nums$input,1:nums$input] <- 0
print("Finished computation of capital composition")