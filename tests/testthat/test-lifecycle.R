execution_environment <- new.env(parent = baseenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "execution.R"),
  envir = execution_environment
)

test_that("invalid worker counts fail before a cluster is created", {
  starts <- 0L
  make_cluster <- function(workers) {
    starts <<- starts + 1L
    structure(list(workers = workers), class = "wlv_test_cluster")
  }

  invalid_workers <- list(
    NULL,
    0,
    -1,
    1.5,
    NA_real_,
    Inf,
    "2",
    c(1, 2)
  )

  for (workers in invalid_workers) {
    expect_error(
      execution_environment$wlv_with_cluster(
        workers = workers,
        run = function(cluster) cluster,
        make_cluster = make_cluster
      ),
      "[Ww]orkers"
    )
  }

  expect_identical(starts, 0L)
})

test_that("one worker uses the sequential path without a factory", {
  starts <- 0L

  result <- execution_environment$wlv_with_cluster(
    workers = 1L,
    run = function(cluster) {
      expect_null(cluster)
      "sequential"
    },
    make_cluster = function(workers) {
      starts <<- starts + 1L
      stop("the cluster factory must not run")
    }
  )

  expect_identical(result, "sequential")
  expect_identical(starts, 0L)
})

test_that("parallel success starts and stops exactly one cluster", {
  starts <- 0L
  stops <- 0L
  fake_cluster <- structure(list(id = "success"), class = "wlv_test_cluster")

  result <- execution_environment$wlv_with_cluster(
    workers = 2L,
    run = function(cluster) {
      expect_identical(cluster, fake_cluster)
      "done"
    },
    make_cluster = function(workers) {
      starts <<- starts + 1L
      expect_identical(workers, 2L)
      fake_cluster
    },
    stop_cluster = function(cluster) {
      stops <<- stops + 1L
      expect_identical(cluster, fake_cluster)
    }
  )

  expect_identical(result, "done")
  expect_identical(starts, 1L)
  expect_identical(stops, 1L)
})

test_that("parallel errors preserve the original condition and stop once", {
  starts <- 0L
  stops <- 0L
  sentinel <- simpleError("sentinel failure")
  fake_cluster <- structure(list(id = "failure"), class = "wlv_test_cluster")

  caught <- tryCatch(
    execution_environment$wlv_with_cluster(
      workers = 2L,
      run = function(cluster) stop(sentinel),
      make_cluster = function(workers) {
        starts <<- starts + 1L
        fake_cluster
      },
      stop_cluster = function(cluster) {
        stops <<- stops + 1L
      }
    ),
    error = identity
  )

  expect_identical(caught, sentinel)
  expect_identical(starts, 1L)
  expect_identical(stops, 1L)
})

test_that("a failing stopper does not hide the computation error", {
  stops <- 0L
  original <- simpleError("original computation failure")

  caught <- suppressWarnings(tryCatch(
    execution_environment$wlv_with_cluster(
      workers = 2L,
      run = function(cluster) stop(original),
      make_cluster = function(workers) structure(list(), class = "wlv_test_cluster"),
      stop_cluster = function(cluster) {
        stops <<- stops + 1L
        stop("cleanup failure")
      }
    ),
    error = identity
  ))

  expect_identical(caught, original)
  expect_identical(stops, 1L)
})

test_that("a failing stopper is reported after successful computation", {
  stops <- 0L

  expect_error(
    execution_environment$wlv_with_cluster(
      workers = 2L,
      run = function(cluster) "completed",
      make_cluster = function(workers) structure(list(), class = "wlv_test_cluster"),
      stop_cluster = function(cluster) {
        stops <<- stops + 1L
        stop("cleanup failure")
      }
    ),
    "cleanup failure",
    fixed = TRUE
  )
  expect_identical(stops, 1L)
})

test_that("cluster cleanup leaves unrelated connections open", {
  captured_output <- character()
  connection <- textConnection("captured_output", "w", local = TRUE)
  on.exit(if (isOpen(connection)) close(connection), add = TRUE)

  execution_environment$wlv_with_cluster(
    workers = 2L,
    run = function(cluster) writeLines("still open", connection),
    make_cluster = function(workers) structure(list(), class = "wlv_test_cluster"),
    stop_cluster = function(cluster) invisible(NULL)
  )

  expect_true(isOpen(connection))
  expect_identical(captured_output, "still open")
})

