# Issue #13 — gate real V5 com oráculo de compatibilidade

Este diretório contém o contrato e a materialização do harness V5. Ele não
contém resultados científicos e não torna elegível nenhuma evidência V4/V4R2.

## Identidades do baseline

O merge do issue #12 permanece a origem histórica imutável:
`cc2c86189a06676bcb9f0e05e08033d710a92509`.

O smoke estrito executado nessa origem passou cinco métodos e falhou sete. Sua
evidência negativa é preservada, autenticada e nunca importada no gate final:

- resumo: `D:\Trabalho\Code\wlvdb-issue13-v5-cc2-smoke-003\baseline-smoke-summary.json`;
- SHA-256: `973079b3cba2df2627b3dcc4dcde0899b261eff9ad1930eb31b2407d23e3dd6d`;
- resultado: 5 aprovados e 7 reprovados;
- `final_evidence_eligible=false`.

O harness físico separado referenciado pelo resumo também permanece fechado:
manifesto `a17a187621cdd4aff6f24efd6bf43ffbf9336de0a19189dfc7f5a82758a92c23`,
39 arquivos em um diretório, 586.873 bytes, inventário
`7ba02db2ad97cd59bc93405057d5cc127fbefaac0e4e72331c13a10e5f8d495b`
e lista de caminhos
`d6fe55884678c1300f661bd4b1ff1f42694af9d49dabd739fad7630ebfd2b416`.
Ele autentica a infraestrutura histórica do smoke, mas não é reutilizado como
runtime ou evidência terminal.

O resumo acima é o registro histórico imutável. O archive write-once
`attempts` preservado é reautenticado com 120 arquivos, 60 diretórios,
2.255.912 bytes, inventário
`12b63f23e87b12b6afc0beabec9e64518b0ce114f1ae8b7fa481c01c78320edf`,
inventário de diretórios
`7bdb481081e12c4522f6dfdace2ec2c00015127139b574356f76e019754592ea` e
lista de arquivos
`5b805a5b9c7d2e1d09b111392b8d0795e60b4866e55f606ac8db9dc4e7cf7657`.
Seus 12 worktrees também são preservados sem alterações, integralmente limpos,
em `cc2c86189a06676bcb9f0e05e08033d710a92509`, árvore
`0cb1142cdadd74bf95272010f5393ebe2af79f47`.

Esse selo integral do archive foi calculado posteriormente. Ele autentica o
estado atual dos artefatos preservados, mas não prova retrospectivamente os
bytes físicos de `Rscript.exe` usados em 25/08/2026. A identidade do Rscript
registrada na configuração é um vínculo atual, reaberto e validado antes e
depois do workflow terminal. Essa distinção é obrigatória no relatório, assim
como `final_evidence_eligible=false` para o smoke histórico.

Com autorização explícita, o runtime do oráculo legado é um único filho direto
de `cc2c861`, fora do branch candidato:

- commit: `e2f4d6dae9a6d35c966b305fabac52e489faa3e7`;
- patch canônico: `D:\Trabalho\Code\wlvdb-issue13-v5-baseline-oracle-v2-e2f4d6dae9a6-canonical.patch`;
- SHA-256: `9f9b878f8e557973127e6260a0f224c868a0c4e8dc2db52dd6aa3f7131f28cd9`;
- stable patch-id: `253ca5f1397132f94e3432264084a37395c60ec3`;
- árvore resultante: `7da19c4f2913e857040ba228280f404b0e54eaab`.

Todos os 76 cenários baseline usam esse mesmo commit e o perfil único
`compatibility-oracle-cc2`. O índice autentica o patch completo; o agregado
recalcula o patch-id do diff `cc2c861 -> runtime-oráculo` e exige que o runtime
seja limpo e tenha `cc2c861` como pai direto.

## Cobertura

- 12 métodos e dois braços;
- 74 fases científicas e duas suplementares;
- cálculo `workers=1` e cinco recálculos independentes por método;
- `workers=2` para WIOD13 e WIOD16, com equivalência a `workers=1` e prova de
  encerramento do cluster;
- preparação WIOD13/WIOD16/EU KLEMS e paper 0;
- dez falhas injetadas;
- 162 cenários monitorados e 202 comparações autenticadas;
- tempo candidato `<= 120%` do baseline e RSS candidato
  `<= baseline + max(10%, 512 MiB)`.

