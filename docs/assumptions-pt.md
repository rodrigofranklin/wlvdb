# Hipóteses, limitações e trabalho pendente

<!-- documentation-revision: wiod-reader-workflows-v2 -->

Português | [English](assumptions-en.md) | [Início](../README-PT.md) | [Teoria](theory-pt.md) | [Matemática](methodology-pt.md) | [Guia prático](guide-pt.md)

## Como ler este registro

Um resultado depende de um modelo e de seus dados. Uma **hipótese** relaciona
um conceito econômico a algo mensurável; uma **imputação** fornece uma
observação ausente; uma **regra numérica** determina como proceder quando um
cálculo é indefinido ou particularmente sensível. Essas escolhas têm
justificativas diferentes. Passar em uma verificação de software estabelece
que a regra escolhida foi implementada de maneira consistente. Isso não
estabelece que todas as hipóteses descrevem a economia igualmente bem.

Este registro abrange os métodos públicos `wiodr13` e `wiodr16`, da preparação
das fontes à interpretação. As seleções ativas estão nos
[módulos comuns](../config/modules/common.csv), [módulos WIOD13](../config/modules/sources/wiodr13.csv)
e [módulos WIOD16](../config/modules/sources/wiodr16.csv). A preservação de um
arquivo alternativo não significa que a alternativa seja executável. As
listas exatas de células e as tolerâncias permanecem nos contratos vinculados;
são extensas demais para serem substituídas por um resumo verbal. Leia esta
página junto com a derivação matemática.

## Modelo econômico e mensuração

| Escolha | Por que é necessária e o que significa | Consequência para a interpretação |
| --- | --- | --- |
| Uma tecnologia representativa por país-setor-ano | As contas anuais de insumo-produto reúnem produtores e produtos. Os requisitos de insumos e a intensidade de trabalho são tratados como proporcionais dentro de cada célula; o modelo acompanha requisitos médios observados. | Diferenças entre firmas, produção conjunta e qualidade dos produtos são agregadas. A necessidade de horas calculada depende dessa agregação; não é o valor de uma mercadoria individual observado independentemente. |
| Reprodução anual com coeficientes fixos | Insumos intermediários e depreciação anual entram no sistema de valores trabalho com os coeficientes do ano. | É uma estimativa estática de reprodução; não modela trajetórias de ajuste, limites de capacidade, substituição ou mudança técnica dentro do ano. A depreciação representa requisitos correntes de reposição, não o trabalho histórico efetivamente gasto em cada máquina sobrevivente. |
| Fluxos monetários representam quantidades avaliadas consistentemente | Dividir fluxos monetários de um fornecedor pelo produto do setor comprador gera coeficientes monetários. O trabalho por USD converte os fluxos do fornecedor em requisitos de trabalho. | A construção não pressupõe igualdade entre preços de mercado e valores. Exige consistência suficiente de preços e unidades e homogeneidade dos produtos setoriais; a [derivação](methodology-pt.md) explica o cancelamento dos preços e seus limites. |
| Peso igual para cada hora | Os dois métodos padrão fixam `complex_labour_multiplier` em 1. | Diferenças de qualificação, intensidade e entre países não são reduzidas separadamente a trabalho simples. As taxas por qualificação da WIOD13 continuam sob essa hipótese. Rodar um método padrão não reproduz as alternativas de redução do artigo. |
| Classificação dos setores produtivos | O bloco produtivo é selecionado por `productive` nas tabelas setoriais [WIOD13](../methods/wiodr13/_sectors.csv) e [WIOD16](../methods/wiodr16/_sectors.csv). A criação de valor é atribuída a esse bloco. | Setores improdutivos podem prestar serviços socialmente úteis e receber valor. Os zeros estruturais da transformação expressam a classificação, não a ausência de trabalhadores ou atividade econômica. Alterar a classificação altera o modelo. |
| Consumo das famílias como cesta de reprodução | A composição nacional das compras das famílias traduz a remuneração no trabalho necessário à cesta que ela financia. A mesma composição nacional é aplicada aos trabalhadores dos setores. | Trabalhadores não precisam consumir como a família média. Poupança, crédito, diferenças entre qualificações, composição familiar e serviços públicos não são identificados separadamente. O resultado estima a reprodução sob essa convenção, não um mínimo normativo de subsistência. |
| Remuneração como recurso para comprar a cesta | A remuneração dos empregados e a remuneração total do trabalho financiam as respectivas cestas; a segunda inclui o tratamento dos não empregados adotado pela fonte. | Uma taxa de `empe` e uma taxa de `emp` têm populações e conceitos de remuneração distintos. A remuneração é uma medida contábil e não corresponde necessariamente ao salário líquido recebido. |
| Taxa de mais-valia como razão em unidades de trabalho | O total de trabalho pertinente é dividido pelo valor da cesta correspondente e subtrai-se 1. Variantes produtivas restringem a população. | Uma taxa elevada, isoladamente, não estabelece pagamento abaixo do valor da força de trabalho nem um diagnóstico causal de dependência. Horas totais e dólares não podem ser inseridos diretamente na mesma razão. |
| Duas normalizações mundiais distintas | Preços diretos usam totais monetários e em valor do produto bruto mundial; transferências comerciais usam totais monetários e em valor do comércio internacional produtivo. | Respondem a perguntas diferentes. Nenhum fator é uma taxa de câmbio observada ou uma conversão por paridade de poder de compra. As transferências descrevem o mecanismo comercial selecionado, não toda a apropriação internacional de renda. |

