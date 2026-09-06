# Metodologia matemática

<!-- documentation-revision: wiod-reader-workflows-v2 -->

[English](methodology-en.md) · [Teoria](theory-pt.md) · [Hipóteses e trabalho pendente](assumptions-pt.md) · [Guia prático](guide-pt.md) · [Referências em ABNT](references-pt.md)

Revisão documental: `wiod-reader-workflows-v2`.

Este capítulo acompanha os **métodos atualmente executáveis `wiodr13` e `wiodr16`**. Ele traduz o cálculo nativo em equações e em um pequeno exemplo. O artigo de Franklin et al. (2022, p. 370–375) explica a estrutura comum de insumo-produto e compara diferentes reduções do trabalho complexo; Franklin (2025, p. 190–200) desenvolve a aplicação internacional. As alternativas de pesquisa desses textos não são todas métodos executáveis nesta versão. Em particular, os métodos padrão utilizam multiplicadores de horas de trabalho iguais a um e cestas nacionais de consumo. Consulte a situação de suporte no [catálogo de métodos](methods.md).

| Diferença entre fonte e código | Consequência para a reprodução |
| --- | --- |
| Franklin et al. (2022, nota 21, p. 386–387) excluem hotéis/restaurantes e outros serviços comunitários/sociais/pessoais; a [classificação atual da WIOD13](../methods/wiodr13/_sectors.csv) inclui `H` e `O` como produtivos | A WIOD13 atual possui 25 atividades produtivas por região (1.025 posições), em vez das 23 do artigo (943 posições). Reproduzir exatamente as tabelas numéricas do artigo exige sua classificação histórica e as demais hipóteses. |
| As equações empíricas simplificadas do livro omitem a depreciação, enquanto o cálculo atual a inclui | A equação simplificada não deve ser copiada como descrição completa do cálculo atual. |
| O artigo compara várias reduções do trabalho; os métodos estáveis atuais fixam ambos os multiplicadores em 1 | A coincidência com sua hipótese de horas iguais não estabelece equivalência integral ao método histórico. |

## 1. Leia a tabela antes de ler a equação

Em cada ano, uma unidade produtiva é um **par país–setor**. A siderurgia brasileira e a siderurgia alemã ocupam linhas diferentes. A tabela mundial registra relações de produção domésticas e internacionais. As linhas fornecem bens ou serviços; as colunas os utilizam. Depois das colunas das atividades aparecem as colunas de demanda final.

| Símbolo | Significado | Unidade / formato |
| --- | --- | --- |
| $M_{ij}$ | Venda monetária do fornecedor $i$ à atividade ou ao destino de demanda final $j$ | USD correntes; tabela completa de fornecimento e uso no ano |
| $Z$ | Bloco de consumo intermediário entre atividades de $M$ | USD correntes; $n\times n$ |
| $x_j$ | Produção bruta da atividade $j$ | USD correntes |
| $H_j$, $H_j^e$ | Horas anuais de todas as pessoas ocupadas ou somente dos empregados | Horas |
| $z_j$, $z_j^e$ | Multiplicadores de complexidade/intensidade do trabalho | Sem unidade; ambos são 1 nos métodos padrão |
| $P$ | Conjunto das atividades classificadas como produtivas | Classificação, não uma observação monetária |
| $k_j$, $K_{ij}$ | Estoque de capital do usuário $j$; estoque atribuído à atividade fornecedora $i$ | USD correntes; vetor e matriz $n\times n$ |
| $D_{ij}$ | Depreciação anual desse estoque distribuído | USD correntes ao longo do ano contábil |
| $\lambda_j$ | Trabalho produtivo direto e indireto incorporado por USD de produção | Unidades de magnitude de valor por USD; `.mv/USD` |
| $b_{ic}$ | Participação do fornecedor $i$ na cesta de consumo do país $c$ | Sem unidade |
| $W_j$, $v_j$ | Remuneração monetária dos empregados; equivalente de sua cesta em valor-trabalho | USD correntes; unidades de magnitude de valor |

Aqui **$D$ é uma matriz de fluxos de depreciação**, correspondente a `k_depreciation`. O artigo utiliza $D$ para os *coeficientes* de depreciação. Abaixo, $d=D\operatorname{diag}(x)^{-1}$ representa esses coeficientes. Essa distinção evita somar um estoque ou um fluxo não normalizado a uma matriz de coeficientes.

