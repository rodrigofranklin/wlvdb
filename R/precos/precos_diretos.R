# Script para leitura dos preços diretos, preços de produção e valores

#versao = versao_fonte <- "July14"
#versao_resultado <- "July14_1001"
#anos <- 1995:2009
versao = versao_fonte <- "Nov16"
versao_resultado <- "Nov16_1002"
anos <- 2000:2014

source('R/sectorespaises.R')
pais.cols <- pais.lins

paises.setores <- data.frame(country=rep(paises$Legenda,each=num.setores))
paises.setores$description <- setores$Setor
paises.setores$code <- setores$Code

resultado_temp <- paises.setores
resultado_temp$variable <- 'valores'
resultado <- resultado_temp
resultado_temp$variable <- 'precos_diretos'
resultado <- rbind(resultado, resultado_temp)
resultado_temp$variable <- 'precos_diretos_n'
resultado <- rbind(resultado, resultado_temp)
resultado_temp$variable <- 'precos_mercado'
resultado <- rbind(resultado, resultado_temp)

for (ano in anos) {
  source('R/precos/calculo_dos_precos.R')
  resultado$temp <- t(cbind(t(valores), t(precos_diretos), t(precos_diretos_n), t(precos_mercado)))
  names(resultado)[names(resultado) == "temp"] <- ano
}

write.csv2(resultado, file = paste0("resultados/",versao_resultado,"/precos_",versao_resultado,".csv"))