## Inventário fonte fechado do controller

O vínculo `source_controller` contém exatamente 34 registros, um para cada
arquivo abaixo, com `name`, `relative_path`, tamanho, SHA-256 e blob Git
recalculado sobre os bytes crus de `git cat-file blob` no commit candidato:

```text
README.md
issue13-v5-aggregate-hardening.R
issue13-v5-attest-delivery.ps1
issue13-v5-baseline-smoke.ps1
issue13-v5-build-baseline-index.R
issue13-v5-build-diagnostic-bridges.R
issue13-v5-build-metadata-equivalence.R
issue13-v5-build-preparation-equivalence.R
issue13-v5-build-stage5-profiles.R
issue13-v5-capture-clean-bridge-evidence.ps1
issue13-v5-capture-clean-stage5-evidence.ps1
issue13-v5-compare-override.R
issue13-v5-compatibility-baseline-override.R
issue13-v5-coordinator-lib.ps1
issue13-v5-coordinator.ps1
issue13-v5-diagnostic-module-bridges.csv
issue13-v5-diagnostics-override.R
issue13-v5-difference-fingerprint.R
issue13-v5-materialize-harness.ps1
issue13-v5-metadata-equivalence.json
issue13-v5-new-config.ps1
issue13-v5-oracle-effect-README.md
issue13-v5-oracle-effect-generate.ps1
issue13-v5-oracle-effect-lib.ps1
issue13-v5-oracle-effect-proof.schema.json
issue13-v5-oracle-effect-spec.json
issue13-v5-oracle-effect-validate.ps1
issue13-v5-preparation-equivalence.R
issue13-v5-preparation-equivalence.json
issue13-v5-render-report.ps1
issue13-v5-run-stage5-evidence.R
issue13-v5-stage5-multiplicity-profiles.csv
issue13-v5-static-verify.ps1
issue13-v5-verify-diagnostic-evidence.R
```

`issue13-v5-diagnostic-bridge-evidence.csv` é um seed absoluto de captura: ele
contém caminhos autenticados para evidência histórica e, por isso, fica
deliberadamente fora desses 34 arquivos, do runtime materializado e de qualquer
autoridade `source_controller`. Sua existência local não altera o inventário
fechado.

## Tooling-fonte Git-bound

O source do harness que pode ser materializado não vem de uma raiz operacional
externa. Ele fica rastreado em
`run_logs/issue13-evidence-source-v5` e contém exatamente 37 arquivos, um único
diretório descendente (`issue13-evidence-harness`) e duas árvores Git (a raiz e
o diretório descendente). O path-list fechado tem SHA-256
`7bf2e27807e9bc36d3d3766789439d0d9afdd7b2cc5127145ce0e0f6819db00d`.

O objeto `source_tooling` registra `candidate_commit`, raiz relativa no
repositório, raízes lógica e física, contagens, bytes, path-list, inventário,
as duas árvores e os 37 arquivos. Cada árvore contém caminho, modo `040000`,
tipo `tree` e objeto Git; cada arquivo contém caminho, tamanho, SHA-256, modo
`100644`, tipo `blob` e objeto Git. Os bytes locais são comparados com
`git cat-file blob` e `git hash-object --no-filters`. Manifesto materializado,
configuração e prova Oracle precisam conter exatamente o mesmo objeto. A antiga
raiz operacional `runtime-v4` não é fonte, fallback nem dependência terminal.

## Pré-condições

1. O diretório V5 deve estar incluído no commit candidato; materializador,
   configurador, verificador e coordenador exigem que todos os arquivos fonte
   do inventário fechado acima sejam byte a byte idênticos aos blobs desse
   commit.
2. O candidato deve ser descendente de `cc2c861`, estar disponível localmente e
   a árvore rastreada deve permanecer limpa até a escrita do relatório.
3. O runtime-oráculo deve ser filho direto de `cc2c861`, permanecer fora do
   histórico do candidato e ter seu patch canônico no caminho autenticado.
4. O source origin baseline deve conter os mesmos 84 arquivos oficiais, com
   SHA-256 de inventário
   `c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26`.
5. O source origin candidato deve ser uma preparação nativa dos mesmos seis
   caches, com 76 arquivos, 2.035.522.216 bytes e inventário
   `22e90e9485d7cee19d1de786c3464106d9a857ad3d85d0c9f2b3d912a0f38026`.
