# Native common indicator modules -----------------------------------------

# Indicadores públicos usam ano × setor × país. As matrizes de origem usam
# ano × fornecedor × usuário/demanda; agrupar exige conservar a interpretação
# econômica desses eixos. As unidades vêm do contrato e das entradas, não da
# operação de soma. Guias: docs/guide-pt.md e docs/guide-en.md.
#
# Para importações, o grupo identifica setor do produto fornecido e país que o
# recebe, inclusive em demanda final. Não é simplesmente o setor comprador.
# A verificação exige que cada célula da WIOT pertença exatamente a um grupo.
wlv_native_import_group_indices_assert <- function(indices, nums) {
  group_lengths <- lengths(indices)
  expected_count <- nums$input * nums$output
  expected_names <- base::as.character(
    rep(seq_len(nums$countries), each = nums$sectors) +
      rep(seq_len(nums$sectors), times = nums$countries) / 1000
  )
  canonical <- inherits(indices, "wlv_import_group_indices") &&
    length(indices) == nums$input &&
    identical(names(indices), expected_names) &&
    all(group_lengths > 0L) &&
    all(base::vapply(indices, is.integer, logical(1L))) &&
    sum(group_lengths) == expected_count
  if (canonical) {
    flat <- base::unlist(indices, recursive = FALSE, use.names = FALSE)
    canonical <- length(flat) == expected_count && !anyNA(flat) &&
      min(flat) == 1L && max(flat) == expected_count &&
      all(base::tabulate(flat, nbins = expected_count) == 1L) &&
      all(!base::vapply(
        indices,
        is.unsorted,
        logical(1L),
        strictly = TRUE
      ))
  }
  if (canonical) {
    canonical <- all(base::vapply(seq_along(indices), function(group) {
      index <- indices[[group]]
      input_row <- ((index - 1L) %% nums$input) + 1L
      output_column <- ((index - 1L) %/% nums$input) + 1L
      input_sector <- ((input_row - 1L) %% nums$sectors) + 1L
      output_country <- ifelse(
        output_column <= nums$countries_sectors,
        ((output_column - 1L) %/% nums$sectors) + 1L,
        ((output_column - nums$countries_sectors - 1L) %/% nums$demands) + 1L
      )
      expected_group <-
        ((output_country - 1L) * nums$sectors) + input_sector
      all(expected_group == group)
    }, logical(1L)))
  }
  if (!canonical) {
    stop("Import aggregation requires canonical import-group indices.",
      call. = FALSE
    )
  }
  invisible(indices)
}

wlv_native_sum_import_groups <- function(value, indices) {
  base::array(
    base::unlist(base::lapply(
      indices,
      function(index) base::sum(value[index], na.rm = TRUE)
    ), recursive = FALSE, use.names = FALSE),
    dim = length(indices),
    dimnames = list(names(indices))
  )
}

# Hipótese dos dois métodos públicos: uma hora conta como uma hora de trabalho
# abstrato, pois todos os multiplicadores de complexidade/intensidade são 1.
# É uma escolha metodológica explícita, não evidência de trabalho homogêneo.
wlv_native_complex_multiplier_spec <- function(id, indicator, employee = FALSE) {
  label <- if (employee) " (employees only)" else ""
  metadata <- wlv_native_indicator_metadata_row(
    indicator,
    paste0("Complex labour multiplier", label),
    if (employee) {
      "Multiplier of labour of emplyees accordingly it's complexty and intensity."
    } else {
      "Multiplier of labour accordingly it's complexty and intensity."
    },
    "The standard treatment is to consider all labour as equal.",
    "Others",
    "index"
  )
  wlv_native_indicator_spec(
    id,
    checkpoint = 2L,
    requires = wlv_native_run_ref("dimensions/lists", "lists", "list"),
    metadata = metadata,
    run = local({
      output_indicator <- indicator
      function(ctx) {
        lists <- ctx$input("lists")
        value <- array(
          1,
          dim = c(length(lists$years), length(lists$sectors), length(lists$countries)),
          dimnames = list(
            year = lists$years,
            sector = lists$sectors,
            country = lists$countries
          )
        )
        wlv_module_result(outputs = list(value = value))
      }
    })
  )
}

wlv_indicator_complex_labour_multiplier_emp_spec <- function() {
  wlv_native_complex_multiplier_spec(
    "indicator.complex_labour_multiplier.emp.r.un",
    "complex_labour_multiplier.emp.r.un"
  )
}
wlv_indicator_complex_labour_multiplier_empe_spec <- function() {
  wlv_native_complex_multiplier_spec(
    "indicator.complex_labour_multiplier.empe.r.un",
    "complex_labour_multiplier.empe.r.un",
    employee = TRUE
  )
}

# Trabalho abstrato = horas totais × multiplicador sem unidade. emp inclui todos
# os ocupados; empe somente empregados. A grandeza mv mantém a escala das horas
# normalizadas. O filtro de setores produtivos é aplicado depois, quando exigido.
wlv_native_abstract_labour_spec <- function(employee = FALSE) {
  person <- if (employee) "empe" else "emp"
  indicator <- paste0("abstract_labour.", person, ".s.mv")
  hours <- paste0("hours_worked.", person, ".s.hr")
  multiplier <- paste0("complex_labour_multiplier.", person, ".r.un")
  metadata <- wlv_native_indicator_metadata_row(
    indicator,
    if (employee) "Total abstract labour of emplyees" else "Total abstract labour of persons engaged",
    paste0(
      "Total abstract labour of ", if (employee) "emplyees" else "persons engaged",
      " is the hours worked by ", if (employee) "employees" else "persons engaged",
      " converted in abstract labour by the complex labour multiplier."
    ),
    NA_character_,
    "Labour and employment",
    "value"
  )
  wlv_native_indicator_spec(
    paste0("indicator.", indicator),
    checkpoint = 2L,
    requires = c(
      wlv_native_indicator_ref(hours, "hours"),
      wlv_native_indicator_ref(multiplier, "multiplier")
    ),
    metadata = metadata,
    run = function(ctx) {
      value <- ctx$input("hours") * ctx$input("multiplier")
      value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
      wlv_module_result(outputs = list(value = value))
    }
  )
}

