module_runtime_environment <- new.env(parent = globalenv())
sys.source(
  file.path(wlv_test_root, "R", "lib", "module_runtime.R"),
  envir = module_runtime_environment
)

wlv_test_scalar_contract <- function(scope = "run", type = "double") {
  module_runtime_environment$wlv_resource_contract(
    scope = scope,
    axes = character(),
    value_type = type,
    unit = "test_unit_v1",
    missingness = "strict_v1"
  )
}

wlv_test_output <- function(key, contract, action = "create", predecessor = NULL) {
  module_runtime_environment$wlv_resource_output(
    module_runtime_environment$wlv_resource_ref(key, contract),
    action = action,
    predecessor = predecessor
  )
}

test_that("native module contracts are typed and registries seal deterministically", {
  runtime <- module_runtime_environment
  scalar <- wlv_test_scalar_contract()
  spec <- runtime$wlv_module_spec(
    id = "constant",
    checkpoint = 1L,
    parameters = list(
      value = runtime$wlv_module_parameter("double"),
      output = runtime$wlv_module_parameter("character")
    ),
    provides = function(args) {
      list(value = wlv_test_output(args$output, scalar))
    },
    run = function(ctx) {
      runtime$wlv_module_result(list(value = ctx$arg("value")))
    }
  )

  registry <- runtime$wlv_module_registry(list(spec))
  expect_true(environmentIsLocked(registry))
  expect_true(registry$sealed)
  expect_error(
    runtime$wlv_register_module(registry, spec),
    "sealed",
    class = "wlv_registry_error"
  )

  instances <- data.frame(
    instance_id = "constant.one",
    module_id = "constant",
    stringsAsFactors = FALSE
  )
  instances$args <- list(list(value = 3, output = "derived/value"))
  store <- runtime$wlv_new_resource_store()
  plan <- runtime$wlv_compile_module_plan(registry, instances, store)
  result <- runtime$wlv_run_module_plan(plan, store)

  expect_identical(plan$order, "constant.one")
  expect_equal(
    runtime$wlv_store_read(
      result$store,
      runtime$wlv_resource_ref("derived/value", scalar)
    ),
    3
  )
  expect_error(
    runtime$wlv_compile_module_plan(
      registry,
      list(runtime$wlv_module_instance(
        "constant.bad",
        "constant",
        list(value = 3, output = "bad", surprise = TRUE)
      )),
      store
    ),
    "unknown argument.*surprise",
    class = "wlv_preflight_error"
  )
})

test_that("resource roles and semantic companions are part of compatibility", {
  runtime <- module_runtime_environment
  value <- runtime$wlv_resource_contract(
    axes = "year",
    value_type = "array",
    unit = "test_unit_v1",
    missingness = "typed_v1",
    semantic_state = TRUE
  )
  state <- runtime$wlv_resource_contract(
    value_type = "data.frame",
    unit = "semantic_state:test_unit_v1",
    missingness = "semantic_state_v1",
    role = "semantic_state"
  )
  expect_true(value$semantic_state)
  expect_identical(value$role, "value")
  expect_false(state$semantic_state)
  expect_identical(state$role, "semantic_state")
  expect_false(runtime$wlv_runtime_contract_compatible(value, state))
  expect_error(
    runtime$wlv_resource_contract(
      role = "diagnostic",
      semantic_state = TRUE
    ),
    "Only value resources",
    class = "wlv_contract_error"
  )
})

test_that("module diagnostics are named immutable payloads", {
  runtime <- module_runtime_environment
  expect_error(
    runtime$wlv_module_result(list(), diagnostics = list(1)),
    "uniquely named list",
    class = "wlv_result_error"
  )
  expect_error(
    runtime$wlv_module_result(
      list(),
      diagnostics = data.frame(value = 1)
    ),
    "uniquely named list",
    class = "wlv_result_error"
  )
  expect_s3_class(
    runtime$wlv_module_result(
      list(value = 1),
      diagnostics = list(counts = list(value = 1L))
    ),
    "wlv_module_result"
  )
})