6. Os manifests candidatos WIOD13/WIOD16 devem estar ligados aos contratos
   `1f246283...`/`3b23ab67...`; o preflight verifica manifests, generation IDs,
   hashes compostos e blobs Git antes de criar worktrees.
7. O smoke compatível terminal deve passar os 12 métodos. Separadamente, a
   prova do efeito do oráculo usa o smoke autenticado para o qual suas
   comparações strict foram produzidas; os dois resumos não são
   intercambiáveis.
8. Nenhum processo R inesperado pode estar ativo.
9. `docs/validation/issue-13.md` não pode existir antes de `Report`.
10. Worktrees, evidência e controle usam raízes novas e distintas. Nenhuma raiz
   V4/V4R2 ou V5 anterior é reutilizada.

O host Codex pode expor `LANG`, `LC_ALL` e `LC_CTYPE` como `C.UTF-8`, nome que
o R 4.6.1 para Windows não reconhece. O smoke remove essas três variáveis
durante sua execução e as restaura no `finally`; o coordenador também as remove
explicitamente de todo `ProcessStartInfo`. O contrato de entrada distingue três
estados sem conversão prematura: chave ausente significa herdar, valor `null`
significa remover, e qualquer string — inclusive `""` — significa definir
exatamente esse valor. O estado real anterior também preserva presença e valor,
portanto ausência e string vazia não são intercambiáveis na restauração.

Cada registro de comando usa somente `environment_set` (itens exatos
`name`/`value`) e `environment_cleared` (nomes removidos). Nomes são únicos sem
diferenciar maiúsculas/minúsculas e os dois conjuntos são disjuntos. Uma string
vazia permanece visível como `value: ""`; não pode ser reinterpretada como
remoção. Os dois campos legados de ambiente são proibidos. Isso evita tanto
queda silenciosa para locale C/codepage 0 quanto corrupção de metadados UTF-8.

## Runtime terminal e origem candidata

O harness aceito para evidência tem geração única `v5-terminal`, é materializado
diretamente dos blobs do commit candidato e não reutiliza evidência. As origens
normalizadas continuam separadas por braço, sem afrouxar
`wlv_verify_source_manifest()` nem restaurar paths legados. Na comparação entre
arquiteturas, cada perfil fechado valida dimensões, dimnames, payload bit a bit,
hash interno e a transição autenticada `legacy-positional` → `versioned-v1` dos
sidecars FST.

Origem candidata histórica autenticada (o nome do diretório é somente a
identidade preservada dessa preparação):

- raiz: `D:\Trabalho\Code\wlvdb-issue13-candidate-source-v5c5-prep-001\source_data`;
- commit preparador: `d7791584c58a9e52ba558da99d763207fe561b4e`;
- WIOD13 manifest `b454f0f0...`, generation `b16a64ed...`;
- WIOD16 manifest `28dc13d3...`, generation `1f747ab8...`;
- caches oficiais: os mesmos seis arquivos autenticados do baseline.

## Capturas limpas dos bridges e do estágio 5

Os manifests diagnósticos são derivados de capturas write-once, em raízes
novas. A captura de bridges completa os sete métodos que não estão no seed
absoluto; a captura do estágio 5 só começa depois de autenticar o índice, o
registro e o manifest de bridges. Os comandos históricos autenticados que
produziram as autoridades preservadas foram:

```powershell
$rscript = 'C:\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe'
$rLibrary = 'D:\Trabalho\Code\wlvdb\renv\library\windows\R-4.6\x86_64-w64-mingw32'
$controller = 'D:\Trabalho\Code\wlvdb\run_logs\issue13-native-gate-orchestrator-v5'
$harness = 'D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5-terminal-rerun-007\issue13-evidence-harness'
$pwsh = 'C:\Users\rodri\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'

& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-capture-clean-bridge-evidence.ps1') `
  -RepositoryRoot D:\Trabalho\Code\wlvdb `
  -CaptureRoot D:\Trabalho\Code\wlvdb-issue13-v5d-bridge-capture-008 `
  -BaselineSourceDataRoot D:\Trabalho\Code\wlvdb-issue13-baseline\source_data `
  -SeedEvidenceIndex (Join-Path $controller 'issue13-v5-diagnostic-bridge-evidence.csv') `
  -HarnessDir $harness `
  -RscriptCommand $rscript `
  -RLibrary $rLibrary

& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-capture-clean-stage5-evidence.ps1') `
  -RepositoryRoot D:\Trabalho\Code\wlvdb `
  -Stage5CaptureRoot D:\Trabalho\Code\wlvdb-issue13-v5d-stage5-capture-002 `
  -BaselineSourceDataRoot D:\Trabalho\Code\wlvdb-issue13-baseline\source_data `
  -BridgeCaptureRoot D:\Trabalho\Code\wlvdb-issue13-v5d-bridge-capture-008 `
  -BridgeManifest (Join-Path $controller 'issue13-v5-diagnostic-module-bridges.csv') `
  -HarnessDir $harness `
  -RscriptCommand $rscript `
  -RLibrary $rLibrary
```

Esses comandos documentam a receita histórica das capturas concluídas.
Uma raiz que recebeu qualquer saída nunca é apagada nem reutilizada. Em cada
invocação R, os capturadores usam `--vanilla`, removem o conjunto exato de 35
variáveis de locale/startup/`renv`, fixam `R_LIBS_USER=$rLibrary`,
`RENV_PATHS_LIBRARY=<raiz-renv>`, `TZ=UTC` e sete opções `RENV_CONFIG_*` como
`FALSE`, e restauram exatamente o ambiente anterior em `finally`. O caminho
físico e o inventário recursivo da biblioteca R são
registrados antes e depois; o mesmo ocorre com o runtime inteiro que contém o
harness e com as árvores normalizadas WIOD13/WIOD16. O manifesto exaustivo de
metadados é uma ferramenta nominalmente pinada no registro. Qualquer diferença
interrompe a captura. A captura do estágio 5 exige ainda igualdade com a
biblioteca, o runtime e as fontes registrados na captura de bridges.

## Equivalência exaustiva da preparação

WIOD13 e WIOD16 são comparados pelo perfil
`wlv-issue13-preparation-equivalence/1`. Para cada fonte, o gate autentica e
compara integralmente `_unit_contract.csv` e `_source_manifest.csv`: todos os
campos, todas as linhas e a ordem devem ser exatos. Não há categoria genérica,
wildcard, tolerância, reordenação nem projeção de arquitetura. A configuração
fecha `architecture_projection = []` e exige
`source_unit_contract_bridge = exhaustive-source-unit-contract-bridge`.

Esse bridge é uma tradução exaustiva entre contratos de engine, não uma
dispensa de paridade. A configuração, o coordenador, o agregado e o renderer
releem o mesmo documento e seu SHA-256. A identidade separada dos 42 artefatos
EU KLEMS continua obrigatória.

## Fluxo terminal write-once

Depois de commitado o tooling, materialize uma cópia nova:

```powershell
$repository = 'D:\Trabalho\Code\wlvdb'
$controller = Join-Path $repository `
  'run_logs\issue13-native-gate-orchestrator-v5'
$pwsh = 'C:\Users\rodri\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe'
$rscript = 'C:\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe'
$candidate = (git rev-parse HEAD).Trim()
& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-materialize-harness.ps1') `
  -CandidateCommit $candidate `
  -Destination D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5-terminal-rerun-014 `
  -ConfirmMaterialize
```

A materialização é recusada se qualquer blob do controller diferir do
candidato. O materializador é Windows-only, resolve repositório, fonte,
staging e destino por identidade física baseada em handle e volume GUID, exige
que sejam disjuntos e rejeita reparse points em ancestrais ou árvores. Aliases
UNC, unidades mapeadas e unidades `SUBST` não podem substituir uma identidade
física aceita; o smoke terminal os rejeita explicitamente e repete a validação
depois de criar sua raiz. A cópia usa blobs Git crus autenticados, staging
exclusivo e promoção atômica.

Cada comando PowerShell deste fluxo deve começar em um processo selado novo,
como nos exemplos com `& $pwsh -NoProfile -File`. Não invoque dois entrypoints
no mesmo host: os tipos nativos compilados ficam no AppDomain, e uma segunda
entrada é recusada de forma fail-closed como estado herdado.

O selo terminal foi derivado de uma staging write-once materializada dos blobs
autenticados do candidato: `47` arquivos, `2615877` bytes e inventário SHA-256
`d45b066fd47cec3cddc0a54098633274ab5b3f7cf448d68297f51b7c6d0cf1ee`.
O spec do Oracle registra `status = sealed`; gerador e validador exigem essa
tripla exata antes da prova Oracle e do gate longo. O output continua exigindo
um único diretório plano `issue13-evidence-harness`, sem subdiretório oculto; o
manifesto nunca é autoridade isolada, pois cada validador recompõe o inventário
físico contra o selo incorporado.

Em um processo novo do `pwsh` selado, aplique ao filho R o mesmo contrato
`set10`/`clear35` descrito acima e gere o índice do oráculo compatível:

```powershell
& $rscript --vanilla `
  ./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-build-baseline-index.R `
  D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5-terminal-rerun-014\issue13-evidence-harness `
  D:\Trabalho\Code\wlvdb-issue13-native-final-index-v5-terminal-rerun-010\baseline-runtime-index.json `
  e2f4d6dae9a6d35c966b305fabac52e489faa3e7 `
  D:\Trabalho\Code\wlvdb-issue13-v5-baseline-oracle-v2-e2f4d6dae9a6-canonical.patch
```

