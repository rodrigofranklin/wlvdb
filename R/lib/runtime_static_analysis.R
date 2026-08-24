wlv_runtime_static_allowlist <- function() {
  c(
    "R/bootstrap.R",
    "scripts/bootstrap.R",
    "scripts/benchmark_leontief.R",
    "scripts/render_method_catalog.R",
    "scripts/run_wlv.R"
  )
}

wlv_runtime_static_relative_path <- function(path, root) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  compare_path <- path
  compare_root <- root
  if (.Platform$OS.type == "windows") {
    compare_path <- tolower(compare_path)
    compare_root <- tolower(compare_root)
  }
  prefix <- paste0(compare_root, "/")
  if (!startsWith(compare_path, prefix)) {
    stop(sprintf("Runtime file is outside project root: %s.", path), call. = FALSE)
  }
  substring(path, nchar(root, type = "chars") + 2L)
}

wlv_runtime_static_files <- function(root = ".") {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  definition_files <- get0(
    ".wlv_runtime_files",
    inherits = TRUE,
    ifnotfound = NULL
  )
  if (is.null(definition_files) || !is.character(definition_files) ||
      !length(definition_files) || anyNA(definition_files)) {
    stop(
      "Reachable static analysis requires the deterministic runtime bootstrap.",
      call. = FALSE
    )
  }
  files <- c(
    file.path(root, "R", "bootstrap.R"),
    definition_files,
    list.files(
      file.path(root, "scripts"),
      pattern = "[.]R$",
      recursive = FALSE,
      full.names = TRUE
    )
  )
  sort(unique(normalizePath(files, winslash = "/", mustWork = TRUE)))
}

wlv_runtime_static_is_allowed <- function(relative_path, allowlist) {
  relative_path <- gsub("\\\\", "/", relative_path)
  allowlist <- gsub("\\\\", "/", allowlist)
  relative_path %in% allowlist ||
    startsWith(relative_path, "tests/") ||
    startsWith(relative_path, "renv/")
}

wlv_runtime_static_allowed_rules <- function(relative_path, allowlist) {
  relative_path <- gsub("\\\\", "/", relative_path)
  allowlist <- gsub("\\\\", "/", allowlist)
  if (
    startsWith(relative_path, "tests/") ||
      startsWith(relative_path, "renv/")
  ) {
    return(c(
      "dynamic_source", "working_directory", "global_environment",
      "indirect_runtime_escape"
    ))
  }
  if (relative_path %in% allowlist) {
    # Bootstraps and launchers may load definitions and renv. They are not
    # exempt from the bans on working-directory or global-state mutation.
    return("dynamic_source")
  }
  character()
}

