# Handoff — Cards 5A/5B/5C

## Estado do repositório

- **Commit-base observado:** `0a41f68aba885c1ab7951108e01519e5b4f2e69e`
- **Branch:** `feature/cards-62-67-preferencias-filtros`
- **Commit, push, merge e troca de branch:** não realizados.
- A worktree já estava suja antes desta continuação. O núcleo local de contribuição/moderação, `0003_report_reward.py`, os registrants Flutter, `.playwright-mcp/` e `docs/cards5_abc/` já apareciam modificados ou não rastreados.

## Alterações desta continuação

- Integridade/reconciliação e auditoria: `contribuicoes/services.py`, `models.py`, `admin.py`, `views.py`, `serializers.py`; migrations `0004_one_reward_per_review.py`, `0005_report_reward_audit_actor.py` e `0006_point_activity_actor.py`.
- Exposição privada e interface: `evidencias/serializers.py`, `evidencias/views.py`, `frontend/lib/screens/own_reports_screen.dart`, `frontend/lib/widgets/contribution_help_sheet.dart` e `contribution_history_card.dart`.
- Cobertura: `contribuicoes/test_contributions.py`, `frontend/test/contributions_central_test.dart` e `evidence_cards_38_41_test.dart`.
- Documentação: `IMPLEMENTACAO.md`, `MATRIZ_TESTES.md`, `MATRIZ_ACEITE.md`, `VALIDACAO.md` e este handoff.
- `acessoja/settings.py`, `contribuicoes/signals.py`, parte do núcleo `models.py`/`services.py`/testes, `evidencias/moderation.py`, `0003_report_reward.py` e arquivos Flutter gerados já tinham alterações locais na entrada. Não atribuir todo o diff desses arquivos a esta continuação.

## Integração segura

1. Não misturar o trabalho dos Cards 5A–5C no PR dos Cards 62–67.
2. Antes de integrar, revisar a worktree e separar somente os hunks/arquivos destes cards em branch/PR próprio. Não descartar, reverter, fazer stash ou mover as alterações 62–67 sem autorização.
3. Aplicar migrations apenas em ambiente controlado após revisão e backup conforme o processo do projeto. Nenhuma migration foi aplicada ao banco local habitual nesta sessão.
4. Completar primeiro os itens **Parcial/Bloqueado** da [MATRIZ_ACEITE.md](./MATRIZ_ACEITE.md), em especial PostgreSQL real, casos negativos de decisão e TalkBack/dispositivo físico.

## Ambiente e ressalvas

- SQLite de teste e validações Django foram isolados no diretório de estado desta sessão.
- O processo preexistente em `127.0.0.1:8000` executa `C:\Users\User\acessoja-app\.venv\Scripts\python.exe manage.py runserver`; é outra cópia, permaneceu intocado e não foi usado.
- A homologação Web usou serviços temporários desta cópia em `127.0.0.1:8001` (Django) e `127.0.0.1:7358` (Flutter Web), ambos encerrados após o teste. O banco com dados sintéticos foi `cards5-final-validation.sqlite3`, fora do repositório; `db.sqlite3` não foi usado.
- O browser confirmou o ciclo de recompensa `0 → +5 → -5 → +5`, estado privado da denúncia, histórico de operações, sem overflow horizontal em viewport de 390×844 e ativação por Tab/Enter. A fonte externa respondeu 504; o catálogo local continuou disponível.
- O Quality Gate local pós-correções passou: suíte backend 784 passed/31 skipped/21 subtests, cobertura 84,37%; Flutter 1.086 testes, analyze e builds passaram; Flake8 passou. Flutter local 3.47.5 difere da CI 3.47.4.
- PostgreSQL/concorrência e TalkBack/dispositivo físico permanecem sem evidência local. Os resultados exatos e as ressalvas de gates estão em [VALIDACAO.md](./VALIDACAO.md).
