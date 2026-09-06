# Consistência entre cálculo completo e recálculo — issue #28

Este registro resolve a divergência WIOD13 do recálculo desde o estágio 4
identificada no [issue #13](issue-13.md). O recálculo deve usar a mesma base de
preços da cesta empregada pelo cálculo completo. Alterar a base de cada índice
setorial antes da agregação muda os pesos econômicos da cesta; normalizar o
índice agregado depois da soma não desfaz essa mudança.

## Causa e decisão metodológica

Na WIOD13, a fonte normalizada `GO_P` guarda índices de preços com **1995 = 1**.
O recurso `basket_zero` conserva a cesta do primeiro ano, 1995, com participações
monetárias desse ano. O pressuposto de resto do mundo usa os índices dos Estados
Unidos como proxy para `ROW`. O cálculo completo consome esses índices antes de
publicar `go_price.r.id` com **2000 = 1**.

Escrevendo (w_{ic,1995}) para a participação fixa do setor de origem (i)
na cesta do país (c), e (p_{it}/p_{i,1995}) para `GO_P`, o índice de preço
publicado é:

\[
 I_{ct} =
 \frac{\sum_i w_{ic,1995}(p_{it}/p_{i,1995})}
      {\sum_i w_{ic,1995}(p_{i,2000}/p_{i,1995})}.
\]

O caminho antigo do recálculo importava o indicador terminal já normalizado
por setor, substituindo `GO_P` por (p_{it}/p_{i,2000}). Isso introduzia fatores
setoriais distintos dentro da soma, equivalentes a mudar os pesos originais.
A normalização final em 2000 fazia os caminhos coincidirem nesse ano, mas não
nos demais. Não era erro de arredondamento nem diferença necessária entre
cálculo completo e recálculo.

A correção em `R/lib/native_planner.R` e
`R/modules/native/indicator_source_derived_modules.R` declara `source/sea`
como dependência dos módulos de cesta no recálculo WIOD13 do estágio 4.
O helper `wlv_native_basket_go_price()` recupera `GO_P` da fonte autenticada e
aplica a mesma proxy `USA` → `ROW`. O valor publicado de `go_price.r.id` continua
herdado do pai. Os caminhos do cálculo completo, do estágio 1 e da WIOD16
mantêm suas fórmulas anteriores.

O índice `basket_value.r.pc` também consome esses preços, combinados com o
índice cambial e os coeficientes de trabalho. Os dois indicadores de remuneração
em USD constantes dependem do índice de preço: `LAB` ou `COMP`, em moeda
nacional, é dividido pelo índice da cesta e pela taxa cambial de 2000. Portanto,
o erro do deflator alcançava a interpretação da remuneração real.

## Alcance histórico autenticado

As provas anteriores em `temp/054/` permanecem inalteradas. O script
`tests/manual/issue28-historical-delta.R` lê os dois painéis, autentica seus
arquivos e metadados contra os manifests originais e registra coordenadas,
anos, unidades e diferenças. Os caminhos antigos são resolvidos pelo mapa
`temp/054/relocation-map.json`; nenhum arquivo autenticado é reescrito.

Foram afetadas **81.132 células**: 78.836 setoriais e 2.296 nacionais/mundiais.
Os anos são 1995–1999 e 2001–2009; 2000 permanece idêntico. Os rótulos e as
posições `NA`/`NaN` não mudaram. As matrizes permaneceram idênticas na prova
original do #13.

| Indicador | Células setoriais | Células nacionais/mundiais | Unidade |
|---|---:|---:|---|
| `basket_price.r.pc` | 20.090 | 574 | Índice, 2000 = 1 |
| `basket_value.r.pc` | 20.090 | 574 | Índice, 2000 = 1 |
| `compensation.emp.s.cu` | 19.331 | 574 | USD constantes de 2000 |
| `compensation.empe.s.cu` | 19.325 | 574 | USD constantes de 2000 |

Na Lituânia, em 2008, o índice de preço era 2,23396152541688 no cálculo
completo e 1,58676332719398 no recálculo antigo, diferença de 0,647198198222900.
Na Bulgária, em 1995, o índice de valor era 0,985665776808987 e
1,13585649087072, respectivamente. A maior diferença absoluta setorial da
remuneração foi USD 15.636.223.962,30, no setor `L` dos EUA em 2008.

Na remuneração mundial de todas as pessoas ocupadas, em 2009, o completo
produziu USD 18.760.372.664.429,90 e o recálculo antigo produziu
USD 19.194.273.800.935,90: diferença de USD 433.901.136.506,00 constantes de
2000. A maior diferença relativa de remuneração entre as células finitas com
referência não nula foi 67,4403%. Essas medidas descrevem o erro de recálculo,
sem atribuir interpretação causal às diferenças entre países ou anos.

## Garantias de uso

As garantias pressupõem fonte normalizada, parâmetros e contratos científicos
compatíveis com o pai autenticado. O contrato completo está em
[scientific-validation.md](../scientific-validation.md).

| Modalidade | Garantia |
|---|---|
| Estágio 1 completo | Recalcula pressupostos e indicadores; preserva matrizes e diagnósticos de matriz. Com entradas inalteradas, os indicadores equivalem ao cálculo completo. `sea_vars` é proibido. |
| Estágio 4 completo | Recalcula indicadores desse estágio e posteriores; recupera a base original dos preços das cestas WIOD13. Os indicadores anteriores e as matrizes permanecem iguais. |
| Estágio 5 completo | Recalcula os indicadores setoriais desse estágio e suas agregações; preserva estágios anteriores e matrizes. |
| Estágio 4 ou 5 seletivo | Recalcula somente os indicadores declarados em `sea_vars` e suas agregações. Os insumos não selecionados vêm do pai; não há atualização implícita de outros indicadores dependentes. Todas as células e estados fora da seleção permanecem idênticos. |

Selecionar somente `basket_price.r.pc` não recalcula automaticamente
`compensation.emp.s.cu` ou `compensation.empe.s.cu`. Para reparar o conjunto
histórico inteiro, use cálculo completo novo ou recálculo completo do estágio 4
de um pai compatível. O estágio 5, sozinho, não repara um índice de cesta
incorreto herdado.

O fingerprint de compatibilidade do runtime mudou com a correção. Um run anterior
incompatível continua bloqueado: é necessário produzir um pai novo com
`get_wlv()`. Não se altera o fingerprint do pai nem se promove um recálculo
incompleto. Os manifests continuam vinculando `parent_run_id`, solicitação,
fontes, contratos e inventário integral de artefatos; a publicação só avança
o canal após todas as validações.

## Verificação reproduzível

`tests/testthat/test-recalculation-price-basis.R` usa preços de dois setores
com bases distintas. Reproduz diferenças maiores que 0,01 em ambos os índices
de cesta pelo caminho antigo e exige identidade exata no caminho corrigido.
Também cobre determinismo, rótulos, preservação do índice publicado,
dependências e o conjunto de saídas dos planos completos/seletivos dos dois
modelos. A fixture nova é finita; a cobertura de ausências efetivas e estados
semânticos vem dos testes existentes e dos painéis reais. Os testes existentes
de execução e publicação também verificam incompatibilidade de pai, seleção
inválida e publicação atômica.

Um controle negativo em cópia descartável forçou o helper a voltar a consumir
o índice publicado. A regressão falhou em quatro verificações numéricas:
1,8 em vez de 1,89473684210526 no segundo ano, para os dois índices. O teste,
portanto, detecta a volta do comportamento científico incorreto, além de
verificar a configuração do grafo. O log é `logs/regression-negative-control.log`.

A campanha nova é `temp/issue28-recalculation/`, criada com
`scripts/manage-campaigns.ps1 -Action New -Id issue28-recalculation` no commit
base `be7d62659710b51bb9a3bbe667bb5c3dd462e751`. O root de execução é uma cópia
fixa em `worktrees/candidate`, sem `.git`; seus manifests registram commit
`null` e o inventário SHA-256 efetivamente executado. O commit base identifica
a origem da cópia, não substitui os hashes dos arquivos modificados.

A geração do runtime executado é
`863e93f94a881e24c43074be76afbe0dfdcce30eb718beb08e5f113427d809d5`.
A auditoria independente inicial, anterior à correção adicional da publicação
conjunta, comparou a cópia com a árvore comentada: 211 arquivos R e 3.191
expressões possuem AST idêntica. As correções posteriores da leitura de metadados
de publicação (#31) e da escrita CSV com Unicode em locale C (#32) são
verificadas separadamente na [validação integrada do #15](issue-15.md).
Esse vínculo de evidência não torna os runtimes operacionalmente
intercambiáveis: a geração de compatibilidade incorpora os bytes do código,
inclusive comentários. Portanto, os runs desta cópia não são pais reutilizáveis
diretamente pelo runtime final comentado. Nesse runtime, `get_wlv()` deve criar
um pai novo. Os fingerprints e os runs da campanha permanecem inalterados.

As fontes preparadas vêm das cópias candidatas autenticadas da campanha 054.
A primeira tentativa recusou, antes do cálculo, o contrato obsoleto da fonte
preparada no repositório principal. O log dessa recusa foi preservado. Nenhuma
fonte foi reclassificada nem teve seu manifest adaptado para fazê-la passar.

O runner `tests/manual/issue28-recalculation.R` usa as APIs públicas,
canais isolados e relatórios por cenário. WIOD13 usa `validation/issue28`;
WIOD16 usa `validation/issue28/wiodr16`. O controlador
`tests/manual/issue28-recalculation-suite.ps1` retoma relatórios aprovados,
recusa tentativas inconclusas e direciona `TEMP`, `TMP`, `TMPDIR` para
`scratch/`. `LC_ALL=LANG=C` remove os avisos de locale nos cenários posteriores
ao primeiro completo. A preservação textual é verificada nos arquivos e rótulos
desses runs; não substitui a regressão Unicode geral do writer, corrigida no #32.
As invocações retomadas usam uma cópia congelada do R harness por cenário.

O ambiente efetivo da campanha usa R 4.6.1 e as mesmas 45 versões de pacotes
registradas nos manifests dos completos preservados da campanha 054. As 33
dependências que constam de `renv.lock` possuem versões semanticamente iguais
às fixadas; a comparação interpreta versões R, inclusive a equivalência entre
`Matrix` 1.7.5 e 1.7-5. O pacote opcional `data.table` 1.18.4 também estava
presente nos runs 054 e nesta campanha, mas não integra o lock. Essa descrição
registra o ambiente realmente executado, sem atribuir-lhe ativação de `renv`
que não ocorreu. A validação integrada do #15 usa `--vanilla`, ativação explícita
da biblioteca fixada e o caminho base de FST quando `data.table` está ausente.

O primeiro cálculo WIOD16 produziu e validou o run
`run-20260906T013526440Z-a787bfa40bfdd3bb`, mas a tentativa de juntá-lo ao canal
WIOD13 falhou: o leitor de metadados tratava campos opcionais vazios como valores
declarados e os considerava conflitantes com o preenchimento da outra fonte.
Essa tentativa permanece registrada como **exit 1**. Não houve erro de parser,
alteração de fingerprint nem publicação de uma release parcial.

`tests/manual/issue28-recover-publication.R` autenticou os artefatos desse run,
comparou exatamente inventários de código, compatibilidade, fonte e insumos
adicionais e chamou `wlv_commit_release()` sob lock para um canal novo de um
único método. Nenhum cálculo foi repetido ou run alterado. O relatório
`wiodr16-publication-recovery.json` mantém a falha original e comprova a
recuperação. A correção do merger e a publicação conjunta no runtime final
possuem evidência própria no #15.

Cada comparação exige identidade exata dos painéis, dimensões e rótulos,
posições `NA`/`NaN`, estados semânticos do snapshot, unidades, metadados,
proveniência da fonte e hashes das matrizes. Seleções incluem comparação
explícita com o pai para as células não selecionadas. Nenhuma tolerância foi
aumentada.

Os cálculos completos novos de WIOD13 e WIOD16 também foram comparados aos
completos preservados da campanha 054, com as mesmas fontes autenticadas:
nenhum valor dos painéis mudou; os estados semânticos e máscaras de ausência
são idênticos. Os arquivos de unidades, proveniência da fonte e os payloads
FST das matrizes são idênticos em bytes. Os dois sidecars `.fst.meta` das
matrizes têm representação serializada
diferente e conteúdo `readRDS()` exatamente idêntico. Essa diferença de
serialização é discriminada no relatório, sem tolerância numérica nem alteração
do arquivo histórico.

A prova histórica do #13 de equivalência entre `workers = 1` e `workers = 2`
nos caminhos completos e de recálculo que não tiveram suas fórmulas alteradas
é reutilizada com sua autoria temporal e seus hashes originais. Ela não é
apresentada como execução do commit novo. Nesta campanha, o estágio 4 completo
e a seleção dos dois índices de cesta são executados novamente com ambos os
números de workers; a repetição parte do resultado recém-publicado e exige a
mesma identidade exata ao completo. A seleção do estágio 5 também é verificada
com ambos os números de workers.

Para reproduzir os cálculos, restaure as dependências de `renv.lock`, crie uma
campanha nova pelo gerenciador e provisione `worktrees/candidate` com a cópia
fixa do código, metadados iniciais de `results/` e fontes normalizadas com
manifests compatíveis. O controlador recusa campanha encerrada ou candidato
ausente. Depois dessa preparação, execute, da raiz do repositório:

```powershell
pwsh -NoProfile -File tests/manual/issue28-recalculation-suite.ps1 -CampaignId issue28-reproduction
```

O lançador versionado após a campanha usa `Rscript --vanilla` e ativa
`renv/activate.R` explicitamente. Um runtime diferente exige seu próprio
cálculo completo; não se retoma um pai antigo alterando a autenticação.
`tests/manual/issue28-summarize.R` consolida os 18 relatórios sem recalcular:
confere hashes de manifests, requisições, linhagem, artefatos herdados,
comparações históricas, versões registradas e contagens efetivas de ausência.
Seu segundo argumento é um relatório novo, que não pode existir previamente.

## Resultado da campanha nova

Os **18 cenários científicos** terminaram com os resultados esperados: dois
cálculos completos e **16 recálculos exatamente iguais ao respectivo completo**.
O número de cenários abaixo inclui WIOD13 e WIOD16:

| Modalidade | Seleção | Workers | Cenários aprovados |
|---|---|---|---:|
| Cálculo completo | Todos | 1 | 2 |
| Recálculo, estágio 1 | Todos | 1 | 2 |
| Recálculo, estágio 4 | Todos | 1 e 2 | 4 |
| Recálculo, estágio 5 | Todos | 1 | 2 |
| Recálculo, estágio 4 | `basket_price.r.pc`, `basket_value.r.pc` | 1 e 2 | 4 |
| Recálculo, estágio 5 | `gross_output.s.du` | 1 e 2 | 4 |

Essa contagem é científica: a tentativa original de publicação conjunta do
completo WIOD16 continua sendo uma falha de API, recuperada pelo procedimento
autenticado descrito acima. A suite retomada dos oito recálculos WIOD16 terminou
com exit 0. A publicação conjunta corrigida tem sua própria prova no #15.

Foram comparadas 25.333.920 posições de painéis nos 16 recálculos, sem
divergências. A igualdade inclui ausências efetivas, além de valores finitos:

| Modelo e painel | Células por painel | Células `NA` |
|---|---:|---:|
| WIOD13 setorial | 1.248.450 | 25.856 |
| WIOD13 nacional/mundial | 36.540 | 540 |
| WIOD16 setorial | 1.848.000 | 46.777 |
| WIOD16 nacional/mundial | 33.750 | 375 |

Os quatro painéis não contêm `NaN`; suas máscaras foram comparadas e os estados
semânticos completos foram preservados. As seleções conservaram exatamente as
células externas à lista pedida. As matrizes, parâmetros, diagnósticos de
Leontief/GFCF, metadados, unidades e proveniência herdados também passaram na
comparação de SHA-256 contra o cálculo completo de referência.

O consolidado `results/summary.json` autentica os 18 relatórios e manifests,
confere toda a cadeia de pais e as solicitações declaradas e vincula as provas
históricas e a recuperação. Seu SHA-256 é
`c2749a9ddda4569e66473daf07759c39f1886b94ee28b98af2221590509c1e49`.
Os manifests dos completos que serviram de referência são:

- WIOD13, `run-20260906T011636058Z-a7f71103e10afefc`:
  `aa67dd40bf1c763d622de2c259781fd6d9ebfae403bc90127a420cfa09f7ac79`.
- WIOD16, `run-20260906T013526440Z-a787bfa40bfdd3bb`:
  `0872bb14b2f7781b3f1b96903abca777817d712b558942dc0186ba87c6ffa5de`.

As provas históricas finais são `results/historical-delta-v2.json`,
`results/wiodr13-full-to-054-v3.json` e `results/wiodr16-full-to-054.json`.
A versão v3 da comparação WIOD13 acrescenta a autenticação dos snapshots e a
igualdade de estados semânticos; as versões anteriores foram preservadas.
Nenhum cálculo foi repetido para acrescentar essa verificação de leitura.

A campanha foi encerrada como **completed**, com **preserve = true**. Os 18
runs, relatórios, tentativas falhas, logs e harnesses congelados permanecem em
`temp/issue28-recalculation/`. O controle negativo está preservado em
`worktrees/regression-control`. Os 914.458.356 bytes de fontes duplicadas foram
removidos por uma campanha auxiliar encerrada, após inspeção e `Clean -Apply`;
as fontes originais da campanha 054 e do repositório principal permanecem
inalteradas. A pasta `scratch/` ficou vazia. `results/cleanup-completed.json`
confere que os 18 relatórios e manifests conservaram seus hashes após a limpeza;
seu SHA-256 é
`5a327ac2232e6ac280c85e8f479be80ee2fc7c72742ffe0a0015dbdbce821cd5`.
