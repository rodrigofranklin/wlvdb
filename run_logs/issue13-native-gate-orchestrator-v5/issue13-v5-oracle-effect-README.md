# Prova terminal fechada do efeito do oracle `cc2 → e2f`

Este conjunto produz uma prova auxiliar e causal para separar duas afirmações:

1. nos cinco métodos que já executavam em `cc2`, o oracle `e2f` não altera
   nenhum artefato científico sob comparação `strict`;
2. nos sete métodos recuperados, a falha observada em `cc2`, o arquivo que a
   corrige, as coordenadas atingidas, os valores permitidos e os diagnósticos
   publicados permanecem fechados por constantes e hashes.

A prova nunca substitui o gate científico V5. Seu envelope e seu schema exigem
`final_evidence_eligible=false`.

## Arquivos

- `issue13-v5-oracle-effect-spec.json`: manifesto imutável do patch, das 25
  relações arquivo×método recuperado×contrato, das evidências históricas 003 e
  do workflow terminal primary/replay;
- `issue13-v5-oracle-effect-proof.schema.json`: JSON Schema fechado e aplicado
  de fato por `Test-Json -SchemaFile`;
- `issue13-v5-oracle-effect-lib.ps1`: autenticação do oracle, do runtime, dos
  17 runs, das comparações e dos diagnósticos;
- `issue13-v5-oracle-effect-generate.ps1`: cria duas raízes novas, executa as
  dez comparações e grava uma prova nova;
- `issue13-v5-oracle-effect-validate.ps1`: relê todas as fontes e revalida a
  prova, incluindo uma nova sondagem autenticada do runtime R.

O materializador inclui esses arquivos no controller terminal e o coordenador
invoca diretamente o validador antes de adotar a prova.

## Limite causal preservado

O spec autentica `cc2c86189a06676bcb9f0e05e08033d710a92509`,
`e2f4d6dae9a6d35c966b305fabac52e489faa3e7`, o tree resultante, o patch
canônico, os oito pares de blobs e o fato de `e2f` ser filho direto de `cc2`.
Os summaries históricos continuam fixados pelos SHA-256:

- strict 003: `973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d`;
- oracle 003: `4ba530a191ef45baaaa08b2aa03ec6dcd0268aa6514caec6520203a0213afdfe`;
- patch canônico: `9f9b878f8e557973127e6260a0f224c868a0c4e8dc2db52dd6aa3f7131f28cd9`.

Esses dois summaries são aceitos somente em seus formatos históricos exatos:
o strict possui 16 propriedades, o oracle compat possui 19 propriedades
(incluindo o legado `environment_removed`), e nenhum deles contém campo
`rscript_*`. Não há injeção, fallback nem reescrita desses documentos selados.
Consequentemente, a identidade de Rscript registrada pela prova terminal é
uma vinculação atual, reaberta e recalculada durante o workflow; ela não prova
retroativamente qual executável gerou os summaries 003. Essa limitação é mais
um motivo para a prova permanecer auxiliar e
`final_evidence_eligible=false`.

Para os sete métodos recuperados, o validador continua exigindo:

- a falha strict e sua mensagem exata em `cc2`;
- o run aprovado em `e2f`, seu `result_id`, proveniência limpa e contrato
  `wlvpanel-output/1.0.0`;
- as 525 coordenadas `go_price.r.id|ano|ROW|setor`, quando aplicável, com
  `ROW = USA` no mesmo ano/setor;
- exatamente 405 anomalias históricas `NaN` em `alternative_2` e `petrovic`,
  com denominador finito igual a zero e saída finita igual a zero;
- o conjunto Leontief completo: 3.150 coordenadas no perfil `stable` ou 2.945
  no perfil `v09`, além dos diagnósticos assinados e checks científicos;
- em `norow_w13`, `_parameters.csv` UTF-8 com “Teste sem suposições para resto
  do mundo”.

## Runtime terminal obrigatório

`ComparisonHarnessManifest` deve apontar para
`v5-harness-manifest.json` de um runtime materializado terminal. O gerador e o
validador exigem simultaneamente:

- `generation = "v5-terminal"`;
- `source_controller.commit_sha256 = ExpectedCandidateCommit`;
- `source_tooling` idêntico no manifest e na derivação independente do
  candidato Git/local;
- `final_evidence_eligible = true`;
- `reuses_candidate_evidence = false`;
- inventário físico instalado, sem reparse points, exatamente igual a
  `output_tooling` e `sealed_output_tooling` e ao pin externo do
  `terminal_comparison_runtime.sealed_inventory` em contagem, bytes e SHA-256;
- os quatro arquivos exatos do comparador no harness flat;
- exatamente os 34 registros nome↔`relative_path` do controller terminal,
  vinculados ao blob Git e ao SHA-256 calculado sobre os bytes crus de
  `git cat-file blob` do commit esperado.