wlv_indicator_abstract_labour_emp_s_mv_spec <- function() {
  wlv_native_abstract_labour_spec(FALSE)
}
wlv_indicator_abstract_labour_empe_s_mv_spec <- function() {
  wlv_native_abstract_labour_spec(TRUE)
}

# Produto novo em valor: trabalho abstrato apenas nos setores produtivos.
# Multiplicar pela classificação 0/1 zera os demais por hipótese do método;
# não declara que seu valor adicionado monetário observado seja zero.
wlv_indicator_gdp_s_mv_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.gdp.s.mv",
  checkpoint = 2L,
  requires = c(
    wlv_native_indicator_ref("abstract_labour.emp.s.mv", "abstract_labour"),
    wlv_native_run_ref("dimensions/rows", "rows", "data.frame"),
    wlv_native_run_ref("dimensions/lists", "lists", "list")
  ),
  metadata = wlv_native_indicator_metadata_row(
    "gdp.s.mv",
    "Gross Domestic Product (magnitude of value)",
    paste0(
      "Gross Domestic Product calculated by value added approach represents ",
      "all value created by residents. Data are in magnitude of value, thus ",
      "it enconpass productive sectors only."
    ),
    "Obtained from the sum of abstract labour performed in productive sectors.",
    "Product",
    "value"
  ),
  run = function(ctx) {
    value <- ctx$input("abstract_labour") * rep(
      ctx$input("rows")$productive,
      each = length(ctx$input("lists")$years)
    )
    value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
    wlv_module_result(outputs = list(value = value))
  }
)
}

# Recorta o VA monetário da SEA pela mesma classificação produtiva. Esta série
# continua a preços de mercado; o recorte não é uma conversão de USD para mv.
wlv_indicator_gdp_p_s_us_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.gdp.p.s.us",
  checkpoint = 2L,
  requires = c(
    wlv_native_indicator_ref("gdp.s.us", "gdp"),
    wlv_native_run_ref("dimensions/rows", "rows", "data.frame"),
    wlv_native_run_ref("dimensions/lists", "lists", "list")
  ),
  metadata = wlv_native_indicator_metadata_row(
    "gdp.p.s.us",
    "Gross domestic product of productive sectors (USD)",
    paste0(
      "Gross Domestic Product of productive sectors is the sum of the ",
      "traditional national accont calculated by value added approach represents ",
      "all value created by residents. "
    ),
    "Obtained from the sum of GDP of productive sectors.",
    "Product",
    "usd"
  ),
  run = function(ctx) {
    value <- ctx$input("gdp") * rep(
      ctx$input("rows")$productive,
      each = length(ctx$input("lists")$years)
    )
    value <- wlv_native_with_named_axes(value, c("year", "sector", "country"))
    wlv_module_result(outputs = list(value = value))
  }
)
}

# Stage 4: matrices to sector indicators ----------------------------------

wlv_native_stage4_matrix_requirements <- function(resource, source = FALSE) {
  c(
    if (source) wlv_native_source_io_ref("matrix") else wlv_native_io_ref(resource, "matrix"),
    wlv_native_run_ref("dimensions/lists", "lists", "list"),
    wlv_native_run_ref("dimensions/nums", "nums", "list")
  )
}

# Somar destinos de cada fornecedor produz sua produção bruta; com filtro trade,
# somente exportações. Ex.: uma linha com vendas domésticas 8 e externas 2 dá
# produção 10 ou exportações 2, na unidade da matriz (USD ou mv).
# A fábrica atende todas as instâncias rowsum abaixo e preserva os anos do bloco.
wlv_native_stage4_rowsum_spec <- function(
    id,
    resource,
    metadata,
    source = FALSE,
    filter_name = NULL) {
  requirements <- wlv_native_stage4_matrix_requirements(resource, source)
  if (!is.null(filter_name)) {
    requirements <- c(
      requirements,
      list(filters = wlv_resource_ref(
        "dimensions/io_filters",
        wlv_native_filters_contract(),
        producer = wlv_runtime_seed_producer()
      ))
    )
  }
  wlv_native_indicator_spec(
    id,
    checkpoint = 4L,
    scope = "io_period",
    requires = requirements,
    metadata = metadata,
    run = local({
      selected_filter <- filter_name
      function(ctx) {
        matrix_value <- ctx$input("matrix")
        lists <- wlv_native_partition_lists(matrix_value, ctx$input("lists"))
        nums <- ctx$input("nums")
        year_count <- dim(matrix_value)[[1L]]
        if (!is.null(selected_filter)) {
          factor <- ctx$input("filters")[selected_filter, , ]
          matrix_value <- matrix_value * rep(factor, each = year_count)
        }
        value <- aperm(
          apply(
            array(matrix_value, dim = c(year_count, nums$input, nums$output)),
            1L,
            rowSums,
            na.rm = TRUE
          ),
          c(2L, 1L)
        )
        value <- wlv_native_sector_array(value, lists)
        wlv_module_result(outputs = list(value = value))
      }
    })
  )
}

