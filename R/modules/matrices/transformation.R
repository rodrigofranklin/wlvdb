print("Transforming...")

a <- nums$years
d <- nums$input
n <- 1:d

# Creates filter matrix for selection of productive sectors only.
# 1 = productive sector; 0 = non-productive sector. By multiplying the filter by the
# input-output matrix, rows of productive sectors remain.
filter <- 
  matrix(rows$productive, nrow = d, ncol = d, byrow = TRUE ) * rows$productive
print("Finished creating productive sectors filter")
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
print("Finished loading leontief intermediates")
# Step 2: calculates -(A+D)
# -(A+D) = (T+C) * <X>^(-1)
leontief_numerator <- wlv_sum_input_flows(
  m_io_source[, n, n] %>% newDim(c(a, d, d)),
  m_io[, "k_depreciation", n, n] %>% newDim(c(a, d, d))
) * rep(filter, each = a)
if (exists("wlv_contract_runtime", inherits = FALSE)) {
  leontief_numerator <- wlv_allowlisted_leontief_zero_output(
    wlv_contract_runtime,
    leontief_numerator,
    leontief,
    years = lists$years,
    inputs = lists$input,
    outputs = lists$input
  )
  leontief <- (-1) * wlv_safe_divide_runtime(
    wlv_contract_runtime,
    leontief_numerator,
    leontief,
    zero = "zero_if_both_zero",
    artifact = "m_io",
    indicator = "leontief_input_ratio",
    checkpoint = "after_matrices",
    stage = 3L,
    module = "transformation.R",
    axes = c(year = 1L, sector = 2L, output = 3L)
  )
} else {
  invalid <- leontief == 0 & leontief_numerator != 0
  if (any(invalid)) {
    stop("Leontief inputs contain a nonzero flow over zero output.", call. = FALSE)
  }
  both_zero <- leontief == 0 & leontief_numerator == 0
  leontief <- (-1) * (leontief_numerator / leontief)
  leontief[both_zero] <- 0
}

# Steo 3: adds I (indentity matrix).
leontief <- leontief + rep(diag(d), each = a)

# Step 4: inverts the matrix.
print("Inverting leontief matrix...")

leontief <- leontief %>% 
  myApply(1, solve) %>%
  newDim(c(d, d, a)) %>%
  aperm(c(3,1,2))

gc()

print("End of invertion...")

#############################.
# Calculates the labour value per unit of output
#############################.

# labour_requirements represent the amount of direct labour 
# required per unit of output 
labour_numerator <-
  sea_sectors[lists$years, "abstract_labour.emp.s.mv", , ] *
  rep(rows$productive, each = a)
labour_denominator <- sea_sectors[lists$years, "gross_output.s.us", , ]
if (exists("wlv_contract_runtime", inherits = FALSE)) {
  labour_requirements <- wlv_safe_divide_runtime(
    wlv_contract_runtime,
    labour_numerator,
    labour_denominator,
    zero = "zero_if_both_zero",
    artifact = "sea_sectors",
    indicator = "labour_requirements",
    checkpoint = "after_matrices",
    stage = 3L,
    module = "transformation.R",
    axes = c(year = 1L, sector = 2L)
  ) %>% newDim(c(a, d))
} else {
  invalid <- labour_denominator == 0 & labour_numerator != 0
  if (any(invalid)) {
    stop("Labour requirements contain nonzero labour over zero output.", call. = FALSE)
  }
  both_zero <- labour_denominator == 0 & labour_numerator == 0
  labour_requirements <- labour_numerator / labour_denominator
  labour_requirements[both_zero] <- 0
  labour_requirements <- labour_requirements %>% newDim(c(a, d))
}

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
rm(
  year, a, d, n, filter, labour_requirements, leontief,
  leontief_numerator, labour_numerator, labour_denominator
)
rm(list = intersect(
  c("invalid", "both_zero"),
  ls(envir = environment(), all.names = TRUE)
), envir = environment())
gc()
