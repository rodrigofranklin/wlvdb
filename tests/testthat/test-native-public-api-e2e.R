test_that("public native calculation and recalculation publish immutable runs", {
  skip_if_not_installed("fst")
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("openssl")

  fixture <- wlv_make_native_public_e2e_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  parent_seed_roots <- character()
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
  expect_length(parent_seed_roots, 1L)
  expect_match(
    basename(parent_seed_roots[[1L]]),
    "^[.]staging-native_test-"
  )
  expect_identical(
    wlv_native_public_e2e_diagnostic_hashes(fixture),
    calculation_diagnostic_hashes
  )

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
  expect_identical(
    wlv_native_public_e2e_diagnostic_hashes(fixture),
    calculation_diagnostic_hashes
  )

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
