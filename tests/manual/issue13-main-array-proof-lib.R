# Exact reuse of authenticated FST-array comparison proofs for issue #13.
#
# This file is deliberately a hook, not a replacement comparator.  It must be
# loaded after the sealed comparison libraries.  A cache hit replaces only
# wlv13_compare_fst_array(); inventory, provenance, sidecar/schema parsing,
# non-FST comparisons, final policy evaluation, and the before/after inventory
# checks remain owned by the original comparator.

wlv13_ap_approved_cache_sha256 <-
  "2490e32895d34ea9029e2a24182bcbc609fb70d345329830508d35a6294d2326"

wlv13_ap_scalar <- function(value, name, pattern = NULL) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value) || (!is.null(pattern) && !grepl(pattern, value))) {
    stop(sprintf("Invalid array-proof %s.", name), call. = FALSE)
  }
  enc2utf8(value)
}

wlv13_ap_bool <- function(value, expected, name) {
  if (!is.logical(value) || length(value) != 1L || is.na(value) ||
      !identical(value, expected)) {
    stop(sprintf("Invalid array-proof %s.", name), call. = FALSE)
  }
  invisible(value)
}

wlv13_ap_hex <- function(value, name) {
  wlv13_ap_scalar(value, name, "^[0-9a-f]{64}$")
}

wlv13_ap_length_token <- function(value) {
  value <- enc2utf8(value)
  paste0(nchar(value, type = "bytes"), ":", value)
}

# Stable, type-aware encoding used only for proof identities.  It avoids JSON
# object-order and integer/double ambiguities and includes names and NULLs.
wlv13_ap_token <- function(value) {
  if (is.null(value)) return("N")
  if (is.data.frame(value)) {
    stop("Data frames are not valid array-proof key components.", call. = FALSE)
  }
  attributes_value <- attributes(value)
  attributes_token <- if (is.null(attributes_value)) {
    "R0:"
  } else {
    labels <- names(attributes_value)
    pieces <- vapply(seq_along(attributes_value), function(index) {
      paste0(wlv13_ap_length_token(labels[[index]]),
        wlv13_ap_length_token(wlv13_ap_token(attributes_value[[index]])))
    }, character(1L))
    paste0("R", length(attributes_value), ":", paste0(pieces, collapse = ""))
  }
  if (is.list(value)) {
    pieces <- vapply(seq_along(value), function(index) {
      wlv13_ap_length_token(wlv13_ap_token(value[[index]]))
    }, character(1L))
    return(paste0("A", length(value), ":", paste0(pieces, collapse = ""),
      attributes_token))
  }
  if (is.character(value)) {
    pieces <- vapply(value, function(item) {
      if (is.na(item)) "X" else paste0("V", wlv13_ap_length_token(item))
    }, character(1L), USE.NAMES = FALSE)
    return(paste0("C", length(value), ":", paste0(pieces, collapse = ""),
      attributes_token))
  }
  if (is.logical(value)) {
    pieces <- ifelse(is.na(value), "X", ifelse(value, "T", "F"))
    return(paste0("L", length(value), ":", paste0(pieces, collapse = ""),
      attributes_token))
  }
  if (is.integer(value)) {
    pieces <- ifelse(is.na(value), "X", as.character(value))
    return(paste0("I", length(value), ":", paste0(
      vapply(pieces, wlv13_ap_length_token, character(1L)), collapse = ""
    ), attributes_token))
  }
  if (is.numeric(value)) {
    pieces <- vapply(value, function(item) {
      if (is.na(item)) return(if (is.nan(item)) "NaN" else "NA")
      if (is.infinite(item)) return(if (item > 0) "+Inf" else "-Inf")
      sprintf("%a", item)
    }, character(1L))
    return(paste0("D", length(value), ":", paste0(
      vapply(pieces, wlv13_ap_length_token, character(1L)), collapse = ""
    ), attributes_token))
  }
  stop(sprintf("Unsupported array-proof key type: %s.",
    paste(class(value), collapse = "/")), call. = FALSE)
}

wlv13_ap_sha <- function(value) {
  wlv13_sha256_text(wlv13_ap_token(value))
}

wlv13_ap_file_size <- function(path, name) {
  details <- file.info(path)
  if (nrow(details) != 1L || isTRUE(details$isdir) || is.na(details$size)) {
    stop(sprintf("Invalid array-proof %s file.", name), call. = FALSE)
  }
  as.numeric(details$size)
}

