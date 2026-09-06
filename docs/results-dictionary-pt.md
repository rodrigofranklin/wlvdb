# Dicionário de resultados

<!-- documentation-revision: wiod-consolidation-v1 -->

[English](results-dictionary-en.md) | [Guia em português](guide-pt.md)

Este dicionário cobre todos os indicadores publicados por `wiodr13` (1995–2009) e `wiodr16` (2000–2014). As tabelas são geradas dos contratos v2 e das descrições econômicas revisadas. Cada linha se aplica a `sea_sectors` e `sea_countries`, salvo a ausência mundial indicada na coluna de agregação. Países e setores seguem os rótulos de cada run: as duas fontes não têm classificação nem cobertura geográfica idênticas.

As unidades são as armazenadas, após normalização: USD, pessoas e horas, nunca milhões ou milhares implícitos. USD significa dólar dos Estados Unidos. USD sem qualificador indica preços correntes. `×100` é aplicado uma única vez na apresentação, não no cálculo. Uma taxa armazenada como 0,25 aparece como 25%. As parcelas por qualificação permanecem razões (0,25) no contrato, apesar do sufixo `.pc`. Índice 1 aparece como 1 no WIOD13 e como 100 pontos no WIOD16, conforme display_multiplier.

`NA` significa ausência justificada, não zero. Consulte `_states.csv` para distinguir `source_missing` (ausente na fonte) de `not_applicable` (operação indefinida). Câmbio e índices nacionais não têm agregado mundial comparável. Denominadores e pesos nulos tornam as razões e médias correspondentes não aplicáveis. Componentes disponíveis podem produzir agregados com cobertura parcial registrada em `_anomalies.csv`: examine o relatório antes de comparar países. Não complete ausências com zero. No WIOD13, 2008–2009 têm perda de cobertura de capital: a preparação histórica converte ausências fixadas em zeros de compatibilidade, e o WLVPanel exclui esses anos de todas as séries. Arquivos do banco ainda podem conter valores finitos nesses anos.

A coluna de agregação apresenta setor → país / país → mundo. Nas médias ponderadas, o peso aparece entre parênteses. Nas fórmulas, a descrição explica numerador e denominador: taxas nacionais e mundiais são construídas a partir dos totais pertinentes, não da média das taxas setoriais. O contrato efetivo de cada run é `_unit_contract.csv`, que prevalece para arquivos históricos.

