###################
# Gráficos comparativos das trocas desiguais das versões July14 e Nov16

Paises14 <- c("Austrália","Áustria",
            "Bélgica","Bulgária","Brasil","Canadá","China","Chipre","Tchéquia","Alemanha","Dinamarca","Espanha",
            "Estônia","Finlândia","França","Reino Unido","Grécia","Hungria","Indonésia","Índia","Irlanda","Itália",
            "Japão","Coreia do Sul","Lituânia","Luxemburgo","Letônia","México","Malta","Países Baixos","Polônia",
            "Portugal","Romênia","Federação Russa","Eslováquia","Eslovênia","Suécia","Turquia","Taiwan",
            "Estados Unidos","Mundo")
# Aloca a matriz de resultados
Resultados14 <- array(data = 0,dim = c(17,41,28), dimnames = list(c(1995:2011),
                                                                Paises14,
                                                                c("","ExpoTTotalPais",
                                                                  "ExpoMTotalPais","ImpoTTotalPais","ImpoMTotalPais","TransfTotalPais","ProdutoTotalTPais","ProdutoTotalMPais",
                                                                  "FatorDINN","FatorDemanda","PIBTPais","PIBMPais","TrabalhadoresPais","RemuneracaoTPais","RemuneracaoMPais",
                                                                  "RemuneracaoRealPais","JornadaTotalPais","AssalariadosPais","SalarioTPais","SalarioMPais","SalarioRealPais",
                                                                  "LucroMPais","CapitalMPais","ConsumoIntermediarioPPais","COXK","COXT","COIK","COIT")))
# Lê os resultados dos arquivos .csv
for (Z in 1995:2011) {
  Resultados14[as.character(Z),,] <- as.matrix(read.csv2(file = paste0(getwd(),"/resultados/July14_1001/resultados_",as.character(Z),".csv"), row.names = 1))
}
#####



Paises16 <- c("Austrália","Áustria","Bélgica","Bulgária","Brasil","Canadá","Suíça","China",
            "Chipre","Tchéquia","Alemanha","Dinamarca","Espanha","Estônia","Finlândia",
            "França","Reino Unido","Grécia",
            "Croácia","Hungria","Indonésia","Índia","Irlanda","Itália","Japão","Coreia do Sul",
            "Lituânia","Luxemburgo","Letônia","México","Malta","Países Baixos","Noruega","Polônia",
            "Portugal","Romênia","Federação Russa","Eslováquia","Eslovênia","Suécia","Turquia",
            "Taiwan","Estados Unidos","Mundo")

# Aloca a matriz de resultados
Resultados16 <- array(data = 0,dim = c(15,44,28), dimnames = list(c(2000:2014),
                                                                Paises16,
                                                                c("","ExpoTTotalPais",
                                                                  "ExpoMTotalPais","ImpoTTotalPais","ImpoMTotalPais","TransfTotalPais","ProdutoTotalTPais","ProdutoTotalMPais",
                                                                  "FatorDINN","FatorDemanda","PIBTPais","PIBMPais","TrabalhadoresPais","RemuneracaoTPais","RemuneracaoMPais",
                                                                  "RemuneracaoRealPais","JornadaTotalPais","AssalariadosPais","SalarioTPais","SalarioMPais","SalarioRealPais",
                                                                  "LucroMPais","CapitalMPais","ConsumoIntermediarioPPais","COXK","COXT","COIK","COIT")))
# Lê os resultados dos arquivos .csv
for (Z in 2000:2014) {
  Resultados16[as.character(Z),,] <- as.matrix(read.csv2(file = paste0(getwd(),"/resultados/Nov16_1001/resultados_",as.character(Z),".csv"), row.names = 1))
}

for (Pais in Paises14) {
Transferencias16 <- c(NA,NA,NA,NA,NA,Resultados16[,Pais,"TransfTotalPais"]/1000)
Transferencias14 <- c(Resultados14[1:15,Pais,"TransfTotalPais"]/1000)
plot(Transferencias16,
     type = "l",
     ylim = c(min(Transferencias16[!is.na(Transferencias16)],Transferencias14,0),max(Transferencias16[!is.na(Transferencias16)],Transferencias14,0)),     
     main = paste('Resultado das trocas desiguais - ',Pais,'\n(em milhares de trabalhadores-ano)'),
     xaxt="n",
     lty="solid", lwd=3,
)
lines(Transferencias14, col="red", lty="solid", lwd=3)
lines(rep(0,times=20), col="blue")
axis(side=1,1:20,as.character(1995:2014))
}

