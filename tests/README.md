# Testes e validação

Esta pasta faz parte do código do projeto e deve permanecer no Git:

- `testthat/`: testes automatizados de contratos, cálculo e publicação.
- `smoke/`: verificação de inicialização sem efeitos colaterais.
- `fixtures/`: entradas pequenas e resultados esperados de referência.
- `manual/`: ferramentas reutilizáveis para validações e campanhas explícitas.
- `manual/archive/`: fontes históricas autenticadas, preservadas para consulta.

A CI executa os testes automatizados em Windows e Ubuntu. Saídas, logs, downloads
e diretórios temporários de qualquer execução ficam em `temp/<id>/`, ignorado
pelo Git; não devem ser gravados aqui. Prepare a campanha e as variáveis de
ambiente conforme [a política de campanhas](../docs/local-campaigns.md).

Com a biblioteca restaurada e os temporários direcionados para a campanha:

```sh
Rscript --vanilla tests/smoke/startup.R
Rscript --vanilla -e 'source("renv/activate.R"); testthat::test_dir("tests/testthat", stop_on_failure = TRUE, stop_on_warning = TRUE)'
```