wlv_indicator_gross_output_s_mv_spec <- function() {
  wlv_native_stage4_rowsum_spec(
  "indicator.gross_output.s.mv",
  "values",
  wlv_native_indicator_metadata_row(
    "gross_output.s.mv",
    "Gross output (magnitude of value)",
    paste0(
      "Gross output is the sum of value of all goods and services produced by ",
      "residents, i.e., the total embodied productive labour presented in all ",
      "commodities. It includes the value added (variable capital and surplus ",
      "value) and the value of intermediate consumption (constant capital)."
    ),
    NA_character_, "Product", "usd"
  )
)
}

wlv_indicator_exports_s_mv_spec <- function() {
  wlv_native_stage4_rowsum_spec(
  "indicator.exports.s.mv",
  "values",
  wlv_native_indicator_metadata_row(
    "exports.s.mv", "Exports of goods and services (magnitude of value)",
    paste0("Exports of goods and services represent the socially necessary ",
      "labour-time to produce all goods and other market services provided to the rest of the world."),
    "Obtained from the sum of embodied productive labour of all commodities provided to other countries.",
    "International trade", "value"
  ),
  filter_name = "trade"
)
}

wlv_indicator_exports_s_us_spec <- function() {
  wlv_native_stage4_rowsum_spec(
  "indicator.exports.s.us",
  "source_io",
  wlv_native_indicator_metadata_row(
    "exports.s.us", "Exports of goods and services (USD)",
    "Exports of goods and services represent the sum of prices of all goods and other market services provided to the rest of the world.",
    NA_character_, "International trade", "usd"
  ),
  source = TRUE,
  filter_name = "trade"
)
}

# Importações são atribuídas ao país de destino e ao setor do produto importado.
# Filtrar trade exclui operações domésticas; os índices canônicos somam usos
# intermediários e finais por essa chave, sem duplicá-los nem trocar origens.
wlv_native_stage4_import_spec <- function(id, resource, metadata, source = FALSE) {
  wlv_native_indicator_spec(
    id,
    checkpoint = 4L,
    scope = "io_period",
    requires = c(
      wlv_native_stage4_matrix_requirements(resource, source),
      list(filters = wlv_resource_ref(
        "dimensions/io_filters",
        wlv_native_filters_contract(),
        producer = wlv_runtime_seed_producer()
      )),
      list(import_group_indices = wlv_resource_ref(
        "dimensions/import_group_indices",
        wlv_native_control_contract("list"),
        producer = wlv_runtime_seed_producer()
      ))
    ),
    services = "year_apply",
    metadata = metadata,
    run = function(ctx) {
      matrix_value <- ctx$input("matrix")
      lists <- wlv_native_partition_lists(matrix_value, ctx$input("lists"))
      nums <- ctx$input("nums")
      filters <- ctx$input("filters")
      import_group_indices <- ctx$input("import_group_indices")
      wlv_native_import_group_indices_assert(import_group_indices, nums)
      year_count <- dim(matrix_value)[[1L]]
      value <- matrix_value * rep(filters["trade", , ], each = year_count)
      value <- ctx$service("year_apply")(
        array(value, dim = c(year_count, nums$input, nums$output)),
        1L,
        wlv_native_sum_import_groups,
        import_group_indices
      )
      value <- aperm(value, c(2L, 1L))
      value <- wlv_native_sector_array(value, lists)
      wlv_module_result(outputs = list(value = value))
    }
  )
}

wlv_indicator_imports_s_mv_spec <- function() {
  wlv_native_stage4_import_spec(
  "indicator.imports.s.mv",
  "values",
  wlv_native_indicator_metadata_row(
    "imports.s.mv", "Imports of goods and services (magnitude of value)",
    "Imports of goods and services represent the socially necessary labour-time to produce all goods and other market services received from the rest of the world.",
    "Obtained from the sum of embodied productive labour of all commodities received from other countries.",
    "International trade", "value"
  )
)
}
wlv_indicator_imports_s_us_spec <- function() {
  wlv_native_stage4_import_spec(
  "indicator.imports.s.us",
  "source_io",
  wlv_native_indicator_metadata_row(
    "imports.s.us", "Imports of goods and services (USD)",
    "Imports of goods and services represent the sum of prices of all goods and other market services received from the rest of the world.",
    NA_character_, "International trade", "usd"
  ),
  source = TRUE
)
}

# O saldo de transferências é transferência nas exportações menos transferência
# nas importações. Positivo = valor apropriado do exterior; negativo = cedido.
# productive limita o cálculo a mercadorias de fornecedores produtivos; a série
# total também inclui fluxos de atividades classificadas como não produtivas.
wlv_native_stage4_trade_transfer_spec <- function(id, productive, metadata) {
  wlv_native_indicator_spec(
    id,
    checkpoint = 4L,
    scope = "io_period",
    requires = c(
      wlv_native_io_ref("transfers_values", "transfers"),
      list(filters = wlv_resource_ref(
        "dimensions/io_filters",
        wlv_native_filters_contract(),
        producer = wlv_runtime_seed_producer()
      )),
      list(import_group_indices = wlv_resource_ref(
        "dimensions/import_group_indices",
        wlv_native_control_contract("list"),
        producer = wlv_runtime_seed_producer()
      )),
      wlv_native_run_ref("dimensions/lists", "lists", "list"),
      wlv_native_run_ref("dimensions/nums", "nums", "list")
    ),
    services = "year_apply",
    metadata = metadata,
    run = local({
      productive_only <- productive
      function(ctx) {
        transfers <- ctx$input("transfers")
        filters <- ctx$input("filters")
        nums <- ctx$input("nums")
        import_group_indices <- ctx$input("import_group_indices")
        wlv_native_import_group_indices_assert(import_group_indices, nums)
        lists <- wlv_native_partition_lists(transfers, ctx$input("lists"))
        year_count <- dim(transfers)[[1L]]
        if (productive_only) {
          transfers <- transfers * rep(
            filters["productive_sectors", , ],
            each = year_count
          )
        }
        shaped <- array(transfers, dim = c(year_count, nums$input, nums$output))
        exports <- apply(shaped, 1L, rowSums, na.rm = TRUE)
        imports <- ctx$service("year_apply")(
          shaped,
          1L,
          wlv_native_sum_import_groups,
          import_group_indices
        )
        value <- aperm(exports - imports, c(2L, 1L))
        value <- wlv_native_sector_array(value, lists)
        wlv_module_result(outputs = list(value = value))
      }
    })
  )
}

