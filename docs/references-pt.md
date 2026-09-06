# Referências e roteiro de leitura

<!-- documentation-revision: wiod-reader-workflows-v2 -->

Português | [English](references-en.md) | [Início](../README-PT.md) | [Teoria](theory-pt.md) | [Matemática](methodology-pt.md) | [Guia prático](guide-pt.md)

As referências seguem as convenções de autoria, título e publicação da
ABNT. Os títulos originais foram preservados. As citações de páginas usam
a numeração impressa nas edições abaixo, inclusive na leitura em PDF.

Para citar uma análise, consulte também [software, resultados e fontes estatísticas](citation-pt.md).
Essa página oferece modelos de nota de dados e distingue exportações do site
de publicações nativas, sem atribuir identificadores que não foram fornecidos.

## Fontes principais consultadas

### Franklin et al. 2022

FRANKLIN, Rodrigo Straessli Pinto; BORGES, Rodrigo Emmanuel Santana;
SÁNCHEZ, César; MONTIBELER, Everlam Elias. Skilled labour and the reduction
problem: questioning the exploitation rate equalization hypothesis.
**World Review of Political Economy**, Hong Kong, v. 13, n. 3,
p. 362–390, 2022. DOI:
[10.13169/worlrevipoliecon.13.3.0362](https://doi.org/10.13169/worlrevipoliecon.13.3.0362).

O artigo de 2022 fundamenta a comparação entre os métodos de redução
do trabalho, sua crítica teórica e a construção empírica original.

| Páginas | Objetivo da leitura |
| --- | --- |
| 363–364 | O programa empírico e sua conexão com o World Labour Values Database. |
| 365–369 | Força de trabalho, criação de valor, redução pelos salários e crítica à equalização das taxas de exploração. |
| 370–374 | Requerimentos de trabalho, depreciação do capital, os cinco métodos de redução e cestas de consumo. |
| 375–383 | Comparações entre preços e valores, estimativas de exploração e transferências internacionais sob hipóteses diferentes. |
| 383–384 | Limites dos multiplicadores arbitrários de qualificação e da alternativa de horas iguais. |
| 386–387, notas 16–27 | Unidades, classificação produtiva, estimativas do resto do mundo, capital e conversões monetárias. |

### Franklin 2025

FRANKLIN, Rodrigo Straessli Pinto. **Teoria da dependência: guia para uma
análise do mercado mundial**. Vitória, ES: Edufes, 2025. 276 p. E-book.
ISBN 978-85-7772-611-0. Disponível em:
[edição digital da Edufes](https://edufes.ufes.br/items/show/777).
Acesso em: 6 set. 2026.

A edição digital fornecida é de **2025**. Não se trata da tese de doutorado
de 2015, com o subtítulo *categorias para uma análise do mercado mundial*,
nem da edição impressa catalogada separadamente. As citações do livro
nesta documentação remetem à edição digital identificada acima.

| Páginas | Objetivo da leitura |
| --- | --- |
| 95–128 | Superexploração e reprodução da força de trabalho. |
| 135–190 | Diferentes mecanismos de apropriação internacional. |
| 190–195 | Contas de insumo-produto, trabalho produtivo e sistema de requerimentos de trabalho. |
| 195–197 | Importância do saldo monetário comercial; referência do comércio e equação de transferência. |
| 197–200 | Exemplo numérico completo e hipóteses simplificadoras da aplicação. |
| 209–239 | Subordinação e vinculação entre processos nacionais de acumulação. |
| 243–250 | Jornada, custos de reprodução e distinção entre exploração e superexploração. |

## Relação entre as fontes e os métodos executáveis

| Questão | Publicações fornecidas | Repositório atual |
| --- | --- | --- |
| Geração de dados | O artigo estuda WIOD 2013, 1995–2009. | `wiodr13` e `wiodr16` possuem contratos de fontes e resultados distintos. |
| Redução do trabalho | O artigo compara cinco métodos. | Ambos os métodos WIOD executáveis usam pesos iguais para as horas. |
| Classificação produtiva | A nota 21 do artigo especifica sua seleção original. | Os arquivos `_sectors.csv` versionados definem a seleção efetiva; a seleção WIOD13 atual difere para hotéis/restaurantes e outros serviços comunitários/sociais/pessoais. |
| Capital fixo | O artigo inclui depreciação reconstruída; a aplicação ilustrativa do livro a omite, p. 200, nota 77. | Os métodos atuais calculam uma matriz de depreciação sob hipóteses documentadas. |
| Reprodução empírica | As tabelas publicadas refletem os dados e escolhas originais. | Uma execução atual reproduz seu próprio contrato versionado; isso não reproduz automaticamente todas as tabelas históricas. |

O [registro de hipóteses](assumptions-pt.md) e os
[contratos das fontes](guide-pt.md) explicam a implementação. As publicações
fornecem os fundamentos teóricos e metodológicos; o repositório registra
as escolhas efetivamente utilizadas em cada execução.

## Leituras complementares citadas pelas fontes principais

As obras a seguir oferecem um percurso de leitura dos conceitos
fundamentais. Seus dados bibliográficos foram conferidos nos materiais
fornecidos. Elas não são apresentadas como textos adicionais integralmente
lidos para esta documentação, e não lhes são atribuídas citações de páginas
não verificadas.

MARX, Karl. **O capital: crítica da economia política: livro primeiro:
o processo de produção do capital**. São Paulo: Boitempo, 2013.

MARX, Karl. **O capital: crítica da economia política: livro segundo:
o processo de circulação do capital**. São Paulo: Boitempo, 2014.

MARX, Karl. **O capital: crítica da economia política: livro terceiro:
o processo global da produção capitalista**. São Paulo: Boitempo, 2017.

MARX, Karl. **Capital: a critique of political economy**. London:
Penguin Books, 1976. v. 1.

MARX, Karl. **Capital: a critique of political economy**. London:
Penguin Books, 1981. v. 3.

MARX, Karl. **Capítulo VI inédito de O capital: resultados do processo
de produção imediata**. São Paulo: Moraes, 1985.

SHAIKH, Anwar M.; TONAK, E. Ahmet. **Measuring the wealth of nations:
the political economy of national accounts**. Cambridge: Cambridge
University Press, 1994.

O primeiro livro de *O capital* desenvolve mercadoria, força de trabalho
e mais-valor; o segundo estuda circulação e reprodução; o terceiro
desenvolve lucro e distribuição. O *Capítulo VI* ajuda a esclarecer o
alcance do trabalho produtivo. Shaikh e Tonak conectam as categorias
marxianas às contas nacionais, distinção utilizada diretamente na discussão
do trabalho produtivo do livro fornecido.
