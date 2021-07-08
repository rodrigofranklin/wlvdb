## Calcula as transferências de valor resultantes do comércio internacional

# Dimensões da matriz insumo-produto abordades neste script
x <- 1:num_paises_setores
y <- 1:(num_output-1)

#### Vetor anual de fator_saldo.
# fator_saldo = fator para converter os preços de mercado em horas de trabalho.
# (O processo inverso dos preços diretos, ou seja, essa conversão permite 
# mostrar quanto de trabalho que a quantidade de moeda trocada deveria 
# representar). Anteção, esse fator é calculado apenas com o saldo das trocas
# internacionais, desse modo, ele se torna mais adequado para avaliar o comércio
# internacional, mas não pode ser utilizado para análise das trocas internas.
# Cálculo: (soma dos valores das exportações) / (soma dos preços das 
# exportações produtivas)
fator_saldo <- 
  (m_io[,"valores",x,y] * 
     (m_io_filtros["comercio",x,y] %>% rep(each = num_anos))) %>% 
  apply (1, sum, na.rm = TRUE) /
  (m_io_fonte[,x,y] *
     ((m_io_filtros["comercio",x,y] * 
         m_io_filtros["setores_produtivos",x,y]) %>% rep(each = num_anos))) %>%
  apply (1, sum, na.rm = TRUE)

#### Calcula as matrizes contendo as transferências setoriais brutas.
# As transferências setorias brutas são calculadas deduzindo as transações
# internacionais em valores do quanto que as transações internacionais em 
# preços representam em termos de valores (ie. inverso de preços diretos).
# ATENÇÃO: ESSAS TRANSFERÊNCIAS INCLUEM A TROCA DESIGUAL E A APROPRIAÇÃO DOS
# SETORES IMPRODUTIVOS. Para separar os dois efeitos, deve-se aplicar o filtro
# "setores_produtivos".
m_io[,"transferencias_valores",x,y] <-
  (m_io_fonte[,x,y] * 
     (m_io_filtros["comercio",x,y] %>%  rep(each = num_anos)) * 
     fator_saldo) -
  (m_io[,"valores",x,y] * 
     (m_io_filtros["comercio",x,y] %>% rep(each = num_anos)))

#### Reduz as matrizes input-output para matrizes de países.
# Observe que é necessário salvar várias matrizes de países x países, pois não
# é possível manipular as informações.
print("Inicio da reducao das matrizes IxO:")

# filtro para eliminar o comércio interno
filtro <- rep(1-diag(num_paises), each = num_anos)


# Exportações em valores ----
print("Exportacoes em valores...")
m_paises[,"exportacoes_valores",,] <- 
  parApply( 
    cl = my.cluster,
    m_io[,"valores", x, y], 1,
    tapply, m_io_filtros["paises", x, y], sum, na.rm = TRUE
  ) %>% aperm(c(2,1)) * filtro

# Exportações em preços de mercado ----
print("Exportacoes em precos de mercado...")
m_paises[,"exportacoes_pm",,] <- 
  parApply(
    cl = my.cluster,
    m_io_fonte[, x, y], 1,
    tapply, m_io_filtros["paises", x, y], sum, na.rm = TRUE
  ) %>% aperm(c(2,1)) * filtro

# Exportações produtivas em preços de mercado ----
print("Exportacoes produtivas em precos de mercado...")
m_paises[,"exportacoes_produtivas_pm",,] <- 
  parApply(
    cl = my.cluster,
    m_io_fonte[, x, y] * 
      (m_io_filtros["setores_produtivos", x, y] %>% rep(each = num_anos)), 1,
    tapply, m_io_filtros["paises", x, y], sum, na.rm = TRUE
  ) %>% aperm(c(2,1)) * filtro

# Transferências totais em valores ----
print("Transferencias totais em valores...")
m_paises[,"transferencias_valores",,] <- 
  parApply( 
    cl = my.cluster,
    m_io[,"transferencias_valores", x, y], 1,
    tapply, m_io_filtros["paises", x, y], sum, na.rm = TRUE
  ) %>% aperm(c(2,1)) * filtro

# Transferências dos setores produtivos em valores ----
# TROCA DESIGUAL
print("Transferencias dos setores produtivos em valores...")
m_paises[,"transferencias_produtivas_valores",,] <- 
  parApply(
    cl = my.cluster,
    m_io[,"transferencias_valores", x, y] * 
      (m_io_filtros["setores_produtivos", x, y] %>% rep(each = num_anos)), 1,
    tapply, m_io_filtros["paises", x, y], sum, na.rm = TRUE
  ) %>% aperm(c(2,1)) * filtro

# Transferências totais em preços diretos ----
m_paises[,"transferencias_pd",,] <-
  m_paises[,"transferencias_valores",,] / fator_saldo

# Transferências dos setores produtivos em preços diretos ----
m_paises[,"transferencias_produtivas_pd",,] <-
  m_paises[,"transferencias_produtivas_valores",,] / fator_saldo

print("Fim da reducao.")
