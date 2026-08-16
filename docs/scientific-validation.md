# Contrato de validação científica

A validação científica é parte da transação de publicação. Um cálculo ou um
recálculo só substitui a geração anterior depois que os resultados em *staging*
passam pelos contratos estruturais, numéricos e semânticos. Falhas abortam a
transação; não são convertidas em avisos silenciosos nem em zeros.

Dois artefatos tornam a decisão auditável:

- `_leontief_diagnostics.csv` registra, por método e ano, orientação e dimensão
  do sistema, condicionamento, resíduos, erros reversos, limite de erro direto,
  refinamentos, domínio dos coeficientes, certificado de estabilidade e um
  fingerprint de `lambda`;
- `_scientific_checks.csv` registra cada invariante verificado, escopo, número
  de observações, erro máximo, erro escalado, tolerância e estado
  `pass`, `warning` ou `not_applicable`.

Ambos são escritos em UTF-8, relidos e validados antes da promoção. Em um
recálculo de variáveis, os módulos de matrizes não são executados outra vez:
os diagnósticos de GFCF e de Leontief da geração isolada são obrigatoriamente
recarregados e revalidados. Um sidecar ausente, com esquema ou política
numérica inválidos, ou incompatível com o método e os anos impede a publicação.

## Invariantes publicados

| Invariante | Regra |
| --- | --- |
| Estrutura | Todo arranjo é numérico, tem o posto declarado e rótulos completos, únicos e ordenados em cada eixo. |
| Alinhamento | Anos, indicadores, setores, países, matrizes bilaterais e agregado `WWW` usam os mesmos rótulos ordenados. |
| Metadados | `_method_solutions.csv` descreve exatamente o eixo de indicadores publicado. |
| Setor → país → mundo | Indicadores com solução direta `sum` ou `mean` reproduzem as agregações declaradas, preservando ausência semântica. |
| Produto bruto | `rowSums(m_io[,"values",,]) = sea_sectors[,"gross_output.s.mv",,]`. |
| Estoque de capital | `colSums(k_composition) = capital_stock.s.us`. |
| Depreciação | `colSums(k_depreciation) = capital_depreciation.s.us`. |
| Bilaterais | Todas as diagonais domésticas são exatamente zero. |
| Transferência produtiva | A soma mundial anual de `transfers_productive_values` é zero dentro do limite de redução. A matriz de transferências totais não está sujeita a essa regra e, nos resultados reais, não soma zero. |
| Faixas do método | Estoque, depreciação, produtos e matrizes de capital são não negativos nos métodos WIOD, salvo a exceção assinada fechada de WIOD13. Em `zerodep_2`, depreciação setorial e `k_depreciation` são exatamente zero. |
| Ausência | `NA` só é aceito nas coordenadas e estados semânticos publicados em `_states.csv`; consulte [`missingness.md`](missingness.md). |

Zeros estruturais e igualdade de rótulos são comparações exatas. Para uma soma
de `k` termos, usa-se o limite orientado pelo erro de arredondamento

```text
gamma_k = k * eps / (1 - k * eps)
limite  = 64 * eps * max(1, abs(esperado))
          + 8 * gamma_k * sum(abs(termos))
```

em que `eps = .Machine$double.eps`. Isso escala com o número e a magnitude dos
termos, em vez de aceitar uma tolerância absoluta arbitrária. No inventário
real usado para definir o contrato, a maior diferença absoluta de conservação
de capital foi `0,001953125`, mas a maior diferença escalada foi somente
`2,318668e-16`. As maiores somas residuais de transferências produtivas foram
`0,0001757815` em WIOD13 e `0,0001455694` em WIOD16, ambas abaixo de
`1,935698e-16` quando escaladas pela massa somada.

Nas faixas físicas, a folga de arredondamento também é local: para cada célula
e limite finito, usa-se `64*eps*max(1, abs(valor), abs(limite))`. Assim, uma
observação de grande magnitude não amplia a tolerância das demais células.

## Sistema e política numérica de Leontief

O sistema efetivamente resolvido é

```text
M lambda = l
M = t(I - C)[produtivo, produtivo]
```

onde `C = A + D` contém os coeficientes de consumo intermediário e de
depreciação depois do filtro produtivo, `l` é o trabalho direto por unidade de
produto e setores não produtivos recebem `lambda = 0`. A implementação resolve
o sistema por fatoração LU; ela não materializa `(I-C)^-1`.

O condicionamento publicado é exatamente
`rcond(M, norm = "I")`: a norma infinito de `t(I-C)`, e não a norma um de
`t(I-C)` nem uma norma de `I-C` descrita ambiguamente. Para uma dimensão
produtiva `n`:

```text
eps                    = .Machine$double.eps
gamma_n                = n * eps / (1 - n * eps)
forward_error_budget   = 1e-8
rcond_min              = gamma_n / forward_error_budget
max_backward_error     = 8 * gamma_n
refinement_trigger     = 64 * eps
max_refinements        = 2
```

