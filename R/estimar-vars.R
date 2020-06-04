##Variáveis básicas e análise


####################################
# Calcula as variáveis que eu quero
#####################################
# Primeiro, aloca o espaço de todas as variáveis desejadas

cols <- max(paiscols[])

exportacaompais <- matrix(0,cols,cols)
exportacaotpais <- matrix(0,cols,cols)

fatordinn = produtototalmpais = produtototaltpais <- matrix(0,1,cols)

pibtpais <- matrix(0,1,cols)
pibmpais <- matrix(0,1,cols)

fatordemanda = demandafinaltpais <- matrix(0,1,cols)
demandafinalmpais <- matrix(0,1,cols)

trabalhadorespais <- matrix(0,1,cols)
remuneracaotpais <- matrix(0,1,cols)
remuneracaompais <- matrix(0,1,cols)
remuneracaorealpais <- matrix(0,1,cols)

jornadatotalpais <- matrix(0,1,cols)
assalariadospais <- matrix(0,1,cols)
salariotpais <- matrix(0,1,cols)
salariompais <- matrix(0,1,cols)
salariorealpais <- matrix(0,1,cols)

lucrompais <- matrix(0,1,cols)
lucrotpais <- matrix(0,1,cols)

capitalmpais <- matrix(0,1,cols)
fbcfmpais <- matrix(0,1,cols)
fbcftpais <- matrix(0,1,cols)
consumointermediarioppais <- matrix(0,1,cols)
capitalconstantetotalpais <- matrix(0,1,cols)
insumoprodutivospais <- matrix(0,cols,cols)

for (p in 1:num_paises){
  #Produto total em horas de trabalho e em moeda (soma dos setores produtivos)
  x <- colprods[which(paiscols[colprods]==p)]
  produtototaltpais[p] <- sum(mt[linprodutototal,x])
  produtototalmpais[p] <- sum(m[linprodutototal, x])
  
  # Valor agregado total em horas de trabalho e em moeda (dos setores produtivos).
  # O valor agregado (valor novo criado) em termos de horas de trabalho consiste
  # na soma das horas trabalhadas nos setores produtivos.
  pibtpais[p] <- sum(trabalho[x])
  # O valor agregado em termos de moeda consiste no produto total menos o custo intermediário.
  # Obs: é preciso deduzir também a depreciação do capital. Além disso, deveríamos somar a margem de comércio.
  pibmpais[p] <- sum(m[linprodutototal, x]- m[linconsumointermediario, x])
  
  # Número de pessoas engajadas na produção e sua remuneração (nominal e real)
  trabalhadorespais[p] <- sum(emp[x])
  remuneracaompais[p] <- sum(lab_usd[x])
  remuneracaorealpais[p] <- sum(lab_real[x])
  
  # Número de trabalhadores assalariados, jornada de trabalho total e remuneração total (nominal e real)
  jornadatotalpais[p] <- sum(h_empe[x])
  assalariadospais[p] <- sum(empe[x])
  salariompais[p] <- sum(comp_usd[x])
  salariorealpais[p] <- sum(comp_real[x])
  
  # Compensação do capital e estoque de capital
  lucrompais[p] <- sum(cap_usd[x])
  capitalmpais[p] <- sum(k_usd[x])
  
  consumointermediarioppais[p] <- sum(m[linconsumointermediario, x])
                                        
  # Soma os consumos intermediários produtivos em variáveis temporárias (Capital constate = trabalho, insumo produtivo = moeda)
  capitalconstantetotalpais[p] <- sum(mt[linprods, x])

  # Soma a formação bruta de capital fixo (em moeda e trabalho) e acrescenta aos insumos produtivos
  xfbcf <- colfbcf[which(paiscols[colfbcf]==p)]
  fbcfmpais[p] <- sum(m[linprods, xfbcf])
  fbcftpais[p] <- sum(mt[linprods, xfbcf])

  for (py in 1:num_paises) {
    y <- linprods[which(paislins[linprods]==py)]
    insumoprodutivospais[py,p] <- sum(m[y, x], m[y,xfbcf])

    #Soma todas as exportações dos setores produtivos (todos os destinos de cada linha de setor produtivo)
    if (p != y) { #ignora as transações internas de cada país
      exportacaompais[py,x]<- sum(m[y,which(paiscols==p)])
      exportacaotpais[py,x]<- sum(mt[y,which(paiscols==p)])
    }
  }

  # Soma a demanda final em moeda e trabalho
  xdemandafinal <- coldemandafinal[which(paiscols[coldemandafinal]==p)]
  demandafinaltpais[x] <- sum(mt[1:tamanho, xdemandafinal])
  demandafinalmpais[x] <- sum(m[1:tamanho, xdemandafinal])

  # Capital Constante total por pais (Para o cálculo da composição orgânica)
  # Esse cálculo soma o estoque de capital (ponderado pela estrutura da formação bruta de k fixo) em horas de trabalho
  capitalconstantetotalpais[p] <- ((capitalmpais[p]/fbcfmpais[p])*fbcftpais[p])+capitalconstantetotalpais[p]
  
  # O fatordinn corresponde à constate K de Ochoa para o cálculo dos preços diretos
  fatordinn[p] <- produtototaltpais[p]/produtototalmpais[p]
  # O fatordemanda é uma espécide de constate K exclusiva para o consumo das famílias.
  # Por isso, a utilizei para o cálculo do valor da força de trabalho
  fatordemanda[p] <- demandafinaltpais[p]/demandafinalmpais[p]
  
  # Calcula as rendas em trabalho de cada país usando fatordemanda
  # (das pessoas engajadas e dos trabalhadores assalariados)
  remuneracaotpais[p]<- sum(lab_usd[x])*fatordemanda[p]
  salariotpais[p]<- sum(comp_usd[x])*fatordemanda[p]
}

