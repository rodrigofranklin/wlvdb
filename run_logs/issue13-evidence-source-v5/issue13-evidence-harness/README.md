# Fonte canônica do harness externo de evidência — Issue #13

Este diretório é a fonte rastreada e autenticada do gate real externo ao
runtime. Ele não é carregado pela aplicação nem entra em manifests de
publicação. Todos os outputs de evidência devem ficar fora dos worktrees
avaliados.

`run_logs/issue13-evidence-source-v5` é a única origem do materializador V5. O
materializador vincula cada arquivo e os dois objetos de árvore ao commit
candidato antes e depois da projeção, e registra essa proveniência em
`source_tooling`. Cópias históricas como `issue13-evidence-runtime-v4` não são
entrada, fallback nem dependência operacional.

Por padrão, execute
`run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-materialize-harness.ps1`
sem sobrescrever a origem. O destino deve ser novo, externo ao repositório e
fisicamente distinto desta árvore canônica.

Nos exemplos abaixo, aponte as duas variáveis para o runtime novo produzido
pelo materializador; nenhum comando depende de uma raiz `run_logs` histórica:

```powershell
$Issue13RuntimeRoot = 'D:\gate\issue13-v5-runtime'
$Issue13HarnessRoot = Join-Path $Issue13RuntimeRoot 'issue13-evidence-harness'
```

O gate é fechado por padrão: faltas, duplicatas, cenários extras, hashes
inconsistentes, inventários não autenticados, exceções de política, clusters
abertos ou relações de parent incorretas fazem o agregado falhar.

## Matriz normativa

- 12 métodos.
- Dois braços: `baseline` e `candidate`.
- Por método: cálculo `workers=1` e cinco recálculos independentes:
  `stage1/full`, `stage4/full`, `stage5/full`,
  `stage4/select-gross-output-mv` (`gross_output.s.mv`) e
  `stage5/select-gross-output-du` (`gross_output.s.du`).
- `workers=2` para `wiodr13` e `wiodr16`, nos dois braços.
- Preparação conjunta de WIOD13/WIOD16/EU KLEMS, nos dois braços.
- Paper 0 com `ochoa_1` e `ochoa_2`, par historicamente executável e aceito pelo
  preflight e pertencente ao mesmo contrato-fonte WIOD13.
- Dez gates de falha: módulo, promoção de preparação e oito fronteiras da
  publicação.

São 162 cenários monitorados e 202 comparações autenticadas. A lista exata é
gerada por `issue13-matrix.R`; o agregador rejeita qualquer desvio.

## Commits e perfis separados

O harness distingue deliberadamente:

- `runtime_commit`: commit do código que executa o cenário atual;
- `seed_commit`: commit que produziu o run completo imutável usado como input
  do recálculo.

O candidato usa um commit global e pode declarar separadamente o commit do full
imutável usado como seed. O baseline final usa um índice externo autenticado com
um único perfil, `compatibility-oracle-cc2`, produzido pelo runtime-filho direto
autorizado do `cc2`. Todos os cálculos e recálculos de um método compartilham
esse perfil e commit; cada recálculo aponta para o full baseline correspondente.
O smoke estrito no `cc2` permanece uma evidência histórica negativa separada
(5 métodos executáveis e 7 falhas esperadas), nunca um perfil do gate final. O
índice exige cobertura exata da matriz, SHA-1 completo, SHA-256 e patch-id
estável do overlay autorizado e nunca pode referenciar o commit candidato.

O gate final aceita somente cenários executados nativamente. Campos
`execution_mode` ou `authentication`, inclusive nulos ou desconhecidos, são
rejeitados nos dois braços. Evidência histórica não é relabelada nem reutilizada
como cenário final; inclusive Ochoa é executado novamente nos dois braços.

## Recálculo independente por canal