wlv13_ap_sidecar <- function(value, payload_sha, name) {
  if (!is.list(value) || !identical(names(value), c(
      "dimensions", "dimnames", "expected_length", "embedded_sha256"
    ))) {
    stop(sprintf("Invalid array-proof %s sidecar.", name), call. = FALSE)
  }
  dimensions <- value$dimensions
  if (!is.integer(dimensions) || !length(dimensions) || anyNA(dimensions) ||
      any(dimensions <= 0L) || !is.list(value$dimnames) ||
      length(value$dimnames) != length(dimensions)) {
    stop(sprintf("Invalid array-proof %s sidecar dimensions.", name),
      call. = FALSE)
  }
  for (axis in seq_along(dimensions)) {
    labels <- value$dimnames[[axis]]
    if (!is.null(labels) && (!is.character(labels) ||
        length(labels) != dimensions[[axis]] || anyNA(labels) ||
        anyDuplicated(labels))) {
      stop(sprintf("Invalid array-proof %s sidecar axis %d.", name, axis),
        call. = FALSE)
    }
  }
  expected <- prod(as.numeric(dimensions))
  if (!is.numeric(value$expected_length) || length(value$expected_length) != 1L ||
      is.na(value$expected_length) || !is.finite(value$expected_length) ||
      !identical(as.numeric(value$expected_length), expected)) {
    stop(sprintf("Invalid array-proof %s sidecar length.", name), call. = FALSE)
  }
  embedded <- value$embedded_sha256
  if (!is.null(embedded) &&
      !identical(wlv13_ap_hex(embedded, paste(name, "embedded SHA-256")),
        payload_sha)) {
    stop(sprintf("Invalid array-proof %s embedded payload binding.", name),
      call. = FALSE)
  }
  list(
    dimensions = dimensions,
    dimnames = value$dimnames,
    expected_length = as.numeric(value$expected_length),
    embedded_sha256 = embedded
  )
}

wlv13_ap_schema <- function(value, name) {
  fields <- c("nrOfRows", "columnNames", "columnTypes", "columnBaseTypes")
  if (!is.list(value) || !all(fields %in% names(value))) {
    stop(sprintf("Invalid array-proof %s FST schema.", name), call. = FALSE)
  }
  schema <- value[fields]
  if (!is.numeric(schema$nrOfRows) || length(schema$nrOfRows) != 1L ||
      is.na(schema$nrOfRows) || !is.character(schema$columnNames) ||
      !length(schema$columnNames) || anyNA(schema$columnNames) ||
      anyDuplicated(schema$columnNames)) {
    stop(sprintf("Invalid array-proof %s FST schema values.", name),
      call. = FALSE)
  }
  schema
}

wlv13_ap_descriptor <- function(value, side) {
  if (!is.list(value) || !identical(value$type, "fst_array")) {
    stop(sprintf("Invalid array-proof %s descriptor.", side), call. = FALSE)
  }
  payload_sha <- wlv13_ap_hex(value$sha256,
    paste(side, "payload SHA-256"))
  sidecar <- wlv13_ap_sidecar(value$sidecar, payload_sha, side)
  schema <- wlv13_ap_schema(value$fst_metadata, side)
  if (!identical(as.numeric(schema$nrOfRows), sidecar$expected_length)) {
    stop(sprintf("Array-proof %s schema disagrees with its sidecar.", side),
      call. = FALSE)
  }
  list(
    payload_sha256 = payload_sha,
    payload_size_bytes = format(wlv13_ap_file_size(value$path,
      paste(side, "payload")), scientific = FALSE, trim = TRUE),
    role = wlv13_ap_scalar(value$role, paste(side, "role")),
    meta_role = wlv13_ap_scalar(value$meta_role, paste(side, "meta role")),
    dimensions = lapply(sidecar$dimensions, as.integer),
    expected_length = format(sidecar$expected_length,
      scientific = FALSE, trim = TRUE),
    sidecar_semantics = wlv13_ap_token(sidecar),
    fst_schema_semantics = wlv13_ap_token(schema)
  )
}

