# Issue #29 — documentação didática bilíngue

Revisão documental: `wiod-consolidation-v1`. Escopo: somente `wiodr13` e
`wiodr16`, contratos de unidades v2 e comportamento de recálculo do
[#28](issue-28.md). A revisão exata de código é o commit que contém este
documento; resultados devem ser citados pelos manifestos de seus próprios runs.

## Entrega

| Critério | Evidência |
| --- | --- |
| README e guias completos equivalentes | [README PT](../../README-PT.md), [README EN](../../README.md), [guia PT](../guide-pt.md), [guia EN](../guide-en.md), com navegação recíproca e mesma revisão. |
| Percursos para iniciantes | Entender o projeto, usar resultados, executar e compreender código, com links de entrada nos READMEs. |
| Vocabulário econômico e técnico | Glossário antes das fórmulas, orientação de matrizes, exemplo numérico de Leontief, exploração, pesos, índices e transferências. |
| Dicionário completo | [PT](../results-dictionary-pt.md) e [EN](../results-dictionary-en.md): 58 indicadores WIOD13 e 50 WIOD16, descrições, unidades, escalas, cobertura, agregações, ausências, hipóteses e limites. |
| Cálculo/recálculo consolidado | Distinção entre GO_P fonte 1995 e índice publicado 2000; compatibilidade obrigatória e ausência de atualização implícita fora de sea_vars. A prova real fica no #28. |
| Comandos verificáveis | Teste automatizado dos blocos/assinaturas/opções e execução real do exemplo de leitura, descritos abaixo. |
| Fontes, versões e licenças | Contratos WIOD13/WIOD16 com IDs, tamanhos, hashes e CC BY 4.0; guias distinguem edições WIOD, versões Dataverse, EU KLEMS 2019 e complementos históricos. |
| Publicação e painel | Runs, releases, canais, manifestos, integridade, parent_run_id, display_multiplier e exportação da árvore completa. |
| Convenção de sincronização | [documentation-sync.md](../documentation-sync.md), teste obrigatório e geração dos dois dicionários dos mesmos contratos. |
| Escopo atual | Removidas promessas de métodos alternativos executáveis e papers; EXIOBASE/EORA aparecem apenas como futuro. Históricos científicos e campanha 054 preservados. |

O parágrafo preexistente de organização de campanhas do README-PT foi
preservado. A documentação anterior de contratos continua como anexo técnico;
as páginas WIOD13/WIOD16, unidades, ausências e validação foram atualizadas
para evitar que referências históricas pareçam suporte executável atual.

## Verificação automatizada e leitura real

`tests/testthat/test-user-documentation.R` passou isoladamente com 140
expectativas em 06/09/2026. Verifica igualdade dos blocos de comandos entre
idiomas, revisão, navegação, links locais e âncoras, sintaxe R, execução do
exemplo numérico, nomes de argumentos da API, opções do parser CLI e igualdade
exata entre dicionários e contratos. Não afirma traduzir semanticamente o
texto: os dois guias e as fórmulas foram também revisados por leitura humana
assistida e cruzados com os módulos científicos.

A verificação adicional em Windows com `LC_ALL=C`, `LC_CTYPE=C` e `LANG=C`
expôs uma dependência indevida do locale: primeiro a leitura CSV com
`fileEncoding` tentava converter acentos para ASCII; depois, os literais R
do próprio gerador não eram marcados como UTF-8. As tentativas reprovadas estão
nos logs `dictionary-check.log` e `dictionary-check-002.log` da campanha.
A correção lê CSVs com `readLines(encoding = "UTF-8")` e mantém um lançador
ASCII que carrega as definições bilíngues legíveis de
`scripts/lib/results_dictionary.R` com `parse(encoding = "UTF-8")`.
O comando `--check` e as 140 expectativas documentais passaram tanto no locale
C quanto no locale UTF-8 padrão. Os textos e bytes dos dicionários canônicos
permaneceram inalterados; não foi necessário mudar o locale para obter sucesso.

Comandos, na raiz do repositório e com temporários configurados numa campanha:

```sh
Rscript --vanilla scripts/render_results_dictionary.R --check
Rscript --vanilla scripts/render_method_catalog.R --check
```

```r
source("renv/activate.R")
testthat::test_dir("tests/testthat", filter = "^user-documentation$",
  reporter = "summary", stop_on_failure = TRUE, stop_on_warning = TRUE)
```

O verificador reutilizável `tests/manual/verify-guide-reading.R` extrai o bloco
de leitura diretamente do guia EN, igual ao PT, e o executa contra uma
publicação real. A biblioteca renv é ativada no checkout principal porque o
snapshot científico não copia `renv/`; somente raiz de cálculo e canal são
adaptados para a campanha. O exemplo verifica a cadeia de publicação e lê
FST, metadados de unidade e estados, selecionando `gdp.s.us` do Brasil em
15 anos. Ele não escreve fontes nem runs.

```sh
Rscript --vanilla tests/manual/verify-guide-reading.R temp/issue28-recalculation/worktrees/candidate validation/issue28 temp/issue15-integration/results/guide-reading.json
```

Esse comando pressupõe a campanha real #28 já criada e publicada; em outra
máquina, passe a raiz e o canal de sua própria execução validada e um caminho
de relatório dentro da campanha local. Não execute novamente a campanha 054.

O relatório `temp/issue15-integration/results/guide-reading.json` conserva
hash do guia, run_id, result_id, hash do manifesto, seleção, resultado e
adaptações. O primeiro teste bem-sucedido leu o run
`run-20260906T013427026Z-25d76dd1991285f1`, manifesto SHA-256
`ce5f989e8ba97b6b995cad18d6f9c90e8145c8acc342e9de88808e1fc0ef8501`, com PIB
Brasil 1995 de `672761725730` USD. A leitura final confirmou o guia EN SHA-256
`d0554a740d145a00ac3922f56d0073b471acf4b83ba5fa4dad14a74e07a7e612` e o
relatório SHA-256
`5d6808153f48da1c4254276ba17d3acb51b46271c403129b82a82bf8fb999535`.

A revisão independente do fluxo de clone limpo confirmou o bootstrap explícito,
as dependências Ubuntu e o objeto retornado por `New`. O workflow valida
PowerShell ≥7.5, caminhos da campanha, versão R e localização de `tempdir()`;
o cache renv fica em `renv/local/ci-cache`, ignorado pelo Git. As imagens
[Ubuntu 24.04](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
e [Windows 2022](https://github.com/actions/runner-images/blob/main/images/windows/Windows2022-Readme.md)
publicadas na data da revisão incluem PowerShell 7.6.5. O YAML foi analisado
localmente e as 140 expectativas documentais passaram novamente sob locale C.
Isso não substitui a execução remota dos dois sistemas. `New` e encerramento
usam APIs portáveis; `Clean` exige inspeção Windows. Runners hospedados
descartam a campanha com o checkout ao terminar o job.

Na construção do verificador, uma tentativa parou porque o snapshot não
incluía renv e outra parou apenas na serialização do hash do relatório
(classe `sha256` ainda não removida). Foram corrigidos o ponto de ativação e
o formato do hash; nenhuma fonte ou publicação foi alterada. Os testes de
documentação não repetem os downloads/preparação reais: a verificação de
preparação anterior e sua equivalência vigente estão no #13; a prova
cálculo/recálculo nova está no #28. A integração final Windows/Ubuntu pertence
ao fechamento do #15.

## Checagens de interpretação material

- **WIOD13 2008–2009:** leitura da SEA normalizada confirmou K_GFCF com
  39 zeros em 2007, 517 em 2008 e 585 em 2009; em todos há 1.400 células finitas
  e 35 ausências ROW. Os runs calculam montantes finitos inclusive para
  Brasil/EUA/mundo. O painel `utils/prepare_data.R` exclui ambos os anos de
  todas as séries WIOD13 pela perda de cobertura de capital. Guias e
  dicionários distinguem esse filtro de uma máscara de ausência no banco.
- **Escala de índices:** armazenamento 2000=1 nos dois métodos;
  apresentação WIOD13 ×1, WIOD16 ×100. Taxas percentuais usam ×100, enquanto
  parcelas por qualificação WIOD13 permanecem razões. O gerador deriva
  essas regras diretamente dos contratos.
- **Transferências:** soma dos fluxos produtivos da matriz bilateral se
  anula; a matriz de transferências totais não possui esse invariante.
  Saldos nacionais são exportações−importações e se cancelam globalmente
  por construção. Os textos distinguem essas operações.
- **ROW:** os métodos públicos completam emprego, horas, capital e índices,
  mantendo ausências de remuneração/empregados. Descrições das antigas
  variantes não foram generalizadas para os métodos atuais.
- **Cesta WIOD13:** participações monetárias 1995 combinam-se com GO_P 1995=1;
  a normalização da cesta em 2000 vem depois. Usar índices setoriais 2000=1
  nesse cálculo muda os pesos, causando a divergência corrigida pelo #28.

## Consulta de origem e licença

Os endpoints oficiais Dataverse consultados por HTTP em 06/09/2026 foram
`https://dataverse.nl/api/datasets/:persistentId/?persistentId=doi:10.34894/XDTAUZ`
e a mesma URL para `doi:10.34894/PJ2M1C`. Ambos retornaram
`latestVersion.versionNumber=2`, `versionMinorNumber=1`; `license` era nulo,
mas `termsOfUse` declarava explicitamente Creative Commons Attribution 4.0
International. Por isso a documentação atribui a licença aos termos do
depósito, sem interpretar `license=null` como ausência de licença.
O [arquivo oficial EU KLEMS 2019](https://euklems.eu/archive-history/) confirma
a mesma licença para essa edição. Os hashes econômicos continuam os fixados
nos preparadores, independentemente da atualização de páginas web.