A resolução aborta se a fatoração falhar, se `rcond` não for finito ou positivo,
se `rcond < rcond_min`, se a solução não for finita, se o erro reverso final
exceder `8*gamma_n` ou se `eta/rcond > 1e-8`. O erro reverso normwise é

```text
eta = ||M lambda - l||inf /
      (||M||inf * ||lambda||inf + ||l||inf).
```

Também se calcula o erro reverso componente a componente. Se o maior dos dois
erros ultrapassar `64*eps`, até dois passos de refinamento usam a mesma
fatoração LU.

As dimensões e limites derivados para os quatro métodos auditados são:

| Método | `n` | `rcond_min` | `max_backward_error` |
| --- | ---: | ---: | ---: |
| `wiodr13` | 1.025 | `2,275957200482089e-5` | `1,8207657603856711e-12` |
| `wiodr16` | 1.716 | `3,8102854205149894e-5` | `3,0482283364119914e-12` |
| `wiodr16v09` | 1.408 | `3,126388037345418e-5` | `2,5011104298763346e-12` |
| `zerodep_2` | 1.452 | `3,2240876635124941e-5` | `2,5792701308099953e-12` |

Uma varredura dos sistemas reais atuais encontrou:

| Método | Faixa de `rcond(t(I-C), "I")` | Maior `eta` |
| --- | ---: | ---: |
| `wiodr13` | `0,061088486737938902`–`0,16691616076854099` | `1,4686976978147001e-15` |
| `wiodr16` | `0,00637345644069691`–`0,087540111483478303` | `1,5929220166619701e-15` |
| `wiodr16v09` | `0,026916755498715601`–`0,099246816382030506` | `1,3848498020747001e-15` |
| `zerodep_2` | `0,075341330775438406`–`0,20363563840952101` | `2,0227146218546799e-15` |

Essas faixas são evidência de regressão, não limiares ajustados aos dados. O
limiar vem do orçamento de erro acima. Isso evita aceitar um sistema novo
apenas porque se parece com o conjunto histórico.

## Certificado econômico e domínio dos coeficientes

Para `C >= 0`, o cálculo resolve também
`t(I-abs(C)) z = 1` e exige, após uma guarda explícita de arredondamento,
`z - t(abs(C))z > 0` e razão superior estritamente menor que um. Nesse domínio
não negativo, o sidecar registra `productivity_nonnegative` e o certificado
sustenta a interpretação de produtividade de Hawkins–Simon.

Se qualquer coeficiente for negativo, essa interpretação não é feita. O mesmo
teste aplicado a `abs(C)` certifica convergência absoluta; o sidecar registra
`absolute_convergence_signed`, e a verificação de produtividade recebe
`not_applicable`. Portanto, um sistema assinado nunca deve ser descrito como
“produtivo por Hawkins–Simon”.

Nos anos não negativos, as maiores razões superiores observadas foram
`0,75096848958283802` em WIOD13, `0,94791088015081904` em WIOD16,
`0,88944812898743097` em `wiodr16v09` e `0,78511859723789401` em
`zerodep_2`, todas estritamente menores que um.

No perfil legado `wiodr16v09`, a regra histórica de capital do ROW continua
baseada em trabalhadores. O contrato completa somente os 165 pontos em que a
fórmula antiga produzia `0/0`: 150 usam a intensidade agregada de capital por
trabalhador da Índia e 15 células `M73`, nas quais o emprego do ROW também é
zero, permanecem em zero. Os 675 valores em que a fórmula histórica já era
definida não são alterados.

### Exceção fechada WIOD13/2006/GBR.23

Há exatamente um caso assinado no método padrão:

- ano `2006`, país-setor de saída `GBR.23`;
- observação de fonte `GFCF_P = -631,84349265723654`;
- `K_GFCF = 6481,3145629698556` e câmbio
  `exchange.r.us = 0,54270254248267125`;
- estoque derivado `capital_stock.s.us = -75458950528,278488`;
- depreciação derivada
  `capital_depreciation.s.us = -6684967062,9865351`;
- 824 células negativas em cada uma de `k_composition` e `k_depreciation`,
  todas na saída `GBR.23`; 705 estão no bloco produtivo;
- 397 coeficientes negativos em `C`, mínimo
  `-0,01898715998070177`;
- `rho(C) = 0,60263205291203048`,
  `rho(abs(C)) = 0,60263969376795989` e razão superior certificada
  `0,81373176272914916`.

O caso não é uma autorização genérica para números negativos. A auditoria o
fecha em camadas:

| Camada | Regra ou fingerprint |
| --- | --- |
| Observação de fonte | chave `2006|GFCF_P|23|GBR`; MD5 da chave `c7d6c9acb4aa4e8664c94642676d94c3`; MD5 de chave mais valor em `%.17g` `1ace51365b57b2d6e825b51d86fc7061` |
| SEA publicada | uma única célula negativa em cada indicador, exatamente em `2006/23/GBR`, com os dois valores derivados acima |
| `k_composition` | 824 negativas; MD5 de coordenadas `31181c10e48b8defdec83affb2a5a261`; MD5 de coordenadas mais valores `4989e51b2a6295660d6fbb0ceffe0686` |
| `k_depreciation` | 824 negativas; MD5 de coordenadas `31181c10e48b8defdec83affb2a5a261`; MD5 de coordenadas mais valores `8d61eeb9b0692f6e896eaef24d85024f` |
| Bloco produtivo das matrizes | 705 negativas; MD5 de coordenadas `21e7e9daecae757c194e29e62093852d` |
| Coeficientes `C` reconstruídos | 397 negativas; MD5 de coordenadas `532229fed583964d5f69c68e5bf1bdeb`; MD5 de coordenadas mais valores `c3557db32e611f176068c2d646b4d7fd` |
| Diagnóstico | somente `wiodr13/2006` pode ter 397 coeficientes negativos e somente ele pode declarar `absolute_convergence_signed`; todos os demais método-anos exigem zero negativas e `productivity_nonnegative` |

Os fingerprints ordenam chaves em radix, codificam-nas em UTF-8, unem linhas
com LF e formatam valores por `sprintf("%.17g")`. Os pins da SEA, das matrizes
de capital e do perfil método-ano são condições do validador publicado. Os
fingerprints da observação, do bloco produtivo e de `C` são referências de
reconstrução: uma auditoria independente deve refazê-los a partir da fonte e
dos resultados, sem reinterpretar o caso como produtividade. Alterar posição,
contagem, magnitude, ano ou método exige uma nova política versionada e revisão
científica.

## Matriz full × recálculo

Uma comparação deve preservar uma cópia imutável da geração completa antes de
executar `recalc_wlv()`, pois um recálculo bem-sucedido promove atomicamente a
nova geração para o mesmo diretório. A unidade de comparação é a célula com
seus rótulos e estado semântico, não apenas o tamanho ou o MD5 comprimido do
arquivo FST.

| Cenário | Chamada | Comparações obrigatórias |
| --- | --- | --- |
| Completo de referência | `get_wlv(method, workers = 1)` | Todos os contratos passam; arquivar arrays, metadados e sidecars. |
| Recálculo desde estágio 1 | `recalc_wlv(method, at_stage = 1, workers = 1)` | Todos os indicadores publicados equivalem ao completo; ausências e estados são idênticos; matrizes e diagnósticos de matriz permanecem inalterados. `sea_vars` seletivo é proibido. |
| Recálculo desde estágio 4 | `recalc_wlv(method, at_stage = 4, workers = 1)` | Indicadores de estágio 4 e seus dependentes equivalem ao completo; indicadores anteriores, matrizes, metadados e sidecars preservados são idênticos. |
| Recálculo desde estágio 5 | `recalc_wlv(method, at_stage = 5, workers = 1)` | Indicadores setoriais de estágio 5 e agregados nacionais equivalem ao completo; estágios anteriores e matrizes são idênticos. |
| Seletivo em estágio 4 ou 5 | `recalc_wlv(method, at_stage = s, sea_vars = vars, workers = 1)` | Células selecionadas são reparadas e equivalem ao completo; toda célula não selecionada e seu estado permanecem exatamente iguais. |
| Sidecar ausente ou inválido | fixture descartável sem o sidecar, com esquema inválido, método/ano incompatível ou limite numérico violado | A operação aborta antes da promoção e a geração anterior permanece byte a byte igual. |
| Matriz ausente ou incompatível | fixture descartável corrompida | Estágios que dependem da matriz abortam; nenhuma geração parcial é publicada. |

Para valores recalculados por soma, “equivale” significa erro menor ou igual ao
limite de redução declarado; rótulos, ausência, zeros estruturais e células não
selecionadas continuam exatos. A comparação deve incluir `sea_sectors`,
`sea_countries`, `m_countries`, todos os `m_io*.fst`, `_states.csv`,
`_scientific_checks.csv`, `_leontief_diagnostics.csv` e o par de sidecars de
GFCF quando aplicável.

O `lambda_fingerprint` é persistido e recalculado a partir de
`sea_sectors/value.m.mv`, com os rótulos canônicos de país-setor, antes de cada
publicação ou recálculo. Isso vincula cada linha anual do diagnóstico ao vetor
de valores efetivamente publicado e rejeita um sidecar obsoleto que descreva
outro `lambda`. O sidecar ainda não contém um fingerprint conjunto do bloco
`C` e do vetor de trabalho direto. Até existir esse manifesto mais amplo, a
comparação com a cópia completa arquivada continua obrigatória para provar a
identidade de todos os insumos entre gerações.

A matriz é imediatamente executável para `wiodr13` e `wiodr16` quando suas
gerações completas publicadas estão disponíveis. `wiodr16v09` e `zerodep_2`
passam pelos mesmos contratos, mas são métodos experimentais: primeiro é
necessário criar sua geração completa com `allow_experimental = TRUE` e repetir
todo o protocolo com essa opção. Não se deve usar o resultado de `wiodr16` como
substituto de baseline para esses dois métodos.