wlv13_ap_algorithm_records <- function(value) {
  expected <- c(
    "issue13-evidence-harness/issue13-lib.R",
    "issue13-prep-paper-lib.R",
    "issue13-evidence-harness/issue13-compare-lib.R",
    "issue13-evidence-harness/issue13-v5-difference-fingerprint.R",
    "issue13-evidence-harness/issue13-v5-compare-override.R",
    "issue13-evidence-harness/issue13-v5-diagnostics-override.R",
    "issue13-evidence-harness/issue13-compare-results.R"
  )
  if (!is.list(value) || length(value) != length(expected)) {
    stop("Invalid array-proof algorithm record count.", call. = FALSE)
  }
  records <- lapply(value, function(record) {
    if (!is.list(record) || !setequal(names(record), c("path", "sha256"))) {
      stop("Invalid array-proof algorithm record.", call. = FALSE)
    }
    list(
      path = wlv13_ap_scalar(record$path, "algorithm path"),
      sha256 = wlv13_ap_hex(record$sha256, "algorithm SHA-256")
    )
  })
  paths <- vapply(records, `[[`, character(1L), "path")
  if (!identical(paths, expected) || anyDuplicated(paths)) {
    stop("Array-proof algorithm records are incomplete or unordered.",
      call. = FALSE)
  }
  records
}

wlv13_ap_engine_pair <- function(value) {
  if (!is.list(value) || !setequal(names(value), c("candidate", "baseline"))) {
    stop("Array-proof engine pair is missing.", call. = FALSE)
  }
  lapply(c("candidate", "baseline"), function(side) {
    record <- value[[side]]
    if (!is.list(record)) {
      stop(sprintf("Array-proof %s engine identity is missing.", side),
        call. = FALSE)
    }
    expected <- wlv13_ap_scalar(record$expected_commit,
      paste(side, "expected commit"), "^[0-9a-f]{40}$")
    observed <- wlv13_ap_scalar(record$observed_commit,
      paste(side, "observed commit"), "^[0-9a-f]{40}$")
    if (!identical(expected, observed)) {
      stop(sprintf("Array-proof %s engine commits disagree.", side),
        call. = FALSE)
    }
    list(
      side = side,
      arm = wlv13_ap_scalar(record$arm, paste(side, "arm")),
      method = wlv13_ap_scalar(record$method, paste(side, "method")),
      commit = expected
    )
  })
}

wlv13_ap_key_document <- function(left, right, chunk_rows, comparison_mode,
                                  context, engine_pair) {
  if (!identical(left$key, right$key)) {
    stop("Array-proof descriptors have different logical keys.", call. = FALSE)
  }
  chunk_rows <- wlv13_integer(chunk_rows, "array-proof chunk_rows", 1L)
  list(
    schema = "wlv-issue13-main-array-proof-key/1",
    logical_key = wlv13_ap_scalar(left$key, "logical key"),
    candidate = wlv13_ap_descriptor(left, "candidate"),
    baseline = wlv13_ap_descriptor(right, "baseline"),
    chunk_rows = chunk_rows,
    comparison_mode = wlv13_ap_scalar(comparison_mode, "comparison mode"),
    engine_pair = wlv13_ap_engine_pair(engine_pair),
    config_sha256 = wlv13_ap_hex(context$config_sha256,
      "config SHA-256"),
    science_tooling_binding_sha256 = wlv13_ap_hex(
      context$science_tooling_binding_sha256, "science binding SHA-256"
    ),
    comparison_binding_sha256 = wlv13_ap_hex(
      context$comparison_binding_sha256, "comparison binding SHA-256"
    ),
    algorithms = wlv13_ap_algorithm_records(context$algorithms)
  )
}

