test_that("repeated native runs retain immutable generations and result identity", {
  fixture <- wlv_make_native_publication_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  plan <- wlv_native_test_release_plan(fixture)

  first <- wlv_native_test_run_environment(fixture, "run-native-001")
  first_release <- runtime$wlv_commit_release(plan, list(first))
  first_run <- runtime$wlv_resolve_current_method_run(
    fixture$root,
    fixture$method,
    channel = "stable"
  )
  second <- wlv_native_test_run_environment(fixture, "run-native-002")
  second_release <- runtime$wlv_commit_release(plan, list(second))
  second_run <- runtime$wlv_resolve_current_method_run(
    fixture$root,
    fixture$method,
    channel = "stable"
  )

  expect_false(identical(first_run$run_id, second_run$run_id))
  expect_identical(first_run$result_id, second_run$result_id)
  expect_true(dir.exists(first_run$path))
  expect_true(dir.exists(second_run$path))
  expect_identical(first_release$marker$sequence, "00000000000000000001")
  expect_identical(second_release$marker$sequence, "00000000000000000002")
  expect_length(runtime$wlv_list_channel_markers(fixture$root, "stable"), 2L)

  duplicate <- file.path(
    dirname(second_release$marker_path),
    paste0(second_release$marker$sequence, "-release-duplicate.json")
  )
  expect_true(file.copy(second_release$marker_path, duplicate))
  expect_error(
    runtime$wlv_read_current_release(fixture$root, "stable"),
    "more than one marker at sequence"
  )
})

test_that("publication warnings are UTF-8, single-line, and redacted", {
  fixture <- wlv_make_native_publication_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  accented <- "Aviso nativo com acentuação"
  raw_warning <- paste0(
    accented, "\nprojeto: ", fixture$root,
    "\thome: ", path.expand("~"),
    "; temp: ", tempdir(),
    "; outros: C:\\dados\\privado.csv e /srv/privado.csv",
    "; espaços: C:\\Dados Sensíveis\\cliente.csv, ",
    "/srv/dados privados/cliente.csv",
    "; URL: https://user:pass@example.test/path?token=secret-value#fragment",
    "; token=top-secret; Authorization: Bearer credential-value"
  )
  run <- wlv_native_test_run_environment(
    fixture,
    "run-warning",
    warnings = raw_warning
  )
  manifest <- runtime$wlv_read_run_manifest(file.path(
    run$wlv_run_dir,
    runtime$wlv_run_manifest_filename()
  ))
  warning <- manifest$execution$warnings[[1L]]

  expect_identical(iconv(warning, "UTF-8", "UTF-8", sub = NA), warning)
  expect_false(grepl("[\r\n\t]", warning))
  expect_false(grepl(fixture$root, warning, fixed = TRUE))
  expect_false(grepl(path.expand("~"), warning, fixed = TRUE))
  expect_false(grepl(tempdir(), warning, fixed = TRUE))
  expect_false(grepl("[A-Za-z]:[/\\\\]", warning))
  expect_false(grepl("secret-value|user:pass|top-secret|credential-value", warning))
  expect_true(grepl("<url>", warning, fixed = TRUE))
  expect_true(grepl(accented, warning, fixed = TRUE))

  bytes <- readBin(
    file.path(run$wlv_run_dir, runtime$wlv_run_manifest_filename()),
    what = "raw",
    n = file.info(file.path(
      run$wlv_run_dir,
      runtime$wlv_run_manifest_filename()
    ))$size
  )
  expect_true(grepl(
    enc2utf8(accented),
    rawToChar(bytes),
    fixed = TRUE,
    useBytes = TRUE
  ))
})