Cada recálculo deve usar um canal exclusivo e vazio. O semeador cria uma nova
release que referencia o mesmo `run_id` completo; os arrays grandes **não são
copiados**. Ele autentica manifest, inventário, `parent_run_id = NULL`,
`mode = calculate`, `workers = 1` e o commit de proveniência do seed antes de
instalar release e marker.

Exemplo para gerar um bundle:

```powershell
Rscript --vanilla "$Issue13HarnessRoot\issue13-build-recalc-bundle.R" `
  --arm candidate `
  --method alternative_2 `
  --stage 4 `
  --variant select-gross-output-mv `
  --project-root D:\gate\candidate `
  --runtime-commit <SHA_RUNTIME_CANDIDATE> `
  --seed-commit <SHA_DO_FULL_CANDIDATE> `
  --seed-result D:\evidence\scenarios\candidate__calculate__alternative_2__workers1\scenario-result.json `
  --channel issue13-candidate-alternative2-s4-select-mv `
  --r-library D:\gate\renv\library\windows\R-4.6\x86_64-w64-mingw32 `
  --output D:\evidence\specs\candidate-alternative2-s4-select-mv `
  --evidence-root D:\evidence
```

O bundle contém specs de seed, cenário e processo. Execute-o assim:

```powershell
& "$Issue13HarnessRoot\issue13-run-recalc-bundle.ps1" `
  -BundlePath D:\evidence\specs\candidate-alternative2-s4-select-mv\bundle.json
```

O runner instala o canal-seed e inicia um novo `Rscript` pelo monitor. Antes de
`recalc_wlv()`, o cenário confirma que o canal resolve exatamente ao full
declarado. Depois, confirma que o output é um filho direto desse `run_id`.
Portanto, executar por engano sobre o filho do cenário anterior falha antes do
cálculo.

## Comparações

`issue13-compare-results.R` recebe diretamente dois `scenario-result.json` e
seletores autenticados:

- `run:<método>`;
- `source:wiodr13` ou `source:wiodr16`;
- `snapshot:euklems`;
- `release`.

Paridade entre candidato e baseline do mesmo cenário:

```powershell
Rscript --vanilla "$Issue13HarnessRoot\issue13-compare-results.R" `
  --candidate-result D:\evidence\scenarios\candidate__recalculate__alternative_2__stage4__full\scenario-result.json `
  --candidate-selector run:alternative_2 `
  --baseline-result D:\evidence\scenarios\baseline__recalculate__alternative_2__stage4__full\scenario-result.json `
  --baseline-selector run:alternative_2 `
  --output D:\evidence\comparisons\parity__recalculate__alternative_2__stage4__full `
  --scenario-id parity/recalculate/alternative_2/stage4/full
```

Oracle do baseline (filho versus full do próprio baseline):

```powershell
Rscript --vanilla "$Issue13HarnessRoot\issue13-compare-results.R" `
  --candidate-result <BASELINE_CHILD_RESULT> `
  --candidate-selector run:alternative_2 `
  --baseline-result <BASELINE_FULL_RESULT> `
  --baseline-selector run:alternative_2 `
  --output <ORACLE_OUTPUT> `
  --scenario-id oracle/baseline/recalculate/alternative_2/stage1/full
