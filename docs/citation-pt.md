# Citar o banco, os resultados e as fontes

<!-- documentation-revision: wiod-reader-workflows-v2 -->

Português | [English](citation-en.md) | [Usar os dados](use-results-pt.md) | [Referências teóricas](references-pt.md) | [Início](../README-PT.md)

Uma referência ao projeto reconhece sua autoria e permite encontrá-lo. Uma
nota de dados identifica o material que sustenta uma análise. Use ambas:
citar o artigo metodológico não identifica, sozinho, a edição das fontes,
o código, as seleções e os resultados utilizados.

## Distinga os objetos citados

| Objeto | Identificação a preservar |
| --- | --- |
| Fundamentação teórica e metodológica | Franklin et al. (2022) e Franklin (2025), conforme o conceito e o método discutidos; referências completas na página bibliográfica. |
| Software WLVDB | Nome do projeto, repositório, commit efetivamente utilizado e data de acesso. |
| Resultado nativo | Método, versão das fontes e contratos, `run_id`, `result_id`, `release_id` e manifestos completos. |
| Seleção obtida pelo site | Endereço de acesso, data, arquivo, indicadores, filtros, unidades e os identificadores efetivamente fornecidos. |
| Análise posterior | Script, versão, transformações, exclusões e justificativas, distinguindo-as dos cálculos do banco. |