A geração da fonte é normalizada antes do cálculo: moeda em unidades monetárias, trabalho em horas e emprego em pessoas, em vez dos milhões/milhares utilizados pelo provedor. Uma unidade `.mv` armazenada tem a escala numérica de uma hora sob $z=1$, mas seu significado teórico depende da classificação produtiva e da hipótese de redução. Os [contratos de unidades](units.md), incluindo `_normalization_contract.csv` e `_unit_contract.csv`, são a referência autorizada. O sistema completo de atividades da WIOD13 tem 1.435 pares; o da WIOD16 tem 2.464. A solução utiliza seu subconjunto produtivo.

A WIOD13 fornece as horas totais das pessoas ocupadas. A WIOD16 normalmente as calcula como `H_EMPE / EMPE * EMP`, supondo a mesma jornada anual média para empregados e demais ocupados de um setor. China, resto do mundo e casos de denominador zero registrados de forma exata exigem os tratamentos adicionais descritos nas [hipóteses](assumptions-pt.md).

## 2. Dos fluxos monetários observados ao trabalho total requerido

Primeiro, calcule os coeficientes de insumo **dividindo cada coluna pela produção de seu usuário**:

$$
A_{ij}=\frac{Z_{ij}}{x_j},\qquad d_{ij}=\frac{D_{ij}}{x_j},\qquad C=A+d.
$$

Assim, $A_{ij}=0.2$ significa que USD 1 de produção na atividade $j$ utiliza USD 0,20 de produção intermediária de $i$. Não significa 0,2 tonelada física. No bloco produtivo, os requisitos diretos de trabalho são

$$
\ell_j=\frac{H_jz_j}{x_j},\quad j\in P.
$$

Uma unidade de produção incorpora seu trabalho direto e o trabalho necessário para reproduzir seus insumos. Escrevendo os requisitos de trabalho como vetor-linha,

$$
\lambda_P=\ell_P+\lambda_PC_{PP},\qquad
\lambda_P=\ell_P(I-C_{PP})^{-1}.
$$

A implementação resolve o sistema equivalente em vetores-coluna

$$
(I-C_{PP})^\mathsf T\lambda_P^\mathsf T=\ell_P^\mathsf T
$$

sem construir explicitamente uma inversa. As atividades fora de $P$ recebem $\lambda_j=0$ neste método. Isso exclui suas linhas e colunas do sistema produtor de valor; apenas zerar suas horas diretas e manter a matriz completa seria outro modelo.

Para $C_{PP}$ não negativa, com raio espectral $\rho(C_{PP})<1$,

$$
\lambda_P=\ell_P+\ell_PC_{PP}+\ell_PC_{PP}^2+\cdots.
$$

Essas parcelas representam o trabalho direto, o trabalho nos insumos imediatos, o trabalho nos insumos desses insumos, e assim sucessivamente. Cada termo adicional contabiliza outra rodada de produção. É por isso que a inversa tem significado econômico sob suas hipóteses, além de ser uma operação matricial conveniente.

Utilizar contas monetárias não exige supor que os preços observados já sejam iguais aos valores-trabalho. No caso ideal de uma tabela física coerente, sejam $Q$ as entregas físicas, $q$ a produção física e $p_i>0$ o preço por unidade física do produto $i$. Então $Z=\operatorname{diag}(p)Q$, $x=\operatorname{diag}(p)q$, e os coeficientes monetários correspondem a uma mudança de unidades dos coeficientes físicos. O coeficiente de trabalho correspondente é o valor-trabalho físico dividido por $p_i$. Os agregados reais de país–atividade aproximam esse caso: diferenças de composição dos produtos, valoração e agregação continuam sendo limitações empíricas. A álgebra matricial não as elimina.

Explicitamente, escreva $S=\operatorname{diag}(p)$, com sobrescritos $m$ e $q$ para unidades monetárias e físicas. Para insumos e depreciação valorados na mesma base coerente,

$$
C^m=SC^qS^{-1},\qquad \ell^m=\ell^qS^{-1},
$$

$$
\lambda^m=\ell^qS^{-1}(I-SC^qS^{-1})^{-1}
=\ell^q(I-C^q)^{-1}S^{-1}=\lambda^qS^{-1}.
$$

