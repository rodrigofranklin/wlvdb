# Banco de Dados de Valores Trabalho Mundiais (WLVDB)

<!-- documentation-revision: wiod-consolidation-v1 -->

Português | [English](README.md)

O WLVDB estima valores trabalho, taxas de mais-valia, capital e transferências
pelo comércio a partir de matrizes mundiais de insumo-produto e contas
socioeconômicas. O projeto relaciona categorias econômicas a cálculos
reproduzíveis e publica os resultados lidos pelo WLVPanel. São estimativas sob
hipóteses explícitas, não observações diretas das categorias marxianas.

Esta versão oferece suporte **somente a `wiodr13` (1995–2009) e `wiodr16`
(2000–2014)**. Ambos preparam fontes, calculam, validam, recalculam variáveis e
publicam resultados para o painel. EXIOBASE e EORA são expansão futura no
[#14](https://github.com/rodrigofranklin/wlvdb/issues/14). As definições
alternativas preservadas não são executáveis, mesmo com a opção experimental.
Pesquisadores podem consumir os resultados em scripts próprios de análise;
preparação e geração de artigos estão fora do projeto.

## Escolha um percurso de leitura

A documentação relaciona **o que está sendo medido**, **como se calcula** e
**como trabalhar com o código e os resultados**. Comece pela teoria se os
valores trabalho forem novos para você. O capítulo matemático constrói uma
pequena economia passo a passo antes de relacionar suas equações à implementação.

| Comece aqui | Percurso de leitura |
| --- | --- |
| Entender os conceitos e sua mensuração | [Teoria: trabalho, valor, reprodução, exploração e comércio](docs/theory-pt.md), com [referências ABNT](docs/references-pt.md) |
| Entender a matemática | [Metodologia: notação, derivações, exemplo resolvido e correspondência com o código](docs/methodology-pt.md) |
| Avaliar hipóteses e lacunas de pesquisa | [Hipóteses, imputações, dados excepcionais e trabalho pendente](docs/assumptions-pt.md) |
| Usar resultados sem executar cálculos | [Arquivos, unidades, ausências e leitura de dados](docs/guide-pt.md#usar-os-resultados), depois o [dicionário completo de indicadores](docs/results-dictionary-pt.md) |
| Reproduzir ou melhorar o projeto | [Instalação e percurso executável](docs/guide-pt.md#executar-o-projeto), depois o [percurso de contribuição](docs/guide-pt.md#contribuir-com-uma-melhoria) |

Os capítulos conceituais se apoiam em Franklin et al. (2022) e Franklin (2025).
Eles distinguem as hipóteses desses estudos das adotadas pelo código atual:
classificações de setores produtivos, alternativas de redução do trabalho e
tratamento da depreciação não são idênticos em todas as versões. Uma execução
bem-sucedida, portanto, não reproduz por si só todas as tabelas das publicações.

## Execute os métodos disponíveis

Na raiz do repositório, com R 4.6.1 instalado:

```sh
Rscript --vanilla scripts/bootstrap.R
Rscript --vanilla scripts/run_wlv.R --method wiodr13 --prepare-only --check
Rscript --vanilla scripts/run_wlv.R --method wiodr13 --prepare-only
Rscript --vanilla scripts/run_wlv.R --method wiodr13 --workers 1
```

O bootstrap restaura os pacotes do `renv.lock`. A preparação baixa e verifica
as entradas econômicas. `--check` verifica apenas o ambiente e a solicitação;
não valida fontes nem calcula resultados. Abrir o projeto não instala pacotes,
não carrega uma sessão salva nem inicia cálculos. O percurso é independente
de IDE: use o editor ou terminal de sua preferência; configurações pessoais
do IDE não são versionadas. Consulte as
[medições de recursos](docs/guide-pt.md#recursos) antes de uma execução real.

O [catálogo de suporte](docs/methods.md), os contratos das fontes
[WIOD13](docs/wiodr13.md) e [WIOD16](docs/wiodr16.md), a
[validação científica](docs/scientific-validation.md) e o
[contrato de publicação](docs/result-publication.md) detalham a implementação.
A teoria, a matemática, as hipóteses, o guia prático e as referências estão
disponíveis integralmente em português e inglês. Os anexos técnicos e os
registros históricos de auditoria conservam seu idioma original.
A revisão documental e as regras de manutenção estão na
[convenção de sincronização](docs/documentation-sync.md).

O código da aplicação e os comandos de manutenção ficam em `scripts/`. A pasta
`tests/` contém código de testes e dados de exemplo controlados (*fixtures*)
versionados para detectar regressões. Resultados gerados pelos testes, logs,
experimentos e campanhas locais ficam exclusivamente em `temp/<id>/`, ignorado
pelo Git. Consulte [campanhas e limpeza local](docs/local-campaigns.md) para
criar, encerrar e remover execuções temporárias. A campanha 054 permanece
preservada em `temp/054/` e não deve ser reexecutada, alterada nem excluída.

Para uma citação reproduzível, registre método, anos, commit Git, contrato de
unidades, `run_id`, `result_id`, `release_id` e referências das fontes do run.
A atribuição e as licenças das fontes são explicadas no
[guia](docs/guide-pt.md#fontes-e-atribuição).
