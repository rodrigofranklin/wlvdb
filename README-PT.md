#Resumo

Projeto de ciência aberta para desenvolver, implementar e melhorar metodologias para obter valores (marxistas, sraffianos ...) e categóricos estima baseados em informações públicas de nível mundial, como matrizes de saída de entrada mundial, Klems, Cepal Io Data. Extensões adicionais para incluir a exiobase, melhores estimativas disponíveis para mais países. 

Ao usar os dados, solicitamos citar: 

FRANKLIN, R.;BORGES, R,; SÁNCHEZ, C.; MONTIBELER, E. Skilled labour and the reduction problem: questioning the exploitation rate equalization hypoyhesis. _World Review of Political Economy_ (no prelo), 2022.

Também inclui estimativas preliminares em: 

- Troca desigual; 
- taxas de exploração; 
- Taxas de lucro; 
- Diferentes aproximações aos valores — preços diretos, valores em tempo de trabalho abstrato e preços sraffianos.

## Suporte de métodos e fontes

A cobertura temporal e as operações disponíveis estão na
[matriz canônica de suporte](docs/methods.md). WIOD13 e WIOD16 são as famílias
recuperadas; `wiodr13` e `wiodr16` são os únicos métodos executáveis nesta
entrega. As definições alternativas ficam preservadas para incorporação
posterior, com cálculo e recálculo bloqueados mesmo com opt-in experimental.
As fontes EXIOBASE e EORA são experimentais, e seus
métodos permanecem desabilitados até que a recuperação seja concluída.

## Inicialização segura e função principal

Abrir o projeto não instala pacotes, não atualiza o checkout Git, não restaura
um workspace salvo e não inicia cálculos. Na raiz do repositório, restaure uma
vez as versões exatas dos pacotes e execute um método explicitamente:

```sh
Rscript --vanilla scripts/bootstrap.R
Rscript --vanilla scripts/run_wlv.R --method wiodr13
```

O bootstrap restaura o `renv.lock`; ele não baixa os dados econômicos de
origem. Para trabalhar interativamente depois do bootstrap, ative a biblioteca
do projeto e carregue as funções principais de forma explícita:

```r
source("renv/activate.R")
bootstrap <- new.env(parent = baseenv())
sys.source("R/bootstrap.R", envir = bootstrap)
wlv <- bootstrap$wlv_load_runtime(".")
wlv$get_wlv("wiodr13")
```

Use `Rscript --vanilla scripts/run_wlv.R --help` para ver todas as opções da
linha de comando, ou acrescente `--check` para validar o ambiente e o método
sem iniciar cálculos.

### Função get_wlv 

**get_wlv** é uma função que executa todos os cálculos e grava arquivos para a pasta de resultados com todas as variáveis e matrizes com país e contas socioeconômicas setoriais (sea_countries e sea_sectors). 

Por exemplo, para calcular o método padrão atual com dados do WIOD13, execute
`wlv$get_wlv("wiodr13")` no runtime privado retornado pelo bootstrap acima.
`R/main.R` contém definições e não deve ser carregado diretamente.

A função aceita os seguintes argumentos: 

* methods - uma string ou um vetor de caracteres como `c("wiodr13", "wiodr16")` para os métodos a serem calculados. Por padrão, `"wiodr13"`
* repeat_pp - Verdadeiro/Falso para indicar se o download completo e a preparação de dados de origem devem ser executados. Por padrão, falso 
* papern, prepaper - argumentos descontinuados, preservados somente nos valores padrão (`0`, `FALSE`) para compatibilidade das chamadas; a geração de papers foi removida e pedidos para ativá-la falham antes do cálculo
* workers - inteiro positivo que controla os workers PSOCK. O padrão é `1`, que executa sequencialmente sem criar cluster
* channel - canal de publicação em minúsculas, como `stable` ou `research/input-v3`
* allow_experimental - opt-in explícito para capacidades experimentais; não habilita métodos cujo cálculo ou recálculo esteja bloqueado

## Estrutura de pastas/ organização do repositório 

###1) source_data - a ser baixada em separado - [link aqui] (https://coletiva.imperialismoedependencia.org/s/wjMfkBXDnptADXF) 

Pasta com dados baixados das fontes primárias de insumo-produto, em subpastas de acordo com a fonte. 

Os dados nesta pasta também são formatados para manter uma estrutura tratável de diferentes fontes para o mesmo fluxo de processamento.

### 2) Catálogo e configuração

`catalog/` declara fontes, métodos, capacidades, perfis de validação e contratos
públicos. `config/modules/` compõe instâncias nativas de método, fonte e
`common` com operações tipadas `add`, `replace` e `remove`.
`config/aggregations/` declara os perfis históricos de agregação. Os CSVs
contêm apenas identificadores e argumentos tipados; caminhos executáveis,
expressões R e ordem semântica não fazem parte da configuração.

### 3) Métodos


O primeiro artigo produzido, e de referência, mostra como a mesma fonte pode ser trabalhada com métodos diferentes. Nesse caso, diferentes métodos para converter o tempo de trabalho concreto ao tempo de trabalho abstrato. 

Uma das características do Banco de Dados de Valores Trabalho Mundiais é a facilidade de criar, aplicar e comparar diferentes métodos para estimativa de categorias. Como tal, fornece complemento subsidiário para discussões teóricas.

As subpastas em `methods/` contêm metadados, parâmetros e classificações
setoriais. O comportamento científico executável é registrado como funções
nativas em `R/modules/native/`; a ordem vem do grafo de dependências compilado,
nunca da posição das linhas nos CSVs.

###4) results - a ser baixado em separado caso se queira verificar os resultados já produzidos pela nossa equipe - [Link aqui] (https://coletiva.imperialismodependencia.org/s/nmmdymxl8fwxfjq) 

Os resultados são runs imutáveis em `results/runs/<método>/<run_id>/`.
Releases em `results/releases/` fixam conjuntos coerentes, e marcadores
append-only em `results/channels/<canal>/` selecionam a release corrente.

### 5) Runtime R

O bootstrap determinístico carrega definições de função de `R/lib/`,
`R/modules/native/`, `R/preparation/` e `R/main.R` em um único namespace
privado e bloqueado. Módulos científicos recebem entradas, argumentos e
serviços injetados por contexto explícito; executores legados baseados em
`source()` não fazem parte do runtime alcançável.