```

Um oracle divergente retorna código 1 e ainda grava a evidência. Isso é
esperado: o agregador classifica o cenário a partir do resultado observado.
Ele só exige `child == full` no candidato quando o oracle equivalente do
baseline é exato. Quando o baseline diverge, registra
`baseline-known-divergence`; não existe whitelist por método.

### Semântica dos artefatos

- Arrays FST são lidos em chunks, com dimensões/dimnames exatos e estados
  distintos para finito, `NA`, `NaN`, `+Inf` e `-Inf`.
- Tabelas FST (EU KLEMS) são comparadas por coluna e chunk.
- CSVs normativos preservam ordem.
- CSVs cujo role autenticado é `diagnostic`, inclusive `_anomalies.csv`, são
  comparados como multiset canônico de linhas. A ordem não é normativa, mas
  duplicatas contam; qualquer linha ausente, extra ou alterada falha.
- JSON é canonicalizado por nomes; RDS usa identidade semântica; XLSX compara
  sheets e células; formatos desconhecidos exigem bytes idênticos.
- O comparador recusa arquivos ausentes, extras, manifests inválidos e mudança
  dos bytes durante a comparação.

## Monitor e processo

`issue13-monitor.ps1` é o monitor Windows do gate real. Para cada cenário ele:

- inicia processo novo e oculto;
- identifica PID + CreationDate para evitar reuso de PID;
- acompanha toda a árvore de processos;
- amostra RSS/private/CPU em CSV;
- mede o pico agregado da árvore;
- exige zero workers R filhos para `workers=1` e exatamente dois para
  `workers=2`;
- aguarda o encerramento dos descendentes e mata apenas a árvore conhecida em
  timeout/cluster pendente;
- autentica spec, stdout, stderr e amostras com SHA-256.

`issue13-run-plan.ps1` executa uma coleção de specs já pronta. Para recálculos,
prefira o bundle, pois ele inclui a prova do canal-seed.

## Preparação normativa

O conjunto de preparação e falhas é gerado de uma só vez, antes de qualquer
execução. O builder recusa worktrees fora dos commits fixados, runtime rastreado
sujo, raiz de evidência existente ou namespace de canais inválido:

```powershell
Rscript --vanilla "$Issue13HarnessRoot\issue13-build-prep-fault-specs.R" `
  --output-root D:\evidence-prep-fault `
  --baseline-root D:\gate\baseline-prep `
  --baseline-commit <SHA_BASELINE> `
  --candidate-root D:\gate\candidate-prep `
  --candidate-commit <SHA_CANDIDATE> `
  --fault-root D:\gate\candidate-fault `
  --r-library D:\gate\renv\library\windows\R-4.6\x86_64-w64-mingw32 `
  --channel-prefix issue13-prep-fault-

Rscript --vanilla "$Issue13HarnessRoot\issue13-audit-prep-fault-plan.R" `
  D:\evidence-prep-fault\plan.json
```

O auditor exige exatamente dois cenários de preparação e as dez fronteiras de
falha canônicas. Ele também revalida tamanho e SHA-256 dos seis caches oficiais,
prova que os dois worktrees de preparação contêm somente os caches, autentica
todos os specs e confirma que nenhum diretório de cenário já existe.

Cada preparação deve ser iniciada individualmente pelo monitor, usando o
`process-spec.json` auditado. Depois dos dois braços, o comparador estrito usa o
mesmo `plan.json`, `process-metrics.json` e `scenario-result.json`:

```powershell
Rscript --vanilla "$Issue13RuntimeRoot\issue13-preparation-compare.R" `
  D:\gate\baseline-prep D:\gate\candidate-prep D:\evidence-prep-compare `
  <SHA_BASELINE> <SHA_CANDIDATE> 1000000 `
  D:\evidence-prep-fault\scenarios\baseline__prepare__all\process-metrics.json `
  D:\evidence-prep-fault\scenarios\candidate__prepare__all\process-metrics.json `
  D:\evidence-prep-fault\scenarios\baseline__prepare__all\scenario-result.json `
  D:\evidence-prep-fault\scenarios\candidate__prepare__all\scenario-result.json `
  D:\gate\library D:\evidence-prep-fault\plan.json
