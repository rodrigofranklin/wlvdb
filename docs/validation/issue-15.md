# Issue #15 — consolidação WIOD13/WIOD16

Revisão documental: `wiod-consolidation-v1`. Este relatório distingue resultados
reais, integração sintética e evidência anterior reutilizada. O aceite da
revisão exata, incluindo os dois jobs de CI, fica vinculado ao
[PR #33](https://github.com/rodrigofranklin/wlvdb/pull/33) e ao
[issue #15](https://github.com/rodrigofranklin/wlvdb/issues/15).

O suporte executável é exclusivamente `wiodr13` e `wiodr16`: preparar, calcular,
recalcular variáveis, validar e publicar resultados para o WLVPanel. EXIOBASE,
EORA, métodos alternativos e preparação de artigos permanecem fora do escopo.

## Entregas vinculadas

- [#28 — consistência científica](issue-28.md): correção da base dos índices
  usados pelas cestas WIOD13, regressão com controle negativo e comparação real.
- [#29 — documentação](issue-29.md): [guias PT](../guide-pt.md) e
  [EN](../guide-en.md), dicionários completos, exemplos verificados e
  [sincronização](../documentation-sync.md).
- [#30 — comentários científicos](issue-30.md): cobertura funcional e prova de
  preservação das expressões executáveis nas alterações explicativas.
- [#31 — metadados ausentes](issue-31.md): a publicação conjunta revelou que o escritor CSV
  representava ausências como campos vazios, mas o leitor reconhecia apenas
  `NA`. Aceitar as duas representações permite completar informações entre
  métodos e mantém a rejeição de dois valores presentes diferentes.
- [#32 — Unicode](issue-32.md): uma regressão adicional encontrou perda de acentos no escritor
  CSV sob locale C. A correção recebe controles de ida e volta e preservação
  do formato numérico, sem reescrever provas ou resultados anteriores.

O cálculo completo continua usando os pesos monetários da cesta de 1995 e
`GO_P` em base 1995=1 no WIOD13. Normalizar cada setor para 2000 antes da soma
alterava os pesos efetivos no recálculo. A correção recupera o índice original
da fonte autenticada e normaliza a cesta agregada como no cálculo completo.
O diagnóstico histórico identificou 81.132 células em quatro indicadores; o
relatório do #28 discrimina anos, unidades, coordenadas e efeitos econômicos.

## Verificação integrada

| Gate | Evidência e estado |
| --- | --- |
| Ciência real e recálculos válidos | 18 cenários na campanha `temp/issue28-recalculation/`: dois fulls e 16 recálculos completos/seletivos. Valores, máscaras, estados, unidades, metadados, matrizes, linhagem e células preservadas exatos. A recuperação da primeira publicação WIOD16 está explicitamente discriminada no #28. |
| Comentários sem mudança executável | 30 arquivos/607 expressões contra o commit anterior; dois arquivos/47 expressões contra a correção #28 antes dos comentários. Controle negativo detecta a mudança científica. |
| Suíte automatizada | Gate completo executado pela CI nos dois sistemas. Após a correção do gerador, 140 verificações documentais em cada locale e 63 verificações estáticas locais passaram; as tentativas anteriores reprovadas estão discriminadas abaixo. |
| WLVPanel — integração sintética | 216 expectativas em 38 casos; zero falhas/avisos, um skip específico de caminhos Unix no Windows. |
| WLVPanel — dados reais | Leitor e contratos reais validaram a publicação conjunta após recálculo: todos os valores, coordenadas, unidades e fatores de apresentação exatos, nos dois métodos. A leitura foi reconfirmada após a limpeza das fontes duplicadas. |
| Documentação e exemplos | Dicionários dos contratos v2, pares PT/EN, links, exemplos numéricos, comandos e leitura real aprovados; versão e hashes no #29. |
| CI de clone limpo | Windows 2022 e Ubuntu 24.04, R 4.6.1; jobs e estado da revisão exata nos [checks do PR #33](https://github.com/rodrigofranklin/wlvdb/pull/33/checks). Dois skips por fontes reais ausentes no clone são complementados pelas campanhas reais. |
| Limpeza e preservação | Resultados, snapshots e tentativas preservados em campanhas registradas. Fontes duplicadas e temporários dispensáveis removidos pelo gerenciador; estados finais nas respectivas `.campaign.json`. O arquivo 054 permanece protegido. |

O leitor do painel conserva nomes vazios na lista de eixos, enquanto o leitor
canônico usa uma lista sem nomes. A verificação aceita exclusivamente essa
diferença de representação: dimensões, todos os rótulos de coordenadas e todos
os valores, inclusive `NA`/`NaN`, permanecem exatamente iguais. Não há tolerância
numérica nessa comparação. Metadados modernos determinam as unidades e a
formatação; o campo legado `type = usd` de `gross_output.s.mv` não substitui sua
unidade `abstract_labour_hour` nem sua apresentação como valor em trabalho.

As tentativas locais anteriores permanecem identificadas como reprovadas.
A primeira suíte executou os testes com sucesso, mas o lançador foi editado
durante a execução e terminou com erro de parsing; ela não é o gate aceito.
A segunda falhou em duas comparações dos dicionários por perda de Unicode no
gerador sob locale C. A terceira execução local e a primeira CI encontraram
um único problema: o carregador UTF-8 do gerador usava avaliação dinâmica,
proibida pelo guard estático. A solução final define a função diretamente no
lançador, com literais Unicode escapados; CSVs e dicionários continuam legíveis
em UTF-8 e byte-idênticos. Não se abriu exceção no guard. O relatório
`results/comments/dictionary-static-final.json` registra a regressão final.
Também foram preservadas
as tentativas do verificador do painel que detectaram a representação dos nomes
dos eixos e a necessidade de converter hashes S3 antes de serializar o relatório.
Nenhuma dessas falhas de verificação foi convertida retroativamente em sucesso.

O log integral e os jobs reprovados da primeira CI estão em
`logs/ci-ea48c02.log` e `results/ci-ea48c02.json`, com hashes em
`results/ci-ea48c02-hashes.json`. Nos dois sistemas, bootstrap, catálogo,
dicionários em ambos os locales, startup, CLI fora da raiz e controle dos
temporários passaram. Os únicos skips foram testes dependentes de fontes
preparadas (`exchange-rate` e `gfcf-contracts`); a integração real utiliza
essas fontes e autentica seus contratos, diagnósticos e resultados.

## Publicação conjunta no runtime final

`get_wlv(c("wiodr13", "wiodr16"))` passou em 920,34 s. Em seguida,
`recalc_wlv()` desde o estágio 4, selecionando `basket_price.r.pc`,
`basket_value.r.pc` e `gross_output.s.du`, passou em 313,17 s. Ambas as
chamadas usaram um worker e o canal isolado `validation/issue15-final`.

Os quatro runs são autenticados e mantêm linhagem correta. Todos os painéis,
rótulos, máscaras `NA`/`NaN`, estados semânticos, unidades, proveniência,
parâmetros e diagnósticos são exatamente iguais aos fulls de referência do #28.
Os payloads FST de todas as matrizes são byte-idênticos; os sidecars RDS têm
conteúdo idêntico, com a diferença de serialização discriminada no relatório.
Como o pai completo e o filho seletivo são ambos idênticos à referência inteira,
todas as células fora da seleção permanecem iguais ao pai.

| Modalidade | Método | Run |
| --- | --- | --- |
| Cálculo completo | WIOD13 | `run-20260906T020911761Z-c57b6019cc60b685` |
| Cálculo completo | WIOD16 | `run-20260906T021302129Z-cd9a3800bf13ebdf` |
| Recálculo seletivo | WIOD13 | `run-20260906T022500643Z-7226d164a9413899` |
| Recálculo seletivo | WIOD16 | `run-20260906T022600416Z-f9e16fe0e787386d` |

O WLVPanel validou a release final
`release-20260906T022938592Z-0b449862cd15738c`. Os relatórios abaixo pertencem
a `temp/issue15-integration/results/` e registram os hashes dos manifestos,
arquivos, código do consumidor e verificações individuais.

| Relatório | SHA-256 |
| --- | --- |
| `final-api.json` | `766972fbedb78fe1f1da8d434bdffac03938adc2f58162cf09f6eaf8d8b4ccea` |
| `panel-final.json` | `2297ba63d26c75f58747d68e0693cd6d3a0fe0548bfcca68ba84136687a6fbb8` |
| `panel-tests.json` | `d0f000becf247316c067a6828431863ee7fdd662aa9748da11812c5aaa8c71f3` |
| `final-snapshot.json` | `026d6e381fc79b8c5c576db17f32cce005c3ec6715782d21bca7c0d74a4f8796` |

`cleanup-plan.json` e `cleanup-final.json` registram a remoção de 914.458.356
bytes de fontes duplicadas, sem tocar nos resultados. A campanha auxiliar
foi encerrada, inspecionada por `Clean` e removida por `Clean -Apply`.
`panel-after-cleanup.json` reconfirma a leitura da publicação sem essas cópias;
os quatro manifestos permanecem com os hashes anteriores e a worktree continua
sem alterações de código. O manifest protegido da campanha 054 também conserva
seu hash anterior à limpeza.

## Evidência anterior e limites

As provas aprovadas do [#13](issue-13.md) permanecem em `temp/054/`, com seus
commits, fontes, hashes e tentativas anteriores. Preparação, publicação,
rollback, encerramento de clusters e desempenho não foram reatribuídos ao
código novo. A preparação recebeu comentários com AST idêntica; sua prova real
anterior continua aplicável. A publicação recebe novas verificações específicas
pelos #31/#32. Os caminhos numéricos alterados recebem nova evidência no #28.
Tempos desta campanha não são novos benchmarks controlados.

A worktree final foi congelada no commit
`ea48c02221f95124b28e6bb4de17051b3538d494`, em
`temp/issue15-integration/worktrees/final`. Seu inventário de 64 arquivos de
fontes, copiados e conferidos individualmente, está em
`results/final-snapshot.json`. Ela recebeu cálculos completos próprios e um
recálculo seletivo conjunto pelo lançador `tests/manual/issue15-final-run.R`.

A auditoria independente comparou os 211 arquivos R dessa worktree com a cópia
científica do #28: 209 arquivos têm árvore sintática idêntica. Das 3.191
expressões examinadas, apenas três definições diferem: o leitor CSV de painel,
o merger de metadados e o escritor CSV. Todas as expressões científicas são
idênticas. O relatório `results/comments/final-mathematics-ast.json` tem SHA-256
`b678e8ef4a5a71f30ad7acf0d0080afd2c2858617a4163339e53f3db237ab3fd`;
o CSV detalhado e o auditor estão ao lado dele.

Essa equivalência científica não permite usar os runs do #28 como pais do
runtime final: o fingerprint de compatibilidade inclui o texto do código,
inclusive comentários. A execução integrada cria novos pais com `get_wlv()`
e verifica `recalc_wlv()` nessa mesma geração. Nenhum fingerprint anterior foi
reescrito. A biblioteca dessa execução é ativada explicitamente pelo `renv`,
com `Rscript --vanilla`; a comparação exata com os dois fulls do #28 também
verifica o resultado do leitor FST com seu fallback de R básico.

A correção final do gerador de dicionários altera somente ferramentas de
documentação. O fingerprint do runtime é idêntico na worktree executada e
na árvore consolidada:
`8ef95868fddf3d66873176a2405f0b289fa6de442cd56ab9fcae5c7a18963703`.
Essa verificação consta em `results/comments/dictionary-static-final.json`,
SHA-256 `9e1d802119666f281e70bd40337c086d0613acb203422491ea72a87d4b2ef521`.

A fonte preparada antiga do checkout principal foi recusada por incompatibilidade
do contrato antes de calcular. A campanha nova usa cópias conferidas das fontes
aprovadas na 054, sem modificar a origem. Em um clone limpo, execute a preparação
documentada; não reutilize uma geração normalizada incompatível.

O banco mantém cobertura WIOD13 1995–2009, inclusive resultados finitos e zeros
de compatibilidade em 2008–2009. O painel aplica um filtro próprio nesses dois
anos por limitações da cobertura de capital. Os guias explicam essa distinção,
as imputações, as diferenças de classificação entre edições e as demais
limitações; não apresentam os zeros de compatibilidade como observações de
ausência de capital na economia.

## Reprodução

Os lançadores reutilizáveis são `tests/manual/issue15-verify.R`,
`tests/manual/issue28-recalculation.R`,
`tests/manual/issue28-recalculation-suite.ps1` e
`tests/manual/verify-comment-ast.R`. Seus argumentos estão nos próprios arquivos.
Crie uma campanha pelo gerenciador e configure `TEMP`, `TMP` e `TMPDIR` antes
de iniciar R. Os dados científicos, relatórios e logs pertencem à campanha;
nenhuma saída gerada é acrescentada ao código versionado.

```powershell
pwsh -File scripts/manage-campaigns.ps1 -Action New -Id verificacao-wiod
$env:TEMP = Join-Path $PWD 'temp/verificacao-wiod/scratch'
$env:TMP = $env:TEMP
$env:TMPDIR = $env:TEMP
Rscript --vanilla scripts/bootstrap.R
Rscript --vanilla tests/manual/issue15-verify.R suite temp/verificacao-wiod/results/suite.json
```

Para o gate real do painel, acrescente ao modo `panel` o caminho do checkout
WLVPanel, a raiz `results/` de uma campanha validada e o canal desejado.
O verificador chama o leitor real e os contratos do painel sem abrir sua
interface, escrever caches do aplicativo ou baixar mapas.

A integração usa o checkout WLVPanel no commit
`227f73f9972f59dd36dbc23379281f5c35f58fcc`. Seus testes sintéticos foram
executados por `scratch/panel-tests.R`, preservado na campanha, com o `renv`
do banco e `openxlsx 4.2.8.1` disponível em uma biblioteca adicional. Essa é uma
dependência dos testes do consumidor, registrada com caminho e versão em
`results/panel-tests.json`; não foi acrescentada ao lock do banco. Para repetir
essa prova, disponibilize os dois checkouts e essa dependência, configure os
temporários da campanha e adapte somente os caminhos locais no lançador
preservado. O teste do leitor real usa apenas os argumentos do modo `panel`.