wlv13_ap_result <- function(record, key_document) {
  result <- record$proof
  required_summary <- c(
    "passed", "same_dimensions", "same_dimnames", "same_payload_schema",
    "dimensions", "mismatch_count", "difference_sha256",
    "maximum_absolute_difference", "maximum_coordinate",
    "candidate_at_maximum", "baseline_at_maximum",
    "first_mismatch_coordinate", "first_candidate_state",
    "first_baseline_state", "first_candidate_value", "first_baseline_value"
  )
  if (!is.list(result) || !setequal(names(result),
      c("summary", "transitions", "indicator_differences")) ||
      !is.list(result$summary) ||
      !identical(names(result$summary), required_summary)) {
    stop("Array-proof result envelope is invalid.", call. = FALSE)
  }
  summary <- result$summary
  for (field in c("passed", "same_dimensions", "same_dimnames",
      "same_payload_schema")) {
    wlv13_ap_bool(summary[[field]], TRUE, paste("summary", field))
  }
  if (!is.numeric(summary$mismatch_count) ||
      !identical(as.numeric(summary$mismatch_count), 0) ||
      !identical(summary$dimensions, key_document$candidate$dimensions) ||
      !identical(summary$dimensions, key_document$baseline$dimensions) ||
      !identical(wlv13_ap_hex(summary$difference_sha256,
        "difference SHA-256"), summary$difference_sha256) ||
      !identical(summary$maximum_absolute_difference, "0e+00") ||
      !identical(summary$first_mismatch_coordinate, "") ||
      !identical(summary$first_candidate_state, "") ||
      !identical(summary$first_baseline_state, "") ||
      !identical(summary$first_candidate_value, "") ||
      !identical(summary$first_baseline_value, "")) {
    stop("Array-proof summary is not an exact zero-difference proof.",
      call. = FALSE)
  }
  transition <- result$transitions
  if (!is.list(transition) || !setequal(names(transition),
      c("row_names", "rows")) || !is.list(transition$rows) ||
      length(transition$rows) < 1L ||
      !is.list(transition$row_names) ||
      length(transition$row_names) != length(transition$rows)) {
    stop("Array-proof transition envelope is invalid.", call. = FALSE)
  }
  row_names <- vapply(transition$row_names, wlv13_ap_scalar, character(1L),
    name = "transition row name")
  if (anyDuplicated(row_names)) {
    stop("Array-proof transition row names are duplicated.", call. = FALSE)
  }
  rows <- lapply(transition$rows, function(row) {
    if (!is.list(row) || !identical(names(row),
        c("candidate_state", "baseline_state", "count"))) {
      stop("Array-proof transition row is invalid.", call. = FALSE)
    }
    candidate_state <- wlv13_ap_scalar(row$candidate_state,
      "candidate transition state")
    baseline_state <- wlv13_ap_scalar(row$baseline_state,
      "baseline transition state")
    count_text <- wlv13_ap_scalar(row$count, "transition count", "^[0-9]+$")
    count <- suppressWarnings(as.numeric(count_text))
    if (!candidate_state %in% wlv13_state_names ||
        !identical(candidate_state, baseline_state) || !is.numeric(count) ||
        length(count) != 1L || is.na(count) || !is.finite(count) ||
        count <= 0 || count != floor(count)) {
      stop("Array-proof transition is not a positive diagonal count.",
        call. = FALSE)
    }
    list(candidate_state = candidate_state,
      baseline_state = baseline_state, count = as.numeric(count))
  })
  pairs <- vapply(rows, function(row) paste(row$candidate_state,
    row$baseline_state, sep = "|"), character(1L))
  total <- sum(vapply(rows, `[[`, numeric(1L), "count"))
  expected_total <- suppressWarnings(as.numeric(
    key_document$candidate$expected_length
  ))
  if (anyDuplicated(pairs) || !is.finite(expected_total) ||
      !identical(total, expected_total) ||
      !identical(key_document$candidate$expected_length,
        key_document$baseline$expected_length)) {
    stop("Array-proof transitions are duplicate or incomplete.", call. = FALSE)
  }
  indicators <- result$indicator_differences
  if (!is.list(indicators) || length(indicators)) {
    stop("Zero-difference array proof has indicator differences.", call. = FALSE)
  }
  transitions <- data.frame(
    candidate_state = vapply(rows, `[[`, character(1L), "candidate_state"),
    baseline_state = vapply(rows, `[[`, character(1L), "baseline_state"),
    count = vapply(rows, `[[`, numeric(1L), "count"),
    stringsAsFactors = FALSE,
    row.names = row_names
  )
  list(summary = summary, transitions = transitions, indicators = data.frame())
}