Consequentemente, $\lambda_i^mM_{ij}=(\lambda_i^q/p_i)(p_iQ_{ij})=\lambda_i^qQ_{ij}$ para uma entrega valorada de forma consistente. O preço se cancela como conversão de unidade. Esse resultado condicional explica por que dados monetários podem ser utilizados; não demonstra que toda tabela empírica agregada ou imputada satisfaça essas condições.

Implementação: [`matrix_modules.R`](../scripts/modules/native/matrix_modules.R), `wlv_matrix_transformation_spec()`; verificações numéricas: [`leontief_diagnostics.R`](../scripts/lib/leontief_diagnostics.R). O sistema verifica resíduos, condicionamento e um certificado de produtividade/convergência. O caso com sinais negativos explicitamente admitido para 2006 na WIOD13 utiliza um **certificado de convergência absoluta**, e não uma afirmação de produtividade não negativa. As exceções exatas de insumo não nulo com produção zero são validadas antes de sua substituição protegida; consulte [WIOD13](wiodr13.md) e [validação científica](scientific-validation.md).

## 3. Reconstrua a composição do capital e a depreciação

As fontes fornecem o estoque total de capital de um setor de forma mais direta que a origem dos ativos que o compõem. O método combina esse estoque conhecido com a composição por ativos da EU KLEMS e a formação bruta de capital fixo (FBCF) da WIOT.

Para colunas ordinárias, sem exceções, a distribuição pode ser resumida como

$$
\omega_{ij,t}=G_{i,c(j),t}\,u_{a(i),g(j),r(j),t}\,s_{j,t},\qquad
K_{ij,t}=k_{j,t}\frac{\omega_{ij,t}}{\sum_i\omega_{ij,t}},
$$

$$
D_{ij,t}=K_{ij,t}\,\delta_{a(i),g(j),r(j),t+1}.
$$

Aqui, $G$ é a FBCF por atividade fornecedora e país investidor; $a(i)$ associa o fornecedor a uma classe de ativo; $g(j)$ associa o usuário aos grupos setoriais da EU KLEMS; $r(j)$ é o país observado ou utilizado como aproximação na EU KLEMS; $u$ é seu peso por ativo; e $s_j=VA_j/VA_{g(j),c(j)}$ é a participação de desagregação da WIOD. Um escalar comum não nulo $s_j$ se cancela na normalização da coluna; participações nulas ou anômalas continuam relevantes para as regras de distribuição. A identidade a preservar é $\sum_iK_{ij}=k_j$.

Trata-se de uma **composição estimada de um estoque observado/estimado**, não da observação de cada compra histórica de ativos. Os padrões de investimento corrente ajudam a distribuir o estoque existente. A EU KLEMS fornece hipóteses de depreciação; os dois métodos padrão aplicam a **taxa do ano seguinte** ao estoque distribuído do ano corrente. Países sem cobertura de composição utilizam o perfil sintético preparado `MD`. Um estoque positivo sem pesos primários utilizáveis só pode utilizar a distribuição nacional de FBCF conforme a alternativa registrada para sua fonte.

A WIOD13 converte seu estoque a preços constantes por `K_GFCF * GFCF_P / exchange.r.us`; a WIOD16 utiliza `K / exchange.r.us`, com `K` corrente. A taxa de câmbio implícita por país e ano é

$$
e_{ct}=\frac{\sum_{j\in c}VA^{LCU}_{jt}}{\sum_{j\in c}VA^{USD}_{jt}},
$$

em unidades de moeda local por USD. Dividir a remuneração ou o estoque em moeda local por $e_{ct}$ resulta em USD correntes.

FBCF negativa, pesos nulos, estoques negativos e exceções com sinais possuem **políticas diferentes e exatas em cada fonte**. Elas não podem ser substituídas por uma regra geral de “transformar todos os negativos ou ausentes em zero”. O [registro de hipóteses](assumptions-pt.md), [WIOD13](wiodr13.md) e [WIOD16](wiodr16.md) detalham abrangência e diagnósticos. Código nativo: [`capital_matrix_modules.R`](../scripts/modules/native/capital_matrix_modules.R), [`indicator_source_derived_modules.R`](../scripts/modules/native/indicator_source_derived_modules.R) e [`native_euklems.R`](../scripts/preparation/native_euklems.R).