wlv_indicator_trade_transfers_s_mv_spec <- function() {
  wlv_native_stage4_trade_transfer_spec(
  "indicator.trade_transfers.s.mv",
  FALSE,
  wlv_native_indicator_metadata_row(
    "trade_transfers.s.mv", "Transfer of value through trade",
    paste0(
      "Transfer of value through trade represents the value received from (if positive) or sent to (if negative) to the rest of the world as a result of the diference between the magnitude of value and the value represented by the prices of commodities. ",
      "This data enconpass two kinds of value transfers: transfers originated from unproductive sectors, in such case the amount of money received/sent represents value, but no value are given or received in return; transfers originated from productive sectors, in this case the amount of money received (in exports) or sent (in imports) can represent an amount of value distintic of the actualy abstract labour embodied in commodities traded."
    ),
    NA_character_, "International trade", "value"
  )
)
}
wlv_indicator_trade_transfers_p_s_mv_spec <- function() {
  wlv_native_stage4_trade_transfer_spec(
  "indicator.trade_transfers.p.s.mv",
  TRUE,
  wlv_native_indicator_metadata_row(
    "trade_transfers.p.s.mv", "Transfer of value through trade (productive sectors)",
    "Transfer of value through trade in productive sectors represents the value received from (if positive) or sent to (if negative) to the rest of the world as a result of the diference between the value represented by the amount of money received (from exports) or sent (from imports) and the actually abstract labour embodied in commodities traded. This data is equivalent of what some authors call \"unequal exchange\" (Bettleheim and others).",
    NA_character_, "International trade", "value"
  )
)
}

# Valor de reprodução da força de trabalho: repartir a remuneração monetária
# pela cesta de consumo e multiplicar cada produto/origem por lambda (mv/USD).
# Somar fornecedores (colSums) dá o trabalho incorporado na cesta comprada pelos
# trabalhadores de cada setor/país. Usa a cesta média nacional ou internacional
# configurada, hipótese que não observa o consumo individual de cada trabalhador.
# A variante empe aproxima capital variável; emp inclui renda dos não empregados.
wlv_native_stage4_labour_force_spec <- function(id, compensation, metadata) {
  wlv_native_indicator_spec(
    id,
    checkpoint = 4L,
    scope = "io_period",
    requires = c(
      wlv_native_indicator_ref(compensation, "compensation"),
      wlv_native_io_ref("consumption_basket", "basket"),
      wlv_native_intermediate_ref("lambda", axes = c("year", "input")),
      wlv_native_run_ref("dimensions/lists", "lists", "list"),
      wlv_native_run_ref("dimensions/nums", "nums", "list")
    ),
    metadata = metadata,
    run = function(ctx) {
      basket <- ctx$input("basket")
      lambda <- ctx$input("lambda")
      nums <- ctx$input("nums")
      lists <- wlv_native_partition_lists(basket, ctx$input("lists"))
      year_count <- dim(basket)[[1L]]
      compensation <- ctx$input("compensation")[lists$years, , , drop = FALSE]
      value <- (
        (aperm(
          array(rep(compensation, times = nums$input),
            dim = c(year_count, nums$input, nums$input)),
          c(1L, 3L, 2L)
        ) * array(basket, dim = c(year_count, nums$input, nums$input))) *
          rep(lambda, times = nums$input)
      )
      value <- aperm(
        apply(
          array(value, dim = c(year_count, nums$input, nums$input)),
          1L,
          colSums
        ),
        c(2L, 1L)
      )
      value <- wlv_native_sector_array(value, lists)
      wlv_module_result(outputs = list(value = value))
    }
  )
}

wlv_indicator_labour_force_value_s_mv_spec <- function() {
  wlv_native_stage4_labour_force_spec(
  "indicator.labour_force_value.s.mv",
  "compensation.empe.s.us",
  wlv_native_indicator_metadata_row(
    "labour_force_value.s.mv", "Variable capital (magnitude of value)",
    "Portion of total social capital directed towards the hiring of labor force. Data are in magnitude of value, i.e., the socially necessary labour-time required to produce the commodities that compose the workers' consumption basket.",
    "Obtained by converting the monetary compensation of employee into value accordingly to the embodied value in the consumption basket.",
    "Wages and value of labour force", "value"
  )
)
}
wlv_indicator_labour_force_value_emp_s_mv_spec <- function() {
  wlv_native_stage4_labour_force_spec(
  "indicator.labour_force_value.emp.s.mv",
  "compensation.emp.s.us",
  wlv_native_indicator_metadata_row(
    "labour_force_value.emp.s.mv", "Labour compensation (magnitude of value)",
    "Labour compensation expressed in magnitude of value represents the socially necessary labour-time to produce the commodities consumed by all persons engaged. It includes variable capital and income received by non-waged and non-salaried workers.",
    "Obtained by converting the monetary labour compensation into value accordingly to the embodied value in the consumption basket.",
    "Wages and value of labour force", "value"
  )
)
}

