# References and reading map

<!-- documentation-revision: wiod-consolidation-v1 -->

[Português](references-pt.md) | English | [Home](../README.md) | [Theory](theory-en.md) | [Mathematics](methodology-en.md) | [Practical guide](guide-en.md)

References use ABNT author-title-publication conventions. Original titles
are preserved. Page citations refer to the printed page numbers in the
editions below, including when the work is read as a PDF.

## Core sources consulted

### Franklin et al. 2022

FRANKLIN, Rodrigo Straessli Pinto; BORGES, Rodrigo Emmanuel Santana;
SÁNCHEZ, César; MONTIBELER, Everlam Elias. Skilled labour and the reduction
problem: questioning the exploitation rate equalization hypothesis.
**World Review of Political Economy**, Hong Kong, v. 13, n. 3,
p. 362–390, 2022. DOI:
[10.13169/worlrevipoliecon.13.3.0362](https://doi.org/10.13169/worlrevipoliecon.13.3.0362).

The supplied article is the source for the comparison of labour-reduction
methods, its theoretical critique and the original empirical construction.

| Pages | Read for |
| --- | --- |
| 363–364 | The empirical programme and its connection to the World Labour Values Database. |
| 365–369 | Labour-power, value creation, wage-based reduction and the exploitation-rate equalization critique. |
| 370–374 | Labour requirements, capital depreciation, the five reduction methods and consumption baskets. |
| 375–383 | Price-value comparisons, exploitation estimates and international transfers under different assumptions. |
| 383–384 | Limits of arbitrary skill multipliers and the equal-hours alternative. |
| 386–387, notes 16–27 | Units, productive classification, rest-of-world estimates, capital and currency conversions. |

### Franklin 2025

FRANKLIN, Rodrigo Straessli Pinto. **Teoria da dependência: guia para uma
análise do mercado mundial**. Vitória, ES: Edufes, 2025. 276 p. E-book.
ISBN 978-85-7772-611-0. Available at:
[Edufes digital edition](https://edufes.ufes.br/items/show/777).
Accessed: 6 Sept. 2026.

The supplied digital edition is dated **2025**. It is not the 2015 doctoral
thesis with the subtitle *categorias para uma análise do mercado mundial*,
nor the separately catalogued print edition. This documentation's book
citations refer to the digital edition identified above.

| Pages | Read for |
| --- | --- |
| 95–128 | Superexploitation and the reproduction of labour-power. |
| 135–190 | Different mechanisms of international appropriation. |
| 190–195 | Input-output accounts, productive labour and the labour-requirement system. |
| 195–197 | Why the monetary trade balance matters; the trade benchmark and transfer equation. |
| 197–200 | A complete numerical example and the simplifying assumptions of the application. |
| 209–239 | Subordination and connections between national accumulation processes. |
| 243–250 | Working time, reproduction costs and the distinction between exploitation and superexploitation. |

## How the sources relate to the executable methods

| Issue | Supplied publications | Current repository |
| --- | --- | --- |
| Data generation | The article studies WIOD 2013, 1995–2009. | `wiodr13` and `wiodr16` have distinct source and output contracts. |
| Labour reduction | The article compares five methods. | Both executable WIOD methods use equal hour weights. |
| Productive classification | Article note 21 specifies its original selection. | Versioned `_sectors.csv` files define the actual selection; the current WIOD13 selection differs for hotels/restaurants and other community/social/personal services. |
| Fixed capital | The article includes reconstructed depreciation; the book's illustrative application omits it, p. 200, note 77. | The current methods calculate a depreciation matrix under documented assumptions. |
| Empirical reproduction | Published tables reflect their original data and choices. | A current execution reproduces its own versioned contract; it does not by itself reproduce every historical table. |

The [assumptions register](assumptions-en.md) and
[source contracts](guide-en.md) explain the implementation. The publications
provide theoretical and methodological foundations; the repository records
which choices a particular execution actually uses.

## Further reading cited by the core sources

The following works provide a reading route into the underlying concepts.
Their bibliographic information was checked against the supplied works.
They are not presented as additional texts read in full for this
documentation, and no unverified page-specific quotations are attributed
to them.

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

The first book of *Capital* develops the commodity, labour-power and surplus
value; the second studies circulation and reproduction; the third develops
profit and distribution. The *Capítulo VI* helps clarify the scope of
productive labour. Shaikh and Tonak connect Marxian categories to national
accounts, the distinction directly used in the supplied book's discussion
of productive labour.
