test_that("repeated calculations retain immutable runs with a stable result identity", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)

  first <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))
  first_run <- wlv_fixture_current_run(fixture, first$runtime)
  first_release <- wlv_fixture_current_release(fixture, first$runtime)

  second <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))
  second_run <- wlv_fixture_current_run(fixture, second$runtime)
  second_release <- wlv_fixture_current_release(fixture, second$runtime)

  expect_false(identical(second_run$run_id, first_run$run_id))
  expect_identical(second_run$result_id, first_run$result_id)
  expect_true(first_run$manifest$result$provenance$complete)
  expect_true(second_run$manifest$result$provenance$complete)
  source <- first_run$manifest$result$provenance$source
  expect_named(
    source,
    c("summary", "manifest", "additional_inputs"),
    ignore.order = TRUE
  )
  expect_gt(length(source$manifest), 0L)
  expect_named(
    source$manifest[[1L]],
    first$runtime$wlv_source_manifest_schema,
    ignore.order = TRUE
  )
  expect_true(all(vapply(source$manifest, function(record) {
    !grepl("^([A-Za-z]:|[/\\\\])", record$artifact) &&
      grepl("^[0-9a-f]{64}$", record$sha256)
  }, logical(1L))))
  publication_input_paths <- vapply(
    first_run$manifest$result$provenance$inputs,
    `[[`,
    character(1L),
    "path"
  )
  expect_true(any(startsWith(publication_input_paths, "contracts/results/")))
  expect_true(any(endsWith(publication_input_paths, "/.gitattributes")))
  expect_true("contracts/results" %in%
    first$runtime$wlv_git_publication_status_scope(
      first_run$manifest$result$provenance$inputs
    ))
  expect_true(dir.exists(first_run$path))
  expect_true(dir.exists(second_run$path))
  expect_identical(first_release$marker$sequence, "00000000000000000001")
  expect_identical(second_release$marker$sequence, "00000000000000000002")
  expect_length(
    second$runtime$wlv_list_channel_markers(fixture$root, "stable"),
    2L
  )
  duplicate_marker <- file.path(
    dirname(second_release$marker_path),
    paste0(second_release$marker$sequence, "-release-duplicate.json")
  )
  expect_true(file.copy(second_release$marker_path, duplicate_marker))
  expect_error(
    second$runtime$wlv_read_current_release(fixture$root, "stable"),
    "more than one marker at sequence"
  )
})

test_that("persisted warnings are single-line UTF-8 text without absolute paths", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)

  runtime <- new.env(parent = globalenv())
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)
  original_run_script <- runtime$wlv_run_script
  accented_warning <- "Aviso com acentua\u00e7\u00e3o"
  runtime$wlv_run_script <- function(script, ...) {
    if (identical(basename(script), "computations.R")) {
      warning(
        paste0(
          accented_warning, "\nprojeto: ", fixture$root,
          "\thome: ", path.expand("~"),
          "; temp: ", tempdir(),
          "; outros: C:\\dados\\privado.csv e /srv/privado.csv",
          "; espaços: C:\\Dados Sensíveis\\cliente.csv, ",
          "/srv/dados privados/cliente.csv",
          "; URL: https://user:pass@example.test/path?token=secret-value#fragment",
          "; token=top-secret; Authorization: Bearer credential-value"
        ),
        call. = FALSE
      )
    }
    original_run_script(script, ...)
  }

  expect_no_error(suppressWarnings(suppressMessages(runtime$get_wlv(
    fixture$method,
    workers = 1L,
    allow_experimental = TRUE
  ))))
  current <- wlv_fixture_current_run(fixture, runtime)
  warning_records <- current$manifest$execution$warnings
  warnings <- warning_records[[1L]]

  expect_length(warning_records, 1L)
  expect_identical(iconv(warnings, "UTF-8", "UTF-8", sub = NA), warnings)
  expect_false(any(grepl("[\r\n\t]", warnings)))
  expect_false(any(grepl(fixture$root, warnings, fixed = TRUE)))
  expect_false(any(grepl(path.expand("~"), warnings, fixed = TRUE)))
  expect_false(any(grepl(tempdir(), warnings, fixed = TRUE)))
  expect_false(any(grepl("[A-Za-z]:[/\\\\]", warnings)))
  expect_false(any(grepl("(?<![:/])/(?:[^[:space:]]+)", warnings, perl = TRUE)))
  expect_false(grepl("Sensíveis\\\\cliente.csv", warnings))
  expect_false(grepl("dados privados/cliente.csv", warnings, fixed = TRUE))
  expect_false(grepl(
    "secret-value|user:pass|top-secret|credential-value",
    warnings
  ))
  expect_true(grepl("<url>", warnings, fixed = TRUE))
  expect_true(grepl(accented_warning, warnings, fixed = TRUE))
  manifest_text <- rawToChar(readBin(
    current$manifest_path,
    what = "raw",
    n = file.info(current$manifest_path)$size
  ))
  expect_true(grepl(
    enc2utf8(accented_warning),
    manifest_text,
    fixed = TRUE,
    useBytes = TRUE
  ))
})

