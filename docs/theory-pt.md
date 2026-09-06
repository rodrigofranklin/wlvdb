# Teoria: o significado das estimativas

<!-- documentation-revision: wiod-reader-workflows-v2 -->

Português | [English](theory-en.md) | [Início](../README-PT.md) | [Guia prático](guide-pt.md) | [Matemática](methodology-pt.md) | [Hipóteses e trabalho pendente](assumptions-pt.md) | [Referências](references-pt.md)

O WLVDB investiga quanto trabalho é necessário para reproduzir as mercadorias
que uma economia produz, como esse trabalho se relaciona com o consumo dos
trabalhadores e como o comércio internacional redistribui o valor que ele
representa. Responder exige tanto uma teoria do objeto medido quanto um
modelo que conecte essa teoria aos registros de produção, emprego e despesa.

Na primeira leitura, siga a ordem deste capítulo. Ele apresenta os conceitos
antes de o [capítulo matemático](methodology-pt.md) desenvolver os cálculos.
Os métodos atuais `wiodr13` e `wiodr16` são implementações particulares do
programa de pesquisa de Franklin et al. (2022) e Franklin (2025). Eles não
implementam todas as alternativas discutidas nessas obras, nem reproduzem
automaticamente suas tabelas publicadas.

## 1. Das coisas úteis ao trabalho social

O pão pode alimentar alguém; uma máquina pode moldar metal; um serviço de
transporte pode levar um produto ao lugar onde ele é necessário. Esses são
**valores de uso**: qualidades úteis de bens ou serviços. O objeto útil e a
atividade que o produz são concretos e particulares. Uma hora de panificação
difere de uma hora de engenharia pelo que o trabalhador faz e pelo que o
resultado permite fazer.

