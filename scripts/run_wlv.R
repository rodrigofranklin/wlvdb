# Interface de linha de comando do percurso público WIOD13/WIOD16. --prepare-only
# termina na fonte normalizada; o cálculo publica também indicadores e metadados
# para WLVPanel. --check valida ambiente/pedido, não executa a prova científica.
# Recálculos seletivos usam recalc_wlv na API R. Exemplos completos e requisitos:
# docs/guide-pt.md e docs/guide-en.md.
usage <- function() {
  cat(
    paste(
      "Usage:",
      "  Rscript --vanilla scripts/run_wlv.R [options]",
      "",
      "Options:",
      "  --method NAME       Method to calculate; repeat or use comma-separated names.",
      "  --repeat-pp         Download and prepare source data before calculation.",
      "  --prepare-only      Download, prepare, and validate source data without calculating.",
      "  --workers NUMBER    Number of workers; 1 is sequential (default: WLV_WORKERS or 1).",
      "  --channel NAME      Release channel to publish (default: WLV_CHANNEL or stable).",
      "  --allow-experimental  Explicitly allow methods marked as experimental.",
      "  --check             Validate the environment and arguments, then exit.",
      "  --list-methods[=FORMAT]  List methods and exit; FORMAT is table, names, or csv.",
      "  -h, --help          Print this help and exit.",
      sep = "\n"
    ),
    "\n",
    sep = ""
  )
}

parse_cli <- function(args) {
  result <- list(
    methods = character(),
    repeat_pp = FALSE,
    prepare_only = FALSE,
    workers = suppressWarnings(as.numeric(Sys.getenv("WLV_WORKERS", unset = "1"))),
    channel = Sys.getenv("WLV_CHANNEL", unset = "stable"),
    allow_experimental = FALSE,
    check = FALSE,
    list_methods = NULL,
    help = FALSE
  )

  i <- 1L
  while (i <= length(args)) {
    argument <- args[[i]]
    if (argument %in% c("-h", "--help")) {
      result$help <- TRUE
    } else if (argument == "--repeat-pp") {
      result$repeat_pp <- TRUE
    } else if (argument == "--prepare-only") {
      result$repeat_pp <- TRUE
      result$prepare_only <- TRUE
    } else if (
      argument %in% c("--paper", "--prepaper", "--prepare-paper") ||
        grepl("^--paper=", argument)
    ) {
      stop(
        paste0(
          "Paper tooling has been removed; remove legacy `--paper`, ",
          "`--prepaper`, or `--prepare-paper` options."
        ),
        call. = FALSE
      )
    } else if (argument == "--check") {
      result$check <- TRUE
    } else if (argument == "--allow-experimental") {
      result$allow_experimental <- TRUE
    } else if (argument == "--list-methods") {
      result$list_methods <- "table"
    } else if (grepl("^--list-methods=", argument)) {
      result$list_methods <- sub("^--list-methods=", "", argument)
    } else if (grepl("^--workers=", argument)) {
      result$workers <- suppressWarnings(as.numeric(sub("^--workers=", "", argument)))
    } else if (argument == "--workers") {
      i <- i + 1L
      if (i > length(args)) {
        stop("--workers requires a number.", call. = FALSE)
      }
      result$workers <- suppressWarnings(as.numeric(args[[i]]))
    } else if (grepl("^--channel=", argument)) {
      result$channel <- sub("^--channel=", "", argument)
    } else if (argument == "--channel") {
      i <- i + 1L
      if (i > length(args)) {
        stop("--channel requires a value.", call. = FALSE)
      }
      result$channel <- args[[i]]
    } else if (grepl("^--method=", argument)) {
      result$methods <- c(result$methods, sub("^--method=", "", argument))
    } else if (argument == "--method") {
      i <- i + 1L
      if (i > length(args)) {
        stop("--method requires a value.", call. = FALSE)
      }
      result$methods <- c(result$methods, args[[i]])
    } else {
      stop(sprintf("Unknown argument: %s", argument), call. = FALSE)
    }
    i <- i + 1L
  }

  if (
    !is.null(result$list_methods) &&
    !(result$list_methods %in% c("table", "names", "csv"))
  ) {
    stop("--list-methods format must be table, names, or csv.", call. = FALSE)
  }

  result$methods <- unique(trimws(unlist(strsplit(result$methods, ",", fixed = TRUE))))
  result$methods <- result$methods[nzchar(result$methods)]
  result
}

raw_args <- commandArgs(trailingOnly = TRUE)
if (!length(raw_args)) {
  usage()
  quit(save = "no", status = 2L)
}

args <- parse_cli(raw_args)
if (args$help) {
  usage()
  quit(save = "no", status = 0L)
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_arg)) {
  stop("Run this file with Rscript.", call. = FALSE)
}

script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]), mustWork = TRUE)
project_root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)

bootstrap_environment <- new.env(parent = baseenv())
sys.source(
  file.path(project_root, "scripts", "runtime_bootstrap.R"),
  envir = bootstrap_environment,
  chdir = FALSE
)

Sys.setenv(RENV_PROJECT = project_root)
invisible(utils::capture.output(
  suppressMessages(suppressWarnings(
    source(file.path(project_root, "renv", "activate.R"), local = TRUE)
  )),
  type = "output"
))

if (!is.null(args$list_methods)) {
  runtime <- bootstrap_environment$wlv_load_runtime(project_root)
  catalog <- runtime$wlv_runtime_catalog()
  output <- runtime$wlv_format_catalog_table(
    catalog,
    format = args$list_methods
  )
  cat(output, sep = "\n")
  if (length(output)) {
    cat("\n")
  }
  quit(save = "no", status = 0L)
}

runtime <- bootstrap_environment$wlv_load_runtime(project_root)
catalog <- runtime$wlv_runtime_catalog()

if (!length(args$methods)) {
  stop("At least one --method is required.", call. = FALSE)
}

valid_syntax <- grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", args$methods)
method_list <- runtime$wlv_catalog_method_table(catalog)$method
unknown <- args$methods[!valid_syntax | !(args$methods %in% method_list)]
if (length(unknown)) {
  stop(
    sprintf("Unknown or invalid method: %s", paste(unknown, collapse = ", ")),
    call. = FALSE
  )
}

requested_operations <- if (args$prepare_only) {
  "prepare"
} else {
  c(if (args$repeat_pp) "prepare", "calculate")
}
request <- runtime$wlv_validate_request(
  methods = args$methods,
  repeat_pp = args$repeat_pp,
  workers = args$workers,
  channel = args$channel,
  mode = "calculate",
  root = project_root,
  requested_operations = requested_operations,
  allow_experimental = args$allow_experimental,
  catalog = catalog
)

runtime$wlv_assert_dependencies(
  include_preparation = request$repeat_pp,
  attach = FALSE
)

if (args$check) {
  cat("Environment and arguments are valid.\n")
  quit(save = "no", status = 0L)
}

if (args$prepare_only) {
  runtime$prepare_wlv(
    methods = args$methods,
    allow_experimental = args$allow_experimental
  )
  cat("Source data are prepared and valid.\n")
  quit(save = "no", status = 0L)
}

runtime$get_wlv(
  methods = args$methods,
  repeat_pp = args$repeat_pp,
  workers = args$workers,
  channel = args$channel,
  allow_experimental = args$allow_experimental
)