test_that("additional source inputs are inventoried by relative path", {
  fixture <- wlv_make_native_publication_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  paths <- file.path(
    fixture$root,
    "source_data",
    "native_test",
    c("countries.csv", "demand.csv")
  )
  wlv_native_test_write_text(paths[[1L]], "country;name\nAAA;A\n")
  wlv_native_test_write_text(paths[[2L]], "demand\nCONS\n")

  inventory <- fixture$runtime$wlv_publication_source_input_inventory(
    fixture$root,
    rev(paths)
  )
  expect_identical(
    vapply(inventory, `[[`, character(1L), "path"),
    c(
      "source_data/native_test/countries.csv",
      "source_data/native_test/demand.csv"
    )
  )
  expect_true(all(vapply(inventory, function(record) {
    is.numeric(record$size_bytes) && record$size_bytes > 0 &&
      grepl("^[0-9a-f]{64}$", record$sha256)
  }, logical(1L))))
})

test_that("release source rechecks deduplicate identical generation snapshots", {
  fixture <- wlv_make_native_publication_fixture(mutable = TRUE)
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  methods <- c("native_a", "native_b")
  plan <- structure(
    list(methods = data.frame(
      method = methods,
      source = "native_source",
      stringsAsFactors = FALSE
    )),
    class = c("wlv_run_plan", "list")
  )
  provenance <- data.frame(
    source = "native_source",
    source_generation_id = "generation-1",
    contract_sha256 = strrep("1", 64L),
    manifest_sha256 = strrep("2", 64L),
    stringsAsFactors = FALSE
  )
  inventory <- list(list(
    path = "source_data/native/input.csv",
    sha256 = strrep("3", 64L)
  ))
  runs <- lapply(methods, function(method) {
    run <- new.env(parent = emptyenv())
    run$wlv_run_manifest <- list(method = method)
    run$wlv_source_provenance <- provenance
    run$wlv_source_provenance_inputs <- "input.csv"
    run$wlv_source_provenance_input_inventory <- inventory
    run
  })
  checked <- character()
  runtime$wlv_assert_method_source_inputs_unchanged <- function(
      plan,
      method,
      run_data) {
    checked <<- c(checked, method$method[[1L]])
    invisible(TRUE)
  }

  expect_no_error(runtime$wlv_assert_run_environments_source_inputs_unchanged(
    plan,
    runs
  ))
  expect_length(checked, 1L)
  runs[[2L]]$wlv_source_provenance$manifest_sha256 <- strrep("4", 64L)
  checked <- character()
  expect_no_error(runtime$wlv_assert_run_environments_source_inputs_unchanged(
    plan,
    runs
  ))
  expect_setequal(checked, methods)
})

test_that("git provenance fails closed and hashes deterministic status", {
  fixture <- wlv_make_native_publication_fixture(mutable = TRUE)
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  dir.create(file.path(fixture$root, ".git"))

  runtime$Sys.which <- function(command) stats::setNames("", command)
  expect_error(
    runtime$wlv_git_publication_provenance(fixture$root, list()),
    "Git is required to record provenance for a detected repository",
    fixed = TRUE
  )
  rm("Sys.which", envir = runtime)
  runtime$system2 <- function(...) structure(character(), status = 128L)
  expect_error(
    runtime$wlv_git_publication_provenance(fixture$root, list()),
    "Git failed while attempting to read the publication commit",
    fixed = TRUE
  )

  call_count <- 0L
  arguments <- list()
  runtime$system2 <- function(command, args, ...) {
    call_count <<- call_count + 1L
    arguments[[call_count]] <<- args
    if (identical(call_count, 1L)) return(strrep("a", 40L))
    c("?? R/z-new.R", " M R/a-existing.R")
  }
  inventory <- list(list(
    path = "contracts/results/run-manifest-v1.schema.json",
    sha256 = strrep("0", 64L)
  ))
  provenance <- runtime$wlv_git_publication_provenance(
    fixture$root,
    inventory
  )
  expected <- paste(
    sort(c("?? R/z-new.R", " M R/a-existing.R"), method = "radix"),
    collapse = "\n"
  )
  expect_true(provenance$dirty)
  expect_identical(
    provenance$status_sha256,
    runtime$wlv_source_sha256_raw(charToRaw(enc2utf8(expected)))
  )
  expect_true(any(grepl("contracts/results", arguments[[2L]], fixed = TRUE)))
})