A classificação produtiva não é idêntica à do artigo: sua nota 21 exclui
Hotéis e Restaurantes e Outros Serviços Comunitários, Sociais e Pessoais,
enquanto a tabela WIOD13 atual inclui ambos (`H` e `O`). A máscara atual tem
25 setores produtivos; o sistema descrito no artigo usa 23. Portanto, usar a
mesma versão da matriz de insumo-produto não basta para reproduzir o estudo.

Os conceitos e as posições de Franklin et al. (2022) e Franklin (2025) estão em
[teoria](theory-pt.md), com [referências ABNT](references-pt.md). A execução
está nos [módulos de matrizes](../scripts/modules/native/matrix_modules.R), nos
[indicadores comuns](../scripts/modules/native/indicator_common_modules.R) e nos
[indicadores derivados das fontes](../scripts/modules/native/indicator_source_derived_modules.R).

## Trabalho e resto do mundo

### China e empregados versus pessoas ocupadas

A WIOD13 fornece horas totais e ocupação; sua hipótese para a China substitui
empregados por pessoas ocupadas, tanto nos efetivos quanto nas horas. A fórmula
geral da WIOD16 estima as horas totais multiplicando as horas por empregado
pelo total de ocupados. Portanto, pressupõe a mesma jornada anual média para
empregados e não empregados de cada país-setor.

Para a China, a WIOD16 usa uma [tabela complementar versionada](../complementar/wiodr16/china_hours_per_worker.csv)
derivada de `H_EMP / EMP` da WIOD13 e mapeada para os setores da WIOD16:

$$
H^{CHN}_{s,t}=N^{CHN}_{s,t}\,a_{s,t}\,1000.
$$

Aqui, $N$ é o número de ocupados e $a$ está em **milhares de horas anuais por
pessoa**. Multiplicar por 1.000 converte a unidade. O coeficiente de 2009,
já igual ao de 2008 no arquivo, é mantido até 2014. Empregados chineses e suas
horas passam a corresponder a todos os ocupados e suas horas. O script original
de correspondência entre setores está ausente: os bytes autenticados da tabela
podem ser reutilizados, mas essa correspondência ainda não pode ser regenerada
independentemente por uma receita versionada. Essa distinção importa para a
reprodutibilidade.

### Ocupação, horas e capital do resto do mundo

`ROW` é uma região residual agregada. Seus fluxos observados de insumo-produto
não fornecem contas completas de trabalho e capital. O modelo lê um
[total complementar de ocupação](../complementar/worldbank/employment_row.new.csv)
baseado nas séries de força de trabalho e desemprego do Banco Mundial. Esse
total é distribuído entre setores usando o valor adicionado do ROW e a
intensidade de ocupação dos países explicitamente observados.

Para um ano, seja $N_R$ esse total, $Y_{Rs}$ o valor adicionado do ROW no setor
$s$, e $N_{Os},H_{Os},Y_{Os}$ os **totais** de ocupação, horas e valor adicionado
do mesmo setor nos países observados. A construção é:

$$
w_s=Y_{Rs}\frac{N_{Os}}{Y_{Os}},\qquad
N_{Rs}=N_R\frac{w_s}{\sum_u w_u},\qquad
H_{Rs}=N_{Rs}\frac{H_{Os}}{N_{Os}}.
$$

