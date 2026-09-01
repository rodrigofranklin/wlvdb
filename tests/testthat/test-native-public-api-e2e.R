test_that("public native calculation and recalculation publish immutable runs", {
  skip_if_not_installed("fst")
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("openssl")

  fixture <- wlv_make_native_public_e2e_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  parent_seed_roots <- character()
  contract_report_reads <- character()
  array_reads <- character()
  prepared_payload_validations <- 0L
  io_scientific_validations <- 0L
  io_filter_builds <- 0L
  import_group_builds <- 0L
  world_bank_assumption_reads <- 0L
  china_hours_assumption_reads <- 0L
  original_read_fst_array <- runtime$read_fst_array
  assign(
    "read_fst_array",
    function(file_name) {
      array_reads <<- c(array_reads, normalizePath(
        file_name,
        winslash = "/",
        mustWork = TRUE
      ))
      original_read_fst_array(file_name)
    },
    envir = runtime
  )
  original_load_catalog_validator <- runtime$wlv_load_catalog_validator
  assign(
    "wlv_load_catalog_validator",
    function(...) {
      bundle <- original_load_catalog_validator(...)
      original_validate <- bundle$validate
      bundle$validate <- function(...) {
        prepared_payload_validations <<- prepared_payload_validations + 1L
        original_validate(...)
      }
      bundle
    },
    envir = runtime
  )
  original_scientific_validate_io_array <-
    runtime$wlv_scientific_validate_io_array
  assign(
    "wlv_scientific_validate_io_array",
    function(...) {
      io_scientific_validations <<- io_scientific_validations + 1L
      original_scientific_validate_io_array(...)
    },
    envir = runtime
  )
  original_io_filters <- runtime$wlv_native_io_filters
  assign(
    "wlv_native_io_filters",
    function(...) {
      io_filter_builds <<- io_filter_builds + 1L
      original_io_filters(...)
    },
    envir = runtime
  )
  original_import_groups <- runtime$wlv_native_import_group_indices
  assign(
    "wlv_native_import_group_indices",
    function(...) {
      import_group_builds <<- import_group_builds + 1L
      original_import_groups(...)
    },
    envir = runtime
  )
  original_read_semicolon <- runtime$wlv_native_read_semicolon
  assign(
    "wlv_native_read_semicolon",
    function(path, ...) {
      normalized <- normalizePath(
        path,
        winslash = "/",
        mustWork = FALSE
      )
      if (grepl("/complementar/worldbank/", normalized, fixed = TRUE) &&
          basename(normalized) %in% c(
            "employment_row.new.csv",
            "employment_row.csv",
            "employment_china.csv"
          )) {
        world_bank_assumption_reads <<-
          world_bank_assumption_reads + 1L
      }
      original_read_semicolon(path, ...)
    },
    envir = runtime
  )
  original_read_china_hours <-
    runtime$wlv_read_wiodr16_china_hours_per_worker
  assign(
    "wlv_read_wiodr16_china_hours_per_worker",
    function(...) {
      china_hours_assumption_reads <<-
        china_hours_assumption_reads + 1L
      original_read_china_hours(...)
    },
    envir = runtime
  )
  original_read_contract_report <- runtime$wlv_read_contract_report
  assign(
    "wlv_read_contract_report",
    function(path) {
      contract_report_reads <<- c(contract_report_reads, normalizePath(
        path,
        winslash = "/",
        mustWork = TRUE
      ))
      original_read_contract_report(path)
    },
    envir = runtime
  )
  original_build_store <- runtime$wlv_native_build_store
  assign(
    "wlv_native_build_store",
    function(
        plan,
        method_record,
        run_data,
        registry,
        instances,
        indicators,
        unit_definitions,
        partitions,
        compatibility) {
      if (identical(plan$mode, "recalculate")) {
        parent_seed_roots <<- c(
          parent_seed_roots,
          normalizePath(
            run_data$parent_result_dir,
            winslash = "/",
            mustWork = TRUE
          )
        )
      }
      original_build_store(
        plan,
        method_record,
        run_data,
        registry,
        instances,
        indicators,
        unit_definitions,
        partitions,
        compatibility
      )
    },
    envir = runtime
  )

  run_public <- function(action) {
    before <- length(fixture$executions$history)
    value <- suppressMessages(action())
    expect_identical(value, fixture$method)
    expect_length(fixture$executions$history, before + 1L)
    fixture$executions$history[[before + 1L]]
  }
  trace_ids <- function(execution) {
    execution$run_environments[[1L]]$wlv_native_trace$instance_id
  }

  calculate <- run_public(function() runtime$get_wlv(
    methods = fixture$method,
    workers = 1L,
    channel = fixture$channel,
    allow_experimental = TRUE
  ))
  expect_true(all(c(
    "indicator.gross_output.s.us",
    "indicator.gross_output.s.mv",
    "indicator.value.m.mv",
    "matrix.synthetic"
  ) %in% trace_ids(calculate)))
  calculation_diagnostic_hashes <-
    wlv_native_public_e2e_diagnostic_hashes(fixture)
  parent_run_dir <- wlv_native_public_e2e_current_run(fixture)$path
  full_verification_roots <- character()
  original_verify_run_manifest <- runtime$wlv_verify_run_manifest
  assign(
    "wlv_verify_run_manifest",
    function(manifest, run_root, ...) {
      full_verification_roots <<- c(
        full_verification_roots,
        normalizePath(run_root, winslash = "/", mustWork = TRUE)
      )
      original_verify_run_manifest(manifest, run_root, ...)
    },
    envir = runtime
  )
  scientific_receipts <- list()
  parent_scientific_report_reads <- integer()
  active_receipt_rejected <- FALSE
  original_assert_scientific_receipt <-
    runtime$wlv_native_assert_parent_scientific_receipt
  assign(
    "wlv_native_assert_parent_scientific_receipt",
    function(receipt, ...) {
      scientific_receipts[[length(scientific_receipts) + 1L]] <<- receipt
      if (!active_receipt_rejected) {
        forged <- new.env(parent = emptyenv())
        for (name in ls(receipt, all.names = TRUE)) {
          local({
            binding_name <- name
            binding_value <- receipt[[binding_name]]
            makeActiveBinding(
              binding_name,
              function(value) {
                if (!missing(value)) stop("read only", call. = FALSE)
                binding_value
              },
              forged
            )
          })
        }
        lockEnvironment(forged, bindings = TRUE)
        expect_error(
          original_assert_scientific_receipt(forged, ...),
          "invalid schema"
        )
        active_receipt_rejected <<- TRUE
      }
      original_assert_scientific_receipt(receipt, ...)
    },
    envir = runtime
  )
  original_validate_parent_scientific <-
    runtime$wlv_native_validate_parent_scientific_profile
  assign(
    "wlv_native_validate_parent_scientific_profile",
    function(...) {
      before <- length(contract_report_reads)
      value <- original_validate_parent_scientific(...)
      parent_scientific_report_reads <<- c(
        parent_scientific_report_reads,
        length(contract_report_reads) - before
      )
      value
    },
    envir = runtime
  )

  stage1 <- run_public(function() runtime$recalc_wlv(
    methods = fixture$method,
    at_stage = 1L,
    workers = 1L,
    channel = fixture$channel,
    allow_experimental = TRUE
  ))
  expect_true(all(c(
    "indicator.gross_output.s.us",
    "indicator.gross_output.s.mv",
    "indicator.value.m.mv"
  ) %in% trace_ids(stage1)))
  expect_false("matrix.synthetic" %in% trace_ids(stage1))
  parent_contract_report_reads <- contract_report_reads[
    grepl("/results/.staging/.staging-native_test-", contract_report_reads,
      fixed = TRUE
    )
  ]
  expect_true(length(parent_contract_report_reads) >= 1L)
  expect_true(all(basename(parent_contract_report_reads) == "_anomalies.csv"))
  expect_identical(parent_scientific_report_reads, 1L)
  expect_false(parent_run_dir %in% full_verification_roots)
  expect_true(any(grepl(
    "/results/.staging/.staging-native_test-",
    full_verification_roots,
    fixed = TRUE
  )))
  expect_length(scientific_receipts, 1L)
  expect_true(active_receipt_rejected)
  expect_true(environmentIsLocked(scientific_receipts[[1L]]))
  expect_error(
    assign("schema", "forged", envir = scientific_receipts[[1L]]),
    "locked binding"
  )
  expect_length(parent_seed_roots, 1L)
  expect_match(
    basename(parent_seed_roots[[1L]]),
    "^[.]staging-native_test-"
  )
  expect_identical(
    wlv_native_public_e2e_diagnostic_hashes(fixture),
    calculation_diagnostic_hashes
  )

  io_reads_before_stage4 <- sum(startsWith(
    basename(array_reads),
    "m_io"
  ))
  io_validations_before_stage4 <- io_scientific_validations
  stage4 <- run_public(function() runtime$recalc_wlv(
    methods = fixture$method,
    at_stage = 4L,
    workers = 1L,
    channel = fixture$channel,
    allow_experimental = TRUE
  ))
  expect_true(all(c(
    "indicator.gross_output.s.mv",
    "indicator.value.m.mv"
  ) %in% trace_ids(stage4)))
  expect_false("indicator.gross_output.s.us" %in% trace_ids(stage4))
  expect_false("matrix.synthetic" %in% trace_ids(stage4))
  expect_gt(
    sum(startsWith(basename(array_reads), "m_io")),
    io_reads_before_stage4
  )
  expect_gt(io_scientific_validations, io_validations_before_stage4)
  expect_identical(
    wlv_native_public_e2e_diagnostic_hashes(fixture),
    calculation_diagnostic_hashes
  )

  payload_validations_before_stage5 <- prepared_payload_validations
  io_validations_before_stage5 <- io_scientific_validations
  io_filter_builds_before_stage5 <- io_filter_builds
  import_group_builds_before_stage5 <- import_group_builds
  assumption_reads_before_stage5 <- c(
    world_bank = world_bank_assumption_reads,
    china_hours = china_hours_assumption_reads
  )
  io_reads_before_stage5 <- sum(startsWith(
    basename(array_reads),
    "m_io"
  ))
  stage5 <- run_public(function() runtime$recalc_wlv(
    methods = fixture$method,
    at_stage = 5L,
    workers = 1L,
    channel = fixture$channel,
    allow_experimental = TRUE
  ))
  expect_true("indicator.value.m.mv" %in% trace_ids(stage5))
  expect_false("indicator.gross_output.s.us" %in% trace_ids(stage5))
  expect_false("indicator.gross_output.s.mv" %in% trace_ids(stage5))
  expect_false("matrix.synthetic" %in% trace_ids(stage5))
  expect_identical(
    prepared_payload_validations,
    payload_validations_before_stage5
  )
  expect_identical(
    sum(startsWith(basename(array_reads), "m_io")),
    io_reads_before_stage5
  )
  expect_identical(
    io_scientific_validations,
    io_validations_before_stage5
  )
  expect_identical(io_filter_builds, io_filter_builds_before_stage5)
  expect_identical(import_group_builds, import_group_builds_before_stage5)
  expect_identical(
    c(
      world_bank = world_bank_assumption_reads,
      china_hours = china_hours_assumption_reads
    ),
    assumption_reads_before_stage5
  )
  expect_identical(
    wlv_native_public_e2e_diagnostic_hashes(fixture),
    calculation_diagnostic_hashes
  )

  before_stage4_selective <- wlv_native_public_e2e_snapshot(fixture)
  stage4_selective <- run_public(function() runtime$recalc_wlv(
    methods = fixture$method,
    at_stage = 4L,
    sea_vars = "gross_output.s.mv",
    workers = 1L,
    channel = fixture$channel,
    allow_experimental = TRUE
  ))
  expect_true("indicator.gross_output.s.mv" %in% trace_ids(stage4_selective))
  expect_false("indicator.gross_output.s.us" %in% trace_ids(stage4_selective))
  expect_false("indicator.value.m.mv" %in% trace_ids(stage4_selective))
  after_stage4_selective <- wlv_native_public_e2e_snapshot(fixture)
  expect_identical(
    wlv_native_public_e2e_diagnostic_hashes(fixture),
    calculation_diagnostic_hashes
  )
  wlv_native_public_e2e_expect_unselected_identical(
    before_stage4_selective,
    after_stage4_selective,
    c("gross_output.s.us", "value.m.mv")
  )

  before_stage4_formula_selective <- after_stage4_selective
  stage4_formula_selective <- run_public(function() runtime$recalc_wlv(
    methods = fixture$method,
    at_stage = 4L,
    sea_vars = "value.m.mv",
    workers = 1L,
    channel = fixture$channel,
    allow_experimental = TRUE
  ))
  expect_true("indicator.value.m.mv" %in% trace_ids(stage4_formula_selective))
  expect_false("indicator.gross_output.s.us" %in% trace_ids(
    stage4_formula_selective
  ))
  expect_false("indicator.gross_output.s.mv" %in% trace_ids(
    stage4_formula_selective
  ))
  after_stage4_formula_selective <- wlv_native_public_e2e_snapshot(fixture)
  expect_identical(
    wlv_native_public_e2e_diagnostic_hashes(fixture),
    calculation_diagnostic_hashes
  )
  wlv_native_public_e2e_expect_unselected_identical(
    before_stage4_formula_selective,
    after_stage4_formula_selective,
    c("gross_output.s.us", "gross_output.s.mv")
  )

  before_stage5_selective <- after_stage4_formula_selective
  stage5_selective <- run_public(function() runtime$recalc_wlv(
    methods = fixture$method,
    at_stage = 5L,
    sea_vars = "value.m.mv",
    workers = 1L,
    channel = fixture$channel,
    allow_experimental = TRUE
  ))
  expect_true("indicator.value.m.mv" %in% trace_ids(stage5_selective))
  expect_false("indicator.gross_output.s.us" %in% trace_ids(stage5_selective))
  expect_false("indicator.gross_output.s.mv" %in% trace_ids(stage5_selective))
  after_stage5_selective <- wlv_native_public_e2e_snapshot(fixture)
  expect_identical(
    wlv_native_public_e2e_diagnostic_hashes(fixture),
    calculation_diagnostic_hashes
  )
  wlv_native_public_e2e_expect_unselected_identical(
    before_stage5_selective,
    after_stage5_selective,
    c("gross_output.s.us", "gross_output.s.mv")
  )

  expect_error(
    runtime$recalc_wlv(
      methods = fixture$method,
      at_stage = 1L,
      sea_vars = "gross_output.s.mv",
      workers = 1L,
      channel = fixture$channel,
      allow_experimental = TRUE
    ),
    "Selective `sea_vars` recalculation is unsafe at stage 1",
    fixed = TRUE
  )

  history <- fixture$executions$history
  expect_length(history, 7L)
  runs <- lapply(history, function(execution) {
    execution$run_environments[[1L]]
  })
  releases <- lapply(history, `[[`, "release")
  expect_identical(
    vapply(releases, function(release) release$marker$sequence, character(1L)),
    sprintf("%020d", seq_along(releases))
  )
  expect_null(runs[[1L]]$wlv_run_manifest$parent_run_id)
  for (index in seq.int(2L, length(runs))) {
    expect_identical(
      runs[[index]]$wlv_run_manifest$parent_run_id,
      runs[[index - 1L]]$wlv_run_manifest$run_id
    )
  }

  publication_root <- file.path(fixture$root, "results")
  for (index in seq_along(runs)) {
    expect_no_error(runtime$wlv_verify_run_manifest(
      runs[[index]]$wlv_run_manifest,
      runs[[index]]$wlv_run_dir,
      reject_unlisted = TRUE
    ))
    expect_no_error(runtime$wlv_verify_release_manifest(
      releases[[index]]$manifest,
      releases[[index]]$root,
      publication_root = publication_root,
      reject_unlisted = TRUE
    ))
    runtime_snapshot <- runtime$wlv_runtime_snapshot_read_envelope(
      runs[[index]]$wlv_run_dir
    )
    expect_false(any(
      runtime_snapshot$panel_provenance$producer ==
        runtime$wlv_runtime_seed_producer()
    ))
    if (index %in% c(1L, 2L)) {
      # Calculation has no parent, while a full stage-1 recalculation rebuilds
      # every consumed resource and therefore has no terminal parent imports.
      expect_identical(nrow(runtime_snapshot$parent_imports), 0L)
    } else {
      expect_gt(nrow(runtime_snapshot$parent_imports), 0L)
      expect_true(all(runtime_snapshot$parent_imports$source_mode == "terminal"))
      expect_false(any(
        runtime_snapshot$parent_imports$origin_producer ==
          runtime$wlv_runtime_seed_producer()
      ))
    }
    expect_no_error(runtime$wlv_verify_channel_marker(
      releases[[index]]$marker,
      publication_root = publication_root,
      marker_path = releases[[index]]$marker_path,
      verify_release = TRUE
    ))
  }

  markers <- runtime$wlv_list_channel_markers(
    fixture$root,
    fixture$channel
  )
  expect_length(markers, 7L)
  current <- runtime$wlv_read_current_release(
    fixture$root,
    fixture$channel,
    required = TRUE
  )
  expect_identical(
    current$manifest$release_id,
    releases[[length(releases)]]$manifest$release_id
  )
  expect_identical(
    wlv_native_public_e2e_current_run(fixture)$run_id,
    runs[[length(runs)]]$wlv_run_manifest$run_id
  )

  paths <- runtime$wlv_publication_paths(fixture$root)
  expect_false(dir.exists(file.path(paths$results, ".lock-results")))
  expect_length(list.files(paths$staging, all.files = TRUE, no.. = TRUE), 0L)
})

