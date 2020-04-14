#####################################
#
# Script para exigição de gráficos 
# com os principais resultados
#
#####################################


#####
# Carrega todos os resultados em uma única matriz 3D (ano, país, variável)


# Cria a lista de países
Paises <- c("Austrália","Áustria",
            "Bélgica","Bulgária","Brasil","Canadá","China","Chipre","Tchéquia","Alemanha","Dinamarca","Espanha",
            "Estônia","Finlândia","França","Reino Unido","Grécia","Hungria","Indonésia","Índia","Irlanda","Itália",
            "Japão","Coreia do Sul","Lituânia","Luxemburgo","Letônia","México","Malta","Países Baixos","Polônia",
            "Portugal","Romênia","Federação Russa","Eslováquia","Eslovênia","Suécia","Turquia","Taiwan",
            "Estados Unidos","Mundo")
# Aloca a matriz de resultados
Resultados <- array(data = 0,dim = c(17,41,28), dimnames = list(c(1995:2011),
                                                  Paises,
                                                  c("","ExpoTTotalPais",
                                                    "ExpoMTotalPais","ImpoTTotalPais","ImpoMTotalPais","TransfTotalPais","ProdutoTotalTPais","ProdutoTotalMPais",
                                                    "FatorDINN","FatorDemanda","PIBTPais","PIBMPais","TrabalhadoresPais","RemuneracaoTPais","RemuneracaoMPais",
                                                    "RemuneracaoRealPais","JornadaTotalPais","AssalariadosPais","SalarioTPais","SalarioMPais","SalarioRealPais",
                                                    "LucroMPais","CapitalMPais","ConsumoIntermediarioPPais","COXK","COXT","COIK","COIT")))
# Lê os resultados dos arquivos .csv
for (Z in 1995:2011) {
  Resultados[as.character(Z),,] <- as.matrix(read.csv2(file = paste0(getwd(),"/Resultados/Resultados",as.character(Z),".csv"), row.names = 1))
}
#####

plot((Resultados[,"Brasil",'JornadaTotalPais']-Resultados[,"Brasil",'SalarioTPais'])/Resultados[,"Brasil",'SalarioTPais'],type = "l")


#VFT <- teste[,Pais,'SalarioTPais']/teste[,Pais,'AssalariadosPais']
#JORNADA <- teste[,Pais,'JornadaTotalPais']/teste[,Pais,'AssalariadosPais']
#if (Pais=='China'){
#}


#Taxa de exploração baseada em pessoas engajadas (menor do que a taxa de exploração de fato)
for (Pais in Paises) {
  VFT <- Resultados[,Pais,'RemuneracaoTPais']/Resultados[,Pais,'TrabalhadoresPais']
  JORNADA <- Resultados[,Pais,'PIBTPais']/Resultados[,Pais,'TrabalhadoresPais']
  plot(VFT,
     type = "l",
     ylim = c(min(VFT,JORNADA),max(JORNADA,VFT)),
     main = paste('Evolução da taxa de exploração (pessoas engajadas) -',Pais),
     xaxt="n",
     lty="dotted", lwd=3, col="red")
  lines(JORNADA,lty="solid", lwd=3)
  axis(side=1,1:17,as.character(1995:2011))
  
  polygon(c(1:17,17:1),c(JORNADA,VFT[17:1]),col="gray")
}

#Taxa de exploração de fato (trabalhadores assalariados)
for (Pais in Paises) {
  VFT <- Resultados[,Pais,'SalarioTPais']/Resultados[,Pais,'AssalariadosPais']
  JORNADA <- Resultados[,Pais,'JornadaTotalPais']/Resultados[,Pais,'AssalariadosPais']
  if (Pais=='China' || Pais=='Mundo'){
    VFT <- Resultados[,Pais,'RemuneracaoTPais']/Resultados[,Pais,'TrabalhadoresPais']
    JORNADA <- Resultados[,Pais,'PIBTPais']/Resultados[,Pais,'TrabalhadoresPais']
  }
  plot(VFT,
       type = "l",
       ylim = c(min(VFT,JORNADA),max(JORNADA,VFT)),
       main = paste('Evolução da taxa de exploração (trabalhadores assalariados) -',Pais),
       xaxt="n",
       lty="dotted", lwd=3)
  lines(JORNADA,lty="solid", lwd=3)
  axis(side=1,1:17,as.character(1995:2011))
  
  polygon(c(1:17,17:1),c(JORNADA,VFT[17:1]),col="gray")
}

for (Pais in Paises) {
  Transferencias <- Resultados[,Pais,"TransfTotalPais"]/1000000
  plot(Transferencias,
       type = "l",
       ylim = c(min(Transferencias,0),max(Transferencias,0)),
       main = paste('Resultado das trocas desiguais -',Pais,'\n(em milhões de horas de trabalho)'),
       xaxt="n",
       lty="solid", lwd=3,
       )
  lines(rep(0,times=17), col="red")
  axis(side=1,1:17,as.character(1995:2011))
  polygon(c(1:17,17:1),c(Transferencias,rep(0,times=17)),col="gray")
}
