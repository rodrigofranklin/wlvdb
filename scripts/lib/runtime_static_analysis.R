wlv_runtime_static_allowlist <- function() {
  c(
    "scripts/runtime_bootstrap.R",
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
  if (!is.function(definition_files)) {
    stop(
      "Reachable static analysis requires the deterministic runtime bootstrap.",
      call. = FALSE
    )
  }
  definition_files <- definition_files()
  if (!is.character(definition_files) ||
      !length(definition_files) || anyNA(definition_files)) {
    stop(
      "Reachable static analysis requires the deterministic runtime bootstrap.",
      call. = FALSE
    )
  }
  files <- c(
    file.path(root, "scripts", "runtime_bootstrap.R"),
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
      "indirect_runtime_escape", "dynamic_evaluation", "legacy_path"
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

wlv_runtime_static_qualified_call_name <- function(head) {
  if (
    is.call(head) && length(head) == 3L && is.symbol(head[[1L]]) &&
      as.character(head[[1L]]) %in% c("::", ":::") &&
      is.symbol(head[[2L]]) &&
      (is.symbol(head[[3L]]) || is.character(head[[3L]]))
  ) {
    return(paste0(
      as.character(head[[2L]]),
      as.character(head[[1L]]),
      as.character(head[[3L]])
    ))
  }
  wlv_runtime_static_call_name(head)
}

wlv_runtime_static_target_name <- function(target) {
  if (!is.character(target) || length(target) != 1L || is.na(target)) {
    return("")
  }
  sub("^.*:::{0,1}", "", target)
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
    "file.rename", "file.create", "file.remove", "file.append",
    "file.link", "file.symlink", "tempfile", "tempdir", "system",
    "system2", "shell", ".Call", ".External", ".External2", ".C",
    ".Fortran", ".Internal", "library", "require", "attach", "detach",
    "environment", "environment<-", "parent.frame", "sys.frame",
    "sys.frames", "sys.status", "sys.parent", "sys.parents", "sys.function",
    "sys.call", "sys.calls", "eval.parent", "topenv", "pos.to.env", "unlockBinding",
    "lockBinding", "lockEnvironment", "makeActiveBinding",
    "activeBindingFunction", ".Primitive", "dynGet", "asNamespace",
    "getExportedValue", "getNamespaceExports", "getNamespaceImports",
    "getNamespaceInfo", "getNamespaceName", "getNamespaceUsers",
    "getNamespaceVersion", "getAnywhere", "getFromNamespace",
    "getS3method", "dump.frames", "recover", "findFunction",
    "findMethod", "findMethods", "getFunction", "getGeneric",
    "getMethod"
  )
}

wlv_runtime_static_scientific_io_namespaces <- function() {
  c(
    "fs", "readr", "readxl", "fst", "processx", "curl", "httr",
    "httr2", "R.matlab", "openxlsx", "writexl", "rio", "rlang"
  )
}

wlv_runtime_static_scientific_target <- function(target) {
  if (!is.character(target) || length(target) != 1L || is.na(target) ||
      !nzchar(target)) {
    return(FALSE)
  }
  terminal <- wlv_runtime_static_target_name(target)
  if (terminal %in% wlv_runtime_static_scientific_io()) {
    return(TRUE)
  }
  qualified <- grepl("::", target, fixed = TRUE)
  if (!qualified) return(FALSE)
  package <- sub("::.*$", "", target)
  if (identical(package, "utils")) {
    # Native modules use only the data-only `head()` helper from utils. A
    # namespace-wide deny-by-default rule prevents new reflection helpers such
    # as getAnywhere(), getFromNamespace(), dump.frames(), or recover() from
    # becoming alternate paths into runner frames.
    return(!terminal %in% c("head", "modifyList"))
  }
  if (identical(package, "methods")) {
    # Matrix coercion is the only scientific use of methods. Keep the rest of
    # the namespace unavailable so function/method lookup cannot recover frame
    # inspection primitives through S4 reflection helpers.
    return(!terminal %in% c("as", "selectMethod"))
  }
  package %in% wlv_runtime_static_scientific_io_namespaces()
}

wlv_runtime_static_runtime_targets <- function() {
  c("source", "sys.source", "setwd", "globalenv", ".GlobalEnv")
}

wlv_runtime_static_dynamic_targets <- function() {
  c(
    "do.call", "get", "get0", "match.fun", "eval", "evalq", "parse",
    "str2lang", "str2expression"
  )
}

wlv_runtime_static_higher_order_positions <- function(call_name) {
  switch(
    call_name,
    lapply = 3L,
    sapply = 3L,
    vapply = 3L,
    apply = 4L,
    tapply = 4L,
    by = 4L,
    aggregate = 4L,
    Map = 2L,
    mapply = 2L,
    Reduce = 2L,
    Filter = 2L,
    Find = 2L,
    Position = 2L,
    outer = 4L,
    map = 3L,
    map_chr = 3L,
    map_dbl = 3L,
    map_int = 3L,
    map_lgl = 3L,
    map_raw = 3L,
    map_vec = 3L,
    walk = 3L,
    map2 = 4L,
    walk2 = 4L,
    imap = 3L,
    iwalk = 3L,
    pmap = 3L,
    pwalk = 3L,
    integer()
  )
}

wlv_runtime_static_higher_order_arguments <- function(call, call_name) {
  if (!is.call(call) || length(call) < 2L) return(list())
  arguments <- as.list(call)[-1L]
  argument_names <- names(arguments)
  selected <- integer()
  if (!is.null(argument_names)) {
    selected <- which(argument_names %in% c("FUN", "f", ".f"))
  }
  positions <- wlv_runtime_static_higher_order_positions(call_name)
  positions <- positions[positions <= length(call)] - 1L
  selected <- unique(c(selected, positions))
  selected <- selected[selected >= 1L & selected <= length(arguments)]
  arguments[selected]
}

wlv_runtime_static_legacy_path <- function(value) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value)) {
    return("")
  }
  normalized <- tryCatch(
    tolower(gsub("\\\\", "/", enc2utf8(value))),
    error = function(error) ""
  )
  if (!nzchar(normalized)) return("")
  patterns <- c(
    "(^|/)(r|scripts)/lib/(re_)?computations[.]r($|[^a-z0-9_.-])",
    "(^|/)(r|scripts)/lib/(parameters|raw_sea_data|control_variables|results_variables|filters_io|prepare_computation|write_labels)[.]r($|[^a-z0-9_.-])",
    "(^|/)(r|scripts)/modules/(assumptions|matrices|reduced_matrices|variables)/",
    "(^|/)methods/[^/]+/_(method|source|common)_(assumptions|matrices|solutions)[.]csv($|[^a-z0-9_.-])"
  )
  if (any(vapply(patterns, grepl, logical(1L), x = normalized, perl = TRUE))) {
    return(value)
  }
  ""
}