test_that("the publication input tree includes every native configuration class", {
  fixture <- wlv_make_native_publication_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  roots <- c(
    "R", "catalog", "config", "complementar", "contracts/results",
    "contracts/units",
    "methods/native_test", "parameters/native_test",
    "parameters/common_ground", "scripts"
  )
  for (path in roots) {
    wlv_native_test_write_text(
      file.path(fixture$root, path, "input.txt"),
      paste("native", path)
    )
  }
  wlv_native_test_write_text(
    file.path(fixture$root, "R", "native_definition.R"),
    "native_definition <- function() TRUE"
  )
  for (path in c("DESCRIPTION", "renv.lock", "scripts/run_wlv.R")) {
    wlv_native_test_write_text(file.path(fixture$root, path), path)
  }
  plan <- list(
    root = fixture$root,
    method_names = fixture$method,
    methods = data.frame(
      method = fixture$method,
      method_dir = file.path(fixture$root, "methods", fixture$method),
      parameter_set = fixture$method,
      stringsAsFactors = FALSE
    )
  )
  inventory <- fixture$runtime$wlv_publication_input_inventory(
    plan,
    fixture$method
  )
  relative <- vapply(inventory, `[[`, character(1L), "path")

  expect_true(any(startsWith(relative, "R/")))
  expect_true(any(startsWith(relative, "catalog/")))
  expect_true(any(startsWith(relative, "config/")))
  expect_true(any(startsWith(relative, "complementar/")))
  expect_true(any(startsWith(relative, "contracts/results/")))
  expect_true(any(startsWith(relative, "contracts/units/")))
  expect_true(any(startsWith(relative, "methods/native_test/")))
  expect_true(any(startsWith(relative, "parameters/native_test/")))
  expect_true(any(startsWith(relative, "parameters/common_ground/")))

  before <- vapply(inventory, `[[`, character(1L), "sha256")
  wlv_native_test_write_text(
    file.path(fixture$root, "config", "input.txt"),
    "changed native configuration"
  )
  after <- vapply(
    fixture$runtime$wlv_publication_input_inventory(plan, fixture$method),
    `[[`,
    character(1L),
    "sha256"
  )
  expect_false(identical(before, after))

  plan$publication_inputs <- stats::setNames(list(inventory), fixture$method)
  expect_error(
    fixture$runtime$wlv_assert_plan_publication_inputs_unchanged(plan),
    "inputs changed after preflight validation",
    fixed = TRUE
  )
})

test_that("an experimental channel cannot change the stable release", {
  fixture <- wlv_make_native_publication_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  stable_run <- wlv_native_test_run_environment(fixture, "run-stable")
  runtime$wlv_commit_release(
    wlv_native_test_release_plan(fixture, channel = "stable"),
    list(stable_run)
  )
  stable_before <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )

  experimental_run <- wlv_native_test_run_environment(
    fixture,
    "run-experimental",
    payload = "experimental"
  )
  runtime$wlv_commit_release(
    wlv_native_test_release_plan(fixture, channel = "experimental/test"),
    list(experimental_run)
  )
  stable_after <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )
  experimental <- runtime$wlv_read_current_release(
    fixture$root,
    "experimental/test",
    required = TRUE
  )

  expect_identical(
    stable_after$manifest$release_id,
    stable_before$manifest$release_id
  )
  expect_false(identical(
    experimental$manifest$release_id,
    stable_before$manifest$release_id
  ))
})

