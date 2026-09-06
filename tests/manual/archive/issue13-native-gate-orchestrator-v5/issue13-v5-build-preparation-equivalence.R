# Build the exhaustive cross-engine preparation equivalence manifest.
#
# This gate-construction utility records every cell, in row order, from the
# architecture-dependent normalized-source tables. Both source manifests are
# authenticated before their tables are admitted to the sealed profile.

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 4L) {
  stop(paste(
    "Usage: issue13-v5-build-preparation-equivalence.R",
    "<baseline-source-data> <candidate-source-data>",
    "<harness-runtime-root> <output.json>"
  ), call. = FALSE)
}

baseline_root <- normalizePath(arguments[[1L]], winslash = "/", mustWork = TRUE)
candidate_root <- normalizePath(arguments[[2L]], winslash = "/", mustWork = TRUE)
harness_root <- normalizePath(arguments[[3L]], winslash = "/", mustWork = TRUE)
output_path <- normalizePath(arguments[[4L]], winslash = "/", mustWork = FALSE)

sys.source(
  file.path(harness_root, "issue13-prep-paper-lib.R"),
  envir = environment(), chdir = FALSE
)
sys.source(
  file.path(harness_root, "issue13-evidence-harness", "issue13-lib.R"),
  envir = environment(), chdir = FALSE
)
wlv_gate_require_namespaces("jsonlite")

sources <- c("wiodr13", "wiodr16")
artifacts <- c("_unit_contract.csv", "_source_manifest.csv")
expected <- list(
  baseline = list(
    wiodr13 = list(
      source_generation_id =
        "65691585592c9cb6dc628c46606f004113f808e5b74c511c89678fae32032e2d",
      contract_sha256 =
        "f7e04664e357d6a334685e48eced6428dfdd410f5b9811785a0ad0f696cc65eb",
      `_unit_contract.csv` =
        "3a6b8a977edfd02dfde6d91971afdeb51f60719d020a958fb13f6804955790bf",
      `_source_manifest.csv` =
        "cd3ee98c7b823b1efa9b1272dca660a3977cc4a185b033263c2bef09cc1f73a8"
    ),
    wiodr16 = list(
      source_generation_id =
        "f135fddb4723ba3cdf29164cf1b7ec006693cc201feaf2063f91fa104e942a7a",
      contract_sha256 =
        "94b9f78e8977001fab92e8fa8528aea5b97a3f22809bec58a16a56f413a6acf7",
      `_unit_contract.csv` =
        "0e6da6f4f20afb9accf4134ded6b2a6e88068254ed8bae209402d36b329e6e2c",
      `_source_manifest.csv` =
        "091183d74d97f5bc22209e57be0314c5ea5e510ae3573eaf2b342237de903aa9"
    )
  ),
  candidate = list(
    wiodr13 = list(
      source_generation_id =
        "b16a64edd8f3cdf117002fda011e1ba19f17e3fa72936671bb98dffeb0207856",
      contract_sha256 =
        "1f2462835e70d5681d7a5b9b29be5f0598cdb35a9abd72d3d147a6636ae5c905",
      `_unit_contract.csv` =
        "49d5706ba4c290322d245eeb7cf0a8751e9927e5b4097a8da50516af71ba0707",
      `_source_manifest.csv` =
        "b454f0f05890374cebde8b1b3222da4b4b63b887f67283fe12c97a351adc0bb8"
    ),
    wiodr16 = list(
      source_generation_id =
        "1f747ab8d53abe8cc674b0842796a5c9b936b036a79b48715b9e04734f949976",
      contract_sha256 =
        "3b23ab671df4905dee50b35efd8dff8d4897f65f2b74a2677d7614d9137e801a",
      `_unit_contract.csv` =
        "8cb2dd77575ca0272cbdddea4be2d062bce998e1bfea21de375819cadabcbdc3",
      `_source_manifest.csv` =
        "28dc13d3abb9856fb984b01eb60379e213e6e0cfae58e8fb08c3b882c19c1a35"
    )
  )
)