#Calcula saldo das transferências pelo Fator Dinheiro mundial - DECIDI
#APRESENTAR OS SALDOS DE HORAS ExPORTADAS E ImPORTADAS, ASSIm COmO OS
#SALDOS mONETÁRIOS ExPORTADOS E ImPORTADOS.

# A importação é a transposta da exportação
importacaompais <- t(exportacaompais)
importacaotpais <- t(exportacaotpais)

# Calcula o total por país
expottotalpais <- colsums(importacaotpais)
expomtotalpais <- colsums(importacaompais)
impottotalpais <- colsums(exportacaotpais)
impomtotalpais <- colsums(exportacaompais)

# Calculando o saldo de transferências utilizando o fator H/$ das
# exportações do mundo todo (Novamente, um tipo de variável K específica do comércio mundial)
fatorsaldo <- sum(exportacaotpais)/sum(exportacaompais)

transferenciapais <- (exportacaompais*fatorsaldo)-exportacaotpais+importacaotpais-(importacaompais*fatorsaldo)
transferenciapais <- t(transferenciapais)
transftotalpais <- as.matrix(colsums(transferenciapais))

# Composição Orgânica
# cox -> composição orgânica ponderada pelas exportações
# coi -> composição orgânica ponderada pelas importações
y <- ncol(m)

exp_setor <- matrix(0,nrow = y, ncol = num_paises)
exp_total <- matrix(0,nrow = 1, ncol = num_paises)
imp_setor <- matrix(0,nrow = y, ncol = num_paises)
imp_total <- matrix(0,nrow = 1, ncol = num_paises)

coxk <- matrix(0,nrow = 1, ncol = num_paises)
coxt <- matrix(0,nrow = 1, ncol = num_paises)
cox <- matrix(0,nrow = 1, ncol = num_paises)

coik <- matrix(0,nrow = 1, ncol = num_paises)
coit <- matrix(0,nrow = 1, ncol = num_paises)
coi <- matrix(0,nrow = 1, ncol = num_paises)

