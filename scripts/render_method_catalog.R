usage <- function() {
  cat(
    paste(
      "Usage:",
      "  Rscript --vanilla scripts/render_method_catalog.R [--check]",
      "",
      "Options:",
      "  --check     Fail if docs/methods.md is not synchronized with the catalog.",
      "  -h, --help  Print this help and exit.",
      sep = "\n"
    ),
    "\n",
    sep = ""
  )
}

parse_args <- function(args) {
  unknown <- setdiff(args, c("--check", "-h", "--help"))
  if (length(unknown)) {
    stop(sprintf("Unknown argument: %s", unknown[[1L]]), call. = FALSE)
  }

  list(
    check = "--check" %in% args,
    help = any(args %in% c("-h", "--help"))
  )
}

catalog_component <- function(catalog, name, aliases = character()) {
  candidates <- c(name, aliases)
  present <- candidates[candidates %in% names(catalog)]
  if (!length(present)) {
    stop(
      sprintf("The loaded catalog does not contain '%s'.", name),
      call. = FALSE
    )
  }
  catalog[[present[[1L]]]]
}

assert_columns <- function(data, component, columns) {
  missing <- setdiff(columns, names(data))
  if (length(missing)) {
    stop(
      sprintf(
        "Catalog component '%s' is missing columns: %s.",
        component,
        paste(missing, collapse = ", ")
      ),
      call. = FALSE
    )
  }
}

markdown_cell <- function(value) {
  if (length(value) == 0L || is.na(value) || !nzchar(trimws(as.character(value)))) {
    return(wlv_markdown_em_dash)
  }

  value <- enc2utf8(gsub("[\r\n]+", " ", as.character(value)))
  value <- gsub("|", "\\|", value, fixed = TRUE)
  trimws(value)
}

markdown_code <- function(value) {
  value <- markdown_cell(value)
  if (identical(value, wlv_markdown_em_dash)) value else sprintf("`%s`", value)
}

markdown_link <- function(value) {
  value <- markdown_cell(value)
  if (identical(value, wlv_markdown_em_dash)) {
    return(value)
  }

  value <- gsub("\\\\", "/", value)
  if (grepl("^https?://", value)) {
    return(sprintf("[link](%s)", value))
  }

  target <- if (startsWith(value, "docs/")) {
    sub("^docs/", "", value)
  } else {
    paste0("../", value)
  }
  sprintf("[%s](%s)", markdown_cell(value), target)
}

yes_no <- function(value) {
  if (isTRUE(value)) "yes" else "no"
}

year_range <- function(start, end) {
  if (is.na(start) && is.na(end)) {
    return(wlv_markdown_em_dash)
  }
  if (is.na(start)) {
    return(sprintf("%s %s", wlv_markdown_less_equal, end))
  }
  if (is.na(end)) {
    return(sprintf("%s %s", wlv_markdown_greater_equal, start))
  }
  if (identical(as.integer(start), as.integer(end))) {
    return(as.character(as.integer(start)))
  }
  sprintf(
    "%d%s%d",
    as.integer(start),
    wlv_markdown_en_dash,
    as.integer(end)
  )
}

markdown_table <- function(headers, rows) {
  if (!length(rows)) {
    stop("Cannot render an empty Markdown table.", call. = FALSE)
  }

  c(
    paste0("| ", paste(headers, collapse = " | "), " |"),
    paste0("| ", paste(rep("---", length(headers)), collapse = " | "), " |"),
    vapply(
      rows,
      function(row) paste0("| ", paste(row, collapse = " | "), " |"),
      character(1L),
      USE.NAMES = FALSE
    )
  )
}

render_method_rows <- function(methods, sources) {
  methods <- methods[order(methods$method), , drop = FALSE]

  lapply(seq_len(nrow(methods)), function(i) {
    method <- methods[i, , drop = FALSE]
    source <- sources[sources$source == method$source, , drop = FALSE]
    if (nrow(source) != 1L) {
      stop(
        sprintf("Method '%s' does not resolve to exactly one source.", method$method),
        call. = FALSE
      )
    }

    c(
      markdown_code(method$method),
      markdown_code(method$source),
      markdown_code(method$status),
      markdown_code(source$status),
      year_range(source$year_start, source$year_end),
      yes_no(source$can_prepare),
      yes_no(method$can_calculate),
      yes_no(method$can_recalculate),
      markdown_cell(method$description),
      markdown_code(method$validation_id),
      markdown_link(method$documentation),
      markdown_cell(method$limitations)
    )
  })
}

