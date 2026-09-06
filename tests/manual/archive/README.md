# Ferramentas históricas da issue 13

Estes diretórios contêm fontes, esquemas e contratos de validação, não logs ou
resultados de execução. Foram realocados sem alterar seus bytes:

Commit de origem anterior à reorganização:
`df5fb9ced810dc158347c5bae44e74b93ab7e820`.

| Caminho original | Caminho atual |
| --- | --- |
| `run_logs/issue13-evidence-source-v5/` | `tests/manual/archive/issue13-evidence-source-v5/` |
| `run_logs/issue13-native-gate-orchestrator-v5/` | `tests/manual/archive/issue13-native-gate-orchestrator-v5/` |

Os inventários e hashes autenticam o conteúdo original. Por isso, as referências
internas a `run_logs/`, `R/`, commits e diretórios de campanhas permanecem como
estavam. Este arquivo está fora dos inventários históricos.

Não execute essas fontes diretamente no checkout atual. Para reproduzir o
ambiente histórico, consulte o commit registrado na evidência e reconstrua seu
layout em uma worktree de `temp/<id>/`. Para uma validação nova, derive ferramentas
adequadas ao código atual em `tests/manual/` ou `scripts/`, com inventários novos,
sem reescrever provas antigas. O derivador `../issue13-main-derive-tooling.ps1`
recebe as raízes e o manifesto do harness materializado explicitamente; estes
diretórios de fontes não substituem esse conjunto autenticado.

As evidências preservadas da campanha 054 continuam em `temp/054/` e não foram
modificadas. Consulte [a política de campanhas](../../../docs/local-campaigns.md)
antes de criar, executar ou limpar uma campanha.