# Publica lambda com o formato setorial: magnitude de trabalho incorporado por
# unidade monetária da produção. Reformatar ano × input para ano × setor × país
# não recalcula Leontief nem altera seus valores/anos.
wlv_indicator_value_m_mv_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.value.m.mv",
  checkpoint = 4L,
  scope = "io_period",
  requires = c(
    wlv_native_intermediate_ref("lambda", axes = c("year", "input")),
    wlv_native_run_ref("dimensions/lists", "lists", "list")
  ),
  metadata = wlv_native_indicator_metadata_row(
    "value.m.mv", "Average value per unit of output",
    "Average value per unit of output represents the abstract productive labour embodied per $1.00 of each sector.",
    NA_character_, "Product", "value"
  ),
  run = function(ctx) {
    lambda <- ctx$input("lambda")
    lists <- wlv_native_partition_lists(lambda, ctx$input("lists"))
    value <- wlv_native_sector_array(lambda, lists)
    wlv_module_result(outputs = list(value = value))
  }
)
}

# Somar origens de capital (colunas de usuários mantidas) produz a depreciação
# anual de cada setor proprietário, em moeda. Será subtraída do lucro bruto
# para a taxa de lucro apropriado; não se soma entre anos como se fosse estoque.
wlv_indicator_capital_depreciation_s_us_spec <- function() {
  wlv_native_indicator_spec(
  "indicator.capital_depreciation.s.us",
  checkpoint = 4L,
  scope = "io_period",
  requires = wlv_native_stage4_matrix_requirements("k_depreciation"),
  metadata = wlv_native_indicator_metadata_row(
    "capital_depreciation.s.us", "Capital depreciation (USD)",
    "Capital depreciation refers to the physical exhaustion of a capital asset measured in terms of the decline in its market price.",
    "See the assumptions of each method for more information about the computation of capital composition em depreciation.",
    "Capital", "usd"
  ),
  run = function(ctx) {
    matrix_value <- ctx$input("matrix")
    lists <- wlv_native_partition_lists(matrix_value, ctx$input("lists"))
    nums <- ctx$input("nums")
    year_count <- dim(matrix_value)[[1L]]
    value <- aperm(
      apply(
        array(matrix_value, dim = c(year_count, nums$input, nums$input)),
        1L,
        colSums,
        na.rm = TRUE
      ),
      c(2L, 1L)
    )
    value <- wlv_native_sector_array(value, lists)
    wlv_module_result(outputs = list(value = value))
  }
)
}

# Stage 5: final sector and country indicators -----------------------------

# Fábrica das médias e taxas abaixo: dividir grandezas com os mesmos eixos.
# subtract_one transforma trabalho/valor da força de trabalho em (trabalho -
# valor da força de trabalho)/valor da força de trabalho, a taxa de mais-valia.
# Taxas são razões decimais: 0,25 corresponde a 25%, sem multiplicação aqui.
# Denominador zero é not_applicable. O agregado nacional/mundial é uma razão
# dos totais independentes, nunca a média simples das razões setoriais.
wlv_native_stage5_ratio_spec <- function(
    id,
    numerator,
    denominator,
    metadata,
    subtract_one = FALSE) {
  indicator <- sub("^indicator[.]", "", id)
  wlv_native_indicator_spec(
    id,
    checkpoint = 5L,
    requires = c(
      wlv_native_indicator_ref(numerator, "numerator"),
      wlv_native_indicator_ref(denominator, "denominator"),
      wlv_native_run_ref("dimensions/lists", "lists", "list")
    ),
    provides = wlv_native_stage5_provides(indicator),
    services = "contract_runtime",
    metadata = metadata,
    run = local({
      output_indicator <- indicator
      minus_one <- subtract_one
      module_name <- id
      function(ctx) {
        runtime <- ctx$service("contract_runtime")
        numerator_value <- ctx$input("numerator")
        denominator_value <- ctx$input("denominator")
        sector <- wlv_ratio_runtime(
          runtime,
          numerator_value,
          denominator_value,
          zero = "not_applicable",
          artifact = "sea_sectors",
          indicator = output_indicator,
          checkpoint = "after_stage_5",
          stage = 5L,
          module = module_name,
          axes = c(year = 1L, sector = 2L, country = 3L)
        )
        if (minus_one) sector <- sector - 1
        sector <- wlv_native_with_named_axes(sector, c("year", "sector", "country"))
        country <- wlv_native_independent_country_ratio(
          runtime,
          numerator_value,
          denominator_value,
          output_indicator,
          module_name,
          ctx$input("lists"),
          subtract_one = minus_one
        )
        wlv_module_result(outputs = list(sector = sector, country = country))
      }
    })
  )
}