render_source_rows <- function(sources) {
  sources <- sources[order(sources$source), , drop = FALSE]

  lapply(seq_len(nrow(sources)), function(i) {
    source <- sources[i, , drop = FALSE]
    c(
      markdown_code(source$source),
      markdown_code(source$status),
      year_range(source$year_start, source$year_end),
      markdown_code(source$parameter_set),
      markdown_code(source$data_dir),
      yes_no(source$can_prepare),
      markdown_code(source$preparation_task),
      markdown_code(source$validator_id),
      markdown_code(source$artifact_profile),
      markdown_code(source$missingness_policy),
      markdown_code(source$unit_contract),
      markdown_link(source$documentation),
      markdown_cell(source$limitations)
    )
  })
}

wlv_markdown_em_dash <- intToUtf8(0x2014L)
wlv_markdown_en_dash <- intToUtf8(0x2013L)
wlv_markdown_less_equal <- intToUtf8(0x2264L)
wlv_markdown_greater_equal <- intToUtf8(0x2265L)

render_unit_contract_rows <- function(contracts) {
  contracts <- contracts[order(contracts$contract), , drop = FALSE]

  lapply(seq_len(nrow(contracts)), function(i) {
    contract <- contracts[i, , drop = FALSE]
    c(
      markdown_code(contract$contract),
      markdown_code(contract$schema_version),
      markdown_code(contract$source),
      markdown_link(contract$units),
      markdown_link(contract$aggregations),
      markdown_link(contract$documentation)
    )
  })
}

render_missingness_policy_rows <- function(policies) {
  policies <- policies[order(policies$policy), , drop = FALSE]

  lapply(seq_len(nrow(policies)), function(i) {
    policy <- policies[i, , drop = FALSE]
    c(
      markdown_code(policy$policy),
      markdown_link(policy$documentation)
    )
  })
}

render_artifact_rows <- function(artifacts) {
  artifacts <- artifacts[
    order(artifacts$profile, artifacts$operations, artifacts$artifact),
    ,
    drop = FALSE
  ]

  lapply(seq_len(nrow(artifacts)), function(i) {
    artifact <- artifacts[i, , drop = FALSE]
    c(
      markdown_code(artifact$profile),
      markdown_code(artifact$operations),
      markdown_code(artifact$artifact),
      markdown_code(artifact$kind),
      markdown_code(artifact$sidecar)
    )
  })
}

