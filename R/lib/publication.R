wlv_publication_output_contract_id <- function() {
  "wlvpanel-output"
}
wlv_publication_output_contract_version <- function() {
  "1.0.0"
}

wlv_publication_paths <- function(root) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  results <- file.path(root, "results")
  list(
    root = root,
    results = results,
    runs = file.path(results, "runs"),
    releases = file.path(results, "releases"),
    channels = file.path(results, "channels"),
    staging = file.path(results, ".staging"),
    trash = file.path(results, ".trash")
  )
}

wlv_publication_ensure_store <- function(root) {
  paths <- wlv_publication_paths(root)
  if (!dir.exists(paths$results) &&
      !dir.create(paths$results, recursive = FALSE, showWarnings = FALSE)) {
    stop(sprintf("Could not create publication directory `%s`.", paths$results),
      call. = FALSE
    )
  }
  paths$results <- wlv_publication_assert_real_directory(
    paths$results,
    paths$root,
    "Publication results root"
  )
  labels <- c(
    runs = "Publication runs root",
    releases = "Publication releases root",
    channels = "Publication channels root",
    staging = "Publication staging root"
  )
  for (name in names(labels)) {
    path <- file.path(
      paths$results,
      switch(name,
        runs = "runs",
        releases = "releases",
        channels = "channels",
        staging = ".staging"
      )
    )
    if (!dir.exists(path) &&
        !dir.create(path, recursive = FALSE, showWarnings = FALSE)) {
      stop(sprintf("Could not create publication directory `%s`.", path),
        call. = FALSE
      )
    }
    paths[[name]] <- wlv_publication_assert_real_directory(
      path,
      paths$results,
      labels[[name]]
    )
  }
  paths$trash <- file.path(paths$results, ".trash")
  paths
}

wlv_publication_channel_directory <- function(
    root,
    channel,
    create = FALSE) {
  channel <- wlv_publication_validate_channel(channel)
  if (!is.logical(create) || length(create) != 1L || is.na(create)) {
    stop("`create` must be one non-missing logical value.", call. = FALSE)
  }
  paths <- if (isTRUE(create)) {
    wlv_publication_ensure_store(root)
  } else {
    value <- wlv_publication_paths(root)
    if (!dir.exists(value$results)) return(NULL)
    value$results <- wlv_publication_assert_real_directory(
      value$results,
      value$root,
      "Publication results root"
    )
    value$channels <- file.path(value$results, "channels")
    if (!dir.exists(value$channels)) return(NULL)
    value$channels <- wlv_publication_assert_real_directory(
      value$channels,
      value$results,
      "Publication channels root"
    )
    value
  }
  current <- paths$channels
  for (segment in strsplit(channel, "/", fixed = TRUE)[[1L]]) {
    candidate <- file.path(current, segment)
    if (!dir.exists(candidate)) {
      if (!isTRUE(create)) return(NULL)
      if (!dir.create(candidate, recursive = FALSE, showWarnings = FALSE)) {
        stop(sprintf("Could not create publication channel `%s`.", channel),
          call. = FALSE
        )
      }
    }
    current <- wlv_publication_assert_real_directory(
      candidate,
      current,
      sprintf("Publication channel `%s`", channel)
    )
  }
  current
}

wlv_publication_safe_id <- function(value, label = "publication identifier") {
  if (
    !is.character(value) || length(value) != 1L || is.na(value) ||
    !grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", value)
  ) {
    stop(sprintf("Invalid %s.", label), call. = FALSE)
  }
  value
}

wlv_new_publication_id <- function(prefix) {
  wlv_publication_safe_id(prefix, "publication ID prefix")
  if (!requireNamespace("openssl", quietly = TRUE)) {
    stop("Package `openssl` is required to create publication IDs.", call. = FALSE)
  }
  now <- Sys.time()
  seconds <- format(now, "%Y%m%dT%H%M%S", tz = "UTC")
  milliseconds <- sprintf("%03d", floor((as.numeric(now) %% 1) * 1000))
  random <- paste0(format(openssl::rand_bytes(8L)), collapse = "")
  paste(prefix, paste0(seconds, milliseconds, "Z"), random, sep = "-")
}

wlv_publication_increment_sequence <- function(sequence = NULL) {
  if (is.null(sequence)) {
    return(strrep("0", 19L) |> paste0("1"))
  }
  if (!is.character(sequence) || length(sequence) != 1L ||
      !grepl("^[0-9]{20}$", sequence)) {
    stop("Publication sequence must contain exactly 20 decimal digits.", call. = FALSE)
  }
  digits <- as.integer(strsplit(sequence, "", fixed = TRUE)[[1L]])
  carry <- 1L
  for (index in rev(seq_along(digits))) {
    value <- digits[[index]] + carry
    digits[[index]] <- value %% 10L
    carry <- value %/% 10L
    if (!carry) break
  }
  if (carry) {
    stop("Publication sequence overflowed its 20-digit namespace.", call. = FALSE)
  }
  paste0(digits, collapse = "")
}

wlv_publication_relative_path <- function(path, parent) {
  parent <- normalizePath(parent, winslash = "/", mustWork = TRUE)
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  compare_parent <- parent
  compare_path <- path
  if (.Platform$OS.type == "windows") {
    compare_parent <- tolower(compare_parent)
    compare_path <- tolower(compare_path)
  }
  prefix <- paste0(sub("/+$", "", compare_parent), "/")
  if (!startsWith(compare_path, prefix)) {
    stop(sprintf("Publication path escapes its root: %s.", path), call. = FALSE)
  }
  chartr("\\", "/", substring(path, nchar(parent) + 2L))
}

wlv_publication_channel_dir <- function(root, channel) {
  channel <- wlv_publication_validate_channel(channel)
  file.path(wlv_publication_paths(root)$channels, channel)
}

wlv_list_channel_markers <- function(root, channel = "stable") {
  channel_dir <- wlv_publication_channel_directory(
    root,
    channel,
    create = FALSE
  )
  if (is.null(channel_dir)) return(character())
  markers <- list.files(
    channel_dir,
    pattern = "^[0-9]{20}-[A-Za-z0-9][A-Za-z0-9._-]*[.]json$",
    full.names = TRUE,
    all.files = FALSE
  )
  sort(markers, method = "radix")
}