test_that("marker installation failure leaves the previous release current", {
  fixture <- wlv_make_native_publication_fixture(mutable = TRUE)
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  plan <- wlv_native_test_release_plan(fixture)
  first <- wlv_native_test_run_environment(fixture, "run-marker-001")
  runtime$wlv_commit_release(plan, list(first))
  current_before <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )
  markers_before <- runtime$wlv_list_channel_markers(fixture$root, "stable")

  channel_dir <- runtime$wlv_publication_channel_directory(
    fixture$root,
    "stable",
    create = TRUE
  )
  base_rename <- base::file.rename
  runtime$file.rename <- function(from, to) {
    target <- normalizePath(dirname(to), winslash = "/", mustWork = FALSE)
    if (identical(tolower(target), tolower(channel_dir)) &&
        grepl("^[0-9]{20}-release-.*[.]json$", basename(to))) {
      return(FALSE)
    }
    base_rename(from, to)
  }
  second <- wlv_native_test_run_environment(fixture, "run-marker-002")

  expect_error(
    runtime$wlv_commit_release(plan, list(second)),
    "Could not atomically install channel marker",
    fixed = TRUE
  )
  rm("file.rename", envir = runtime)
  current_after <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )
  expect_identical(
    current_after$manifest$release_id,
    current_before$manifest$release_id
  )
  expect_identical(
    runtime$wlv_list_channel_markers(fixture$root, "stable"),
    markers_before
  )
})

test_that("installed release verification blocks post-staging run corruption", {
  fixture <- wlv_make_native_publication_fixture(mutable = TRUE)
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  plan <- wlv_native_test_release_plan(fixture)
  first <- wlv_native_test_run_environment(fixture, "run-verified-001")
  runtime$wlv_commit_release(plan, list(first))
  current_before <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )
  markers_before <- runtime$wlv_list_channel_markers(fixture$root, "stable")
  marker_bytes_before <- readBin(
    current_before$marker_path,
    what = "raw",
    n = file.info(current_before$marker_path)$size
  )

  second <- wlv_native_test_run_environment(fixture, "run-verified-002")
  payload <- file.path(second$wlv_run_dir, "payload.txt")
  original_verify_release <- runtime$wlv_verify_release_manifest
  verification_modes <- logical()
  corrupted <- FALSE
  runtime$wlv_verify_release_manifest <- function(
      manifest,
      release_root,
      publication_root = dirname(release_root),
      reject_unlisted = TRUE,
      verify_runs = TRUE) {
    verification_modes <<- c(verification_modes, verify_runs)
    value <- original_verify_release(
      manifest,
      release_root,
      publication_root = publication_root,
      reject_unlisted = reject_unlisted,
      verify_runs = verify_runs
    )
    if (!corrupted && identical(verify_runs, FALSE)) {
      connection <- file(payload, open = "ab")
      on.exit(close(connection), add = TRUE)
      writeBin(charToRaw("post-staging corruption"), connection)
      corrupted <<- TRUE
    }
    value
  }
  on.exit({
    runtime$wlv_verify_release_manifest <- original_verify_release
  }, add = TRUE)

  expect_error(
    runtime$wlv_commit_release(plan, list(second)),
    "mismatch for run artifact"
  )
  expect_true(corrupted)
  expect_identical(verification_modes, c(FALSE, TRUE))
  runtime$wlv_verify_release_manifest <- original_verify_release
  current_after <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )

  expect_identical(
    runtime$wlv_list_channel_markers(fixture$root, "stable"),
    markers_before
  )
  expect_identical(current_after$marker_path, current_before$marker_path)
  expect_identical(
    readBin(
      current_after$marker_path,
      what = "raw",
      n = file.info(current_after$marker_path)$size
    ),
    marker_bytes_before
  )
})