wlv_indicator_abstract_labour_empe_m_mv_spec <- function() {
  wlv_native_stage5_ratio_spec(
  "indicator.abstract_labour.empe.m.mv",
  "abstract_labour.empe.s.mv", "empe.s.un",
  wlv_native_indicator_metadata_row(
    "abstract_labour.empe.m.mv", "Annual abstract labour per employee",
    "Annual weighted employee hours divided by employee count. Includes productive and unproductive industries; this is not a daily working time or a claim that every included industry creates new value.",
    NA_character_, "Labour and employment", "value"
  )
)
}
wlv_indicator_abstract_labour_emp_m_mv_spec <- function() {
  wlv_native_stage5_ratio_spec(
  "indicator.abstract_labour.emp.m.mv",
  "abstract_labour.emp.s.mv", "emp.s.un",
  wlv_native_indicator_metadata_row(
    "abstract_labour.emp.m.mv", "Annual abstract labour per person engaged",
    "Annual weighted hours divided by the number of persons engaged, including non-employees and unproductive industries. This is not daily working time or the productive new-value aggregate.",
    NA_character_, "Labour and employment", "value"
  )
)
}
wlv_indicator_labour_force_value_m_mv_spec <- function() {
  wlv_native_stage5_ratio_spec(
  "indicator.labour_force_value.m.mv",
  "labour_force_value.s.mv", "empe.s.un",
  wlv_native_indicator_metadata_row(
    "labour_force_value.m.mv", "Labour force average value",
    "Average value of labour force is the socially necessary labour-time required to produce the consumption basket of an average worker.",
    "Obtained by dividing variable capital by the number of employees.",
    "Wages and value of labour force", "value"
  )
)
}
wlv_indicator_labour_force_value_emp_m_mv_spec <- function() {
  wlv_native_stage5_ratio_spec(
  "indicator.labour_force_value.emp.m.mv",
  "labour_force_value.emp.s.mv", "emp.s.un",
  wlv_native_indicator_metadata_row(
    "labour_force_value.emp.m.mv", "Worker's average reproduction value",
    "Worker's average reproduction value representes the socially necessary labour-time required to produce the consumptio basket consumed by person engaged.",
    "Obtained by dividing labour compensation in magnitude of value by the number of persons engaged.",
    "Wages and value of labour force", "value"
  )
)
}
wlv_indicator_surplus_value_empe_r_pc_spec <- function() {
  wlv_native_stage5_ratio_spec(
  "indicator.surplus_value.empe.r.pc",
  "abstract_labour.empe.s.mv", "labour_force_value.s.mv",
  wlv_native_indicator_metadata_row(
    "surplus_value.empe.r.pc", "Rate of surplus value",
    "Rate of surplus value of productive and unproductive employees. It is a measure of exploitation of labour in a capitalist relation of production.",
    "Obtained by dividing the sum of abstract labour of productive and unproductive employees by the variable capital, minus one.",
    "Rate of surplus value", "percent", TRUE
  ),
  subtract_one = TRUE
)
}
wlv_indicator_surplus_value_emp_r_pc_spec <- function() {
  wlv_native_stage5_ratio_spec(
  "indicator.surplus_value.emp.r.pc",
  "abstract_labour.emp.s.mv", "labour_force_value.emp.s.mv",
  wlv_native_indicator_metadata_row(
    "surplus_value.emp.r.pc", "Rate of surplus value of persons engaged",
    "Rate of surplus value of persons engaged. It includes productive and unproductive sectors.",
    "Obtained by dividing the sum of abstract labour of productive and unproductive persons engaged by the labour compensation in magnitude of value, minus one.",
    "Rate of surplus value", "percent", TRUE
  ),
  subtract_one = TRUE
)
}
# Taxa de lucro apropriado = (lucro monetário - depreciação) / estoque de capital.
# É uma aproximação contábil à rentabilidade, distinta da taxa marxiana m/(c+v).
# País e mundo calculam primeiro os totais monetários. Estoque zero torna a razão
# inaplicável; não é motivo para publicar zero de rentabilidade.
wlv_native_appropriated_profit_spec <- function() {
  wlv_native_indicator_spec(
    "indicator.appropriated_profit.r.pc",
    checkpoint = 5L,
    requires = c(
      wlv_native_indicator_ref("profit.s.us", "profit"),
      wlv_native_indicator_ref("capital_depreciation.s.us", "depreciation"),
      wlv_native_indicator_ref("capital_stock.s.us", "capital_stock"),
      wlv_native_run_ref("dimensions/lists", "lists", "list")
    ),
    provides = wlv_native_stage5_provides("appropriated_profit.r.pc"),
    services = "contract_runtime",
    metadata = wlv_native_indicator_metadata_row(
      "appropriated_profit.r.pc", "Rate of appropriated profit",
      "Rate of appropriated profit represents the relation between the net profit appropriated by a sector (profit minus capital depreciation) and its stock of capital. This is a first approximation about the profit rate. It does not correspond to the Marxist concept of profit rate (i.e., surplus value divided by constant and variable capital).",
      NA_character_, "Capital", "percent"
    ),
    run = function(ctx) {
      runtime <- ctx$service("contract_runtime")
      numerator <- ctx$input("profit") - ctx$input("depreciation")
      denominator <- ctx$input("capital_stock")
      sector <- wlv_ratio_runtime(
        runtime, numerator, denominator,
        zero = "not_applicable", artifact = "sea_sectors",
        indicator = "appropriated_profit.r.pc", checkpoint = "after_stage_5",
        stage = 5L, module = "indicator.appropriated_profit.r.pc",
        axes = c(year = 1L, sector = 2L, country = 3L)
      )
      sector <- wlv_native_with_named_axes(
        sector,
        c("year", "sector", "country")
      )
      lists <- ctx$input("lists")
      country_numerator <-
        wlv_native_sum_country_and_world(ctx$input("profit"), lists) -
        wlv_native_sum_country_and_world(ctx$input("depreciation"), lists)
      country_denominator <- wlv_native_sum_country_and_world(
        ctx$input("capital_stock"), lists
      )
      country <- wlv_ratio_runtime(
        runtime, country_numerator, country_denominator,
        zero = "not_applicable", artifact = "sea_countries",
        indicator = "appropriated_profit.r.pc",
        checkpoint = "after_country_module", stage = 5L,
        module = "indicator.appropriated_profit.r.pc",
        axes = c(year = 1L, country = 2L)
      )
      country <- wlv_native_with_named_axes(country, c("year", "country"))
      wlv_module_result(outputs = list(sector = sector, country = country))
    }
  )
}

