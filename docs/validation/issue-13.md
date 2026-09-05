# Issue 13 — validação do corte principal

Estado em 2026-09-04: **relatório parcial; gate de merge pendente**. Este registro não constitui aprovação de paridade científica, desempenho ou publicação. Os registros anteriores em `run_logs/` e nas campanhas externas permanecem preservados; seus resultados não são convertidos automaticamente em evidência da campanha atual.

## Escopo e referências

- Métodos executáveis: `wiodr13` e `wiodr16`. Dez métodos experimentais permanecem declarados, com cálculo e recálculo desabilitados; seus contratos e testes unitários isolados foram preservados.
- Referência científica original: merge do #12, `cc2c861`. Baseline executável de compatibilidade: `e2f4d6dae9a6d35c966b305fabac52e489faa3e7`, discriminado do commit original.
- Candidato congelado para a campanha 054: `972d9f8fc7a887b3db485080264f2958cce13cdd`.
- Configuração local efetiva: `D:/Trabalho/Code/wlvdb-issue13-main-054/campaign-v2.json`; configuração anterior preservada em `campaign.json`.
- Tooling científico: cópia privada do runtime externo da campanha 053, vinculada por arquivo e hash. Comparação: derivada separada em `comparison-tooling-v1/`, sem alterar o tooling ou o estado científico; não representa adoção de resultados científicos anteriores.
- Matriz: 14 pares científicos (cálculo, recálculos 1/4/5, seleções 4/5 e `workers=2`), duas preparações e dez falhas. São 40 cenários nessa matriz, além dos seeds auxiliares, e 41 comparações previstas.
- Papers não integram este corte.

As preparações usam os mesmos seis caches oficiais: WIOD13 (`WIOTS_in_MATLAB.zip`, `Socio_Economic_Accounts_July14.xlsx`), WIOD16 (`WIOTS_in_R.zip`, `Socio_Economic_Accounts.xlsx`) e EU KLEMS (`Statistical_Capital.rds`, `Statistical_National-Accounts.rds`). A verificação normativa de tamanhos e SHA-256 será executada antes da preparação; a igualdade real ainda não foi atestada por esta campanha.

## Evidência registrada

| Verificação | Resultado conhecido |
| --- | --- |
| Catálogo, configuração, perfis de saída e agregação | Suítes focadas passaram durante o fechamento do corte. |
| Execução nativa, planejador e consistência dos slices terminais | Suítes focadas passaram com fixtures; experimentais habilitados apenas em catálogos de teste em memória. |
| Catálogo publicado em `docs/methods.md` | Regeneração e `--check` passaram. |
| Suíte completa de fixtures | 66 arquivos passaram em quatro shards antes do commit `972d9f8`; registros `unit-tests/shard1.json` a `shard4.json`, com 242,865 / 387,4972 / 97,33 / 249,79 segundos. |
| CI | Execuções `33934593144` (`972d9f8`) e `33936297967` (`ed3fdc0`) concluídas com sucesso. A execução de `a73d344` ainda estava em andamento na última consulta. |
| Controlador suplementar | Parser passou; smoke de processo verificou captura de logs, erro de processo e escrita atômica de estado. |
| Ambiente dos filhos | Teste confirmou 35 variáveis removidas e dez definidas; biblioteca R preservada. |
| Isolamento e retomada do suplemento | Casos de igualdade/ancestralidade de paths e identidade PID + horário de início passaram. |
| Inicialização suplementar | Plano de 12 registros construído e auditor independente passou. Vínculo do controlador atualizado após sua estabilização, preservando a inicialização provisória. Nenhum cenário de preparação/falha foi executado. |
| Execução científica real | Revisão v2, tentativa 2: quatro cálculos `workers=1` iniciados simultaneamente às 22h23min32 BRT de 2026-09-04. WIOD13 baseline/candidato e WIOD16 candidato terminaram com `passed=true`; WIOD16 baseline ainda executava na última consulta. Conclusão de execução não implica paridade. |
| Comparação antecipada WIOD13 | A primeira tentativa parou no perfil histórico de metadados, antes de produzir `comparison.json`. A derivação atual e seu vínculo separado passaram; segunda tentativa em execução desde `2026-09-05T02:28:07Z`, preservando os cálculos concluídos. |
| Paridade real, desempenho, preparação e dez falhas | Gate pendente; execução científica iniciada, demais provas ainda não concluídas. |

A inicialização suplementar provisória terminou em `2026-09-05T01:01:48Z` (2026-09-04 no horário local). Seu plano tem SHA-256 `7fa43b85892dc2b34ccd9113c21d0edfa31a7d0241bb127037101210093732c3`; o auditor, `f08bdc7cafb39136fb1de0de6a77fddffe54052fed0f9376f970f80f7a55a950`.