test_that("the channel-marker rename remains the final fallible commit step", {
  fixture <- wlv_make_native_publication_fixture(mutable = TRUE)
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  plan <- wlv_native_test_release_plan(fixture)
  first <- wlv_native_test_run_environment(fixture, "run-final-001")
  runtime$wlv_commit_release(plan, list(first))
  stable_channel <- normalizePath(
    file.path(fixture$root, "results", "channels", "stable"),
    winslash = "/",
    mustWork = TRUE
  )

  committed <- FALSE
  base_rename <- base::file.rename
  original_verify <- runtime$wlv_verify_channel_marker
  runtime$file.rename <- function(from, to) {
    target <- normalizePath(dirname(to), winslash = "/", mustWork = FALSE)
    result <- base_rename(from, to)
    if (isTRUE(result) && identical(tolower(target), tolower(stable_channel)) &&
        grepl("^[0-9]{20}-release-.*[.]json$", basename(to))) {
      committed <<- TRUE
    }
    result
  }
  runtime$wlv_verify_channel_marker <- function(
      marker,
      publication_root,
      marker_path = NULL,
      verify_release = TRUE) {
    if (committed && !is.null(marker_path)) {
      stop("fallible post-commit marker verification", call. = FALSE)
    }
    original_verify(
      marker,
      publication_root,
      marker_path = marker_path,
      verify_release = verify_release
    )
  }
  second <- wlv_native_test_run_environment(fixture, "run-final-002")

  expect_no_error(runtime$wlv_commit_release(plan, list(second)))
  expect_true(committed)
  rm("file.rename", envir = runtime)
  runtime$wlv_verify_channel_marker <- original_verify
  current <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )
  expect_identical(current$manifest$runs[[1L]]$run_id, "run-final-002")
})

test_that("a later native method failure prevents the joint release commit", {
  fixture <- wlv_make_native_publication_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  initial <- wlv_native_test_run_environment(fixture, "run-joint-001")
  runtime$wlv_commit_release(
    wlv_native_test_release_plan(fixture),
    list(initial)
  )
  before <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )
  marker_bytes <- readBin(
    before$marker_path,
    what = "raw",
    n = file.info(before$marker_path)$size
  )

  expect_error(runtime$wlv_with_publication_lock(
    list(root = fixture$root, method_names = c("native_a", "native_b")),
    function() {
      wlv_native_test_run_environment(
        fixture,
        "run-joint-a",
        method = "native_a"
      )
      stop("injected native method failure", call. = FALSE)
    }
  ), "injected native method failure", fixed = TRUE)
  after <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )

  expect_identical(after$manifest$release_id, before$manifest$release_id)
  expect_identical(
    readBin(after$marker_path, what = "raw", n = file.info(after$marker_path)$size),
    marker_bytes
  )
  expect_false(dir.exists(file.path(fixture$root, "results", ".lock-results")))
})

test_that("paper artifacts are hashed inside the committed release", {
  fixture <- wlv_make_native_publication_fixture(mutable = TRUE)
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  runtime$wlv_run_staged_paper <- function(
      plan,
      run_environments,
      release_staging) {
    output <- file.path(release_staging, "reduction_problem.xlsx")
    writeBin(charToRaw("native paper"), output)
    structure(
      list(output = output, sheets = list()),
      class = c("wlv_paper_result", "list")
    )
  }
  plan <- wlv_native_test_release_plan(fixture)
  plan$prepaper <- TRUE
  run <- wlv_native_test_run_environment(fixture, "run-paper")

  release <- runtime$wlv_commit_release(plan, list(run))

  paper <- release$manifest$artifacts[vapply(
    release$manifest$artifacts,
    function(artifact) identical(artifact$role, "paper"),
    logical(1L)
  )]
  expect_length(paper, 1L)
  expect_identical(paper[[1L]]$path, "reduction_problem.xlsx")
  expect_no_error(runtime$wlv_verify_release_manifest(
    release$manifest,
    release$root,
    publication_root = file.path(fixture$root, "results"),
    reject_unlisted = TRUE
  ))
})

test_that("paper failure leaves the previous release current", {
  fixture <- wlv_make_native_publication_fixture(mutable = TRUE)
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  plan <- wlv_native_test_release_plan(fixture)
  first <- wlv_native_test_run_environment(fixture, "run-paper-before")
  runtime$wlv_commit_release(plan, list(first))
  before <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )
  markers_before <- runtime$wlv_list_channel_markers(fixture$root, "stable")
  runtime$wlv_run_staged_paper <- function(...) {
    stop("injected paper failure", call. = FALSE)
  }
  plan$prepaper <- TRUE
  second <- wlv_native_test_run_environment(fixture, "run-paper-after")

  expect_error(
    runtime$wlv_commit_release(plan, list(second)),
    "injected paper failure",
    fixed = TRUE
  )
  after <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )
  expect_identical(after$manifest$release_id, before$manifest$release_id)
  expect_identical(
    runtime$wlv_list_channel_markers(fixture$root, "stable"),
    markers_before
  )
})

