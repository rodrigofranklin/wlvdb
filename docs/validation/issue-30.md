# Issue #30 — comentários do percurso científico WIOD

Revisão documental: `wiod-consolidation-v1`. O percurso público WIOD13/WIOD16
recebeu comentários em português, com definições locais de grandezas, eixos,
unidades, hipóteses, fórmulas, ausência e dependências. A
[convenção](../code-commenting.md) vincula os [guias PT](../guide-pt.md) e
[EN](../guide-en.md) e exige sua atualização conjunta. A entrega integra o
[#15](https://github.com/rodrigofranklin/wlvdb/issues/15); a mudança científica
das cestas é tratada separadamente no
[#28](https://github.com/rodrigofranklin/wlvdb/issues/28).

## Cobertura revisada

As fábricas comuns documentam a fórmula de suas instâncias. Os wrappers que só
passam códigos, variantes e metadados compartilham essa explicação. A revisão
foi feita sobre as configurações públicas e o registro nativo; funções históricas
de métodos alternativos preservados não foram apresentadas como suporte atual.

| Etapa e arquivos | Explicações junto às operações relevantes |
|---|---|
| `R/main.R`, `scripts/run_wlv.R` | Preparar, calcular e recalcular; retorno versus artefatos; canal e publicação; limite de `--check`. |
| `R/preparation/native_wiodr13.R` | 1995–2009, SEA 15 × 27 × 35 × 41 e WIOT 15 × 1435 × 1640; ausência autenticada substituída por zero; exclusão de TOT; revisão WIOT 2008/2009; VA e GO contábeis; normalização e promoção. |
| `R/preparation/native_wiodr16.R` | 2000–2014, SEA 15 × 18 × 56 × 44 e WIOT 15 × 2464 × 2684; lacunas China/ROW; entregas iguais à produção bruta; tolerância e contratos. |
| `R/preparation/native_euklems.R` | Composição versus estoque; exclusões da referência; repartição pelo VA; imputações por nível; taxas sintéticas ponderadas pelo estoque; pesos setoriais nacionais; média sintética MD. |
| `R/lib/source_normalization.R`, `R/lib/native_data.R` | Escalas de moeda/pessoas/horas/índices; rejeição de normalização duplicada; ordem país-setor; filtros e recursos autenticados. |
| `R/modules/native/contracts.R`, `source_modules.R` | Eixos, unidade, escopo, produtor/predecessor; seleção de variável SEA e preservação do estado semântico. |
| `R/modules/native/assumption_modules.R`, `R/lib/row_capital.R` | China: ocupados versus empregados, jornada projetada e fator 1000; ROW: total externo, pesos por intensidade laboral/VA, jornada setorial e capital por referência; estoque constante e zeros estruturais. |
| `R/modules/native/indicator_source_derived_modules.R` | Câmbio nacional LCU/USD e índice cambial; remunerações correntes e constantes; estoque WIOD13 revalorizado pelo preço de FBCF; estoque WIOD16 deflacionado por GO; horas extrapoladas; índices, cesta fixa e rebaseamento. |
| `R/modules/native/capital_matrix_modules.R`, `R/lib/functions.R`, `R/lib/wiodr16_allocation.R` | Fornecedor versus usuário de capital; FBCF como peso; VA e correspondência EU KLEMS; taxas do ano seguinte em ambos os métodos; conservação das colunas; fallback nacional, ausência e sinais autenticados. |
| `R/modules/native/matrix_modules.R`, `R/lib/leontief_diagnostics.R` | A[i,j], trabalho direto l e lambda; exemplo de um setor; bloco produtivo; zeros de produção; fatoração, transposição, resíduo e condicionamento; certificado de convergência; transferências e cestas nacionais/internacionais. |
| `R/modules/native/reduced_matrix_modules.R` | País de origem/destino; exclusão da diagonal doméstica; recorte produtivo; fator do comércio para conversão das transferências em preços diretos. |
| `R/modules/native/indicator_common_modules.R` | Multiplicador laboral igual a 1; produto novo em valor; produção/exportações por soma de destinos; importações por produto e país receptor; transferências líquidas e sinal; reprodução da força de trabalho; lambda; depreciação; médias/taxas, mais-valia, lucro apropriado e preços diretos. |
| `R/modules/native/indicator_helpers.R`, `R/lib/aggregation_specs.R`, `R/modules/native/aggregation_modules.R` | Reformatação sem reordenar valores; razão de totais independentes versus pares completos; soma, média histórica, invariância, pesos e fórmulas; WWW versus ROW; ausência parcial ou total; exemplo numérico de média ponderada. |
| `R/modules/native/indicator_stage4_collector.R`, `assembler_modules.R`, `zz_indicator_registry.R` | Partições anuais sem lacunas/duplicação; eixo indicador/variável; recursos terminais para o painel; catálogo ativo versus definições históricas; ordem coletores → normalização → indicadores. |
| `R/lib/native_planner.R`, `R/lib/execution.R` | Seleção de instâncias e recursos herdados; preflight; staging privado; snapshot e dependências científicas; substituição de diagnósticos; validação dos artefatos gravados. |
| `R/lib/wiodr13_validation.R`, `wiodr16_validation.R`, `missingness.R`, `scientific_validation.R` | Perfis de fonte por coordenada; 0/0 versus ausência/inaplicabilidade; tolerâncias numéricas; referências de agregação; conservação de capital/depreciação; rótulos cruzados; critérios de herança e cobertura temporal. |
| `R/lib/publication.R` | Execução imutável, versão publicada e canal; hash como vínculo da evidência aos bytes; linhagem de recálculo; marcador atômico que impede misturar gerações no painel. |

Os comentários das cestas incorporam a resolução final do #28: em WIOD13,
`basket_zero` fixa participações monetárias de 1995 e `GO_P` permanece índice
1995=1 dentro da soma ponderada. A cesta agregada é então rebaseada para 2000=1.
Importar o índice **setorial** já rebaseado para 2000 alteraria os pesos efetivos.
No recálculo de estágio 4, recuperar `GO_P` da fonte normalizada autenticada
preserva o cálculo completo e o índice público herdado.

## Verificação de preservação do comportamento

Em 2026-09-06 UTC, R 4.6.1 no Windows, o verificador
[`tests/manual/verify-comment-ast.R`](../../tests/manual/verify-comment-ast.R)
comparou as árvores sintáticas produzidas por
`parse(..., keep.source = FALSE, encoding = "UTF-8")`. Comentários e espaços
não fazem parte dessas expressões; nomes, constantes, operadores, argumentos e
ordem do programa fazem.

| Verificação | Resultado |
|---|---|
| 30 arquivos exclusivamente explicativos contra `17f8a38df1efa6e2222a7cae0c899deafb561a36` | 30/30 idênticos, 607 expressões de nível superior. |
| Dois arquivos compartilhados com #28, contra cópia pós-correção e anterior aos comentários | 2/2 idênticos, 47 expressões. |
| Controle negativo: os mesmos dois arquivos contra o commit anterior à correção científica | 0/2 idênticos; saída não zero esperada, demonstrando que o verificador detecta alteração executável. |
| `git diff --check` | Sem erros de whitespace. |

O teste AST abrange **todas** as expressões dos arquivos envolvidos, não apenas
os blocos onde foram acrescentados comentários. A parte explicativa deste issue
não altera dados, metadados executáveis ou fórmulas. Os testes científicos e de
integração da árvore consolidada são registrados na
[validação do #15](issue-15.md); a igualdade AST não substitui esses testes nem
é apresentada como nova execução de dados reais.

As evidências pequenas ficam na campanha `temp/issue15-integration/results/comments/`:

| Arquivo | SHA-256 |
|---|---|
| `pure-comments-ast.csv` | `c01710cb0f316f2813c28a202c8e599a1a7e0f73927dd54644b6b911fdc2cef1` |
| `issue28-comments-ast.csv` | `7eebb785ebd05b6a987cfa31c841b97e67b7089d9c9672914ab805a76bbf25bc` |
| `science-delta-rejected.csv` | `975aa663165e782075f640249d14069fab257ebd33508ecc848e291a2bd571af` |

Cada relatório registra arquivo, quantidade de expressões, igualdade e MD5 dos
bytes comparados. Os dois arquivos-base pós-#28, preservados exclusivamente para
reproduzir a separação das mudanças, ficam em `baseline-issue28/` nessa mesma
pasta. A campanha é evidência gerada e não integra o código-fonte versionado.

Para repetir em uma revisão futura, crie ou retome uma campanha pelo gerenciador,
direcione `TEMP`, `TMP` e `TMPDIR` ao seu `scratch/` **antes** de iniciar R e
forneça os caminhos relativos dos arquivos a comparar:

```text
Rscript --vanilla tests/manual/verify-comment-ast.R BASE temp/ID/results/comments-ast.csv R/main.R R/modules/native/matrix_modules.R
```

`BASE` pode ser uma revisão Git ou um diretório com os arquivos em seus caminhos
relativos originais. Os relatórios existentes fornecem a lista exata dos 30 + 2
arquivos. Não inclua mudanças científicas na alegação de equivalência explicativa.
Hashes de bytes podem mudar com a política de fins de linha; a árvore sintática
é a verificação específica de comportamento executável.

## Limites da revisão

As correções posteriores de leitura, chaves e serialização dos metadados têm
provas próprias nos [#31](issue-31.md) e [#32](issue-32.md). A auditoria final
registrada no [#15](issue-15.md) compara a worktree executada ao snapshot
científico: 209 de 211 arquivos têm AST idêntica; as únicas três definições
alteradas pertencem à publicação. A prova de comentários acima conserva o
recorte e os hashes da etapa em que foi produzida.

A prova cobre ausência de mudanças executáveis nos comentários, não uma auditoria
independente de toda hipótese econômica preservada. Hipóteses históricas como
extrapolações de jornada, média MD e zeros convencionais foram nomeadas, sem
receber justificativas empíricas inventadas. Os contratos versionados continuam
sendo a autoridade sobre unidade/escala e ausência. Os dez métodos alternativos,
EXIOBASE, EORA e preparação de papers permanecem fora do percurso suportado.