Execute o preflight descartável do oráculo antes do gate longo:

```powershell
& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-baseline-smoke.ps1') `
  -HarnessRuntimeRoot D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5-terminal-rerun-014 `
  -SmokeRoot D:\Trabalho\Code\wlvdb-issue13-v5-terminal-smoke-014 `
  -BaselineRuntimeCommit e2f4d6dae9a6d35c966b305fabac52e489faa3e7 `
  -Purpose compatibility-oracle-executability-preflight `
  -ConfirmCreateWorktrees `
  -ConfirmExecuteR
```

O resumo precisa declarar 12 aprovados, zero reprovados e
`final_evidence_eligible=false`.
Preserve integralmente os dois roots de smoke e seus worktrees até a conclusão
do relatório: eles não são reutilizados como evidência científica, mas cada
`ValidateConfig`, retomada e renderização reautentica seus 12 registros,
commits, árvores, resultados, métricas e quatro arquivos de telemetria.
O archive histórico `attempts` e os 12 worktrees de `cc2` também são
write-once: o selo post-hoc documentado acima e a limpeza Git são verificados,
mas jamais promovem o smoke 5/7 a evidência final ou fazem uma afirmação
retrospectiva sobre o executável usado na data histórica.

Em seguida, gere a prova Oracle-effect `/2` com duas raízes novas e distintas.
O spec usa `wlv-issue13-v5-oracle-effect-spec/2` e o proof usa
`wlv-issue13-v5-oracle-effect-proof/2`. O gerador cria cinco comparações strict
em `primary`, repete as cinco em `replay` e autentica os dez comandos e os
inventários físicos dos 17 runs aprovados:

```powershell
$rscript = 'C:\Users\rodri\AppData\Local\Programs\R\R-4.6.1\bin\x64\Rscript.exe'
$rLibrary = 'D:\Trabalho\Code\wlvdb\renv\library\windows\R-4.6\x86_64-w64-mingw32'
$oraclePrimary = 'D:\Trabalho\Code\wlvdb-issue13-oracle-effect-primary-terminal-rerun-014'
$oracleReplay = 'D:\Trabalho\Code\wlvdb-issue13-oracle-effect-replay-terminal-rerun-014'
$oracleProof = 'D:\Trabalho\Code\wlvdb-issue13-oracle-effect-proof-terminal-rerun-014.json'

& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-oracle-effect-generate.ps1') `
  -RepositoryRoot D:\Trabalho\Code\wlvdb `
  -ExpectedCandidateCommit $candidate `
  -StrictSmokeSummary D:\Trabalho\Code\wlvdb-issue13-v5-cc2-smoke-003\baseline-smoke-summary.json `
  -OracleSmokeSummary D:\Trabalho\Code\wlvdb-issue13-v5-compat-smoke-003\baseline-smoke-summary.json `
  -OraclePatch D:\Trabalho\Code\wlvdb-issue13-v5-baseline-oracle-v2-e2f4d6dae9a6-canonical.patch `
  -ComparisonHarnessManifest D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5-terminal-rerun-014\v5-harness-manifest.json `
  -Rscript $rscript `
  -RLibrary $rLibrary `
  -ComparisonRoot $oraclePrimary `
  -ReplayRoot $oracleReplay `
  -OutputPath $oracleProof