test_that("uncommitted native staging is invisible to current-run resolution", {
  fixture <- wlv_make_native_publication_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  published <- wlv_native_test_run_environment(fixture, "run-visible")
  runtime$wlv_commit_release(
    wlv_native_test_release_plan(fixture),
    list(published)
  )
  staging <- runtime$wlv_create_result_staging(fixture$root, fixture$method)
  on.exit(runtime$wlv_remove_result_staging(
    staging,
    file.path(fixture$root, "results")
  ), add = TRUE)
  wlv_native_test_write_text(file.path(staging, "payload.txt"), "uncommitted")

  current <- runtime$wlv_resolve_current_method_run(
    fixture$root,
    fixture$method,
    channel = "stable"
  )
  expect_identical(current$run_id, "run-visible")
  expect_identical(basename(dirname(staging)), ".staging")
  expect_false(startsWith(current$path, staging))
})

test_that("publication refuses redirected store and channel directories", {
  runtime <- wlv_test_load_runtime()
  root <- tempfile("wlv-publication-links-")
  results_root <- file.path(root, "results")
  release_target <- file.path(results_root, "releases")
  dir.create(release_target, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  link_directory <- function(target, link) {
    if (.Platform$OS.type == "windows" &&
        exists("Sys.junction", envir = baseenv(), mode = "function")) {
      suppressWarnings(Sys.junction(target, link))
    } else {
      suppressWarnings(file.symlink(target, link))
    }
  }

  runs_link <- file.path(results_root, "runs")
  linked <- link_directory(release_target, runs_link)
  if (!isTRUE(linked)) {
    skip("This platform cannot create a directory link for the topology test.")
  }
  expect_error(
    runtime$wlv_publication_ensure_store(root),
    "symbolic link or junction|canonical publication parent"
  )
  unlink(runs_link, recursive = FALSE, force = TRUE)
  paths <- runtime$wlv_publication_ensure_store(root)
  channel_target <- file.path(paths$channels, "experiment")
  dir.create(channel_target)
  channel_link <- file.path(paths$channels, "stable")
  expect_true(link_directory(channel_target, channel_link))
  expect_error(
    runtime$wlv_list_channel_markers(root, "stable"),
    "symbolic link or junction|canonical publication parent"
  )
  expect_length(list.files(channel_target, all.files = TRUE, no.. = TRUE), 0L)
})

test_that("current release resolution rejects redirected components", {
  fixture <- wlv_make_native_publication_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  run <- wlv_native_test_run_environment(fixture, "run-links")
  runtime$wlv_commit_release(
    wlv_native_test_release_plan(fixture),
    list(run)
  )
  paths <- runtime$wlv_publication_paths(fixture$root)
  current_release <- runtime$wlv_read_current_release(
    fixture$root,
    "stable",
    required = TRUE
  )
  current_run <- runtime$wlv_resolve_current_method_run(
    fixture$root,
    fixture$method,
    channel = "stable"
  )
  link_directory <- function(target, link) {
    if (.Platform$OS.type == "windows" &&
        exists("Sys.junction", envir = baseenv(), mode = "function")) {
      suppressWarnings(Sys.junction(target, link))
    } else {
      suppressWarnings(file.symlink(target, link))
    }
  }
  expect_rejected_redirect <- function(path, target) {
    expect_true(file.rename(path, target))
    restored <- FALSE
    on.exit({
      if (!restored) {
        if (dir.exists(path) || file.exists(path)) {
          unlink(path, recursive = FALSE, force = TRUE)
        }
        if (dir.exists(target)) file.rename(target, path)
      }
    }, add = TRUE)
    if (!isTRUE(link_directory(target, path))) {
      skip("This platform cannot create a directory link for the reader test.")
    }
    expect_error(
      runtime$wlv_read_current_release(
        fixture$root,
        "stable",
        required = TRUE
      ),
      paste0(
        "symbolic link or junction|canonical publication parent|",
        "must be an existing directory"
      )
    )
    unlink(path, recursive = FALSE, force = TRUE)
    expect_true(file.rename(target, path))
    restored <- TRUE
  }

  expect_rejected_redirect(
    paths$runs,
    file.path(paths$results, "runs-sibling")
  )
  expect_rejected_redirect(
    paths$releases,
    file.path(paths$results, "releases-sibling")
  )
  expect_rejected_redirect(
    current_release$root,
    file.path(paths$releases, "release-sibling")
  )
  expect_rejected_redirect(
    file.path(paths$runs, fixture$method),
    file.path(paths$runs, "method-sibling")
  )
  expect_rejected_redirect(
    current_run$path,
    file.path(dirname(current_run$path), "run-sibling")
  )
})

test_that("native preparation, validation, execution, and commit share one lock", {
  fixture <- wlv_make_native_publication_fixture(mutable = TRUE)
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  events <- character()
  lock_path <- file.path(fixture$root, "results", ".lock-results")
  runtime$wlv_prepare_sources <- function(plan) {
    expect_true(dir.exists(lock_path))
    events <<- c(events, "prepare")
  }
  runtime$wlv_validate_data <- function(plan) {
    expect_true(dir.exists(lock_path))
    events <<- c(events, "validate")
    plan
  }
  runtime$wlv_with_cluster <- function(workers, run) run(NULL)
  runtime$wlv_run_method <- function(plan, method, cluster = NULL) {
    expect_true(dir.exists(lock_path))
    events <<- c(events, "calculate")
    new.env(parent = emptyenv())
  }
  runtime$wlv_commit_release <- function(plan, run_environments) {
    expect_true(dir.exists(lock_path))
    events <<- c(events, "commit")
    list(manifest = list(release_id = "release-native-test"))
  }
  plan <- wlv_native_test_release_plan(fixture)
  plan$workers <- 1L
  plan$mode <- "calculate"
  plan$repeat_pp <- TRUE

  expect_no_error(runtime$wlv_execute_run_plan(plan))
  expect_identical(events, c("prepare", "validate", "calculate", "commit"))
  expect_false(dir.exists(lock_path))
  events <- character()
  expect_no_error(runtime$wlv_execute_preparation_plan(plan))
  expect_identical(events, c("prepare", "validate"))
  expect_false(dir.exists(lock_path))
})

test_that("result locks reject concurrency and remain reusable", {
  fixture <- wlv_make_native_publication_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  results_root <- file.path(fixture$root, "results")
  lock <- runtime$wlv_acquire_result_lock(results_root, fixture$method)
  on.exit(try(runtime$wlv_release_result_lock(
    lock,
    results_root
  ), silent = TRUE), add = TRUE)

  expect_error(
    runtime$wlv_acquire_result_lock(results_root, fixture$method),
    "already locked",
    fixed = TRUE
  )
  expect_error(
    runtime$wlv_acquire_result_lock(results_root, "another_native_method"),
    "already locked",
    fixed = TRUE
  )
  runtime$wlv_release_result_lock(lock, results_root)
  expect_false(dir.exists(lock))
  lock <- runtime$wlv_acquire_result_lock(results_root, fixture$method)
  expect_true(dir.exists(lock))
})

test_that("post-commit lock cleanup cannot turn success into failure", {
  fixture <- wlv_make_native_publication_fixture(mutable = TRUE)
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  release <- runtime$wlv_release_result_lock
  release_calls <- 0L
  runtime$wlv_release_result_lock <- function(...) {
    release_calls <<- release_calls + 1L
    if (identical(release_calls, 1L)) {
      stop("injected lock cleanup failure", call. = FALSE)
    }
    release(...)
  }
  value <- NULL
  expect_message(
    value <- runtime$wlv_with_publication_lock(
      list(root = fixture$root, method_names = fixture$method),
      function() "committed-native-value"
    ),
    "result lock cleanup warning"
  )
  expect_identical(value, "committed-native-value")
  expect_identical(release_calls, 2L)
  expect_false(dir.exists(file.path(fixture$root, "results", ".lock-results")))
})

test_that("method metadata validation detects missing, stale, and extra sidecars", {
  fixture <- wlv_make_native_publication_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  result_dir <- file.path(fixture$root, "metadata-sidecars")
  dir.create(result_dir)
  metadata <- runtime$wlv_method_result_metadata(
    parameters = data.frame(source = "native_test"),
    assumptions = data.frame(computation = "none"),
    matrices = data.frame(names = "values"),
    solutions = data.frame(names = "metric", stage = 5L),
    sectors = data.frame(sector = "S"),
    meta_indicators = data.frame(
      code = "metric",
      name = "Metric",
      stringsAsFactors = FALSE,
      row.names = "metric"
    ),
    extra_csv = list(
      `_diagnostic.csv` = data.frame(
        coordinate = "2000|S",
        original_value = -1,
        applied_value = 0,
        stringsAsFactors = FALSE
      )
    )
  )
  runtime$wlv_write_method_result_metadata(result_dir, metadata)
  expect_no_error(runtime$wlv_validate_method_result_metadata(
    result_dir,
    metadata
  ))

  files <- c(names(metadata$csv), "meta_indicators.RDS")
  for (name in files) {
    local({
      path <- file.path(result_dir, name)
      bytes <- readBin(path, what = "raw", n = file.info(path)$size)
      unlink(path)
      expect_error(
        runtime$wlv_validate_method_result_metadata(result_dir, metadata),
        "missing",
        fixed = TRUE
      )
      writeBin(bytes, path)
      writeBin(charToRaw("corrupt"), path)
      expect_error(
        runtime$wlv_validate_method_result_metadata(result_dir, metadata),
        "differs|Cannot read"
      )
      writeBin(bytes, path)
    })
  }
  unexpected <- file.path(result_dir, "_gfcf_negative_unexpected.csv")
  runtime$wlv_write_result_csv(data.frame(value = 1), unexpected)
  expect_error(
    runtime$wlv_validate_method_result_metadata(result_dir, metadata),
    "unexpected scientific sidecar",
    fixed = TRUE
  )
})

test_that("resolving a current run rejects a corrupted native artifact", {
  fixture <- wlv_make_native_publication_fixture()
  on.exit(wlv_remove_native_fixture(fixture), add = TRUE)
  runtime <- fixture$runtime
  run <- wlv_native_test_run_environment(fixture, "run-corrupt")
  runtime$wlv_commit_release(
    wlv_native_test_release_plan(fixture),
    list(run)
  )
  artifact <- file.path(run$wlv_run_dir, "payload.txt")
  connection <- file(artifact, open = "ab")
  writeBin(charToRaw("corruption"), connection)
  close(connection)

  expect_error(
    runtime$wlv_resolve_current_method_run(
      fixture$root,
      fixture$method,
      channel = "stable"
    ),
    "payload.txt"
  )
})

test_that("publication lifecycle tests use only native test fixtures", {
  paths <- c(
    file.path(wlv_test_root, "tests", "testthat", "test-publication-lifecycle.R"),
    file.path(wlv_test_root, "tests", "testthat", "helper-synthetic-fixture.R")
  )
  text <- paste(unlist(lapply(paths, readLines, warn = FALSE)), collapse = "\n")
  legacy <- paste0(
    "computations[.]R|re_computations[.]R|wlv_run_", "script|",
    "sys[.]source[(].*main[.]R"
  )
  expect_false(grepl(legacy, text))
})
