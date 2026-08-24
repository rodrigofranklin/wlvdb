wlv_test_scientific_profile <- function(
    runtime_environment,
    method,
    source,
    years = "2000") {
  runtime_environment$wlv_scientific_profile_contract(
    id = paste0(method, "_scientific_test_v1"),
    method = method,
    source = source,
    output_profile = paste0(method, "_output_test"),
    leontief_zero = list(
      id = paste0(method, "_zero_test_v1"),
      exception_count = 0L,
      coordinate_md5 = "d41d8cd98f00b204e9800998ecf8427e",
      counts = data.frame(
        year = character(), output = character(),
        exception_count = integer(), stringsAsFactors = FALSE
      )
    ),
    leontief_signed = list(
      id = paste0(method, "_signed_test_v1"),
      rows = data.frame(
        year = as.character(years),
        coefficient_negative_count = rep(0L, length(years)),
        certificate_type = rep("productivity_nonnegative", length(years)),
        stringsAsFactors = FALSE
      )
    ),
    nonfinite_resolution = list(
      id = "nonfinite_test_none_v1",
      action = "reject",
      expected_count = 0L,
      groups = data.frame(
        binding = character(), indicator = character(),
        kind = character(), module = character(),
        expected_count = integer(), coordinate_sha256 = character(),
        stringsAsFactors = FALSE
      ),
      rules = data.frame(
        artifact = character(), indicator = character(),
        year = character(), country = character(), sector = character(),
        from = character(), to = character(), stringsAsFactors = FALSE
      )
    )
  )
}

wlv_test_contract_runtime <- function(
    runtime_environment,
    method,
    source,
    policy,
    years = "2000") {
  runtime_environment$wlv_new_contract_runtime(
    method = method,
    source = source,
    policy = policy,
    scientific_profile = wlv_test_scientific_profile(
      runtime_environment,
      method,
      source,
      years
    )
  )
}
