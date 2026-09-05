# Focused self-test for issue13-main-preparation-equivalence.R.
# It reads manifests, contracts, and FST sidecars only; it never reads FST data.

script_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_argument)) {
  stop("Run this self-test with Rscript.", call. = FALSE)
}
script_path <- normalizePath(
  sub("^--file=", "", script_argument[[1L]]),
  winslash = "/",
  mustWork = TRUE
)
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 3L) {
  stop(
    paste(
      "Expected: <harness-root> <baseline-e2f4-root>",
      "<candidate-6549597-root>."
    ),
    call. = FALSE
  )
}
harness_root <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
baseline_root <- normalizePath(arguments[[2L]], winslash = "/", mustWork = TRUE)
candidate_root <- normalizePath(arguments[[3L]], winslash = "/", mustWork = TRUE)

namespace <- new.env(parent = baseenv())
sys.source(
  file.path(dirname(harness_root), "issue13-prep-paper-lib.R"),
  envir = namespace,
  chdir = FALSE
)
sys.source(
  file.path(harness_root, "issue13-lib.R"),
  envir = namespace,
  chdir = FALSE
)
sys.source(
  file.path(harness_root, "issue13-v5-preparation-equivalence.R"),
  envir = namespace,
  chdir = FALSE
)
assign(
  "preparation_equivalence_path",
  file.path(harness_root, "issue13-v5-preparation-equivalence.json"),
  envir = namespace
)
sys.source(script_path <- file.path(
  dirname(script_path), "issue13-main-preparation-equivalence.R"
), envir = namespace, chdir = FALSE)

checks <- 0L
expect_true <- function(value, label) {
  if (!isTRUE(value)) {
    stop(sprintf("Preparation equivalence self-test failed: %s.", label),
      call. = FALSE)
  }
  checks <<- checks + 1L
}
expect_false <- function(value, label) {
  if (isTRUE(value)) {
    stop(sprintf("Preparation equivalence self-test false PASS: %s.", label),
      call. = FALSE)
  }
  checks <<- checks + 1L
}

profile_path <- get(
  "preparation_equivalence_path", envir = namespace, inherits = FALSE
)
profile_hash_before <- namespace$wlv13_v5p_file_sha256(profile_path)
metadata <- namespace$wlv13_main_install_preparation_equivalence(
  namespace, baseline_root, candidate_root
)
binding <- get(
  ".wlv13_main_preparation_equivalence_binding",
  envir = namespace,
  inherits = FALSE
)
expect_true(
  identical(profile_hash_before, namespace$wlv13_v5p_file_sha256(profile_path)),
  "historical profile remained byte-identical"
)
expect_true(
  identical(metadata$derived_profile_sha256,
    binding$metadata$derived_profile_sha256),
  "installer returned the bound derived profile"
)

