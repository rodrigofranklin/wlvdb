sea_sectors[,"gdp.s.us",,] <- 
  (sea_source[,"Taxes less subsidies on products purchased: Total",,] +
     sea_source[,"Other net taxes on production",,] +
     sea_source[,"Compensation of employees; wages, salaries, & employers' social contributions: Low-skilled",,] +
     sea_source[,"Compensation of employees; wages, salaries, & employers' social contributions: Medium-skilled",,] +
     sea_source[,"Compensation of employees; wages, salaries, & employers' social contributions: High-skilled",,] +
     sea_source[,"Operating surplus: Rents on land",,] +
     sea_source[,"Operating surplus: Royalties on resources",,] +
     sea_source[,"Operating surplus: Remaining net operating surplus",,] +
     sea_source[,"Operating surplus: Consumption of fixed capital",,])