test_that("additional source inputs are inventoried with relative paths", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  runtime <- new.env(parent = globalenv())
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)

  paths <- file.path(
    fixture$root,
    "source_data",
    "synthetic",
    c("countries.csv", "demand.csv")
  )
  inventory <- runtime$wlv_publication_source_input_inventory(
    fixture$root,
    rev(paths)
  )

  expect_identical(
    vapply(inventory, `[[`, character(1L), "path"),
    c(
      "source_data/synthetic/countries.csv",
      "source_data/synthetic/demand.csv"
    )
  )
  expect_true(all(vapply(inventory, function(record) {
    is.numeric(record$size_bytes) && record$size_bytes > 0 &&
      grepl("^[0-9a-f]{64}$", record$sha256)
  }, logical(1L))))
})

test_that("git provenance aborts when repository inspection fails", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  runtime <- new.env(parent = globalenv())
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)
  writeLines(
    "gitdir: injected-worktree-metadata",
    file.path(fixture$root, ".git"),
    useBytes = TRUE
  )
  runtime$Sys.which <- function(command) {
    stats::setNames("", command)
  }
  expect_error(
    runtime$wlv_git_publication_provenance(fixture$root, list()),
    "Git is required to record provenance for a detected repository",
    fixed = TRUE
  )
  rm("Sys.which", envir = runtime)
  runtime$system2 <- function(...) {
    structure(character(), status = 128L)
  }

  expect_error(
    runtime$wlv_git_publication_provenance(
      fixture$root,
      list(list(
        path = "contracts/results/run-manifest-v1.schema.json",
        sha256 = strrep("0", 64L)
      ))
    ),
    "Git failed while attempting to read the publication commit",
    fixed = TRUE
  )

  call_count <- 0L
  git_arguments <- list()
  runtime$system2 <- function(command, args, ...) {
    call_count <<- call_count + 1L
    git_arguments[[call_count]] <<- args
    if (identical(call_count, 1L)) {
      return(strrep("a", 40L))
    }
    c("?? R/z-new.R", " M R/a-existing.R")
  }
  provenance <- runtime$wlv_git_publication_provenance(
    fixture$root,
    list(list(
      path = "contracts/results/run-manifest-v1.schema.json",
      sha256 = strrep("0", 64L)
    ))
  )
  expected_status <- paste(
    sort(c("?? R/z-new.R", " M R/a-existing.R"), method = "radix"),
    collapse = "\n"
  )
  expect_true(provenance$dirty)
  expect_identical(
    provenance$status_sha256,
    runtime$wlv_source_sha256_raw(charToRaw(enc2utf8(expected_status)))
  )
  expect_true(any(grepl(
    "contracts/results",
    git_arguments[[2L]],
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "complementar",
    git_arguments[[2L]],
    fixed = TRUE
  )))
  expect_true(any(grepl(
    "renv.lock",
    git_arguments[[2L]],
    fixed = TRUE
  )))
})

