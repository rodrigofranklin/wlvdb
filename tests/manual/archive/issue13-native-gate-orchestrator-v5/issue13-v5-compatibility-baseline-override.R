# V5 compatibility-oracle policy for Issue #13.
#
# The immutable scientific origin remains the merge of Issue #12. The runtime
# used to execute the legacy oracle is one clean, direct child authenticated by
# its complete binary diff. The strict cc2 smoke remains separate negative
# evidence and is never imported as final scenario evidence.

wlv13_v5_baseline_base_commit <-
  "cc2c86189a06676bcb9f0e05e08033d710a92509"
wlv13_v5_compatibility_profile <- "compatibility-oracle-cc2"
wlv13_v5_compatibility_runtime <-
  "e2f4d6dae9a6d35c966b305fabac52e489faa3e7"
wlv13_v5_compatibility_patch_sha256 <-
  "9f9b878f8e557973127e6260a0f224c868a0c4e8dc2db52dd6aa3f7131f28cd9"
wlv13_v5_compatibility_patch_id <-
  "253ca5f1397132f94e3432264084a37395c60ec3"

wlv13_validate_baseline_runtime_matrix <- function(index, candidate_commit) {
  candidate_commit <- wlv13_scalar_text(
    candidate_commit,
    "candidate_commit",
    "^[0-9a-f]{40}$"
  )
  if (!is.list(index) ||
      !identical(index$baseline_base_commit,
        wlv13_v5_baseline_base_commit)) {
    stop("V5 requires the exact Issue #12 baseline origin.", call. = FALSE)
  }
  if (identical(candidate_commit, wlv13_v5_baseline_base_commit)) {
    stop("The V5 candidate must differ from the baseline origin.",
      call. = FALSE
    )
  }

  if (!is.list(index$profiles) ||
      !identical(names(index$profiles), wlv13_v5_compatibility_profile)) {
    stop(
      "V5 permits exactly one authenticated compatibility-oracle profile.",
      call. = FALSE
    )
  }
  profile <- index$profiles[[wlv13_v5_compatibility_profile]]
  profile_ok <-
    identical(profile$id, wlv13_v5_compatibility_profile) &&
    identical(profile$inventory_value, wlv13_v5_compatibility_profile) &&
    identical(profile$source_commit, wlv13_v5_compatibility_runtime) &&
    identical(profile$runtime_commit, wlv13_v5_compatibility_runtime) &&
    !identical(profile$runtime_commit, candidate_commit) &&
    identical(profile$run_dirty, FALSE) &&
    is.character(profile$overlay_patch_path) &&
    length(profile$overlay_patch_path) == 1L &&
    nzchar(profile$overlay_patch_path) &&
    is.character(profile$overlay_patch_sha256) &&
    length(profile$overlay_patch_sha256) == 1L &&
    identical(profile$overlay_patch_sha256,
      wlv13_v5_compatibility_patch_sha256) &&
    is.character(profile$overlay_patch_id) &&
    length(profile$overlay_patch_id) == 1L &&
    identical(profile$overlay_patch_id, wlv13_v5_compatibility_patch_id)
  if (!profile_ok) {
    stop("The V5 compatibility oracle is not fully authenticated.",
      call. = FALSE
    )
  }

  expected_ids <- sort(
    wlv13_scenario_ids()[startsWith(wlv13_scenario_ids(), "baseline/")],
    method = "radix"
  )
  if (!is.list(index$scenarios) ||
      !identical(names(index$scenarios), expected_ids)) {
    stop("V5 baseline scenario coverage differs from the canonical matrix.",
      call. = FALSE
    )
  }
  valid <- vapply(index$scenarios, function(record) {
    identical(record$runtime_commit, profile$runtime_commit) &&
      identical(record$profile_id, wlv13_v5_compatibility_profile)
  }, logical(1L))
  if (!all(valid)) {
    stop(
      "Every V5 baseline scenario must use the single compatibility oracle.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}