```

A prova divide os métodos em `5` comuns — com artefatos científicos
integralmente iguais entre `cc2` e `e2f` nas duas execuções — e `7` recuperados,
com falhas, coordenadas e diagnósticos fechados pelo patch autorizado. Seu
`terminal_runtime` fecha simultaneamente:

- `comparison_harness.source_controller`, com o commit e os 34 registros
  nome↔caminho↔blob Git;
- `comparison_harness.source_tooling`, com o mesmo objeto 37/1/2 do manifesto
  e da configuração, incluindo raízes, path-list, inventário, trees e blobs;
- o executável R, com exatamente `logical_path`, `physical_path`, `item_id`,
  `link_count`, `size_bytes` e `sha256`; os snapshots `before`, `after` e o
  registro corrente precisam ser idênticos, com um único hard link;
- a biblioteca R física, com versão/plataforma, `.libPaths()`, inventário
  recursivo e os namespaces carregados; `fst`, `jsonlite` e `openssl` devem
  resolver dentro de `RLibrary`;
- o ambiente de cada comando, com o set exato de dez entradas
  (`R_LIBS_USER`, `RENV_PATHS_LIBRARY`, `TZ` e sete opções
  `RENV_CONFIG_*=FALSE`) em `environment_set` e o conjunto exato de 35
  variáveis em `environment_cleared`;
- `runtime_immutability`, com snapshots completos `before` e `after`
  idênticos e `immutable=true`.

O validador relê os dois smokes, patch, source-controller, runtime terminal,
Rscript/RLibrary, ambiente, as duas raízes e os 17 runs; o JSON não é aceito
como autoridade isolada. A prova permanece
`final_evidence_eligible=false`, mas sua validação é obrigatória para o gate
final.

Com o candidato já commitado e limpo, gere a configuração selada:

```powershell
$candidate = (git rev-parse HEAD).Trim()
& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-new-config.ps1') `
  -CandidateCommit $candidate `
  -HarnessRuntimeRoot D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5-terminal-rerun-014 `
  -BaselineRuntimeIndex D:\Trabalho\Code\wlvdb-issue13-native-final-index-v5-terminal-rerun-010\baseline-runtime-index.json `
  -BaselineRuntimeCommit e2f4d6dae9a6d35c966b305fabac52e489faa3e7 `
  -BaselineOverlayPatch D:\Trabalho\Code\wlvdb-issue13-v5-baseline-oracle-v2-e2f4d6dae9a6-canonical.patch `
  -StrictBaselineSmokeSummary D:\Trabalho\Code\wlvdb-issue13-v5-cc2-smoke-003\baseline-smoke-summary.json `
  -CompatibilityBaselineSmokeSummary D:\Trabalho\Code\wlvdb-issue13-v5-terminal-smoke-014\baseline-smoke-summary.json `
  -OracleEffectSmokeSummary D:\Trabalho\Code\wlvdb-issue13-v5-compat-smoke-003\baseline-smoke-summary.json `
  -ProofPath $oracleProof `
  -ComparisonRoot $oraclePrimary `
  -ReplayRoot $oracleReplay `
  -Rscript $rscript `
  -RLibrary $rLibrary `
  -CandidateSourceOrigin D:\Trabalho\Code\wlvdb-issue13-candidate-source-v5c5-prep-001\source_data `
  -WorktreeRoot D:\Trabalho\Code\wlvdb-issue13-native-worktrees-v5-terminal-rerun-014 `
  -EvidenceRoot D:\Trabalho\Code\wlvdb-issue13-native-final-evidence-v5-terminal-rerun-014 `
  -ControlRoot D:\Trabalho\Code\wlvdb-issue13-native-final-control-v5-terminal-rerun-014 `
  -Output D:\Trabalho\Code\wlvdb-issue13-native-final-config-v5-terminal-rerun-014\gate-config.json
```

## Validação, execução e monitoramento

```powershell
$config = 'D:\Trabalho\Code\wlvdb-issue13-native-final-config-v5-terminal-rerun-014\gate-config.json'

& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-static-verify.ps1') `
  -CandidateCommit $candidate `
  -HarnessRuntimeRoot D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5-terminal-rerun-014

& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-coordinator.ps1') `
  -Action ValidateConfig -ConfigPath $config

& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-coordinator.ps1') `
  -Action Initialize -ConfigPath $config

& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-coordinator.ps1') `
  -Action PrepareWorktrees -ConfigPath $config -ConfirmCreateWorktrees