A raiz-fonte rastreada é exclusivamente
`run_logs/issue13-evidence-source-v5`: 37 arquivos, um diretório físico e dois
objetos tree (`.` e `issue13-evidence-harness`). O spec guarda apenas os campos
estáveis desse contrato: raiz relativa, contagens, SHA-256 da lista ordenada de
caminhos, as duas raízes relativas, os 37 caminhos obrigatórios e os modos
`040000`/`100644`. Commit, trees/blobs, bytes totais e hash de inventário são
deliberadamente dinâmicos e aparecem somente no `source_tooling` derivado.

A derivação usa `ProcessStartInfo.ArgumentList` e lê stdout como bytes crus;
`git ls-tree -z`, `git cat-file` e `git hash-object --no-filters` evitam
interpretação de shell, quebra por espaços e perda de delimitadores NUL. Cada
arquivo local precisa ser byte a byte idêntico ao blob do
`ExpectedCandidateCommit`. A lista dos 37 registros preserva a ordem fechada
do spec (inclusive `README.md` na posição 32), e não a ordem lexical do Git.
O manifest, o contexto anterior e a recaptura posterior precisam conter o
mesmo objeto derivado; qualquer troca do commit, tree, blob ou byte local
interrompe a prova.

Runtimes com basename contendo `v5c5` ou `v5c6`, manifests com o campo antigo
`candidate_commit` e qualquer geração anterior a `v5-terminal` são rejeitados.
A prova armazena o commit esperado, o hash do manifest, os três inventários e
o inventário físico completo instalado.

O fixture terminal está marcado `status = "sealed"` e fixa a tripla física
`47 / 2637821 / a4db0927…a29525bc`, derivada de uma staging write-once. Gerador e
validador recusam produzir ou adotar proof se status, contagem, bytes ou hash
divergirem desse selo.

## Comparações criadas pelo gerador

`ComparisonRoot` e `ReplayRoot` devem ser dois caminhos canônicos, distintos,
não aninhados e inexistentes, com pais já existentes. Cada ancestral existente
é percorrido e rejeitado se for reparse point. As duas raízes também devem ser
disjuntas do repositório, runtime/harness, `RLibrary` e raízes dos dois smokes;
essas condições são verificadas antes e depois da criação e após a execução. O
gerador se recusa a adotar uma raiz pré-fabricada. Ele cria e executa, nesta
ordem, uma fase `primary` e uma fase `replay`, cada uma com exatamente os
métodos:

```text
wiodr13
wiodr16
wiodr16v09
zerodep_1
zerodep_2
```

Cada comando usa `--vanilla`, o `issue13-compare-results.R` do harness terminal,
o executável informado em `Rscript` e o harness como diretório de trabalho. O
processo limpa o conjunto exato de 35 variáveis de locale/startup/`renv`, fixa
o set exato de dez entradas (`R_LIBS_USER=RLibrary`,
`RENV_PATHS_LIBRARY=<raiz-renv>`, `TZ=UTC` e sete opções
`RENV_CONFIG_*=FALSE`) e restaura o ambiente do processo ao terminar.
Candidate e baseline são
obtidos somente dos summaries autenticados e dos cenários
`baseline__calculate__<method>__workers1`; não há parâmetros livres para runs.

O ambiente do processo é tratado como estado tri-state, sem confundir
ausência com string vazia: `present=false,value=null` significa variável
ausente; `present=true,value=""` significa valor vazio visível; e
`present=true,value="..."` preserva um valor real. Os nomes de `set` e
`cleared` são únicos sem distinção de maiúsculas/minúsculas e os dois conjuntos
são disjuntos. Somente o setter remove uma variável ausente; valores vazios
são definidos, não removidos. Uma falha durante `Enter` desfaz todas as
mutações já aplicadas em ordem inversa; `Exit` tenta todas as restaurações e
agrega erros. Os autotestes negativos cobrem ausência, vazio, valor, sentinela,
exceção da ação, rollback parcial e restauração exata do ambiente externo.

Cada diretório de método deve terminar com somente:

```text
artifact-summary.csv
state-transitions.csv
indicator-differences.csv
comparison.json
```

Os três CSVs de primary/replay devem ser byte-idênticos. Os dois
`comparison.json` devem ser semanticamente idênticos depois de remover somente
o campo top-level `compared_at`. A prova preserva os dez comandos exatos, os
hashes brutos, os hashes normalizados e os dois timestamps.

Antes do primeiro comando e depois do último, o gerador recompõe em PowerShell
o contrato de `wlv13_run_inventory`/`wlv13_inventory_signature` para todos os
17 runs aprovados: 5 runs strict comuns e os 12 runs oracle. Ele enumera o
conjunto físico exato de arquivos, rejeita reparse points, verifica tamanho e
SHA-256 contra `run_manifest.json`, recalcula a assinatura declarada e confere
os pins de `scenario-result.json` e `scenario-spec.json`. Qualquer mutação
entre as duas capturas aborta a prova.