Resultados estão disponíveis no [World Labour Values](https://panel.worldlabourvalues.org/)
e no [LabCidades/UFES](http://labcidades.ufes.br/worldlabourvalues/).
Use o endereço pelo qual obteve a seleção. Um exportador pode fornecer menos
metadados que uma publicação nativa; registre os campos não fornecidos em vez
de preenchê-los com o commit atual do repositório ou com identificadores supostos.

## Modelo de nota para uma exportação

Substitua cada campo entre colchetes por informação da sua análise. Este é um
modelo editorial, não uma descrição de uma execução já realizada.

> Fonte dos resultados: World Labour Values Database (WLVDB), obtidos em
> [endereço], em [data]. Arquivo original: [nome e formato]. Método: [método].
> Indicador: [código e descrição]. Países/setores: [códigos e classificação].
> Período: [anos]. População e recorte produtivo: [definição]. Unidade recebida:
> [razão, porcentagem, índice, horas ou unidade monetária]. Identificadores da
> publicação fornecidos: [campos e valores; ou “não informados na exportação”].
> Transformações: [procedimentos, inclusive escala]. Cobertura e exclusões:
> [decisões e justificativas]. Script de análise: [arquivo e versão].

Para a pergunta introdutória deste manual, a descrição do recorte é
“Brasil (`BRA`), `wiodr13`, `surplus_value.empe_p.r.pc`, empregados de setores
produtivos, 1995–2007”. Esse texto identifica uma **seleção proposta**, não
fornece valores empíricos nem dispensa a avaliação de sua cobertura.

## Modelo de nota para uma publicação nativa

> Resultados WLVDB: método [método], anos [anos], run [run_id], conteúdo
> [result_id], release [release_id]. Código do cálculo: [commit registrado no
> manifesto]. Fonte: [edição, depósito e identidade dos arquivos]. Contratos:
> [versões de fonte, unidade e saída]. Indicadores e recortes: [seleção].
> Estados e anomalias: [artefatos preservados e decisões de uso]. Análise:
> [script e versão]. Data de acesso: [data]. Manifestos completos arquivados
> com a pesquisa em [local ou identificador persistente].

O commit do cálculo e o commit da análise podem ser diferentes. O nome do
canal `stable` não substitui a release imutável. Um checksum identifica bytes;
não demonstra validade de uma hipótese ou equivalência entre duas metodologias.

## Modelos de referência do software e dos dados

Conserve a autoria indicada na versão citada. Os modelos abaixo usam o título
do projeto como entrada e seguem a estrutura de identificação bibliográfica;
não atribuem uma autoria pessoal nova nem uma data de publicação não verificada.

**WORLD LABOUR VALUES DATABASE (WLVDB).** Código-fonte. Revisão [commit].
[Repositório do projeto](https://github.com/rodrigofranklin/wlvdb).
Acesso em: [dia mês ano].

**WORLD LABOUR VALUES DATABASE (WLVDB).** Resultados: [método e período].
Release [release_id], run [run_id], conteúdo [result_id].
[World Labour Values](https://panel.worldlabourvalues.org/).
Acesso em: [dia mês ano].

Uma exportação sem esses IDs deve ser citada pelo arquivo, recorte, endereço
e data de obtenção realmente disponíveis. Não copie os colchetes como se
fossem identificadores. Ao citar resultados de um artigo, registre a seleção
e a versão utilizadas naquele artigo; executar o código atual não estabelece
reprodução de suas tabelas históricas.

## Fontes estatísticas e referência de uso da WIOD

Os títulos das edições e seus DOIs identificam as fontes, enquanto os manifestos
e contratos identificam os arquivos exatos aceitos pelo cálculo. O ano de
depósito 2021 não é o ano de edição 2013/2016 nem o período observado. A
cobertura da fonte WIOD13 abaixo é maior que a cobertura do método WLVDB.

TIMMER, Marcel; DIETZENBACHER, Erik; LOS, Bart; STEHRER, Robert; DE VRIES,
Gaaitzen. **World Input-Output Database 2013 Release, 1995–2011**.
DataverseNL, 2021. Conjunto de dados. DOI:
[10.34894/XDTAUZ](https://doi.org/10.34894/XDTAUZ).
Acesso em: 6 set. 2026.

TIMMER, Marcel; DIETZENBACHER, Erik; LOS, Bart; STEHRER, Robert; DE VRIES,
Gaaitzen. **World Input-Output Database 2016 Release, 2000–2014**.
DataverseNL, 2021. Conjunto de dados. DOI:
[10.34894/PJ2M1C](https://doi.org/10.34894/PJ2M1C).
Acesso em: 6 set. 2026.

TIMMER, Marcel P.; DIETZENBACHER, Erik; LOS, Bart; STEHRER, Robert;
DE VRIES, Gaaitzen J. An illustrated user guide to the World Input-Output
Database: the case of global automotive production.
**Review of International Economics**, v. 23, n. 3, p. 575–605, 2015.
DOI: [10.1111/roie.12178](https://doi.org/10.1111/roie.12178).

THE VIENNA INSTITUTE FOR INTERNATIONAL ECONOMIC STUDIES (wiiw).
**The EU KLEMS 2019 data repository**. Vienna: wiiw, 2019.
Disponível em: [arquivo oficial da edição 2019](https://euklems.eu/archive-history/).
Acesso em: 6 set. 2026.

A identificação bibliográfica foi conferida no
[portal da Universidade de Groningen](https://research.rug.nl/en/publications/an-illustrated-user-guide-to-the-world-input-output-database-the-/)
e no arquivo oficial EU KLEMS. As páginas oficiais
[WIOD13](https://www.rug.nl/ggdc/valuechain/wiod/wiod-2013-release?lang=en) e
[WIOD16](https://www.rug.nl/ggdc/valuechain/wiod/wiod-2016-release?lang=en)
solicitam a referência ao artigo de Timmer et al. (2015). A página EU KLEMS
indica também seus relatórios de construção e análise para atribuição conforme
o uso. Consulte essas orientações ao preparar a bibliografia da pesquisa.

Os complementos de emprego, horas e correspondências não se tornam novas
observações WIOD por serem utilizados pelo programa. Cite seus provedores e
as transformações do WLVDB conforme [fontes e atribuição](guide-pt.md#fontes-e-atribuição)
e os manifestos do run. Não substitua a edição fixada por outra de mesmo nome.
