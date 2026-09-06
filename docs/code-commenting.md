# Convenção dos comentários científicos

Revisão documental: `wiod-consolidation-v1`. Esta convenção acompanha os
[guias em português](guide-pt.md) e [inglês](guide-en.md) e a
[política de sincronização](documentation-sync.md).

Os comentários do percurso executável WIOD13/WIOD16 são escritos em português,
com acentos e UTF-8, para economistas marxistas iniciantes em programação.
Identificadores e mensagens já existentes continuam em sua língua original.
As explicações extensas pertencem aos guias bilíngues; a explicação local fica
junto à operação cuja leitura ela facilita. Ao alterar uma fórmula, hipótese,
unidade, política de ausência ou dependência, revise conjuntamente código,
comentário, guias e dicionários nos dois idiomas. Não traduza um guia deixando
o outro com uma regra científica antiga.

Cada bloco científico deve responder, conforme aplicável:

1. Que grandeza econômica calcula e para qual etapa ela serve?
2. Quais entradas usa, o que devolve, quais eixos e unidades preserva?
3. Como ler a fórmula em palavras, inclusive numerador e denominador?
4. Que hipótese transforma observações em estimativas?
5. O que significam zero, ausência e limites numéricos neste ponto?
6. Quais resultados dependem desta operação, inclusive no recálculo?

Uma fábrica compartilhada documenta sua fórmula comum; funções que somente a
instanciam ficam cobertas por essa explicação e por seus argumentos e metadados.
Isso evita repetir a mesma regra em dezenas de indicadores. Auxiliares puramente
estruturais recebem explicação quando sua orientação ou seu contrato interfere
na interpretação científica. Código histórico de métodos desabilitados não é
apresentado como suporte atual.

Terminologia: SEA são as contas socioeconômicas; WIOT é a tabela mundial de
insumo-produto; ROW é o resto do mundo, uma região incluída nas contas; WWW é o
agregado mundial, que não deve ser somado novamente aos países. `emp` designa
todas as pessoas ocupadas e `empe`, empregados. Setor produtivo é uma classificação
metodológica explícita nos metadados, não um julgamento sobre a utilidade social
da atividade. Valor em `mv` é a magnitude estimada de trabalho abstrato; dólares
a preços de mercado e dólares a preços diretos não são a mesma medida.

Orientação: uma matriz anual de insumo-produto tem fornecedores nas linhas
(`input`) e usuários/demandas nas colunas (`output`). Os indicadores setoriais
internos usam ano × setor × país; a publicação acrescenta o eixo indicador.
Por exemplo, a célula BRA.agricultura → ARG.indústria é uma entrega brasileira
para uso argentino. `rowSums` soma destinos; `colSums` soma origens. Unidades e
escalas vêm dos contratos versionados, não apenas do sufixo do identificador.

Zeros só devem ser descritos como observações quando forem observados. Hipóteses
que os introduzem precisam ser nomeadas. `NA` pode ser ausência de fonte,
inaplicabilidade ou outra condição registrada no estado semântico; `na.rm=TRUE`
descreve uma operação numérica e não demonstra cobertura completa. Uma razão
0/0 não é universalmente zero. Na ausência de uma regra contratual específica,
não invente uma justificativa para o comportamento: registre o limite ou abra
um defeito separado.

Comentários explicativos não alteram expressões R, dados, metadados executáveis
ou constantes. A verificação pode comparar `parse(..., keep.source=FALSE)` antes
e depois, separando as alterações científicas autorizadas em outros issues.
O mapa de cobertura e a evidência desta revisão estão em
[issue-30.md](validation/issue-30.md).
