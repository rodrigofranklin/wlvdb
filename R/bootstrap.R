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
  declarative_calls <- base::c(
    ":", "as.character", "as.integer", "c", "list", "paste0", "sprintf",
    "wlv_matrix_basket_spec", "wlv_matrix_zero_depreciation_spec",
    "wlv_module_parameter", "wlv_module_spec",
    "wlv_native_abstract_labour_spec", "wlv_native_array_contract",
    "wlv_native_artifact_output", "wlv_native_assumption_table_ref",
    "wlv_native_appropriated_profit_spec",
    "wlv_native_capital_spec", "wlv_native_complex_multiplier_spec",
    "wlv_native_constant_compensation_spec", "wlv_native_current_usd_spec",
    "wlv_native_direct_price_spec", "wlv_native_exchange_index_spec",
    "wlv_native_exchange_us_spec", "wlv_native_filters_contract",
    "wlv_native_indicator_metadata_row", "wlv_native_indicator_output",
    "wlv_native_indicator_ref", "wlv_native_indicator_spec",
    "wlv_native_intermediate_contract", "wlv_native_intermediate_output",
    "wlv_native_intermediate_ref", "wlv_native_io_contract",
    "wlv_native_io_output", "wlv_native_io_ref", "wlv_native_ochoa_1_spec",
    "wlv_native_ochoa_2_spec", "wlv_native_parameters_output",
    "wlv_native_parameters_ref", "wlv_native_petrovic_requirements",
    "wlv_native_productive_surplus_spec", "wlv_native_reduction_metadata",
    "wlv_native_reduction_ones_spec", "wlv_native_reduction_output",
    "wlv_native_reduction_skill_outputs", "wlv_native_reduction_skill_refs",
    "wlv_native_replace_indicator", "wlv_native_run_ref",
    "wlv_native_skill_surplus_spec", "wlv_native_source_io_ref",
    "wlv_native_source_requirements", "wlv_native_source_sea_contract",
    "wlv_native_stage4_import_spec", "wlv_native_stage4_labour_force_spec",
    "wlv_native_stage4_matrix_requirements", "wlv_native_stage4_rowsum_spec",
    "wlv_native_stage4_trade_transfer_spec", "wlv_native_stage5_ratio_spec",
    "wlv_native_stage5_sum_spec", "wlv_native_wiodr16_capital_spec",
    "wlv_reduced_direct_price_spec", "wlv_reduced_matrix_spec",
    "wlv_resource_ref"
  )
  declarative_rhs <- function(value) {
    if (base::is.null(value) || base::is.atomic(value) || base::is.symbol(value)) {
      return(TRUE)
    }
    if (!base::is.call(value) || !base::length(value) ||
        !base::is.symbol(value[[1L]])) {
      return(FALSE)
    }
    head <- base::as.character(value[[1L]])
    if (base::identical(head, "function")) {
      return(TRUE)
    }
    if (!head %in% declarative_calls) {
      return(FALSE)
    }
    arguments <- base::as.list(value)[-1L]
    !base::length(arguments) || base::all(base::vapply(
      arguments,
      declarative_rhs,
      logical(1L)
    ))
  }
  definitions <- base::vapply(expressions, function(expression) {
    base::is.call(expression) && base::length(expression) == 3L &&
      base::is.symbol(expression[[1L]]) &&
      base::identical(base::as.character(expression[[1L]]), "<-") &&
      base::is.symbol(expression[[2L]]) &&
      declarative_rhs(expression[[3L]])
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
  inventory <- wlv_bootstrap_definition_inventory(
    inventory_paths,
    inventory_relative
  )
  if (!base::identical(
    inventory,
    wlv_bootstrap_definition_inventory(inventory_paths, inventory_relative)
  )) {
    base::stop(
      "Runtime definitions changed while their bootstrap inventory was captured.",
      call. = FALSE
    )
  }

  # Parse every definition before evaluating any of them. A syntax or encoding
  # failure therefore cannot expose a partially initialized namespace.
  definition_origins <- character()
  for (index in base::seq_along(files)) {
    expressions <- base::tryCatch(
      base::parse(file = files[[index]], encoding = "UTF-8"),
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
  }

  namespace <- base::new.env(parent = base::baseenv())
  base::assign(".wlv_runtime_root", root, envir = namespace)
  base::assign(".wlv_runtime_files", files, envir = namespace)
  working_directory <- base::getwd()
  search_path <- base::search()

  for (index in base::seq_along(files)) {
    base::tryCatch(
      base::sys.source(
        files[[index]],
        envir = namespace,
        chdir = FALSE,
        keep.source = FALSE
      ),
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
  if (!base::identical(inventory, current_inventory) ||
      !base::identical(
        current_inventory,
        wlv_bootstrap_definition_inventory(inventory_paths, inventory_relative)
      )) {
    base::stop(
      "Runtime definitions changed while the private namespace was loading.",
      call. = FALSE
    )
  }
  base::assign(
    ".wlv_runtime_definition_paths",
    stats::setNames(inventory_paths, inventory_relative),
    envir = namespace
  )
  base::assign(
    ".wlv_runtime_definition_md5",
    inventory,
    envir = namespace
  )
  bindings <- base::ls(namespace, all.names = TRUE)
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