test_that("dynamic contracts can resolve against explicit instance metadata", {
  runtime <- module_runtime_environment
  scalar <- wlv_test_scalar_contract()
  spec <- runtime$wlv_module_spec(
    id = "instance_contract",
    checkpoint = 1L,
    requires = function(args, instance) {
      list(seed = runtime$wlv_resource_ref(
        paste0("seed/", instance$instance_id),
        scalar,
        producer = ".seed"
      ))
    },
    provides = function(args, instance) {
      list(value = wlv_test_output(
        paste0("result/", instance$instance_id),
        scalar
      ))
    },
    run = function(ctx) {
      runtime$wlv_module_result(list(value = ctx$input("seed")))
    }
  )
  registry <- runtime$wlv_module_registry(list(spec))
  store <- runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource("seed/instance.one", 7, scalar)
  ))
  plan <- runtime$wlv_compile_module_plan(
    registry,
    list(runtime$wlv_module_instance("instance.one", "instance_contract")),
    store
  )
  result <- runtime$wlv_run_module_plan(plan, store)
  expect_equal(
    runtime$wlv_store_read(
      result$store,
      runtime$wlv_resource_ref("result/instance.one", scalar)
    ),
    7
  )
})

test_that("stateful module contracts fail preflight without exact pairs", {
  runtime <- module_runtime_environment
  value_contract <- runtime$wlv_resource_contract(
    axes = "year",
    value_type = "array",
    missingness = "typed_v1",
    semantic_state = TRUE
  )
  state_contract <- runtime$wlv_resource_contract(
    value_type = "data.frame",
    role = "semantic_state"
  )
  value_ref <- runtime$wlv_resource_ref(
    "sea/sector/test",
    value_contract,
    producer = ".seed"
  )
  missing_input_pair <- runtime$wlv_module_spec(
    "missing_input_pair",
    checkpoint = 1L,
    requires = list(value = value_ref),
    run = function(ctx) runtime$wlv_module_result(list())
  )
  registry <- runtime$wlv_module_registry(list(missing_input_pair))
  value <- array(1, dim = 1L, dimnames = list(year = "2000"))
  store <- runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource("sea/sector/test", value, value_contract)
  ))
  expect_error(
    runtime$wlv_compile_module_plan(
      registry,
      list(runtime$wlv_module_instance("missing.input", "missing_input_pair")),
      store
    ),
    "without one exact semantic-state pair",
    class = "wlv_preflight_error"
  )

  missing_output_pair <- runtime$wlv_module_spec(
    "missing_output_pair",
    checkpoint = 1L,
    provides = list(value = wlv_test_output(
      "sea/sector/test",
      value_contract
    )),
    run = function(ctx) runtime$wlv_module_result(list(value = value))
  )
  registry <- runtime$wlv_module_registry(list(missing_output_pair))
  expect_error(
    runtime$wlv_compile_module_plan(
      registry,
      list(runtime$wlv_module_instance("missing.output", "missing_output_pair")),
      runtime$wlv_new_resource_store()
    ),
    "without a semantic-state pair",
    class = "wlv_preflight_error"
  )

  paired <- runtime$wlv_module_spec(
    "paired",
    checkpoint = 1L,
    provides = list(
      value = wlv_test_output("sea/sector/test", value_contract),
      state = wlv_test_output("semantic_state/sea/sector/test", state_contract)
    ),
    run = function(ctx) runtime$wlv_module_result(list(
      value = value,
      state = data.frame(year = character(), state = character())
    ))
  )
  registry <- runtime$wlv_module_registry(list(paired))
  plan <- runtime$wlv_compile_module_plan(
    registry,
    list(runtime$wlv_module_instance("paired.one", "paired")),
    runtime$wlv_new_resource_store()
  )
  expect_identical(plan$order, "paired.one")
})