As hipóteses de trabalho produtivo, igualdade das horas, resto do mundo, China, capital, cestas e comércio estão no [guia](guide-pt.md#metodologia). Lucro apropriado não equivale à taxa marxiana de lucro, e transferências modeladas não identificam por si só uma relação causal. Mudanças v1 → v2 exigem comparar contratos, não simplesmente unir séries.

## wiodr13 — 58 indicadores

| Identificador | Significado econômico | Unidade armazenada | Apresentação | Agregação: país / mundo |
| --- | --- | --- | --- | --- |
| `emp.s.un` | Pessoas ocupadas, incluindo empregados e trabalhadores por conta própria. | pessoas | sem escala adicional | soma / soma |
| `empe.s.un` | Empregados assalariados. | pessoas | sem escala adicional | soma / soma |
| `hours_worked.emp.s.hr` | Horas anuais de todas as pessoas ocupadas. | horas | sem escala adicional | soma / soma |
| `hours_worked.empe.s.hr` | Horas anuais dos empregados. | horas | sem escala adicional | soma / soma |
| `compensation.empe_hs.r.pc` | Parcela da remuneração dos empregados destinada à alta qualificação. | razão | sem escala adicional | média ponderada (`compensation.empe.s.us`) / média ponderada (`compensation.empe.s.us`) |
| `compensation.empe_ms.r.pc` | Parcela da remuneração dos empregados destinada à média qualificação. | razão | sem escala adicional | média ponderada (`compensation.empe.s.us`) / média ponderada (`compensation.empe.s.us`) |
| `compensation.empe_ls.r.pc` | Parcela da remuneração dos empregados destinada à baixa qualificação. | razão | sem escala adicional | média ponderada (`compensation.empe.s.us`) / média ponderada (`compensation.empe.s.us`) |
| `hours_worked.empe_hs.r.pc` | Parcela das horas dos empregados de alta qualificação. | razão | sem escala adicional | média ponderada (`hours_worked.empe.s.hr`) / média ponderada (`hours_worked.empe.s.hr`) |
| `hours_worked.empe_ms.r.pc` | Parcela das horas dos empregados de média qualificação. | razão | sem escala adicional | média ponderada (`hours_worked.empe.s.hr`) / média ponderada (`hours_worked.empe.s.hr`) |
| `hours_worked.empe_ls.r.pc` | Parcela das horas dos empregados de baixa qualificação. | razão | sem escala adicional | média ponderada (`hours_worked.empe.s.hr`) / média ponderada (`hours_worked.empe.s.hr`) |
| `gross_output.s.us` | Produto bruto a preços de mercado (GO_USD), incluindo consumo intermediário: não é PIB. | USD | sem escala adicional | soma / soma |
| `gdp.s.us` | Valor adicionado (VA_USD), cuja soma é o PIB pela ótica da produção. | USD | sem escala adicional | soma / soma |
| `go_price.r.id` | Índice de preço do produto bruto de cada setor, rebaseado em 2000. | índice (2000 = 1) | sem escala adicional | média ponderada (`gross_output.s.us`) / NA |
| `exchange.r.us` | Unidades monetárias nacionais por dólar: valor adicionado nacional em moeda local dividido pelo total em USD. Igual em todos os setores do país. | moeda local/USD | sem escala adicional | valor nacional comum / NA |
| `compensation.empe.s.us` | Remuneração dos empregados (COMP), convertida pelo câmbio nacional. | USD | sem escala adicional | soma / soma |
| `compensation.emp.s.us` | Remuneração do trabalho de todas as pessoas ocupadas (LAB), incluindo renda imputada dos não assalariados. | USD | sem escala adicional | soma / soma |
| `capital_stock.s.us` | Estoque de ativos de capital a preços correntes. WIOD13 combina K_GFCF e GFCF_P, WIOD16 usa K, com as exceções documentadas. | USD | sem escala adicional | soma / soma |
| `profit.s.us` | Remuneração do capital (CAP), incluindo lucro e outras rendas do capital: não é uma observação direta de mais-valia. | USD | sem escala adicional | soma / soma |
| `exchange.r.id` | Câmbio nacional dividido pelo câmbio de 2000. Uma alta indica mais moeda local por USD. | índice (2000 = 1) | sem escala adicional | valor nacional comum / NA |
| `complex_labour_multiplier.empe.r.un` | Fator aplicado às horas dos empregados. Nos dois métodos atuais vale 1: uma hora recebe o mesmo peso. | multiplicador | sem escala adicional | média ponderada (`hours_worked.empe.s.hr`) / média ponderada (`hours_worked.empe.s.hr`) |
| `complex_labour_multiplier.emp.r.un` | Fator aplicado às horas de todas as pessoas ocupadas. Nos dois métodos atuais vale 1. | multiplicador | sem escala adicional | média ponderada (`hours_worked.emp.s.hr`) / média ponderada (`hours_worked.emp.s.hr`) |
| `gdp.p.s.us` | Valor adicionado em USD somente nos setores produtivos. Zero nos demais setores pelo filtro econômico. | USD | sem escala adicional | soma / soma |
| `abstract_labour.empe.s.mv` | Horas dos empregados multiplicadas pelo fator de trabalho complexo. Inclui setores produtivos e improdutivos. | horas abstratas | sem escala adicional | soma / soma |
| `abstract_labour.emp.s.mv` | Horas de todas as pessoas ocupadas multiplicadas pelo fator de trabalho complexo. | horas abstratas | sem escala adicional | soma / soma |
| `gdp.s.mv` | Trabalho abstrato de todas as pessoas ocupadas nos setores classificados como produtivos. Os demais setores recebem zero pelo filtro econômico. | horas abstratas | sem escala adicional | soma / soma |
| `basket_price.r.pc` | Índice nacional do preço da cesta fixa de consumo, rebaseado em 2000. Cesta de referência: 1995 em WIOD13, 2000 em WIOD16. | índice (2000 = 1) | sem escala adicional | valor nacional comum / NA |
| `basket_value.r.pc` | Índice nacional do trabalho incorporado na cesta fixa de consumo, rebaseado em 2000. | índice (2000 = 1) | sem escala adicional | valor nacional comum / NA |
| `gross_output.s.mv` | Trabalho produtivo total incorporado ao produto bruto, direto e indireto, pela soma das linhas da matriz values. | horas abstratas | sem escala adicional | soma / soma |
| `labour_force_value.s.mv` | Valor da cesta de consumo financiada pela remuneração dos empregados, usado como estimativa do capital variável. | horas abstratas | sem escala adicional | soma / soma |
| `value.m.mv` | Trabalho produtivo incorporado por USD de produto bruto: lambda no setor, razão dos totais nos agregados. | horas abstratas/USD | sem escala adicional | razão dos totais / razão dos totais |
| `capital_depreciation.s.us` | Depreciação anual do capital alocado, somada por coluna da matriz k_depreciation. | USD | sem escala adicional | soma / soma |
| `trade_transfers.s.mv` | Transferência líquida pelo comércio: valor representado pelos preços menos trabalho incorporado, exportações menos importações. Positivo indica recebimento líquido. | horas abstratas | sem escala adicional | soma / soma |
| `trade_transfers.p.s.mv` | Componente produtivo da transferência líquida pelo comércio. Sua soma mundial é zero dentro da tolerância. | horas abstratas | sem escala adicional | soma / soma |
| `exports.s.us` | Vendas a outros países, incluindo demanda final, avaliadas em preços de mercado. | USD | sem escala adicional | soma / soma |
| `exports.s.mv` | Trabalho produtivo incorporado às exportações. | horas abstratas | sem escala adicional | soma / soma |
| `imports.s.us` | Compras de outros países em preços de mercado. No dado setorial, agrupadas pelo setor do bem importado e país comprador. | USD | sem escala adicional | soma / soma |
| `imports.s.mv` | Trabalho produtivo incorporado às importações, no mesmo agrupamento das importações em USD. | horas abstratas | sem escala adicional | soma / soma |
| `labour_force_value.emp.s.mv` | Trabalho incorporado à cesta financiada pela remuneração de todas as pessoas ocupadas, incluindo não assalariados. | horas abstratas | sem escala adicional | soma / soma |
| `surplus_value.empe_hs.r.pc` | Trabalho abstrato dos empregados ponderado pela parcela de horas de alta qualificação, dividido pelo valor da força de trabalho ponderado pela parcela salarial correspondente, menos 1. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `surplus_value.empe_ms.r.pc` | Mesma fórmula da taxa por qualificação, usando as parcelas de média qualificação. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `surplus_value.empe_ls.r.pc` | Mesma fórmula da taxa por qualificação, usando as parcelas de baixa qualificação. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `compensation.emp.s.cu` | Remuneração de todas as pessoas ocupadas, deflacionada pelo índice da cesta e convertida pelo câmbio de 2000. O sufixo cu não significa moeda local neste resultado. | USD constantes de 2000 | sem escala adicional | soma / soma |
| `compensation.empe.s.cu` | Remuneração dos empregados deflacionada pelo índice da cesta e convertida pelo câmbio de 2000. | USD constantes de 2000 | sem escala adicional | soma / soma |
| `gdp.s.du` | PIB em horas produtivas convertido pelo fator mundial produto bruto em USD dividido pelo produto bruto em horas. Preço direto modelado. | USD | sem escala adicional | soma / soma |
| `gross_output.s.du` | Produto bruto em horas convertido pelo mesmo fator mundial USD por hora, preservando o total mundial em USD. | USD | sem escala adicional | soma / soma |
| `surplus_value.empe.r.pc` | Trabalho abstrato dos empregados dividido pelo valor da força de trabalho, menos 1. Inclui setores produtivos e improdutivos. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `labour_force_value.m.mv` | Valor da força de trabalho dividido pelo número de empregados: custo anual médio de reprodução em horas. | horas abstratas/pessoa | sem escala adicional | fórmula descrita / fórmula descrita |
| `trade_transfers.u.s.mv` | Transferência total menos o componente produtivo. É um saldo de exportações menos importações, distinto da soma das células da matriz bilateral. | horas abstratas | sem escala adicional | soma / soma |
| `abstract_labour.empe.m.mv` | Trabalho abstrato anual dos empregados dividido pelo número de empregados. Não é a duração de um dia de trabalho. | horas abstratas/pessoa | sem escala adicional | fórmula descrita / fórmula descrita |
| `abstract_labour.emp.m.mv` | Trabalho abstrato anual de todas as pessoas ocupadas dividido pelo seu número. | horas abstratas/pessoa | sem escala adicional | fórmula descrita / fórmula descrita |
| `trade_balance.s.us` | Exportações menos importações em USD. | USD | sem escala adicional | soma / soma |
| `trade_balance.s.mv` | Exportações menos importações em trabalho incorporado. | horas abstratas | sem escala adicional | soma / soma |
| `appropriated_profit.r.pc` | Remuneração do capital menos depreciação, dividida pelo estoque de capital. Aproximação contábil da rentabilidade, distinta de mais-valia dividida por capital constante mais variável. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `trade_transfers.p.m.pc` | Transferência produtiva pelo comércio dividida pelo trabalho abstrato produtivo (gdp.s.mv). Mede a transferência relativamente ao valor novo produzido. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `labour_force_value.emp.m.mv` | Valor da cesta de todas as pessoas ocupadas dividido pelo número de pessoas ocupadas. | horas abstratas/pessoa | sem escala adicional | fórmula descrita / fórmula descrita |
| `surplus_value.emp.r.pc` | Trabalho abstrato de todas as pessoas ocupadas dividido pelo valor de sua cesta, menos 1. Inclui não assalariados e setores improdutivos. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `surplus_value.emp_p.r.pc` | Taxa de todas as pessoas ocupadas, restrita aos setores produtivos. Agregados usam razão de totais, menos 1. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `surplus_value.empe_p.r.pc` | Taxa dos empregados, restrita aos setores produtivos. Agregados usam razão de totais, menos 1. | razão | ×100 % | fórmula descrita / fórmula descrita |

## wiodr16 — 50 indicadores

| Identificador | Significado econômico | Unidade armazenada | Apresentação | Agregação: país / mundo |
| --- | --- | --- | --- | --- |
| `emp.s.un` | Pessoas ocupadas, incluindo empregados e trabalhadores por conta própria. | pessoas | sem escala adicional | soma / soma |
| `empe.s.un` | Empregados assalariados. | pessoas | sem escala adicional | soma / soma |
| `hours_worked.empe.s.hr` | Horas anuais dos empregados. | horas | sem escala adicional | soma / soma |
| `gross_output.s.us` | Produto bruto a preços de mercado (GO_USD), incluindo consumo intermediário: não é PIB. | USD | sem escala adicional | soma / soma |
| `gdp.s.us` | Valor adicionado (VA_USD), cuja soma é o PIB pela ótica da produção. | USD | sem escala adicional | soma / soma |
| `hours_worked.emp.s.hr` | Horas anuais de todas as pessoas ocupadas. | horas | sem escala adicional | soma / soma |
| `exchange.r.us` | Unidades monetárias nacionais por dólar: valor adicionado nacional em moeda local dividido pelo total em USD. Igual em todos os setores do país. | moeda local/USD | sem escala adicional | valor nacional comum / NA |
| `go_price.r.id` | Índice de preço do produto bruto de cada setor, rebaseado em 2000. | índice (2000 = 1) | ×100 pontos | média ponderada (`gross_output.s.us`) / NA |
| `compensation.empe.s.us` | Remuneração dos empregados (COMP), convertida pelo câmbio nacional. | USD | sem escala adicional | soma / soma |
| `compensation.emp.s.us` | Remuneração do trabalho de todas as pessoas ocupadas (LAB), incluindo renda imputada dos não assalariados. | USD | sem escala adicional | soma / soma |
| `capital_stock.s.us` | Estoque de ativos de capital a preços correntes. WIOD13 combina K_GFCF e GFCF_P, WIOD16 usa K, com as exceções documentadas. | USD | sem escala adicional | soma / soma |
| `profit.s.us` | Remuneração do capital (CAP), incluindo lucro e outras rendas do capital: não é uma observação direta de mais-valia. | USD | sem escala adicional | soma / soma |
| `capital_stock.s.cu` | Estoque de capital em USD constantes de 2000, deflacionado pelo preço do produto e convertido pelo câmbio de 2000. | USD constantes de 2000 | sem escala adicional | soma / soma |
| `exchange.r.id` | Câmbio nacional dividido pelo câmbio de 2000. Uma alta indica mais moeda local por USD. | índice (2000 = 1) | ×100 pontos | valor nacional comum / NA |
| `complex_labour_multiplier.empe.r.un` | Fator aplicado às horas dos empregados. Nos dois métodos atuais vale 1: uma hora recebe o mesmo peso. | multiplicador | sem escala adicional | média ponderada (`hours_worked.empe.s.hr`) / média ponderada (`hours_worked.empe.s.hr`) |
| `complex_labour_multiplier.emp.r.un` | Fator aplicado às horas de todas as pessoas ocupadas. Nos dois métodos atuais vale 1. | multiplicador | sem escala adicional | média ponderada (`hours_worked.emp.s.hr`) / média ponderada (`hours_worked.emp.s.hr`) |
| `gdp.p.s.us` | Valor adicionado em USD somente nos setores produtivos. Zero nos demais setores pelo filtro econômico. | USD | sem escala adicional | soma / soma |
| `abstract_labour.empe.s.mv` | Horas dos empregados multiplicadas pelo fator de trabalho complexo. Inclui setores produtivos e improdutivos. | horas abstratas | sem escala adicional | soma / soma |
| `abstract_labour.emp.s.mv` | Horas de todas as pessoas ocupadas multiplicadas pelo fator de trabalho complexo. | horas abstratas | sem escala adicional | soma / soma |
| `gdp.s.mv` | Trabalho abstrato de todas as pessoas ocupadas nos setores classificados como produtivos. Os demais setores recebem zero pelo filtro econômico. | horas abstratas | sem escala adicional | soma / soma |
| `basket_price.r.pc` | Índice nacional do preço da cesta fixa de consumo, rebaseado em 2000. Cesta de referência: 1995 em WIOD13, 2000 em WIOD16. | índice (2000 = 1) | ×100 pontos | valor nacional comum / NA |
| `basket_value.r.pc` | Índice nacional do trabalho incorporado na cesta fixa de consumo, rebaseado em 2000. | índice (2000 = 1) | ×100 pontos | valor nacional comum / NA |
| `gross_output.s.mv` | Trabalho produtivo total incorporado ao produto bruto, direto e indireto, pela soma das linhas da matriz values. | horas abstratas | sem escala adicional | soma / soma |
| `labour_force_value.s.mv` | Valor da cesta de consumo financiada pela remuneração dos empregados, usado como estimativa do capital variável. | horas abstratas | sem escala adicional | soma / soma |
| `value.m.mv` | Trabalho produtivo incorporado por USD de produto bruto: lambda no setor, razão dos totais nos agregados. | horas abstratas/USD | sem escala adicional | razão dos totais / razão dos totais |
| `capital_depreciation.s.us` | Depreciação anual do capital alocado, somada por coluna da matriz k_depreciation. | USD | sem escala adicional | soma / soma |
| `trade_transfers.s.mv` | Transferência líquida pelo comércio: valor representado pelos preços menos trabalho incorporado, exportações menos importações. Positivo indica recebimento líquido. | horas abstratas | sem escala adicional | soma / soma |
| `trade_transfers.p.s.mv` | Componente produtivo da transferência líquida pelo comércio. Sua soma mundial é zero dentro da tolerância. | horas abstratas | sem escala adicional | soma / soma |
| `exports.s.us` | Vendas a outros países, incluindo demanda final, avaliadas em preços de mercado. | USD | sem escala adicional | soma / soma |
| `exports.s.mv` | Trabalho produtivo incorporado às exportações. | horas abstratas | sem escala adicional | soma / soma |
| `imports.s.us` | Compras de outros países em preços de mercado. No dado setorial, agrupadas pelo setor do bem importado e país comprador. | USD | sem escala adicional | soma / soma |
| `imports.s.mv` | Trabalho produtivo incorporado às importações, no mesmo agrupamento das importações em USD. | horas abstratas | sem escala adicional | soma / soma |
| `labour_force_value.emp.s.mv` | Trabalho incorporado à cesta financiada pela remuneração de todas as pessoas ocupadas, incluindo não assalariados. | horas abstratas | sem escala adicional | soma / soma |
| `compensation.emp.s.cu` | Remuneração de todas as pessoas ocupadas, deflacionada pelo índice da cesta e convertida pelo câmbio de 2000. O sufixo cu não significa moeda local neste resultado. | USD constantes de 2000 | sem escala adicional | soma / soma |
| `compensation.empe.s.cu` | Remuneração dos empregados deflacionada pelo índice da cesta e convertida pelo câmbio de 2000. | USD constantes de 2000 | sem escala adicional | soma / soma |
| `gdp.s.du` | PIB em horas produtivas convertido pelo fator mundial produto bruto em USD dividido pelo produto bruto em horas. Preço direto modelado. | USD | sem escala adicional | soma / soma |
| `gross_output.s.du` | Produto bruto em horas convertido pelo mesmo fator mundial USD por hora, preservando o total mundial em USD. | USD | sem escala adicional | soma / soma |
| `surplus_value.empe.r.pc` | Trabalho abstrato dos empregados dividido pelo valor da força de trabalho, menos 1. Inclui setores produtivos e improdutivos. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `labour_force_value.m.mv` | Valor da força de trabalho dividido pelo número de empregados: custo anual médio de reprodução em horas. | horas abstratas/pessoa | sem escala adicional | fórmula descrita / fórmula descrita |
| `trade_transfers.u.s.mv` | Transferência total menos o componente produtivo. É um saldo de exportações menos importações, distinto da soma das células da matriz bilateral. | horas abstratas | sem escala adicional | soma / soma |
| `abstract_labour.empe.m.mv` | Trabalho abstrato anual dos empregados dividido pelo número de empregados. Não é a duração de um dia de trabalho. | horas abstratas/pessoa | sem escala adicional | fórmula descrita / fórmula descrita |
| `abstract_labour.emp.m.mv` | Trabalho abstrato anual de todas as pessoas ocupadas dividido pelo seu número. | horas abstratas/pessoa | sem escala adicional | fórmula descrita / fórmula descrita |
| `trade_balance.s.us` | Exportações menos importações em USD. | USD | sem escala adicional | soma / soma |
| `trade_balance.s.mv` | Exportações menos importações em trabalho incorporado. | horas abstratas | sem escala adicional | soma / soma |
| `appropriated_profit.r.pc` | Remuneração do capital menos depreciação, dividida pelo estoque de capital. Aproximação contábil da rentabilidade, distinta de mais-valia dividida por capital constante mais variável. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `trade_transfers.p.m.pc` | Transferência produtiva pelo comércio dividida pelo trabalho abstrato produtivo (gdp.s.mv). Mede a transferência relativamente ao valor novo produzido. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `labour_force_value.emp.m.mv` | Valor da cesta de todas as pessoas ocupadas dividido pelo número de pessoas ocupadas. | horas abstratas/pessoa | sem escala adicional | fórmula descrita / fórmula descrita |
| `surplus_value.emp.r.pc` | Trabalho abstrato de todas as pessoas ocupadas dividido pelo valor de sua cesta, menos 1. Inclui não assalariados e setores improdutivos. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `surplus_value.emp_p.r.pc` | Taxa de todas as pessoas ocupadas, restrita aos setores produtivos. Agregados usam razão de totais, menos 1. | razão | ×100 % | fórmula descrita / fórmula descrita |
| `surplus_value.empe_p.r.pc` | Taxa dos empregados, restrita aos setores produtivos. Agregados usam razão de totais, menos 1. | razão | ×100 % | fórmula descrita / fórmula descrita |

Gerado por `scripts/render_results_dictionary.R`. Edite as descrições e os contratos de origem, regenere os dois idiomas e execute `--check`. Consulte a [convenção de sincronização](documentation-sync.md).