wlv_runtime_static_higher_order_targets <- function() {
  c(
    "lapply", "sapply", "vapply", "apply", "tapply", "by", "aggregate",
    "Map", "mapply", "Reduce", "Filter", "Find", "Position", "outer",
    "map", "map_chr", "map_dbl", "map_int", "map_lgl", "map_raw",
    "map_vec", "walk", "map2", "walk2", "imap", "iwalk", "pmap",
    "pwalk"
  )
}

wlv_runtime_static_assignment_parts <- function(node) {
  if (!is.call(node) || length(node) != 3L || !is.symbol(node[[1L]])) {
    return(NULL)
  }
  operator <- as.character(node[[1L]])
  if (operator %in% c("<-", "=", "<<-")) {
    return(list(left = node[[2L]], right = node[[3L]]))
  }
  if (operator %in% c("->", "->>")) {
    return(list(left = node[[3L]], right = node[[2L]]))
  }
  NULL
}

wlv_runtime_static_assignment_root <- function(left) {
  current <- left
  while (
    is.call(current) && length(current) >= 2L &&
      is.symbol(current[[1L]]) &&
      as.character(current[[1L]]) %in% c("[", "[[", "$", "@")
  ) {
    current <- current[[2L]]
  }
  if (is.symbol(current)) as.character(current) else ""
}