test_that("the compiler derives a deterministic DAG instead of using row order", {
  runtime <- module_runtime_environment
  scalar <- wlv_test_scalar_contract()
  seed_ref <- runtime$wlv_resource_ref("seed", scalar, producer = ".seed")
  make_branch <- function(id, key, increment) {
    runtime$wlv_module_spec(
      id = id,
      checkpoint = 1L,
      requires = list(seed = seed_ref),
      provides = list(value = wlv_test_output(key, scalar)),
      run = function(ctx) {
        runtime$wlv_module_result(list(
          value = ctx$input("seed") + increment
        ))
      }
    )
  }
  alpha <- make_branch("alpha", "branch/alpha", 1)
  beta <- make_branch("beta", "branch/beta", 2)
  sink <- runtime$wlv_module_spec(
    id = "sink",
    checkpoint = 2L,
    requires = list(
      alpha = runtime$wlv_resource_ref(
        "branch/alpha",
        scalar,
        producer = "alpha.one"
      ),
      beta = runtime$wlv_resource_ref(
        "branch/beta",
        scalar,
        producer = "beta.one"
      )
    ),
    provides = list(total = wlv_test_output("total", scalar)),
    run = function(ctx) {
      runtime$wlv_module_result(list(
        total = ctx$input("alpha") + ctx$input("beta")
      ))
    }
  )
  registry <- runtime$wlv_module_registry(list(sink, beta, alpha))
  store <- runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource("seed", 10, scalar)
  ))
  instances <- list(
    runtime$wlv_module_instance("sink.one", "sink"),
    runtime$wlv_module_instance("beta.one", "beta"),
    runtime$wlv_module_instance("alpha.one", "alpha")
  )
  plan <- runtime$wlv_compile_module_plan(registry, instances, store)
  result <- runtime$wlv_run_module_plan(plan, store)

  expect_identical(plan$order, c("alpha.one", "beta.one", "sink.one"))
  expect_equal(
    runtime$wlv_store_read(result$store, runtime$wlv_resource_ref("total", scalar)),
    23
  )
  expect_identical(result$trace$instance_id, plan$order)
})

test_that("contexts expose only declared immutable capabilities", {
  runtime <- module_runtime_environment
  context <- runtime$wlv_runtime_context(
    inputs = list(declared = c(1, 2)),
    input_names = "declared",
    args = list(scale = 2L),
    argument_names = "scale",
    services = list(round = round),
    service_names = "round",
    partition = NULL,
    instance_id = "context.test"
  )

  expect_true(environmentIsLocked(context))
  expect_error(context$undeclared <- TRUE, "locked environment")
  expect_error(
    context$input("hidden"),
    "attempted undeclared input",
    class = "wlv_context_error"
  )
  expect_error(
    context$arg("hidden"),
    "attempted undeclared argument",
    class = "wlv_context_error"
  )
  expect_error(
    context$service("hidden"),
    "attempted undeclared service",
    class = "wlv_context_error"
  )
  local_value <- context$input("declared")
  local_value[[1L]] <- 99
  expect_identical(context$input("declared"), c(1, 2))
  expect_identical(context$arg("scale"), 2L)
  expect_identical(context$service("round"), round)
})

test_that("create, patch, and replace form one validated resource generation chain", {
  runtime <- module_runtime_environment
  matrix_contract <- runtime$wlv_resource_contract(
    axes = c("row", "column"),
    value_type = "array",
    unit = "test_unit_v1",
    missingness = "strict_v1"
  )
  original <- array(
    1:4,
    dim = c(2L, 2L),
    dimnames = list(row = c("r1", "r2"), column = c("c1", "c2"))
  )
  seed <- runtime$wlv_resource_ref(
    "matrix",
    matrix_contract,
    producer = ".seed"
  )
  patched <- runtime$wlv_resource_ref(
    "matrix",
    matrix_contract,
    producer = "patch.matrix"
  )
  patcher <- runtime$wlv_module_spec(
    id = "matrix_patch",
    checkpoint = 1L,
    requires = list(matrix = seed),
    provides = list(matrix = wlv_test_output(
      "matrix",
      matrix_contract,
      action = "patch",
      predecessor = seed
    )),
    run = function(ctx) {
      runtime$wlv_module_result(list(
        matrix = runtime$wlv_resource_patch(
          list(row = "r1", column = "c2"),
          99L
        )
      ))
    }
  )
  replacer <- runtime$wlv_module_spec(
    id = "matrix_replace",
    checkpoint = 2L,
    requires = list(matrix = patched),
    provides = list(matrix = wlv_test_output(
      "matrix",
      matrix_contract,
      action = "replace",
      predecessor = patched
    )),
    run = function(ctx) {
      runtime$wlv_module_result(list(matrix = ctx$input("matrix") * 2L))
    }
  )
  registry <- runtime$wlv_module_registry(list(replacer, patcher))
  store <- runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource("matrix", original, matrix_contract)
  ))
  plan <- runtime$wlv_compile_module_plan(
    registry,
    list(
      runtime$wlv_module_instance("replace.matrix", "matrix_replace"),
      runtime$wlv_module_instance("patch.matrix", "matrix_patch")
    ),
    store
  )
  result <- runtime$wlv_run_module_plan(
    plan,
    store,
    retain_history = TRUE
  )

  expected <- original
  expected["r1", "c2"] <- 99L
  expected <- expected * 2L
  expect_identical(
    runtime$wlv_store_read(
      result$store,
      runtime$wlv_resource_ref("matrix", matrix_contract)
    ),
    expected
  )
  expect_identical(
    runtime$wlv_store_read(store, runtime$wlv_resource_ref("matrix", matrix_contract)),
    original
  )
  expect_identical(
    runtime$wlv_store_catalog(result$store)$action,
    c("seed", "patch", "replace")
  )
})