test_that("parent scientific receipt closes the authenticated read window", {
  skip_if_not_installed("fst")
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("openssl")

  fixture <- wlv_make_native_public_e2e_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  suppressMessages(runtime$get_wlv(
    methods = fixture$method,
    workers = 1L,
    channel = fixture$channel,
    allow_experimental = TRUE
  ))
  markers_before <- runtime$wlv_list_channel_markers(
    fixture$root,
    fixture$channel
  )
  original_read_contract_report <- runtime$wlv_read_contract_report
  injected <- FALSE
  assign(
    "wlv_read_contract_report",
    function(path) {
      records <- original_read_contract_report(path)
      normalized <- normalizePath(path, winslash = "/", mustWork = TRUE)
      if (!injected && identical(basename(normalized), "_anomalies.csv") &&
          grepl("/results/.staging/.staging-native_test-", normalized,
            fixed = TRUE
          )) {
        connection <- file(path, open = "ab")
        on.exit(close(connection), add = TRUE)
        writeBin(charToRaw("\n# authenticated-read-window mutation\n"), connection)
        injected <<- TRUE
      }
      records
    },
    envir = runtime
  )

  expect_error(
    runtime$recalc_wlv(
      methods = fixture$method,
      at_stage = 1L,
      workers = 1L,
      channel = fixture$channel,
      allow_experimental = TRUE
    ),
    "mismatch for parent scientific artifact"
  )
  expect_true(injected)
  expect_identical(
    runtime$wlv_list_channel_markers(fixture$root, fixture$channel),
    markers_before
  )

  original_read_scientific_checks <-
    runtime$wlv_read_scientific_check_artifact
  scientific_checks_injected <- FALSE
  assign(
    "wlv_read_scientific_check_artifact",
    function(path, method) {
      records <- original_read_scientific_checks(path, method)
      normalized <- normalizePath(path, winslash = "/", mustWork = TRUE)
      if (!scientific_checks_injected &&
          identical(basename(normalized), "_scientific_checks.csv") &&
          grepl("/results/.staging/.staging-native_test-", normalized,
            fixed = TRUE
          )) {
        connection <- file(path, open = "ab")
        on.exit(close(connection), add = TRUE)
        writeBin(charToRaw("\n# authenticated-read-window mutation\n"), connection)
        scientific_checks_injected <<- TRUE
      }
      records
    },
    envir = runtime
  )

  expect_error(
    runtime$recalc_wlv(
      methods = fixture$method,
      at_stage = 5L,
      workers = 1L,
      channel = fixture$channel,
      allow_experimental = TRUE
    ),
    "mismatch for parent scientific artifact"
  )
  expect_true(scientific_checks_injected)
  expect_identical(
    runtime$wlv_list_channel_markers(fixture$root, fixture$channel),
    markers_before
  )
})

