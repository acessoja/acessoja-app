# Cards 5A, 5B e 5C — estado da implementação

**Verificado em:** 2026-11-03
**Branch de trabalho:** `feature/cards-62-67-preferencias-filtros`
**Commit-base:** `0a41f68aba885c1ab7951108e01519e5b4f2e69e`

Esta entrega continua alterações locais já existentes: o núcleo de `report_upheld`, o modelo inicial e a migration `0003_report_reward.py` já estavam modificados antes desta continuação. O código abaixo foi auditado, corrigido e validado em banco de teste SQLite isolado. A matriz não declara os três cards integralmente homologados; veja os itens parciais e bloqueados em [MATRIZ_ACEITE.md](./MATRIZ_ACEITE.md).

## 5A — recompensa por denúncia procedente

- `CONTRIBUTION_POINTS["report_upheld"]` vale 5.
- `process_report_reward_for_decision()` só processa decisão `invalidate` com `effect_applied`, vinculada à revisão exata de uma avaliação que foi invalidada. Não concede por denúncia de foto/recurso, autor da avaliação, alvo sem local interno ou decisão sem efeito.
- A atribuição escolhe o denunciante ativo mais antigo para `target_key + target_revision`, com desempate pelo protocolo. O teste cobre dois denunciantes e moderação iniciada pelo protocolo mais novo.
- O modelo `ReportRewardAttribution` registra atribuição, revisão, decisão, usuário, local, estado e evento do ledger. As migrations `0004` e `0005` adicionam unicidade por revisão e por usuário/local/ação e registram o moderador da revisão formal.
- A decisão, a alteração da avaliação, a atribuição, o evento e a atividade são gravados na transação de moderação. Uma falha no ledger reverte a invalidação; retry e repetição do mesmo `operation_id` não duplicam pontos.
- A criação do evento trata colisão de unicidade em savepoint, aceitando apenas o evento idempotente correspondente e propagando erros de integridade não relacionados. Há regressão PostgreSQL específica, mas ela foi ignorada no SQLite local.
- Revisão formal por fraude/anulação/restauração está disponível no admin apenas para quem tem `evidencias.moderate_content`. `set_report_reward_status()` registra deltas separados (`+5`, `-5`, `+5`), motivo e ator. A migration `0006` adiciona o ator auditável à atividade.
- A API privada de denúncias inclui `reward_status`; a lista e o detalhe filtram a atribuição para o próprio denunciante. Não expõem moderador nem justificativa interna.

## 5B — Meu impacto, histórico e ajuda

- A tela existente preserva as abas de descoberta, avaliações próprias, comunidade e impacto; o resumo usa saldo, nível e progresso retornados pelo backend.
- `ContributionHistoryCard` identifica `report_upheld`, mostra sua razão e não o rotula como avaliação excluída quando o evento não possui avaliação do denunciante. Concessão, revogação e restauração aparecem como atividades distintas.
- `OwnReportsScreen` separa estado do protocolo e estado da recompensa, sem inventar estado quando a API antiga não fornece o campo.
- A ajuda agora inclui os 5 pontos por denúncia procedente e explica que só uma invalidação efetiva de avaliação gera o bônus. Os outros valores continuam vindo das regras da API.
- Os testes Flutter focados cobrem resumo, progressão, histórico, regra da denúncia, layout, escala de texto e a tela privada de denúncias. A suíte Flutter completa, análise estática e builds Web/Android também foram executados; veja [VALIDACAO.md](./VALIDACAO.md).
- A homologação Web com contas/dados sintéticos e banco SQLite isolado percorreu o ciclo `0 → +5 → 0 após revogação → +5 após restauração`, conferindo painel, histórico e estado privado da denúncia. Em 390×844 não houve overflow horizontal; semântica foi inspecionada e Tab/Enter ativou um controle. TalkBack e dispositivo físico continuam pendentes.

## 5C — integridade e reconciliação

- `reconcile_user()` deriva o bônus da atribuição concedida, não da existência de uma avaliação própria. Inclui locais presentes em atribuições, oferece dry-run sem gravação e pode reconstruir evento/atividade ausentes, restaurando o vínculo da atribuição.
- A descoberta padrão do comando `reconcile_contributions` também inclui beneficiários que só aparecem em atribuições de recompensa; teste cobre dry-run, aplicação e repetição idempotente.
- As constraints do banco impedem mais de uma atribuição por revisão e mais de uma atribuição por usuário/local/ação, inclusive após revogação.
- A suíte focalizada comprova rollback transacional, replay idempotente, escolha do denunciante mais antigo, limite por usuário/local, revogação/restauração e reparo do ledger sem avaliação própria.
- O cenário concorrente em PostgreSQL não foi executado. SQLite não comprova a ordenação de locks nem a concorrência real de produção.

## Migrations

- `0003_report_reward.py` — migration local preexistente que cria a atribuição.
- `0004_one_reward_per_review.py` — unicidade de atribuição por revisão e usuário/local/ação.
- `0005_report_reward_audit_actor.py` — ator da revisão formal na atribuição.
- `0006_point_activity_actor.py` — ator por atividade auditável.

Nenhuma migration foi aplicada ao `db.sqlite3` habitual. A suíte Django aplicou as migrations apenas ao banco de teste isolado.

## Evidência e limites

- Migrations limpas no banco temporário, `manage.py check`, `makemigrations --check --dry-run`, OpenAPI e Flake8 passaram. A suíte backend completa pós-correção passou com 784 aprovados, 31 ignorados, 21 subtestes aprovados e cobertura de 84,37%; os testes focados também passaram (57/3; módulo de contribuições: 33/2). Veja [VALIDACAO.md](./VALIDACAO.md).
- Flutter 3.47.5: 1.086 testes completos aprovados, `flutter analyze` completo sem problemas, build Web e APK debug aprovados. Os testes focados dos arquivos diretamente relacionados também passaram (76).
- Browser: API isolada em `127.0.0.1:8001`, build Web em `127.0.0.1:7358`, banco `cards5-final-validation.sqlite3` fora do repositório. O ciclo de recompensa e a leitura privada foram observados com dados sintéticos. A consulta opcional de locais externos respondeu 504; a base local permaneceu acessível.
- PostgreSQL real/concorrência e TalkBack em dispositivo físico não foram executados. O serviço já ativo em `127.0.0.1:8000` pertence a `C:\Users\User\acessoja-app`; permaneceu intocado.