```

As regras exatas estão em
`$Issue13RuntimeRoot\issue13-preparation-rule-matrix.json`. Não há
lista de artefatos ignorados nem tolerância numérica: arrays usam comparação
bitwise, incluindo `NA`, `NaN`, infinitos e zero assinado. O comparador também
recalcula os hashes de plan-audit, specs, logs, amostras, manifests e snapshot,
e rejeita qualquer staging ou lock remanescente.

## Fault gates

Um cenário de falha declara o objeto `fault` com `fault_id`, `binding`, `when`,
`call`, `checkpoint` e token único `issue13-injected-...`. A matriz fixa ação,
binding, ordinal e checkpoint; o spec não pode escolher uma chamada mais fácil.
O wrapper é instalado apenas na memória daquele processo, registra que a
fronteira foi realmente atingida e é restaurado antes da verificação de
integridade do runtime.

O gate de promoção EU KLEMS intercepta, dentro de
`wlv_commit_preparation_result()`, o checkpoint
`after_install:euklems.capital.1995`. Assim ele falha depois da primeira
instalação e prova o rollback da transação, em vez de abortar antes do commit.
Os gates de staging injetam somente depois que o cleanup foi armado:
`wlv_new_contract_runtime()` para run e `wlv_merge_panel_result_tables()` para
release. O gate de promoção da release usa a segunda chamada autenticada de
`wlv_read_release_manifest()`: a primeira verifica a release anterior e a
segunda lê a release recém-promovida, ainda antes do marker.

O agregado exige, simultaneamente: erro injetado e reconhecido, marker
inalterado, nenhuma release parcial visível, staging de publicação vazio,
staging/locks de preparação vazios, gerações normalizadas inalteradas e
release anterior verificável.

Os fault gates usam um terceiro worktree/store. Depois da preparação candidata
passar, `issue13-import-fault-inputs.R` copia para esse store somente fontes
preparadas e um full `wiodr13/workers=1` já autenticado. A cópia é rehashada
arquivo a arquivo; o script confirma que os dois stores de origem não mudaram
e emite uma prova de seed cujo único campo ajustado é o caminho canônico da
cópia imutável. Uma falha deixa o worktree inválido para inspeção e exige outro
worktree — o script nunca apaga nem corrige silenciosamente uma importação
parcial.

`issue13-build-fault-seed-specs.R` gera dez canais exclusivos, um por fronteira.
`issue13-run-fault-seeds.ps1` instala e monitora as dez releases-seed; depois,
cada fault spec auditado é executado individualmente com
`issue13-run-prep-fault-record.ps1`. O agregado específico relê hashes, verifica
que todos os dez canais continuam apontando para suas releases-seed e exige
zero staging/lock:

```powershell
Rscript --vanilla "$Issue13HarnessRoot\issue13-aggregate-prep-fault.R" `
  --plan D:\evidence-prep-fault\plan.json `
  --preparation-comparison D:\evidence-prep-compare\issue13-preparation-comparison.json `
  --import-report D:\evidence-prep-fault\fault-inputs\fault-input-import.json `
  --seed-plan D:\evidence-prep-fault\fault-seeds\seed-plan.json `
  --output D:\evidence-prep-fault\aggregate
```

## Agregação final

```powershell
Rscript --vanilla "$Issue13HarnessRoot\issue13-aggregate.R" `
  --evidence-root D:\evidence `
  --output D:\evidence-final `
  --baseline-base-commit <SHA_BASE_CC2> `
  --candidate-commit <SHA_RUNTIME_CANDIDATE> `
  --candidate-seed-commit <SHA_FULL_CANDIDATE> `
  --baseline-runtime-index D:\evidence-specs\baseline-runtime-index.json `
  --baseline-runtime-index-sha256 <SHA256_DO_INDICE>
```

Antes de concluir, o agregador relê uma vez cada inventário distinto e confere
todos os bytes autenticados. Também aplica, por cenário pareado:

- tempo candidato `<= 120%` do baseline;
- RSS candidato `<= baseline + max(10%, 512 MiB)`;
- equivalência workers 1/2;
- vínculo exato de cada comparação aos outputs registrados;
- completude e unicidade de toda a matriz.

Outputs: `aggregate.json`, `checks.csv`, `oracle-classification.csv` e
`performance.csv`.

## Self-tests leves

```powershell
Rscript --vanilla "$Issue13HarnessRoot\issue13-selftest.R"
& "$Issue13HarnessRoot\issue13-monitor-selftest.ps1"
Rscript --vanilla "$Issue13HarnessRoot\issue13-seed-runtime-selftest.R" `
  <BASELINE_ROOT> <BASELINE_COMMIT> <CANDIDATE_ROOT> <CANDIDATE_COMMIT> [LIBRARY]
```