test_that("result contracts affect the provenance input tree", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  runtime <- new.env(parent = globalenv())
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)
  plan <- list(
    root = fixture$root,
    methods = data.frame(
      method = fixture$method,
      method_dir = file.path(fixture$root, "methods", fixture$method),
      parameter_set = "synthetic",
      stringsAsFactors = FALSE
    )
  )

  before <- runtime$wlv_publication_input_inventory(plan, fixture$method)
  contract_path <- file.path(
    fixture$root,
    "contracts",
    "results",
    "run-manifest-v1.schema.json"
  )
  write("", contract_path, append = TRUE)
  after <- runtime$wlv_publication_input_inventory(plan, fixture$method)
  before_git <- runtime$wlv_git_publication_provenance(fixture$root, before)
  after_git <- runtime$wlv_git_publication_provenance(fixture$root, after)

  expect_false(identical(before, after))
  expect_false(identical(
    before_git$input_tree_sha256,
    after_git$input_tree_sha256
  ))
})

test_that("complementary calculation inputs affect the provenance input tree", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  runtime <- new.env(parent = globalenv())
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)
  plan <- list(
    root = fixture$root,
    methods = data.frame(
      method = fixture$method,
      method_dir = file.path(fixture$root, "methods", fixture$method),
      parameter_set = "synthetic",
      stringsAsFactors = FALSE
    )
  )

  before <- runtime$wlv_publication_input_inventory(plan, fixture$method)
  complementary_path <- file.path(
    fixture$root,
    "complementar",
    "worldbank",
    "employment_row.csv"
  )
  write("# provenance change", complementary_path, append = TRUE)
  after <- runtime$wlv_publication_input_inventory(plan, fixture$method)
  before_git <- runtime$wlv_git_publication_provenance(fixture$root, before)
  after_git <- runtime$wlv_git_publication_provenance(fixture$root, after)

  expect_true(any(startsWith(
    vapply(before, `[[`, character(1L), "path"),
    "complementar/"
  )))
  expect_false(identical(before, after))
  expect_false(identical(
    before_git$input_tree_sha256,
    after_git$input_tree_sha256
  ))
  expect_true("complementar" %in%
    runtime$wlv_git_publication_status_scope(after))
})

test_that("an experimental channel cannot change the stable release", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)

  run <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))
  stable_before <- wlv_fixture_current_release(fixture, run$runtime)

  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  expect_no_error(suppressWarnings(suppressMessages(run$runtime$get_wlv(
    fixture$method,
    workers = 1L,
    channel = "experiment-v2",
    allow_experimental = TRUE
  ))))

  stable_after <- wlv_fixture_current_release(fixture, run$runtime)
  experimental <- wlv_fixture_current_release(
    fixture,
    run$runtime,
    channel = "experiment-v2"
  )
  expect_identical(
    stable_after$manifest$release_id,
    stable_before$manifest$release_id
  )
  expect_false(identical(
    experimental$manifest$release_id,
    stable_before$manifest$release_id
  ))
  expect_identical(experimental$marker$channel, "experiment-v2")
})

test_that("marker installation failure leaves the previous release current", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)

  run <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))
  current_before <- wlv_fixture_current_release(fixture, run$runtime)
  marker_bytes_before <- readBin(
    current_before$marker_path,
    what = "raw",
    n = file.info(current_before$marker_path)$size
  )
  markers_before <- run$runtime$wlv_list_channel_markers(fixture$root, "stable")

  base_file_rename <- base::file.rename
  stable_channel_dir <- normalizePath(
    file.path(fixture$root, "results", "channels", "stable"),
    winslash = "/",
    mustWork = TRUE
  )
  run$runtime$file.rename <- function(from, to) {
    target_dir <- normalizePath(
      dirname(to),
      winslash = "/",
      mustWork = FALSE
    )
    if (identical(tolower(target_dir), tolower(stable_channel_dir)) && grepl(
      "^[0-9]{20}-release-.*[.]json$",
      basename(to)
    )) return(FALSE)
    base_file_rename(from, to)
  }
  on.exit(rm("file.rename", envir = run$runtime), add = TRUE)

  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  expect_error(
    suppressWarnings(suppressMessages(run$runtime$get_wlv(
      fixture$method,
      workers = 1L,
      allow_experimental = TRUE
    ))),
    "Could not atomically install channel marker",
    fixed = TRUE
  )

  current_after <- wlv_fixture_current_release(fixture, run$runtime)
  expect_identical(
    current_after$manifest$release_id,
    current_before$manifest$release_id
  )
  expect_identical(
    readBin(
      current_after$marker_path,
      what = "raw",
      n = file.info(current_after$marker_path)$size
    ),
    marker_bytes_before
  )
  expect_identical(
    run$runtime$wlv_list_channel_markers(fixture$root, "stable"),
    markers_before
  )
})

