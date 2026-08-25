# Deterministic runtime bootstrap ------------------------------------------
#
# This is the only runtime definition loader. Every reachable task is loaded
# into one private namespace whose parent is baseenv(); no package is attached
# and no definition is evaluated in .GlobalEnv.

wlv_runtime_definition_manifest <- function() {
  c(
    # Shared contracts and scientific services.
    "R/lib/dependencies.R",
    "R/lib/functions.R",
    "R/lib/catalog.R",
    "R/lib/missingness.R",
    "R/lib/unit_dimensions.R",
    "R/lib/aggregation_specs.R",
    "R/lib/indicator_metadata.R",
    "R/lib/gfcf_contracts.R",
    "R/lib/gfcf_diagnostics.R",
    "R/lib/leontief_diagnostics.R",
    "R/lib/wiodr16_allocation.R",
    "R/lib/wiodr13_validation.R",
    "R/lib/wiodr16_validation.R",
    "R/lib/scientific_validation.R",
    "R/lib/result_contracts.R",
    "R/lib/source_manifest.R",
    "R/lib/source_normalization.R",
    "R/lib/publication_manifest.R",
    "R/lib/publication.R",
    "R/lib/publication_retention.R",
    "R/lib/row_capital.R",

    # Explicit module runtime, configuration, and native module definitions.
    "R/lib/module_runtime.R",
    "R/lib/semantic_resources.R",
    "R/lib/module_config.R",
    "R/lib/native_aggregation_registry.R",
    "R/lib/native_output_contract.R",
    "R/modules/native/contracts.R",
    "R/modules/native/source_modules.R",
    "R/modules/native/matrix_modules.R",
    "R/modules/native/capital_matrix_modules.R",
    "R/modules/native/reduced_matrix_modules.R",
    "R/modules/native/indicator_helpers.R",
    "R/modules/native/indicator_common_modules.R",
    "R/modules/native/indicator_source_derived_modules.R",
    "R/modules/native/indicator_reduction_modules.R",
    "R/modules/native/indicator_stage4_collector.R",
    "R/modules/native/zz_indicator_registry.R",
    "R/modules/native/assumption_modules.R",
    "R/modules/native/aggregation_modules.R",
    "R/modules/native/assembler_modules.R",
    "R/lib/native_data.R",
    "R/lib/native_registry.R",
    "R/lib/native_planner.R",
    "R/lib/native_store.R",
    "R/lib/runtime_snapshot.R",

    # Native source-preparation tasks and their injected production services.
    "R/utils/preparation_downloads.R",
    "R/utils/wiodr16_preparation.R",
    "R/lib/preparation_tasks.R",
    "R/preparation/native_euklems.R",
    "R/preparation/native_wiodr13.R",
    "R/preparation/native_wiodr16.R",
    "R/preparation/registry.R",

    # Native paper tasks and static enforcement.
    "R/lib/paper_tasks.R",
    "R/utils/papers/paper_0_selection.R",
    "R/utils/papers/paper_3_selection.R",
    "R/utils/papers/paper_4_selection.R",
    "R/lib/runtime_static_analysis.R",

    # Orchestration and the public API are deliberately last.
    "R/lib/execution.R",
    "R/main.R"
  )
}

wlv_bootstrap_root <- function(root) {
  if (
    !base::is.character(root) || base::length(root) != 1L ||
      base::is.na(root) || !base::nzchar(root) || !base::dir.exists(root)
  ) {
    base::stop("`root` must be one existing project directory.", call. = FALSE)
  }
  base::normalizePath(root, winslash = "/", mustWork = TRUE)
}

wlv_bootstrap_is_within_root <- function(paths, root) {
  compare_paths <- paths
  compare_root <- root
  if (base::.Platform$OS.type == "windows") {
    compare_paths <- base::tolower(compare_paths)
    compare_root <- base::tolower(compare_root)
  }
  base::startsWith(compare_paths, base::paste0(compare_root, "/"))
}