wlv_runtime_static_assignments <- function(expressions) {
  assignments <- list()
  collect <- function(node) {
    if (!is.null(wlv_runtime_static_assignment_parts(node))) {
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
  assignments
}

wlv_runtime_static_text_value <- function(node, strings = character()) {
  if (is.character(node) && length(node) == 1L && !is.na(node)) {
    return(node)
  }
  if (is.symbol(node)) {
    name <- as.character(node)
    if (name %in% names(strings)) return(unname(strings[[name]]))
    return("")
  }
  if (!is.call(node)) return("")
  call_name <- wlv_runtime_static_target_name(
    wlv_runtime_static_qualified_call_name(node[[1L]])
  )
  if (!call_name %in% c("paste0", "paste", "file.path")) return("")
  arguments <- as.list(node)[-1L]
  argument_names <- names(arguments)
  values <- vapply(arguments, wlv_runtime_static_text_value, character(1L),
    strings = strings)
  if (any(!nzchar(values))) return("")
  if (identical(call_name, "file.path")) {
    return(do.call(file.path, as.list(unname(values))))
  }
  separator <- if (identical(call_name, "paste0")) "" else " "
  collapse <- NULL
  if (!is.null(argument_names)) {
    separator_index <- which(argument_names == "sep")
    collapse_index <- which(argument_names == "collapse")
    if (length(separator_index)) separator <- values[[separator_index[[1L]]]]
    if (length(collapse_index)) collapse <- values[[collapse_index[[1L]]]]
    values <- values[!argument_names %in% c("sep", "collapse")]
  }
  paste(unname(values), collapse = separator)
}

wlv_runtime_static_access_key <- function(node, strings = character()) {
  if (is.symbol(node)) return(as.character(node))
  if (!is.call(node) || length(node) != 3L || !is.symbol(node[[1L]])) {
    return("")
  }
  operator <- as.character(node[[1L]])
  if (!operator %in% c("$", "[[")) return("")
  owner <- wlv_runtime_static_access_key(node[[2L]], strings = strings)
  if (!nzchar(owner)) return("")
  member <- node[[3L]]
  if (identical(operator, "$")) {
    if (is.symbol(member)) member <- as.character(member)
    if (!is.character(member) || length(member) != 1L || is.na(member)) {
      return(paste0(owner, "$*"))
    }
    return(paste0(owner, "$", member))
  }
  if (is.symbol(member)) {
    member_name <- as.character(member)
    if (member_name %in% names(strings)) {
      member <- unname(strings[[member_name]])
    } else {
      return(paste0(owner, "$*"))
    }
  }
  if (is.character(member) && length(member) == 1L && !is.na(member)) {
    return(paste0(owner, "$", member))
  }
  if ((is.integer(member) || is.double(member)) &&
      length(member) == 1L && !is.na(member)) {
    return(paste0(owner, "[[", format(member, scientific = FALSE), "]]"))
  }
  paste0(owner, "$*")
}

wlv_runtime_static_callable_universe <- function() {
  unique(c(
    wlv_runtime_static_runtime_targets(),
    wlv_runtime_static_dynamic_targets(),
    wlv_runtime_static_higher_order_targets(),
    wlv_runtime_static_scientific_io()
  ))
}

wlv_runtime_static_resolve_target <- function(
    node,
    aliases = character(),
    strings = character()) {
  if (is.character(node) && length(node) == 1L && !is.na(node)) {
    target <- node
    if (target %in% names(aliases)) return(unname(aliases[[target]]))
    return(target)
  }
  if (is.symbol(node)) {
    target <- as.character(node)
    if (target %in% names(aliases)) return(unname(aliases[[target]]))
    if (target %in% wlv_runtime_static_callable_universe()) return(target)
    return("")
  }
  if (!is.call(node)) return("")
  if (length(node) == 3L && is.symbol(node[[1L]]) &&
      as.character(node[[1L]]) %in% c("$", "[[")) {
    access_key <- wlv_runtime_static_access_key(node, strings = strings)
    if (nzchar(access_key) && access_key %in% names(aliases)) {
      return(unname(aliases[[access_key]]))
    }
    root <- wlv_runtime_static_assignment_root(node)
    wildcard <- if (nzchar(root)) paste0(root, "$*") else ""
    if (nzchar(wildcard) && wildcard %in% names(aliases)) {
      return(unname(aliases[[wildcard]]))
    }
    owner <- wlv_runtime_static_resolve_target(
      node[[2L]], aliases = aliases, strings = strings
    )
    member <- node[[3L]]
    if (nzchar(owner) &&
        (is.symbol(member) ||
          (is.character(member) && length(member) == 1L && !is.na(member)))) {
      return(paste0(owner, "$", as.character(member)))
    }
  }
  qualified <- wlv_runtime_static_qualified_call_name(node)
  if (grepl("::", qualified, fixed = TRUE)) return(qualified)
  call_target <- wlv_runtime_static_resolve_target(
    node[[1L]], aliases = aliases, strings = strings
  )
  call_name <- wlv_runtime_static_target_name(call_target)
  if (!call_name %in% c("get", "get0", "match.fun") || length(node) < 2L) {
    return("")
  }
  indirect <- wlv_runtime_static_text_value(node[[2L]], strings = strings)
  if (!nzchar(indirect)) {
    indirect <- wlv_runtime_static_resolve_target(
      node[[2L]], aliases = aliases, strings = strings
    )
  }
  if (indirect %in% names(aliases)) return(unname(aliases[[indirect]]))
  indirect
}

wlv_runtime_static_copy_container_aliases <- function(
    aliases,
    source_prefix,
    target_prefix) {
  if (!nzchar(source_prefix) || !nzchar(target_prefix) || !length(aliases)) {
    return(aliases)
  }
  names_aliases <- names(aliases)
  descendants <- startsWith(names_aliases, paste0(source_prefix, "$")) |
    startsWith(names_aliases, paste0(source_prefix, "[["))
  for (source_name in names_aliases[descendants]) {
    suffix <- substring(
      source_name,
      nchar(source_prefix, type = "chars") + 1L
    )
    aliases[[paste0(target_prefix, suffix)]] <- aliases[[source_name]]
  }
  aliases
}

wlv_runtime_static_container_aliases <- function(
    node,
    prefix,
    aliases = character(),
    strings = character()) {
  if (!is.call(node) || !nzchar(prefix)) return(aliases)
  constructor <- wlv_runtime_static_target_name(
    wlv_runtime_static_qualified_call_name(node[[1L]])
  )
  if (!constructor %in% c("list", "pairlist", "c")) return(aliases)
  arguments <- as.list(node)[-1L]
  argument_names <- names(arguments)
  if (is.null(argument_names)) {
    argument_names <- rep.int("", length(arguments))
  }
  for (position in seq_along(arguments)) {
    argument <- arguments[[position]]
    positional_key <- paste0(prefix, "[[", position, "]]" )
    named_key <- if (nzchar(argument_names[[position]])) {
      paste0(prefix, "$", argument_names[[position]])
    } else {
      ""
    }
    keys <- unique(c(named_key[nzchar(named_key)], positional_key))
    target <- wlv_runtime_static_resolve_target(
      argument,
      aliases = aliases,
      strings = strings
    )
    terminal <- wlv_runtime_static_target_name(target)
    recognized <- terminal %in% wlv_runtime_static_callable_universe() ||
      wlv_runtime_static_scientific_target(target)
    if (nzchar(target) && recognized) {
      for (key in keys) aliases[[key]] <- target
    }
    for (key in keys) {
      aliases <- wlv_runtime_static_container_aliases(
        argument,
        prefix = key,
        aliases = aliases,
        strings = strings
      )
    }
  }
  aliases
}

wlv_runtime_static_alias_context <- function(expressions) {
  assignments <- wlv_runtime_static_assignments(expressions)

  strings <- character()
  repeat {
    before <- strings
    for (assignment in assignments) {
      parts <- wlv_runtime_static_assignment_parts(assignment)
      if (!is.symbol(parts$left)) next
      value <- wlv_runtime_static_text_value(parts$right, strings = strings)
      if (nzchar(value)) strings[[as.character(parts$left)]] <- value
    }
    if (identical(before, strings)) break
  }

  aliases <- character()
  repeat {
    before <- aliases
    for (assignment in assignments) {
      parts <- wlv_runtime_static_assignment_parts(assignment)
      left_key <- wlv_runtime_static_access_key(parts$left, strings = strings)
      if (!nzchar(left_key)) next
      target <- wlv_runtime_static_resolve_target(
        parts$right,
        aliases = aliases,
        strings = strings
      )
      terminal <- wlv_runtime_static_target_name(target)
      recognized <- terminal %in% wlv_runtime_static_callable_universe() ||
        wlv_runtime_static_scientific_target(target)
      if (nzchar(target) && recognized) {
        aliases[[left_key]] <- target
      }
      if (is.symbol(parts$left)) {
        aliases <- wlv_runtime_static_container_aliases(
          parts$right,
          prefix = left_key,
          aliases = aliases,
          strings = strings
        )
      }
      if (is.symbol(parts$left) && is.symbol(parts$right)) {
        aliases <- wlv_runtime_static_copy_container_aliases(
          aliases,
          source_prefix = as.character(parts$right),
          target_prefix = left_key
        )
      }
    }
    if (identical(before, aliases)) break
  }

  parsed <- character()
  repeat {
    before <- parsed
    for (assignment in assignments) {
      parts <- wlv_runtime_static_assignment_parts(assignment)
      left_name <- wlv_runtime_static_assignment_root(parts$left)
      if (!nzchar(left_name)) next
      parsed_value <- wlv_runtime_static_contains_parsed(
        parts$right,
        aliases = aliases,
        strings = strings,
        parsed = parsed
      )
      if (parsed_value) parsed <- unique(c(parsed, left_name))
    }
    if (identical(before, parsed)) break
  }

  list(aliases = aliases, strings = strings, parsed = parsed)
}

wlv_runtime_static_scientific_aliases <- function(expressions) {
  aliases <- wlv_runtime_static_alias_context(expressions)$aliases
  aliases[vapply(aliases, wlv_runtime_static_scientific_target, logical(1L))]
}

wlv_runtime_static_contains_parsed <- function(
    node,
    aliases = character(),
    strings = character(),
    parsed = character()) {
  if (is.symbol(node) && as.character(node) %in% parsed) return(TRUE)
  if (is.call(node)) {
    target <- wlv_runtime_static_resolve_target(
      node[[1L]], aliases = aliases, strings = strings
    )
    target_name <- wlv_runtime_static_target_name(target)
    if (target_name %in% c("parse", "str2lang", "str2expression")) {
      return(TRUE)
    }
    if (identical(target_name, "do.call") && length(node) >= 2L) {
      indirect <- wlv_runtime_static_resolve_target(
        node[[2L]], aliases = aliases, strings = strings
      )
      if (wlv_runtime_static_target_name(indirect) %in%
          c("parse", "str2lang", "str2expression")) {
        return(TRUE)
      }
    }
  }
  if (!is.call(node) && !is.expression(node) && !is.pairlist(node)) {
    return(FALSE)
  }
  children <- as.list(node)
  if (is.call(node) && length(children)) children <- children[-1L]
  any(vapply(children, wlv_runtime_static_contains_parsed, logical(1L),
    aliases = aliases, strings = strings, parsed = parsed))
}

wlv_runtime_static_function_calls <- function(
    node,
    aliases = character(),
    strings = character()) {
  calls <- character()
  collect <- function(value) {
    if (is.call(value)) {
      target <- wlv_runtime_static_resolve_target(
        value[[1L]], aliases = aliases, strings = strings
      )
      if (!nzchar(target)) {
        target <- wlv_runtime_static_qualified_call_name(value[[1L]])
      }
      if (nzchar(target)) calls <<- c(calls, target)
      call_name <- wlv_runtime_static_target_name(target)
      callbacks <- wlv_runtime_static_higher_order_arguments(value, call_name)
      if (length(callbacks)) {
        callback_targets <- vapply(
          callbacks,
          wlv_runtime_static_observed_target,
          character(1L),
          aliases = aliases,
          strings = strings
        )
        calls <<- c(calls, callback_targets[nzchar(callback_targets)])
      }
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
  calls <- list()
  for (path in files) {
    expressions <- tryCatch(
      parse(file = path, keep.source = FALSE),
      error = function(error) NULL
    )
    if (is.null(expressions)) next
    current <- wlv_runtime_static_top_level_functions(expressions)
    context <- wlv_runtime_static_alias_context(expressions)
    if (length(current)) {
      definitions[names(current)] <- current
      current_calls <- lapply(
        current,
        wlv_runtime_static_function_calls,
        aliases = context$aliases,
        strings = context$strings
      )
      calls[names(current_calls)] <- current_calls
    }
    scientific_aliases <- context$aliases[vapply(
      context$aliases,
      wlv_runtime_static_scientific_target,
      logical(1L)
    )]
    if (length(scientific_aliases)) {
      file_aliases[names(scientific_aliases)] <- scientific_aliases
    }
  }
  if (!length(definitions)) return(character())
  reasons <- character()
  for (name in names(calls)) {
    direct <- calls[[name]][vapply(
      calls[[name]],
      wlv_runtime_static_scientific_target,
      logical(1L)
    )]
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

wlv_runtime_static_observed_target <- function(
    node,
    aliases = character(),
    strings = character()) {
  target <- wlv_runtime_static_resolve_target(
    node,
    aliases = aliases,
    strings = strings
  )
  if (nzchar(target)) return(target)
  if (is.symbol(node)) return(as.character(node))
  if (is.character(node) && length(node) == 1L && !is.na(node)) return(node)
  if (is.call(node)) return(wlv_runtime_static_qualified_call_name(node))
  ""
}

wlv_runtime_static_display_target <- function(target) {
  if (!is.character(target) || length(target) != 1L || is.na(target)) {
    return("")
  }
  sub("^(base|utils|stats):::{0,1}", "", target)
}

wlv_runtime_static_is_bootstrap_eval <- function(node) {
  if (!is.call(node) || length(node) != 3L) return(FALSE)
  head <- node[[1L]]
  if (!is.call(head) || length(head) != 3L || !is.symbol(head[[1L]]) ||
      !identical(as.character(head[[1L]]), "::") ||
      !is.symbol(head[[2L]]) ||
      !identical(as.character(head[[2L]]), "base") ||
      !is.symbol(head[[3L]]) ||
      !identical(as.character(head[[3L]]), "eval")) {
    return(FALSE)
  }
  arguments <- as.list(node)[-1L]
  argument_names <- names(arguments)
  if (is.null(argument_names)) argument_names <- rep.int("", length(arguments))
  if (!identical(argument_names, c("", "envir"))) return(FALSE)
  expressions <- arguments[[1L]]
  environment <- arguments[[2L]]
  is.call(expressions) && length(expressions) == 3L &&
    is.symbol(expressions[[1L]]) &&
    identical(as.character(expressions[[1L]]), "[[") &&
    is.symbol(expressions[[2L]]) &&
    identical(as.character(expressions[[2L]]), "parsed_definitions") &&
    is.symbol(expressions[[3L]]) &&
    identical(as.character(expressions[[3L]]), "index") &&
    is.symbol(environment) &&
    identical(as.character(environment), "namespace")
}

wlv_runtime_static_count_bootstrap_evals <- function(node) {
  count <- 0L
  collect <- function(value) {
    if (wlv_runtime_static_is_bootstrap_eval(value)) count <<- count + 1L
    if (is.call(value) || is.expression(value) || is.pairlist(value)) {
      children <- as.list(value)
      if (is.call(value) && length(children)) {
        head <- children[[1L]]
        children <- children[-1L]
        if (is.call(head)) children <- c(list(head), children)
      }
      invisible(lapply(children, function(child) {
        if (!missing(child)) collect(child)
        NULL
      }))
    }
    invisible(NULL)
  }
  collect(node)
  count
}

wlv_runtime_static_walk <- function(
    node,
    file,
    line = NA_integer_,
    scientific_aliases = character(),
    aliases = character(),
    strings = character(),
    parsed = character(),
    bootstrap_eval_count = 0L,
    nested = FALSE) {
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
  if (is.symbol(node) && identical(as.character(node), ".BaseNamespaceEnv") &&
      startsWith(gsub("\\\\", "/", file), "scripts/modules/native/")) {
    add_violation("scientific_io", ".BaseNamespaceEnv")
  }
  if (is.character(node) && length(node) == 1L) {
    legacy <- wlv_runtime_static_legacy_path(node)
    if (nzchar(legacy)) add_violation("legacy_path", legacy)
  }
  if (is.call(node)) {
    target <- wlv_runtime_static_observed_target(
      node[[1L]], aliases = aliases, strings = strings
    )
    call_name <- wlv_runtime_static_target_name(target)
    target_symbol <- wlv_runtime_static_display_target(target)
    if (is.symbol(node[[1L]])) {
      head_name <- as.character(node[[1L]])
      if (head_name %in% names(aliases)) {
        target_symbol <- paste0(
          head_name,
          "->",
          wlv_runtime_static_display_target(target)
        )
      }
    } else if (is.call(node[[1L]])) {
      access_key <- wlv_runtime_static_access_key(
        node[[1L]],
        strings = strings
      )
      if (nzchar(access_key) &&
          (access_key %in% names(aliases) ||
            paste0(wlv_runtime_static_assignment_root(node[[1L]]), "$*") %in%
              names(aliases))) {
        target_symbol <- paste0(
          access_key,
          "->",
          wlv_runtime_static_display_target(target)
        )
      }
    }
    if (call_name %in% c("source", "sys.source")) {
      add_violation("dynamic_source", target_symbol)
    } else if (identical(call_name, "setwd")) {
      add_violation("working_directory", target_symbol)
    } else if (identical(call_name, "globalenv")) {
      add_violation("global_environment", target_symbol)
    }

    indirect <- ""
    if (call_name %in% c("do.call", "get", "get0", "match.fun") &&
        length(node) >= 2L) {
      indirect <- wlv_runtime_static_observed_target(
        node[[2L]], aliases = aliases, strings = strings
      )
      indirect_name <- wlv_runtime_static_target_name(indirect)
      if (indirect_name %in% wlv_runtime_static_runtime_targets()) {
        add_violation("indirect_runtime_escape", indirect)
      }
    }

    bootstrap_eval_allowed <- identical(
      gsub("\\\\", "/", file),
      "scripts/runtime_bootstrap.R"
    ) && identical(as.integer(bootstrap_eval_count), 1L) &&
      wlv_runtime_static_is_bootstrap_eval(node)
    if (call_name %in% c("eval", "evalq") && length(node) >= 2L &&
        wlv_runtime_static_contains_parsed(
          node[[2L]], aliases = aliases, strings = strings, parsed = parsed
        ) && !bootstrap_eval_allowed) {
      add_violation("dynamic_evaluation", target_symbol)
    }
    if (identical(call_name, "do.call") &&
        wlv_runtime_static_target_name(indirect) %in% c("eval", "evalq") &&
        length(node) >= 3L &&
        wlv_runtime_static_contains_parsed(
          node[[3L]], aliases = aliases, strings = strings, parsed = parsed
        )) {
      add_violation("dynamic_evaluation", paste0("do.call->", indirect))
    }

    callbacks <- wlv_runtime_static_higher_order_arguments(node, call_name)
    callback_targets <- if (length(callbacks)) {
      vapply(
        callbacks,
        wlv_runtime_static_observed_target,
        character(1L),
        aliases = aliases,
        strings = strings
      )
    } else {
      character()
    }
    runtime_callbacks <- callback_targets[
      vapply(
        callback_targets,
        function(value) {
          wlv_runtime_static_target_name(value) %in%
            wlv_runtime_static_runtime_targets()
        },
        logical(1L)
      )
    ]
    if (length(runtime_callbacks)) {
      add_violation(
        "indirect_runtime_escape",
        paste0(call_name, "->", runtime_callbacks[[1L]])
      )
    }
    evaluation_callbacks <- callback_targets[
      vapply(
        callback_targets,
        function(value) {
          wlv_runtime_static_target_name(value) %in% c("eval", "evalq")
        },
        logical(1L)
      )
    ]
    if (length(evaluation_callbacks)) {
      non_callback <- as.list(node)[-1L]
      if (length(non_callback) && any(vapply(
        non_callback,
        wlv_runtime_static_contains_parsed,
        logical(1L),
        aliases = aliases,
        strings = strings,
        parsed = parsed
      ))) {
        add_violation(
          "dynamic_evaluation",
          paste0(call_name, "->", evaluation_callbacks[[1L]])
        )
      }
    }

    constant_text <- wlv_runtime_static_text_value(node, strings = strings)
    legacy <- wlv_runtime_static_legacy_path(constant_text)
    if (nzchar(legacy)) add_violation("legacy_path", legacy)

    scientific_module <- startsWith(
      gsub("\\\\", "/", file),
      "scripts/modules/native/"
    )
    internal_namespace_call <- is.call(node[[1L]]) &&
      length(node[[1L]]) == 3L && is.symbol(node[[1L]][[1L]]) &&
      identical(as.character(node[[1L]][[1L]]), ":::")
    if (scientific_module && internal_namespace_call) {
      add_violation("scientific_io", target_symbol)
    }
    if (scientific_module && wlv_runtime_static_scientific_target(target)) {
      add_violation("scientific_io", target_symbol)
    }
    if (scientific_module && target %in% names(scientific_aliases)) {
      add_violation(
        "scientific_io",
        paste0(target, "->", scientific_aliases[[target]])
      )
    }
    if (scientific_module && call_name %in% c(
      "eval", "evalq", "parse", "str2lang", "str2expression", "assign",
      "get", "get0", "mget", "match.fun", "baseenv", "parent.env",
      "as.environment", "getNamespace", "loadNamespace"
    )) {
      add_violation("scientific_io", target_symbol)
    }
    if (scientific_module && identical(call_name, "do.call")) {
      safe_literal <- indirect %in% c("rbind", "[<-") &&
        (is.character(node[[2L]]) || is.symbol(node[[2L]]))
      if (!safe_literal) add_violation("scientific_io", target_symbol)
    }
    scientific_callbacks <- callback_targets[vapply(
      callback_targets,
      function(value) {
        wlv_runtime_static_scientific_target(value) ||
          value %in% names(scientific_aliases)
      },
      logical(1L)
    )]
    if (scientific_module && length(scientific_callbacks)) {
      callback <- scientific_callbacks[[1L]]
      reason <- if (callback %in% names(scientific_aliases)) {
        paste0(callback, "->", scientific_aliases[[callback]])
      } else {
        wlv_runtime_static_display_target(callback)
      }
      add_violation("scientific_io", paste0(call_name, "->", reason))
    }

    assignment <- wlv_runtime_static_assignment_parts(node)
    if (!is.null(assignment) && is.symbol(assignment$left) &&
        !is.character(assignment$right)) {
      assigned_target <- wlv_runtime_static_observed_target(
        assignment$right, aliases = aliases, strings = strings
      )
      assigned_name <- wlv_runtime_static_target_name(assigned_target)
      alias_symbol <- paste0(
        as.character(assignment$left),
        "->",
        wlv_runtime_static_display_target(assigned_target)
      )
      if (assigned_name %in% c("source", "sys.source")) {
        add_violation("dynamic_source", alias_symbol)
      } else if (identical(assigned_name, "setwd")) {
        add_violation("working_directory", alias_symbol)
      } else if (assigned_name %in% c("globalenv", ".GlobalEnv")) {
        add_violation("global_environment", alias_symbol)
      }
      if (scientific_module &&
          (wlv_runtime_static_scientific_target(assigned_target) ||
            assigned_target %in% names(scientific_aliases))) {
        reason <- if (assigned_target %in% names(scientific_aliases)) {
          paste0(assigned_target, "->", scientific_aliases[[assigned_target]])
        } else {
          wlv_runtime_static_display_target(assigned_target)
        }
        add_violation(
          "scientific_io",
          paste0(as.character(assignment$left), "->", reason)
        )
      }
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
        scientific_aliases = scientific_aliases,
        aliases = aliases,
        strings = strings,
        parsed = parsed,
        bootstrap_eval_count = bootstrap_eval_count,
        nested = TRUE
      )
    })
    for (child_violations in child_rows) {
      if (!is.null(child_violations) && nrow(child_violations)) {
        violations[[length(violations) + 1L]] <- child_violations
      }
    }
  }

  if (!length(violations)) {
    if (isTRUE(nested)) return(NULL)
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
  context <- wlv_runtime_static_alias_context(expressions)
  bootstrap_eval_count <- if (identical(
    gsub("\\\\", "/", relative_path),
    "scripts/runtime_bootstrap.R"
  )) {
    wlv_runtime_static_count_bootstrap_evals(expressions)
  } else {
    0L
  }
  scientific_aliases <- if (startsWith(
    gsub("\\\\", "/", relative_path),
    "scripts/modules/native/"
  )) {
    local <- context$aliases[vapply(
      context$aliases,
      wlv_runtime_static_scientific_target,
      logical(1L)
    )]
    local[names(transitive_scientific_io)] <- transitive_scientific_io
    local
  } else {
    character()
  }
  wlv_runtime_static_walk(
    expressions,
    file = relative_path,
    scientific_aliases = scientific_aliases,
    aliases = context$aliases,
    strings = context$strings,
    parsed = context$parsed,
    bootstrap_eval_count = bootstrap_eval_count
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
