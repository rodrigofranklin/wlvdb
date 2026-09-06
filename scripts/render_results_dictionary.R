# Keep this executable source ASCII: Unicode escapes preserve bilingual text
# when Rscript/sys.source use the C locale. Human-readable meanings remain in
# the UTF-8 descriptions CSV and generated guides; no dynamic loader is needed.
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
    hour = if (pt) "horas" else "hours", ratio = if (pt) "raz\u00e3o" else "ratio",
    multiplier = if (pt) "multiplicador" else "multiplier", index = if (pt) "\u00edndice (2000 = 1)" else "index (2000 = 1)",
    local_currency_per_usd = if (pt) "moeda local/USD" else "local currency/USD",
    abstract_labour_hour = if (pt) "horas abstratas" else "abstract hours",
    abstract_labour_hour_per_usd = if (pt) "horas abstratas/USD" else "abstract hours/USD",
    abstract_labour_hour_per_person = if (pt) "horas abstratas/pessoa" else "abstract hours/person"
  )
  strategies <- c(
    sum = if (pt) "soma" else "sum",
    mean = if (pt) "m\u00e9dia simples" else "arithmetic mean",
    invariant = if (pt) "valor nacional comum" else "common national value",
    not_applicable = "NA",
    formula = if (pt) "f\u00f3rmula descrita" else "described formula",
    ratio_of_sums = if (pt) "raz\u00e3o dos totais" else "ratio of totals",
    weighted_mean = if (pt) "m\u00e9dia ponderada" else "weighted mean"
  )
  lines <- c(
    if (pt) "# Dicion\u00e1rio de resultados" else "# Results dictionary",
    "", "<!-- documentation-revision: wiod-consolidation-v1 -->", "",
    if (pt) "[English](results-dictionary-en.md) | [Guia em portugu\u00eas](guide-pt.md)" else "[Portugu\u00eas](results-dictionary-pt.md) | [English guide](guide-en.md)", "",
    if (pt) "Este dicion\u00e1rio cobre todos os indicadores publicados por `wiodr13` (1995\u20132009) e `wiodr16` (2000\u20132014). As tabelas s\u00e3o geradas dos contratos v2 e das descri\u00e7\u00f5es econ\u00f4micas revisadas. Cada linha se aplica a `sea_sectors` e `sea_countries`, salvo a aus\u00eancia mundial indicada na coluna de agrega\u00e7\u00e3o. Pa\u00edses e setores seguem os r\u00f3tulos de cada run: as duas fontes n\u00e3o t\u00eam classifica\u00e7\u00e3o nem cobertura geogr\u00e1fica id\u00eanticas."
    else "This dictionary covers every indicator published by `wiodr13` (1995\u20132009) and `wiodr16` (2000\u20132014). Tables are generated from v2 contracts and reviewed economic descriptions. Each row applies to `sea_sectors` and `sea_countries`, except for the world absence indicated in the aggregation column. Countries and sectors follow each run's labels: the sources do not have identical classifications or geographic coverage.", "",
    if (pt) "As unidades s\u00e3o as armazenadas, ap\u00f3s normaliza\u00e7\u00e3o: USD, pessoas e horas, nunca milh\u00f5es ou milhares impl\u00edcitos. USD significa d\u00f3lar dos Estados Unidos. USD sem qualificador indica pre\u00e7os correntes. `\u00d7100` \u00e9 aplicado uma \u00fanica vez na apresenta\u00e7\u00e3o, n\u00e3o no c\u00e1lculo. Uma taxa armazenada como 0,25 aparece como 25%. As parcelas por qualifica\u00e7\u00e3o permanecem raz\u00f5es (0,25) no contrato, apesar do sufixo `.pc`. \u00cdndice 1 aparece como 1 no WIOD13 e como 100 pontos no WIOD16, conforme display_multiplier."
    else "Units describe storage after normalization: USD, persons and hours, with no implicit millions or thousands. USD means United States dollar. Unqualified USD means current prices. `\u00d7100` is applied exactly once for display, never in calculation. A stored rate of 0.25 appears as 25%. Skill shares remain ratios (0.25) in the contract despite their `.pc` suffix. Index 1 appears as 1 in WIOD13 and as 100 points in WIOD16, according to display_multiplier.", "",
    if (pt) "`NA` significa aus\u00eancia justificada, n\u00e3o zero. Consulte `_states.csv` para distinguir `source_missing` (ausente na fonte) de `not_applicable` (opera\u00e7\u00e3o indefinida). C\u00e2mbio e \u00edndices nacionais n\u00e3o t\u00eam agregado mundial compar\u00e1vel. Denominadores e pesos nulos tornam as raz\u00f5es e m\u00e9dias correspondentes n\u00e3o aplic\u00e1veis. Componentes dispon\u00edveis podem produzir agregados com cobertura parcial registrada em `_anomalies.csv`: examine o relat\u00f3rio antes de comparar pa\u00edses. N\u00e3o complete aus\u00eancias com zero. No WIOD13, 2008\u20132009 t\u00eam perda de cobertura de capital: a prepara\u00e7\u00e3o hist\u00f3rica converte aus\u00eancias fixadas em zeros de compatibilidade, e o WLVPanel exclui esses anos de todas as s\u00e9ries. Arquivos do banco ainda podem conter valores finitos nesses anos."
    else "`NA` means justified absence, not zero. Consult `_states.csv` to distinguish `source_missing` (absent in the source) from `not_applicable` (undefined operation). National exchange rates and indices have no comparable world aggregate. Zero denominators or weights make the corresponding ratios or averages not applicable. Available components can produce partial-coverage aggregates recorded in `_anomalies.csv`: inspect that report before comparing countries. Do not fill missing values with zero. WIOD13 loses capital coverage in 2008\u20132009: historical preparation converts pinned absences to compatibility zeros, and WLVPanel excludes those years from all series. Database files can still contain finite values in those years.", "",
    if (pt) "A coluna de agrega\u00e7\u00e3o apresenta setor \u2192 pa\u00eds / pa\u00eds \u2192 mundo. Nas m\u00e9dias ponderadas, o peso aparece entre par\u00eanteses. Nas f\u00f3rmulas, a descri\u00e7\u00e3o explica numerador e denominador: taxas nacionais e mundiais s\u00e3o constru\u00eddas a partir dos totais pertinentes, n\u00e3o da m\u00e9dia das taxas setoriais. O contrato efetivo de cada run \u00e9 `_unit_contract.csv`, que prevalece para arquivos hist\u00f3ricos."
    else "The aggregation column gives sector \u2192 country / country \u2192 world. Weighted means show their weight in parentheses. For formulas, the description explains numerator and denominator: national and world rates use the relevant totals, not an average of sector rates. Each run's effective contract is `_unit_contract.csv`, which governs historical files.", "",
    if (pt) "As hip\u00f3teses de trabalho produtivo, igualdade das horas, resto do mundo, China, capital, cestas e com\u00e9rcio est\u00e3o no [guia](guide-pt.md#metodologia). Lucro apropriado n\u00e3o equivale \u00e0 taxa marxiana de lucro, e transfer\u00eancias modeladas n\u00e3o identificam por si s\u00f3 uma rela\u00e7\u00e3o causal. Mudan\u00e7as v1 \u2192 v2 exigem comparar contratos, n\u00e3o simplesmente unir s\u00e9ries."
    else "Assumptions about productive labour, equal hours, the rest of the world, China, capital, baskets and trade are in the [guide](guide-en.md#methodology). Appropriated profit is not the Marxian profit rate, and modelled transfers alone do not identify a causal relationship. For v1 \u2192 v2 changes, compare contracts rather than simply joining series.", ""
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
    display <- ifelse(unit$display_multiplier == "100", paste0("\u00d7100 ", ifelse(unit$display_unit == "percent", "%", if (pt) "pontos" else "points")), if (pt) "sem escala adicional" else "no additional scaling")
    lines <- c(lines, paste0("## ", method, " \u2014 ", nrow(unit), if (pt) " indicadores" else " indicators"), "",
      if (pt) "| Identificador | Significado econ\u00f4mico | Unidade armazenada | Apresenta\u00e7\u00e3o | Agrega\u00e7\u00e3o: pa\u00eds / mundo |" else "| Identifier | Economic meaning | Stored unit | Display | Aggregation: country / world |",
      "| --- | --- | --- | --- | --- |",
      vapply(seq_len(nrow(unit)), function(i) paste0(
        "| `", unit$indicator[[i]], "` | ", meanings[[i]], " | ", unit_label[[i]], " | ", display[[i]], " | ",
        agg(unit$indicator[[i]], "sector_to_country"), " / ", agg(unit$indicator[[i]], "country_to_world"), " |"
      ), character(1L)), "")
  }
  stopifnot(setequal(union_indicators, descriptions$indicator))
  c(lines, if (pt) "Gerado por `scripts/render_results_dictionary.R`. Edite as descri\u00e7\u00f5es e os contratos de origem, regenere os dois idiomas e execute `--check`. Consulte a [conven\u00e7\u00e3o de sincroniza\u00e7\u00e3o](documentation-sync.md)."
    else "Generated by `scripts/render_results_dictionary.R`. Edit source descriptions and contracts, regenerate both languages and run `--check`. See the [synchronization convention](documentation-sync.md).")
}

if (sys.nframe() == 0L) {
  argument <- grep("^--file=", commandArgs(FALSE), value = TRUE)[[1L]]
  root <- dirname(dirname(normalizePath(sub("^--file=", "", argument))))
  check <- "--check" %in% commandArgs(TRUE)
  for (language in c("pt", "en")) {
    path <- file.path(root, "docs", paste0("results-dictionary-", language, ".md"))
    expected <- enc2utf8(wlv_render_results_dictionary(root, language))
    if (check) {
      if (!file.exists(path) || !identical(readLines(path, encoding = "UTF-8"), expected)) {
        stop("Results dictionary is out of sync: ", path, call. = FALSE)
      }
    } else {
      writeLines(expected, path, useBytes = TRUE)
    }
  }
  cat(if (check) "Bilingual results dictionaries are synchronized.\n" else "Bilingual results dictionaries generated.\n")
}