wlv_runtime_static_validate_allowlist <- function(allowlist) {
  allowlist <- gsub("\\\\", "/", allowlist)
  approved <- wlv_runtime_static_allowlist()
  invalid <- allowlist[
    !allowlist %in% approved &
      !startsWith(allowlist, "tests/") &
      !startsWith(allowlist, "renv/")
  ]
  if (length(invalid)) {
    stop(
      sprintf(
        "Runtime static allowlist is restricted to bootstrap, launchers, renv, and tests; invalid: %s.",
        paste(invalid, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  allowlist
}

wlv_runtime_static_call_name <- function(head) {
  if (is.symbol(head)) {
    return(as.character(head))
  }
  if (
    is.call(head) && length(head) == 3L && is.symbol(head[[1L]]) &&
    as.character(head[[1L]]) %in% c("::", ":::")
  ) {
    target <- head[[3L]]
    if (is.symbol(target) || is.character(target)) {
      return(as.character(target))
    }
  }
  ""
}

wlv_runtime_static_indirect_target <- function(call) {
  if (length(call) < 2L) {
    return("")
  }
  target <- call[[2L]]
  if (is.character(target) && length(target) == 1L) {
    return(target)
  }
  if (is.symbol(target)) {
    return(as.character(target))
  }
  ""
}

wlv_runtime_static_scientific_io <- function() {
  c(
    "file.path", "normalizePath", "path.expand", "getwd", "Sys.getenv",
    "Sys.glob", "file.exists", "file.info", "dir.exists", "dir.create",
    "list.files", "list.dirs", "readRDS", "saveRDS", "readLines",
    "writeLines", "readBin", "writeBin", "scan", "read.csv",
    "read.csv2", "read.table", "write.csv", "write.csv2", "write.table",
    "load", "save", "file", "url", "gzfile", "bzfile", "xzfile", "unz",
    "pipe", "socketConnection", "download.file", "unlink", "file.copy",
    "file.rename", "system", "system2", "shell"
  )
}

wlv_runtime_static_alias_target <- function(node, aliases, forbidden) {
  if (is.symbol(node)) {
    target <- as.character(node)
    if (target %in% forbidden) return(target)
    if (target %in% names(aliases)) return(unname(aliases[[target]]))
    return("")
  }
  target <- wlv_runtime_static_call_name(node)
  if (target %in% forbidden) return(target)
  if (target %in% names(aliases)) return(unname(aliases[[target]]))
  if (is.call(node) && target %in% c("get", "get0", "match.fun")) {
    indirect <- wlv_runtime_static_indirect_target(node)
    if (indirect %in% forbidden) return(indirect)
    if (indirect %in% names(aliases)) return(unname(aliases[[indirect]]))
  }
  ""
}

wlv_runtime_static_scientific_aliases <- function(expressions) {
  forbidden <- wlv_runtime_static_scientific_io()
  assignments <- list()
  collect <- function(node) {
    if (is.call(node) && length(node) == 3L && is.symbol(node[[1L]]) &&
        as.character(node[[1L]]) %in% c("<-", "=")) {
      assignments[[length(assignments) + 1L]] <<- node
    }
    if (is.call(node) || is.expression(node) || is.pairlist(node)) {
      children <- as.list(node)
      if (is.call(node) && length(children)) children <- children[-1L]
      invisible(lapply(children, collect))
    }
    invisible(NULL)
  }
  collect(expressions)

  aliases <- character()
  repeat {
    before <- aliases
    for (assignment in assignments) {
      left <- assignment[[2L]]
      if (!is.symbol(left)) next
      target <- wlv_runtime_static_alias_target(
        assignment[[3L]],
        aliases,
        forbidden
      )
      if (nzchar(target)) aliases[[as.character(left)]] <- target
    }
    if (identical(before, aliases)) break
  }
  aliases
}

wlv_runtime_static_function_calls <- function(node) {
  calls <- character()
  collect <- function(value) {
    if (is.call(value)) {
      name <- wlv_runtime_static_call_name(value[[1L]])
      if (nzchar(name)) calls <<- c(calls, name)
    }
    if (is.call(value) || is.expression(value) || is.pairlist(value)) {
      children <- as.list(value)
      if (is.call(value) && length(children)) {
        head <- children[[1L]]
        children <- children[-1L]
        if (is.call(head)) children <- c(list(head), children)
      }
      invisible(lapply(children, collect))
    }
    invisible(NULL)
  }
  collect(node)
  unique(calls)
}

wlv_runtime_static_top_level_functions <- function(expressions) {
  definitions <- list()
  for (expression in as.list(expressions)) {
    if (!is.call(expression) || length(expression) != 3L ||
        !is.symbol(expression[[1L]]) ||
        !as.character(expression[[1L]]) %in% c("<-", "=") ||
        !is.symbol(expression[[2L]]) ||
        !is.call(expression[[3L]]) ||
        !is.symbol(expression[[3L]][[1L]]) ||
        !identical(as.character(expression[[3L]][[1L]]), "function")) {
      next
    }
    definitions[[as.character(expression[[2L]])]] <- expression[[3L]]
  }
  definitions
}

wlv_runtime_static_transitive_scientific_io <- function(files) {
  definitions <- list()
  file_aliases <- character()
  for (path in files) {
    expressions <- tryCatch(
      parse(file = path, keep.source = FALSE),
      error = function(error) NULL
    )
    if (is.null(expressions)) next
    current <- wlv_runtime_static_top_level_functions(expressions)
    if (length(current)) definitions[names(current)] <- current
    aliases <- wlv_runtime_static_scientific_aliases(expressions)
    if (length(aliases)) file_aliases[names(aliases)] <- aliases
  }
  if (!length(definitions)) return(character())
  calls <- lapply(definitions, wlv_runtime_static_function_calls)
  forbidden <- wlv_runtime_static_scientific_io()
  reasons <- character()
  for (name in names(calls)) {
    direct <- calls[[name]][calls[[name]] %in% forbidden]
    indirect_alias <- calls[[name]][calls[[name]] %in% names(file_aliases)]
    if (length(direct)) {
      reasons[[name]] <- direct[[1L]]
    } else if (length(indirect_alias)) {
      alias <- indirect_alias[[1L]]
      reasons[[name]] <- paste0(alias, "->", file_aliases[[alias]])
    }
  }
  repeat {
    before <- reasons
    for (name in setdiff(names(calls), names(reasons))) {
      unsafe <- calls[[name]][calls[[name]] %in% names(reasons)]
      if (length(unsafe)) {
        callee <- unsafe[[1L]]
        reasons[[name]] <- paste0(callee, "->", reasons[[callee]])
      }
    }
    if (identical(before, reasons)) break
  }
  reasons
}

wlv_runtime_static_deparse <- function(value) {
  paste(deparse(value, width.cutoff = 80L), collapse = " ")
}

wlv_runtime_static_walk <- function(
    node,
    file,
    line = NA_integer_,
    scientific_aliases = character()) {
  reference <- attr(node, "srcref", exact = TRUE)
  if (!is.null(reference)) {
    if (inherits(reference, "srcref")) {
      line <- as.integer(reference[[1L]])
    } else if (is.list(reference) && length(reference) &&
               inherits(reference[[1L]], "srcref")) {
      line <- as.integer(reference[[1L]][[1L]])
    }
  }
  violations <- list()
  add_violation <- function(rule, symbol) {
    violations[[length(violations) + 1L]] <<- data.frame(
      file = file,
      line = line,
      rule = rule,
      symbol = symbol,
      expression = wlv_runtime_static_deparse(node),
      stringsAsFactors = FALSE
    )
  }

  if (is.symbol(node) && identical(as.character(node), ".GlobalEnv")) {
    add_violation("global_environment", ".GlobalEnv")
  }
  if (is.call(node)) {
    call_name <- wlv_runtime_static_call_name(node[[1L]])
    if (call_name %in% c("source", "sys.source")) {
      add_violation("dynamic_source", call_name)
    } else if (identical(call_name, "setwd")) {
      add_violation("working_directory", call_name)
    } else if (identical(call_name, "globalenv")) {
      add_violation("global_environment", call_name)
    } else if (call_name %in% c("do.call", "get", "match.fun")) {
      target <- wlv_runtime_static_indirect_target(node)
      if (target %in% c("source", "sys.source", "setwd", ".GlobalEnv", "globalenv")) {
        add_violation("indirect_runtime_escape", target)
      }
    }
    scientific_module <- startsWith(
      gsub("\\\\", "/", file),
      "R/modules/native/"
    )
    scientific_io <- wlv_runtime_static_scientific_io()
    if (scientific_module && call_name %in% scientific_io) {
      add_violation("scientific_io", call_name)
    }
    if (scientific_module && call_name %in% names(scientific_aliases)) {
      add_violation(
        "scientific_io",
        paste0(call_name, "->", scientific_aliases[[call_name]])
      )
    }
    if (scientific_module && call_name %in% c(
      "eval", "evalq", "parse", "str2lang", "str2expression", "assign",
      "get", "get0", "mget", "match.fun", "baseenv", "parent.env",
      "as.environment", "getNamespace", "loadNamespace"
    )) {
      add_violation("scientific_io", call_name)
    }
    if (scientific_module && identical(call_name, "do.call")) {
      target <- wlv_runtime_static_indirect_target(node)
      safe_literal <- target %in% c("rbind", "[<-") &&
        (is.character(node[[2L]]) || is.symbol(node[[2L]]))
      if (!safe_literal) add_violation("scientific_io", call_name)
    }
    if (scientific_module && length(node) == 3L && is.symbol(node[[1L]]) &&
        as.character(node[[1L]]) %in% c("<-", "=") &&
        is.symbol(node[[2L]]) &&
        as.character(node[[2L]]) %in% names(scientific_aliases) &&
        !(is.call(node[[3L]]) && is.symbol(node[[3L]][[1L]]) &&
          identical(as.character(node[[3L]][[1L]]), "function"))) {
      alias <- as.character(node[[2L]])
      add_violation(
        "scientific_io",
        paste0(alias, "->", scientific_aliases[[alias]])
      )
    }
  }

  if (is.call(node) || is.expression(node) || is.pairlist(node)) {
    children <- as.list(node)
    if (is.call(node) && length(children)) {
      head <- children[[1L]]
      children <- children[-1L]
      if (is.call(head)) children <- c(list(head), children)
    }
    child_rows <- lapply(children, function(child) {
      if (missing(child)) {
        return(NULL)
      }
      wlv_runtime_static_walk(
        child,
        file = file,
        line = line,
        scientific_aliases = scientific_aliases
      )
    })
    for (child_violations in child_rows) {
      if (!is.null(child_violations) && nrow(child_violations)) {
        violations[[length(violations) + 1L]] <- child_violations
      }
    }
  }

  if (!length(violations)) {
    return(data.frame(
      file = character(),
      line = integer(),
      rule = character(),
      symbol = character(),
      expression = character(),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, violations)
}

wlv_runtime_static_scan_file <- function(
    path,
    root = ".",
    transitive_scientific_io = character()) {
  relative_path <- wlv_runtime_static_relative_path(path, root)
  expressions <- tryCatch(
    parse(file = path, keep.source = TRUE),
    error = function(error) error
  )
  if (inherits(expressions, "error")) {
    return(data.frame(
      file = relative_path,
      line = NA_integer_,
      rule = "parse_error",
      symbol = "parse",
      expression = conditionMessage(expressions),
      stringsAsFactors = FALSE
    ))
  }
  scientific_aliases <- if (startsWith(
    gsub("\\\\", "/", relative_path),
    "R/modules/native/"
  )) {
    c(
      wlv_runtime_static_scientific_aliases(expressions),
      transitive_scientific_io
    )
  } else {
    character()
  }
  wlv_runtime_static_walk(
    expressions,
    file = relative_path,
    scientific_aliases = scientific_aliases
  )
}

wlv_runtime_static_violations <- function(
    root = ".",
    files = wlv_runtime_static_files(root),
    allowlist = wlv_runtime_static_allowlist()) {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  if (!is.character(files) || anyNA(files)) {
    stop("`files` must be a character vector without NA.", call. = FALSE)
  }
  if (!is.character(allowlist) || anyNA(allowlist)) {
    stop("`allowlist` must be a character vector without NA.", call. = FALSE)
  }
  allowlist <- wlv_runtime_static_validate_allowlist(allowlist)
  if (!length(files)) {
    return(wlv_runtime_static_walk(expression(), file = ""))
  }
  transitive_scientific_io <- wlv_runtime_static_transitive_scientific_io(files)
  rows <- lapply(files, function(path) {
    relative_path <- wlv_runtime_static_relative_path(path, root)
    violations <- wlv_runtime_static_scan_file(
      path,
      root = root,
      transitive_scientific_io = transitive_scientific_io
    )
    allowed_rules <- wlv_runtime_static_allowed_rules(
      relative_path,
      allowlist
    )
    if (length(allowed_rules) && nrow(violations)) {
      violations <- violations[!violations$rule %in% allowed_rules, , drop = FALSE]
    }
    violations
  })
  rows <- rows[!vapply(rows, is.null, logical(1L))]
  if (!length(rows)) {
    return(wlv_runtime_static_walk(expression(), file = ""))
  }
  violations <- do.call(rbind, rows)
  rownames(violations) <- NULL
  violations
}

wlv_assert_runtime_static_clean <- function(
    root = ".",
    files = wlv_runtime_static_files(root),
    allowlist = wlv_runtime_static_allowlist()) {
  violations <- wlv_runtime_static_violations(
    root = root,
    files = files,
    allowlist = allowlist
  )
  if (nrow(violations)) {
    locations <- sprintf(
      "%s:%s [%s: %s]",
      violations$file,
      ifelse(is.na(violations$line), "?", violations$line),
      violations$rule,
      violations$symbol
    )
    stop(
      paste(
        "Forbidden runtime construct(s) detected:",
        paste0("- ", locations, collapse = "\n"),
        sep = "\n"
      ),
      call. = FALSE
    )
  }
  invisible(violations)
}