wlv_indicator_appropriated_profit_r_pc_spec <- function() {
  wlv_native_appropriated_profit_spec()
}

wlv_indicator_trade_transfers_p_m_pc_spec <- function() {
  wlv_native_stage5_ratio_spec(
  "indicator.trade_transfers.p.m.pc",
  "trade_transfers.p.s.mv", "gdp.s.mv",
  wlv_native_indicator_metadata_row(
    "trade_transfers.p.m.pc", "Transfer of value through trade (productive sectors) (% of GDP)",
    "Transfer of value through trade in productive sectors represents the value received from (if positive) or sent to (if negative) to the rest of the world as a result of the diference between the value represented by the amount of money received (from exports) or sent (from imports) and the actually abstract labour embodied in commodities traded. This data is equivalent of what some authors call \"unequal exchange\" (Bettleheim and others). Data are in percentage of GDP in magnitude of value.",
    NA_character_, "International trade", "percent"
  )
)
}

# Combina séries aditivas já comparáveis: exportações - importações é saldo
# comercial; transferência total - produtiva isola a parcela não produtiva.
# Os agregados são produzidos depois pelo registro de agregação, preservando
# a unidade e a política de ausência de cada indicador.
wlv_native_stage5_sum_spec <- function(
    id,
    requires,
    formula,
    metadata,
    services = character()) {
  indicator <- sub("^indicator[.]", "", id)
  wlv_native_indicator_spec(
    id,
    checkpoint = 5L,
    requires = c(
      requires,
      wlv_native_run_ref("dimensions/lists", "lists", "list")
    ),
    provides = wlv_native_indicator_output(indicator, alias = "sector"),
    services = services,
    metadata = metadata,
    run = local({
      calculate <- formula
      function(ctx) {
        sector <- calculate(ctx)
        sector <- wlv_native_with_named_axes(sector, c("year", "sector", "country"))
        wlv_module_result(outputs = list(sector = sector))
      }
    })
  )
}

wlv_indicator_trade_transfers_u_s_mv_spec <- function() {
  wlv_native_stage5_sum_spec(
  "indicator.trade_transfers.u.s.mv",
  c(
    wlv_native_indicator_ref("trade_transfers.s.mv", "total"),
    wlv_native_indicator_ref("trade_transfers.p.s.mv", "productive")
  ),
  function(ctx) ctx$input("total") - ctx$input("productive"),
  wlv_native_indicator_metadata_row(
    "trade_transfers.u.s.mv", "Transfer of value through trade (unproductive sectors)",
    "The transfer of value through trade in unproductive sectors refers to the value represented by the amount of money received (in exports) or sent (in imports) in transactions involving unproductive sectors.",
    NA_character_, "International trade", "value"
  )
)
}
wlv_indicator_trade_balance_s_us_spec <- function() {
  wlv_native_stage5_sum_spec(
  "indicator.trade_balance.s.us",
  c(
    wlv_native_indicator_ref("exports.s.us", "exports"),
    wlv_native_indicator_ref("imports.s.us", "imports")
  ),
  function(ctx) ctx$input("exports") - ctx$input("imports"),
  wlv_native_indicator_metadata_row(
    "trade_balance.s.us", "Trade balance on good and services (USD)",
    "Trade balance on goods and services equals exports of goods and services minus imports of goods and services.",
    NA_character_, "International trade", "usd"
  )
)
}
wlv_indicator_trade_balance_s_mv_spec <- function() {
  wlv_native_stage5_sum_spec(
  "indicator.trade_balance.s.mv",
  c(
    wlv_native_indicator_ref("exports.s.mv", "exports"),
    wlv_native_indicator_ref("imports.s.mv", "imports")
  ),
  function(ctx) ctx$input("exports") - ctx$input("imports"),
  wlv_native_indicator_metadata_row(
    "trade_balance.s.mv", "Trade balance on good and services (magnitude of value)",
    "Trade balance on goods and services equals exports of goods and services minus imports of goods and services. Data are in magnitude of value",
    NA_character_, "International trade", "value"
  )
)
}

# Preços diretos proporcionais ao valor: produção bruta mundial em USD / produção
# bruta mundial em mv fornece USD/mv para cada ano. Multiplicar produto ou VA
# em mv por esse coeficiente conserva a soma mundial da produção monetária.
# Não é câmbio, preço observado nem deflator temporal. Denominador zero aborta.
wlv_native_direct_price_spec <- function(id, base_indicator, metadata) {
  base_is_gross_output <- identical(base_indicator, "gross_output.s.mv")
  requirements <- c(
    wlv_native_indicator_ref(base_indicator, "base"),
    wlv_native_indicator_ref("gross_output.s.us", "gross_output_us")
  )
  if (!base_is_gross_output) {
    requirements <- c(
      requirements,
      wlv_native_indicator_ref("gross_output.s.mv", "gross_output_mv")
    )
  }
  wlv_native_stage5_sum_spec(
    id,
    requirements,
    local({
      denominator_alias <- if (base_is_gross_output) {
        "base"
      } else {
        "gross_output_mv"
      }
      function(ctx) {
        numerator <- apply(ctx$input("gross_output_us"), 1L, sum)
        denominator <- apply(ctx$input(denominator_alias), 1L, sum)
        coefficient <- wlv_safe_divide_runtime(
          ctx$service("contract_runtime"), numerator, denominator,
          zero = "error", artifact = "sea_sectors",
          indicator = "direct_price_coefficient", checkpoint = "after_stage_5",
          stage = 5L, module = id, axes = c(year = 1L)
        )
        ctx$input("base") * rep(
          coefficient,
          times = length(ctx$input("lists")$sectors) *
            length(ctx$input("lists")$countries)
        )
      }
    }),
    metadata,
    services = "contract_runtime"
  )
}