## 4. Transforme a produção e escolha uma escala monetária

Depois de resolver $\lambda$, as vendas monetárias de cada fornecedor são convertidas por seu próprio coeficiente:

$$
V_{ij}=\lambda_iM_{ij}.
$$

A soma dos destinos produz `gross_output.s.mv`. Esse total inclui trabalho intermediário incorporado e não deve ser interpretado apenas como trabalho novo. O valor novo é representado por

$$
N_j=\mathbf 1(j\in P)H_jz_j,
$$

publicado como `gdp.s.mv`. Seu nome designa uma medida do produto novo em valor; não se trata do PIB monetário convencional expresso em outra moeda.

Para os indicadores de produção a **preços diretos**, a implementação escolhe uma escala anual

$$
\mu_t=\frac{\sum_jx_{jt}}{\sum_jV^{GO}_{jt}}\quad[USD/\text{labour value}].
$$

Ela publica `gross_output.s.du` = $\mu V^{GO}$ e `gdp.s.du` = $\mu N$. Isso fixa o numerário de modo que a produção bruta mundial a preços diretos some a produção bruta monetária mundial. Não obriga o preço direto de cada atividade a coincidir com seu preço de mercado, nem obriga o PIB total a preços diretos a coincidir com o PIB monetário. Essa escala não é taxa de câmbio nem deflator temporal.

Código nativo: [`indicator_common_modules.R`](../scripts/modules/native/indicator_common_modules.R), `wlv_native_direct_price_spec()`.

## 5. Dos salários ao valor de reprodução e às taxas de mais-valia

A cesta nacional utiliza a primeira categoria de consumo final declarada nos rótulos da fonte. Para o país de destino $c$,

$$
b_{ic}=\frac{F_{ic}}{\sum_iF_{ic}},\qquad \sum_i b_{ic}=1.
$$

A dimensão dos fornecedores inclui as importações. Todas as atividades de um país recebem a mesma composição, enquanto seu nível de remuneração pode variar. O método considera que a remuneração adquire essa cesta:

$$
v_j=W_j\sum_i\lambda_ib_{i,c(j)}.
$$

`labour_force_value.s.mv` utiliza a remuneração dos empregados (`COMP`, convertida em USD); `labour_force_value.emp.s.mv` utiliza a remuneração de todas as pessoas ocupadas (`LAB`, incluindo a renda do trabalho atribuída aos não empregados). Seus indicadores por pessoa dividem pelos números de empregados e de pessoas ocupadas, respectivamente. São estimativas a partir de **participações médias de consumo e remuneração**, não observações domiciliares sobre poupança, impostos, transferências ou necessidades individuais de consumo dos trabalhadores.

Para empregados, seja $L_j^e=H_j^ez_j^e$. A taxa de mais-valia publicada é

$$
e_j^e=\frac{L_j^e-v_j}{v_j}=\frac{L_j^e}{v_j}-1.
$$

A variante para pessoas ocupadas substitui esses termos por $H_jz_j$ e pela cesta da remuneração mais ampla do trabalho. As séries sem restrição incluem atividades classificadas como improdutivas. As variantes `_p` restringem **o numerador e o denominador** do agregado às atividades produtivas:

$$
e_c^{e,P}=\frac{\sum_{j\in c\cap P}L_j^e}{\sum_{j\in c\cap P}v_j}-1.
$$

Portanto, uma taxa sem restrição em uma atividade improdutiva não deve ser lida como afirmação de que ela cria valor novo no sistema de Leontief. Fora do recorte produtivo, a variante *setorial* produtiva multiplica a taxa de origem por zero; uma ausência semântica ainda pode permanecer ausente. As variantes nacionais e mundiais recalculam razões de totais.

A WIOD13 também publica taxas por grupo de qualificação. Se $h_{jq}$ é a participação do grupo $q$ nas horas dos empregados e $a_{jq}$ sua participação na remuneração, a fórmula é $e_{jq}=L_j^eh_{jq}/(v_ja_{jq})-1$. As categorias de alta, média e baixa qualificação não alteram o multiplicador padrão $z=1$; suas taxas refletem as participações observadas de horas/remuneração sob a hipótese de cesta nacional comum. As taxas nacionais e mundiais utilizam novamente as somas dos numeradores e denominadores.

