print("Transforming...")

a <- nums$years
d <- nums$input
n <- 1:d

# Creates filter matrix for selection of productive sectors only.
# 1 = productive sector; 0 = non-productive sector. By multiplying the filter by the
# input-output matrix, rows of productive sectors remain.
filter <- 
  matrix(rows$productive, nrow = d, ncol = d, byrow = TRUE ) * rows$productive

#####.
# Calculates the inverse matrix of leontief = (I-A-D)^(-1), where:
# I => identity matrix;
# A => matrix of technical coefficients: (intermediate consumption)/total product
# D => matrix of depreciation coefficients: (depreciation)/total product
# X => Total Gross Output
# T => Intermediate consumption matrix
# C => Depreciation matrix
# Code designed to save memory, applied to all years at once.

# Step 1: Create an array of annual matrices whose columns are the total 
# product of each sector.
leontief <- 
  sea_sectors[lists$years,"gross_output.s.us",,] %>% 
  rep(times = d) %>% 
  newDim(c(a, d, d)) %>%
  aperm(c(1,3,2))

# Step 2: calculates -(A+D)
# -(A+D) = (T+C) * <X>^(-1)
leontief <- (-1) *
  (((m_io_source[,n,n] %>%
     newDim(c(a, d, d))) +
  (m_io[,"k_depreciation",n,n] %>%
     newDim(c(a, d, d)))) /
  leontief * rep(filter, each = a)) %>%
  clean

# Steo 3: adds I (indentity matrix).
leontief <- leontief + rep(diag(d), each = a)

# Step 4: inverts the matrix.
print("Inverting leontief matrix...")

leontief <- parApply(cl = my.cluster, leontief, 1, solve) %>%
  newDim(c(d, d, a)) %>%
  aperm(c(3,1,2))

gc()

print("End of invertion...")

#############################.
# Calculates the labour value per unit of output
#############################.

# labour_requirements represent the amount of direct labour 
# required per unit of output 
labour_requirements <- 
  ((sea_sectors[lists$years,"abstract_labour.emp.s.mv",,] / 
     sea_sectors[lists$years,"gross_output.s.us",,]) * 
  rep(rows$productive, each = a)) %>%
  newDim(c(a, d)) %>%
  clean

# lambda represents labour values per unit of output
# (i.e., per $ 1.00 of each sector)
lambda <- labour_requirements # assignment just to replicate the structure
for (year in 1:a) {
  lambda[year,] <-  labour_requirements[year,]%*%leontief[year,,]
}

m_io[, "values", n, 1:nums$output] <-
  m_io_source[, n, 1:nums$output] * 
  rep(lambda, times = nums$output)

print("End of transformation.")

# clear environment
rm(year, a, d, n, filter, labour_requirements, leontief)
gc()
