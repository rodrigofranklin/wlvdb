# Reproducible bilingual documentation from the executable unit contracts.
# No runtime or source data are loaded. Keep reviewed economic descriptions in
# docs/indicator-descriptions.csv; unit or aggregation changes come from CSVs.
wlv_render_results_dictionary <- function(root, language = "en") {
  stopifnot(language %in% c("pt", "en"))
  # As in the catalog reader, mark UTF-8 strings without transcoding them to
  # the process locale: fileEncoding would reject accents under LC_ALL=C.
  read <- function(path) utils::read.csv2(
    text = readLines(file.path(root, path), encoding = "UTF-8", warn = FALSE),
    stringsAsFactors = FALSE, check.names = FALSE,
    colClasses = "character", na.strings = NULL
  )
  pt <- identical(language, "pt")
  descriptions <- read("docs/indicator-descriptions.csv")
  stopifnot(!anyDuplicated(descriptions$indicator), all(nzchar(descriptions[[language]])))
  units <- c(
    usd = "USD", person = if (pt) "pessoas" else "persons",
    hour = if (pt) "horas" else "hours", ratio = if (pt) "razão" else "ratio",
    multiplier = if (pt) "multiplicador" else "multiplier", index = if (pt) "índice (2000 = 1)" else "index (2000 = 1)",
    local_currency_per_usd = if (pt) "moeda local/USD" else "local currency/USD",
    abstract_labour_hour = if (pt) "horas abstratas" else "abstract hours",
    abstract_labour_hour_per_usd = if (pt) "horas abstratas/USD" else "abstract hours/USD",
    abstract_labour_hour_per_person = if (pt) "horas abstratas/pessoa" else "abstract hours/person"
  )
  strategies <- c(
    sum = if (pt) "soma" else "sum",
    mean = if (pt) "média simples" else "arithmetic mean",
    invariant = if (pt) "valor nacional comum" else "common national value",
    not_applicable = "NA",
    formula = if (pt) "fórmula descrita" else "described formula",
    ratio_of_sums = if (pt) "razão dos totais" else "ratio of totals",
    weighted_mean = if (pt) "média ponderada" else "weighted mean"
  )
  lines <- c(
    if (pt) "# Dicionário de resultados" else "# Results dictionary",
    "", "<!-- documentation-revision: wiod-consolidation-v1 -->", "",
    if (pt) "[English](results-dictionary-en.md) | [Guia em português](guide-pt.md)" else "[Português](results-dictionary-pt.md) | [English guide](guide-en.md)", "",
    if (pt) "Este dicionário cobre todos os indicadores publicados por `wiodr13` (1995–2009) e `wiodr16` (2000–2014). As tabelas são geradas dos contratos v2 e das descrições econômicas revisadas. Cada linha se aplica a `sea_sectors` e `sea_countries`, salvo a ausência mundial indicada na coluna de agregação. Países e setores seguem os rótulos de cada run: as duas fontes não têm classificação nem cobertura geográfica idênticas."
    else "This dictionary covers every indicator published by `wiodr13` (1995–2009) and `wiodr16` (2000–2014). Tables are generated from v2 contracts and reviewed economic descriptions. Each row applies to `sea_sectors` and `sea_countries`, except for the world absence indicated in the aggregation column. Countries and sectors follow each run's labels: the sources do not have identical classifications or geographic coverage.", "",
    if (pt) "As unidades são as armazenadas, após normalização: USD, pessoas e horas, nunca milhões ou milhares implícitos. USD significa dólar dos Estados Unidos. USD sem qualificador indica preços correntes. `×100` é aplicado uma única vez na apresentação, não no cálculo. Uma taxa armazenada como 0,25 aparece como 25%. As parcelas por qualificação permanecem razões (0,25) no contrato, apesar do sufixo `.pc`. Índice 1 aparece como 1 no WIOD13 e como 100 pontos no WIOD16, conforme display_multiplier."
    else "Units describe storage after normalization: USD, persons and hours, with no implicit millions or thousands. USD means United States dollar. Unqualified USD means current prices. `×100` is applied exactly once for display, never in calculation. A stored rate of 0.25 appears as 25%. Skill shares remain ratios (0.25) in the contract despite their `.pc` suffix. Index 1 appears as 1 in WIOD13 and as 100 points in WIOD16, according to display_multiplier.", "",
    if (pt) "`NA` significa ausência justificada, não zero. Consulte `_states.csv` para distinguir `source_missing` (ausente na fonte) de `not_applicable` (operação indefinida). Câmbio e índices nacionais não têm agregado mundial comparável. Denominadores e pesos nulos tornam as razões e médias correspondentes não aplicáveis. Componentes disponíveis podem produzir agregados com cobertura parcial registrada em `_anomalies.csv`: examine o relatório antes de comparar países. Não complete ausências com zero. No WIOD13, 2008–2009 têm perda de cobertura de capital: a preparação histórica converte ausências fixadas em zeros de compatibilidade, e o WLVPanel exclui esses anos de todas as séries. Arquivos do banco ainda podem conter valores finitos nesses anos."
    else "`NA` means justified absence, not zero. Consult `_states.csv` to distinguish `source_missing` (absent in the source) from `not_applicable` (undefined operation). National exchange rates and indices have no comparable world aggregate. Zero denominators or weights make the corresponding ratios or averages not applicable. Available components can produce partial-coverage aggregates recorded in `_anomalies.csv`: inspect that report before comparing countries. Do not fill missing values with zero. WIOD13 loses capital coverage in 2008–2009: historical preparation converts pinned absences to compatibility zeros, and WLVPanel excludes those years from all series. Database files can still contain finite values in those years.", "",
    if (pt) "A coluna de agregação apresenta setor → país / país → mundo. Nas médias ponderadas, o peso aparece entre parênteses. Nas fórmulas, a descrição explica numerador e denominador: taxas nacionais e mundiais são construídas a partir dos totais pertinentes, não da média das taxas setoriais. O contrato efetivo de cada run é `_unit_contract.csv`, que prevalece para arquivos históricos."
    else "The aggregation column gives sector → country / country → world. Weighted means show their weight in parentheses. For formulas, the description explains numerator and denominator: national and world rates use the relevant totals, not an average of sector rates. Each run's effective contract is `_unit_contract.csv`, which governs historical files.", "",
    if (pt) "As hipóteses de trabalho produtivo, igualdade das horas, resto do mundo, China, capital, cestas e comércio estão no [guia](guide-pt.md#metodologia). Lucro apropriado não equivale à taxa marxiana de lucro, e transferências modeladas não identificam por si só uma relação causal. Mudanças v1 → v2 exigem comparar contratos, não simplesmente unir séries."
    else "Assumptions about productive labour, equal hours, the rest of the world, China, capital, baskets and trade are in the [guide](guide-en.md#methodology). Appropriated profit is not the Marxian profit rate, and modelled transfers alone do not identify a causal relationship. For v1 → v2 changes, compare contracts rather than simply joining series.", ""
  )
  union_indicators <- character()
  for (method in c("wiodr13", "wiodr16")) {
    unit <- read(paste0("contracts/units/", method, "_v2-units.csv"))
    aggregation <- read(paste0("contracts/units/", method, "_v2-aggregations.csv"))
    output <- read(paste0("config/outputs/sources/", method, ".csv"))
    stopifnot(setequal(output$indicator, unit$indicator), !anyDuplicated(unit$indicator))
    union_indicators <- union(union_indicators, unit$indicator)
    unit <- unit[match(output$indicator, unit$indicator), , drop = FALSE]
    meanings <- descriptions[[language]][match(unit$indicator, descriptions$indicator)]
    stopifnot(!anyNA(meanings), all(unit$canonical_unit %in% names(units)))
    agg <- function(indicator, level) {
      row <- aggregation[aggregation$indicator == indicator & aggregation$level == level, , drop = FALSE]
      stopifnot(nrow(row) == 1L, row$strategy %in% names(strategies))
      paste0(strategies[[row$strategy]], if (nzchar(row$weight)) paste0(" (`", row$weight, "`)") else "")
    }
    unit_label <- unname(units[unit$canonical_unit])
    constant <- unit$price_basis == "constant"
    unit_label[constant] <- paste0(unit_label[constant], if (pt) " constantes de " else " at constant ", unit$base_year[constant], if (pt) "" else " prices")
    display <- ifelse(unit$display_multiplier == "100", paste0("×100 ", ifelse(unit$display_unit == "percent", "%", if (pt) "pontos" else "points")), if (pt) "sem escala adicional" else "no additional scaling")
    lines <- c(lines, paste0("## ", method, " — ", nrow(unit), if (pt) " indicadores" else " indicators"), "",
      if (pt) "| Identificador | Significado econômico | Unidade armazenada | Apresentação | Agregação: país / mundo |" else "| Identifier | Economic meaning | Stored unit | Display | Aggregation: country / world |",
      "| --- | --- | --- | --- | --- |",
      vapply(seq_len(nrow(unit)), function(i) paste0(
        "| `", unit$indicator[[i]], "` | ", meanings[[i]], " | ", unit_label[[i]], " | ", display[[i]], " | ",
        agg(unit$indicator[[i]], "sector_to_country"), " / ", agg(unit$indicator[[i]], "country_to_world"), " |"
      ), character(1L)), "")
  }
  stopifnot(setequal(union_indicators, descriptions$indicator))
  c(lines, if (pt) "Gerado por `scripts/render_results_dictionary.R`. Edite as descrições e os contratos de origem, regenere os dois idiomas e execute `--check`. Consulte a [convenção de sincronização](documentation-sync.md)."
    else "Generated by `scripts/render_results_dictionary.R`. Edit source descriptions and contracts, regenerate both languages and run `--check`. See the [synchronization convention](documentation-sync.md).")
}
