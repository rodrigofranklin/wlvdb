# Fichas das famílias de indicadores

<!-- documentation-revision: wiod-reader-workflows-v2 -->

Português | [English](indicator-families-en.md) | [Usar os dados](use-results-pt.md) | [Dicionário](results-dictionary-pt.md) | [Matemática](methodology-pt.md)

Estas fichas ajudam a escolher e interpretar uma medida. O dicionário contém
os identificadores exatos de cada método; `_unit_contract.csv` é a referência
para a unidade, a apresentação e a agregação de um run. Os exemplos numéricos
abaixo são **hipotéticos**, não resultados WIOD. As fórmulas resumem casos com
componentes definidos; zeros, ausências e cobertura parcial seguem os contratos.

## 1. Pessoas, horas e trabalho abstrato

**Pergunta.** Quantas pessoas participam da atividade, quantas horas realizam
e como essas horas entram na medida de trabalho do modelo?

`emp.s.un` conta pessoas ocupadas; `empe.s.un` restringe aos empregados.
`hours_worked.*.s.hr` registra horas anuais. O multiplicador de redução transforma
horas em trabalho abstrato operacional: $L_j=z_jH_j$. Nos dois métodos atuais,
$z_j=1$; a igualdade numérica não elimina a distinção conceitual. As variantes
`abstract_labour.*.m.mv` dividem o trabalho anual pela respectiva população.

**Exemplo.** Dez empregados com 18.000 horas anuais, sob peso 1, correspondem
a 1.800 horas abstratas por empregado por ano. Para agregar dois setores,
some horas e pessoas e só depois divida; não dê o mesmo peso a setores de
10 e 1.000 pessoas.

**O que não mede.** O indicador anual por pessoa não é duração da jornada diária.
O trabalho abstrato que inclui setores improdutivos não é o agregado de valor
novo produtivo. `emp` e `empe` não são populações intercambiáveis.

**Antes de usar.** Confira a aproximação entre empregados e ocupados na China,
as horas e efetivos imputados do ROW, a cobertura do denominador e o peso das
horas. Veja [trabalho e resto do mundo](assumptions-pt.md).

## 2. Produto bruto, valor novo e preços diretos

**Pergunta.** Quanto foi produzido, quanto trabalho é requerido ao longo das
cadeias produtivas e quanto trabalho produtivo novo ocorreu no ano?

`gross_output.s.us` mede produto bruto monetário; `gdp.s.us` mede valor adicionado
monetário. `value.m.mv` é o coeficiente $\lambda$ de trabalho produtivo direto e
indireto por USD. Multiplicar as entregas de cada fornecedor por seu coeficiente
produz a matriz `values`; a soma das vendas é `gross_output.s.mv`.
`gdp.s.mv` registra o trabalho direto das pessoas ocupadas nos setores produtivos.

**Exemplo.** Se a farinha requer 2 horas e a panificação acrescenta 1, o pão
requer 3 horas. Somar farinha e pão no produto bruto dá 5 horas, enquanto o pão
final requer 3 ao longo da cadeia. Produto bruto incorporado e valor novo são
objetos diferentes mesmo quando ambos estão expressos em horas.

Nos preços diretos, $\mu=\sum x/\sum V^{GO}$ converte magnitudes de valor em USD.
`gross_output.s.du` e `gdp.s.du` utilizam esse numerário comum. A normalização
conserva o total mundial do produto bruto monetário, não a igualdade entre cada
preço de mercado e seu preço direto nem entre os dois totais de PIB.

**O que não mede.** Preço direto não é preço observado, preço de produção,
câmbio, paridade de poder de compra ou deflator. Somar valores incorporados
em todos os produtos intermediários não mede somente o trabalho novo.

**Antes de usar.** Confira preços correntes/constantes, classificação produtiva,
unidades, agregação e cobertura das matrizes. A intensidade agregada é razão
dos totais de valor e produto, não média simples dos coeficientes. Veja a
[derivação e as duas normalizações](methodology-pt.md).

## 3. Valor de reprodução e taxas de mais-valia

