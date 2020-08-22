#### Valores, preços de mercado e preços diretos
valores <- m.t[lin.produto.total, 1:tamanho]
precos_mercado <- m.wio[lin.produto.total, 1:tamanho]
k <- sum(precos_mercado)/sum(valores)
precos_diretos <-  k * valores

#### Preços de produção
#[K + (A + b.a0)<t>] (I - A - b.a0 - D)-1
print(paste0("calculando precos de producao do ano ",as.character(ano)))
A <- m.wio[1:tamanho,1:tamanho]/matrix(m.wio[lin.produto.total,1:tamanho], nrow = tamanho, ncol=tamanho, byrow = TRUE)
A[is.infinite(A)] <- 0
A[is.nan(A)] <- 0

K <- k.composicao/matrix(m.wio[lin.produto.total,1:tamanho], nrow = tamanho, ncol=tamanho, byrow = TRUE)
K[is.infinite(K)] <- 0
K[is.nan(K)] <- 0

D <- m.depreciacao/matrix(m.wio[lin.produto.total,1:tamanho], nrow = tamanho, ncol=tamanho, byrow = TRUE)
D[is.infinite(D)] <- 0
D[is.nan(D)] <- 0

# t <- diag(tamanho)
# t[is.infinite(t)] <- 0
# t[is.nan(t)] <- 0

I <- diag(tamanho)

prop_demanda_familias <- as.data.frame(prop.table(m.wio[1:tamanho,col.demanda.final], margin = 2))
prop_demanda_familias <- as.matrix(prop_demanda_familias[rep(names(prop_demanda_familias), each = num.setores)])
b.a0 <- (matrix(lab.usd, ncol = tamanho, nrow = tamanho, byrow = TRUE)*prop_demanda_familias)/matrix(m.wio[lin.produto.total,1:tamanho], nrow = tamanho, ncol=tamanho, byrow = TRUE)
b.a0[is.infinite(b.a0)] <- 0
b.a0[is.nan(b.a0)] <- 0

inversa <- solve(I -A -b.a0 -D)
#[K + (A + b.a0)<t>] (I - A - b.a0 - D)-1 -> turnover => 1 por ano
t <- diag(tamanho)
prec_prod <- eigen(t((K + (A+b.a0)%*%t ) %*% inversa))

ro <- 1/Re(prec_prod[["values"]][1])
prec_prod <- Re(prec_prod[["vectors"]][,1])

k <- sum(m.wio[lin.produto.total,1:tamanho])/sum(m.wio[lin.produto.total,1:tamanho]*prec_prod)
prec_prod <- k*prec_prod*m.wio[lin.produto.total,1:tamanho]


#[K + (A + b.a0)<t>] (I - A - b.a0 - D)-1 -> turnover => 2 por ano
t <- diag(0.5, tamanho)
prec_prod2 <- eigen(t((K + (A+b.a0)%*%t ) %*% inversa))

ro2 <- 1/Re(prec_prod2[["values"]][1])
prec_prod2 <- Re(prec_prod2[["vectors"]][,1])

k <- sum(m.wio[lin.produto.total,1:tamanho])/sum(m.wio[lin.produto.total,1:tamanho]*prec_prod2)
prec_prod2 <- k*prec_prod2*m.wio[lin.produto.total,1:tamanho]



print("Fim do calculo")

#### Preços diretos com base nacional
k_n = produto_total_t_pais = produto_total_m_pais <- matrix(0,1,num.paises)
for (x in 1:num.paises){
  #Produto total em horas de trabalho e em moeda (soma dos setores produtivos)
  produto_total_t_pais[x] <- sum(m.t[lin.produto.total, which(pais.cols==x)])
  produto_total_m_pais[x] <- sum(m.wio[lin.produto.total, which(pais.cols==x)])
  
  #Variável K para o cálculo dos preços diretos (base nacional)
  k_n[x] <- produto_total_m_pais[x]/produto_total_t_pais[x]
}

precos_diretos_n <- valores * rep(k_n, each=num.setores)