test_that("runner prunes dead generations but retains future locators and terminals", {
  runtime <- module_runtime_environment
  scalar <- wlv_test_scalar_contract()
  created <- runtime$wlv_resource_ref(
    "chain/value",
    scalar,
    producer = "create.value"
  )
  replaced <- runtime$wlv_resource_ref(
    "chain/value",
    scalar,
    producer = "replace.value"
  )
  creator <- runtime$wlv_module_spec(
    "chain_create",
    checkpoint = 1L,
    provides = list(value = wlv_test_output("chain/value", scalar)),
    run = function(ctx) runtime$wlv_module_result(list(value = 2))
  )
  replacer <- runtime$wlv_module_spec(
    "chain_replace",
    checkpoint = 2L,
    requires = list(value = created),
    provides = list(value = wlv_test_output(
      "chain/value",
      scalar,
      action = "replace",
      predecessor = created
    )),
    run = function(ctx) {
      runtime$wlv_module_result(list(value = ctx$input("value") * 10))
    }
  )
  consumer <- runtime$wlv_module_spec(
    "chain_consumer",
    checkpoint = 3L,
    requires = list(
      original = created,
      current = replaced
    ),
    provides = list(value = wlv_test_output("chain/observed", scalar)),
    run = function(ctx) {
      runtime$wlv_module_result(list(
        value = ctx$input("original") + ctx$input("current")
      ))
    }
  )
  registry <- runtime$wlv_module_registry(list(consumer, replacer, creator))
  store <- runtime$wlv_new_resource_store()
  plan <- runtime$wlv_compile_module_plan(
    registry,
    list(
      runtime$wlv_module_instance("consume.value", "chain_consumer"),
      runtime$wlv_module_instance("replace.value", "chain_replace"),
      runtime$wlv_module_instance("create.value", "chain_create")
    ),
    store
  )

  expect_false(exists("base_store", envir = plan, inherits = FALSE))
  expect_identical(plan$base_store_token, store$identity_token)
  expect_identical(
    names(plan$terminal_catalog),
    c(
      "locator_id", "key", "partition", "producer", "role",
      "semantic_state"
    )
  )
  expect_true(all(plan$terminal_catalog$role == "value"))
  expect_false(any(plan$terminal_catalog$semantic_state))
  observed_id <- plan$terminal_catalog$locator_id[
    plan$terminal_catalog$key == "chain/observed"
  ]
  replacement_id <- plan$terminal_catalog$locator_id[
    plan$terminal_catalog$key == "chain/value"
  ]
  expect_setequal(
    plan$terminal_catalog$locator_id,
    c(observed_id, replacement_id)
  )
  created_id <- runtime$wlv_runtime_locator_id(
    "chain/value",
    NULL,
    "create.value"
  )
  expect_identical(unname(plan$liveness$produced_at[[created_id]]), 1L)
  expect_identical(unname(plan$liveness$last_use[[created_id]]), 3L)
  expect_true(observed_id %in% plan$liveness$release_after[[3L]])

  same_catalog <- runtime$wlv_new_resource_store()
  expect_identical(
    runtime$wlv_store_catalog(same_catalog),
    runtime$wlv_store_catalog(store)
  )
  expect_error(
    runtime$wlv_run_module_plan(plan, same_catalog),
    "identity",
    class = "wlv_runner_error"
  )
  expect_error(
    runtime$wlv_run_module_plan(
      plan,
      store,
      retain_locator_ids = created_id
    ),
    "not a terminal",
    class = "wlv_runner_error"
  )

  compact <- runtime$wlv_run_module_plan(plan, store)
  selected <- runtime$wlv_run_module_plan(
    plan,
    store,
    retain_locator_ids = observed_id
  )
  history <- runtime$wlv_run_module_plan(
    plan,
    store,
    retain_history = TRUE,
    retain_locator_ids = observed_id
  )
  expect_false(identical(compact$store$identity_token, store$identity_token))

  expect_identical(
    runtime$wlv_store_read(
      compact$store,
      runtime$wlv_resource_ref("chain/observed", scalar)
    ),
    22
  )
  compact_catalog <- runtime$wlv_store_catalog(compact$store)
  expect_setequal(
    compact_catalog$producer,
    c("consume.value", "replace.value")
  )
  expect_identical(
    compact_catalog$predecessor[compact_catalog$producer == "replace.value"],
    "chain/value@create.value"
  )
  terminal_ids <- runtime$wlv_runtime_locator_ids(plan$terminals)
  compact_ids <- vapply(seq_len(nrow(compact_catalog)), function(index) {
    runtime$wlv_runtime_locator_id(
      compact_catalog$key[[index]],
      if (nzchar(compact_catalog$partition[[index]])) {
        compact_catalog$partition[[index]]
      } else {
        NULL
      },
      compact_catalog$producer[[index]]
    )
  }, character(1L))
  expect_setequal(compact_ids, terminal_ids)
  expect_error(
    runtime$wlv_store_read(compact$store, created),
    "is not available",
    class = "wlv_store_error"
  )

  selected_catalog <- runtime$wlv_store_catalog(selected$store)
  expect_identical(selected_catalog$producer, "consume.value")
  expect_identical(
    runtime$wlv_store_read(
      selected$store,
      runtime$wlv_resource_ref("chain/observed", scalar)
    ),
    22
  )
  expect_error(
    runtime$wlv_store_read(selected$store, replaced),
    "is not available",
    class = "wlv_store_error"
  )

  history_catalog <- runtime$wlv_store_catalog(history$store)
  expect_setequal(
    history_catalog$producer,
    c("consume.value", "create.value", "replace.value")
  )
  expect_identical(compact$trace, history$trace)
  expect_identical(compact$trace, selected$trace)
})