O indicador de lucro é uma aproximação contábil monetária separada:

$$
r_j^{app}=\frac{\Pi_j-\sum_iD_{ij}}{k_j},\qquad
\Pi_j=CAP_j/e_{c(j)}.
$$

Ele é publicado como `appropriated_profit.r.pc`. **Não** implementa a taxa marxiana $s/(c+v)$: o numerador é a remuneração monetária do capital líquida da depreciação estimada, e o denominador é um estoque de capital fixo. Um denominador zero normalmente produz o estado semântico `not_applicable`, não uma taxa zero. As taxas são armazenadas como razões: 0,25 é apresentado como 25% quando o multiplicador do contrato de unidades é 100.

Código nativo: [`matrix_modules.R`](../scripts/modules/native/matrix_modules.R) para cestas; [`indicator_common_modules.R`](../scripts/modules/native/indicator_common_modules.R) para valor de reprodução, taxas de mais-valia e lucro; [`indicator_source_derived_modules.R`](../scripts/modules/native/indicator_source_derived_modules.R) para conversões das fontes monetárias.

## 6. Meça transferências pelo comércio internacional

Seja $T_{ij}=1$ quando fornecedor e destino estão em países diferentes, e 0 nos demais casos. O comércio produtivo exige também $i\in P$. A normalização anual do comércio é

$$
\beta_t=\frac{\sum_{ij}T_{ij}V_{ij}}{\sum_{ij}T_{ij}\mathbf1(i\in P)M_{ij}}
\quad[\text{labour value}/USD].
$$

Esse é o `balance_factor` do código. Ele utiliza o comércio internacional e, em geral, **não é** $1/\mu_t$, que utiliza a produção total. A transferência atribuída a um fluxo de saída é

$$
\tau_{ij}=T_{ij}(\beta M_{ij}-V_{ij}).
$$

Para esse vendedor, um número positivo significa que sua receita monetária representa mais valor-trabalho do que ele entrega. Para um país, a apropriação líquida corresponde às transferências nas saídas menos as transferências nas entradas:

$$
\Delta_c=\sum_{i\in c,j}\tau_{ij}-\sum_{i,j\in c}\tau_{ij}
=\beta(X_c^{USD}-M_c^{USD})-(X_c^{V}-M_c^{V}).
$$

Aqui, $X_c$ e $M_c$ representam os totais de exportação e importação. A última expressão explicita a **correção pelo saldo comercial**. Apenas subtrair o trabalho incorporado nas exportações daquele incorporado nas importações misturaria a troca desigual com empréstimos/endividamento ou outras formas de financiamento de uma conta comercial monetária desequilibrada. O cálculo padrão não reequilibra fisicamente o comércio de cada país; ele compara os dois saldos na mesma unidade de valor-trabalho utilizando a normalização comum.

Em um mundo completo, com cobertura consistente, os saldos nacionais líquidos se cancelam porque cada fluxo de saída de um país é uma entrada em outro. Essa identidade contábil é distinta da normalização: a soma dos **fluxos de transferência produtivos** é zero pela definição de $\beta$, enquanto a soma de todos os fluxos de transferência não precisa ser zero porque os fornecedores improdutivos têm $\lambda=0$. `trade_transfers.p.s.mv` restringe as atividades fornecedoras a $P$; `trade_transfers.u.s.mv` corresponde ao total menos as transferências produtivas. `trade_transfers.p.m.pc` divide as transferências produtivas líquidas por `gdp.s.mv`.

As matrizes de países mantêm **origem × destino**. `transfers_dp` e `transfers_productive_dp` dividem as transferências bilaterais por $\beta$ para expressar seu equivalente monetário. Os indicadores *setoriais* de importação agrupam pelo setor do produto fornecido e pelo país receptor, incluindo a demanda final; eles não identificam apenas a atividade compradora.

Código nativo: [`matrix_modules.R`](../scripts/modules/native/matrix_modules.R), [`reduced_matrix_modules.R`](../scripts/modules/native/reduced_matrix_modules.R), [`indicator_common_modules.R`](../scripts/modules/native/indicator_common_modules.R). A validação da fonte e das ausências é essencial: várias somas utilizam as células disponíveis, e um cancelamento aritmético não demonstra cobertura completa.

