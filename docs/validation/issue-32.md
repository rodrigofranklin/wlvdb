# Issue #32 — preservação de Unicode na publicação CSV

O gravador `wlv_write_result_csv()` e o leitor autenticado
`wlv_read_panel_result_csv()` preservam texto UTF-8 também quando o processo R
inicia com `LC_ALL=C`, `LC_CTYPE=C` e `LANG=C`. A correção mantém as convenções
CSV existentes: separador `;`, decimal `,`, aspas duplicadas, ausência como
campo vazio e formatação numérica de `utils::write.csv2()`.

## Defeito reproduzido e correção

No Windows/R 4.6.1, o rótulo `Índice`, construído por `intToUtf8()` para não
depender da codificação do script, era gravado como o texto ASCII
`<U+00CD>ndice`. Os bytes esperados começam em `c38d`; os bytes antigos
começavam em `3c552b303043443e`. `fileEncoding = "UTF-8"` não prevenia o
defeito: `write.table()` traduzia a string marcada para o locale nativo
antes da codificação da conexão. A validação final aceitava o escape porque
ele próprio é ASCII válido.

O gravador agora prepara uma cópia com bytes UTF-8 validados dos textos,
nomes das colunas e níveis de fatores. Retira dessa cópia a marca que
disparava a segunda tradução e entrega os bytes a uma conexão binária.
O serializador CSV original continua responsável por aspas e números.
No Windows, a expansão de LF para CRLF reproduz os bytes da antiga conexão
de texto, inclusive dentro de campos entre aspas. O objeto fornecido pelo
chamador permanece inalterado. Texto inválido ou com U+FFFD é rejeitado
antes da escrita, e o arquivo continua sujeito à verificação UTF-8 final.

O leitor já capturava bytes e verificava o hash antes de interpretar o CSV.
Agora informa também `encoding = "UTF-8"` ao parser, preservando a marca
das strings resultantes sob locale C. A interpretação de campos vazios
como ausências, corrigida no [#31](issue-31.md), continua em vigor.

## Verificação

`tests/testthat/test-publication-unicode.R` cobre cabeçalho e conteúdo
acentuados, caracteres chineses, travessão, delimitador, aspas, quebra de
linha interna, níveis de fatores, NA, valores numéricos, booleanos e tabela
sem linhas. Verifica igualdade do texto lido, ausência de escapes espúrios,
preservação do objeto original, rejeição de U+FFFD e igualdade byte a byte
com o gravador anterior para uma tabela ASCII com números de alta precisão.

Em 06/09/2026, no Windows/R 4.6.1, passaram 23 expectativas desse arquivo
no processo UTF-8 padrão, incluindo uma troca temporária para C no teste,
e 13 em um processo iniciado diretamente em C. As 18 expectativas iniciais
de `test-publication-missing-metadata.R` também passaram em ambos.
O primeiro ensaio do teste expôs apenas que a serialização R inclui o nome
do locale; a referência de imutabilidade passou a ser capturada depois de
selecionar cada locale. Nenhum resultado científico foi produzido ou
alterado por esses ensaios.

O controle negativo separado executou o gravador antigo e o corrigido sobre
a mesma tabela sintética de duas linhas, sob locale C, e confirmou que
somente o segundo conserva exatamente o objeto lido. Os dois arquivos e o
relatório foram preservados em `temp/issue15-integration/results/`:

| Artefato | SHA-256 |
| --- | --- |
| `issue32-before.csv` (resultado reprovado) | `738ae5a4266d342d3e5eebaba0944137654f3f5f93dc89221aacf1b0551f529b` |
| `issue32-after.csv` (ida e volta exata) | `f8c28b479f7b18c881c74f38cc1ca044e74222b97ad16a0a372802f810c9b21f` |
| `issue32-unicode-check.json` | `1a2df5520c77b8139a4c85ce096d39ac2df769777f523b4237db114d6bcdb748` |

O relatório registra R 4.6.1, locale C e hashes dos arquivos-fonte de leitura
e escrita no momento da prova. O script da campanha é
`temp/issue15-integration/scratch/issue32-evidence.R`; executa-se com
`Rscript --vanilla` depois de configurar os temporários e as três variáveis
de locale indicadas acima. Esses hashes de arquivos locais incluem seus
fins de linha e não substituem a impressão digital canônica do runtime.

Com temporários configurados dentro de uma campanha, a verificação focada é:

```r
source("renv/activate.R")
testthat::test_dir("tests/testthat",
  filter = "^publication-(unicode|missing-metadata)$",
  reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)
```

As verificações locais não substituem o gate de integração remoto nem a
publicação real dos dois métodos registrada no #15. A correção não modifica
fórmulas, unidades ou matrizes. Como qualquer alteração do runtime, muda
sua impressão digital; os novos runs devem registrar o código final, sem
reatribuir a proveniência de runs anteriores.