test_that("runner rejects an altered fork of its preflighted store", {
  runtime <- module_runtime_environment
  scalar <- wlv_test_scalar_contract()
  seed <- runtime$wlv_resource_ref(
    "identity/value",
    scalar,
    producer = ".seed"
  )
  copier <- runtime$wlv_module_spec(
    "identity_copy",
    checkpoint = 1L,
    requires = list(value = seed),
    provides = list(value = wlv_test_output("identity/result", scalar)),
    run = function(ctx) {
      runtime$wlv_module_result(list(value = ctx$input("value")))
    }
  )
  registry <- runtime$wlv_module_registry(list(copier))
  store <- runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource("identity/value", 1, scalar)
  ))
  plan <- runtime$wlv_compile_module_plan(
    registry,
    list(runtime$wlv_module_instance("identity.copy", "identity_copy")),
    store
  )
  altered <- runtime$wlv_runtime_fork_store(store)
  locator_id <- runtime$wlv_runtime_locator_id(
    "identity/value",
    NULL,
    ".seed"
  )
  altered$entries[[locator_id]]$value <- 99
  runtime$wlv_seal_resource_store(altered)

  expect_identical(
    runtime$wlv_store_catalog(altered),
    runtime$wlv_store_catalog(store)
  )
  expect_false(identical(altered$identity_token, store$identity_token))
  expect_error(
    runtime$wlv_run_module_plan(plan, altered),
    "identity",
    class = "wlv_runner_error"
  )
})