wlv13_ap_load <- function(path, expected_sha256, expected_context) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  expected_sha256 <- wlv13_ap_hex(expected_sha256, "cache SHA-256")
  if (!identical(expected_sha256, wlv13_ap_approved_cache_sha256) ||
      !identical(wlv13_sha256_file(path), expected_sha256)) {
    stop("Array-proof cache SHA-256 changed.", call. = FALSE)
  }
  cache <- wlv13_json_read(path, simplify = FALSE)
  if (!is.list(cache) || !identical(cache$schema,
      "wlv-issue13-main-array-proof-cache/1") ||
      !identical(cache$campaign_id, "issue13-main-054-v2") ||
      !identical(cache$classification,
        "authenticated-comparison-proof-reuse-no-science-reexecution") ||
      !is.list(cache$context) || !is.list(cache$origins) ||
      length(cache$origins) != 2L || !is.list(cache$records) ||
      length(cache$records) != 8L) {
    stop("Array-proof cache envelope is invalid.", call. = FALSE)
  }
  context_fields <- c("config_sha256", "science_tooling_binding_sha256",
    "comparison_binding_sha256", "algorithms")
  if (!identical(wlv13_ap_token(cache$context[context_fields]),
      wlv13_ap_token(expected_context[context_fields]))) {
    stop("Array-proof cache belongs to different tooling or bindings.",
      call. = FALSE)
  }
  keys <- character()
  prepared <- list()
  for (record in cache$records) {
    if (!is.list(record) || !setequal(names(record), c(
        "logical_key", "key_sha256", "key", "origin_comparison_id",
        "proof", "proof_sha256"
      ))) {
      stop("Array-proof cache record is invalid.", call. = FALSE)
    }
    key_sha <- wlv13_ap_hex(record$key_sha256, "record key SHA-256")
    if (!identical(wlv13_ap_sha(record$key), key_sha) ||
        !identical(record$logical_key, record$key$logical_key) ||
        !record$origin_comparison_id %in% vapply(cache$origins,
          `[[`, character(1L), "comparison_id") ||
        !identical(wlv13_ap_sha(record$proof),
          wlv13_ap_hex(record$proof_sha256, "record proof SHA-256"))) {
      stop("Array-proof cache record hashes or origin are invalid.",
        call. = FALSE)
    }
    prepared[[key_sha]] <- wlv13_ap_result(record, record$key)
    keys <- c(keys, key_sha)
  }
  if (anyDuplicated(keys) || length(prepared) != 8L) {
    stop("Array-proof cache has duplicate pair identities.", call. = FALSE)
  }
  list(path = path, sha256 = expected_sha256, context = cache$context,
    origins = cache$origins, records = prepared)
}

wlv13_ap_lookup <- function(left, right, chunk_rows, comparison_mode, cache,
                            engine_pair) {
  # Unsupported modes/chunking are ordinary cache misses.  In particular,
  # source comparisons have no run-engine context and must retain the original
  # comparator behavior rather than failing inside this optional optimization.
  if (!identical(comparison_mode, "cross_engine_run_v3") ||
      !identical(as.integer(chunk_rows), 1000000L)) {
    return(NULL)
  }
  key <- wlv13_ap_key_document(left, right, chunk_rows, comparison_mode,
    cache$context, engine_pair)
  cache$records[[wlv13_ap_sha(key)]]
}

wlv13_ap_install <- function(cache, fail_on_miss = FALSE) {
  if (!is.list(cache) || !is.list(cache$records) ||
      !is.logical(fail_on_miss) || length(fail_on_miss) != 1L ||
      is.na(fail_on_miss) ||
      exists("wlv13_ap_original_compare_fst_array", envir = .GlobalEnv,
        inherits = FALSE)) {
    stop("Array-proof hook cannot be installed twice or without a cache.",
      call. = FALSE)
  }
  assign("wlv13_ap_original_compare_fst_array", wlv13_compare_fst_array,
    envir = .GlobalEnv)
  assign("wlv13_ap_cache", cache, envir = .GlobalEnv)
  assign("wlv13_ap_hits", 0L, envir = .GlobalEnv)
  assign("wlv13_ap_fail_on_miss", fail_on_miss, envir = .GlobalEnv)
  wlv13_compare_fst_array <<- function(left, right, chunk_rows) {
    mode <- getOption("wlv13.array_proof.comparison_mode", "strict")
    engine_pair <- get("wlv13_v5_comparison_context", inherits = TRUE)
    cached <- wlv13_ap_lookup(left, right, chunk_rows, mode,
      get("wlv13_ap_cache", envir = .GlobalEnv, inherits = FALSE),
      engine_pair)
    if (is.null(cached)) {
      if (isTRUE(get("wlv13_ap_fail_on_miss", envir = .GlobalEnv,
          inherits = FALSE))) {
        stop(sprintf("Required array proof missed: %s.", left$key),
          call. = FALSE)
      }
      return(get("wlv13_ap_original_compare_fst_array", envir = .GlobalEnv,
        inherits = FALSE)(left, right, chunk_rows))
    }
    assign("wlv13_ap_hits", get("wlv13_ap_hits", envir = .GlobalEnv,
      inherits = FALSE) + 1L, envir = .GlobalEnv)
    unserialize(serialize(cached, NULL, version = 3L))
  }
  invisible(cache)
}
