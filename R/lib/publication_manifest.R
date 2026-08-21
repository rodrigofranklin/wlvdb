wlv_publication_schema_version <- "1"
wlv_run_manifest_schema <- "wlv-run-manifest"
wlv_release_manifest_schema <- "wlv-release-manifest"
wlv_channel_marker_schema <- "wlv-channel-marker"
wlv_output_contract_id <- "wlvpanel-output"
wlv_output_contract_version <- "1.0.0"

wlv_run_manifest_filename <- "run_manifest.json"
wlv_release_manifest_filename <- "release_manifest.json"

wlv_run_manifest_fields <- c(
  "schema",
  "schema_version",
  "run_id",
  "result_id",
  "created_at_utc",
  "parent_run_id",
  "method",
  "output_contract",
  "result",
  "execution",
  "artifacts"
)

wlv_release_manifest_fields <- c(
  "schema",
  "schema_version",
  "release_id",
  "channel",
  "sequence",
  "created_at_utc",
  "metadata",
  "runs",
  "artifacts"
)

wlv_channel_marker_fields <- c(
  "schema",
  "schema_version",
  "channel",
  "sequence",
  "release_id",
  "release_manifest_path",
  "release_manifest_sha256",
  "published_at_utc"
)

wlv_publication_artifact_fields <- c(
  "path", "role", "size_bytes", "sha256"
)

wlv_publication_run_reference_fields <- c(
  "method", "run_id", "result_id", "manifest_path", "manifest_sha256"
)

wlv_publication_result_fields <- c(
  "provenance", "request", "schema", "audit_summary"
)

wlv_publication_execution_fields <- c(
  "started_at_utc",
  "finished_at_utc",
  "duration_seconds",
  "warnings",
  "host"
)

wlv_publication_host_fields <- c(
  "r_version", "platform", "os", "arch"
)

wlv_publication_path_key <- function(path) {
  path <- sub("/+$", "", chartr("\\", "/", path))
  if (.Platform$OS.type == "windows") tolower(path) else path
}

wlv_publication_assert_real_directory <- function(
    path,
    parent = NULL,
    label,
    direct_child = TRUE) {
  if (!is.character(path) || length(path) != 1L || is.na(path) ||
      !dir.exists(path)) {
    stop(sprintf("%s must be an existing directory.", label), call. = FALSE)
  }
  link <- Sys.readlink(path)
  if (length(link) == 1L && !is.na(link) && nzchar(link)) {
    stop(sprintf("%s must not be a symbolic link or junction.", label),
      call. = FALSE
    )
  }
  resolved <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (is.null(parent)) return(resolved)
  if (!is.character(parent) || length(parent) != 1L || is.na(parent) ||
      !dir.exists(parent)) {
    stop(sprintf("Parent of %s must be an existing directory.", label), call. = FALSE)
  }
  resolved_parent <- normalizePath(parent, winslash = "/", mustWork = TRUE)
  parent_key <- wlv_publication_path_key(resolved_parent)
  path_key <- wlv_publication_path_key(resolved)
  expected_key <- wlv_publication_path_key(file.path(
    resolved_parent,
    basename(path)
  ))
  inside <- startsWith(path_key, paste0(parent_key, "/"))
  if (!identical(path_key, expected_key) || !inside || (isTRUE(direct_child) &&
      !identical(wlv_publication_path_key(dirname(resolved)), parent_key))) {
    stop(sprintf("%s is outside its canonical publication parent.", label),
      call. = FALSE
    )
  }
  resolved
}