test_that("preflight rejects missing providers, forks, cycles, and checkpoint reversal", {
  runtime <- module_runtime_environment
  scalar <- wlv_test_scalar_contract()
  missing_consumer <- runtime$wlv_module_spec(
    "missing_consumer",
    checkpoint = 1L,
    requires = list(value = runtime$wlv_resource_ref("absent", scalar)),
    run = function(ctx) runtime$wlv_module_result(list())
  )
  registry <- runtime$wlv_module_registry(list(missing_consumer))
  store <- runtime$wlv_new_resource_store()
  expect_error(
    runtime$wlv_compile_module_plan(
      registry,
      list(runtime$wlv_module_instance("missing.one", "missing_consumer")),
      store
    ),
    "requires missing resource",
    class = "wlv_preflight_error"
  )

  seed <- runtime$wlv_resource_ref("value", scalar, producer = ".seed")
  make_replacement <- function(id) {
    runtime$wlv_module_spec(
      id,
      checkpoint = 1L,
      provides = list(value = wlv_test_output(
        "value",
        scalar,
        action = "replace",
        predecessor = seed
      )),
      run = function(ctx) runtime$wlv_module_result(list(value = 1))
    )
  }
  fork_registry <- runtime$wlv_module_registry(list(
    make_replacement("fork_a"),
    make_replacement("fork_b")
  ))
  seeded <- runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource("value", 0, scalar)
  ))
  expect_error(
    runtime$wlv_compile_module_plan(
      fork_registry,
      list(
        runtime$wlv_module_instance("fork.a", "fork_a"),
        runtime$wlv_module_instance("fork.b", "fork_b")
      ),
      seeded
    ),
    "forks after provider",
    class = "wlv_preflight_error"
  )

  cycle_a <- runtime$wlv_module_spec(
    "cycle_a",
    checkpoint = 1L,
    requires = list(b = runtime$wlv_resource_ref(
      "cycle/b",
      scalar,
      producer = "cycle.b"
    )),
    provides = list(a = wlv_test_output("cycle/a", scalar)),
    run = function(ctx) runtime$wlv_module_result(list(a = ctx$input("b")))
  )
  cycle_b <- runtime$wlv_module_spec(
    "cycle_b",
    checkpoint = 1L,
    requires = list(a = runtime$wlv_resource_ref(
      "cycle/a",
      scalar,
      producer = "cycle.a"
    )),
    provides = list(b = wlv_test_output("cycle/b", scalar)),
    run = function(ctx) runtime$wlv_module_result(list(b = ctx$input("a")))
  )
  cycle_registry <- runtime$wlv_module_registry(list(cycle_a, cycle_b))
  expect_error(
    runtime$wlv_compile_module_plan(
      cycle_registry,
      list(
        runtime$wlv_module_instance("cycle.a", "cycle_a"),
        runtime$wlv_module_instance("cycle.b", "cycle_b")
      ),
      store
    ),
    "cycle.a -> cycle.b -> cycle.a|cycle.b -> cycle.a -> cycle.b",
    class = "wlv_preflight_error"
  )

  late <- runtime$wlv_module_spec(
    "late",
    checkpoint = 2L,
    provides = list(value = wlv_test_output("late/value", scalar)),
    run = function(ctx) runtime$wlv_module_result(list(value = 1))
  )
  early <- runtime$wlv_module_spec(
    "early",
    checkpoint = 1L,
    requires = list(value = runtime$wlv_resource_ref(
      "late/value",
      scalar,
      producer = "late.one"
    )),
    run = function(ctx) runtime$wlv_module_result(list())
  )
  checkpoint_registry <- runtime$wlv_module_registry(list(late, early))
  expect_error(
    runtime$wlv_compile_module_plan(
      checkpoint_registry,
      list(
        runtime$wlv_module_instance("early.one", "early"),
        runtime$wlv_module_instance("late.one", "late")
      ),
      store
    ),
    "Checkpoint violation",
    class = "wlv_preflight_error"
  )
})