test_that("run environments keep execution state out of the global environment", {
  global_names <- c("my.cluster", "method_version")
  global_was_present <- vapply(
    global_names,
    exists,
    logical(1),
    envir = .GlobalEnv,
    inherits = FALSE
  )
  global_values <- if (any(global_was_present)) {
    mget(global_names[global_was_present], envir = .GlobalEnv, inherits = FALSE)
  } else {
    list()
  }

  on.exit({
    created <- global_names[vapply(
      global_names,
      exists,
      logical(1),
      envir = .GlobalEnv,
      inherits = FALSE
    )]
    if (length(created)) {
      rm(list = created, envir = .GlobalEnv)
    }
    if (length(global_values)) {
      list2env(global_values, envir = .GlobalEnv)
    }
  }, add = TRUE)

  if (any(global_was_present)) {
    rm(list = global_names[global_was_present], envir = .GlobalEnv)
  }

  fake_cluster <- structure(list(id = "isolated"), class = "wlv_test_cluster")
  run_environment <- execution_environment$wlv_new_run_environment(
    values = list(
      my.cluster = fake_cluster,
      method_version = "demo"
    )
  )

  expect_identical(run_environment$my.cluster, fake_cluster)
  expect_identical(run_environment$method_version, "demo")
  expect_false(exists("my.cluster", envir = .GlobalEnv, inherits = FALSE))
  expect_false(exists("method_version", envir = .GlobalEnv, inherits = FALSE))
})

test_that("two script runs are isolated and never create a started sentinel", {
  global_names <- c("my.cluster", "method_version")
  global_was_present <- vapply(
    global_names,
    exists,
    logical(1),
    envir = .GlobalEnv,
    inherits = FALSE
  )
  global_values <- if (any(global_was_present)) {
    mget(global_names[global_was_present], envir = .GlobalEnv, inherits = FALSE)
  } else {
    list()
  }
  on.exit({
    created <- global_names[vapply(
      global_names,
      exists,
      logical(1),
      envir = .GlobalEnv,
      inherits = FALSE
    )]
    if (length(created)) {
      rm(list = created, envir = .GlobalEnv)
    }
    if (length(global_values)) {
      list2env(global_values, envir = .GlobalEnv)
    }
  }, add = TRUE)
  if (any(global_was_present)) {
    rm(list = global_names[global_was_present], envir = .GlobalEnv)
  }

  sandbox <- tempfile("wlv-lifecycle-")
  dir.create(sandbox)
  on.exit(unlink(sandbox, recursive = TRUE, force = TRUE), add = TRUE)

  script <- file.path(sandbox, "run.R")
  writeLines(
    c(
      "stopifnot(exists('method_version', inherits = FALSE))",
      "stopifnot(exists('my.cluster', inherits = FALSE))",
      "method_version <- paste0(method_version, '-mutated')",
      "my.cluster <- 'mutated'"
    ),
    script
  )

  seen_environments <- list()
  runner <- function(script, envir) {
    sys.source(script, envir = envir)
    seen_environments[[length(seen_environments) + 1L]] <<- envir
    invisible(NULL)
  }
  fake_cluster <- structure(list(id = "run"), class = "wlv_test_cluster")

  old_wd <- setwd(sandbox)
  on.exit(setwd(old_wd), add = TRUE)
  for (iteration in seq_len(2L)) {
    execution_environment$wlv_run_script(
      script = script,
      values = list(method_version = "demo"),
      cluster = fake_cluster,
      runner = runner
    )
  }

  expect_length(seen_environments, 2L)
  expect_false(identical(seen_environments[[1]], seen_environments[[2]]))
  expect_identical(seen_environments[[1]]$method_version, "demo-mutated")
  expect_identical(seen_environments[[2]]$method_version, "demo-mutated")
  expect_false(file.exists(file.path(sandbox, "started")))
  expect_false(exists("my.cluster", envir = .GlobalEnv, inherits = FALSE))
  expect_false(exists("method_version", envir = .GlobalEnv, inherits = FALSE))
})

test_that("preamble and nested sources share the run environment and root", {
  sandbox <- tempfile("wlv-script-root-")
  outside <- tempfile("wlv-script-outside-")
  dir.create(sandbox)
  dir.create(outside)
  on.exit(unlink(c(sandbox, outside), recursive = TRUE, force = TRUE), add = TRUE)

  preamble <- file.path(sandbox, "preamble.R")
  nested <- file.path(sandbox, "nested.R")
  script <- file.path(sandbox, "run.R")
  writeLines("helper <- function(value) paste0(value, '-ready')", preamble)
  writeLines(
    c(
      "result <- helper(method_version)",
      "observed_wd <- normalizePath(getwd())"
    ),
    nested
  )
  writeLines("source('nested.R')", script)

  old_wd <- setwd(outside)
  on.exit(setwd(old_wd), add = TRUE)
  run_environment <- execution_environment$wlv_run_script(
    script = script,
    values = list(method_version = "demo"),
    preamble = preamble,
    root = sandbox
  )

  expect_identical(run_environment$result, "demo-ready")
  expect_identical(run_environment$observed_wd, normalizePath(sandbox))
  expect_identical(normalizePath(getwd()), normalizePath(outside))
})
