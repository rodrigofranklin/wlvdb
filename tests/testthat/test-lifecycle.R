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


test_that("the atomic runtime exposes no script executor or shared run environment", {
  expect_false(exists("wlv_run_script", envir = execution_environment, inherits = FALSE))
  expect_false(exists("wlv_new_run_environment", envir = execution_environment, inherits = FALSE))
})

test_that("the native sequential apply service is deterministic", {
  service <- execution_environment$wlv_native_year_apply_service(NULL)
  value <- array(1:12, dim = c(3L, 4L))
  expect_identical(service(value, 1L, sum), base::apply(value, 1L, sum))
})
