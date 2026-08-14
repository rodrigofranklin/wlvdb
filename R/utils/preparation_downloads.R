wlv_file_hash <- function(path, algorithm = c("sha256", "sha1")) {
  algorithm <- match.arg(tolower(algorithm), c("sha256", "sha1"))
  if (!requireNamespace("openssl", quietly = TRUE)) {
    stop(
      "Package `openssl` is required to verify source-data downloads.",
      call. = FALSE
    )
  }

  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  hash_function <- getExportedValue("openssl", algorithm)
  paste0(tolower(as.character(hash_function(connection))), collapse = "")
}

wlv_verify_download <- function(
    path,
    expected_size,
    expected_hash,
    hash_algorithm = c("sha256", "sha1"),
    validator = NULL) {
  hash_algorithm <- match.arg(tolower(hash_algorithm), c("sha256", "sha1"))
  if (!file.exists(path) || isTRUE(file.info(path)$isdir)) {
    stop(sprintf("Downloaded file does not exist: %s", path), call. = FALSE)
  }
  if (
    length(expected_size) != 1L ||
    !is.numeric(expected_size) ||
    is.na(expected_size) ||
    expected_size < 0 ||
    expected_size != floor(expected_size)
  ) {
    stop("`expected_size` must be one non-negative integer.", call. = FALSE)
  }
  if (
    !is.character(expected_hash) ||
    length(expected_hash) != 1L ||
    is.na(expected_hash) ||
    !grepl("^[0-9A-Fa-f]+$", expected_hash) ||
    nchar(expected_hash) != if (hash_algorithm == "sha256") 64L else 40L
  ) {
    stop(
      sprintf("`expected_hash` must be one valid %s hexadecimal string.", toupper(hash_algorithm)),
      call. = FALSE
    )
  }
  if (!is.null(validator) && !is.function(validator)) {
    stop("`validator` must be NULL or a function.", call. = FALSE)
  }

  actual_size <- unname(file.info(path)$size)
  if (is.na(actual_size) || actual_size != expected_size) {
    stop(
      sprintf(
        "Size mismatch for `%s`: expected %s bytes, found %s.",
        basename(path),
        format(expected_size, scientific = FALSE),
        format(actual_size, scientific = FALSE)
      ),
      call. = FALSE
    )
  }

  actual_hash <- wlv_file_hash(path, hash_algorithm)
  if (!identical(actual_hash, tolower(expected_hash))) {
    stop(
      sprintf(
        "%s mismatch for `%s`: expected %s, found %s.",
        toupper(hash_algorithm), basename(path), tolower(expected_hash), actual_hash
      ),
      call. = FALSE
    )
  }

  if (!is.null(validator)) {
    validation_result <- validator(path)
    if (identical(validation_result, FALSE)) {
      stop(sprintf("Structural validation failed for `%s`.", basename(path)), call. = FALSE)
    }
  }

  invisible(path)
}