wlv_runtime_definition_files <- function(root = ".") {
  root <- wlv_bootstrap_root(root)
  relative <- wlv_runtime_definition_manifest()
  if (
    !base::length(relative) || base::anyNA(relative) ||
      base::any(!base::nzchar(relative)) || base::anyDuplicated(relative) ||
      !base::identical(relative[[base::length(relative)]], "R/main.R") ||
      base::any(base::startsWith(relative, "/")) ||
      base::any(base::grepl("(^|/)\\.\\.(/|$)", relative))
  ) {
    base::stop("The runtime definition manifest is invalid.", call. = FALSE)
  }

  paths <- base::file.path(root, relative)
  missing <- relative[!base::file.exists(paths)]
  if (base::length(missing)) {
    base::stop(
      base::sprintf(
        "Runtime definition file(s) do not exist: %s.",
        base::paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  directories <- relative[base::file.info(paths)$isdir %in% TRUE]
  if (base::length(directories)) {
    base::stop(
      base::sprintf(
        "Runtime definition path(s) are not files: %s.",
        base::paste(directories, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  paths <- base::normalizePath(paths, winslash = "/", mustWork = TRUE)
  escaped <- relative[!wlv_bootstrap_is_within_root(paths, root)]
  if (base::length(escaped)) {
    base::stop(
      base::sprintf(
        "Runtime definition file(s) escape the project root: %s.",
        base::paste(escaped, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  base::unname(paths)
}

wlv_bootstrap_validate_api <- function(namespace) {
  expected <- list(
    prepare_wlv = c("methods", "allow_experimental"),
    get_wlv = c(
      "methods", "repeat_pp", "papern", "prepaper", "workers", "channel",
      "allow_experimental"
    ),
    recalc_wlv = c(
      "methods", "at_stage", "sea_vars", "papern", "prepaper", "workers",
      "channel", "allow_experimental"
    )
  )
  for (name in base::names(expected)) {
    if (!base::exists(name, envir = namespace, mode = "function", inherits = FALSE)) {
      base::stop(
        base::sprintf("Runtime did not define the public function `%s`.", name),
        call. = FALSE
      )
    }
    value <- base::get(name, envir = namespace, inherits = FALSE)
    if (!base::identical(base::names(base::formals(value)), expected[[name]])) {
      base::stop(
        base::sprintf("Public function `%s` has an incompatible signature.", name),
        call. = FALSE
      )
    }
    if (!base::identical(base::environment(value), namespace)) {
      base::stop(
        base::sprintf("Public function `%s` escaped the runtime namespace.", name),
        call. = FALSE
      )
    }
  }
  base::invisible(namespace)
}

wlv_bootstrap_validate_definitions <- function(expressions, relative_path) {
  definitions <- base::vapply(expressions, function(expression) {
    base::is.call(expression) && base::length(expression) == 3L &&
      base::is.symbol(expression[[1L]]) &&
      base::identical(base::as.character(expression[[1L]]), "<-") &&
      base::is.symbol(expression[[2L]]) &&
      base::is.call(expression[[3L]]) &&
      base::length(expression[[3L]]) >= 3L &&
      base::is.symbol(expression[[3L]][[1L]]) &&
      base::identical(base::as.character(expression[[3L]][[1L]]), "function")
  }, logical(1L))
  if (base::length(definitions) && !base::all(definitions)) {
    base::stop(
      base::sprintf(
        "Runtime file `%s` contains top-level execution instead of definitions.",
        relative_path
      ),
      call. = FALSE
    )
  }
  base::invisible(expressions)
}

wlv_bootstrap_value_accessor <- function(value) {
  base::force(value)
  holder <- base::new.env(parent = base::baseenv())
  base::assign(".value", value, envir = holder)
  accessor <- function() {
    value <- base::get(".value", inherits = TRUE)
    if (base::is.list(value)) {
      return(base::unserialize(base::serialize(value, NULL, version = 3L)))
    }
    value
  }
  base::environment(accessor) <- holder
  base::lockBinding(".value", holder)
  base::lockEnvironment(holder, bindings = TRUE)
  accessor
}

wlv_bootstrap_definition_names <- function(expressions) {
  names <- base::vapply(expressions, function(expression) {
    left <- expression[[2L]]
    if (base::is.symbol(left)) base::as.character(left) else ""
  }, character(1L))
  names[base::nzchar(names)]
}

wlv_bootstrap_definition_inventory <- function(paths, relative_paths) {
  if (
    !base::is.character(paths) || !base::is.character(relative_paths) ||
      !base::length(paths) || !base::identical(base::length(paths), base::length(relative_paths)) ||
      base::anyNA(paths) || base::anyNA(relative_paths) ||
      base::any(!base::file.exists(paths)) || base::anyDuplicated(relative_paths)
  ) {
    base::stop("Runtime definition inventory received invalid files.", call. = FALSE)
  }
  hashes <- base::unname(tools::md5sum(paths))
  if (base::anyNA(hashes) || base::any(!base::nzchar(hashes))) {
    base::stop("Could not hash every runtime definition file.", call. = FALSE)
  }
  stats::setNames(hashes, relative_paths)
}

wlv_bootstrap_sha256_file <- function(path) {
  connection <- base::file(path, open = "rb")
  on.exit(base::close(connection), add = TRUE)
  base::as.character(openssl::sha256(connection))
}

wlv_bootstrap_definition_sha256 <- function(paths, relative_paths) {
  if (
    !base::is.character(paths) || !base::is.character(relative_paths) ||
      !base::length(paths) || !base::identical(base::length(paths), base::length(relative_paths)) ||
      base::anyNA(paths) || base::anyNA(relative_paths) ||
      base::any(!base::file.exists(paths)) || base::anyDuplicated(relative_paths)
  ) {
    base::stop("Runtime SHA-256 inventory received invalid files.", call. = FALSE)
  }
  hashes <- base::vapply(paths, wlv_bootstrap_sha256_file, character(1L))
  if (base::anyNA(hashes) || base::any(!base::grepl("^[0-9a-f]{64}$", hashes))) {
    base::stop("Could not SHA-256 hash every runtime definition file.", call. = FALSE)
  }
  stats::setNames(base::unname(hashes), relative_paths)
}

wlv_bootstrap_read_definition_bytes <- function(path, relative_path) {
  size <- base::file.info(path)$size
  if (
    base::length(size) != 1L || base::is.na(size) || size < 1 ||
      size >= base::.Machine$integer.max
  ) {
    base::stop(
      base::sprintf("Runtime definition `%s` has an invalid size.", relative_path),
      call. = FALSE
    )
  }
  connection <- base::file(path, open = "rb")
  on.exit(base::close(connection), add = TRUE)
  value <- base::readBin(
    connection,
    what = "raw",
    n = base::as.integer(size) + 1L
  )
  if (!base::identical(base::length(value), base::as.integer(size))) {
    base::stop(
      base::sprintf(
        "Runtime definition `%s` changed while its bytes were captured.",
        relative_path
      ),
      call. = FALSE
    )
  }
  value
}

wlv_bootstrap_capture_definitions <- function(paths, relative_paths) {
  if (
    !base::is.character(paths) || !base::is.character(relative_paths) ||
      !base::length(paths) ||
      !base::identical(base::length(paths), base::length(relative_paths)) ||
      base::anyNA(paths) || base::anyNA(relative_paths) ||
      base::any(!base::file.exists(paths)) || base::anyDuplicated(relative_paths)
  ) {
    base::stop("Runtime byte capture received invalid files.", call. = FALSE)
  }
  bytes <- base::Map(
    wlv_bootstrap_read_definition_bytes,
    paths,
    relative_paths
  )
  md5 <- base::vapply(bytes, function(value) {
    base::as.character(openssl::md5(value))
  }, character(1L))
  sha256 <- base::vapply(bytes, function(value) {
    base::as.character(openssl::sha256(value))
  }, character(1L))
  list(
    bytes = stats::setNames(bytes, relative_paths),
    md5 = stats::setNames(base::unname(md5), relative_paths),
    sha256 = stats::setNames(base::unname(sha256), relative_paths)
  )
}

wlv_bootstrap_definition_text <- function(bytes, relative_path) {
  if (!base::is.raw(bytes) || !base::length(bytes)) {
    base::stop(
      base::sprintf("Runtime definition `%s` has no captured bytes.", relative_path),
      call. = FALSE
    )
  }
  value <- base::rawToChar(bytes)
  value <- base::`Encoding<-`(value, "UTF-8")
  validated <- base::iconv(
    value,
    from = "UTF-8",
    to = "UTF-8",
    sub = NA_character_
  )
  if (base::length(validated) != 1L || base::is.na(validated)) {
    base::stop(
      base::sprintf("Runtime definition `%s` is not valid UTF-8.", relative_path),
      call. = FALSE
    )
  }
  # `parse(text = ...)` does not consistently treat an embedded CR from a
  # CRLF string as a line terminator on Windows. Keep the captured raw hashes
  # unchanged, but evaluate the UTF-8 source with canonical LF terminators.
  base::gsub("\r\n?", "\n", validated, perl = TRUE)
}

wlv_bootstrap_compatibility_sha256_bytes <- function(bytes, relative_path) {
  value <- wlv_bootstrap_definition_text(bytes, relative_path)
  base::as.character(openssl::sha256(base::charToRaw(base::enc2utf8(value))))
}

wlv_bootstrap_function_fingerprint <- function(formals, body) {
  payload <- base::paste(
    base::paste(base::deparse(formals, width.cutoff = 500L), collapse = "\n"),
    base::paste(base::deparse(body, width.cutoff = 500L), collapse = "\n"),
    sep = "\035"
  )
  base::as.character(openssl::sha256(base::charToRaw(base::enc2utf8(payload))))
}

wlv_bootstrap_validate_loaded_identity <- function(bytes, relative_path) {
  expressions <- base::tryCatch(
    base::parse(
      text = wlv_bootstrap_definition_text(bytes, relative_path),
      encoding = "UTF-8",
      keep.source = FALSE
    ),
    error = function(error) {
      base::stop(
        base::sprintf(
          "Cannot parse bootstrap identity `%s`: %s",
          relative_path,
          base::conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  wlv_bootstrap_validate_definitions(expressions, relative_path)
  expected_names <- wlv_bootstrap_definition_names(expressions)
  loaded_environment <- base::environment(wlv_load_runtime)
  loaded_names <- base::ls(loaded_environment, all.names = TRUE)
  if (!base::identical(
    base::sort(expected_names, method = "radix"),
    base::sort(loaded_names, method = "radix")
  )) {
    base::stop(
      "The executed bootstrap definitions differ from the selected project root.",
      call. = FALSE
    )
  }
  expected <- stats::setNames(base::vapply(expressions, function(expression) {
    definition <- expression[[3L]]
    wlv_bootstrap_function_fingerprint(definition[[2L]], definition[[3L]])
  }, character(1L)), expected_names)
  observed <- stats::setNames(base::vapply(expected_names, function(name) {
    value <- base::get(name, envir = loaded_environment, inherits = FALSE)
    if (!base::is.function(value) ||
        !base::identical(base::environment(value), loaded_environment)) {
      return(NA_character_)
    }
    wlv_bootstrap_function_fingerprint(
      base::formals(value),
      base::body(value)
    )
  }, character(1L)), expected_names)
  if (base::anyNA(observed) || !base::identical(expected, observed)) {
    base::stop(
      "The executed bootstrap is not structurally identical to the selected project root.",
      call. = FALSE
    )
  }
  base::invisible(observed)
}

wlv_bootstrap_definition_generation <- function(sha256) {
  if (
    !base::is.character(sha256) || !base::length(sha256) ||
      base::is.null(base::names(sha256)) || base::anyNA(sha256) ||
      base::any(!base::nzchar(base::names(sha256))) ||
      base::anyDuplicated(base::names(sha256)) ||
      base::any(!base::grepl("^[0-9a-f]{64}$", sha256))
  ) {
    base::stop("Runtime generation received an invalid SHA-256 inventory.", call. = FALSE)
  }
  payload <- base::paste(
    base::c(
      "wlv-runtime-definitions/1",
      base::paste(base::names(sha256), sha256, sep = "\034")
    ),
    collapse = "\035"
  )
  base::as.character(openssl::sha256(base::charToRaw(base::enc2utf8(payload))))
}

wlv_load_runtime <- function(root = ".") {
  root <- wlv_bootstrap_root(root)
  files <- wlv_runtime_definition_files(root)
  relative <- wlv_runtime_definition_manifest()
  bootstrap_file <- base::normalizePath(
    base::file.path(root, "R", "bootstrap.R"),
    winslash = "/",
    mustWork = TRUE
  )
  inventory_paths <- base::c(bootstrap_file, files)
  inventory_relative <- base::c("R/bootstrap.R", relative)
  captured <- wlv_bootstrap_capture_definitions(
    inventory_paths,
    inventory_relative
  )
  wlv_bootstrap_validate_loaded_identity(
    captured$bytes[["R/bootstrap.R"]],
    "R/bootstrap.R"
  )
  inventory <- captured$md5
  inventory_sha256 <- captured$sha256
  inventory_generation <- wlv_bootstrap_definition_generation(inventory_sha256)
  compatibility_sha256 <- stats::setNames(base::vapply(
    base::seq_along(inventory_relative),
    function(index) {
      wlv_bootstrap_compatibility_sha256_bytes(
        captured$bytes[[index]],
        inventory_relative[[index]]
      )
    },
    character(1L)
  ), inventory_relative)
  compatibility_generation <- wlv_bootstrap_definition_generation(
    compatibility_sha256
  )
  if (!base::identical(
    inventory,
    wlv_bootstrap_definition_inventory(inventory_paths, inventory_relative)
  ) || !base::identical(
    inventory_sha256,
    wlv_bootstrap_definition_sha256(inventory_paths, inventory_relative)
  ) || !base::identical(
    inventory_generation,
    wlv_bootstrap_definition_generation(inventory_sha256)
  )) {
    base::stop(
      "Runtime definitions changed while their bootstrap inventory was captured.",
      call. = FALSE
    )
  }

  # Parse every definition before evaluating any of them. A syntax or encoding
  # failure therefore cannot expose a partially initialized namespace.
  definition_origins <- character()
  parsed_definitions <- vector("list", length(files))
  for (index in base::seq_along(files)) {
    expressions <- base::tryCatch(
      base::parse(
        text = wlv_bootstrap_definition_text(
          captured$bytes[[relative[[index]]]],
          relative[[index]]
        ),
        encoding = "UTF-8",
        keep.source = FALSE
      ),
      error = function(error) {
        base::stop(
          base::sprintf(
            "Cannot parse runtime definition `%s`: %s",
            relative[[index]],
            base::conditionMessage(error)
          ),
          call. = FALSE
        )
      }
    )
    wlv_bootstrap_validate_definitions(expressions, relative[[index]])
    names <- wlv_bootstrap_definition_names(expressions)
    repeated <- base::unique(names[
      base::duplicated(names) | names %in% base::names(definition_origins)
    ])
    if (base::length(repeated)) {
      base::stop(
        base::sprintf(
          "Runtime definition(s) are shadowed by `%s`: %s.",
          relative[[index]],
          base::paste(repeated, collapse = ", ")
        ),
        call. = FALSE
      )
    }
    definition_origins[names] <- relative[[index]]
    parsed_definitions[[index]] <- expressions
  }

  namespace <- base::new.env(parent = base::baseenv())
  base::assign(
    ".wlv_runtime_root",
    wlv_bootstrap_value_accessor(root),
    envir = namespace
  )
  base::assign(
    ".wlv_runtime_files",
    wlv_bootstrap_value_accessor(files),
    envir = namespace
  )
  working_directory <- base::getwd()
  search_path <- base::search()

  for (index in base::seq_along(files)) {
    base::tryCatch(
      base::eval(parsed_definitions[[index]], envir = namespace),
      error = function(error) {
        base::stop(
          base::sprintf(
            "Cannot load runtime definition `%s`: %s",
            relative[[index]],
            base::conditionMessage(error)
          ),
          call. = FALSE
        )
      }
    )
  }

  if (!base::identical(base::getwd(), working_directory)) {
    base::stop("A runtime definition changed the working directory.", call. = FALSE)
  }
  if (!base::identical(base::search(), search_path)) {
    base::stop("A runtime definition changed the package search path.", call. = FALSE)
  }
  if (!base::identical(base::parent.env(namespace), base::baseenv())) {
    base::stop("The runtime namespace has an invalid parent.", call. = FALSE)
  }
  current_inventory <- wlv_bootstrap_definition_inventory(
    inventory_paths,
    inventory_relative
  )
  current_sha256 <- wlv_bootstrap_definition_sha256(
    inventory_paths,
    inventory_relative
  )
  if (!base::identical(inventory, current_inventory) ||
      !base::identical(inventory_sha256, current_sha256) ||
      !base::identical(
        inventory_generation,
        wlv_bootstrap_definition_generation(current_sha256)
      ) ||
      !base::identical(
        current_inventory,
        wlv_bootstrap_definition_inventory(inventory_paths, inventory_relative)
      ) ||
      !base::identical(
        current_sha256,
        wlv_bootstrap_definition_sha256(inventory_paths, inventory_relative)
      )) {
    base::stop(
      "Runtime definitions changed while the private namespace was loading.",
      call. = FALSE
    )
  }
  base::assign(
    ".wlv_runtime_definition_paths",
    wlv_bootstrap_value_accessor(
      stats::setNames(inventory_paths, inventory_relative)
    ),
    envir = namespace
  )
  base::assign(
    ".wlv_runtime_definition_md5",
    wlv_bootstrap_value_accessor(inventory),
    envir = namespace
  )
  base::assign(
    ".wlv_runtime_definition_sha256",
    wlv_bootstrap_value_accessor(inventory_sha256),
    envir = namespace
  )
  base::assign(
    ".wlv_runtime_definition_compatibility_sha256",
    wlv_bootstrap_value_accessor(compatibility_sha256),
    envir = namespace
  )
  base::assign(
    ".wlv_runtime_generation",
    wlv_bootstrap_value_accessor(inventory_generation),
    envir = namespace
  )
  base::assign(
    ".wlv_runtime_compatibility_generation",
    wlv_bootstrap_value_accessor(compatibility_generation),
    envir = namespace
  )
  bindings <- base::ls(namespace, all.names = TRUE)
  non_functions <- bindings[!base::vapply(
    bindings,
    function(name) base::is.function(base::get(name, envir = namespace, inherits = FALSE)),
    logical(1L)
  )]
  if (base::length(non_functions)) {
    base::stop(
      base::sprintf(
        "Runtime definitions created non-function binding(s): %s.",
        base::paste(non_functions, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  sealed_accessors <- base::c(
    ".wlv_runtime_root",
    ".wlv_runtime_files",
    ".wlv_runtime_definition_paths",
    ".wlv_runtime_definition_md5",
    ".wlv_runtime_definition_sha256",
    ".wlv_runtime_definition_compatibility_sha256",
    ".wlv_runtime_generation",
    ".wlv_runtime_compatibility_generation"
  )
  escaped <- base::setdiff(bindings, sealed_accessors)
  escaped <- escaped[!base::vapply(
    escaped,
    function(name) base::identical(
      base::environment(base::get(name, envir = namespace, inherits = FALSE)),
      namespace
    ),
    logical(1L)
  )]
  if (base::length(escaped)) {
    base::stop(
      base::sprintf(
        "Runtime function(s) escaped the private namespace: %s.",
        base::paste(escaped, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  invalid_accessors <- sealed_accessors[!base::vapply(
    sealed_accessors,
    function(name) {
      value <- base::get(name, envir = namespace, inherits = FALSE)
      holder <- base::environment(value)
      base::identical(base::parent.env(holder), base::baseenv()) &&
        base::environmentIsLocked(holder) &&
        base::exists(".value", envir = holder, inherits = FALSE) &&
        base::bindingIsLocked(".value", holder) &&
        !base::length(base::formals(value))
    },
    logical(1L)
  )]
  if (base::length(invalid_accessors)) {
    base::stop(
      base::sprintf(
        "Runtime metadata accessor(s) are not sealed: %s.",
        base::paste(invalid_accessors, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  active <- bindings[base::vapply(
    bindings,
    base::bindingIsActive,
    logical(1L),
    env = namespace
  )]
  if (base::length(active)) {
    base::stop(
      base::sprintf(
        "Runtime definitions created active binding(s): %s.",
        base::paste(active, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  wlv_bootstrap_validate_api(namespace)
  base::lockEnvironment(namespace, bindings = TRUE)
  namespace
}
