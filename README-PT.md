#Resumo

Projeto de ciência aberta para desenvolver, implementar e melhorar metodologias para obter valores (marxistas, sraffianos ...) e categóricos estima baseados em informações públicas de nível mundial, como matrizes de saída de entrada mundial, Klems, Cepal Io Data. Extensões adicionais para incluir a exiobase, melhores estimativas disponíveis para mais países. 

Ao usar os dados, solicitamos citar: 

FRANKLIN, R.;BORGES, R,; SÁNCHEZ, C.; MONTIBELER, E. Skilled labour and the reduction problem: questioning the exploitation rate equalization hypoyhesis. _World Review of Political Economy_ (no prelo), 2022.

Também inclui estimativas preliminares em: 

- Troca desigual; 
- taxas de exploração; 
- Taxas de lucro; 
- Diferente aproximação aos valores - preços diretos, valores em tempo de trabalho abstrato, preços sraffianos disponíveis por região, país e setor de 1995 a 2014, ou de 1990 a 2024, dependendo da fase atual da inclusão da fonte ao projeto

##Fontes de dados já incluídas: 

- Banco de Dados Mundial de Insumo-Produto, release 2013  (WIOD13) 
- Banco de Dados Mundial de Insumo-Produto, release 2016 (WIOD16) 
- Exiobase (V 3.8.2, v. 3.7, V.3.8.1) * 
- EORA26 *

 * Trabalho em andamento 

## Início automático e função principal 

Quando o projeto é aberto, ele automaticamente: 

- detecta quais pacotes não estão instalados, e os instala silenciosamente; 
- Executa o script R/main.r, que carrega a função  ** get_wlv ** 
- fornece uma mensagem de boas-vindas 

### Função get_wlv 

**get_wlv** é uma função que executa todos os cálculos e grava arquivos para a pasta de resultados com todas as variáveis e matrizes com país e contas socioeconômicas setoriais (sea_countries e sea_sectors). 

Por exemplo, para calcular o método padrão atual com dados do WIOD16, só é necessário executar

ˋget_wlv("WIOD16")ˋ 

A função aceita os seguintes argumentos: 

* methods - uma string ou um vetor de caracteres como ˋc("WIOD13", "WIOD16")ˋ   para os métodos a serem calculados. Por padrão  "WIOD13" 
* repeat_pp - Verdadeiro/Falso para indicar se o download completo e a preparação de dados de origem devem ser executados. Por padrão, falso 
* paper - número do papel para complementarmente computar tabelas e / ou gráficos que comparem diferentes métodos, indicadores transversais e longitudinais, ou seja, qualquer análise personalizada a ser incluída no trabalho referido pelo mesmo número. 
* prepaper - Verdadeiro/Falso - se desencadear, de fato, a preparação de tal análise personalizada (realizando a chamada correspondente nos script da pasta *papers*) 

## Estrutura de pastas/ organização do repositório 

###1) source_data - a ser baixada em separado - [link aqui] (https://coletiva.imperialismoedependencia.org/s/wjMfkBXDnptADXF) 

Pasta com dados baixados das fontes primárias de insumo-produto, em subpastas de acordo com a fonte. 

Os dados nesta pasta também são formatados para manter uma estrutura tratável de diferentes fontes para o mesmo fluxo de processamento.

###2) parameters

Poucos parâmetros em arquivos csv para fácil edição, organizados em subpastas, uma de parâmetros globais (subpasta common_ground) e parâmetros gerais para cada fontes primária de IO para cada fonte, por exemplo "WIOD13"

Em geral, os seguintes arquivos: 

* _source_assumptions.csv - indica como lidar para estimar informações importantes (e ausentes da fonte), atualmente informação do trabalho sobre o Resto do Mundo e da China  
* _source_matrices.csv - indica como lidar principalmente para inferir matrizes de capital e depreciação 
* _source_solutions.csv - indica variáveis a serem calculadas e procedimento correspondente a ser chamado para sua estimativa, a serem usados se nenhuma definição específica diferente for fornecida em qualquer método que use tal ou qual fonte de origem 

###3)  method- lib
- modules
  - assumptions
  - matrices
  - reduced_matrices
  - variables
-utils


O primeiro artigo produzido, e de referência, mostra como a mesma fonte pode ser trabalhada com métodos diferentes. Nesse caso, diferentes métodos para converter o tempo de trabalho concreto ao tempo de trabalho abstrato. 

Uma das características do Banco de Dados de Valores Trabalho Mundiais é a facilidade de criar, aplicar e comparar diferentes métodos para estimativa de categorias. Como tal, fornece complemento subsidiário para discussões teóricas.

As subpastas em métodos referem-se a um método específico. Sua estrutura é semelhante a parâmetros: 

* _method_assumptions.csv - indica como lidar para estimar informações importantes (e ausentes da fonte), atualmente informação do trabalho sobre o Resto do Mundo e da China  
* _method_matrices.csv - indica como lidar principalmente para inferir matrizes de capital e depreciação 
* _method_solutions.csv - indica variáveis a serem calculadas e procedimento correspondente a ser chamado para sua estimativa, a serem usados se nenhuma definição específica diferente for fornecida em qualquer método que use tal ou qual fonte de origem 

###4) results - a ser baixado em separado caso se queira verificar os resultados já produzidos pela nossa equipe - [Link aqui] (https://coletiva.imperialismodependencia.org/s/nmmdymxl8fwxfjq) 

Os resultados dos cálculos são salvos como arquivos em subpastas nomeadas pelo método que os gerou. As variáveis são salvas em: arquivos M_IO  (em valores, por ex) por setor ou nacionais m_countries,, contas socioeconômicas setoriais(sea_sectors) e nacionais (sea_countries)

###5) papers 

Pasta com 1 arquivo de script para cada paper, identificado por um número. 

Para alguma análise, ensaio, é geralmente necessário algum novo processamento dos resultados, dado seu volume: pode-se filtrar alguns indicadores, regiões e produzir novos cálculos - ver, por exemplo, o ensaio referido.

###6) scripts

Pasta com scripts em R, organizados em:
 - lib
- modules
  - assumptions
  - matrices
  - reduced_matrices
  - variables
-utils
 
  
  Cada subpasta está estruturada em scripts comuns e de origem ou método específicos.