Em uma economia mercantil, esses produtos diferentes também são trocados.
O **valor de troca** é a relação pela qual uma mercadoria se troca por outra;
o **preço** expressa uma relação desse tipo em dinheiro. O conceito marxiano
de **valor** diz respeito ao trabalho social representado pela mercadoria.
Sua grandeza é determinada pelo **tempo de trabalho socialmente necessário**:
trabalho realizado nas condições de produção socialmente vigentes, com
habilidade e intensidade normais. Um produtor que demora o dobro por usar
uma técnica ineficiente não cria, por isso, o dobro do valor da mesma
mercadoria. Essa distinção teórica é o ponto de partida da abordagem
empírica, e não um resultado produzido pelo programa
([Franklin et al., 2022, p. 365–370](references-pt.md#franklin-et-al-2022)).

**Trabalho concreto** designa o trabalho em sua forma útil particular.
**Trabalho abstrato** designa a dimensão social comum pela qual os produtos
de atividades diferentes se tornam comparáveis. Isso não significa que
trabalhadores, qualificações ou condições de trabalho sejam fisicamente
idênticos. Tampouco uma matriz resolve, por si só, como o trabalho privado
é validado socialmente.

O banco utiliza contas por país e setor e horas informadas para estimar essas
grandezas. As médias setoriais representam aproximadamente as condições de
produção; o multiplicador escolhido representa a redução de horas
heterogêneas a uma unidade comum. Trata-se de uma aproximação empírica.
Diferenças entre empresas, qualidade dos produtos, intensidade, produção
não vendida e qualificação podem permanecer ocultas pela agregação.
Portanto, `abstract_labour` é a medida operacional do método, e não uma
observação estatística direta do trabalho abstrato.

## 2. Por que toda a cadeia produtiva importa

Um pão exige mais trabalho do que as horas do padeiro. Também exige o
trabalho associado à farinha, à eletricidade e à parcela dos equipamentos
consumida na panificação. A farinha, por sua vez, exige grãos, transporte
e processamento. Parar no último estabelecimento deixaria de fora esses
requerimentos.

Por isso, o modelo distingue três componentes:

| Componente | Interpretação econômica | Conexão com o cálculo |
| --- | --- | --- |
| Trabalho vivo direto | Trabalho realizado no processo produtivo do período corrente. | Horas diretas divididas pelo produto bruto do setor. |
| Insumos intermediários | Produtos consumidos na produção do produto corrente. | Entregas entre setores divididas pelo produto do comprador. |
| Depreciação do capital fixo | Parcela dos ativos duráveis consumida durante o período. | Matriz estimada de depreciação dividida pelo produto do comprador. |

Somar o trabalho direto ao trabalho requerido pelos insumos e pela depreciação
fornece o requerimento total de trabalho da mercadoria. Em termos marxianos,
o trabalho vivo cria **valor novo**, enquanto os meios de produção transferem
valor à medida que são consumidos. O estoque completo de uma máquina não
entra no produto de cada ano: o modelo utiliza a parcela depreciada.
Esses são os componentes da equação 1 de
[Franklin et al. (2022, p. 370)](references-pt.md#franklin-et-al-2022).

A distinção também evita dupla contagem. Suponha que a farinha incorpore
2 horas e o padeiro acrescente 1 hora. O pão incorpora 3 horas. Somar as
2 horas da farinha às 3 horas do pão produz um total de 5 horas no produto
bruto, mas apenas 3 horas são requeridas pelo pão final ao longo de sua cadeia produtiva. Uma medida
de trabalho incorporado no produto bruto e uma medida de valor novo
respondem a perguntas diferentes. Ambas podem estar em horas e, ainda
assim, ter conteúdos econômicos distintos.

No WLVDB, o indicador matricial `values` converte entregas em horas
incorporadas; `value.m.mv` informa o requerimento de trabalho por unidade
monetária de produto. `abstract_labour` mede o trabalho direto ponderado.
Consulte o [dicionário](results-dictionary-pt.md) para a população, unidade
e agregação precisas de cada indicador publicado.

## 3. Por que é possível usar contas monetárias de insumo-produto

Uma matriz insumo-produto registra quem fornece cada produto e quem o
utiliza. O setor fornecedor ocupa a linha; o setor comprador ocupa a coluna.
Quando um comprador utiliza um insumo, o modelo também precisa do trabalho
necessário para fornecê-lo. Repetir esse raciocínio conecta todas as etapas
produtivas, inclusive as localizadas no exterior
([Franklin, 2025, p. 190–195](references-pt.md#franklin-2025)).

Os registros monetários são utilizáveis porque o dinheiro pode servir como
unidade para expressar as quantidades de produtos. Suponha que a mesma cesta
custe USD 10 e exija 2 horas. Seu coeficiente é 0,2 hora/USD. Se essa cesta
passar a ser expressa por USD 20, mantendo os mesmos requerimentos físicos,
o coeficiente será 0,1 hora/USD. Multiplicar cada coeficiente pelo fluxo
monetário correspondente devolve as mesmas 2 horas. Esse exemplo muda a
unidade em um modelo homogêneo e consistente; ele não afirma que movimentos
reais de preços deixam a produção ou a distribuição inalteradas.

O procedimento, portanto, **não exige que os preços observados sejam iguais
aos valores-trabalho**. Produto e insumos monetários são combinados com horas
informadas de maneira independente; o coeficiente resultante mede horas por
unidade monetária, e não dinheiro por hora trabalhada. A mudança algébrica
de unidades é demonstrada no [capítulo matemático](methodology-pt.md).
O artigo observa explicitamente que o produto pode ser expresso em unidades
físicas ou monetárias
([Franklin et al., 2022, p. 386, nota 16](references-pt.md#franklin-et-al-2022)).

Esse raciocínio exige valorações compatíveis, uma estrutura setorial comum
e uma aproximação utilizável para os produtos e técnicas de cada setor.
Uma unidade monetária do produto de um setor é tratada como exigindo a mesma
estrutura produtiva independentemente do comprador. Composições diferentes
de produtos, preços específicos por comprador, margens, impostos ou
fronteiras estatísticas inconsistentes podem enfraquecer essa aproximação.
Um método que converte dólares em horas precisa documentar essas limitações
além da aritmética.

O **sistema de Leontief** reúne esses requerimentos produtivos mutuamente
dependentes. Sob as condições pertinentes de convergência, soma os
requerimentos diretos, indiretos e os de etapas sucessivamente mais distantes.
Resolvê-lo estabelece consistência com as contas e hipóteses escolhidas.
Isso não demonstra, por si só, que essas hipóteses descrevem corretamente
todos os processos econômicos.

## 4. Trabalho produtivo e improdutivo

A distinção entre produtivo e improdutivo diz respeito ao papel da atividade
na produção e distribuição do valor. Não classifica o esforço, a utilidade,
a dignidade ou o direito à remuneração de um trabalhador. Uma atividade
pode ser indispensável ao funcionamento do capitalismo sem ser tratada
pelo modelo como criadora de valor novo.

O livro utiliza um conceito amplo de trabalho produtivo associado à produção
ou conservação de um valor de uso em uma mercadoria, porque as economias
nacionais também contêm produção mercantil fora do assalariamento
capitalista. Ele distingue esse conceito da definição mais restrita de
trabalho que produz mais-valor para o capital
([Franklin, 2025, p. 193–194, nota 74](references-pt.md#franklin-2025)).

Nenhuma das definições identifica trabalho produtivo simplesmente com a
fabricação de objetos tangíveis. Serviços podem entrar na categoria produtiva.
Por outro lado, vender ou distribuir direitos sobre uma riqueza existente
não implica necessariamente criar um novo valor de uso. Aplicar essas
distinções a setores que reúnem atividades diferentes exige julgamento e
admite discussão.

O WLVDB explicita esse julgamento na coluna `productive` de
[`wiodr13/_sectors.csv`](../methods/wiodr13/_sectors.csv) e
[`wiodr16/_sectors.csv`](../methods/wiodr16/_sectors.csv). O sistema atual
de requerimentos de trabalho utiliza o bloco produtivo e atribui zeros
estruturais fora dele. Esse zero é uma classificação do modelo: não significa
que ninguém trabalhou ou que nenhum pagamento ocorreu. Remunerações, emprego
e transações desses setores continuam economicamente relevantes.

As classificações também têm uma história. O artigo de 2022 inclui hotéis e
restaurantes e outros serviços comunitários, sociais e pessoais entre seus
setores improdutivos; o arquivo setorial atual do WIOD13 marca ambos como
produtivos. A classificação do artigo não substitui a consulta ao arquivo
versionado efetivamente usado por uma execução
([Franklin et al., 2022, p. 386–387, nota 21](references-pt.md#franklin-et-al-2022)).

## 5. Força de trabalho, salários e mais-valor

O trabalhador vende sua **força de trabalho**, a capacidade de trabalhar.
Manter e reproduzir essa capacidade exige alimentação, moradia, cuidados,
educação e outras condições histórica e socialmente determinadas.
O trabalho necessário para produzir seus meios de reprodução constitui
o **valor da força de trabalho**. Ele difere conceitualmente do valor criado
pelo trabalhador durante a jornada. Os custos de formação podem alterar
os custos de reprodução sem determinar uma elevação idêntica do valor
criado por hora trabalhada
([Franklin et al., 2022, p. 365–366](references-pt.md#franklin-et-al-2022)).

Suponha que 8 horas de trabalho produtivo criem valor novo e os meios de
reprodução da força de trabalho correspondente exijam 3 horas. As 5 horas
restantes constituem **mais-valor**; a razão entre trabalho excedente e
necessário é `5 / 3`, aproximadamente 167%. Essa é a **taxa de exploração**,
também chamada de taxa de mais-valia. Não se divide 5 pela jornada inteira
de 8 horas, nem se calcula uma razão entre horas e salários em dólares.

Para conectar essa ideia às contas, o WLVDB estima o conteúdo de trabalho
de uma cesta de consumo financiada pela remuneração. Utiliza a composição
do consumo das famílias do país como aproximação da composição das compras
dos trabalhadores. Multiplicar as participações das despesas pelos
requerimentos de trabalho dos produtos transforma salários monetários em
horas da cesta. O resultado `labour_force_value` permite comparar as duas
grandezas na mesma unidade. A família de indicadores chamada `surplus_value`
publica a taxa correspondente; o recorte de emprego e de setores
produtivos/improdutivos deve ser conferido no dicionário.

A aproximação não demonstra que a remuneração efetiva compra todos os meios
socialmente necessários à reprodução. O consumo total das famílias inclui
domicílios com fontes de renda diferentes, e trabalhadores de um mesmo país
consomem cestas distintas. O artigo utiliza cestas nacionais para suas
alternativas não baseadas em salários porque não dispunha de dados
específicos dos trabalhadores e de cada setor
([Franklin et al., 2022, p. 374](references-pt.md#franklin-et-al-2022)).

Uma taxa de exploração elevada tampouco identifica, por si só,
**superexploração**. Essa questão diz respeito ao comprometimento da
reprodução, incluindo a relação entre remuneração, consumo e desgaste da
força de trabalho. Exige evidências adicionais sobre jornada, intensidade,
condições de vida e necessidades de reprodução. A exploração pode crescer
ao mesmo tempo que os meios de subsistência se barateiam e o consumo real
aumenta. O livro examina precisamente por que essas questões precisam ser
distinguidas
([Franklin, 2025, p. 243–248](references-pt.md#franklin-2025)).

## 6. Por que salários maiores não são automaticamente mais trabalho abstrato

As horas informadas diferem em qualificação e intensidade. Reduzi-las a uma
unidade comum é, portanto, um problema teórico e empírico substantivo.
Uma possível simplificação atribui maior peso às horas de trabalhadores
mais bem remunerados. O artigo examina por que essa simplificação pode
incorporar a resposta à própria premissa.

Para que salários relativos representem criação relativa de valor, a
abordagem de Ochoa exige uma estrutura comum de cesta de consumo, uma taxa
de exploração uniforme e equilíbrio no mercado de trabalho. Entretanto,
salários também são influenciados pela luta de classes, discriminação,
barreiras migratórias e acesso à educação. Trabalhadores comparam salários;
não se deslocam livremente até que seus empregadores se apropriem da mesma
proporção de valor. Se o multiplicador baseado em salários impõe exploração
igual, as estimativas resultantes não podem testar essa igualdade de forma
independente
([Franklin et al., 2022, p. 365–369](references-pt.md#franklin-et-al-2022)).

| Abordagem discutida no artigo | Como as horas são ponderadas | Principal questão de interpretação |
| --- | --- | --- |
| Ochoa 1 | Remuneração horária do setor em relação à menor remuneração mundial. | Vincula diferenças salariais internacionais diretamente à criação de valor. |
| Ochoa 2 | Remuneração horária do setor em relação à menor remuneração do próprio país. | A dispersão salarial nacional afeta as comparações internacionais. |
| Petrović | Participações das horas por qualificação, ponderadas pela remuneração média de cada estrato. | Reconhece a composição interna dos setores, mas mantém hipóteses baseadas em salários. |
| Alternativa 1 | Todas as horas recebem peso 1. | Não mensura diferenças de qualificação ou intensidade. |
| Alternativa 2 | Horas de alta, média e baixa qualificação recebem pesos 6,25, 2,5 e 1. | Pesos ilustrativos arbitrários, não multiplicadores medidos de forma independente. |

O artigo compara as cinco abordagens; **os métodos WIOD atualmente
executáveis atribuem pesos iguais às horas**. Eles não oferecem as cinco
alternativas como opções intercambiáveis da linha de comando. Pesos iguais
são uma escolha parcimoniosa na ausência de medida independente, e não uma
demonstração de que diferenças de qualificação sejam irrelevantes. O artigo
encontra movimentos semelhantes entre suas duas alternativas não baseadas
em salários, reconhecendo diferenças nas grandezas e a necessidade ainda
aberta de obter multiplicadores melhores
([Franklin et al., 2022, p. 371–372, 383–384](references-pt.md#franklin-et-al-2022)).

## 7. Preços, apropriação e comércio internacional

Um **preço direto** é um preço proporcional ao valor-trabalho estimado,
expresso em dinheiro mediante uma normalização escolhida. Serve à comparação
analítica com o preço de mercado, sem constituir um segundo preço de venda
observado. A normalização atual utiliza o produto bruto mundial. Ele difere
do **preço de produção**, preço teórico relacionado à equalização das taxas
de lucro, cujo cálculo não é implementado como resultado dos métodos WIOD
atuais. O artigo apresenta a distinção entre valores, preços diretos e
preços de produção
([Franklin et al., 2022, p. 363, 370](references-pt.md#franklin-et-al-2022)).

Como preços podem diferir de valores, o mais-valor produzido em um setor
não precisa coincidir com o lucro apropriado nele. O trabalho realizado em
um lugar pode sustentar renda apropriada em outro. O cálculo de lucro
apropriado do banco é uma medida contábil baseada na remuneração do capital,
depreciação e estoque de capital; não deve ser renomeado como mais-valor
dividido por capital constante mais capital variável.

O comércio internacional torna essa distinção visível. Se um país vende
mercadorias contendo 100 horas por USD 100 e compra mercadorias contendo
150 horas pelos mesmos USD 100, seu comércio monetário está equilibrado,
mas ele recebe 50 horas incorporadas a mais do que envia. Trata-se de um
exemplo ilustrativo de troca desigual sob o modelo.

O comércio monetário real frequentemente é desequilibrado. Um país pode
importar mais horas incorporadas ao incorrer em déficit monetário. Por isso,
o WLVDB compara o trabalho incorporado com o trabalho representado pelo
pagamento, utilizando uma referência anual comum obtida do comércio
produtivo mundial. Considera tanto a etapa de exportação quanto a de
importação; saldo nacional positivo de transferência indica recebimento
líquido. O [capítulo matemático](methodology-pt.md) desenvolve essa correção
e explica a convenção de sinal bilateral
([Franklin, 2025, p. 195–200](references-pt.md#franklin-2025)).

Essa referência comercial difere da normalização de preços diretos do
produto bruto mundial. Também difere de uma medida de paridade do poder
de compra voltada ao custo de vida. Esses fatores não são intercambiáveis
apenas porque relacionam horas, dinheiro ou poder de compra.

A estimativa de transferência não identifica, sozinha, se salários,
produtividade, monopólio, câmbio ou outros mecanismos explicam o resultado.
Também não mede todos os canais de apropriação internacional. A explicação
mais ampla da dependência desenvolvida no livro considera lucros, juros,
rendas, subordinação e vinculação entre os processos de acumulação dos países.
Os indicadores comerciais fornecem evidências para uma parte dessa
investigação
([Franklin, 2025, p. 135–208, 209–239](references-pt.md#franklin-2025)).

## 8. O que torna uma estimativa defensável

Quatro perguntas diferentes precisam ser respondidas:

1. **O conceito corresponde à pergunta da pesquisa?** Trabalho incorporado,
   valor novo, reprodução da força de trabalho, lucro e transferências
   comerciais são objetos relacionados, mas distintos.
2. **A aproximação estatística corresponde ao conceito?** Confira o recorte
   produtivo, as populações de emprego, cestas de consumo, imputações e
   agregação.
3. **O cálculo implementa fielmente o modelo?** Unidades, orientação das
   matrizes, identidades, convergência e resíduos numéricos precisam ser
   consistentes.
4. **A interpretação resiste a alternativas plausíveis?** Avalie a
   sensibilidade às classificações, estimativas de capital, redução do
   trabalho e cobertura incompleta dos países antes de tirar conclusões
   substantivas.

Responder positivamente à terceira pergunta é necessário e valioso; não
responde às outras três. Uma correlação elevada entre preços e valores
também não resolve, por si só, o problema da redução nem comprova todas as
proposições teóricas. Código aberto, hipóteses explícitas e fontes rastreáveis
servem para permitir esses julgamentos. Continue com
[os cálculos](methodology-pt.md),
[as hipóteses e prioridades de pesquisa](assumptions-pt.md) e
[o uso, a reprodução ou a expansão dos resultados](guide-pt.md).