A normalização preserva o total externo de ocupação. Ela não demonstra que a
distribuição setorial estimada seja observada. A fórmula das horas extrapola
a jornada média de cada setor nos países observados, ponderada pela ocupação.

O método padrão seleciona um país de referência pela menor intensidade agregada
não nula de capital por hora entre os países observados; nas entradas fixadas
da WIOD16, a referência é a Índia. Sujeito às regras explícitas de denominador
zero abaixo, o capital de cada setor do ROW é:

$$
K_{Rs}=H_{Rs}\frac{K_{qs}}{H_{qs}},
$$

em que $q$ é o país selecionado. Trata-se de extrapolação da intensidade de
capital, não de observação direta ou comprovação do estágio de desenvolvimento
de um país. O índice de preços do produto bruto do ROW acompanha o dos EUA.
A WIOD16 reconstrói o capital do ROW em USD constantes multiplicando o estoque
corrente pelo índice cambial e dividindo-o pelo índice de preços do produto
bruto, ambos com base em 2000.

A hipótese pública do ROW **não** completa o número de empregados, suas horas
ou a remuneração. As ausências resultantes precisam conservar seus estados
semânticos. Elas também limitam a cobertura de agregados que envolvem salários
ou reprodução dos empregados. A alternativa histórica que completa essas
variáveis é outro método, não executável. Consulte as
[hipóteses nativas](../scripts/modules/native/assumption_modules.R) e as
[regras do capital do ROW](../scripts/lib/row_capital.R).

## Capital, preços e comparações no tempo

| Escolha | Implementação efetiva | O que permanece incerto |
| --- | --- | --- |
| Estoque de capital em USD correntes | A WIOD13 usa estoque local constante de 1995 `K_GFCF`, seu índice de preços `GFCF_P` e o câmbio corrente; a WIOD16 divide o estoque local corrente `K` pelo câmbio corrente. | Conceitos e fontes de estoque dessas versões exigem correspondência antes de comparações. Estoque não é investimento anual. |
| Composição do capital | Pesos por ativo da EU KLEMS, correspondência setorial WIOD-KLEMS, parcelas de desagregação por valor adicionado e composição da oferta de FBCF do país investidor distribuem o estoque de cada setor entre fornecedores. Os pesos são normalizados para conservar o estoque. | A oferta contemporânea de investimento aproxima a composição/origem de um estoque existente. Não identifica a idade ou a origem efetiva de cada ativo. |
| Cobertura da EU KLEMS | Países sem cobertura KLEMS mapeada usam o país médio sintético `MD`, preparado pelo projeto. `GBR`/`GRC` correspondem a `UK`/`EL`. Taxas agregadas de depreciação diretamente disponíveis prevalecem sobre taxas sintetizadas de componentes. | Os coeficientes do país médio extrapolam os países observados; conservar um estoque não valida independentemente sua composição por ativos. |
| Momento da depreciação | Estoque/composição do ano $t$ usa taxas EU KLEMS de $t+1$. | É uma convenção temporal explícita. O último ano de cálculo exige taxas do ano seguinte. Depreciação zero é um contrafactual preservado, não uma opção atual. |
| Taxa de câmbio | Para cada país-ano, total do valor adicionado em moeda local dividido pelo total em USD correntes; uma taxa é aplicada a todos os setores. A taxa dos EUA é conferida contra 1. | É uma taxa implícita de conversão nacional. Câmbios setoriais e médias entre moedas de países teriam outro significado. |
| Moeda constante e cestas fixas | A cesta de referência é de 1995 na WIOD13 e de 2000 na WIOD16; os índices de saída são apresentados relativamente a 2000. O capital constante da WIOD16 usa o índice de preços do produto bruto como aproximação do deflator do estoque. | A base de apresentação não é o ano de composição da cesta. USD constantes, USD correntes, horas e unidades de paridade de poder de compra são medidas diferentes. Um índice temporal não é um nível de preços comparável internacionalmente. |

As equações e os locais do código estão em [metodologia](methodology-pt.md).
Para as unidades básicas exatas, consulte o `_unit_contract.csv` publicado e o
[dicionário de indicadores](results-dictionary-pt.md), sem deduzi-las apenas
dos sufixos históricos dos nomes.