test_that("the final marker rename is the last fallible commit operation", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  run <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))
  release_before <- wlv_fixture_current_release(fixture, run$runtime)
  stable_channel_dir <- normalizePath(
    file.path(fixture$root, "results", "channels", "stable"),
    winslash = "/",
    mustWork = TRUE
  )

  committed <- FALSE
  base_file_rename <- base::file.rename
  original_verify <- run$runtime$wlv_verify_channel_marker
  run$runtime$file.rename <- function(from, to) {
    target_dir <- normalizePath(
      dirname(to),
      winslash = "/",
      mustWork = FALSE
    )
    result <- base_file_rename(from, to)
    if (isTRUE(result) &&
        identical(tolower(target_dir), tolower(stable_channel_dir)) &&
        grepl("^[0-9]{20}-release-.*[.]json$", basename(to))) {
      committed <<- TRUE
    }
    result
  }
  run$runtime$wlv_verify_channel_marker <- function(
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
  on.exit({
    if (exists("file.rename", envir = run$runtime, inherits = FALSE)) {
      rm("file.rename", envir = run$runtime)
    }
    run$runtime$wlv_verify_channel_marker <- original_verify
  }, add = TRUE)

  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  expect_no_error(suppressWarnings(suppressMessages(run$runtime$get_wlv(
    fixture$method,
    workers = 1L,
    allow_experimental = TRUE
  ))))
  expect_true(committed)

  rm("file.rename", envir = run$runtime)
  run$runtime$wlv_verify_channel_marker <- original_verify
  release_after <- wlv_fixture_current_release(fixture, run$runtime)
  expect_false(identical(
    release_after$manifest$release_id,
    release_before$manifest$release_id
  ))
})

test_that("a later method failure prevents the joint release commit", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)

  run <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))
  release_before <- wlv_fixture_current_release(fixture, run$runtime)
  marker_before <- readBin(
    release_before$marker_path,
    what = "raw",
    n = file.info(release_before$marker_path)$size
  )
  commit_called <- FALSE
  run$runtime$wlv_validate_data <- identity
  run$runtime$wlv_with_cluster <- function(workers, execute) execute(NULL)
  run$runtime$wlv_run_method <- function(plan, method, cluster = NULL) {
    if (identical(method, "second")) {
      stop("injected second-method failure", call. = FALSE)
    }
    new.env(parent = emptyenv())
  }
  run$runtime$wlv_commit_release <- function(...) {
    commit_called <<- TRUE
    stop("joint commit should not run", call. = FALSE)
  }
  plan <- structure(
    list(
      root = fixture$root,
      method_names = c("first", "second"),
      workers = 1L,
      mode = "calculate"
    ),
    class = c("wlv_run_plan", "list")
  )

  expect_error(
    run$runtime$wlv_execute_run_plan(plan),
    "injected second-method failure",
    fixed = TRUE
  )
  expect_false(commit_called)
  release_after <- wlv_fixture_current_release(fixture, run$runtime)
  expect_identical(release_after$manifest$release_id, release_before$manifest$release_id)
  expect_identical(
    readBin(
      release_after$marker_path,
      what = "raw",
      n = file.info(release_after$marker_path)$size
    ),
    marker_before
  )
  expect_false(dir.exists(file.path(fixture$root, "results", ".lock-results")))
})

