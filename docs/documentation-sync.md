# Convenção de documentação / Documentation convention

Revisão / revision: `wiod-consolidation-v1`.

## Português

Os pares de documentos canônicos são `README-PT.md` / `README.md`,
`docs/guide-pt.md` / `docs/guide-en.md` e
`docs/results-dictionary-pt.md` / `docs/results-dictionary-en.md`. Cada par
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

Uma alteração de comportamento precisa atualizar os dois idiomas no mesmo PR
(proposta de alteração no Git), incluindo exemplos, unidades, ausências e
limites afetados. Incremente a revisão documental quando mudar suporte,
semântica científica ou o percurso público. Correções editoriais podem manter
a revisão. As descrições econômicas ficam em `docs/indicator-descriptions.csv`
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
Exemplos de cálculo precisam das fontes e recursos declarados; a prova real
está separada das verificações sintéticas em `docs/validation/`. Nunca declare
que um teste de sintaxe executou uma campanha científica.

## English

Canonical document pairs are `README-PT.md` / `README.md`,
`docs/guide-pt.md` / `docs/guide-en.md`, and
`docs/results-dictionary-pt.md` / `docs/results-dictionary-en.md`. Each pair
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

A behaviour change must update both languages in the same PR (Git change
proposal), including affected examples, units, missingness and limitations.
Increment the documentation revision when support, scientific semantics or
the public workflow changes. Editorial corrections may retain the revision.
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
synchronization. Human review checks equivalent meaning. Calculation examples
require the declared sources and resources; real-data evidence is separate
from synthetic checks in `docs/validation/`. Never describe a syntax check
as executing a scientific campaign.