O teste cria somente fixtures temporárias pequenas. Ele cobre:

- comparação chunked e transição `NA -> NaN`;
- `_anomalies.csv` reordenado com duplicatas;
- agregado positivo completo (162 cenários/202 comparações);
- uma divergência histórica derivada do oracle;
- rejeição fail-closed quando falta uma comparação, telemetria ou log;
- índice baseline sem cenários extras/ausentes, mistura de perfis ou commit
  candidato;
- rejeição de evidência importada nos dois braços e no semeador;
- carregamento fail-closed dos runtimes legado e candidato pelo semeador.

O monitor também pode ser testado com um `Rscript` que apenas executa
`Sys.sleep(0.35)`; não é necessário nem permitido usar jobs científicos para
esse teste.

Para validar somente o parser, a identidade byte a byte dos helpers de ambiente,
os valores definidos estritamente como strings (inclusive a string vazia), o
`null` declarado como remoção temporária e a restauração tri-state (`ausente`,
vazio e valor), sem iniciar R, use
`issue13-monitor-selftest.ps1 -SkipSyntheticProcess`.

## Inventário

- `issue13-lib.R`: validação, manifests, hashing e snapshots.
- `issue13-compare-lib.R`, `issue13-compare.R`,
  `issue13-compare-results.R`: comparação semântica.
- `issue13-matrix.R`: matriz normativa e fronteiras de falha.
- `issue13-scenario.R`: cálculo, recálculo, preparação, paper e fault runner.
- `issue13-seed-channel.R`, `issue13-seed-runtime-lib.R`: canal-seed sem cópia
  do run e carregamento fail-closed dos dois runtimes.
- `issue13-baseline-runtime-index-lib.R`: autenticação do perfil único
  `compatibility-oracle-cc2` e do vínculo cenário/commit do baseline final.
- `issue13-build-recalc-bundle.R`, `issue13-run-recalc-bundle.ps1`: geração e
  execução segura de recálculo independente.
- `issue13-build-prep-fault-specs.R`, `issue13-audit-prep-fault-plan.R`:
  geração imutável e preflight do subgate de preparação/falhas.
- `issue13-import-fault-inputs.R`, `issue13-build-fault-seed-specs.R`,
  `issue13-run-fault-seeds.ps1`, `issue13-run-prep-fault-record.ps1`:
  store isolado, canais-seed e execução controlada das falhas.
- `issue13-aggregate-prep-fault.R`: agregado fechado do subgate de
  preparação/falhas.
- `issue13-monitor.ps1`, `issue13-run-plan.ps1`: isolamento/telemetria.
- `issue13-snapshot.R`: inventário externo para artefatos sem manifest nativo.
- `issue13-aggregate.R`: gate final.
- `issue13-selftest.R`, `issue13-seed-runtime-selftest.R`,
  `issue13-monitor-selftest.ps1`: fixtures e regressões do harness.

## Limitações deliberadas

- O monitor de RSS/árvore real é Windows/PowerShell/CIM.
- A canonicalização de CSV diagnóstico lê a tabela na memória; arrays e FSTs
  grandes permanecem chunked. O caso real conhecido de 415.516 linhas cabe
  confortavelmente sem materializar arrays 4D.
- O semeador cria uma nova release/marker no store isolado do gate. Por isso o
  canal deve ser exclusivo e vazio; ele nunca deve apontar para `stable`.
- Specs e evidence dirs são imutáveis: rerun exige novos diretórios/canais.
- Os self-tests não substituem a prova oficial de 7–10 horas; validam apenas a
  mecânica do harness.