wlv_install_files <- function(source_paths, destinations) {
  if (
    !is.character(source_paths) ||
    !is.character(destinations) ||
    !length(source_paths) ||
    length(source_paths) != length(destinations) ||
    anyNA(source_paths) ||
    anyNA(destinations) ||
    any(!nzchar(source_paths)) ||
    any(!nzchar(destinations)) ||
    anyDuplicated(destinations)
  ) {
    stop("Source and destination paths must be unique, non-empty vectors of equal length.", call. = FALSE)
  }
  missing_sources <- source_paths[!file.exists(source_paths)]
  if (length(missing_sources)) {
    stop(
      sprintf("Files to install do not exist: %s", paste(missing_sources, collapse = ", ")),
      call. = FALSE
    )
  }
  destination_directories <- dirname(destinations)
  missing_directories <- unique(destination_directories[!dir.exists(destination_directories)])
  if (length(missing_directories)) {
    stop(
      sprintf(
        "Destination directories do not exist: %s",
        paste(missing_directories, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  source_directories <- normalizePath(dirname(source_paths), mustWork = TRUE)
  normalized_destination_directories <- normalizePath(
    destination_directories,
    mustWork = TRUE
  )
  if (any(source_directories != normalized_destination_directories)) {
    stop(
      "Each staged file must be in its destination directory for an atomic rename.",
      call. = FALSE
    )
  }

  backups <- vapply(
    seq_along(destinations),
    function(index) {
      tempfile(
        pattern = paste0(".", basename(destinations[[index]]), "-backup-"),
        tmpdir = destination_directories[[index]]
      )
    },
    character(1)
  )
  moved_previous <- rep(FALSE, length(destinations))
  installed <- rep(FALSE, length(destinations))
  transaction_complete <- FALSE

  on.exit({
    if (!transaction_complete) {
      for (index in which(installed)) {
        if (file.exists(destinations[[index]])) {
          unlink(destinations[[index]], force = TRUE)
        }
      }
      for (index in which(moved_previous)) {
        if (file.exists(backups[[index]]) && !file.exists(destinations[[index]])) {
          file.rename(backups[[index]], destinations[[index]])
        }
      }
    }
  }, add = TRUE)

  for (index in seq_along(destinations)) {
    if (file.exists(destinations[[index]])) {
      if (!file.rename(destinations[[index]], backups[[index]])) {
        stop(
          sprintf("Cannot move the previous file aside: %s", destinations[[index]]),
          call. = FALSE
        )
      }
      moved_previous[[index]] <- TRUE
    }
  }

  for (index in seq_along(destinations)) {
    if (!file.rename(source_paths[[index]], destinations[[index]])) {
      stop(
        sprintf("Cannot install verified file at: %s", destinations[[index]]),
        call. = FALSE
      )
    }
    installed[[index]] <- TRUE
  }
  transaction_complete <- TRUE

  existing_backups <- backups[file.exists(backups)]
  if (length(existing_backups)) {
    cleanup_status <- unlink(existing_backups, force = TRUE)
    if (cleanup_status != 0L) {
      message(
        sprintf("Could not remove replaced-file backup(s): %s", paste(existing_backups, collapse = ", "))
      )
    }
  }

  invisible(destinations)
}

wlv_install_download <- function(download_path, destination) {
  wlv_install_files(download_path, destination)
  invisible(destination)
}

wlv_write_fst_atomic <- function(value, destination, writer) {
  if (!is.function(writer)) {
    stop("`writer` must be a function.", call. = FALSE)
  }
  destination_directory <- dirname(destination)
  if (!dir.exists(destination_directory)) {
    stop(sprintf("FST destination directory does not exist: %s", destination_directory), call. = FALSE)
  }
  temporary <- tempfile(
    pattern = paste0(".", basename(destination), "-write-"),
    tmpdir = destination_directory,
    fileext = ".fst"
  )
  on.exit({
    if (file.exists(temporary)) {
      unlink(temporary, force = TRUE)
    }
  }, add = TRUE)

  writer(value, temporary)
  if (!file.exists(temporary) || is.na(file.info(temporary)$size) || file.info(temporary)$size <= 0) {
    stop(sprintf("FST writer did not produce a non-empty file for: %s", destination), call. = FALSE)
  }
  wlv_install_files(temporary, destination)
  invisible(destination)
}

wlv_write_fst_array_atomic <- function(value, destination, writer) {
  if (!is.function(writer)) {
    stop("`writer` must be a function.", call. = FALSE)
  }
  destination_directory <- dirname(destination)
  if (!dir.exists(destination_directory)) {
    stop(sprintf("FST destination directory does not exist: %s", destination_directory), call. = FALSE)
  }
  temporary <- tempfile(
    pattern = paste0(".", basename(destination), "-write-"),
    tmpdir = destination_directory,
    fileext = ".fst"
  )
  temporary_paths <- c(temporary, paste0(temporary, ".meta"))
  destination_paths <- c(destination, paste0(destination, ".meta"))
  on.exit({
    remaining <- temporary_paths[file.exists(temporary_paths)]
    if (length(remaining)) {
      unlink(remaining, force = TRUE)
    }
  }, add = TRUE)

  writer(value, temporary)
  missing <- temporary_paths[!file.exists(temporary_paths)]
  if (length(missing)) {
    stop(
      sprintf("Array writer did not produce: %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  sizes <- file.info(temporary_paths)$size
  if (anyNA(sizes) || any(sizes <= 0)) {
    stop(sprintf("Array writer produced an empty file for: %s", destination), call. = FALSE)
  }
  tryCatch(
    readRDS(temporary_paths[[2]]),
    error = function(error) {
      stop(
        sprintf("Array writer produced invalid metadata for `%s`: %s", destination, conditionMessage(error)),
        call. = FALSE
      )
    }
  )
  wlv_install_files(temporary_paths, destination_paths)
  invisible(destination)
}

wlv_download_verified <- function(
    url,
    destination,
    expected_size,
    expected_hash,
    hash_algorithm = c("sha256", "sha1"),
    validator = NULL,
    timeout = 3600,
    downloader = utils::download.file) {
  hash_algorithm <- match.arg(tolower(hash_algorithm), c("sha256", "sha1"))
  if (!is.character(url) || length(url) != 1L || is.na(url) || !nzchar(url)) {
    stop("`url` must be one non-empty string.", call. = FALSE)
  }
  if (
    !is.character(destination) ||
    length(destination) != 1L ||
    is.na(destination) ||
    !nzchar(destination)
  ) {
    stop("`destination` must be one non-empty path.", call. = FALSE)
  }
  if (!is.function(downloader)) {
    stop("`downloader` must be a function.", call. = FALSE)
  }
  if (
    length(timeout) != 1L ||
    !is.numeric(timeout) ||
    is.na(timeout) ||
    !is.finite(timeout) ||
    timeout <= 0
  ) {
    stop("`timeout` must be one positive finite number.", call. = FALSE)
  }

  destination_directory <- dirname(destination)
  if (!dir.exists(destination_directory)) {
    stop(
      sprintf("Download destination directory does not exist: %s", destination_directory),
      call. = FALSE
    )
  }

  verify <- function(path) {
    wlv_verify_download(
      path = path,
      expected_size = expected_size,
      expected_hash = expected_hash,
      hash_algorithm = hash_algorithm,
      validator = validator
    )
  }

  if (file.exists(destination)) {
    existing_error <- tryCatch(
      {
        verify(destination)
        NULL
      },
      error = identity
    )
    if (is.null(existing_error)) {
      message(sprintf("Using verified download: %s", destination))
      return(invisible(destination))
    }
    message(
      sprintf(
        "Replacing invalid cached download `%s`: %s",
        destination,
        conditionMessage(existing_error)
      )
    )
  }

  destination_extension <- tools::file_ext(destination)
  temporary_extension <- if (nzchar(destination_extension)) {
    paste0(".", destination_extension)
  } else {
    ".download"
  }
  download_path <- tempfile(
    pattern = paste0(".", basename(destination), "-download-"),
    tmpdir = destination_directory,
    fileext = temporary_extension
  )
  on.exit({
    if (file.exists(download_path)) {
      unlink(download_path, force = TRUE)
    }
  }, add = TRUE)

  previous_timeout <- getOption("timeout")
  options(timeout = max(timeout, previous_timeout))
  on.exit(options(timeout = previous_timeout), add = TRUE)

  status <- downloader(
    url = url,
    destfile = download_path,
    mode = "wb",
    quiet = TRUE
  )
  if (length(status) && (!is.numeric(status) || anyNA(status) || any(status != 0))) {
    stop(sprintf("Download failed with status %s: %s", paste(status, collapse = ", "), url), call. = FALSE)
  }

  verify(download_path)
  wlv_install_download(download_path, destination)
  message(sprintf("Installed verified download: %s", destination))
  invisible(destination)
}

wlv_validate_zip_members <- function(path, required_members) {
  listing <- utils::unzip(path, list = TRUE)
  missing <- setdiff(required_members, listing$Name)
  if (length(missing)) {
    stop(
      sprintf("ZIP archive lacks required members: %s", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  required_sizes <- listing$Length[match(required_members, listing$Name)]
  if (anyNA(required_sizes) || any(required_sizes <= 0)) {
    stop("One or more required ZIP members are empty.", call. = FALSE)
  }
  invisible(TRUE)
}