## 7. Compare uma cesta fixa ao longo do tempo

O cálculo dos índices de cesta fixa congela as participações $b^0$ e os coeficientes de trabalho iniciais $\lambda^0$ em **1995 para WIOD13** e **2000 para WIOD16**. Seja $p_{it}$ o índice de preços da produção bruta baseado na fonte e $E_{it}=e_{c(i),t}/e_{c(i),2000}$ o índice cambial do país fornecedor. Antes da mudança final de base, as fórmulas são

$$
P_{ct}^{raw}=\sum_i b^0_{ic}p_{it},\qquad
B_{ct}^{raw}=\frac{\sum_i b^0_{ic}(p_{it}/E_{it})\lambda_{it}}
{\sum_i b^0_{ic}\lambda_i^0}.
$$

Cada trajetória resultante é então dividida por sua própria observação de 2000. **Ano dos pesos, base do índice de preços da fonte e base do índice publicado são conceitos diferentes.** A fórmula da cesta da WIOD13 precisa dos níveis originais de `GO_P` com 1995 = 1, e não dos índices setoriais publicados já rebaseados. Os dois métodos armazenam os índices públicos resultantes com 2000 = 1; a apresentação segue os metadados de unidades de cada método. As cestas nacionais utilizam uma estrutura monetária nacional, portanto esses índices não são somados entre países para produzir um índice mundial. Consulte [`indicator_source_derived_modules.R`](../scripts/modules/native/indicator_source_derived_modules.R) e [a correção de recálculo da WIOD13](validation/issue-28.md).

Essa descrição corresponde ao **índice com participações congeladas implementado**, não a uma demonstração de reprodução física exata de uma cesta de 1995. Na WIOD13, a base dos preços/pesos e a base do índice cambial diferem. Diferenças dessas bases entre origens podem afetar os pesos das importações; rebasear o agregado final não elimina, por si só, essa questão. Avaliar a compatibilidade das bases e comparar com uma construção de cesta física inteiramente consistente permanece como trabalho metodológico.

A remuneração constante corresponde a `COMP` ou `LAB` em moeda local corrente dividida pelo índice de preços da cesta rebaseado e pela **taxa de câmbio de 2000**. Apesar de seu sufixo histórico `.cu`, ela é armazenada em USD constantes de 2000. A série de capital constante da WIOD16 utiliza, por sua vez, o índice de preços da produção bruta como aproximação do deflator do capital e o câmbio do ano-base; sua série do resto do mundo é reconstruída depois da imputação do estoque corrente. Nenhuma dessas operações corresponde à conversão de moeda em valor-trabalho.

## 8. Um exemplo de dois setores que você pode reproduzir

Considere duas atividades produtivas, com todo o trabalho tratado como trabalho de empregados e uma cesta comum com participações monetárias iguais de cada atividade. Todos os números abaixo são ilustrativos, não observações da WIOD.

$$
x=\begin{pmatrix}100\\200\end{pmatrix},\quad
Z=\begin{pmatrix}15&10\\15&50\end{pmatrix},\quad
K=\begin{pmatrix}50&100\\50&100\end{pmatrix},\quad
D=0.1K=\begin{pmatrix}5&10\\5&10\end{pmatrix}.
$$

As horas anuais são $H=(40,40)$; a remuneração é $W=(27,54)$. Dividir as colunas resulta em

$$
C=\begin{pmatrix}0.2&0.1\\0.2&0.3\end{pmatrix},\quad
\ell=(0.4,0.2),\quad
\lambda=(16/27,10/27).
$$

Por exemplo, a primeira igualdade é $16/27=0.4+0.2(16/27)+0.2(10/27)$. Ela inclui o trabalho direto da primeira atividade e o trabalho indireto nos dois insumos.

| Resultado | Setor 1 | Setor 2 | Conjunto |
| --- | ---: | ---: | ---: |
| Produção bruta em valor-trabalho | $1600/27$ | $2000/27$ | $400/3$ |
| Valor-trabalho novo | 40 | 40 | 80 |
| Valor de reprodução $v$ | 13 | 26 | 39 |
| Mais-valia $H-v$ | 27 | 14 | 41 |
| Taxa de mais-valia | $27/13$ | $7/13$ | $41/39$ |