Após estabilização do controlador compartilhado, a vinculação foi atualizada em `2026-09-05T01:05:37Z`, reaproveitando o mesmo plano/auditor, sem repetir o builder nem executar cenários. Os arquivos anteriores de estado e vínculo foram preservados, com hashes conferidos, em `D:/Trabalho/Code/wlvdb-issue13-main-054/control/supplemental/initializations/before-controller-finalization/`. O novo `tooling-binding.json` tem SHA-256 `9547fc55f2f322b1db655053fac3969b71ed2accc4e82f06ffbd6ee942c7cc16`. O estado confirmado é `initialized`, com zero cenários e zero comparações concluídos no suplemento.

## Ações operacionais

As duas primeiras tentativas de setup da 054 não produziram evidência científica: a primeira falhou na captura de `LASTEXITCODE` após inspeção Git; a segunda detectou que o PowerShell vinculado havia sido atualizado pelo aplicativo antes de iniciar R. Os diagnósticos foram preservados. A revisão operacional `054v2` mantém os mesmos roots de dados e separa controle/evidência em `control-v2` e `evidence-v2`; foi vinculada a uma cópia privada do PowerShell para não depender de futuras atualizações do aplicativo. Esses eventos não são resultados de paridade nem novos RunAll científicos.

Na revisão v2, a tentativa 1 parou no bootstrap em cerca de quatro segundos, antes do cálculo: o layout do checkpoint não correspondia ao contrato histórico do harness. A correção ficou restrita ao frontend das novas tentativas: `specs` e `evidence` passaram a ser diretórios irmãos sob a mesma base, mantendo `job` e `outcome` no controle. A relação exigida entre o diretório de especificações e o terceiro ancestral da evidência do cenário foi conferida. Não houve alteração científica, recriação da campanha ou substituição dos roots; a tentativa anterior e seus diagnósticos foram preservados.

A tentativa 2 começou às `2026-09-05T01:23:32Z` (22h23min32 BRT de 2026-09-04), com controlador PID `58912`. O estado das `01:23:34Z` registra os quatro cálculos simultâneos como `running`: WIOD13 e WIOD16, baseline e candidato, todos com `workers=1`. Os logs baseline já alcançaram transformação de dados e Leontief, distinguindo esta execução real dos erros anteriores de bootstrap. O resultado científico ainda precisa terminar e ser comparado.

O canal público permanece intacto: a campanha opera nos seus canais e roots isolados, sem promover os resultados em andamento. A automação existente de acompanhamento foi reativada com o prompt atualizado para o escopo dos dois métodos principais; ela não amplia o escopo do gate nem constitui autorização de merge ou publicação.

A comparação antecipada de WIOD13 (`early/parity/wiodr13/001`), executada de `01:44:49Z` a `01:47:23Z`, preservou comando, entradas e hashes em `early-parity-wiodr13-001/`. O erro `Candidate runtime generation differs from metadata derivation.` veio do perfil V5 derivado em `3ae99a848156a28431ff44cf4d9e619c6de84a83`, que espera geração `4668bf1eadb9ea3ea3f121a889f6b29016c1505f1dbcb3cc27ed3c02ab52c2dd`; o candidato congelado apresenta `600d8cdd2c692fea0b608285b84c3d260b123aac4cf1904ee8b6b997ec988c63`. O diagnóstico integral está em `execution-error.json`. Não houve `comparison.json`, escrita no estado científico ou reinício dos cálculos. O próximo ajuste deve reconstruir e verificar a equivalência dos metadados a partir dos commits congelados, em um vínculo de comparação separado; não basta substituir o hash esperado nem modificar o harness utilizado pelos processos científicos ativos.

Esse ajuste foi implementado por `tests/manual/issue13-main-build-metadata.R`: definições e configurações foram reconstruídas em três worktrees limpos, somente de código, nos commits `cc2c861`, `e2f4d6d` e `972d9f8`. Nenhum payload científico foi aberto ou calculado. Os seis sidecars do baseline original e do oráculo executável são exatamente iguais. As 12 tabelas por braço dos dois métodos também são iguais aos perfis históricos, sem diferenças de esquema, linhas, células ou ordem. As únicas três diferenças de envelope são commit candidato, geração e redução de 12 para dois métodos. Os negativos de método, geração, célula e ordem passaram.

Artefatos locais em `comparison-tooling-v1/`:

| Artefato | SHA-256 |
| --- | --- |
| `metadata-derived.json` | `8476d0389d7cdaf87c8d63e2be569ad00d4978627869810f560bc26fceecaf23` |
| `metadata-derivation-provenance.json` | `dde0c2e6b1c1c4dfaefa42341349c7bc67149f238ae1687fe30616fa6642dbdb` |
| `metadata-diff-vs-v5.json` | `edee1e23c59d43113ede4389677b38278a143435cd85bd7fc9a6bf369b74b161` |
| `comparison-binding.json` | `b464b4c29255feed2a30a41c59f22d9ef5df4dd9304efc01dcfd62e37871e3d9` |

O vínculo separado conserva 45 dos 47 arquivos byte a byte; muda somente o perfil de metadados e, deterministicamente, os guards de commit e métodos do validador. Também autentica os dois braços de execução, a proveniência semanticamente validada, snapshots do controlador e contratos de entrada por lado. Paridade aceita os commits diferentes dos dois motores; comparações internas usam o mesmo braço. Retomada com outro vínculo é rejeitada. Os 25 testes positivos/negativos passaram em `comparison-selftest-001/selftest.json`, sem alteração no tooling científico. A segunda comparação antecipada usa o worker `/2` e registra evidência em `early-parity-wiodr13-002/`; é diagnóstico antecipado, não adoção automática entre as 38 comparações finais.

A inspeção dos demais perfis alcançáveis não exigiu mudanças: oito SHA-256 de `_unit_contract.csv`/`_source_manifest.csv` dos dados normalizados dos dois métodos/braços coincidiram com o perfil de preparação histórico. Os quatro `_anomalies.csv` de cálculo coincidiram com os fingerprints históricos dos bridges e parents de estágio 5; o target baseline WIOD13/estágio 1 também coincidiu. Os outros cinco targets de recálculo ainda precisam ser conferidos quando concluídos. Os perfis históricos de preparação, bridges e multiplicidade permaneceram byte-idênticos; seus artefatos e contratos atuais continuam sujeitos à comparação efetiva.

O suplemento da revisão v2 foi inicializado e auditado às `2026-09-05T01:18:52Z`, sem executar os cenários de preparação/falha: zero cenários e zero comparações concluídos. SHA-256 do plano: `e4ea4f7c1d575657d30699a9f721502ceeed7c34cb86ff5b76018322bf31dc72`; vínculo do tooling suplementar: `4cd8afad9dfc8b716713583ea500b8f126464c526c33561a9c59138041ac1fa2`. O controle anterior permanece preservado.

Às `2026-09-05T01:44:29Z`, somente o controlador suplementar foi reautenticado para registrar intervalos individuais de processos. Estado e vínculo anteriores foram preservados, com igualdade dos hashes confirmada, em `control-v2/supplemental/initializations/before-process-journal-20260905T014428967Z/`. O novo vínculo tem SHA-256 `73988e10a28537ce6f3e6fcec8ce6e1bb0f949c0f027f8746322b681563045fd`. Plano, auditor e inventário de logs permaneceram iguais: nenhum builder, auditor R, preparação ou cenário foi repetido. O journal começa vazio e conserva o limite histórico anterior em `01:18:52Z`, sem estendê-lo até a reautenticação. O estado científico não foi alterado.

Executar a partir do checkout, usando o PowerShell selado definido na configuração. `Status` é somente leitura. As ações científicas e suplementares devem ser coordenadas pelo mesmo orçamento de recursos; não iniciar `Prepare` ou `Faults` como carga adicional não contabilizada enquanto o pool científico estiver cheio.

```powershell
$campaign = 'D:\Trabalho\Code\wlvdb-issue13-main-054\campaign-v2.json'
$runner = 'D:\Trabalho\Code\wlvdb-issue13-main-054\tools\powershell\pwsh.exe'
$comparisonBinding = 'D:\Trabalho\Code\wlvdb-issue13-main-054\comparison-tooling-v1\comparison-binding.json'
& $runner -NoProfile -File tests/manual/issue13-main-gate.ps1 -Action Plan
& $runner -NoProfile -File tests/manual/issue13-main-gate.ps1 -Action Initialize -ConfigPath $campaign
& $runner -NoProfile -File tests/manual/issue13-main-gate.ps1 -Action RunScience -ConfigPath $campaign -Arm all -MaxJobs 4
& $runner -NoProfile -File tests/manual/issue13-main-compare.ps1 -ConfigPath $campaign -ComparisonBindingPath $comparisonBinding -MaxJobs 2
& $runner -NoProfile -File tests/manual/issue13-main-gate.ps1 -Action Status -ConfigPath $campaign
```