```

Para avançar uma unidade por vez:

```powershell
& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-coordinator.ps1') `
  -Action RunNext -ConfigPath $config -ConfirmExecuteR

& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-coordinator.ps1') `
  -Action Status -ConfigPath $config
```

Para executar todo o restante, sem escrever o relatório prematuramente:

```powershell
& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-coordinator.ps1') `
  -Action RunAll -ConfigPath $config -ConfirmExecuteR
```

`Status` não toma o lock de execução e pode ser chamado durante `RunAll`. O
estado retomável fica em
`D:\Trabalho\Code\wlvdb-issue13-native-final-control-v5-terminal-rerun-014\gate-state.json`.
O `Initialize` também cria, de forma write-once,
`oracle-effect-validation.json`: ele registra a invocação exata do validador,
os hashes da prova/patch/harness, os inventários separados de `primary` e
`replay`, os dez comandos e os 17 inventários de runs aprovados. Toda retomada
autentica esse registro; o fechamento reexecuta o validador e exige resultado
idêntico. O resumo agregado dos dois inventários é mantido apenas como vínculo
determinístico do estado; ele não substitui nenhum dos dois inventários fonte.

## Retomada

`RunNext` executa uma única unidade irreversível: braço baseline, braço
candidato, comparação do par, import/seed/fault ou subagregado. Depois de uma
interrupção segura, invoque novamente o mesmo `RunAll`; ele retoma pelo estado e
reautentica qualquer saída terminal já completa.

Não edite `gate-state.json`, não apague evidência e não reutilize raízes. Uma
saída parcial que já ocupou um destino write-once é terminal. Nesse caso,
preserve-a para diagnóstico e gere nova configuração com outro sufixo, por
exemplo `v5-terminal-rerun-001`.

`Initialize` só pode ser executado uma vez. `PrepareWorktrees` retoma apenas os
registros já salvos como completos; um worktree criado sem registro de estado é
terminal para aquela geração.

## Agregado e relatório

Depois de `Status` indicar 76 pares concluídos e dez falhas executadas:

```powershell
& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-coordinator.ps1') `
  -Action Aggregate -ConfigPath $config -ConfirmExecuteR

& $pwsh -NoLogo -NoProfile -NonInteractive -File `
  (Join-Path $controller 'issue13-v5-coordinator.ps1') `
  -Action Report -ConfigPath $config -ConfirmWriteReport
```

Não invoque `issue13-v5-render-report.ps1` diretamente. `Report` verifica e
registra atomicamente o vínculo no estado. O renderer recusa relatório parcial:
exige agregado aprovado, 76 pares e 202 comparações concluídos, dez fault gates, todos os
limites de tempo/RSS, preparação e paper 0 aprovados, inventários imutáveis,
HEAD candidato fixado, árvore rastreada limpa, caminho exato e roundtrip UTF-8.
Ele também registra as identidades `source_generation_id`, `contract_id`,
`contract_version` e `contract_sha256` dos manifestos WIOD13/WIOD16, além da
identidade autenticada dos 42 artefatos preparados EU KLEMS.
Ele ainda exige exatamente 60 deltas completos de recálculo com digests iguais,
recomposição de RSS a partir de amostras autenticadas nas 76 linhas, e registra
no Markdown os resultados `5+7`, os hashes da prova/patch/comparações e cada
um dos dez comandos oracle com executável, argumentos, ambiente e diretório de
trabalho, além dos 17 inventários imutáveis. Os comandos do coordenador usam o
shape fechado `environment_set`/`environment_cleared`; o renderer rejeita
campos legados, nomes duplicados ou sobrepostos e preserva string vazia de modo
visível. Ele também exige igualdade do objeto `source_tooling` entre manifesto,
configuração e prova, a identidade Rscript de seis campos nos snapshots
before/after/current e os selos do resumo, archive e 12 worktrees históricos.

Antes de cada comparação de par, o coordenador reconfere no estado os hashes de
`scenario-result.json` e `process-metrics.json` dos dois braços; o hash das
métricas ancora o `process-samples.csv`. Antes do agregado, essa verificação é
repetida para os 76 pares, seus `comparison.json`/`pair-result`, e para todo o
fluxo de preparação/falhas. Alterar coerentemente amostras e métricas sem
alterar o estado continua sendo rejeitado.