wlv_publication_require_jsonlite <- function() {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop(
      "Package `jsonlite` is required for publication manifests.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

wlv_publication_validate_text <- function(value, label, allow_empty = FALSE) {
  if (
    !is.character(value) ||
    anyNA(value) ||
    (!allow_empty && any(!nzchar(value))) ||
    any(is.na(iconv(value, from = "UTF-8", to = "UTF-8", sub = NA))) ||
    any(grepl("[\r\n\t]", value))
  ) {
    stop(
      sprintf("`%s` must contain valid single-line UTF-8 text.", label),
      call. = FALSE
    )
  }
  invisible(value)
}

wlv_publication_validate_scalar_text <- function(
    value,
    label,
    allow_empty = FALSE) {
  wlv_publication_validate_text(value, label, allow_empty = allow_empty)
  if (length(value) != 1L) {
    stop(sprintf("`%s` must be one string.", label), call. = FALSE)
  }
  enc2utf8(value)
}

wlv_publication_validate_id <- function(value, label) {
  value <- wlv_publication_validate_scalar_text(value, label)
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", value)) {
    stop(
      sprintf(
        "`%s` must be a portable identifier of at most 128 characters.",
        label
      ),
      call. = FALSE
    )
  }
  value
}

wlv_publication_validate_sha256 <- function(value, label) {
  value <- wlv_publication_validate_scalar_text(value, label)
  if (!grepl("^[0-9a-f]{64}$", value)) {
    stop(
      sprintf("`%s` must be a lowercase SHA-256 string.", label),
      call. = FALSE
    )
  }
  value
}

wlv_publication_timestamp <- function(time = Sys.time()) {
  if (!inherits(time, "POSIXt") || length(time) != 1L || is.na(time)) {
    stop("`time` must be one valid POSIX timestamp.", call. = FALSE)
  }
  format(as.POSIXct(time, tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

wlv_publication_validate_timestamp <- function(value, label) {
  value <- wlv_publication_validate_scalar_text(value, label)
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", value)) {
    stop(sprintf("`%s` must be an RFC 3339 UTC timestamp.", label), call. = FALSE)
  }
  parsed <- suppressWarnings(as.POSIXct(
    value,
    format = "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  ))
  if (
    is.na(parsed) ||
    !identical(format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), value)
  ) {
    stop(sprintf("`%s` is not a valid UTC timestamp.", label), call. = FALSE)
  }
  value
}

wlv_publication_validate_sequence <- function(value) {
  value <- wlv_publication_validate_scalar_text(value, "sequence")
  if (!grepl("^[0-9]{20}$", value)) {
    stop(
      "`sequence` must be a canonical 20-digit decimal string.",
      call. = FALSE
    )
  }
  value
}

wlv_publication_normalize_relative_paths <- function(
    paths,
    label = "paths",
    allow_empty = FALSE) {
  if (!is.character(paths) || anyNA(paths)) {
    stop(sprintf("`%s` must be a character vector.", label), call. = FALSE)
  }
  if (!length(paths)) {
    if (!allow_empty) {
      stop(sprintf("`%s` must not be empty.", label), call. = FALSE)
    }
    return(character())
  }
  wlv_publication_validate_text(paths, label)
  normalized <- chartr("\\", "/", enc2utf8(paths))
  invalid <-
    grepl("^(/|[A-Za-z]:/|//)", normalized) |
    grepl("(^|/)[.][.](/|$)", normalized) |
    grepl("(^|/)[.](/|$)", normalized) |
    grepl("//", normalized, fixed = TRUE) |
    grepl("/$", normalized) |
    grepl("[<>:\"|?*]", normalized) |
    grepl("[[:cntrl:]]", normalized) |
    grepl("[. ](/|$)", normalized)
  if (any(invalid)) {
    stop(
      sprintf(
        "`%s` must contain normalized, portable relative paths: %s.",
        label,
        paste(unique(paths[invalid]), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  normalized
}

wlv_publication_validate_channel <- function(value) {
  value <- wlv_publication_validate_scalar_text(value, "channel")
  normalized <- wlv_publication_normalize_relative_paths(value, "channel")
  segments <- strsplit(value, "/", fixed = TRUE)[[1L]]
  if (
    !identical(value, normalized) ||
    nchar(value, type = "chars") > 128L ||
    any(!grepl(
      "^[a-z0-9](?:[a-z0-9._-]*[a-z0-9_-])?$",
      segments,
      perl = TRUE
    ))
  ) {
    stop(
      "`channel` must be a normalized lowercase channel identifier.",
      call. = FALSE
    )
  }
  value
}

wlv_publication_exact_object <- function(value, fields, label) {
  if (
    !is.list(value) ||
    is.null(names(value)) ||
    anyNA(names(value)) ||
    any(!nzchar(names(value))) ||
    anyDuplicated(names(value)) ||
    !setequal(names(value), fields) ||
    length(value) != length(fields)
  ) {
    stop(
      sprintf(
        "%s must contain exactly these fields: %s.",
        label,
        paste(fields, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  value[fields]
}

wlv_publication_normalize_json <- function(value, label = "JSON value") {
  if (is.null(value)) {
    return(NULL)
  }
  if (is.factor(value) || is.data.frame(value) || is.raw(value) || is.complex(value)) {
    stop(sprintf("`%s` is not JSON-safe data.", label), call. = FALSE)
  }
  if (is.list(value)) {
    object_names <- names(value)
    if (!length(value)) {
      if (is.null(object_names)) {
        return(list())
      }
      return(structure(list(), names = character()))
    }
    if (is.null(object_names)) {
      return(lapply(seq_along(value), function(index) {
        wlv_publication_normalize_json(
          value[[index]],
          sprintf("%s[[%d]]", label, index)
        )
      }))
    }
    if (
      length(object_names) != length(value) ||
      anyNA(object_names) ||
      any(!nzchar(object_names)) ||
      anyDuplicated(object_names)
    ) {
      stop(
        sprintf("`%s` must use unique non-empty JSON object keys.", label),
        call. = FALSE
      )
    }
    wlv_publication_validate_text(object_names, paste0(label, " keys"))
    order_index <- order(enc2utf8(object_names), method = "radix")
    normalized <- lapply(order_index, function(index) {
      wlv_publication_normalize_json(
        value[[index]],
        paste0(label, "$", object_names[[index]])
      )
    })
    names(normalized) <- enc2utf8(object_names[order_index])
    return(normalized)
  }
  if (!is.atomic(value) || is.object(value)) {
    stop(sprintf("`%s` is not JSON-safe data.", label), call. = FALSE)
  }
  if (!length(value)) {
    return(list())
  }
  if (anyNA(value)) {
    stop(sprintf("`%s` must not contain NA values.", label), call. = FALSE)
  }
  if (is.numeric(value) && any(!is.finite(value))) {
    stop(sprintf("`%s` must contain finite JSON numbers.", label), call. = FALSE)
  }
  if (!is.character(value) && !is.logical(value) && !is.numeric(value)) {
    stop(sprintf("`%s` is not JSON-safe data.", label), call. = FALSE)
  }
  if (is.character(value)) {
    wlv_publication_validate_text(value, label, allow_empty = TRUE)
    value <- enc2utf8(value)
  }
  if (length(value) == 1L) {
    return(unname(value))
  }
  lapply(seq_along(value), function(index) unname(value[[index]]))
}

wlv_publication_normalize_named_object <- function(value, label) {
  if (!is.list(value)) {
    stop(sprintf("`%s` must be a JSON object.", label), call. = FALSE)
  }
  if (!length(value)) {
    return(structure(list(), names = character()))
  }
  if (
    is.null(names(value)) ||
    anyNA(names(value)) ||
    any(!nzchar(names(value))) ||
    anyDuplicated(names(value))
  ) {
    stop(sprintf("`%s` must be a JSON object.", label), call. = FALSE)
  }
  wlv_publication_normalize_json(value, label)
}

wlv_publication_normalize_allowed_object <- function(
    value,
    fields,
    label,
    values_must_be_objects = FALSE) {
  value <- wlv_publication_normalize_named_object(value, label)
  unknown <- setdiff(names(value), fields)
  if (length(unknown)) {
    stop(
      sprintf(
        "`%s` contains unsupported fields: %s.",
        label,
        paste(unknown, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (isTRUE(values_must_be_objects)) {
    value <- lapply(names(value), function(name) {
      wlv_publication_normalize_named_object(
        value[[name]],
        paste0(label, "$", name)
      )
    }) |>
      stats::setNames(names(value))
  }
  value[intersect(fields, names(value))]
}

wlv_publication_sha256_raw <- function(value) {
  if (!is.raw(value)) {
    stop("SHA-256 input must be a raw vector.", call. = FALSE)
  }
  if (exists("wlv_source_sha256_raw", mode = "function", inherits = TRUE)) {
    return(wlv_source_sha256_raw(value))
  }
  if (!requireNamespace("openssl", quietly = TRUE)) {
    stop("Package `openssl` is required for publication manifests.", call. = FALSE)
  }
  paste0(tolower(as.character(openssl::sha256(value))), collapse = "")
}

wlv_publication_file_sha256 <- function(path) {
  if (
    !is.character(path) ||
    length(path) != 1L ||
    is.na(path) ||
    !nzchar(path) ||
    !file.exists(path) ||
    isTRUE(file.info(path)$isdir)
  ) {
    stop(sprintf("Cannot hash publication file: %s.", path), call. = FALSE)
  }
  if (exists("wlv_source_file_sha256", mode = "function", inherits = TRUE)) {
    return(wlv_source_file_sha256(path))
  }
  if (!requireNamespace("openssl", quietly = TRUE)) {
    stop("Package `openssl` is required for publication manifests.", call. = FALSE)
  }
  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  paste0(tolower(as.character(openssl::sha256(connection))), collapse = "")
}

wlv_publication_file_record <- function(path) {
  before <- unname(file.info(path)$size)
  hash <- wlv_publication_file_sha256(path)
  after <- unname(file.info(path)$size)
  if (
    is.na(before) ||
    is.na(after) ||
    !identical(before, after) ||
    before < 0 ||
    before > 2^53 - 1
  ) {
    stop(
      sprintf("Publication artifact changed while being hashed: %s.", path),
      call. = FALSE
    )
  }
  list(size_bytes = as.numeric(before), sha256 = hash)
}

wlv_publication_resolve_files <- function(root, paths, label = "artifacts") {
  if (
    !is.character(root) ||
    length(root) != 1L ||
    is.na(root) ||
    !dir.exists(root)
  ) {
    stop(sprintf("Root for `%s` must be an existing directory.", label), call. = FALSE)
  }
  paths <- wlv_publication_normalize_relative_paths(
    paths,
    label,
    allow_empty = TRUE
  )
  if (!length(paths)) {
    return(character())
  }
  normalized_root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  candidates <- file.path(normalized_root, paths)
  if (exists("wlv_source_resolve_artifacts", mode = "function", inherits = TRUE)) {
    resolved <- wlv_source_resolve_artifacts(root, paths)
  } else {
    missing <- !file.exists(candidates) | file.info(candidates)$isdir %in% TRUE
    if (any(missing)) {
      stop(
        sprintf(
          "Publication artifact files are missing: %s.",
          paste(paths[missing], collapse = ", ")
        ),
        call. = FALSE
      )
    }
    resolved <- normalizePath(candidates, winslash = "/", mustWork = TRUE)
  }
  comparison_root <- normalized_root
  comparison_resolved <- resolved
  comparison_expected <- chartr("\\", "/", candidates)
  if (.Platform$OS.type == "windows") {
    comparison_root <- tolower(comparison_root)
    comparison_resolved <- tolower(comparison_resolved)
    comparison_expected <- tolower(comparison_expected)
  }
  inside <- startsWith(comparison_resolved, paste0(comparison_root, "/"))
  if (any(!inside)) {
    stop(
      sprintf(
        "Publication files must resolve inside their root: %s.",
        paste(paths[!inside], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  canonical <- comparison_resolved == comparison_expected
  if (any(!canonical)) {
    stop(
      sprintf(
        "Publication files must use canonical link-free paths: %s.",
        paste(paths[!canonical], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  resolved
}

wlv_publication_list_files <- function(root, exclude = character()) {
  if (!dir.exists(root)) {
    stop("Publication root must be an existing directory.", call. = FALSE)
  }
  exclude <- wlv_publication_normalize_relative_paths(
    exclude,
    "excluded paths",
    allow_empty = TRUE
  )
  files <- list.files(
    root,
    all.files = TRUE,
    full.names = FALSE,
    recursive = TRUE,
    include.dirs = FALSE,
    no.. = TRUE
  )
  files <- chartr("\\", "/", files)
  files <- setdiff(files, exclude)
  files <- sort(files, method = "radix")
  if (length(files)) {
    normalized <- wlv_publication_normalize_relative_paths(files, "publication files")
    if (!identical(normalized, files)) {
      stop("Publication files do not have canonical relative paths.", call. = FALSE)
    }
    wlv_publication_resolve_files(root, files, "publication files")
  }
  files
}

wlv_publication_validate_fst_pairs <- function(paths, label = "artifacts") {
  fst <- paths[grepl("[.]fst$", paths, ignore.case = TRUE)]
  meta <- paths[grepl("[.]fst[.]meta$", paths, ignore.case = TRUE)]
  missing_meta <- if (length(fst)) {
    setdiff(paste0(fst, ".meta"), paths)
  } else {
    character()
  }
  orphan_meta <- setdiff(sub("[.]meta$", "", meta, ignore.case = TRUE), paths)
  if (length(missing_meta) || length(orphan_meta)) {
    details <- c(
      if (length(missing_meta)) paste0("missing sidecars: ", paste(missing_meta, collapse = ", ")),
      if (length(orphan_meta)) paste0("orphan sidecars: ", paste(meta[match(orphan_meta, sub("[.]meta$", "", meta, ignore.case = TRUE))], collapse = ", "))
    )
    stop(
      sprintf("FST/.meta pairing failed for `%s` (%s).", label, paste(details, collapse = "; ")),
      call. = FALSE
    )
  }
  invisible(paths)
}

wlv_publication_validate_artifact_records <- function(
    artifacts,
    label = "artifacts",
    allow_empty = FALSE) {
  if (!is.list(artifacts) || !is.null(names(artifacts))) {
    stop(sprintf("`%s` must be a JSON array.", label), call. = FALSE)
  }
  if (!length(artifacts)) {
    if (!allow_empty) {
      stop(sprintf("`%s` must contain at least one artifact.", label), call. = FALSE)
    }
    return(list())
  }
  normalized <- lapply(seq_along(artifacts), function(index) {
    record <- wlv_publication_exact_object(
      artifacts[[index]],
      wlv_publication_artifact_fields,
      sprintf("%s[[%d]]", label, index)
    )
    path <- wlv_publication_validate_scalar_text(record$path, paste0(label, " path"))
    normalized_path <- wlv_publication_normalize_relative_paths(path, paste0(label, " path"))
    if (!identical(path, normalized_path)) {
      stop(sprintf("`%s` paths must already be normalized.", label), call. = FALSE)
    }
    role <- wlv_publication_validate_scalar_text(record$role, paste0(label, " role"))
    if (!grepl("^[a-z0-9][a-z0-9._-]{0,127}$", role)) {
      stop(sprintf("`%s` roles must be portable lowercase identifiers.", label), call. = FALSE)
    }
    size <- record$size_bytes
    if (
      !is.numeric(size) ||
      length(size) != 1L ||
      is.na(size) ||
      !is.finite(size) ||
      size < 0 ||
      size > 2^53 - 1 ||
      size != floor(size)
    ) {
      stop(sprintf("`%s` sizes must be safe non-negative JSON integers.", label), call. = FALSE)
    }
    list(
      path = path,
      role = role,
      size_bytes = as.numeric(size),
      sha256 = wlv_publication_validate_sha256(
        record$sha256,
        paste0(label, " sha256")
      )
    )
  })
  paths <- vapply(normalized, `[[`, character(1), "path")
  if (anyDuplicated(paths)) {
    stop(sprintf("`%s` paths must be unique.", label), call. = FALSE)
  }
  canonical_order <- order(paths, method = "radix")
  if (!identical(canonical_order, seq_along(paths))) {
    stop(sprintf("`%s` must be in canonical path order.", label), call. = FALSE)
  }
  wlv_publication_validate_fst_pairs(paths, label)
  normalized
}

wlv_publication_build_artifacts <- function(
    root,
    artifacts,
    artifact_roles,
    allow_empty = FALSE,
    excluded_paths = character()) {
  artifacts <- wlv_publication_normalize_relative_paths(
    artifacts,
    "artifacts",
    allow_empty = allow_empty
  )
  if (!is.character(artifact_roles) || anyNA(artifact_roles)) {
    stop("`artifact_roles` must be a character vector.", call. = FALSE)
  }
  if (length(artifacts) != length(artifact_roles)) {
    stop("Artifacts and roles must have equal lengths.", call. = FALSE)
  }
  if (!length(artifacts)) {
    return(list())
  }
  wlv_publication_validate_text(artifact_roles, "artifact_roles")
  if (anyDuplicated(artifacts)) {
    stop("Artifact paths must be unique.", call. = FALSE)
  }
  excluded_paths <- wlv_publication_normalize_relative_paths(
    excluded_paths,
    "excluded paths",
    allow_empty = TRUE
  )
  forbidden <- artifacts %in% excluded_paths
  if (any(forbidden)) {
    stop(
      sprintf(
        "Manifest files must not inventory themselves: %s.",
        paste(artifacts[forbidden], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  paths <- wlv_publication_resolve_files(root, artifacts)
  records <- lapply(paths, wlv_publication_file_record)
  order_index <- order(artifacts, method = "radix")
  value <- lapply(order_index, function(index) {
    list(
      path = artifacts[[index]],
      role = artifact_roles[[index]],
      size_bytes = records[[index]]$size_bytes,
      sha256 = records[[index]]$sha256
    )
  })
  wlv_publication_validate_artifact_records(
    value,
    allow_empty = allow_empty
  )
}

wlv_publication_verify_artifacts <- function(
    artifacts,
    root,
    excluded_paths,
    reject_unlisted = TRUE,
    label = "artifact") {
  artifacts <- wlv_publication_validate_artifact_records(
    artifacts,
    label = paste0(label, "s"),
    allow_empty = TRUE
  )
  expected <- vapply(artifacts, `[[`, character(1), "path")
  if (isTRUE(reject_unlisted)) {
    actual <- wlv_publication_list_files(root, exclude = excluded_paths)
    missing <- setdiff(expected, actual)
    extra <- setdiff(actual, expected)
    if (length(missing) || length(extra)) {
      details <- c(
        if (length(missing)) paste0("missing: ", paste(missing, collapse = ", ")),
        if (length(extra)) paste0("unlisted: ", paste(extra, collapse = ", "))
      )
      stop(
        sprintf("Publication inventory mismatch (%s).", paste(details, collapse = "; ")),
        call. = FALSE
      )
    }
  }
  paths <- wlv_publication_resolve_files(root, expected, paste0(label, "s"))
  for (index in seq_along(paths)) {
    record <- wlv_publication_file_record(paths[[index]])
    if (!identical(record$size_bytes, artifacts[[index]]$size_bytes)) {
      stop(
        sprintf("Size mismatch for %s `%s`.", label, expected[[index]]),
        call. = FALSE
      )
    }
    if (!identical(record$sha256, artifacts[[index]]$sha256)) {
      stop(
        sprintf("SHA-256 mismatch for %s `%s`.", label, expected[[index]]),
        call. = FALSE
      )
    }
  }
  invisible(artifacts)
}

wlv_publication_normalize_result <- function(result) {
  wlv_publication_normalize_allowed_object(
    result,
    wlv_publication_result_fields,
    "result",
    values_must_be_objects = TRUE
  )
}

wlv_publication_normalize_execution <- function(execution) {
  execution <- wlv_publication_normalize_allowed_object(
    execution,
    wlv_publication_execution_fields,
    "execution"
  )
  for (field in intersect(c("started_at_utc", "finished_at_utc"), names(execution))) {
    execution[[field]] <- wlv_publication_validate_timestamp(
      execution[[field]],
      paste0("execution$", field)
    )
  }
  if ("duration_seconds" %in% names(execution)) {
    duration <- execution$duration_seconds
    if (
      !is.numeric(duration) ||
      length(duration) != 1L ||
      is.na(duration) ||
      !is.finite(duration) ||
      duration < 0
    ) {
      stop("`execution$duration_seconds` must be one finite non-negative number.", call. = FALSE)
    }
    execution$duration_seconds <- as.numeric(duration)
  }
  if ("warnings" %in% names(execution)) {
    warnings <- execution$warnings
    if (is.character(warnings)) {
      warnings <- as.list(enc2utf8(warnings))
    }
    if (
      !is.list(warnings) ||
      !is.null(names(warnings)) ||
      any(!vapply(warnings, function(value) {
        is.character(value) && length(value) == 1L && !is.na(value)
      }, logical(1)))
    ) {
      stop("`execution$warnings` must be an array of strings.", call. = FALSE)
    }
    if (length(warnings)) {
      wlv_publication_validate_text(
        unlist(warnings, use.names = FALSE),
        "execution warnings",
        allow_empty = TRUE
      )
      warnings <- lapply(warnings, enc2utf8)
    }
    execution$warnings <- warnings
  }
  if ("host" %in% names(execution)) {
    host <- wlv_publication_normalize_allowed_object(
      execution$host,
      wlv_publication_host_fields,
      "execution$host"
    )
    if (length(host)) {
      host <- lapply(names(host), function(field) {
        wlv_publication_validate_scalar_text(
          host[[field]],
          paste0("execution$host$", field)
        )
      }) |>
        stats::setNames(names(host))
      host <- host[intersect(wlv_publication_host_fields, names(host))]
    }
    execution$host <- host
  }
  execution[intersect(wlv_publication_execution_fields, names(execution))]
}

wlv_publication_normalize_output_contract <- function(value) {
  value <- wlv_publication_exact_object(
    value,
    c("id", "version"),
    "Output contract"
  )
  value$id <- wlv_publication_validate_scalar_text(value$id, "output_contract$id")
  value$version <- wlv_publication_validate_scalar_text(
    value$version,
    "output_contract$version"
  )
  if (
    !identical(value$id, wlv_output_contract_id) ||
    !identical(value$version, wlv_output_contract_version)
  ) {
    stop(
      sprintf(
        "Unsupported output contract; expected `%s` version `%s`.",
        wlv_output_contract_id,
        wlv_output_contract_version
      ),
      call. = FALSE
    )
  }
  value
}

wlv_publication_canonical_json <- function(value) {
  wlv_publication_require_jsonlite()
  normalized <- wlv_publication_normalize_json(value)
  as.character(jsonlite::toJSON(
    normalized,
    auto_unbox = TRUE,
    null = "null",
    na = "string",
    digits = NA,
    pretty = FALSE,
    force = TRUE
  ))
}

wlv_publication_calculate_result_id <- function(
    method,
    output_contract,
    result,
    artifacts) {
  payload <- list(
    domain = "wlv-result-id-v1",
    method = method,
    output_contract = output_contract,
    result = result,
    artifacts = artifacts
  )
  wlv_publication_sha256_raw(charToRaw(enc2utf8(
    wlv_publication_canonical_json(payload)
  )))
}

wlv_run_manifest_result_id <- function(manifest) {
  manifest <- wlv_publication_exact_object(
    manifest,
    wlv_run_manifest_fields,
    "Run manifest"
  )
  method <- wlv_publication_validate_id(manifest$method, "method")
  output_contract <- wlv_publication_normalize_output_contract(
    manifest$output_contract
  )
  result <- wlv_publication_normalize_result(manifest$result)
  artifacts <- wlv_publication_validate_artifact_records(manifest$artifacts)
  wlv_publication_calculate_result_id(
    method,
    output_contract,
    result,
    artifacts
  )
}

wlv_validate_run_manifest <- function(manifest) {
  manifest <- wlv_publication_exact_object(
    manifest,
    wlv_run_manifest_fields,
    "Run manifest"
  )
  manifest$schema <- wlv_publication_validate_scalar_text(manifest$schema, "schema")
  manifest$schema_version <- wlv_publication_validate_scalar_text(
    manifest$schema_version,
    "schema_version"
  )
  if (!identical(manifest$schema, wlv_run_manifest_schema)) {
    stop("Unsupported run manifest schema.", call. = FALSE)
  }
  if (!identical(manifest$schema_version, wlv_publication_schema_version)) {
    stop("Unsupported run manifest schema version.", call. = FALSE)
  }
  manifest$run_id <- wlv_publication_validate_id(manifest$run_id, "run_id")
  manifest$result_id <- wlv_publication_validate_sha256(
    manifest$result_id,
    "result_id"
  )
  manifest$created_at_utc <- wlv_publication_validate_timestamp(
    manifest$created_at_utc,
    "created_at_utc"
  )
  if (!is.null(manifest$parent_run_id)) {
    manifest$parent_run_id <- wlv_publication_validate_id(
      manifest$parent_run_id,
      "parent_run_id"
    )
  }
  manifest$method <- wlv_publication_validate_id(manifest$method, "method")
  manifest$output_contract <- wlv_publication_normalize_output_contract(
    manifest$output_contract
  )
  manifest$result <- wlv_publication_normalize_result(manifest$result)
  manifest$execution <- wlv_publication_normalize_execution(manifest$execution)
  manifest$artifacts <- wlv_publication_validate_artifact_records(manifest$artifacts)
  expected <- wlv_publication_calculate_result_id(
    manifest$method,
    manifest$output_contract,
    manifest$result,
    manifest$artifacts
  )
  if (!identical(manifest$result_id, expected)) {
    stop("Run manifest result_id does not match its semantic contents.", call. = FALSE)
  }
  invisible(manifest[wlv_run_manifest_fields])
}

wlv_build_run_manifest <- function(
    run_root,
    artifacts,
    artifact_roles,
    run_id,
    method,
    result = list(),
    execution = list(),
    created_at_utc = wlv_publication_timestamp(),
    parent_run_id = NULL,
    output_contract_id = wlv_output_contract_id,
    output_contract_version = wlv_output_contract_version) {
  manifest <- list(
    schema = wlv_run_manifest_schema,
    schema_version = wlv_publication_schema_version,
    run_id = run_id,
    result_id = paste(rep("0", 64L), collapse = ""),
    created_at_utc = created_at_utc,
    parent_run_id = parent_run_id,
    method = method,
    output_contract = list(
      id = output_contract_id,
      version = output_contract_version
    ),
    result = wlv_publication_normalize_result(result),
    execution = wlv_publication_normalize_execution(execution),
    artifacts = wlv_publication_build_artifacts(
      run_root,
      artifacts,
      artifact_roles,
      allow_empty = FALSE,
      excluded_paths = wlv_run_manifest_filename
    )
  )
  manifest$result_id <- wlv_publication_calculate_result_id(
    manifest$method,
    manifest$output_contract,
    manifest$result,
    manifest$artifacts
  )
  wlv_validate_run_manifest(manifest)
}

wlv_publication_read_json <- function(path, validator, label) {
  wlv_publication_require_jsonlite()
  if (
    !is.character(path) ||
    length(path) != 1L ||
    is.na(path) ||
    !file.exists(path) ||
    isTRUE(file.info(path)$isdir)
  ) {
    stop(sprintf("%s file is missing: %s.", label, path), call. = FALSE)
  }
  size <- unname(file.info(path)$size)
  if (is.na(size) || size <= 0 || size > .Machine$integer.max) {
    stop(sprintf("%s has an invalid file size.", label), call. = FALSE)
  }
  bytes <- readBin(path, what = "raw", n = as.integer(size))
  if (
    length(bytes) >= 3L &&
    identical(bytes[seq_len(3L)], as.raw(c(0xef, 0xbb, 0xbf)))
  ) {
    stop(sprintf("%s must be UTF-8 without a byte-order mark.", label), call. = FALSE)
  }
  decoded <- tryCatch(rawToChar(bytes), error = function(error) NA_character_)
  if (
    length(decoded) != 1L ||
    is.na(decoded) ||
    is.na(iconv(decoded, from = "UTF-8", to = "UTF-8", sub = NA))
  ) {
    stop(sprintf("%s is not valid UTF-8.", label), call. = FALSE)
  }
  # `rawToChar()` returns an unmarked string. Mark the already-validated bytes
  # explicitly so JSON parsing cannot reinterpret UTF-8 through the native
  # Windows code page.
  Encoding(decoded) <- "UTF-8"
  if (!jsonlite::validate(decoded)) {
    stop(sprintf("%s is not valid JSON.", label), call. = FALSE)
  }
  value <- tryCatch(
    jsonlite::fromJSON(decoded, simplifyVector = FALSE),
    error = function(error) {
      stop(
        sprintf("Cannot parse %s: %s", label, conditionMessage(error)),
        call. = FALSE
      )
    }
  )
  validator(value)
}

wlv_read_run_manifest <- function(path) {
  wlv_publication_read_json(path, wlv_validate_run_manifest, "Run manifest")
}

wlv_publication_json_text <- function(value) {
  wlv_publication_require_jsonlite()
  paste0(
    as.character(jsonlite::toJSON(
      value,
      auto_unbox = TRUE,
      null = "null",
      na = "string",
      digits = NA,
      pretty = TRUE,
      force = TRUE
    )),
    "\n"
  )
}

wlv_publication_json_identical <- function(left, right) {
  identical(
    wlv_publication_canonical_json(left),
    wlv_publication_canonical_json(right)
  )
}

wlv_publication_write_json <- function(value, path, reader, label) {
  if (
    !is.character(path) ||
    length(path) != 1L ||
    is.na(path) ||
    !nzchar(path) ||
    !dir.exists(dirname(path))
  ) {
    stop(sprintf("Invalid %s destination: %s.", label, path), call. = FALSE)
  }
  if (file.exists(path)) {
    stop(sprintf("Refusing to overwrite existing %s: %s.", label, path), call. = FALSE)
  }
  temporary <- tempfile(paste0(".", basename(path), "-"), tmpdir = dirname(path))
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  payload <- enc2utf8(wlv_publication_json_text(value))
  writeBin(charToRaw(payload), temporary)
  roundtrip <- reader(temporary)
  if (!wlv_publication_json_identical(value, roundtrip)) {
    stop(sprintf("%s failed exact UTF-8 round-trip verification.", label), call. = FALSE)
  }
  if (!file.rename(temporary, path)) {
    stop(sprintf("Could not atomically install %s: %s.", label, path), call. = FALSE)
  }
  installed <- reader(path)
  if (!wlv_publication_json_identical(value, installed)) {
    stop(sprintf("Installed %s differs from its verified payload.", label), call. = FALSE)
  }
  invisible(path)
}

wlv_write_run_manifest <- function(manifest, path) {
  manifest <- wlv_validate_run_manifest(manifest)
  if (!identical(basename(path), wlv_run_manifest_filename)) {
    stop(
      sprintf("Run manifests must be named `%s`.", wlv_run_manifest_filename),
      call. = FALSE
    )
  }
  wlv_publication_write_json(
    manifest,
    path,
    wlv_read_run_manifest,
    "run manifest"
  )
}

wlv_publication_as_run_manifest <- function(manifest) {
  if (is.character(manifest) && length(manifest) == 1L && !is.na(manifest)) {
    return(wlv_read_run_manifest(manifest))
  }
  wlv_validate_run_manifest(manifest)
}

wlv_verify_run_manifest <- function(
    manifest,
    run_root,
    expected_output_contract_id = wlv_output_contract_id,
    expected_output_contract_version = wlv_output_contract_version,
    reject_unlisted = TRUE) {
  manifest <- wlv_publication_as_run_manifest(manifest)
  expected_output_contract_id <- wlv_publication_validate_scalar_text(
    expected_output_contract_id,
    "expected_output_contract_id"
  )
  expected_output_contract_version <- wlv_publication_validate_scalar_text(
    expected_output_contract_version,
    "expected_output_contract_version"
  )
  if (
    !identical(manifest$output_contract$id, expected_output_contract_id) ||
    !identical(manifest$output_contract$version, expected_output_contract_version)
  ) {
    stop("Run manifest output contract differs from the expected contract.", call. = FALSE)
  }
  wlv_publication_verify_artifacts(
    manifest$artifacts,
    run_root,
    excluded_paths = wlv_run_manifest_filename,
    reject_unlisted = reject_unlisted,
    label = "run artifact"
  )
  invisible(manifest)
}

wlv_publication_normalize_run_references <- function(runs) {
  if (!is.list(runs) || !is.null(names(runs)) || !length(runs)) {
    stop("`runs` must be a non-empty JSON array.", call. = FALSE)
  }
  normalized <- lapply(seq_along(runs), function(index) {
    run <- wlv_publication_exact_object(
      runs[[index]],
      wlv_publication_run_reference_fields,
      sprintf("runs[[%d]]", index)
    )
    path <- wlv_publication_validate_scalar_text(
      run$manifest_path,
      "runs manifest_path"
    )
    normalized_path <- wlv_publication_normalize_relative_paths(
      path,
      "runs manifest_path"
    )
    if (!identical(path, normalized_path)) {
      stop("Run manifest paths must already be normalized.", call. = FALSE)
    }
    if (!identical(basename(path), wlv_run_manifest_filename)) {
      stop(
        sprintf("Run references must target `%s`.", wlv_run_manifest_filename),
        call. = FALSE
      )
    }
    normalized_run <- list(
      method = wlv_publication_validate_id(run$method, "runs method"),
      run_id = wlv_publication_validate_id(run$run_id, "runs run_id"),
      result_id = wlv_publication_validate_sha256(
        run$result_id,
        "runs result_id"
      ),
      manifest_path = path,
      manifest_sha256 = wlv_publication_validate_sha256(
        run$manifest_sha256,
        "runs manifest_sha256"
      )
    )
    expected_path <- paste(
      "runs",
      normalized_run$method,
      normalized_run$run_id,
      wlv_run_manifest_filename,
      sep = "/"
    )
    if (!identical(normalized_run$manifest_path, expected_path)) {
      stop(
        sprintf(
          "Run `%s` manifest must use canonical path `%s`.",
          normalized_run$run_id,
          expected_path
        ),
        call. = FALSE
      )
    }
    normalized_run
  })
  methods <- vapply(normalized, `[[`, character(1), "method")
  paths <- vapply(normalized, `[[`, character(1), "manifest_path")
  run_ids <- vapply(normalized, `[[`, character(1), "run_id")
  if (anyDuplicated(methods) || anyDuplicated(paths) || anyDuplicated(run_ids)) {
    stop("Release run methods, IDs, and manifest paths must be unique.", call. = FALSE)
  }
  canonical_order <- order(methods, paths, method = "radix")
  if (!identical(canonical_order, seq_along(runs))) {
    stop("Release runs must be in canonical method order.", call. = FALSE)
  }
  normalized
}

wlv_validate_release_manifest <- function(manifest) {
  manifest <- wlv_publication_exact_object(
    manifest,
    wlv_release_manifest_fields,
    "Release manifest"
  )
  manifest$schema <- wlv_publication_validate_scalar_text(manifest$schema, "schema")
  manifest$schema_version <- wlv_publication_validate_scalar_text(
    manifest$schema_version,
    "schema_version"
  )
  if (!identical(manifest$schema, wlv_release_manifest_schema)) {
    stop("Unsupported release manifest schema.", call. = FALSE)
  }
  if (!identical(manifest$schema_version, wlv_publication_schema_version)) {
    stop("Unsupported release manifest schema version.", call. = FALSE)
  }
  manifest$release_id <- wlv_publication_validate_id(
    manifest$release_id,
    "release_id"
  )
  manifest$channel <- wlv_publication_validate_channel(manifest$channel)
  manifest$sequence <- wlv_publication_validate_sequence(manifest$sequence)
  manifest$created_at_utc <- wlv_publication_validate_timestamp(
    manifest$created_at_utc,
    "created_at_utc"
  )
  manifest$metadata <- wlv_publication_normalize_named_object(
    manifest$metadata,
    "metadata"
  )
  manifest$runs <- wlv_publication_normalize_run_references(manifest$runs)
  manifest$artifacts <- wlv_publication_validate_artifact_records(
    manifest$artifacts,
    label = "release artifacts",
    allow_empty = TRUE
  )
  invisible(manifest[wlv_release_manifest_fields])
}

wlv_build_release_run_reference <- function(
    publication_root,
    method,
    manifest_path) {
  method <- wlv_publication_validate_id(method, "method")
  normalized_path <- wlv_publication_normalize_relative_paths(
    manifest_path,
    "manifest_path"
  )
  if (!identical(normalized_path, manifest_path)) {
    stop("`manifest_path` must already be normalized.", call. = FALSE)
  }
  if (!identical(basename(manifest_path), wlv_run_manifest_filename)) {
    stop(
      sprintf("Run references must target `%s`.", wlv_run_manifest_filename),
      call. = FALSE
    )
  }
  path <- wlv_publication_resolve_files(
    publication_root,
    manifest_path,
    "run manifest path"
  )[[1L]]
  run <- wlv_read_run_manifest(path)
  wlv_verify_run_manifest(run, dirname(path))
  if (!identical(run$method, method)) {
    stop("Referenced run method differs from the release method.", call. = FALSE)
  }
  list(
    method = method,
    run_id = run$run_id,
    result_id = run$result_id,
    manifest_path = manifest_path,
    manifest_sha256 = wlv_publication_file_sha256(path)
  )
}

wlv_build_release_manifest <- function(
    release_root,
    artifacts = character(),
    artifact_roles = character(),
    release_id,
    channel,
    sequence,
    runs,
    metadata = list(),
    created_at_utc = wlv_publication_timestamp()) {
  runs <- wlv_publication_normalize_run_references(runs)
  manifest <- list(
    schema = wlv_release_manifest_schema,
    schema_version = wlv_publication_schema_version,
    release_id = release_id,
    channel = channel,
    sequence = sequence,
    created_at_utc = created_at_utc,
    metadata = wlv_publication_normalize_named_object(metadata, "metadata"),
    runs = runs,
    artifacts = wlv_publication_build_artifacts(
      release_root,
      artifacts,
      artifact_roles,
      allow_empty = TRUE,
      excluded_paths = wlv_release_manifest_filename
    )
  )
  wlv_validate_release_manifest(manifest)
}

wlv_read_release_manifest <- function(path) {
  wlv_publication_read_json(
    path,
    wlv_validate_release_manifest,
    "Release manifest"
  )
}

wlv_write_release_manifest <- function(manifest, path) {
  manifest <- wlv_validate_release_manifest(manifest)
  if (!identical(basename(path), wlv_release_manifest_filename)) {
    stop(
      sprintf("Release manifests must be named `%s`.", wlv_release_manifest_filename),
      call. = FALSE
    )
  }
  wlv_publication_write_json(
    manifest,
    path,
    wlv_read_release_manifest,
    "release manifest"
  )
}

wlv_publication_as_release_manifest <- function(manifest) {
  if (is.character(manifest) && length(manifest) == 1L && !is.na(manifest)) {
    return(wlv_read_release_manifest(manifest))
  }
  wlv_validate_release_manifest(manifest)
}

wlv_verify_release_manifest <- function(
    manifest,
    release_root,
    publication_root = dirname(release_root),
    reject_unlisted = TRUE) {
  manifest <- wlv_publication_as_release_manifest(manifest)
  wlv_publication_verify_artifacts(
    manifest$artifacts,
    release_root,
    excluded_paths = wlv_release_manifest_filename,
    reject_unlisted = reject_unlisted,
    label = "release artifact"
  )
  for (reference in manifest$runs) {
    path <- wlv_publication_resolve_files(
      publication_root,
      reference$manifest_path,
      "release run manifests"
    )[[1L]]
    actual_hash <- wlv_publication_file_sha256(path)
    if (!identical(actual_hash, reference$manifest_sha256)) {
      stop(
        sprintf("Run manifest SHA-256 mismatch for `%s`.", reference$manifest_path),
        call. = FALSE
      )
    }
    run <- wlv_read_run_manifest(path)
    wlv_verify_run_manifest(run, dirname(path))
    if (
      !identical(run$method, reference$method) ||
      !identical(run$run_id, reference$run_id) ||
      !identical(run$result_id, reference$result_id)
    ) {
      stop(
        sprintf("Run reference identity mismatch for `%s`.", reference$manifest_path),
        call. = FALSE
      )
    }
  }
  invisible(manifest)
}

wlv_channel_marker_filename <- function(sequence, release_id) {
  sequence <- wlv_publication_validate_sequence(sequence)
  release_id <- wlv_publication_validate_id(release_id, "release_id")
  paste0(sequence, "-", release_id, ".json")
}

wlv_validate_channel_marker <- function(marker) {
  marker <- wlv_publication_exact_object(
    marker,
    wlv_channel_marker_fields,
    "Channel marker"
  )
  marker$schema <- wlv_publication_validate_scalar_text(marker$schema, "schema")
  marker$schema_version <- wlv_publication_validate_scalar_text(
    marker$schema_version,
    "schema_version"
  )
  if (!identical(marker$schema, wlv_channel_marker_schema)) {
    stop("Unsupported channel marker schema.", call. = FALSE)
  }
  if (!identical(marker$schema_version, wlv_publication_schema_version)) {
    stop("Unsupported channel marker schema version.", call. = FALSE)
  }
  marker$channel <- wlv_publication_validate_channel(marker$channel)
  marker$sequence <- wlv_publication_validate_sequence(marker$sequence)
  marker$release_id <- wlv_publication_validate_id(marker$release_id, "release_id")
  path <- wlv_publication_validate_scalar_text(
    marker$release_manifest_path,
    "release_manifest_path"
  )
  normalized_path <- wlv_publication_normalize_relative_paths(
    path,
    "release_manifest_path"
  )
  if (!identical(path, normalized_path)) {
    stop("`release_manifest_path` must already be normalized.", call. = FALSE)
  }
  if (!identical(basename(path), wlv_release_manifest_filename)) {
    stop(
      sprintf("Channel markers must target `%s`.", wlv_release_manifest_filename),
      call. = FALSE
    )
  }
  expected_path <- paste(
    "releases",
    marker$release_id,
    wlv_release_manifest_filename,
    sep = "/"
  )
  if (!identical(path, expected_path)) {
    stop(
      sprintf(
        "Channel marker release must use canonical path `%s`.",
        expected_path
      ),
      call. = FALSE
    )
  }
  marker$release_manifest_path <- path
  marker$release_manifest_sha256 <- wlv_publication_validate_sha256(
    marker$release_manifest_sha256,
    "release_manifest_sha256"
  )
  marker$published_at_utc <- wlv_publication_validate_timestamp(
    marker$published_at_utc,
    "published_at_utc"
  )
  invisible(marker[wlv_channel_marker_fields])
}

wlv_build_channel_marker <- function(
    channel,
    sequence,
    release_id,
    release_manifest_path,
    release_manifest_sha256,
    published_at_utc = wlv_publication_timestamp()) {
  marker <- list(
    schema = wlv_channel_marker_schema,
    schema_version = wlv_publication_schema_version,
    channel = channel,
    sequence = sequence,
    release_id = release_id,
    release_manifest_path = release_manifest_path,
    release_manifest_sha256 = release_manifest_sha256,
    published_at_utc = published_at_utc
  )
  wlv_validate_channel_marker(marker)
}

wlv_read_channel_marker <- function(path) {
  wlv_publication_read_json(path, wlv_validate_channel_marker, "Channel marker")
}

wlv_write_channel_marker <- function(marker, path) {
  marker <- wlv_validate_channel_marker(marker)
  expected_filename <- wlv_channel_marker_filename(
    marker$sequence,
    marker$release_id
  )
  if (!identical(basename(path), expected_filename)) {
    stop(
      sprintf("Channel marker filename must be `%s`.", expected_filename),
      call. = FALSE
    )
  }
  wlv_publication_write_json(
    marker,
    path,
    wlv_read_channel_marker,
    "channel marker"
  )
}

wlv_publication_as_channel_marker <- function(marker) {
  if (is.character(marker) && length(marker) == 1L && !is.na(marker)) {
    return(wlv_read_channel_marker(marker))
  }
  wlv_validate_channel_marker(marker)
}

wlv_validate_channel_marker_path <- function(
    marker,
    publication_root,
    marker_path,
    must_exist = TRUE) {
  marker <- wlv_publication_as_channel_marker(marker)
  marker_path <- wlv_publication_validate_scalar_text(marker_path, "marker_path")
  if (!is.logical(must_exist) || length(must_exist) != 1L || is.na(must_exist)) {
    stop("`must_exist` must be one non-missing logical value.", call. = FALSE)
  }
  expected_filename <- wlv_channel_marker_filename(
    marker$sequence,
    marker$release_id
  )
  if (!identical(basename(marker_path), expected_filename)) {
    stop(
      sprintf(
        "Channel marker sequence does not match filename `%s`.",
        basename(marker_path)
      ),
      call. = FALSE
    )
  }
  if (isTRUE(must_exist) &&
      (!file.exists(marker_path) || isTRUE(file.info(marker_path)$isdir))) {
    stop("Channel marker path is missing or is not a regular file.", call. = FALSE)
  }
  publication_parent <- dirname(publication_root)
  same_as_parent <- identical(
    wlv_publication_path_key(normalizePath(
      publication_root,
      winslash = "/",
      mustWork = TRUE
    )),
    wlv_publication_path_key(normalizePath(
      publication_parent,
      winslash = "/",
      mustWork = TRUE
    ))
  )
  publication_root <- wlv_publication_assert_real_directory(
    publication_root,
    parent = if (same_as_parent) NULL else publication_parent,
    label = "Publication root"
  )
  wlv_publication_assert_real_directory(
    file.path(publication_root, "runs"),
    publication_root,
    "Publication runs root"
  )
  releases_root <- wlv_publication_assert_real_directory(
    file.path(publication_root, "releases"),
    publication_root,
    "Publication releases root"
  )
  wlv_publication_assert_real_directory(
    file.path(releases_root, marker$release_id),
    releases_root,
    sprintf("Publication release `%s`", marker$release_id)
  )
  channels_root <- wlv_publication_assert_real_directory(
    file.path(publication_root, "channels"),
    publication_root,
    "Publication channels root"
  )
  expected_channel_dir <- channels_root
  channel_segments <- strsplit(marker$channel, "/", fixed = TRUE)[[1L]]
  for (segment in channel_segments) {
    candidate <- file.path(expected_channel_dir, segment)
    expected_channel_dir <- wlv_publication_assert_real_directory(
      candidate,
      expected_channel_dir,
      sprintf("Publication channel `%s`", marker$channel)
    )
  }
  marker_dir <- normalizePath(
    dirname(marker_path),
    winslash = "/",
    mustWork = TRUE
  )
  resolved_marker_dir <- marker_dir
  resolved_marker_path <- marker_path
  if (isTRUE(must_exist)) {
    marker_link <- Sys.readlink(marker_path)
    if (length(marker_link) == 1L && !is.na(marker_link) && nzchar(marker_link)) {
      stop("Channel marker must not be a symbolic link.", call. = FALSE)
    }
    resolved_marker_path <- normalizePath(
      marker_path,
      winslash = "/",
      mustWork = TRUE
    )
    resolved_marker_dir <- dirname(resolved_marker_path)
  }
  compare_channels_root <- channels_root
  compare_channel_dir <- expected_channel_dir
  compare_marker_dir <- marker_dir
  compare_resolved_marker_dir <- resolved_marker_dir
  compare_resolved_marker_path <- resolved_marker_path
  compare_expected_marker_path <- file.path(
    expected_channel_dir,
    expected_filename
  )
  if (.Platform$OS.type == "windows") {
    compare_channels_root <- tolower(compare_channels_root)
    compare_channel_dir <- tolower(compare_channel_dir)
    compare_marker_dir <- tolower(compare_marker_dir)
    compare_resolved_marker_dir <- tolower(compare_resolved_marker_dir)
    compare_resolved_marker_path <- tolower(compare_resolved_marker_path)
    compare_expected_marker_path <- tolower(compare_expected_marker_path)
  }
  if (
    !startsWith(
      compare_channel_dir,
      paste0(sub("/+$", "", compare_channels_root), "/")
    ) ||
    !identical(compare_marker_dir, compare_channel_dir) ||
    !identical(compare_resolved_marker_dir, compare_channel_dir) ||
    !identical(compare_resolved_marker_path, compare_expected_marker_path)
  ) {
    stop(
      sprintf(
        "Channel marker path does not match channel `%s`.",
        marker$channel
      ),
      call. = FALSE
    )
  }
  invisible(marker_path)
}

wlv_verify_channel_marker <- function(
    marker,
    publication_root,
    marker_path = NULL,
    verify_release = TRUE) {
  if (
    is.null(marker_path) &&
    is.character(marker) &&
    length(marker) == 1L &&
    !is.na(marker)
  ) {
    marker_path <- marker
  }
  marker <- wlv_publication_as_channel_marker(marker)
  if (!is.logical(verify_release) || length(verify_release) != 1L ||
      is.na(verify_release)) {
    stop("`verify_release` must be one non-missing logical value.", call. = FALSE)
  }
  if (!is.null(marker_path)) {
    wlv_validate_channel_marker_path(
      marker,
      publication_root,
      marker_path,
      must_exist = TRUE
    )
  }
  release_path <- wlv_publication_resolve_files(
    publication_root,
    marker$release_manifest_path,
    "release manifest path"
  )[[1L]]
  actual_hash <- wlv_publication_file_sha256(release_path)
  if (!identical(actual_hash, marker$release_manifest_sha256)) {
    stop("Release manifest SHA-256 mismatch in channel marker.", call. = FALSE)
  }
  release <- wlv_read_release_manifest(release_path)
  if (
    !identical(release$channel, marker$channel) ||
    !identical(release$sequence, marker$sequence) ||
    !identical(release$release_id, marker$release_id)
  ) {
    stop("Channel marker identity differs from its release manifest.", call. = FALSE)
  }
  if (!is.null(marker_path)) {
    runs_root <- wlv_publication_assert_real_directory(
      file.path(publication_root, "runs"),
      publication_root,
      "Publication runs root"
    )
    for (reference in release$runs) {
      method_root <- wlv_publication_assert_real_directory(
        file.path(runs_root, reference$method),
        runs_root,
        sprintf("Publication method `%s`", reference$method)
      )
      wlv_publication_assert_real_directory(
        file.path(method_root, reference$run_id),
        method_root,
        sprintf("Publication run `%s`", reference$run_id)
      )
    }
  }
  if (isTRUE(verify_release)) {
    wlv_verify_release_manifest(
      release,
      dirname(release_path),
      publication_root = publication_root
    )
  }
  invisible(list(
    marker = marker,
    release = release,
    release_path = release_path,
    release_root = dirname(release_path)
  ))
}
