# Issue #15 — consolidação WIOD13/WIOD16

Revisão documental: `wiod-consolidation-v1`. A verificação integrada está em
andamento. Este relatório distingue resultados reais, integração sintética e
evidência anterior reutilizada; o encerramento depende de todos os gates abaixo.

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
- #31 — metadados ausentes: a publicação conjunta revelou que o escritor CSV
  representava ausências como campos vazios, mas o leitor reconhecia apenas
  `NA`. Aceitar as duas representações permite completar informações entre
  métodos e mantém a rejeição de dois valores presentes diferentes.
- #32 — Unicode: uma regressão adicional encontrou perda de acentos no escritor
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
| Ciência real e recálculos válidos | Campanha `temp/issue28-recalculation/`, APIs públicas, fontes autenticadas, relatórios e runs imutáveis; matriz completa em andamento. |
| Comentários sem mudança executável | 30 arquivos/607 expressões contra o commit anterior; dois arquivos/47 expressões contra a correção #28 antes dos comentários. Controle negativo detecta a mudança científica. |
| Suíte automatizada | Primeira execução concluiu 4.135 expectativas sem falhas ou avisos; um erro posterior do lançador impede aceitá-la como gate final. A execução com o lançador congelado será registrada separadamente. |
| WLVPanel — integração sintética | 216 expectativas em 38 casos; zero falhas/avisos, um skip específico de caminhos Unix no Windows. |
| WLVPanel — dados reais | Leitor e contratos do painel validaram o WIOD13 novo, valores e coordenadas exatos, unidades e fatores de apresentação. Verificação dos dois métodos em andamento. |
| Documentação e exemplos | Dicionários gerados de contratos v2; pares PT/EN, links e exemplos em revisão. |
| CI de clone limpo | Windows 2022 e Ubuntu 24.04, R 4.6.1; execução do branch consolidado pendente. |
| Limpeza e preservação | Campanhas registradas em `temp/`; finalização após os processos e gates. O arquivo 054 permanece protegido. |

O leitor do painel conserva nomes vazios na lista de eixos, enquanto o leitor
canônico usa uma lista sem nomes. A verificação aceita exclusivamente essa
diferença de representação: dimensões, todos os rótulos de coordenadas e todos
os valores, inclusive `NA`/`NaN`, permanecem exatamente iguais. Não há tolerância
numérica nessa comparação. Metadados modernos determinam as unidades e a
formatação; o campo legado `type = usd` de `gross_output.s.mv` não substitui sua
unidade `abstract_labour_hour` nem sua apresentação como valor em trabalho.

## Evidência anterior e limites

As provas aprovadas do [#13](issue-13.md) permanecem em `temp/054/`, com seus
commits, fontes, hashes e tentativas anteriores. Preparação, publicação,
rollback, encerramento de clusters e desempenho não foram reatribuídos ao
código novo. A preparação recebeu comentários com AST idêntica; sua prova real
anterior continua aplicável. A publicação recebe novas verificações específicas
pelos #31/#32. Os caminhos numéricos alterados recebem nova evidência no #28.
Tempos desta campanha não são novos benchmarks controlados.

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
