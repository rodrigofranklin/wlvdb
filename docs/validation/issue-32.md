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
e 13 em um processo iniciado diretamente em C. Os 18 testes de expectativas
iniciais de `test-publication-missing-metadata.R` também passaram em ambos.
O primeiro ensaio do teste expôs apenas que a serialização R inclui o nome
do locale; a referência de imutabilidade passou a ser capturada depois de
selecionar cada locale. Nenhum resultado científico foi produzido ou
alterado por esses ensaios.

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