A cesta contém $(\lambda_1+\lambda_2)/2=13/27$ unidade de magnitude de valor por USD. Isso converte USD 27 e USD 54 de remuneração em 13 e 26 unidades. A taxa de mais-valia do conjunto é $80/39-1=41/39$, aproximadamente 105,13%; a média aritmética das taxas setoriais produziria 130,77% e responderia a outra pergunta. O numerário da produção é $300/(400/3)=9/4$ USD por unidade de magnitude de valor.

Em uma ilustração separada da fórmula do comércio com esses mesmos coeficientes de trabalho, suponha que o país A exporte USD 20 do produto 1 para B, e B exporte USD 10 do produto 2 para A. Então $\beta=14/27$, as transferências de saída são $-40/27$ e $+40/27$, e a transferência líquida de A é $-80/27$. Seu saldo comercial monetário positivo de USD 10 não implica, por si só, apropriação de valor-trabalho.

O bloco abaixo utiliza somente **R básico**, sem pacotes ou arquivos, para implementar esses exemplos. Ele ilustra a matemática; não reproduz a preparação das fontes, as políticas de ausência ou todo o processo de validação do cálculo de produção.

```r
x <- c(100, 200)
Z <- matrix(c(15, 10, 15, 50), nrow = 2, byrow = TRUE)
K <- matrix(c(50, 100, 50, 100), nrow = 2, byrow = TRUE)
Dep <- 0.1 * K
H <- c(40, 40)
W <- c(27, 54)
C <- sweep(Z + Dep, 2, x, "/")
ell <- H / x
lambda <- as.vector(solve(t(diag(2) - C), ell))
gross_value <- lambda * x
basket <- c(0.5, 0.5)
v <- W * sum(lambda * basket)
surplus <- H - v
surplus_rate <- H / v - 1
aggregate_rate <- sum(H) / sum(v) - 1
mu <- sum(x) / sum(gross_value)
capital_stock <- colSums(K)
monetary_va <- x - colSums(Z)
capital_compensation <- monetary_va - W
profit_rate <- (capital_compensation - colSums(Dep)) / capital_stock

trade_usd <- matrix(c(0, 20, 10, 0), nrow = 2, byrow = TRUE)
trade_value <- sweep(trade_usd, 1, lambda, "*")
beta <- sum(trade_value) / sum(trade_usd)
transfers <- beta * trade_usd - trade_value
net_transfers <- rowSums(transfers) - colSums(transfers)

stopifnot(
  max(abs(lambda - c(16, 10) / 27)) < 1e-12,
  max(abs(as.vector(lambda %*% (diag(2) - C)) - ell)) < 1e-12,
  max(abs(v - c(13, 26))) < 1e-12,
  abs(aggregate_rate - 41 / 39) < 1e-12,
  abs(sum(mu * gross_value) - sum(x)) < 1e-12,
  max(abs(profit_rate - 0.33)) < 1e-12,
  abs(beta - 14 / 27) < 1e-12,
  max(abs(net_transfers - c(-80, 80) / 27)) < 1e-12,
  abs(sum(net_transfers)) < 1e-12
)
print(data.frame(lambda, gross_value, v, surplus, surplus_rate, profit_rate))
print(c(aggregate_rate = aggregate_rate, mu = mu, beta = beta))
print(net_transfers)
```

## 9. Agregue de acordo com a grandeza econômica

| Grandeza | Operação correta nos contratos atuais | Motivo |
| --- | --- | --- |
| Horas, remuneração, capital e outros totais comparáveis | Soma | São aditivos na mesma unidade e no mesmo período |
| Valor-trabalho por USD | Valor da produção bruta total / produção bruta monetária total | Atividades grandes e pequenas não devem receber pesos arbitrariamente iguais |
| Valor de reprodução ou trabalho por pessoa | Numerador total / total de pessoas correspondente | Preserve a população de empregados/pessoas ocupadas relevante |
| Taxa de mais-valia | Trabalho total / valor total de reprodução − 1 | Preserve os dois lados da relação |
| Taxa de lucro apropriado | Remuneração líquida total do capital / estoque total | Preserve o denominador contábil |
| Multiplicador de complexidade do trabalho | Média ponderada pelas horas | O multiplicador atua sobre as horas |
| Índice nacional de preços da produção | Média ponderada pela produção bruta em USD correntes | Essa é a regra de agregação atualmente declarada |
| Câmbio nacional ou índice compartilhado de cesta | Invariante entre seus setores | São valores nacionais repetidos nos setores |
| Índices mundiais de câmbio/cestas/preços de produção | `not_applicable`, conforme declarado | Bases monetárias nacionais não constituem uma moeda mundial comum |