for (source in c("wiodr13", "wiodr16")) {
  baseline_normalized <- file.path(
    baseline_root, "source_data", source, "normalized"
  )
  candidate_normalized <- file.path(
    candidate_root, "source_data", source, "normalized"
  )
  baseline_manifest_path <- file.path(
    baseline_normalized, "_source_manifest.csv"
  )
  candidate_manifest_path <- file.path(
    candidate_normalized, "_source_manifest.csv"
  )
  baseline_manifest <- namespace$wlv_gate_read_character_csv(
    baseline_manifest_path
  )
  candidate_manifest <- namespace$wlv_gate_read_character_csv(
    candidate_manifest_path
  )
  comparison <- namespace$wlv13_v5p_compare_source(
    baseline_normalized,
    candidate_normalized,
    source,
    baseline_manifest,
    candidate_manifest,
    profile_path
  )
  expect_true(comparison$passed, paste(source, "derived source comparison"))
  expect_true(
    identical(
      comparison$source_manifest$comparison_mode,
      "sealed-derived-versioned-source-manifest-equivalence"
    ),
    paste(source, "derived comparison identity")
  )
  expect_true(
    identical(
      comparison$source_manifest$derived_profile_sha256,
      metadata$derived_profile_sha256
    ),
    paste(source, "derived profile hash")
  )

  profile_index <- match(source, vapply(
    binding$derived_manifest$profiles, `[[`, character(1L), "source"
  ))
  derived_profile <- binding$derived_manifest$profiles[[profile_index]]
  expected_manifest_artifact <- namespace$wlv13_main_prep_profile_artifact(
    derived_profile, "baseline", "_source_manifest.csv"
  )
  expected_manifest <- namespace$wlv13_v5p_decode_table(
    expected_manifest_artifact$table,
    paste0(source, "/derived-baseline/_source_manifest.csv")
  )

  changed_field <- expected_manifest
  changed_field$artifact_role[[1L]] <- paste0(
    changed_field$artifact_role[[1L]], "-changed"
  )
  expect_false(
    namespace$wlv13_v5p_compare_artifact(
      baseline_manifest_path,
      changed_field,
      expected_manifest_artifact,
      paste(source, "changed field")
    )$passed,
    paste(source, "changed manifest field")
  )

  changed_order <- expected_manifest[
    c(2L, 1L, seq.int(3L, nrow(expected_manifest))), , drop = FALSE
  ]
  rownames(changed_order) <- NULL
  expect_false(
    namespace$wlv13_v5p_compare_artifact(
      baseline_manifest_path,
      changed_order,
      expected_manifest_artifact,
      paste(source, "changed order")
    )$passed,
    paste(source, "changed manifest order")
  )

  changed_sha <- expected_manifest
  sha_row <- match("m_io.fst.meta", changed_sha$artifact)
  changed_sha$sha256[[sha_row]] <- paste0(
    if (startsWith(changed_sha$sha256[[sha_row]], "0")) "1" else "0",
    substring(changed_sha$sha256[[sha_row]], 2L)
  )
  expect_false(
    namespace$wlv13_v5p_compare_artifact(
      baseline_manifest_path,
      changed_sha,
      expected_manifest_artifact,
      paste(source, "changed SHA")
    )$passed,
    paste(source, "changed sidecar SHA")
  )

  expected_unit_artifact <- namespace$wlv13_main_prep_profile_artifact(
    derived_profile, "baseline", "_unit_contract.csv"
  )
  baseline_unit_path <- file.path(baseline_normalized, "_unit_contract.csv")
  changed_unit <- namespace$wlv_gate_read_character_csv(baseline_unit_path)
  changed_unit[[1L]][[1L]] <- paste0(changed_unit[[1L]][[1L]], "-changed")
  expect_false(
    namespace$wlv13_v5p_compare_artifact(
      baseline_unit_path,
      changed_unit,
      expected_unit_artifact,
      paste(source, "changed unit contract")
    )$passed,
    paste(source, "changed unit contract")
  )

  for (name in c("m_io.fst", "sea.fst")) {
    left_path <- file.path(baseline_normalized, name)
    right_path <- file.path(candidate_normalized, name)
    left_contract <- namespace$wlv_gate_fst_sidecar(left_path)
    right_contract <- namespace$wlv_gate_fst_sidecar(right_path)
    payload_row <- match(name, baseline_manifest$artifact)
    candidate_payload_row <- match(name, candidate_manifest$artifact)
    left_sha256 <- baseline_manifest$sha256[[payload_row]]
    right_sha256 <- candidate_manifest$sha256[[candidate_payload_row]]
    expect_true(
      namespace$wlv13_main_prep_sidecar_policy(
        left_contract, right_contract, left_sha256, right_sha256
      ),
      paste(source, name, "versioned exact sidecars")
    )
    expect_true(
      identical(namespace$wlv13_main_prep_sidecar_format(left_contract),
        "versioned-v1") &&
        identical(namespace$wlv13_main_prep_sidecar_format(right_contract),
          "versioned-v1"),
      paste(source, name, "real sidecar formats")
    )

    bad_schema <- left_contract
    bad_schema$schema_version <- "2"
    expect_false(
      namespace$wlv13_main_prep_sidecar_policy(
        bad_schema, right_contract, left_sha256, right_sha256
      ),
      paste(source, name, "schema mutation")
    )
    bad_legacy <- left_contract
    bad_legacy$legacy <- TRUE
    expect_false(
      namespace$wlv13_main_prep_sidecar_policy(
        bad_legacy, right_contract, left_sha256, right_sha256
      ),
      paste(source, name, "legacy sidecar")
    )
    bad_raw <- left_contract
    bad_raw$raw[[2L]][[1L]] <- paste0(bad_raw$raw[[2L]][[1L]], "#")
    expect_false(
      namespace$wlv13_main_prep_sidecar_policy(
        bad_raw, right_contract, left_sha256, right_sha256
      ),
      paste(source, name, "sidecar mutation")
    )
    changed_payload_sha256 <- paste0(
      if (startsWith(left_sha256, "0")) "1" else "0",
      substring(left_sha256, 2L)
    )
    expect_false(
      namespace$wlv13_main_prep_sidecar_policy(
        left_contract, right_contract, changed_payload_sha256, right_sha256
      ),
      paste(source, name, "payload SHA mutation")
    )
  }
}

cat(as.character(jsonlite::toJSON(list(
  schema = "wlv-issue13-main-preparation-equivalence-selftest/1",
  passed = TRUE,
  checks = checks,
  binding = metadata
), auto_unbox = TRUE, pretty = TRUE, digits = NA, null = "null")), "\n")
