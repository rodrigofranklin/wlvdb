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

O cálculo WIOD13 novo também foi comparado ao completo preservado da campanha
054, com as mesmas fontes autenticadas: nenhum valor dos painéis mudou;
unidades, proveniência da fonte e os payloads FST das matrizes são idênticos em
bytes. Os dois sidecars `.fst.meta` das matrizes têm representação serializada
diferente e conteúdo `readRDS()` exatamente idêntico. Essa diferença de
serialização é discriminada no relatório, sem tolerância numérica nem alteração
do arquivo histórico.

**Estado da campanha:** validação real em execução. Resultados finais e hashes
serão registrados aqui após a conclusão de todos os cenários.