wlv_indicator_gdp_s_du_spec <- function() {
  wlv_native_direct_price_spec(
  "indicator.gdp.s.du", "gdp.s.mv",
  wlv_native_indicator_metadata_row(
    "gdp.s.du", "Gross Domestic Product (direct prices - USD) ",
    "Gross Domestic Product calculated by value added approach represents all value created by residents. Data are in direct prices (prices proportional to value), thus it enconpass productive sectors only.",
    "Obtained by converting the sum of abstract labour performed in productive sectors into prices throught the relation between the sum  of gross output in market prices and the sum of gross output in value of whole world.",
    "Product", "usd"
  )
)
}

wlv_indicator_gross_output_s_du_spec <- function() {
  wlv_native_direct_price_spec(
  "indicator.gross_output.s.du", "gross_output.s.mv",
  wlv_native_indicator_metadata_row(
    "gross_output.s.du", "Gross output (direct prices - USD)",
    "Gross output is the sum of prices of all goods and services produced by residents. It includes the value added (variable capital and surplus value) and the price of intermediate consumption (constant capital). Data are in direct prices (prices proportional to values).",
    NA_character_, "Product", "usd"
  )
)
}

# Taxa de mais-valia restrita aos setores produtivos. Setorialmente a máscara
# zera a taxa fora do recorte (convenção publicada); nacionalmente/mundialmente
# recalcula trabalho produtivo / custo de reprodução produtivo - 1, em razão
# decimal. Somar taxas ou zerar apenas uma das parcelas distorceria a medida.
wlv_native_productive_surplus_spec <- function(employee = FALSE) {
  person <- if (employee) "empe" else "emp"
  indicator <- paste0("surplus_value.", person, "_p.r.pc")
  source_indicator <- paste0("surplus_value.", person, ".r.pc")
  numerator_indicator <- paste0("abstract_labour.", person, ".s.mv")
  denominator_indicator <- if (employee) {
    "labour_force_value.s.mv"
  } else {
    "labour_force_value.emp.s.mv"
  }
  wlv_native_indicator_spec(
    paste0("indicator.", indicator),
    checkpoint = 5L,
    requires = c(
      wlv_native_indicator_ref(source_indicator, "source"),
      wlv_native_indicator_ref(numerator_indicator, "numerator"),
      wlv_native_indicator_ref(denominator_indicator, "denominator"),
      wlv_native_run_ref("dimensions/rows", "rows", "data.frame"),
      wlv_native_run_ref("dimensions/lists", "lists", "list")
    ),
    provides = wlv_native_stage5_provides(indicator),
    anomaly_bindings = list(
      wlv_native_anomaly_binding(
        "sea_countries",
        paste0(indicator, ".numerator")
      ),
      wlv_native_anomaly_binding(
        "sea_countries",
        paste0(indicator, ".denominator")
      )
    ),
    services = "contract_runtime",
    metadata = wlv_native_indicator_metadata_row(
      indicator,
      if (employee) "Rate of surplus value (productive workers)" else "Rate of surplus value of persons engaged (productive workers)",
      if (employee) "Estimated surplus-value rate of employees in industries classified as productive, under the national consumption-basket and equal-hour assumptions." else "Estimated surplus-value rate of persons engaged in productive industries, including non-employees under the source's labour-compensation convention.",
      if (employee) "Productive employee abstract labour divided by the labour content of the basket financed by productive employee compensation, minus one." else "Productive persons-engaged abstract labour divided by the labour content of the basket financed by their labour compensation, minus one. Both operands are in labour-value units, not hours divided by money.",
      "Rate of surplus value", "percent", TRUE
    ),
    run = local({
      output_code <- indicator
      source_code <- source_indicator
      numerator_code <- numerator_indicator
      denominator_code <- denominator_indicator
      function(ctx) {
        runtime <- ctx$service("contract_runtime")
        years <- length(ctx$input("lists")$years)
        productive <- rep(ctx$input("rows")$productive, each = years)
        source <- ctx$input("source")
        sector <- source * productive
        wlv_contract_copy_indicator_states(
          runtime,
          artifact = "sea_sectors",
          source_indicator = source_code,
          target_indicator = output_code,
          value = source,
          checkpoint = "after_stage_5"
        )
        numerator <- ctx$input("numerator") * productive
        denominator <- ctx$input("denominator") * productive
        country <- wlv_native_country_and_world_ratio(
          runtime, numerator, denominator, output_code,
          numerator_code, denominator_code,
          paste0("indicator.", output_code), ctx$input("lists"),
          subtract_one = TRUE
        )
        sector <- wlv_native_with_named_axes(sector, c("year", "sector", "country"))
        wlv_module_result(outputs = list(sector = sector, country = country))
      }
    })
  )
}

wlv_indicator_surplus_value_emp_p_r_pc_spec <- function() {
  wlv_native_productive_surplus_spec(FALSE)
}
wlv_indicator_surplus_value_empe_p_r_pc_spec <- function() {
  wlv_native_productive_surplus_spec(TRUE)
}