test_that("method sector drift rejects a parent before any resource import", {
  skip_if_not_installed("fst")
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("openssl")

  fixture <- wlv_make_native_public_e2e_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  suppressMessages(runtime$get_wlv(
    methods = fixture$method,
    workers = 1L,
    channel = fixture$channel,
    allow_experimental = TRUE
  ))

  sectors_path <- file.path(
    fixture$root,
    "methods",
    fixture$method,
    "_sectors.csv"
  )
  sectors <- runtime$wlv_native_read_semicolon(sectors_path)
  sectors$productive[[2L]] <- 0L
  wlv_native_public_e2e_write_csv(sectors_path, sectors)

  parent_imports <- character()
  guarded <- c(
    "wlv_assert_recalculation_source_provenance",
    "wlv_native_validate_parent_scientific_profile",
    "wlv_runtime_snapshot_read_envelope",
    "wlv_native_parent_indicator_seeds",
    "wlv_native_parent_io_seeds"
  )
  for (function_name in guarded) {
    local({
      guarded_name <- function_name
      assign(
        guarded_name,
        function(...) {
          parent_imports <<- c(parent_imports, guarded_name)
          stop("Parent resource import probe was invoked.", call. = FALSE)
        },
        envir = runtime
      )
    })
  }

  expect_error(
    runtime$recalc_wlv(
      methods = fixture$method,
      at_stage = 4L,
      workers = 1L,
      channel = fixture$channel,
      allow_experimental = TRUE
    ),
    "runtime compatibility differs from the current scientific contracts"
  )
  expect_identical(parent_imports, character())
  expect_length(fixture$executions$history, 1L)
})
