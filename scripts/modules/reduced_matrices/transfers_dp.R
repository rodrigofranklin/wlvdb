# Total transfers in direct prices ----
m_countries[lists$years,"transfers_dp",,] <-
  m_countries[lists$years,"transfers_values",,] / balance_factor

gc()