Há outra distinção nos índices de cesta da WIOD13: parcelas monetárias fixas
e índices de preços da fonte referem-se a 1995, enquanto o índice cambial usa
2000. O capítulo matemático registra explicitamente essa combinação
implementada. Interpretá-la como o custo em trabalho de exatamente a mesma
cesta física de 1995 exige avaliar as bases de preços e câmbio por país
fornecedor, incluindo importações. Rebasear o agregado final para 2000 não
estabelece, por si só, essa equivalência.

## Dados excepcionais e regras numéricas

São regras fechadas para fontes fixadas. Uma contagem resume sua abrangência;
não autoriza aplicar o mesmo tratamento a uma nova observação. Coordenadas,
valores e, quando especificadas, assinaturas também precisam coincidir com o
contrato.

| Regra | Método público e abrangência | Interpretação e evidência |
| --- | --- | --- |
| Compatibilidade histórica de ausências convertidas em zero | A preparação WIOD13 conserva uma conversão histórica fixada de entradas ausentes em zero. A cobertura do capital piora em 2008–2009. | Valores finitos podem ter cobertura incompleta. O WLVPanel exclui esses dois anos de todas as séries WIOD13; isso não é uma máscara geral de `NA` na base. Consulte o [contrato WIOD13](wiodr13.md) e os metadados publicados de anomalias/cobertura. |
| Investimento negativo usado na alocação | 24 células negativas de FBCF da WIOD13 e 649 da WIOD16 são truncadas em zero nos pesos de alocação após validação. | Fluxos originais permanecem intactos. A escolha altera a distribuição inferida do capital. `_gfcf_negative_cells.csv` e `_gfcf_negative_summary.csv` permitem examinar a transformação. |
| Ausência de pesos primários positivos | 93 colunas de estoque positivo da WIOD13 e 120 da WIOD16 usam a distribuição não negativa da FBCF do próprio país. | Preserva os totais do estoque enquanto substitui sua composição por uma distribuição menos detalhada. Os casos exatos constam nos contratos [WIOD13](wiodr13.md) e [WIOD16](wiodr16.md). |
| Capital com sinal na WIOD13 | O caso fechado `2006/GBR.23` preserva capital e depreciação negativos. | O argumento de produtividade para matrizes não negativas não se aplica à matriz de coeficientes desse ano. A implementação certifica convergência absoluta com a matriz de coeficientes em módulo e registra produtividade como `not_applicable`. |
| Fluxos não nulos com produto zero na WIOD13 | 3.150 coordenadas exatas em quatro colunas país-setor-ano de Chipre/Malta são zeradas para a divisão protegida dos coeficientes. | Esses coeficientes não são zeros observados ordinários. Novas divisões indefinidas são erros; o [contrato científico](scientific-validation.md) registra a exceção. |
| Capital e pesos KLEMS negativos na WIOD16 | Três observações portuguesas de estoque são truncadas. Dos 21 pesos KLEMS negativos validados em 2010–2015, 19 entram nos anos de composição 2010–2014 e são truncados. | As alterações são registradas em `_anomalies.csv`. Valores adicionados negativos são mantidos; o sinal da única desagregação romena J58 de 2007 é tratado explicitamente, sem retirar todo valor adicionado negativo. |
| Denominadores de emprego na WIOD16 | 1.914 casos sem empregados também não têm ocupados e recebem zero horas; `2001/MLT/M72` usa a razão agregada de horas por empregado de Malta. | A única substituição usa jornada nacional em vez de setorial. Não é uma reposição universal para denominadores zero. |
| Denominadores do capital do ROW na WIOD16 | Setores de referência indianos sem horas produzem 15 zeros explícitos de M73 no ROW e 150 usos da intensidade agregada de capital por hora da Índia. | Horas zero no ROW geram capital zero; os demais setores afetados usam uma intensidade mais agregada. O [contrato da fonte](wiodr16.md) identifica os grupos. |
| Admissibilidade do sistema linear | Dimensões produtivas, condicionamento, resíduos, regras de sinal/zero e certificado de convergência aplicável são verificados anualmente. | Um pequeno resíduo numérico sustenta a solução calculada, não a verdade da teoria do valor ou a exatidão das imputações. Sistemas quase singulares exigem diagnóstico, não uma inversa arbitrária. |
| Ausências e agregação | `NA` ordinário exige `source_missing` ou `not_applicable`; estados inacabados `uncomputed` não podem ser publicados. Agregados de componentes disponíveis registram cobertura parcial. Variáveis extensivas são somadas; intensidades e taxas seguem pesos ou razões de totais especificados. | `NA` não é zero. Um agregado mundial com componentes ausentes não comprova cobertura mundial completa. Não faça média de taxas de exploração nem some `WWW` com os países que o compõem. |