Os [contratos v2 de unidades e agregações](units.md) são especificações executáveis, não sugestões opcionais de apresentação. Algumas fórmulas são implementadas em módulos específicos de agregação. As somas de observações disponíveis exigem a informação de seus estados semânticos: um total finito pode apresentar cobertura incompleta. Consulte `_states.csv`, `_anomalies.csv` e `_scientific_checks.csv` junto aos arrays numéricos; veja [ausências](missingness.md).

## 10. Hipóteses que devem acompanhar um resultado empírico

As razões agregadas padrão utilizam componentes somados independentemente,
em vez de selecionar automaticamente pares completos de numerador e
denominador. Assim, `WWW` em `surplus_value.emp.r.pc` pode incluir trabalho
imputado do ROW no numerador enquanto seus custos de reprodução estão ausentes
do denominador; o lucro agregado também soma remuneração do capital,
depreciação e estoque separadamente. Examine a cobertura de cada componente:
essas fórmulas não estabelecem que todos os termos correspondam à mesma
população observada.

O [registro completo de hipóteses](assumptions-pt.md) relaciona cada hipótese a seu código, evidência, efeitos e trabalho pendente. Informe, no mínimo:

1. Fonte, período e classificação produtiva selecionados; a tecnologia setorial média anual representa produtores heterogêneos, com requisitos proporcionais de insumo e sem reconstrução da produção de cada empresa.
2. Multiplicadores de horas de trabalho iguais, em vez de uma redução internacional de complexidade e intensidade identificada empiricamente; as diferenças salariais observadas não são utilizadas para demonstrar diferenças de produtividade.
3. Composição do capital estimada com EU KLEMS, participações de investimento e aproximações, incluindo a convenção de depreciação do ano seguinte e todas as alternativas específicas de cada fonte.
4. Participações médias nacionais de consumo utilizadas para converter remuneração em valor de reprodução da força de trabalho; não se estima um modelo de orçamento individual, poupança ou trabalho doméstico não remunerado.
5. Complementação de China e resto do mundo: a WIOD13 trata as pessoas ocupadas chinesas como empregados; a WIOD16 também importa horas por ocupado mapeadas da WIOD13 e mantém a última observação até 2014. O emprego do resto do mundo é distribuído com intensidades setoriais observadas de emprego/valor adicionado; as horas utilizam a jornada média setorial observada por ocupado; e o capital utiliza o país de referência de menor capital por hora. As lacunas restantes de empregados/remuneração não são automaticamente preenchidas por essas etapas.
6. Escala monetária e normalização do comércio internacional, distinção entre valor da produção bruta e valor novo e entre lucro monetário e mais-valia.
7. Políticas registradas de zeros/ausências/sinais, seus diagnósticos e a menor cobertura de capital na WIOD13 em 2008–2009. A validação numérica bem-sucedida é condicionada por essas escolhas; ela não é uma validação externa de seu realismo econômico.

## 11. O que ainda precisa ser desenvolvido

Ampliações cientificamente úteis incluem sensibilidade à redução do trabalho e aos limites da classificação produtiva; cestas observadas por grupo de trabalhadores; imputações alternativas de trabalho e capital do resto do mundo; estimativas empíricas de origem dos ativos e depreciação; e análise explícita do impacto dos zeros de compatibilidade e da FBCF negativa truncada. Recuperar uma sequência executável de origem e transformação do mapeamento setorial histórico da China ampliaria a reprodutibilidade. Estender períodos, recuperar outras bases e implementar métodos alternativos exige contratos próprios de fonte, unidade, ausência e validação.

Uma futura série de taxa marxiana de lucro precisaria definir e medir explicitamente capital constante e variável adiantados, rotação e valoração; mudar o nome da razão contábil atual não forneceria essas grandezas. Essas são propostas, não capacidades implementadas. O [guia prático](guide-pt.md) explica como utilizar resultados existentes, reproduzir cálculos suportados e contribuir com uma expansão submetida a revisão própria.