normalize_table <- function(value) {
  if (!is.data.frame(value) || !length(names(value)) || anyDuplicated(names(value))) {
    stop("Preparation equivalence received an invalid table.", call. = FALSE)
  }
  result <- as.data.frame(lapply(value, function(column) {
    column <- as.character(column)
    column[is.na(column)] <- ""
    enc2utf8(column)
  }), stringsAsFactors = FALSE, check.names = FALSE)
  rownames(result) <- NULL
  result
}

encode_table <- function(value) {
  list(
    columns = as.list(names(value)),
    rows = lapply(seq_len(nrow(value)), function(index) {
      as.list(unname(vapply(
        value[index, , drop = FALSE],
        function(column) as.character(column[[1L]]), character(1L)
      )))
    })
  )
}

table_sha256 <- function(value) {
  encoded <- encode_table(value)
  wlv13_sha256_text(as.character(jsonlite::toJSON(
    encoded, auto_unbox = TRUE, digits = NA, null = "null", na = "string"
  )))
}

build_arm <- function(root, arm, source) {
  normalized <- file.path(root, source, "normalized")
  verified <- wlv_gate_verify_source_manifest(normalized)
  if (!isTRUE(verified$passed)) {
    stop(sprintf("Prepared source manifest failed authentication: %s/%s.",
      arm, source), call. = FALSE
    )
  }
  specification <- expected[[arm]][[source]]
  if (!identical(verified$source_generation_id,
      specification$source_generation_id) ||
      !identical(verified$contract_sha256, specification$contract_sha256)) {
    stop(sprintf("Prepared source identity changed: %s/%s.", arm, source),
      call. = FALSE
    )
  }
  artifact_profiles <- lapply(artifacts, function(artifact) {
    path <- file.path(normalized, artifact)
    observed_sha256 <- wlv_gate_sha256(path)
    if (!identical(observed_sha256, specification[[artifact]])) {
      stop(sprintf("Prepared artifact changed: %s/%s/%s.",
        arm, source, artifact), call. = FALSE
      )
    }
    value <- if (identical(artifact, "_source_manifest.csv")) {
      verified$table
    } else {
      wlv_gate_read_character_csv(path)
    }
    value <- normalize_table(value)
    list(
      artifact = artifact,
      file_sha256 = observed_sha256,
      table_sha256 = table_sha256(value),
      table = encode_table(value)
    )
  })
  names(artifact_profiles) <- NULL
  list(
    source_generation_id = verified$source_generation_id,
    contract_id = verified$contract_id,
    contract_version = verified$contract_version,
    contract_sha256 = verified$contract_sha256,
    artifacts = artifact_profiles
  )
}

profiles <- lapply(sources, function(source) {
  list(
    source = source,
    baseline = build_arm(baseline_root, "baseline", source),
    candidate = build_arm(candidate_root, "candidate", source)
  )
})

manifest <- list(
  schema = "wlv-issue13-preparation-equivalence/1",
  baseline_commit = "cc2c86189a06676bcb9f0e05e08033d710a92509",
  candidate_commit_at_derivation =
    "a70cef8ef7ec19b329dd60cc2a10f49bf0c9533b",
  derivation = paste(
    "Exact authenticated normalized-source tables paired by source and arm;",
    "no field, row, wildcard, tolerance or row-order projection."
  ),
  sources = as.list(sources),
  artifacts = as.list(artifacts),
  profiles = profiles
)

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(
  manifest, output_path, auto_unbox = TRUE, pretty = TRUE,
  null = "null", na = "string"
)
observed <- jsonlite::fromJSON(
  output_path, simplifyVector = FALSE, simplifyDataFrame = FALSE,
  simplifyMatrix = FALSE
)
reference <- jsonlite::fromJSON(
  jsonlite::toJSON(
    manifest, auto_unbox = TRUE, null = "null", na = "string"
  ),
  simplifyVector = FALSE, simplifyDataFrame = FALSE,
  simplifyMatrix = FALSE
)
if (!identical(observed, reference)) {
  stop("Preparation equivalence manifest failed its JSON round trip.",
    call. = FALSE
  )
}

cat(sprintf(
  "issue13 preparation equivalence: %d sources, %d artifact pairs\n",
  length(profiles), length(profiles) * length(artifacts)
))