O suplemento usa `tests/manual/issue13-main-supplemental.ps1 -ConfigPath $campaign -Action <ação>`:

| Ação | Efeito |
| --- | --- |
| `Initialize` | Constrói e audita o plano; não prepara dados nem calcula resultados. |
| `Prepare` | Confere os seis caches e executa as preparações baseline/candidata. |
| `Compare` | Compara semanticamente as preparações e os três seletores de artefatos. |
| `Faults` | Exige preparação comparada e cálculo candidato WIOD13 aprovado; importa o seed, prepara dez canais, executa dez falhas e valida o agregado transacional. |
| `RunAll` | Executa a sequência suplementar completa. |
| `Status` | Lê `control/supplemental/state.json`. |

### Desempenho controlado, separado da ciência

`tests/manual/issue13-main-performance.ps1 -ConfigPath $campaign -Action Plan` é somente leitura. Ele classifica os 14 pares, identifica quais braços podem ser aproveitados e estima o espaço adicional antes de qualquer repetição. `Status` recalcula a mesma classificação; `Run -MaximumRepeats N` executa no máximo N repetições necessárias, sempre em série, após os 28 cenários científicos passarem. Usar a configuração efetiva da campanha após a vinculação da revisão operacional.

Uma medição científica só recebe `controlled-reused-singleton` quando seu intervalo UTC não se sobrepõe a nenhum outro job, comparador, preparação ou falha da campanha, incluindo tentativas malsucedidas e seeds auxiliares. O suplemento registra cada processo com início e fim reais em UTC, PID, ação e resultado, inclusive falhas; medições anteriores ou posteriores não são invalidadas retroativamente. Intervalos interrompidos sem encerramento comprovado ficam abertos. Somente o histórico anterior ao journal usa exclusão conservadora, com limite final fixado na migração; executar ações novas não estende esse limite sobre medições já concluídas.

O smoke do journal executou dois processos PowerShell leves, um com saída zero e outro com erro sete, confirmando registro de ambos, fim real e preservação dos timestamps como strings UTC. Os testes conservaram medições anteriores/posteriores, recusaram a sobreposição efetiva e confirmaram que a atualização posterior do estado não amplia o intervalo histórico. Esse smoke não executou R e não constitui medição científica.

As repetições usam o mesmo worker e os mesmos commits, fontes e seeds autenticados da ciência, em canais e diretórios de tentativa próprios. Não repetem comparações já aprovadas e não alteram o estado da paridade. O roteiro utiliza os locks dos controladores da campanha, sem exigir exclusividade de todos os processos R do computador. Se os resultados adicionais não couberem com a folga prevista, ele bloqueia a execução para coordenação de novos roots vinculados; não remove evidência para liberar espaço.

Até os 14 pares terem medições controladas, o estado permanece `performance-pending`. Só depois aplica os limites normativos de tempo e RSS. Parser e smoke sintético cobriram UTC, singleton, fronteiras adjacentes, quatro tipos de sobreposição, valores exatos de aceitação/rejeição dos limites e matriz completa/incompleta. `Plan` executado contra a v2 confirmou 14 pares pendentes, sem ciência pronta; a estimativa inicial mínima de 84 GiB de novas saídas será recalculada após as saídas reais e não é autorização para reservar esse espaço agora. Nenhuma repetição real de desempenho foi executada nesta implementação.

## Critérios ainda necessários para encerrar o gate

Consolidar os resultados reais por cenário, IDs e hashes das fontes/artefatos, dimensões e dimnames, máscaras de `NA`/`NaN`, estados semânticos, metadados, matrizes, diagnósticos, células não selecionadas e equivalência `workers=1/2`. Registrar todas as diferenças e aplicar apenas as tolerâncias científicas já normativas.

Executar as medições controladas de tempo e memória. O limite temporal é `max(1,2 × baseline, baseline + 600 segundos)`; o de RSS é `baseline + max(10% do baseline, 512 MiB)`. Tempos coletados sob concorrência científica são observacionais e não fecham esse critério. A revisão operacional 054v2 mantém orçamento de 80 GiB e reservas por job de 8/22/40 GiB (WIOD13, WIOD16 e `workers=2`), com piso ajustado de 24 para 16 GiB livres; o roteiro de desempenho lê os valores vinculados na configuração, sem impor novos limites.

Anexar a comparação das preparações, os dez resultados de falha com rollback e ausência de release parcial, o encerramento dos clusters, os registros da CI Windows/Ubuntu já aprovada e o resultado agregado final. Até essa evidência estar completa, manter o PR sem aprovação de merge e o #13 aberto.