render_document <- function(catalog) {
  methods <- catalog_component(catalog, "methods")
  sources <- catalog_component(catalog, "sources")
  artifacts <- catalog_component(
    catalog,
    "artifacts",
    aliases = c("artifact_profiles")
  )
  missingness_policies <- catalog_component(
    catalog,
    "missingness_policies",
    aliases = c("missingness")
  )
  unit_contracts <- catalog_component(catalog, "unit_contracts")

  assert_columns(
    methods,
    "methods",
    c(
      "method", "source", "description", "status", "can_calculate",
      "can_recalculate", "validation_id", "documentation", "limitations"
    )
  )
  assert_columns(
    sources,
    "sources",
    c(
      "source", "status", "year_start", "year_end", "parameter_set",
      "data_dir", "can_prepare", "preparation_task", "validator_id",
      "artifact_profile", "missingness_policy",
      "unit_contract", "documentation", "limitations"
    )
  )
  assert_columns(
    artifacts,
    "artifacts",
    c("profile", "artifact", "kind", "sidecar", "operations")
  )
  assert_columns(
    missingness_policies,
    "missingness_policies",
    c("policy", "documentation")
  )
  assert_columns(
    unit_contracts,
    "unit_contracts",
    c(
      "contract", "schema_version", "source", "units", "aggregations",
      "documentation"
    )
  )

  method_table <- markdown_table(
    c(
      "Method", "Source", "Method status", "Source status", "Coverage",
      "Prepare", "Calculate", "Recalculate", "Description", "Validation ID",
      "Documentation", "Known limitations"
    ),
    render_method_rows(methods, sources)
  )
  source_table <- markdown_table(
    c(
      "Source", "Status", "Coverage", "Parameter set", "Data directory",
      "Prepare", "Preparation task", "Validator ID", "Artifact profile",
      "Missingness policy", "Unit contract", "Documentation", "Known limitations"
    ),
    render_source_rows(sources)
  )
  missingness_policy_table <- markdown_table(
    c("Policy", "Documentation"),
    render_missingness_policy_rows(missingness_policies)
  )
  unit_contract_table <- markdown_table(
    c(
      "Contract", "Schema", "Source", "Unit definitions", "Aggregations",
      "Documentation"
    ),
    render_unit_contract_rows(unit_contracts)
  )
  artifact_table <- markdown_table(
    c("Profile", "Operations", "Artifact", "Kind", "Required sidecar"),
    render_artifact_rows(artifacts)
  )

  c(
    "# Method and source support",
    "",
    "<!-- Generated by scripts/render_method_catalog.R; do not edit manually. -->",
    "",
    "This matrix is generated from the canonical, machine-readable registries in",
    "[`catalog/methods.csv`](../catalog/methods.csv),",
    "[`catalog/sources.csv`](../catalog/sources.csv),",
    "[`catalog/artifact-profiles.csv`](../catalog/artifact-profiles.csv),",
    "[`catalog/missingness-policies.csv`](../catalog/missingness-policies.csv), and",
    "[`catalog/unit-contracts.csv`](../catalog/unit-contracts.csv).",
    "Regenerate it with `Rscript --vanilla scripts/render_method_catalog.R` and",
    "verify synchronization with `Rscript --vanilla scripts/render_method_catalog.R --check`.",
    "",
    "## Status semantics",
    "",
    "- `stable`: the declared operations are supported by recovered preparation, registered validation, and documentation.",
    "- `experimental`: the method or source is available for development and evaluation, but requires explicit opt-in with `--allow-experimental` and is not yet a supported scientific release.",
    "- `disabled`: execution is blocked, including with experimental opt-in, until the listed recovery work is complete.",
    "",
    "A method and its source have independent statuses. For example, a source may remain experimental while methods that depend on its incomplete lifecycle are disabled. Capabilities are also explicit: repository contents alone do not imply that preparation, calculation, or recalculation is supported.",
    "",
    "## Methods",
    "",
    "Preparation is a source capability and is repeated here for convenience.",
    "",
    method_table,
    "",
    "## Sources",
    "",
    source_table,
    "",
    "## Missingness policies",
    "",
    "Sources reference versioned policy identifiers; catalog loading validates those declarations against the native registry.",
    "",
    missingness_policy_table,
    "",
    "## Unit contracts",
    "",
    "Stable sources select versioned unit and aggregation declarations; catalog loading validates exact indicator coverage and calculations execute the selected contract.",
    "",
    unit_contract_table,
    "",
    "## Expected artifact profiles",
    "",
    "Artifact profiles describe the files required for the operations declared by each source.",
    "",
    artifact_table
  )
}

raw_args <- commandArgs(trailingOnly = TRUE)
args <- parse_args(raw_args)
if (args$help) {
  usage()
  quit(save = "no", status = 0L)
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (!length(script_arg)) {
  stop("Run this file with Rscript.", call. = FALSE)
}

script_path <- normalizePath(
  sub("^--file=", "", script_arg[[1L]]),
  winslash = "/",
  mustWork = TRUE
)
project_root <- normalizePath(
  file.path(dirname(script_path), ".."),
  winslash = "/",
  mustWork = TRUE
)

Sys.setenv(RENV_PROJECT = project_root)
source(file.path(project_root, "renv", "activate.R"), local = TRUE)

bootstrap_environment <- new.env(parent = baseenv())
sys.source(
  file.path(project_root, "scripts", "runtime_bootstrap.R"),
  envir = bootstrap_environment,
  chdir = FALSE
)
runtime <- bootstrap_environment$wlv_load_runtime(project_root)
catalog <- runtime$wlv_load_catalog(project_root)
document <- render_document(catalog)
output_path <- file.path(project_root, "docs", "methods.md")

if (args$check) {
  if (!file.exists(output_path)) {
    stop(
      "docs/methods.md is missing; run scripts/render_method_catalog.R.",
      call. = FALSE
    )
  }

  existing <- readLines(output_path, warn = FALSE, encoding = "UTF-8")
  if (!identical(existing, document)) {
    stop(
      paste(
        "docs/methods.md is out of date; regenerate it with",
        "Rscript --vanilla scripts/render_method_catalog.R."
      ),
      call. = FALSE
    )
  }

  cat("docs/methods.md is synchronized with the method catalog.\n")
  quit(save = "no", status = 0L)
}

dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
writeLines(document, output_path, useBytes = TRUE)
cat(sprintf("Wrote %s.\n", output_path))