Antes e depois das comparações, uma sondagem `Rscript --vanilla` registra a
versão/plataforma R, `.libPaths()`, o conjunto exato de variáveis limpas/fixadas
e todos os namespaces carregados, com nome, versão, caminho, papel requerido,
contagem/bytes e SHA-256 recursivo do pacote. `fst`, `jsonlite` e `openssl` são
obrigatórios e devem resolver dentro de `RLibrary`. Os dois snapshots completos
precisam ser idênticos; proof, config e control preservam seus pins.

Além da sondagem R, cada captura abre novamente `Rscript.exe` e registra
exatamente seis campos: `logical_path` (resultado de `Resolve-Path`, com barras
invertidas no Windows), `physical_path`, `item_id`, `link_count`, `size_bytes`
e `sha256`. A identidade física combina o serial de volume de
`ByHandleFileInformation` em 16 hex com o `FileId` de 128 bits. Essa identidade
é capturada dinamicamente (a verificação local atual produz
`0000000034ee9270:0000000000000000000200000005ebe0`). O spec estável sela
somente `required_link_count=1`, `size_bytes=94720` e
`sha256=3ad097e1…15f9`; caminhos e `item_id` não são pins estáticos. O arquivo é
reaberto e hasheado antes e depois do
workflow, mesmo quando um `PreparedContext` é reutilizado. A prova publica a
identidade em `terminal_runtime.rscript` e nos snapshots `before`/`after` de
`runtime_immutability`, que devem ser exatamente iguais.

## Gerar e validar

Não execute em paralelo com smoke ou gate pesado: as comparações leem os arrays
FST existentes e podem consumir memória e I/O. O gerador nunca sobrescreve
prova ou raízes.

```powershell
$repo = 'D:\Trabalho\Code\wlvdb'
$toolRoot = Join-Path $repo 'run_logs\issue13-native-gate-orchestrator-v5'
$pwsh = 'C:\Users\rodri\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
$strictRoot = 'D:\Trabalho\Code\wlvdb-issue13-v5-cc2-smoke-003'
$oracleRoot = 'D:\Trabalho\Code\wlvdb-issue13-v5-compat-smoke-003'
$runtimeRoot = 'D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5-terminal-rerun-014'
$rscript = 'C:\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe'
$rLibrary = 'D:\Trabalho\Code\wlvdb\renv\library\windows\R-4.6\x86_64-w64-mingw32'
$candidateCommit = '<commit Git de 40 hex que materializou o runtime terminal>'
$comparisonRoot = 'D:\Trabalho\Code\wlvdb-issue13-oracle-effect-primary-terminal-rerun-014'
$replayRoot = 'D:\Trabalho\Code\wlvdb-issue13-oracle-effect-replay-terminal-rerun-014'
$proof = 'D:\Trabalho\Code\wlvdb-issue13-oracle-effect-proof-terminal-rerun-014.json'

& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $toolRoot 'issue13-v5-oracle-effect-generate.ps1') `
  -RepositoryRoot $repo `
  -ExpectedCandidateCommit $candidateCommit `
  -StrictSmokeSummary (Join-Path $strictRoot 'baseline-smoke-summary.json') `
  -OracleSmokeSummary (Join-Path $oracleRoot 'baseline-smoke-summary.json') `
  -OraclePatch D:\Trabalho\Code\wlvdb-issue13-v5-baseline-oracle-v2-e2f4d6dae9a6-canonical.patch `
  -ComparisonHarnessManifest (Join-Path $runtimeRoot 'v5-harness-manifest.json') `
  -Rscript $rscript `
  -RLibrary $rLibrary `
  -ComparisonRoot $comparisonRoot `
  -ReplayRoot $replayRoot `
  -OutputPath $proof
if ($LASTEXITCODE -ne 0) { throw 'Oracle-effect proof generation failed.' }

& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $toolRoot 'issue13-v5-oracle-effect-validate.ps1') `
  -RepositoryRoot $repo `
  -ExpectedCandidateCommit $candidateCommit `
  -StrictSmokeSummary (Join-Path $strictRoot 'baseline-smoke-summary.json') `
  -OracleSmokeSummary (Join-Path $oracleRoot 'baseline-smoke-summary.json') `
  -OraclePatch D:\Trabalho\Code\wlvdb-issue13-v5-baseline-oracle-v2-e2f4d6dae9a6-canonical.patch `
  -ComparisonHarnessManifest (Join-Path $runtimeRoot 'v5-harness-manifest.json') `
  -Rscript $rscript `
  -RLibrary $rLibrary `
  -ComparisonRoot $comparisonRoot `
  -ReplayRoot $replayRoot `
  -ProofPath $proof
if ($LASTEXITCODE -ne 0) { throw 'Oracle-effect proof validation failed.' }
```

Qualquer arquivo ausente ou excedente, hash divergente, runtime não terminal,
método fora da partição 5+7, comparação não reprodutível, transição fora da
diagonal, coordenada duplicada, diagnóstico inesperado, run sujo, reparse point
ou tentativa de promover a prova a evidência final interrompe o processo.