**Pergunta.** Como o trabalho realizado se compara ao trabalho incorporado
na cesta financiada pela remuneração da população escolhida?

Para empregados, `labour_force_value.s.mv` estima $v$ a partir da remuneração
e da composição nacional de consumo; para todas as pessoas ocupadas, use
`labour_force_value.emp.s.mv`. As médias por pessoa dividem pelo efetivo correto.
A taxa é $e=L/v-1$, com ambos os componentes em unidades de trabalho.

| Indicador | População e recorte |
| --- | --- |
| `surplus_value.empe_p.r.pc` | Empregados de setores produtivos. |
| `surplus_value.empe.r.pc` | Empregados, incluindo setores improdutivos. |
| `surplus_value.emp_p.r.pc` | Pessoas ocupadas de setores produtivos, incluindo não assalariados. |
| `surplus_value.emp.r.pc` | Pessoas ocupadas, incluindo não assalariados e setores improdutivos. |
| `surplus_value.empe_hs.r.pc`, `surplus_value.empe_ms.r.pc`, `surplus_value.empe_ls.r.pc` | Variantes WIOD13 por qualificação; os códigos completos constam no dicionário. |

**Exemplo.** Dois setores com trabalho 100 e 300 e reprodução 50 e 100 têm
taxas de 100% e 200%. A taxa agregada é $400/150-1$, aproximadamente 166,67%,
não a média simples de 150%. No contrato, armazena-se a razão antes de exibir
porcentagem. Uma ausência no denominador não vira custo de reprodução zero.

**O que não mede.** A cesta financiada pela remuneração não é uma observação
independente de um mínimo normativo de subsistência. Uma taxa elevada não
estabelece, sozinha, superexploração, duração da jornada, produtividade física
ou taxa de lucro. A variante com ocupados não assalariados tem interpretação
mais ampla que uma medida exclusiva da relação salarial capitalista.

