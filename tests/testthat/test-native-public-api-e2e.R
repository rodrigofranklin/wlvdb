test_that("public native calculation and recalculation publish immutable runs", {
  skip_if_not_installed("fst")
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("openssl")

  fixture <- wlv_make_native_public_e2e_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime

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