#Não lembro para que isso serve...
#CORELK <- matrix(0,nrow = num_paises, ncol = num_paises)
#CORELT <- matrix(0,nrow = num_paises, ncol = num_paises)
#COREL <- matrix(0,nrow = num_paises, ncol = num_paises)

#cols <- ncol(m)-1 # -1 para desconsiderar a coluna do produto total

#for (y in linprods) {
#  for (x in 1:cols) {
#    if (paislins[y] != paiscols[x]) {
#      exp_setor[y,paislins[y]] = exp_setor[y,paislins[y]] + m[y,x]
#      exp_total[paislins[y]] = exp_total[paislins[y]] + m[y,x]
#      imp_setor[y,paiscols[x]] = imp_setor[y,paiscols[x]] + m[y,x]
#      imp_total[paiscols[x]] = imp_total[paiscols[x]] + m[y,x]
#    }
#  }
#}

#for (y in linprods) {
#  for (x in paises[,2]) {
#    if (paislins[y] == x) {
#      # Pondera a participação do capital e do trabalho conforme a importância do setor para as exportações do país
#      sigma = exp_setor[y,x] / exp_total[x]
#      coxk[1,x] = coxk[1,x] + ((k_usd[y] + m[linconsumointermediario,y]) * sigma)
#      coxt[1,x] = coxt[1,x] + (H_emp[y] * sigma)
#    } else {
#      # Pondera a participação do capital e do trabalho conforme a importância do setor para as importações do país
#      sigma = imp_setor[y,x] / imp_total[x]
#     coik[1,x] = coik[1,x] +((k_usd[y] + m[linconsumointermediario,y]) * sigma)
#      coit[1,x] = coit[1,x] + (H_emp[y] * sigma)
#      #      CORELK[paislins[y],x] = CORELK[paislins[y],x] + ((k_usd[y] + m[linconsumointermediario,y]) * sigma)
#      #      CORELT[paislins[y],x] = CORELT[paislins[y],x] + (H_emp[y] * sigma)
#    }
#  }
#}

#COREL = CORELK./CORELT

# Formatação do resultado
resultados <- matrix(0, nrow = 28, ncol = num_paises, dimnames = list(c("","expottotalpais",
                                                                        "expomtotalpais","impottotalpais","impomtotalpais","transftotalpais","produtototaltpais","produtototalmpais",
                                                                        "fatordinn","fatordemanda","pibtpais","pibmpais","trabalhadorespais","remuneracaotpais","remuneracaompais",
                                                                        "remuneracaorealpais","jornadatotalpais","assalariadospais","salariotpais","salariompais","salariorealpais",
                                                                        "lucrompais","capitalmpais","consumointermediarioppais","coxk","coxt","coik","coit"),paises[,1]))
#resultados[1,] <- 
resultados[2,] <- expottotalpais
resultados[3,] <- expomtotalpais
resultados[4,] <- impottotalpais
resultados[5,] <- impomtotalpais
resultados[6,] <- transftotalpais
resultados[7,] <- produtototaltpais
resultados[8,] <- produtototalmpais
resultados[9,] <- fatordinn
resultados[10,] <- fatordemanda
resultados[11,] <- pibtpais
resultados[12,] <- pibmpais
resultados[13,] <- trabalhadorespais
resultados[14,] <- remuneracaotpais
resultados[15,] <- remuneracaompais
resultados[16,] <- remuneracaorealpais
resultados[17,] <- jornadatotalpais
resultados[18,] <- assalariadospais
resultados[19,] <- salariotpais
resultados[20,] <- salariompais
resultados[21,] <- salariorealpais
resultados[22,] <- lucrompais
resultados[23,] <- capitalmpais
resultados[24,] <- consumointermediarioppais
resultados[25,] <- coxk
resultados[26,] <- coxt
resultados[27,] <- coik
resultados[28,] <- coit
resultados= t(resultados)
