# Convenção de documentação / Documentation convention

Revisão / revision: `wiod-consolidation-v1`.

## Português

Os pares de documentos canônicos são `README-PT.md` / `README.md`,
`docs/guide-pt.md` / `docs/guide-en.md` e
`docs/results-dictionary-pt.md` / `docs/results-dictionary-en.md`, além dos
capítulos `docs/theory-pt.md` / `docs/theory-en.md`,
`docs/methodology-pt.md` / `docs/methodology-en.md`,
`docs/assumptions-pt.md` / `docs/assumptions-en.md` e
`docs/references-pt.md` / `docs/references-en.md`. Cada par
tem navegação recíproca, a mesma revisão em `documentation-revision`, os mesmos
comandos executáveis e a mesma cobertura econômica. A tradução pode adaptar
a redação, mas não suprimir hipóteses, limites ou pré-requisitos.

Esta revisão descreve somente `wiodr13` e `wiodr16`, contratos de unidades v2,
publicação `wlvpanel-output/1.0.0` e o cálculo/recálculo consolidado no #28.
O commit do checkout identifica exatamente o código documentado; não se fixa
um hash futuro dentro do próprio commit. Para citar um resultado, prevalecem
o commit e os contratos do manifesto do run. Anexos técnicos e provas
históricas mantêm seu idioma e seu contexto temporal: não são substitutos dos
guias completos bilíngues e não autorizam caminhos executáveis antigos.

A organização atual reúne o código em `scripts/`: referências históricas a
`R/lib/`, `R/modules/`, `R/preparation/` e `R/main.R` correspondem hoje aos
mesmos caminhos sob `scripts/`. O antigo `R/bootstrap.R` corresponde a
`scripts/runtime_bootstrap.R`; `scripts/bootstrap.R` continua sendo o
restaurador de pacotes. As provas em `docs/validation/` conservam os nomes e
hashes das revisões verificadas; use os guias atuais para comandos novos.
O destino das ferramentas autenticadas antes mantidas em `run_logs/` está
documentado em [campanhas locais](local-campaigns.md); os registros históricos
de execução continuam com seus nomes originais.

A realocação altera a identidade do código usada para validar o recálculo.
Resultados publicados antes dela continuam preservados, mas um recálculo com
o código reorganizado exige primeiro um cálculo completo nessa versão. Para
reproduzir um recálculo antigo, use o commit registrado no run; não altere seus
manifestos ou hashes para forçar compatibilidade.

Uma alteração de comportamento precisa atualizar os dois idiomas no mesmo PR
(proposta de alteração no Git), incluindo exemplos, unidades, ausências e
limites afetados. Incremente a revisão documental quando mudar suporte,
semântica científica ou o percurso público. Correções editoriais podem manter
a revisão. A ampliação didática desta revisão não altera os métodos: separa
teoria, derivação matemática, hipóteses e prática, distinguindo o artigo de
2022, o livro digital de 2025 e o código executável. Ao atualizar os capítulos,
confira também as remissões entre equação, identificador e módulo, as diferenças
entre as publicações e o código, as páginas citadas e as referências ABNT.
Os anexos históricos não substituem esse percurso bilíngue.
As descrições econômicas ficam em `docs/indicator-descriptions.csv`
com colunas PT/EN; unidades, escalas e agregações vêm exclusivamente dos
contratos executáveis. O gerador recusa indicadores sem tradução e cobertura
diferente dos resultados configurados.

O gerador `scripts/render_results_dictionary.R` usa apenas ASCII, com escapes
Unicode nos literais bilíngues. A função está definida diretamente nesse
arquivo, sem carregamento dinâmico. Descrições e dicionários permanecem
legíveis em UTF-8. Isso preserva os mesmos bytes sob locale C ou UTF-8;
não troque a leitura por conversão para o locale da máquina.

```sh
Rscript --vanilla scripts/render_results_dictionary.R
Rscript --vanilla scripts/render_results_dictionary.R --check
Rscript --vanilla scripts/render_method_catalog.R --check
```