Os detalhes legíveis por máquina são mantidos nos
[perfis contratuais](../config/contracts), nas
[políticas de ausência](../catalog/missingness-policies.csv), na
[validação científica](scientific-validation.md) e na documentação de
[ausências](missingness.md). Devem acompanhar os valores quando se avalia a
confiabilidade de um resultado.

As razões agregadas padrão somam seus componentes independentemente; não
restringem automaticamente os dois lados às observações em que ambos estão
presentes. Por exemplo, `WWW` em `surplus_value.emp.r.pc` pode incluir horas
imputadas do ROW no numerador sem custos de reprodução correspondentes no
denominador, porque a remuneração do ROW está ausente. O lucro agregado
também soma remuneração do capital, depreciação e estoque separadamente:
examine a cobertura de cada componente antes de interpretar uma razão finita
como medida de uma população com cobertura consistente.

## Trabalho pendente

O quadro abaixo é uma agenda de pesquisa e contribuição, não uma afirmação de
que essas capacidades já existem ou de que sua implementação está agendada.

| Trabalho | Limite atual | Evidência necessária para encerrá-lo |
| --- | --- | --- |
| Reconstruir independentemente a correspondência setorial chinesa | A tabela complementar histórica é autenticada, mas o script original de correspondência está ausente. | Correspondência entre origem e destino, decisões de ponderação, script reproduzível e comparação com os coeficientes fixados. |
| Avaliar alternativas de redução do trabalho | Os métodos padrão usam horas homogêneas; definições alternativas estão preservadas com execução desabilitada. | Multiplicador fundamentado, efeitos na criação de valor e nas cestas de reprodução, unidades/ausências/contratos próprios, exemplos analíticos e comparações independentes com o artigo de 2022. |
| Mensurar sensibilidade a imputações e ao tratamento do capital | ROW, China, coeficientes KLEMS do país médio, truncamentos/substituições de FBCF e a exceção com sinal afetam as estimativas. | Hipóteses alternativas explícitas, execuções comparáveis controladas e relatos das mudanças em níveis, ordenações e taxas. Arquivos de diagnóstico, isoladamente, não constituem um estudo de sensibilidade concluído. |
| Melhorar a cobertura final da WIOD13 | A cobertura das fontes de 2008–2009 limita a interpretação mesmo com resultados finitos. | Evidência recuperada das fontes ou política de ausências/imputação versionada separadamente, relatório de impacto e concordância com a cobertura do painel. |
| Avaliar índices de cesta entre bases cambiais e de preços | A WIOD13 combina parcelas/índices de preços da fonte de 1995 com índice cambial de 2000. | Derivação independente com quantidades fixas por país fornecedor, comparação com o índice implementado e avaliação de sensibilidade dos componentes importados antes de afirmar equivalência exata à cesta física. |
| Incorporar outras fontes de insumo-produto | EXIOBASE e EORA estão desabilitadas; o [issue #14](https://github.com/rodrigofranklin/wlvdb/issues/14) registra a expansão adiada. | Fontes e licenças fixadas, unidades de trabalho e política de capital explícitas, estruturas, exemplos analíticos, evidência de cálculo/recálculo/publicação completos e comparabilidade justificada entre fontes. |
| Ampliar a cobertura das medidas de dependência | As transferências comerciais atuais não identificam todos os juros, dividendos, rendas, relações de propriedade ou subordinação política. | Dados adicionais e mecanismos claramente definidos; distinguir medidas novas do indicador atual de transferências comerciais. |
| Fortalecer a validação empírica | Identidades internas, exemplos analíticos e paridade histórica validam partes importantes da implementação. | Estimativas reconstruídas independentemente e comparações externas/com as fontes, explicando discrepâncias. Coincidir com resultados históricos, isoladamente, não comprova as hipóteses econômicas do modelo. |

Para propor uma dessas mudanças, siga o
[percurso de contribuição](guide-pt.md#contribuir-com-uma-melhoria).
Registre método exato, commit do código, proveniência das entradas, unidades e
hipóteses ao relatar resultados. O [guia de referências](references-pt.md)
explica como distinguir os estudos fornecidos da implementação atual.