wlv_read_current_release_internal <- function(
    root,
    channel,
    required,
    verify_release) {
  if (!is.logical(verify_release) || length(verify_release) != 1L ||
      is.na(verify_release)) {
    stop("`verify_release` must be one non-missing logical value.", call. = FALSE)
  }
  paths <- wlv_publication_paths(root)
  markers <- wlv_list_channel_markers(root, channel)
  if (!length(markers)) {
    if (isTRUE(required)) {
      stop(sprintf("Release channel `%s` has no committed release.", channel), call. = FALSE)
    }
    return(NULL)
  }
  sequences <- substr(basename(markers), 1L, 20L)
  duplicated_sequences <- unique(sequences[duplicated(sequences)])
  if (length(duplicated_sequences)) {
    stop(
      sprintf(
        "Release channel `%s` has more than one marker at sequence(s): %s.",
        channel,
        paste(duplicated_sequences, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  marker_path <- markers[[length(markers)]]
  marker <- wlv_read_channel_marker(marker_path)
  if (!identical(marker$channel, wlv_publication_validate_channel(channel))) {
    stop(
      sprintf(
        "Channel marker in `%s` declares channel `%s`.",
        channel,
        marker$channel
      ),
      call. = FALSE
    )
  }
  verified <- wlv_verify_channel_marker(
    marker,
    publication_root = paths$results,
    marker_path = marker_path,
    verify_release = verify_release
  )
  release_path <- verified$release_path
  release <- verified$release
  release_root <- verified$release_root
  list(
    marker = marker,
    marker_path = normalizePath(marker_path, winslash = "/", mustWork = TRUE),
    manifest = release,
    manifest_path = normalizePath(release_path, winslash = "/", mustWork = TRUE),
    root = normalizePath(release_root, winslash = "/", mustWork = TRUE)
  )
}

wlv_read_current_release <- function(root, channel = "stable", required = FALSE) {
  wlv_read_current_release_internal(
    root,
    channel,
    required,
    verify_release = TRUE
  )
}

wlv_read_current_release_reference <- function(
    root,
    channel = "stable",
    required = FALSE) {
  # This path authenticates the channel marker and release manifest, but
  # intentionally leaves run artifacts to the narrower consumer-specific
  # verification that follows. Public release reads continue to verify every
  # referenced run through `wlv_read_current_release()` above.
  wlv_read_current_release_internal(
    root,
    channel,
    required,
    verify_release = FALSE
  )
}

wlv_release_run_record <- function(release, method) {
  records <- release$manifest$runs
  matches <- which(vapply(records, function(record) {
    identical(record$method, method)
  }, logical(1L)))
  if (length(matches) != 1L) return(NULL)
  records[[matches]]
}

wlv_resolve_method_run_reference <- function(root, method, release) {
  wlv_publication_safe_id(method, "method name")
  paths <- wlv_publication_paths(root)
  if (!is.null(release)) {
    record <- wlv_release_run_record(release, method)
    if (is.null(record)) {
      stop(
        sprintf("Current release `%s` does not contain method `%s`.",
          release$manifest$release_id, method),
        call. = FALSE
      )
    }
    manifest_path <- file.path(paths$results, record$manifest_path)
    manifest <- wlv_read_run_manifest(
      manifest_path,
      expected_sha256 = record$manifest_sha256
    )
    run_root <- dirname(manifest_path)
    if (!identical(manifest$method, record$method) ||
        !identical(manifest$run_id, record$run_id) ||
        !identical(manifest$result_id, record$result_id)) {
      stop("Current run manifest changed after release verification.", call. = FALSE)
    }
    return(list(
      path = normalizePath(run_root, winslash = "/", mustWork = TRUE),
      run_id = manifest$run_id,
      result_id = manifest$result_id,
      manifest = manifest,
      manifest_path = normalizePath(manifest_path, winslash = "/", mustWork = TRUE),
      release_id = release$manifest$release_id
    ))
  }

  stop(sprintf("No published results exist for method `%s`.", method), call. = FALSE)
}

wlv_resolve_current_method_run <- function(
    root,
    method,
    channel = "stable") {
  wlv_resolve_method_run_reference(
    root,
    method,
    wlv_read_current_release(root, channel = channel, required = FALSE)
  )
}

wlv_resolve_current_method_run_reference <- function(
    root,
    method,
    channel = "stable") {
  wlv_resolve_method_run_reference(
    root,
    method,
    wlv_read_current_release_reference(
      root,
      channel = channel,
      required = FALSE
    )
  )
}

wlv_current_result_dir <- function(
    method,
    root = ".",
    channel = getOption("wlv.channel", "stable")) {
  wlv_resolve_current_method_run(
    root = root,
    method = method,
    channel = channel
  )$path
}

wlv_current_release_dir <- function(
    root = ".",
    channel = getOption("wlv.channel", "stable"),
    required = TRUE) {
  release <- wlv_read_current_release(root, channel = channel, required = required)
  if (is.null(release)) NULL else release$root
}

wlv_publication_input_paths <- function(plan, method) {
  record <- plan$methods[match(method, plan$methods$method), , drop = FALSE]
  candidates <- c(
    list.files(
      file.path(plan$root, "R"),
      pattern = "[.]R$",
      recursive = TRUE,
      full.names = TRUE
    ),
    list.files(file.path(plan$root, "catalog"), recursive = TRUE, full.names = TRUE),
    list.files(
      file.path(plan$root, "config"),
      recursive = TRUE,
      full.names = TRUE,
      all.files = TRUE,
      include.dirs = FALSE,
      no.. = TRUE
    ),
    list.files(
      file.path(plan$root, "complementar"),
      recursive = TRUE,
      full.names = TRUE,
      all.files = TRUE,
      include.dirs = FALSE,
      no.. = TRUE
    ),
    list.files(
      file.path(plan$root, "contracts", "results"),
      recursive = TRUE,
      full.names = TRUE,
      all.files = TRUE,
      include.dirs = FALSE,
      no.. = TRUE
    ),
    list.files(
      file.path(plan$root, "contracts", "units"),
      recursive = TRUE,
      full.names = TRUE,
      all.files = TRUE,
      include.dirs = FALSE,
      no.. = TRUE
    ),
    list.files(record$method_dir[[1L]], recursive = TRUE, full.names = TRUE),
    list.files(
      file.path(plan$root, "parameters", record$parameter_set[[1L]]),
      recursive = TRUE,
      full.names = TRUE
    ),
    list.files(
      file.path(plan$root, "parameters", "common_ground"),
      recursive = TRUE,
      full.names = TRUE
    ),
    file.path(plan$root, c("DESCRIPTION", "renv.lock", "scripts/run_wlv.R"))
  )
  candidates <- unique(candidates[file.exists(candidates)])
  candidates <- candidates[!file.info(candidates)$isdir]
  sort(normalizePath(candidates, winslash = "/", mustWork = TRUE), method = "radix")
}

wlv_publication_input_inventory_capture <- function(
    plan,
    method,
    paths = wlv_publication_input_paths(plan, method)) {
  lapply(paths, function(path) {
    list(
      path = wlv_publication_relative_path(path, plan$root),
      sha256 = wlv_publication_file_sha256(path)
    )
  })
}

wlv_publication_input_path_stamps <- function(paths) {
  if (!is.character(paths) || anyNA(paths) || any(!nzchar(paths)) ||
      anyDuplicated(paths)) {
    stop("Publication input paths are invalid.", call. = FALSE)
  }
  info <- file.info(paths, extra_cols = FALSE)
  if (nrow(info) != length(paths) || anyNA(info$isdir) || any(info$isdir) ||
      anyNA(info$size) || anyNA(info$mtime) || anyNA(info$ctime)) {
    stop("Publication input metadata could not be captured.", call. = FALSE)
  }
  lapply(seq_along(paths), function(index) {
    list(
      path = paths[[index]],
      size = as.double(info$size[[index]]),
      mtime = as.double(info$mtime[[index]]),
      ctime = as.double(info$ctime[[index]])
    )
  })
}

wlv_publication_input_receipt <- function(
    plan,
    method,
    inventory,
    paths,
    stamps) {
  relative <- vapply(inventory, `[[`, character(1L), "path")
  stamp_paths <- vapply(stamps, `[[`, character(1L), "path")
  if (!is.character(method) || length(method) != 1L || is.na(method) ||
      !nzchar(method) || !is.list(inventory) ||
      !is.character(paths) || anyNA(paths) || any(!nzchar(paths)) ||
      anyDuplicated(paths) || !is.list(stamps) ||
      !identical(length(stamps), length(paths)) ||
      !identical(stamp_paths, paths) ||
      !identical(length(relative), length(paths))) {
    stop("Publication input receipt values are invalid.", call. = FALSE)
  }
  receipt <- new.env(parent = emptyenv())
  receipt$schema <- "wlv-publication-input-receipt/1.0.0"
  receipt$root <- normalizePath(plan$root, winslash = "/", mustWork = TRUE)
  receipt$method <- method
  receipt$inventory <- inventory
  receipt$paths <- paths
  receipt$stamps <- stamps
  lockEnvironment(receipt, bindings = TRUE)
  receipt
}

wlv_publication_input_capture <- function(
    plan,
    method,
    stabilize = TRUE) {
  if (!is.logical(stabilize) || length(stabilize) != 1L || is.na(stabilize)) {
    stop("Publication input stabilization flag is invalid.", call. = FALSE)
  }
  first_paths <- wlv_publication_input_paths(plan, method)
  first_stamps <- wlv_publication_input_path_stamps(first_paths)
  first <- wlv_publication_input_inventory_capture(
    plan,
    method,
    paths = first_paths
  )
  second_paths <- wlv_publication_input_paths(plan, method)
  second_stamps <- wlv_publication_input_path_stamps(second_paths)
  if (!identical(first_paths, second_paths) ||
      !identical(first_stamps, second_stamps)) {
    stop(
      sprintf(
        "Publication inputs changed while method `%s` was being inventoried.",
        method
      ),
      call. = FALSE
    )
  }
  if (!isTRUE(stabilize)) {
    # Hash content once, then re-enumerate the paths and compare filesystem
    # change stamps around that pass. This detects additions/removals and
    # same-path writes without doubling all content I/O. As with any completed
    # capture, later writes are rejected by the next transactional boundary.
    return(list(
      inventory = first,
      receipt = wlv_publication_input_receipt(
        plan,
        method,
        first,
        second_paths,
        second_stamps
      )
    ))
  }
  second <- wlv_publication_input_inventory_capture(
    plan,
    method,
    paths = second_paths
  )
  final_paths <- wlv_publication_input_paths(plan, method)
  final_stamps <- wlv_publication_input_path_stamps(final_paths)
  if (!identical(second_paths, final_paths) ||
      !identical(second_stamps, final_stamps) ||
      !identical(first, second)) {
    stop(
      sprintf(
        "Publication inputs changed while method `%s` was being inventoried.",
        method
      ),
      call. = FALSE
    )
  }
  list(
    inventory = first,
    receipt = wlv_publication_input_receipt(
      plan,
      method,
      first,
      final_paths,
      final_stamps
    )
  )
}

wlv_publication_input_inventory <- function(
    plan,
    method,
    stabilize = TRUE) {
  wlv_publication_input_capture(
    plan,
    method,
    stabilize = stabilize
  )$inventory
}

wlv_capture_plan_publication_inputs <- function(plan) {
  if (!is.list(plan) || !is.character(plan$method_names) ||
      !length(plan$method_names) || anyNA(plan$method_names)) {
    stop("A method plan is required to capture publication inputs.", call. = FALSE)
  }
  captures <- lapply(plan$method_names, function(method) {
    # The preflight capture is bracketed by exact path/size/mtime/ctime stamps.
    # A mandatory two-pass strong capture remains at the final commit boundary.
    wlv_publication_input_capture(plan, method, stabilize = FALSE)
  })
  inventories <- lapply(captures, `[[`, "inventory")
  names(inventories) <- plan$method_names
  receipts <- lapply(captures, `[[`, "receipt")
  names(receipts) <- plan$method_names
  cache <- new.env(parent = emptyenv())
  cache$schema <- "wlv-publication-input-receipt-cache/1.0.0"
  cache$root <- normalizePath(plan$root, winslash = "/", mustWork = TRUE)
  cache$methods <- plan$method_names
  cache$receipts <- receipts
  lockEnvironment(cache, bindings = TRUE)
  attr(inventories, "wlv_publication_input_receipts") <- cache
  inventories
}

wlv_plan_publication_input_inventory <- function(plan, method) {
  if (!is.character(method) || length(method) != 1L || is.na(method) ||
      is.null(plan$publication_inputs) ||
      !identical(names(plan$publication_inputs), plan$method_names) ||
      !method %in% names(plan$publication_inputs)) {
    stop(
      "The run plan lacks its immutable preflight publication inventory.",
      call. = FALSE
    )
  }
  plan$publication_inputs[[method]]
}

wlv_plan_publication_input_receipt <- function(plan, method) {
  expected <- wlv_plan_publication_input_inventory(plan, method)
  cache <- attr(
    plan$publication_inputs,
    "wlv_publication_input_receipts",
    exact = TRUE
  )
  valid <- tryCatch({
    cache_fields <- if (is.environment(cache)) {
      sort(ls(cache, all.names = TRUE), method = "radix")
    } else {
      character()
    }
    required_cache_fields <- sort(
      c("schema", "root", "methods", "receipts"),
      method = "radix"
    )
    if (!is.environment(cache) || !identical(parent.env(cache), emptyenv()) ||
        !environmentIsLocked(cache) ||
        !identical(cache_fields, required_cache_fields) ||
        !all(vapply(cache_fields, bindingIsLocked, logical(1L), env = cache)) ||
        any(vapply(cache_fields, bindingIsActive, logical(1L), env = cache)) ||
        !identical(cache$schema, "wlv-publication-input-receipt-cache/1.0.0") ||
        !identical(
          cache$root,
          normalizePath(plan$root, winslash = "/", mustWork = TRUE)
        ) || !identical(cache$methods, plan$method_names) ||
        !is.list(cache$receipts) ||
        !identical(names(cache$receipts), plan$method_names)) {
      return(NULL)
    }
    receipt <- cache$receipts[[method]]
    receipt_fields <- if (is.environment(receipt)) {
      sort(ls(receipt, all.names = TRUE), method = "radix")
    } else {
      character()
    }
    required_receipt_fields <- sort(
      c("schema", "root", "method", "inventory", "paths", "stamps"),
      method = "radix"
    )
    if (!is.environment(receipt) ||
        !identical(parent.env(receipt), emptyenv()) ||
        !environmentIsLocked(receipt) ||
        !identical(receipt_fields, required_receipt_fields) ||
        !all(vapply(
          receipt_fields,
          bindingIsLocked,
          logical(1L),
          env = receipt
        )) || any(vapply(
          receipt_fields,
          bindingIsActive,
          logical(1L),
          env = receipt
        )) ||
        !identical(receipt$schema, "wlv-publication-input-receipt/1.0.0") ||
        !identical(receipt$root, cache$root) ||
        !identical(receipt$method, method) ||
        !identical(receipt$inventory, expected)) {
      return(NULL)
    }
    stamp_paths <- vapply(receipt$stamps, `[[`, character(1L), "path")
    if (!is.character(receipt$paths) || anyNA(receipt$paths) ||
        any(!nzchar(receipt$paths)) || anyDuplicated(receipt$paths) ||
        !identical(stamp_paths, receipt$paths) ||
        !identical(length(receipt$paths), length(expected))) {
      return(NULL)
    }
    receipt
  }, error = function(error) NULL)
  valid
}

wlv_publication_input_receipt_is_current <- function(plan, method, receipt) {
  if (is.null(receipt)) return(FALSE)
  tryCatch({
    paths <- wlv_publication_input_paths(plan, method)
    stamps <- wlv_publication_input_path_stamps(paths)
    identical(paths, receipt$paths) && identical(stamps, receipt$stamps)
  }, error = function(error) FALSE)
}

wlv_publication_changed_inputs <- function(expected, current) {
  expected_paths <- vapply(expected, `[[`, character(1L), "path")
  current_paths <- vapply(current, `[[`, character(1L), "path")
  paths <- union(expected_paths, current_paths)
  expected_hashes <- stats::setNames(
    vapply(expected, `[[`, character(1L), "sha256"),
    expected_paths
  )
  current_hashes <- stats::setNames(
    vapply(current, `[[`, character(1L), "sha256"),
    current_paths
  )
  paths[vapply(paths, function(path) {
    !path %in% expected_paths || !path %in% current_paths ||
      !identical(expected_hashes[[path]], current_hashes[[path]])
  }, logical(1L))]
}

wlv_assert_plan_publication_inputs_unchanged <- function(
    plan,
    methods = plan$method_names,
    stabilize = FALSE,
    use_receipt = FALSE) {
  if (!is.character(methods) || !length(methods) || anyNA(methods) ||
      any(!methods %in% plan$method_names)) {
    stop("Publication input verification received invalid methods.", call. = FALSE)
  }
  if (!is.logical(stabilize) || length(stabilize) != 1L || is.na(stabilize)) {
    stop("Publication input stabilization flag is invalid.", call. = FALSE)
  }
  if (!is.logical(use_receipt) || length(use_receipt) != 1L ||
      is.na(use_receipt)) {
    stop("Publication input receipt flag is invalid.", call. = FALSE)
  }
  for (method in methods) {
    expected <- wlv_plan_publication_input_inventory(plan, method)
    receipt <- if (isTRUE(use_receipt) && !isTRUE(stabilize)) {
      wlv_plan_publication_input_receipt(plan, method)
    } else {
      NULL
    }
    if (wlv_publication_input_receipt_is_current(plan, method, receipt)) {
      next
    }
    # The immutable preflight inventory is already stabilized by two complete
    # captures. Intermediate transaction boundaries hash each file once and
    # bind that pass to stable paths and filesystem change stamps. The final
    # boundary requests two complete captures because Windows timestamps can be
    # restored after a same-size overwrite.
    current <- wlv_publication_input_inventory(
      plan,
      method,
      stabilize = stabilize
    )
    if (!identical(expected, current)) {
      changed <- wlv_publication_changed_inputs(expected, current)
      stop(
        sprintf(
          paste0(
            "Runtime or configuration inputs changed after preflight ",
            "validation for method `%s`: %s."
          ),
          method,
          paste(changed, collapse = ", ")
        ),
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

wlv_git_publication_status_scope <- function(input_inventory) {
  input_paths <- vapply(input_inventory, `[[`, character(1L), "path")
  status_scope <- vapply(input_paths, function(path) {
    components <- strsplit(path, "/", fixed = TRUE)[[1L]]
    if (components[[1L]] %in% c("R", "catalog", "config", "complementar")) {
      return(components[[1L]])
    }
    if (identical(components[[1L]], "contracts") &&
        length(components) >= 2L &&
        components[[2L]] %in% c("results", "units")) {
      return(paste0("contracts/", components[[2L]]))
    }
    if (components[[1L]] %in% c("methods", "parameters") &&
        length(components) >= 2L) {
      return(paste(components[seq_len(2L)], collapse = "/"))
    }
    path
  }, character(1L))
  sort(
    unique(c(
      status_scope,
      "R",
      "catalog",
      "complementar",
      "contracts/results",
      "contracts/units",
      "DESCRIPTION",
      "renv.lock",
      "scripts/run_wlv.R"
    )),
    method = "radix"
  )
}

wlv_git_publication_provenance <- function(root, input_inventory) {
  git <- Sys.which("git")
  repository_detected <- file.exists(file.path(root, ".git"))
  if (!repository_detected) {
    return(list(
      commit = NULL,
      dirty = NULL,
      status_sha256 = NULL,
      input_tree_sha256 = wlv_source_sha256_raw(charToRaw(enc2utf8(
        wlv_publication_canonical_json(input_inventory)
      )))
    ))
  }
  if (!nzchar(git)) {
    stop(
      "Git is required to record provenance for a detected repository.",
      call. = FALSE
    )
  }
  run_git <- function(arguments, operation) {
    output <- tryCatch(
      suppressWarnings(system2(
        git,
        c("-C", shQuote(root), arguments),
        stdout = TRUE,
        stderr = FALSE
      )),
      error = function(error) {
        stop(
          sprintf("Git failed while attempting to %s.", operation),
          call. = FALSE
        )
      }
    )
    status <- attr(output, "status")
    if (!is.null(status) && !identical(as.integer(status), 0L)) {
      stop(
        sprintf("Git failed while attempting to %s.", operation),
        call. = FALSE
      )
    }
    output
  }
  commit <- run_git(c("rev-parse", "HEAD"), "read the publication commit")
  if (length(commit) != 1L ||
      !grepl("^[0-9a-fA-F]{40}([0-9a-fA-F]{24})?$", trimws(commit[[1L]]))) {
    stop("Git returned an invalid publication commit identity.", call. = FALSE)
  }
  status_scope <- wlv_git_publication_status_scope(input_inventory)
  status <- run_git(c(
    "status", "--porcelain=v1", "--untracked-files=all", "--",
    shQuote(status_scope)
  ), "inspect publication input status")
  status <- sort(enc2utf8(status), method = "radix")
  status_payload <- charToRaw(enc2utf8(paste(status, collapse = "\n")))
  list(
    commit = tolower(trimws(commit[[1L]])),
    dirty = length(status) > 0L,
    status_sha256 = wlv_source_sha256_raw(status_payload),
    input_tree_sha256 = wlv_source_sha256_raw(charToRaw(enc2utf8(
      wlv_publication_canonical_json(input_inventory)
    )))
  )
}

wlv_runtime_package_inventory <- function() {
  packages <- if (exists("wlv_dependency_groups", inherits = TRUE)) {
    groups <- get("wlv_dependency_groups", inherits = TRUE)
    if (is.list(groups) && is.character(groups$runtime)) {
      groups$runtime
    } else {
      loadedNamespaces()
    }
  } else {
    loadedNamespaces()
  }
  packages <- sort(unique(packages), method = "radix")
  lapply(packages, function(package) {
    list(name = package, version = as.character(utils::packageVersion(package)))
  })
}

wlv_array_schema_from_sidecar <- function(path) {
  metadata_path <- paste0(path, ".meta")
  metadata <- readRDS(metadata_path)
  dimensions <- metadata$dim
  labels <- if (!is.null(metadata$array_dimnames)) {
    metadata$array_dimnames
  } else {
    metadata[seq.int(2L, length(dimensions) + 1L)]
  }
  axis_names <- names(labels)
  if (is.null(axis_names)) axis_names <- rep("", length(labels))
  axes <- lapply(seq_along(labels), function(index) {
    list(
      name = if (nzchar(axis_names[[index]])) axis_names[[index]] else paste0("axis", index),
      labels = if (is.null(labels[[index]])) NULL else as.character(labels[[index]])
    )
  })
  list(
    artifact = basename(path),
    dimensions = as.integer(dimensions),
    axes = axes
  )
}

wlv_staged_result_schema <- function(staging) {
  arrays <- sort(list.files(staging, pattern = "[.]fst$", full.names = TRUE), method = "radix")
  list(arrays = lapply(arrays, wlv_array_schema_from_sidecar))
}

wlv_publication_source_manifest_projection <- function(manifest) {
  wlv_validate_source_manifest(manifest)
  lapply(seq_len(nrow(manifest)), function(index) {
    lapply(manifest[index, , drop = FALSE], function(value) {
      enc2utf8(as.character(value[[1L]]))
    })
  })
}

wlv_publication_source_input_inventory <- function(root, paths = character()) {
  if (is.null(paths)) paths <- character()
  if (!is.character(paths) || anyNA(paths) || any(!nzchar(paths))) {
    stop("Additional source provenance inputs must be file paths.", call. = FALSE)
  }
  if (!length(paths)) return(list())
  normalized <- normalizePath(paths, winslash = "/", mustWork = TRUE)
  if (any(file.info(normalized)$isdir %in% TRUE)) {
    stop("Additional source provenance inputs must be files.", call. = FALSE)
  }
  relative <- vapply(
    normalized,
    wlv_publication_relative_path,
    character(1L),
    parent = root
  )
  if (anyDuplicated(relative)) {
    stop("Additional source provenance inputs must be unique.", call. = FALSE)
  }
  order_index <- order(relative, method = "radix")
  lapply(order_index, function(index) {
    record <- wlv_publication_file_record(normalized[[index]])
    list(
      path = relative[[index]],
      size_bytes = record$size_bytes,
      sha256 = record$sha256
    )
  })
}

wlv_restore_publication_warning_unicode <- function(values) {
  matches <- gregexpr("<U[+][0-9A-Fa-f]{4,6}>", values, perl = TRUE)
  replacements <- lapply(regmatches(values, matches), function(tokens) {
    vapply(tokens, function(token) {
      codepoint <- strtoi(
        substring(token, 4L, nchar(token) - 1L),
        base = 16L
      )
      if (is.na(codepoint) || codepoint > 0x10FFFF ||
          codepoint %in% 0xD800:0xDFFF) {
        return(token)
      }
      intToUtf8(codepoint)
    }, character(1L))
  })
  regmatches(values, matches) <- replacements
  enc2utf8(values)
}

wlv_sanitize_publication_warnings <- function(warnings, root) {
  if (is.null(warnings)) return(character())
  if (!is.character(warnings) || anyNA(warnings)) {
    stop("Publication warnings must be character data without NA.", call. = FALSE)
  }
  if (!length(warnings)) return(character())

  warnings <- enc2utf8(warnings)
  warnings <- iconv(warnings, from = "UTF-8", to = "UTF-8", sub = "")
  warnings[is.na(warnings)] <- "[warning text unavailable]"
  warnings <- wlv_restore_publication_warning_unicode(warnings)
  warnings <- gsub("[\r\n\t]+", " ", warnings, perl = TRUE)
  warnings <- gsub("[[:cntrl:]]+", " ", warnings, perl = TRUE)

  redactions <- list(
    "<project-root>" = root,
    "<home-root>" = path.expand("~"),
    "<temp-root>" = tempdir()
  )
  redaction_records <- do.call(rbind, lapply(names(redactions), function(token) {
    path <- normalizePath(redactions[[token]], winslash = "/", mustWork = FALSE)
    data.frame(
      token = token,
      path = unique(c(path, chartr("/", "\\", path))),
      stringsAsFactors = FALSE
    )
  }))
  redaction_records <- redaction_records[
    order(nchar(redaction_records$path), decreasing = TRUE),
    ,
    drop = FALSE
  ]
  for (index in seq_len(nrow(redaction_records))) {
    path <- redaction_records$path[[index]]
    if (.Platform$OS.type == "windows") {
      warnings <- gsub(
        paste0("(?i)\\Q", path, "\\E"),
        redaction_records$token[[index]],
        warnings,
        perl = TRUE
      )
    } else {
      warnings <- gsub(
        path,
        redaction_records$token[[index]],
        warnings,
        fixed = TRUE
      )
    }
  }

  warnings <- gsub(
    "(?i)\\b[A-Z][A-Z0-9+.-]*://[^,;<>\"'`]+",
    "<url>",
    warnings,
    perl = TRUE
  )
  warnings <- gsub(
    paste0(
      "(?i)\\b((?:token|password|passwd|secret|api[_-]?key|authorization)",
      "[[:space:]]*[:=][[:space:]]*)([\"'`]).+?\\2"
    ),
    "\\1<redacted>",
    warnings,
    perl = TRUE
  )
  warnings <- gsub(
    paste0(
      "(?i)\\b(authorization[[:space:]]*[:=][[:space:]]*)",
      "(?:(?:bearer|basic)[[:space:]]+)?[^[:space:],;]+"
    ),
    "\\1<redacted>",
    warnings,
    perl = TRUE
  )
  warnings <- gsub(
    paste0(
      "(?i)\\b((?:token|password|passwd|secret|api[_-]?key)",
      "[[:space:]]*[:=][[:space:]]*)[^[:space:],;]+"
    ),
    "\\1<redacted>",
    warnings,
    perl = TRUE
  )
  warnings <- gsub(
    "(?i)([\"'`])(?:[A-Z]:[\\\\/]|\\\\\\\\|/).+?\\1",
    "<absolute-path>",
    warnings,
    perl = TRUE
  )
  warnings <- gsub(
    "(?i)file:(?://+)?(?:[A-Z]:)?[\\\\/][^,;<>\"'`]+",
    "<absolute-path>",
    warnings,
    perl = TRUE
  )
  warnings <- gsub(
    "(?i)(?:[A-Z]:[\\\\/]|\\\\\\\\)[^,;<>\"'`]+",
    "<absolute-path>",
    warnings,
    perl = TRUE
  )
  warnings <- gsub(
    "(?<![:/])//[^,;<>\"'`]+",
    "<absolute-path>",
    warnings,
    perl = TRUE
  )
  warnings <- gsub(
    "(?<![:/])/(?:[^,;<>\"'`]+)",
    "<absolute-path>",
    warnings,
    perl = TRUE
  )
  warnings <- trimws(gsub("[[:space:]]+", " ", warnings, perl = TRUE))
  warnings[!nzchar(warnings)] <- "[warning without message]"
  unique(enc2utf8(warnings))
}

wlv_result_artifact_role <- function(path) {
  name <- basename(path)
  if (endsWith(name, ".fst.meta")) return("array_metadata")
  if (endsWith(name, ".fst")) return("array")
  if (identical(name, "_panel_indicators.csv")) return("panel_labels")
  if (identical(name, "_panel_meta_indicators.csv")) return("panel_metadata")
  if (grepl("diagnostic|scientific|anomal", name, ignore.case = TRUE)) return("diagnostic")
  if (grepl("contract|provenance|states", name, ignore.case = TRUE)) return("contract")
  "metadata"
}

wlv_capture_validated_run_artifacts <- function(staging) {
  artifacts <- wlv_publication_list_files(
    staging,
    exclude = wlv_run_manifest_filename()
  )
  roles <- vapply(artifacts, wlv_result_artifact_role, character(1L))
  wlv_publication_build_artifacts(
    root = staging,
    artifacts = artifacts,
    artifact_roles = roles,
    allow_empty = FALSE,
    excluded_paths = wlv_run_manifest_filename()
  )
}

wlv_assert_staged_validation_snapshot <- function(before, after) {
  before <- wlv_publication_validate_artifact_records(
    before,
    label = "pre-validation artifacts"
  )
  after <- wlv_publication_validate_artifact_records(
    after,
    label = "validated artifacts"
  )
  mutable <- "_scientific_checks.csv"
  before_paths <- vapply(before, `[[`, character(1L), "path")
  after_paths <- vapply(after, `[[`, character(1L), "path")
  if (!mutable %in% after_paths) {
    stop(
      "Staged validation did not produce `_scientific_checks.csv`.",
      call. = FALSE
    )
  }
  stable_before <- before[before_paths != mutable]
  stable_after <- after[after_paths != mutable]
  if (!identical(stable_before, stable_after)) {
    stop(
      paste0(
        "Staged result artifacts changed while their semantic contracts ",
        "were being validated."
      ),
      call. = FALSE
    )
  }
  invisible(after)
}

wlv_run_manifest_result <- function(
    plan,
    method,
    staging,
    run_data) {
  input_inventory <- wlv_plan_publication_input_inventory(plan, method)
  input_paths <- vapply(input_inventory, `[[`, character(1L), "path")
  renv_index <- match("renv.lock", input_paths)
  source_provenance <- lapply(seq_len(nrow(run_data$source_provenance)), function(index) {
    as.list(run_data$source_provenance[index, , drop = FALSE])
  })
  source_manifest <- wlv_publication_source_manifest_projection(
    run_data$source_manifest
  )
  additional_source_inputs <- run_data$source_provenance_input_inventory
  if (!is.list(additional_source_inputs)) {
    stop(
      "Validated run data lack the additional source input inventory.",
      call. = FALSE
    )
  }
  if (is.null(run_data$runtime_compatibility)) {
    stop("Validated run data lack runtime compatibility provenance.",
      call. = FALSE
    )
  }
  runtime_compatibility <- wlv_runtime_compatibility_manifest(
    run_data$runtime_compatibility
  )
  anomaly_path <- file.path(staging, "_anomalies.csv")
  anomaly_count <- if (file.exists(anomaly_path)) {
    nrow(utils::read.csv2(anomaly_path, stringsAsFactors = FALSE))
  } else {
    0L
  }
  diagnostics <- sort(unique(c(
    basename(list.files(
      staging,
      pattern = wlv_scientific_sidecar_pattern(),
      full.names = TRUE
    )),
    if (file.exists(anomaly_path)) "_anomalies.csv" else character()
  )), method = "radix")
  list(
    provenance = list(
      complete = TRUE,
      git = wlv_git_publication_provenance(plan$root, input_inventory),
      renv_lock_sha256 = if (!is.na(renv_index)) {
        input_inventory[[renv_index]]$sha256
      } else {
        NULL
      },
      packages = wlv_runtime_package_inventory(),
      inputs = input_inventory,
      runtime_compatibility = runtime_compatibility,
      source = list(
        summary = source_provenance,
        manifest = source_manifest,
        additional_inputs = additional_source_inputs
      )
    ),
    request = list(
      mode = plan$mode,
      method = method,
      workers = plan$workers,
      at_stage = if (identical(plan$mode, "recalculate")) plan$at_stage else NULL,
      sea_vars = if (identical(plan$mode, "recalculate")) plan$sea_vars else NULL
    ),
    schema = wlv_staged_result_schema(staging),
    audit_summary = list(
      anomaly_count = anomaly_count,
      diagnostics = diagnostics
    )
  )
}

wlv_run_manifest_host <- function() {
  info <- Sys.info()
  list(
    r_version = as.character(getRversion()),
    platform = R.version$platform,
    os = unname(info[["sysname"]]),
    arch = unname(info[["machine"]])
  )
}

wlv_promote_method_run <- function(
    plan,
    method,
    staging,
    run_environment,
    run_data,
    run_id,
    parent_run_id = NULL,
    started_at,
    warnings = character()) {
  validated_artifacts <- run_environment$wlv_validated_run_artifacts
  if (is.null(validated_artifacts)) {
    stop(
      "Run promotion requires the semantic-validation artifact snapshot.",
      call. = FALSE
    )
  }
  validated_artifacts <- wlv_publication_validate_artifact_records(
    validated_artifacts,
    label = "validated artifacts"
  )
  wlv_assert_plan_publication_inputs_unchanged(
    plan,
    method,
    use_receipt = TRUE
  )
  method_record <- plan$methods[
    match(method, plan$methods$method),
    ,
    drop = FALSE
  ]
  wlv_assert_method_source_inputs_unchanged(
    plan,
    method_record,
    run_data,
    use_receipt = TRUE
  )
  paths <- wlv_publication_ensure_store(plan$root)
  finished_at <- Sys.time()
  artifacts <- sort(list.files(
    staging,
    recursive = TRUE,
    full.names = FALSE,
    all.files = TRUE,
    include.dirs = FALSE,
    no.. = TRUE
  ), method = "radix")
  artifacts <- artifacts[artifacts != wlv_run_manifest_filename()]
  roles <- vapply(artifacts, wlv_result_artifact_role, character(1L))
  result <- wlv_run_manifest_result(
    plan,
    method,
    staging,
    run_data
  )
  execution <- list(
    started_at_utc = wlv_publication_timestamp(started_at),
    finished_at_utc = wlv_publication_timestamp(finished_at),
    duration_seconds = unname(as.numeric(difftime(finished_at, started_at, units = "secs"))),
    warnings = wlv_sanitize_publication_warnings(warnings, plan$root),
    host = wlv_run_manifest_host()
  )
  manifest <- wlv_build_run_manifest(
    run_root = staging,
    artifacts = artifacts,
    artifact_roles = roles,
    run_id = run_id,
    method = method,
    result = result,
    execution = execution,
    parent_run_id = parent_run_id,
    output_contract_id = wlv_publication_output_contract_id(),
    output_contract_version = wlv_publication_output_contract_version(),
    validated_artifacts = validated_artifacts
  )
  if (!identical(manifest$artifacts, validated_artifacts)) {
    stop(
      paste0(
        "Staged result artifacts changed after semantic validation and ",
        "cannot be authenticated."
      ),
      call. = FALSE
    )
  }
  manifest_path <- file.path(staging, wlv_run_manifest_filename())
  wlv_write_run_manifest(manifest, manifest_path)
  # `validated_artifacts` is the post-semantic hash snapshot used verbatim by
  # the manifest. The mandatory full verification after the directory rename
  # below closes the remaining staging-to-run window before this function
  # returns an immutable run.
  wlv_assert_plan_publication_inputs_unchanged(
    plan,
    method,
    use_receipt = TRUE
  )
  wlv_assert_method_source_inputs_unchanged(
    plan,
    method_record,
    run_data,
    use_receipt = TRUE
  )

  staging <- wlv_publication_assert_real_directory(
    staging,
    paths$staging,
    "Validated run staging"
  )
  method_root <- file.path(paths$runs, method)
  if (!dir.exists(method_root) &&
      !dir.create(method_root, recursive = FALSE, showWarnings = FALSE)) {
    stop(sprintf("Could not create run store for method `%s`.", method),
      call. = FALSE
    )
  }
  method_root <- wlv_publication_assert_real_directory(
    method_root,
    paths$runs,
    sprintf("Run store for method `%s`", method)
  )
  final <- file.path(method_root, run_id)
  if (file.exists(final)) {
    stop(sprintf("Run destination already exists: %s.", final), call. = FALSE)
  }
  if (!file.rename(staging, final)) {
    stop(sprintf("Could not promote validated run `%s`.", run_id), call. = FALSE)
  }
  final <- normalizePath(final, winslash = "/", mustWork = TRUE)
  installed_manifest <- wlv_read_run_manifest(file.path(final, wlv_run_manifest_filename()))
  if (!wlv_publication_json_identical(installed_manifest, manifest)) {
    stop("Installed run manifest differs from its verified staging manifest.",
      call. = FALSE
    )
  }
  wlv_verify_run_manifest(
    installed_manifest,
    final,
    reject_unlisted = TRUE
  )
  run_environment$wlv_run_id <- installed_manifest$run_id
  run_environment$wlv_result_id <- installed_manifest$result_id
  run_environment$wlv_run_dir <- final
  run_environment$wlv_run_manifest <- installed_manifest
  run_environment$wlv_source_manifest <- run_data$source_manifest
  run_environment$wlv_source_provenance <- run_data$source_provenance
  run_environment$wlv_source_provenance_inputs <-
    run_data$source_provenance_inputs
  run_environment$wlv_source_provenance_input_inventory <-
    run_data$source_provenance_input_inventory
  run_environment$wlv_source_input_receipt <- run_data$source_input_receipt
  wlv_assert_run_environments_source_inputs_unchanged(
    plan,
    list(run_environment),
    use_receipt = TRUE
  )
  run_environment
}

wlv_read_panel_result_csv <- function(
    path,
    columns,
    expected_sha256 = NULL) {
  size <- unname(file.info(path)$size)
  if (is.na(size) || size <= 0 || size > .Machine$integer.max) {
    stop(sprintf("Panel metadata `%s` has an invalid file size.", path), call. = FALSE)
  }
  bytes <- readBin(path, what = "raw", n = as.integer(size))
  size_after <- unname(file.info(path)$size)
  if (!identical(length(bytes), as.integer(size)) ||
      !identical(size, size_after)) {
    stop(sprintf("Panel metadata `%s` changed while being captured.", path),
      call. = FALSE
    )
  }
  if (!is.null(expected_sha256) &&
      !identical(wlv_publication_sha256_raw(bytes), expected_sha256)) {
    stop(sprintf("Panel metadata `%s` SHA-256 mismatch.", path), call. = FALSE)
  }
  decoded <- tryCatch(rawToChar(bytes), error = function(error) NA_character_)
  if (length(decoded) != 1L || is.na(decoded) ||
      is.na(iconv(decoded, from = "UTF-8", to = "UTF-8", sub = NA))) {
    stop(sprintf("Panel metadata `%s` is not valid UTF-8.", path), call. = FALSE)
  }
  Encoding(decoded) <- "UTF-8"
  connection <- textConnection(decoded, open = "r", encoding = "UTF-8")
  on.exit(close(connection), add = TRUE)
  value <- utils::read.csv2(
    connection,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = "NA"
  )
  if (!identical(names(value), columns)) {
    stop(sprintf("Panel metadata `%s` has an incompatible schema.", path), call. = FALSE)
  }
  value
}

wlv_merge_panel_result_tables <- function(
    paths,
    key,
    columns,
    expected_sha256 = NULL) {
  if (is.null(expected_sha256)) {
    expected_sha256 <- rep(list(NULL), length(paths))
  } else {
    expected_sha256 <- as.list(expected_sha256)
  }
  if (length(expected_sha256) != length(paths)) {
    stop("Panel metadata paths and hashes must have equal lengths.", call. = FALSE)
  }
  tables <- lapply(seq_along(paths), function(index) {
    wlv_read_panel_result_csv(
      paths[[index]],
      columns = columns,
      expected_sha256 = expected_sha256[[index]]
    )
  })
  combined <- do.call(rbind, tables)
  keys <- sort(unique(as.character(combined[[key]])), method = "radix")
  rows <- lapply(keys, function(value) {
    group <- combined[as.character(combined[[key]]) == value, , drop = FALSE]
    result <- group[1L, , drop = FALSE]
    for (column in setdiff(columns, key)) {
      candidates <- group[[column]][!is.na(group[[column]])]
      candidates <- unique(candidates)
      if (length(candidates) > 1L) {
        stop(
          sprintf("Conflicting panel metadata for `%s` field `%s`.", value, column),
          call. = FALSE
        )
      }
      result[[column]] <- if (length(candidates)) candidates[[1L]] else NA
    }
    result
  })
  merged <- do.call(rbind, rows)
  rownames(merged) <- NULL
  merged
}

wlv_commit_release <- function(plan, run_environments) {
  wlv_assert_plan_publication_inputs_unchanged(plan, use_receipt = TRUE)
  wlv_assert_run_environments_source_inputs_unchanged(
    plan,
    run_environments,
    use_receipt = TRUE
  )
  paths <- wlv_publication_ensure_store(plan$root)
  # Only the marker and release manifest are needed to compose the next
  # release. Runs retained from the current release are authenticated below,
  # after replacement has been resolved, instead of hashing runs that will be
  # discarded.
  current <- wlv_read_current_release_reference(
    plan$root,
    plan$channel,
    required = FALSE
  )
  prior_runs <- if (is.null(current)) list() else current$manifest$runs
  replaced <- vapply(prior_runs, function(record) {
    record$method %in% plan$method_names
  }, logical(1L))
  prior_runs <- prior_runs[!replaced]
  new_runs <- lapply(run_environments, function(environment) {
    manifest_path <- file.path(environment$wlv_run_dir, wlv_run_manifest_filename())
    wlv_build_release_run_reference(
      publication_root = paths$results,
      method = environment$wlv_run_manifest$method,
      manifest_path = wlv_publication_relative_path(manifest_path, paths$results),
      verified_run = environment$wlv_run_manifest
    )
  })
  runs <- c(prior_runs, new_runs)
  runs <- runs[order(vapply(runs, `[[`, character(1L), "method"), method = "radix")]

  previous_sequence <- if (is.null(current)) NULL else current$marker$sequence
  sequence <- wlv_publication_increment_sequence(previous_sequence)
  release_id <- wlv_new_publication_id("release")
  staging <- tempfile(
    pattern = paste0(".staging-", release_id, "-"),
    tmpdir = paths$staging
  )
  if (!dir.create(staging, recursive = FALSE, showWarnings = FALSE)) {
    stop("Could not create release staging directory.", call. = FALSE)
  }
  staging_open <- TRUE
  on.exit({
    if (staging_open && dir.exists(staging)) {
      unlink(staging, recursive = TRUE, force = TRUE)
    }
  }, add = TRUE)

  run_roots <- vapply(runs, function(record) {
    dirname(file.path(paths$results, record$manifest_path))
  }, character(1L))
  panel_artifacts <- c("_panel_indicators.csv", "_panel_meta_indicators.csv")
  panel_hashes <- vector("list", length(runs))
  for (index in seq_along(runs)) {
    reference <- runs[[index]]
    manifest_path <- wlv_publication_resolve_files(
      paths$results,
      reference$manifest_path,
      "release run manifest"
    )[[1L]]
    run_manifest <- wlv_read_run_manifest(
      manifest_path,
      expected_sha256 = reference$manifest_sha256
    )
    if (!identical(run_manifest$method, reference$method) ||
        !identical(run_manifest$run_id, reference$run_id) ||
        !identical(run_manifest$result_id, reference$result_id)) {
      stop(
        sprintf("Run reference identity mismatch for `%s`.", reference$manifest_path),
        call. = FALSE
      )
    }
    panel_records <- wlv_run_manifest_artifact_subset(
      run_manifest,
      panel_artifacts,
      label = "release panel-metadata artifact"
    )
    panel_hashes[[index]] <- vapply(
      panel_records,
      `[[`,
      character(1L),
      "sha256"
    )
  }
  indicator_paths <- file.path(run_roots, "_panel_indicators.csv")
  metadata_paths <- file.path(run_roots, "_panel_meta_indicators.csv")
  missing <- c(indicator_paths[!file.exists(indicator_paths)], metadata_paths[!file.exists(metadata_paths)])
  if (length(missing)) {
    stop(
      sprintf("Release runs lack panel metadata: %s.", paste(basename(missing), collapse = ", ")),
      call. = FALSE
    )
  }
  indicators <- wlv_merge_panel_result_tables(
    indicator_paths,
    key = "cod_label",
    columns = c("cod_label", "label"),
    expected_sha256 = vapply(panel_hashes, `[[`, character(1L), 1L)
  )
  metadata <- wlv_merge_panel_result_tables(
    metadata_paths,
    key = "value",
    columns = c("value", "groups", "type", "reverted"),
    expected_sha256 = vapply(panel_hashes, `[[`, character(1L), 2L)
  )
  wlv_write_result_csv(indicators, file.path(staging, "indicators_en.csv"))
  wlv_write_result_csv(metadata, file.path(staging, "meta_indicators.csv"))

  paper_result <- NULL
  if (isTRUE(plan$prepaper)) {
    # Papers execute against the staged immutable runs, so bind both sides of
    # that execution to the preflight inventories. Ordinary calculations do
    # no work at this boundary and are covered by the release and final checks
    # below without two redundant full-tree hash passes.
    wlv_assert_plan_publication_inputs_unchanged(plan, use_receipt = TRUE)
    paper_result <- wlv_run_staged_paper(plan, run_environments, staging)
    wlv_assert_plan_publication_inputs_unchanged(plan, use_receipt = TRUE)
    wlv_assert_run_environments_source_inputs_unchanged(
      plan,
      run_environments,
      use_receipt = TRUE
    )
  }
  release_artifacts <- c("indicators_en.csv", "meta_indicators.csv")
  release_roles <- c("panel_labels", "panel_metadata")
  if (!is.null(paper_result)) {
    release_artifacts <- c(release_artifacts, basename(paper_result$output))
    release_roles <- c(release_roles, "paper")
  }

  release <- wlv_build_release_manifest(
    release_root = staging,
    artifacts = release_artifacts,
    artifact_roles = release_roles,
    release_id = release_id,
    channel = plan$channel,
    sequence = sequence,
    runs = runs,
    metadata = list(methods = vapply(runs, `[[`, character(1L), "method"))
  )
  release_path <- file.path(staging, wlv_release_manifest_filename())
  wlv_write_release_manifest(release, release_path)
  # At this boundary the release artifacts and every run-reference manifest
  # must be exact. Run artifacts are verified once more from the installed
  # release below, immediately before the channel-marker commit point.
  wlv_verify_release_manifest(
    release,
    release_root = staging,
    publication_root = paths$results,
    reject_unlisted = TRUE,
    verify_runs = FALSE
  )
  wlv_assert_plan_publication_inputs_unchanged(plan, use_receipt = TRUE)
  wlv_assert_run_environments_source_inputs_unchanged(
    plan,
    run_environments,
    use_receipt = TRUE
  )
  final <- file.path(paths$releases, release_id)
  if (file.exists(final) || !file.rename(staging, final)) {
    stop(sprintf("Could not promote release `%s`.", release_id), call. = FALSE)
  }
  staging_open <- FALSE
  final <- normalizePath(final, winslash = "/", mustWork = TRUE)
  installed_release_path <- file.path(final, wlv_release_manifest_filename())
  installed_release <- wlv_read_release_manifest(installed_release_path)
  if (!wlv_publication_json_identical(installed_release, release)) {
    stop("Installed release manifest differs from its verified staging manifest.",
      call. = FALSE
    )
  }
  marker <- wlv_build_channel_marker(
    channel = plan$channel,
    sequence = sequence,
    release_id = release_id,
    release_manifest_path = wlv_publication_relative_path(
      installed_release_path,
      paths$results
    ),
    release_manifest_sha256 = wlv_publication_file_sha256(installed_release_path)
  )
  channel_dir <- wlv_publication_channel_directory(
    plan$root,
    plan$channel,
    create = TRUE
  )
  marker_filename <- wlv_channel_marker_filename(sequence, release_id)
  marker_path <- file.path(
    channel_dir,
    marker_filename
  )
  committed_marker_path <- normalizePath(
    marker_path,
    winslash = "/",
    mustWork = FALSE
  )
  wlv_validate_channel_marker_path(
    marker,
    paths$results,
    marker_path,
    must_exist = FALSE
  )
  marker_staging <- tempfile(pattern = ".marker-", tmpdir = paths$staging)
  if (!dir.create(marker_staging, recursive = FALSE, showWarnings = FALSE)) {
    stop("Could not create channel-marker staging.", call. = FALSE)
  }
  marker_staging_open <- TRUE
  on.exit({
    if (marker_staging_open && dir.exists(marker_staging)) {
      try(
        suppressWarnings(unlink(marker_staging, recursive = TRUE, force = TRUE)),
        silent = TRUE
      )
    }
  }, add = TRUE)
  pending_marker_path <- file.path(marker_staging, marker_filename)
  wlv_write_channel_marker(marker, pending_marker_path)
  wlv_assert_plan_publication_inputs_unchanged(plan, stabilize = TRUE)
  wlv_assert_run_environments_source_inputs_unchanged(plan, run_environments)
  # This is the final fallible release validation boundary. It re-reads the exact
  # manifest named and hashed by the marker, then verifies the installed
  # release and every referenced run after all injectable publication checks.
  wlv_verify_channel_marker(
    marker,
    paths$results,
    verify_release = TRUE
  )
  pending_marker <- wlv_read_channel_marker(pending_marker_path)
  if (!wlv_publication_json_identical(pending_marker, marker)) {
    stop("Pending channel marker changed after it was written.", call. = FALSE)
  }
  if (file.exists(marker_path) ||
      !file.rename(pending_marker_path, marker_path)) {
    stop("Could not atomically install channel marker.", call. = FALSE)
  }
  # The rename above is the commit point. Everything that can invalidate the
  # publication has already been verified; no fallible I/O follows it.
  list(
    marker = marker,
    marker_path = committed_marker_path,
    manifest = installed_release,
    manifest_path = installed_release_path,
    root = final
  )
}

wlv_with_publication_lock <- function(plan, execute) {
  if (!is.list(plan) || !is.function(execute)) {
    stop("A run plan and lock-scoped operation are required.", call. = FALSE)
  }
  results_root <- wlv_publication_ensure_store(plan$root)$results
  lock <- wlv_acquire_result_lock(
    results_root,
    paste(plan$method_names, collapse = ",")
  )
  lock_open <- TRUE
  on.exit({
    if (lock_open) {
      try(wlv_release_result_lock(lock, results_root), silent = TRUE)
    }
  }, add = TRUE)

  value <- execute()
  released <- tryCatch(
    {
      wlv_release_result_lock(lock, results_root)
      TRUE
    },
    error = function(error) {
      message(
        "Operation completed; result lock cleanup warning: ",
        conditionMessage(error)
      )
      FALSE
    }
  )
  if (released) lock_open <- FALSE
  value
}

wlv_execute_preparation_plan <- function(plan) {
  wlv_with_publication_lock(plan, function() {
    wlv_assert_plan_publication_inputs_unchanged(plan, use_receipt = TRUE)
    wlv_prepare_sources(plan)
    validated <- wlv_validate_data(plan)
    wlv_assert_plan_publication_inputs_unchanged(
      validated,
      stabilize = TRUE
    )
    validated
  })
}

wlv_execute_run_plan <- function(plan) {
  wlv_with_publication_lock(plan, function() {
    wlv_assert_plan_publication_inputs_unchanged(plan, use_receipt = TRUE)
    if (isTRUE(plan$repeat_pp)) {
      wlv_prepare_sources(plan)
    }

    plan <- wlv_validate_data(plan)
    wlv_assert_plan_publication_inputs_unchanged(plan, use_receipt = TRUE)
    run_environments <- wlv_with_cluster(plan$workers, function(cluster) {
      lapply(plan$method_names, function(method) {
        wlv_assert_plan_publication_inputs_unchanged(
          plan,
          method,
          use_receipt = TRUE
        )
        message(sprintf(
          "%s %s...",
          if (plan$mode == "recalculate") "Recalculating" else "Calculating",
          method
        ))
        wlv_run_method(plan, method, cluster = cluster)
      })
    })
    release <- wlv_commit_release(plan, run_environments)
    list(plan = plan, run_environments = run_environments, release = release)
  })
}