**Antes de usar.** Confira a hipótese de cesta nacional comum, a população,
o filtro produtivo e a cobertura de cada componente. Uma taxa setorial produtiva
zerada fora do recorte expressa uma máscara do modelo, não ausência de exploração
observada. Nas taxas por qualificação, as parcelas de horas e remuneração não
mudam o peso padrão das horas. Para `WWW`, examine particularmente ROW e as
[somas de componentes com coberturas diferentes](use-results-pt.md#comparar-razões-com-cobertura-comum).

## 4. Capital, depreciação e rentabilidade contábil

**Pergunta.** Qual é o estoque de capital estimado, quanto se deprecia no ano
e como a remuneração líquida do capital se relaciona com esse estoque?

`capital_stock.s.us` mede o estoque em USD correntes. `k_composition` distribui
o estoque por fornecedores de ativos e usuários; somar a coluna recupera o
estoque do usuário. `k_depreciation` distribui a depreciação anual;
`capital_depreciation.s.us` soma essa depreciação por usuário.

`appropriated_profit.r.pc` aplica $r^{app}=(\Pi-D)/K$, usando remuneração
monetária do capital, depreciação estimada e estoque de capital fixo.

**Exemplo.** Remuneração do capital de USD 30, depreciação de USD 10 e estoque
de USD 100 produzem uma razão de 0,20, apresentada como 20%. A agregação exige
somar os componentes pertinentes antes de dividir. Denominador zero não é
rentabilidade zero.

**O que não mede.** Estoque não é investimento anual, e depreciação não é o
estoque integral. A composição é estimada, não a história observada de cada
compra. A rentabilidade contábil não implementa a taxa marxiana $s/(c+v)$ e
não deve receber esse nome.

**Antes de usar.** Confira a composição KLEMS, o país médio, as substituições
de pesos, a convenção da taxa de depreciação do ano seguinte, as exceções com
sinais e a perda de cobertura WIOD13 em 2008–2009. Os componentes da taxa
contábil são agregados separadamente e também precisam de revisão de cobertura.
Veja [capital e regras excepcionais](assumptions-pt.md).

## 5. Cestas, índices, remuneração constante e câmbio

**Pergunta.** Como os preços e o conteúdo de trabalho de uma cesta de referência
variam no tempo, e como obter uma remuneração deflacionada sob essa convenção?

`basket_price.r.pc` e `basket_value.r.pc` são índices nacionais do preço e do
conteúdo de trabalho da cesta implementada. O ano dos pesos é 1995 na WIOD13
e 2000 na WIOD16; os índices publicados têm base 2000 = 1. Índice armazenado 1
é apresentado como 1 no WIOD13 e 100 pontos no WIOD16, segundo o contrato.
`compensation.*.s.cu` é remuneração em USD constantes de 2000, apesar de `.cu`.
`exchange.r.us` é moeda local por USD; `exchange.r.id` é seu índice de base 2000.

**Exemplo.** Um índice que passa de 1 para 1,2 aumenta 20% relativamente à base.
Dois países com índice 1 em 2000 não têm, por isso, o mesmo custo de vida.
Somar os índices nacionais não produz um índice mundial comparável.

**O que não mede.** Um índice temporal não é nível de preços internacional,
paridade de poder de compra nem valor nominal da cesta. A valorização de uma
moeda local perante o dólar não é o mesmo fenômeno que aumento de seu índice
de moeda local por USD. Remuneração deflacionada não é valor-trabalho.

**Antes de usar.** Na WIOD13, os pesos/preços de origem de 1995 e o índice
cambial de 2000 exigem a avaliação metodológica descrita no capítulo matemático.
Não interprete o índice implementado como reprodução física exata de uma cesta
fixa de 1995 já demonstrada. A mudança final de base não resolve sozinha essa questão.
A série de capital constante WIOD16 usa ainda um deflator aproximado próprio.
Veja [cestas e bases](methodology-pt.md) e preserve essa ressalva nas conclusões.

## 6. Comércio, transferências e apropriação

**Pergunta.** Quanto trabalho o comércio incorpora e qual é a transferência
estimada quando se compara esse conteúdo ao valor representado pelos pagamentos?

`exports.s.us` e `imports.s.us` medem fluxos monetários; as versões `.mv`, trabalho
incorporado. `trade_balance` é exportação menos importação. A transferência por
saída é $\tau_{ij}=T_{ij}(\beta M_{ij}-V_{ij})$, e o saldo do país é
$\Delta_c=\beta(X_c^{USD}-M_c^{USD})-(X_c^V-M_c^V)$. **Saldo nacional positivo
significa recebimento líquido**. O fator comercial $\beta$ não é, em geral,
o inverso do numerário $\mu$ dos preços diretos da produção.

**Exemplo.** Um país que exporta 100 horas e importa 150 pelo mesmo montante
monetário recebe 50 horas líquidas nesse exemplo. Havendo saldo monetário,
a diferença de horas sozinha não isola a transferência: a expressão acima
inclui a correção pelo saldo comercial.

`trade_transfers.p.s.mv` restringe os produtos fornecedores ao recorte produtivo;
`.u.s.mv` é total menos produtivo. `trade_transfers.p.m.pc` divide a transferência
produtiva por `gdp.s.mv`, não pelo PIB monetário. As matrizes bilaterais mantêm
origem × destino. As importações setoriais agrupam setor do produto importado
e país receptor, inclusive demanda final, não somente a atividade compradora.

**O que não mede.** O indicador não identifica sozinho a causa da transferência
nem todos os canais da dependência, como juros, dividendos e relações de
propriedade. A soma dos saldos nacionais, que se cancela contabilmente, não é
a soma das células de transferência de uma matriz bilateral. A soma das
células produtivas é normalizada a zero; a soma das células totais não tem a
mesma obrigação, pois inclui fornecedores improdutivos com valor modelado zero.

**Antes de usar.** Confira sinal, orientação, componente produtivo, denominador,
unidade e cobertura. Não some `WWW` aos países. Examine se rankings e
conclusões resistem às imputações de trabalho e capital. Veja a
[metodologia do comércio](methodology-pt.md) e os limites na [teoria](theory-pt.md).
