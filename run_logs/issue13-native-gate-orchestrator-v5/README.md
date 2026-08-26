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

## Pré-condições

1. O diretório V5 deve estar incluído no commit candidato; materializador,
   configurador, verificador e coordenador exigem que seus 11 arquivos fonte
   sejam byte a byte idênticos aos blobs desse commit.
2. O candidato deve ser descendente de `cc2c861`, estar disponível localmente e
   a árvore rastreada deve permanecer limpa até a escrita do relatório.
3. O runtime-oráculo deve ser filho direto de `cc2c861`, permanecer fora do
   histórico do candidato e ter seu patch canônico no caminho autenticado.
4. O source origin deve conter os mesmos 84 arquivos oficiais, com SHA-256 de
   inventário
   `c593624ebfa75fb350b8b6528c1d5b6535d71bfe672c7eb61729c1b02f784e26`.
5. O smoke compatível deve passar os 12 métodos.
6. Nenhum processo R inesperado pode estar ativo.
7. `docs/validation/issue-13.md` não pode existir antes de `Report`.
8. Worktrees, evidência e controle usam raízes novas e distintas. Nenhuma raiz
   V4/V4R2 ou V5 anterior é reutilizada.

O host Codex pode expor `LANG`, `LC_ALL` e `LC_CTYPE` como `C.UTF-8`, nome que
o R 4.6.1 para Windows não reconhece. O smoke remove essas três variáveis
durante sua execução e as restaura no `finally`; o coordenador também as remove
explicitamente de todo `ProcessStartInfo`. Cada resumo compatível e registro de
comando autentica a lista em `environment_removed`, evitando queda silenciosa
para locale C/codepage 0 e corrupção de metadados UTF-8.

## Materialização V5C4

Depois de commitado o tooling, materialize uma cópia nova:

```powershell
$candidate = (git rev-parse HEAD).Trim()
./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-materialize-harness.ps1 `
  -CandidateCommit $candidate `
  -Destination D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5c4 `
  -ConfirmMaterialize
```

A materialização é recusada se qualquer um dos 11 blobs diferir do candidato.
O output deve ter exatamente 39 arquivos, 588671 bytes, inventário SHA-256
`0d5b7cfd4a9085afd9b9d196d4ac487853b41948981e3436e9d87811ef473ced`,
um único diretório plano `issue13-evidence-harness` e nenhum subdiretório
oculto. O manifesto não é aceito como autoridade para esses valores: todos os
validadores repetem a conferência contra o selo incorporado.

Gere o índice do oráculo compatível:

```powershell
Rscript --vanilla `
  ./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-build-baseline-index.R `
  D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5c4\issue13-evidence-harness `
  D:\Trabalho\Code\wlvdb-issue13-native-final-index-v5c4\baseline-runtime-index.json `
  e2f4d6dae9a6d35c966b305fabac52e489faa3e7 `
  D:\Trabalho\Code\wlvdb-issue13-v5-baseline-oracle-v2-e2f4d6dae9a6-canonical.patch
```

Execute o preflight descartável do oráculo antes do gate longo:

```powershell
./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-baseline-smoke.ps1 `
  -HarnessRuntimeRoot D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5c4 `
  -SmokeRoot D:\Trabalho\Code\wlvdb-issue13-v5-compat-smoke-003 `
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

Com o candidato já commitado e limpo, gere a configuração selada:

```powershell
$candidate = (git rev-parse HEAD).Trim()
./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-new-config.ps1 `
  -CandidateCommit $candidate `
  -HarnessRuntimeRoot D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5c4 `
  -BaselineRuntimeIndex D:\Trabalho\Code\wlvdb-issue13-native-final-index-v5c4\baseline-runtime-index.json `
  -BaselineRuntimeCommit e2f4d6dae9a6d35c966b305fabac52e489faa3e7 `
  -BaselineOverlayPatch D:\Trabalho\Code\wlvdb-issue13-v5-baseline-oracle-v2-e2f4d6dae9a6-canonical.patch `
  -StrictBaselineSmokeSummary D:\Trabalho\Code\wlvdb-issue13-v5-cc2-smoke-003\baseline-smoke-summary.json `
  -CompatibilityBaselineSmokeSummary D:\Trabalho\Code\wlvdb-issue13-v5-compat-smoke-003\baseline-smoke-summary.json `
  -WorktreeRoot D:\Trabalho\Code\wlvdb-issue13-native-worktrees-v5c4 `
  -EvidenceRoot D:\Trabalho\Code\wlvdb-issue13-native-final-evidence-v5c4 `
  -ControlRoot D:\Trabalho\Code\wlvdb-issue13-native-final-control-v5c4 `
  -Output D:\Trabalho\Code\wlvdb-issue13-native-final-config-v5c4\gate-config.json
```

## Validação, execução e monitoramento

```powershell
$config = 'D:\Trabalho\Code\wlvdb-issue13-native-final-config-v5c4\gate-config.json'

./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-static-verify.ps1 `
  -CandidateCommit $candidate `
  -HarnessRuntimeRoot D:\Trabalho\Code\wlvdb-issue13-evidence-runtime-v5c4

./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator.ps1 `
  -Action ValidateConfig -ConfigPath $config

./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator.ps1 `
  -Action Initialize -ConfigPath $config

./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator.ps1 `
  -Action PrepareWorktrees -ConfigPath $config -ConfirmCreateWorktrees
```

Para avançar uma unidade por vez:

```powershell
./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator.ps1 `
  -Action RunNext -ConfigPath $config -ConfirmExecuteR

./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator.ps1 `
  -Action Status -ConfigPath $config
```

Para executar todo o restante, sem escrever o relatório prematuramente:

```powershell
./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator.ps1 `
  -Action RunAll -ConfigPath $config -ConfirmExecuteR
```

`Status` não toma o lock de execução e pode ser chamado durante `RunAll`. O
estado retomável fica em
`D:\Trabalho\Code\wlvdb-issue13-native-final-control-v5c4\gate-state.json`.

## Retomada

`RunNext` executa uma única unidade irreversível: braço baseline, braço
candidato, comparação do par, import/seed/fault ou subagregado. Depois de uma
interrupção segura, invoque novamente o mesmo `RunAll`; ele retoma pelo estado e
reautentica qualquer saída terminal já completa.

Não edite `gate-state.json`, não apague evidência e não reutilize raízes. Uma
saída parcial que já ocupou um destino write-once é terminal. Nesse caso,
preserve-a para diagnóstico e gere nova configuração com outro sufixo, por
exemplo `v5c5`.

`Initialize` só pode ser executado uma vez. `PrepareWorktrees` retoma apenas os
registros já salvos como completos; um worktree criado sem registro de estado é
terminal para aquela geração.

## Agregado e relatório

Depois de `Status` indicar 76 pares concluídos e dez falhas executadas:

```powershell
./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator.ps1 `
  -Action Aggregate -ConfigPath $config -ConfirmExecuteR

./run_logs/issue13-native-gate-orchestrator-v5/issue13-v5-coordinator.ps1 `
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
