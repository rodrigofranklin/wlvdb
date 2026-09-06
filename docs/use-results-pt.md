# Usar, interpretar e citar os resultados

<!-- documentation-revision: wiod-reader-workflows-v2 -->

Português | [English](use-results-en.md) | [Início](../README-PT.md) | [Famílias de indicadores](indicator-families-pt.md) | [Dicionário](results-dictionary-pt.md)

## Comece pelos dados

Os resultados do WLVDB estão disponíveis no [World Labour Values](https://panel.worldlabourvalues.org/)
e no [acesso pelo LabCidades/UFES](http://labcidades.ufes.br/worldlabourvalues/).
A consulta e a obtenção de dados pelo site não exigem instalar R, clonar o
repositório ou recalcular as matrizes mundiais.

Este percurso acompanha uma análise: formular a pergunta, escolher o indicador,
obter os dados, verificar sua cobertura, interpretar o resultado e registrar
sua origem. O [guia técnico](guide-pt.md) é a referência para arquivos nativos,
instalação e reprodução. A [teoria](theory-pt.md) e a
[metodologia](methodology-pt.md) explicam o significado e a construção das medidas.

| Trabalho | Material necessário | Próximo passo |
| --- | --- | --- |
| Consultar ou analisar pelo site | Navegador e a identificação da seleção | Siga este capítulo até a nota de dados; R é opcional. |
| Analisar uma exportação | Arquivo obtido, descrições, unidades e identificação da seleção | Leia seu formato e conserve a escala informada na exportação. |
| Ler uma publicação nativa em R | Repositório, pacotes restaurados e árvore completa de publicação | Siga o exemplo FST deste capítulo. |
| Reconstruir o banco | Código, fontes estatísticas fixadas e recursos computacionais | Siga [executar o projeto](guide-pt.md#executar-o-projeto). |

Uma exportação para análise e uma publicação nativa são produtos diferentes.
Um arquivo tabular pode bastar para uma pesquisa; ele não substitui a árvore
de manifestos, canais, releases, runs e arquivos auxiliares exigida pelo leitor
nativo ou pelo WLVPanel. Confira os arquivos efetivamente obtidos antes de
escolher o programa de leitura. Não renomeie um CSV para FST.

## Transforme a pergunta em uma seleção

Uma pergunta inicial bem delimitada é: **como evoluiu a taxa de mais-valia dos
empregados dos setores classificados como produtivos no Brasil entre 1995 e
2007, segundo `wiodr13`?** Sua seleção é:

| Campo | Escolha e significado |
| --- | --- |
| Método | `wiodr13`, distinguindo essa edição de `wiodr16`. |
| País | Brasil, código `BRA`; não confundir com `ROW` ou `WWW`. |
| Indicador | `surplus_value.empe_p.r.pc`: empregados, setores produtivos, razão de trabalho e valor de reprodução menos um. |
| Período | 1995–2007, o recorte inicial compatível com a cobertura WIOD13 apresentada pelo painel. |
| Unidade de leitura | Taxa em porcentagem; no arquivo nativo a razão é armazenada antes da multiplicação de apresentação. |
| Agregação | Taxa nacional já calculada, não média simples das taxas setoriais. |

Use esses critérios na consulta e registre-os ao obter os dados. Preserve o
arquivo original da exportação e trabalhe sobre uma cópia de análise. Registre
os rótulos exibidos junto aos códigos: um nome parecido de setor não estabelece
correspondência entre WIOD13 e WIOD16.

A cobertura de cálculo WIOD13 vai até 2009, mas 2008–2009 têm limitações de
capital, inclusive zeros de compatibilidade que podem gerar resultados finitos.
O painel exclui esses anos de suas séries WIOD13. O recorte acima é uma decisão
conservadora para o primeiro exercício, não uma declaração de que todos os
outros anos e indicadores estão livres de imputações. Estudar os anos finais
exige justificar fontes, tratamento e impacto; consulte as
[hipóteses](assumptions-pt.md).

## Confira escala, cobertura e significado

Antes de interpretar a série, confira a definição nas
[fichas por família](indicator-families-pt.md) e no dicionário. Preserve a
distinção entre uma razão armazenada e sua apresentação. No contrato nativo,
1,5 pode ser apresentado como 150%. Uma exportação que já contém 150% não deve
receber novamente a multiplicação por 100. O sufixo `.pc` não resolve essa
distinção: ele também aparece em indicadores com outras convenções históricas.

Para cada série, registre método, indicador, unidade, período, população e
filtro produtivo. Para cada observação, mantenha o valor original e sua condição
de uso. Um `NA` não é zero; um número finito não comprova cobertura completa.

| Evidência | Decisão de análise |
| --- | --- |
| `source_missing` ou `not_applicable` | Conservar a ausência e seu motivo; não interpolar nem preencher automaticamente. |
| Anomalia ou cobertura parcial | Ler a regra e os componentes afetados; registrar inclusão ou exclusão e justificativa. Uma anomalia pode ser um tratamento conhecido, não um erro. |
| Taxa agregada com componentes ausentes | Examinar numerador e denominador separadamente e avaliar uma comparação de cobertura comum. |
| Exportação sem diagnósticos ou identificadores técnicos | Registrar quais metadados foram fornecidos e quais não foram; não inventar `run_id`, hash ou estado de uma célula. |
| Mudança de fonte, classificação, hipótese ou contrato | Separar as séries até estabelecer uma correspondência explícita. |

Uma exportação permite analisar os campos que contém. Uma auditoria das fontes,
das imputações ou da integridade da publicação exige os documentos e artefatos
correspondentes. A ausência de um arquivo auxiliar em uma exportação não prova
a ausência de problemas nem invalida, sozinha, toda análise daquele arquivo.

## Interprete antes de comparar

Em um exemplo **hipotético**, 250 horas de trabalho e uma cesta de reprodução
com 100 horas resultam em `250 / 100 - 1 = 1,5`, ou 150%. Isso significa que o
trabalho excedente estimado equivale a 1,5 vez o valor estimado de reprodução,
sob as hipóteses do método. Não significa 150 horas, taxa de lucro de 150%, ou
comprovação isolada de superexploração.

A mudança de 150% para 160% é de **10 pontos percentuais**. A variação relativa
da taxa é aproximadamente 6,67%, uma pergunta diferente. Nenhum desses números
hipotéticos constitui resultado para o Brasil.

Escolher `surplus_value.empe.r.pc` acrescenta os empregados dos setores
improdutivos. Escolher `emp` inclui também ocupados não assalariados e o
tratamento de sua remuneração. Essas variantes não são apenas rótulos de
apresentação. O [capítulo teórico](theory-pt.md) esclarece o alcance da
interpretação de exploração em cada recorte.

## Ler uma publicação nativa em R

Esta seção é opcional para quem utiliza o site. Execute os blocos na raiz do
repositório, depois de restaurar os pacotes e dispor de uma publicação nativa
completa em `results/`. A [instalação](guide-pt.md#instalação-e-preparação)
e o [contrato de publicação](result-publication.md) explicam os pré-requisitos.
O exemplo não baixa arquivos do painel nem supõe uma API de exportação.

```r
source("renv/activate.R")
bootstrap <- new.env(parent = baseenv())
sys.source("scripts/runtime_bootstrap.R", envir = bootstrap)
wlv <- bootstrap$wlv_load_runtime(".")
method <- "wiodr13"
run_dir <- wlv$wlv_current_result_dir(method, root = ".", channel = "stable")
countries <- wlv$read_fst_array(file.path(run_dir, "sea_countries.fst"))
units <- read.csv2(file.path(run_dir, "_unit_contract.csv"), stringsAsFactors = FALSE)
states <- read.csv2(file.path(run_dir, "_states.csv"), stringsAsFactors = FALSE)
anomalies <- read.csv2(file.path(run_dir, "_anomalies.csv"), stringsAsFactors = FALSE)
example <- new.env(parent = baseenv())
sys.source("scripts/examples/analysis_review.R", envir = example)
report <- example$wlv_example_review_series(
  countries, units, states, anomalies,
  method = method, country = "BRA",
  indicator = "surplus_value.empe_p.r.pc", years = 1995:2007
)
print(report$series)
print(report$states)
print(utils::head(report$anomalies, 20L))
```

O leitor público resolve a publicação antes da análise. O exemplo auxiliar
somente organiza a revisão: não autentica arquivos por conta própria, não
recalcula indicadores e não altera resultados publicados. Ele associa cada
`NA` ao estado da série e rejeita ausência sem estado, estado associado a
número finito, duplicação de estados, escala ambígua, `NaN` e infinitos.

O resultado conserva **todos os anos do arquivo**, inclusive os que ficam fora
da pergunta inicial. `in_requested_period` marca o recorte;
`wiodr13_coverage_alert` identifica os anos finais; `candidate_by_scope` marca
candidatos, não observações cientificamente aprovadas. `decision` inicia como
`pending` nos candidatos e `exclude` nos demais, com motivo em `reason`.

Os eventos de anomalia são conservados para todos os países nos anos relevantes,
inclusive eventos sem ano específico. Isso importa porque uma imputação fora
do Brasil pode afetar os requisitos mundiais de trabalho. As contagens são
pistas de revisão, não pesos, testes de significância ou medidas de qualidade.
`head()` é apenas uma prévia: examine a tabela completa antes de decidir.

Depois de ler os diagnósticos e a cobertura dos componentes, registre em
`report$series$decision` a decisão `include` ou `exclude`, e em `reason` sua
justificativa para cada candidato. Uma edição de revisão pode ser feita em uma
cópia da tabela no seu projeto de análise. **Não aprove todos os candidatos
apenas por apresentarem números finitos.** O bloco seguinte é executado somente
após essa revisão; ele recusa decisões pendentes e inclusões fora do recorte.

```r
review <- report$series
stopifnot(
  all(review$decision %in% c("include", "exclude")),
  all(!is.na(review$reason) & nzchar(trimws(review$reason))),
  !any(review$decision == "include" & !review$candidate_by_scope),
  !any(review$decision == "include" & review$reason == "pending_scientific_review")
)
analysis <- review[review$decision == "include", , drop = FALSE]
print(analysis[, c("year", "stored_value", "display_value", "display_unit", "reason")])
```

Preserve `review`, os diagnósticos completos e os manifestos junto à seleção
final. Salve os derivados no seu projeto de análise, ou em uma campanha de
`temp/<id>/` ao trabalhar neste repositório; nunca dentro do run publicado.
O exemplo não escolhe um diretório nem grava arquivos silenciosamente.

## Comparar razões com cobertura comum

O cálculo padrão de algumas taxas soma os dois componentes independentemente.
Assim, uma taxa mundial de pessoas ocupadas pode incluir horas imputadas do
ROW sem custo correspondente de reprodução. As regras constam na
[metodologia](methodology-pt.md) e em [ausências](missingness.md).

Uma análise de sensibilidade pode selecionar as **mesmas coordenadas completas**
para numerador e denominador, conservando a população e o filtro produtivo da
pergunta. Isso muda a cobertura e deve receber um rótulo próprio; não é uma
correção silenciosa da taxa publicada nem uma estimativa da parcela ausente.
Se as lacunas forem setoriais, use dados setoriais: uma taxa nacional finita
não revela, sozinha, quais setores entraram em cada componente.

O exemplo abaixo é autocontido, usa R básico e **dados hipotéticos**. Um segundo
grupo tem horas conhecidas e custo de reprodução ausente. A razão de somas
independentes é 300%; no grupo com ambos os componentes, é 100%.

```r
example <- new.env(parent = baseenv())
sys.source("scripts/examples/analysis_review.R", envir = example)
H <- c(100, 100)
V <- c(50, NA_real_)
independent_rate <- sum(H, na.rm = TRUE) / sum(V, na.rm = TRUE) - 1
matched <- example$wlv_example_common_coverage(H, V)
stopifnot(independent_rate == 3, matched$rate == 1,
          identical(matched$excluded, 2L))
print(c(independent_percent = 100 * independent_rate,
        common_coverage_percent = 100 * matched$rate))
```

Na aplicação real, informe quais países/setores foram incluídos e excluídos,
quantas coordenadas têm pares completos e a participação da amostra nos totais
conhecidos de cada componente. Para comparações temporais, examine também
uma amostra constante: coberturas que variam de ano para ano podem produzir
mudanças de composição. Excluir ROW não garante, por si só, cobertura completa
dos demais países. A interpretação fica condicionada à amostra resultante.

## Registre uma nota de dados reproduzível

Uma nota de dados identifica o material realmente utilizado, não apenas o
endereço de acesso. Conserve data de obtenção, nome e formato do arquivo,
método, anos, códigos dos indicadores, população, setores/países, unidades,
transformações, decisões de cobertura e versão do seu script de análise.
Inclua os identificadores da publicação quando fornecidos; registre
explicitamente os campos não informados na exportação.

Em uma publicação nativa, consulte também:

```r
manifest <- jsonlite::fromJSON(
  file.path(run_dir, "run_manifest.json"), simplifyVector = FALSE
)
print(manifest[c("method", "run_id", "result_id", "parent_run_id")])
print(manifest$output_contract)
str(manifest$result$provenance, max.level = 2L)
```

Preserve a release correspondente e os manifestos completos, e não somente os
campos exibidos acima. Um canal como `stable` pode selecionar outra release;
um arquivo obtido hoje não deve ser identificado pelo estado futuro do canal.
O [modelo de citação](citation-pt.md) distingue software, resultado, exportação,
publicação metodológica e fontes estatísticas, com referências para adaptação.

## Reprodução e contribuição são próximos percursos distintos

Para reconstruir as estimativas, siga [executar o projeto](guide-pt.md#executar-o-projeto).
Para propor uma alteração, siga [contribuir](guide-pt.md#contribuir-com-uma-melhoria).
Uma melhoria de interpretação não exige mudar fórmulas; uma nova população,
hipótese ou regra de agregação exige uma definição própria e evidências de
seus efeitos. Os exemplos auxiliares são verificados em
`tests/testthat/test-analysis-review-example.R`; esses testes sintéticos não
substituem uma execução com fontes reais.