`tests/testthat/test-user-documentation.R` verifica revisão e navegação,
igualdade dos blocos de comandos nos pares, sintaxe dos exemplos R e
sincronização do dicionário. A revisão humana confere equivalência de sentido.
O exemplo autocontido de dois setores do capítulo matemático também é
executado e comparado com seus resultados analíticos, sem dados externos.
Exemplos de cálculo precisam das fontes e recursos declarados; a prova real
está separada das verificações sintéticas em `docs/validation/`. Nunca declare
que um teste de sintaxe executou uma campanha científica.

## English

Canonical document pairs are `README-PT.md` / `README.md`,
`docs/guide-pt.md` / `docs/guide-en.md`, and
`docs/results-dictionary-pt.md` / `docs/results-dictionary-en.md`, plus
`docs/theory-pt.md` / `docs/theory-en.md`,
`docs/methodology-pt.md` / `docs/methodology-en.md`,
`docs/assumptions-pt.md` / `docs/assumptions-en.md`, and
`docs/references-pt.md` / `docs/references-en.md`. Each pair
has reciprocal navigation, the same `documentation-revision`, identical
executable commands and equivalent economic coverage. Translation may adapt
wording but cannot omit assumptions, limitations or prerequisites.

This revision describes only `wiodr13` and `wiodr16`, v2 unit contracts,
`wlvpanel-output/1.0.0` publication and calculation/recalculation consolidated
by #28. The checkout commit identifies the exact documented code; a future
hash is not embedded in its own commit. For result citation, use the commit
and contracts from the run manifest. Technical annexes and historical proofs
retain their language and temporal context: they do not replace the complete
bilingual guides or authorize old execution paths.

The current layout groups code under `scripts/`: historical references to
`R/lib/`, `R/modules/`, `R/preparation/` and `R/main.R` now correspond to the
same paths under `scripts/`. The former `R/bootstrap.R` is now
`scripts/runtime_bootstrap.R`; `scripts/bootstrap.R` remains the package
restorer. Evidence in `docs/validation/` retains the names and hashes of the
verified revisions; use the current guides for new commands.
The destination of authenticated tools formerly kept in `run_logs/` is
documented in [local campaigns](local-campaigns.md); historical execution
records retain their original names.

Relocation changes the code identity used to validate recalculation. Earlier
published results remain preserved, but recalculation with the reorganized code
requires a full calculation with this version first. To reproduce an older
recalculation, use the commit recorded in its run; do not edit manifests or
hashes to force compatibility.

A behaviour change must update both languages in the same PR (Git change
proposal), including affected examples, units, missingness and limitations.
Increment the documentation revision when support, scientific semantics or
the public workflow changes. Editorial corrections may retain the revision.
This revision's teaching expansion does not change the methods: it separates
theory, mathematical derivation, assumptions and practice, distinguishing the
2022 article, the 2025 digital book and the executable code. When updating the
chapters, also check equation-to-identifier-to-module links, differences between
the publications and code, cited pages and ABNT references. Historical annexes
do not replace this bilingual reading path.
Economic descriptions live in `docs/indicator-descriptions.csv` with PT/EN
columns; units, scales and aggregations come exclusively from executable
contracts. The generator rejects missing translations and coverage differing
from configured outputs. Use the three commands above to regenerate and check.

The `scripts/render_results_dictionary.R` generator is ASCII-only, using
Unicode escapes for bilingual literals. Its function is defined directly
in that file, without dynamic loading. Descriptions and dictionaries remain
readable UTF-8. This ensures identical bytes under C and UTF-8 locales;
do not replace this reading path with conversion to the machine's locale.

`tests/testthat/test-user-documentation.R` checks revision and navigation,
identical command blocks in pairs, R example syntax and dictionary
synchronization. Human review checks equivalent meaning. The self-contained
two-sector mathematical example is also executed against its analytical results,
without external data. Full calculation examples
require the declared sources and resources; real-data evidence is separate
from synthetic checks in `docs/validation/`. Never describe a syntax check
as executing a scientific campaign.