test_that("uncommitted staging is invisible to the legacy method scan", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  runtime <- new.env(parent = globalenv())
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)

  staging <- runtime$wlv_create_result_staging(fixture$root, fixture$method)
  on.exit(
    runtime$wlv_remove_result_staging(
      staging,
      file.path(fixture$root, "results")
    ),
    add = TRUE
  )
  writeLines("method;synthetic", file.path(staging, "_parameters.csv"))
  immediate_directories <- list.dirs(
    file.path(fixture$root, "results"),
    recursive = FALSE,
    full.names = TRUE
  )

  expect_identical(basename(dirname(staging)), ".staging")
  expect_false(any(file.exists(file.path(
    immediate_directories,
    "_parameters.csv"
  ))))
})

test_that("publication refuses redirected store and channel directories", {
  runtime <- new.env(parent = globalenv())
  sys.source(
    file.path(wlv_test_root, "R", "lib", "publication_manifest.R"),
    envir = runtime
  )
  sys.source(
    file.path(wlv_test_root, "R", "lib", "publication.R"),
    envir = runtime
  )
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
  method_target <- file.path(paths$runs, "other")
  dir.create(method_target)
  method_link <- file.path(paths$runs, "synthetic")
  expect_true(link_directory(method_target, method_link))
  expect_error(
    runtime$wlv_publication_assert_real_directory(
      method_link,
      paths$runs,
      "Synthetic method store"
    ),
    "symbolic link or junction|canonical publication parent"
  )
  unlink(method_link, recursive = FALSE, force = TRUE)
  channel_target <- file.path(paths$channels, "experiment")
  dir.create(channel_target)
  channel_link <- file.path(paths$channels, "stable")
  expect_true(link_directory(channel_target, channel_link))
  expect_error(
    runtime$wlv_list_channel_markers(root, "stable"),
    "symbolic link or junction|canonical publication parent"
  )
  expect_length(list.files(channel_target, all.files = TRUE, no.. = TRUE), 0L)
  unlink(channel_link, recursive = FALSE, force = TRUE)
})

test_that("current release reader rejects redirected publication components", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  calculated <- suppressMessages(wlv_run_synthetic_calculation(
    fixture,
    workers = 1L
  ))
  runtime <- calculated$runtime
  paths <- runtime$wlv_publication_paths(fixture$root)
  current_release <- wlv_fixture_current_release(fixture, runtime)
  current_run <- wlv_fixture_current_run(fixture, runtime)

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
        if (dir.exists(target)) {
          file.rename(target, path)
        }
      }
    }, add = TRUE)
    if (!isTRUE(link_directory(target, path))) {
      skip("This platform cannot create a directory link for the reader test.")
    }
    expect_error(
      runtime$wlv_read_current_release(fixture$root, "stable", required = TRUE),
      paste(
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

test_that("source preparation and validation execute under the publication lock", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)
  old_working_directory <- setwd(fixture$root)
  on.exit(setwd(old_working_directory), add = TRUE)
  runtime <- new.env(parent = globalenv())
  sys.source(file.path(fixture$root, "R", "main.R"), envir = runtime)

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
    list(manifest = list(release_id = "release-test"))
  }
  plan <- list(
    root = fixture$root,
    method_names = fixture$method,
    workers = 1L,
    mode = "calculate",
    repeat_pp = TRUE
  )

  expect_no_error(runtime$wlv_execute_run_plan(plan))
  expect_identical(events, c("prepare", "validate", "calculate", "commit"))
  expect_false(dir.exists(lock_path))

  events <- character()
  expect_no_error(runtime$wlv_execute_preparation_plan(plan))
  expect_identical(events, c("prepare", "validate"))
  expect_false(dir.exists(lock_path))
})

test_that("resolving a current run rejects a corrupted artifact", {
  fixture <- wlv_make_synthetic_calculation_fixture()
  on.exit(wlv_remove_synthetic_calculation_fixture(fixture), add = TRUE)

  run <- suppressMessages(wlv_run_synthetic_calculation(fixture, workers = 1L))
  current <- wlv_fixture_current_run(fixture, run$runtime)
  artifact <- file.path(current$path, "_parameters.csv")
  connection <- file(artifact, open = "ab")
  writeBin(charToRaw("corruption"), connection)
  close(connection)

  expect_error(
    run$runtime$wlv_resolve_current_method_run(
      fixture$root,
      fixture$method,
      channel = "stable",
      allow_legacy = FALSE
    ),
    "_parameters.csv"
  )
})