test_that("io-period collectors require exact declared coverage", {
  runtime <- module_runtime_environment
  period_contract <- wlv_test_scalar_contract("io_period")
  run_contract <- wlv_test_scalar_contract("run")
  period <- runtime$wlv_module_spec(
    "period_value",
    scope = "io_period",
    checkpoint = 1L,
    parameters = list(value = runtime$wlv_module_parameter("double")),
    provides = list(value = wlv_test_output("period/value", period_contract)),
    run = function(ctx) {
      runtime$wlv_module_result(list(value = ctx$arg("value")))
    }
  )
  collector <- runtime$wlv_module_spec(
    "period_collector",
    scope = "run",
    checkpoint = 2L,
    requires = list(values = runtime$wlv_resource_ref(
      "period/value",
      period_contract,
      collect = TRUE
    )),
    provides = list(total = wlv_test_output("period/total", run_contract)),
    run = function(ctx) {
      runtime$wlv_module_result(list(
        total = sum(unlist(ctx$input("values"), use.names = FALSE))
      ))
    }
  )
  registry <- runtime$wlv_module_registry(list(collector, period))
  store <- runtime$wlv_new_resource_store()
  complete <- list(
    runtime$wlv_module_instance(
      "period.value",
      "period_value",
      list(value = 2),
      partition = "2001"
    ),
    runtime$wlv_module_instance("collector.one", "period_collector"),
    runtime$wlv_module_instance(
      "period.value",
      "period_value",
      list(value = 1),
      partition = "2000"
    )
  )
  plan <- runtime$wlv_compile_module_plan(
    registry,
    complete,
    store,
    partitions = c("2000", "2001")
  )
  result <- runtime$wlv_run_module_plan(plan, store)
  expect_identical(
    plan$order,
    c("period.value@2000", "period.value@2001", "collector.one")
  )
  expect_identical(
    result$trace$instance_id,
    c("period.value", "period.value", "collector.one")
  )
  expect_equal(
    runtime$wlv_store_read(
      result$store,
      runtime$wlv_resource_ref("period/total", run_contract)
    ),
    3
  )
  expect_error(
    runtime$wlv_compile_module_plan(
      registry,
      complete[-1L],
      store,
      partitions = c("2000", "2001")
    ),
    "missing resource.*partition `2001`",
    class = "wlv_preflight_error"
  )
})

test_that("runner commits no generation when a later output or module fails", {
  runtime <- module_runtime_environment
  scalar <- wlv_test_scalar_contract()
  first <- runtime$wlv_module_spec(
    "first",
    checkpoint = 1L,
    provides = list(value = wlv_test_output("first/value", scalar)),
    run = function(ctx) runtime$wlv_module_result(list(value = 1))
  )
  invalid <- runtime$wlv_module_spec(
    "invalid",
    checkpoint = 2L,
    requires = list(value = runtime$wlv_resource_ref(
      "first/value",
      scalar,
      producer = "first.one"
    )),
    provides = list(
      good = wlv_test_output("second/good", scalar),
      bad = wlv_test_output("second/bad", scalar)
    ),
    run = function(ctx) {
      runtime$wlv_module_result(list(
        good = ctx$input("value") + 1,
        bad = "not numeric"
      ))
    }
  )
  registry <- runtime$wlv_module_registry(list(first, invalid))
  store <- runtime$wlv_new_resource_store()
  plan <- runtime$wlv_compile_module_plan(
    registry,
    list(
      runtime$wlv_module_instance("invalid.one", "invalid"),
      runtime$wlv_module_instance("first.one", "first")
    ),
    store
  )
  before <- runtime$wlv_store_catalog(store)
  expect_error(
    runtime$wlv_run_module_plan(plan, store),
    "does not satisfy value type",
    class = "wlv_result_error"
  )
  expect_identical(runtime$wlv_store_catalog(store), before)
  expect_error(
    runtime$wlv_new_resource_store(list(
      runtime$wlv_seed_resource(
        "mutable",
        list(environment()),
        runtime$wlv_resource_contract(value_type = "list")
      )
    )),
    "mutable reference",
    class = "wlv_result_error"
  )
})

test_that("parent resources retain their declared producer generation", {
  runtime <- module_runtime_environment
  contract <- wlv_test_scalar_contract()
  store <- runtime$wlv_new_resource_store(list(
    runtime$wlv_seed_resource(
      "parent/value",
      42,
      contract,
      producer = "original.module"
    )
  ))
  catalog <- runtime$wlv_store_catalog(store)
  expect_identical(catalog$producer, "original.module")
  expect_identical(catalog$action, "inherited")
  expect_identical(catalog$role, "value")
  expect_false(catalog$semantic_state)
  expect_identical(
    runtime$wlv_store_read(
      store,
      runtime$wlv_resource_ref(
        "parent/value",
        contract,
        producer = "original.module"
      )
    ),
    42
  )
})
