# Card 51 — evidências e aceite dos Cards 47–51

Implementação concluída para revisão. A homologação integral Android/Chrome, tecnologia assistiva e
concorrência PostgreSQL permanece pendente nos itens identificados. Não houve commit, push, PR,
aprovação de revisão nem alteração de cartões externos. Base: `develop`
`e4a8db02dd4aa8a77fe9dfea9c3f0ffb62d280ef` + entrega Cards 42–46.

## Resultados executados

| Verificação | Resultado real |
|---|---|
| Backend completo Python 3.12.14 / Django 5.2.18 / SQLite | 692 passaram; 29 skips; 21 subtestes passaram; 172,89 s |
| Cobertura backend com branches | 84,0971%; gate original 80% preservado |
| Skips | 25 dependem de PostgreSQL/restore e 4 de Redis real; não contam como aprovação |
| Flake8, Django check, pip check | Passaram |
| Migrations em banco SQLite vazio e verificação de drift | Aplicadas; sem alterações pendentes |
| OpenAPI `--validate --fail-on-warn` | Passou sem warnings |
| Flutter 3.47.4 / Dart 3.13.3 analyze | No issues found |
| Testes novos do Flutter | 25 passaram |
| Suíte Flutter completa | 933 passaram |
| Build web real, recursos locais | Passou em 43,6 s |
| APK debug | Não gerado: Android SDK ausente |
| Quality Gate no GitHub | Não executado nesta entrega; jobs PG/Redis mantidos, sem reduzir o gate |

Os testes unitários de controller usam serviços de teste para injetar falhas; testes de API usam banco
SQLite e arquivos sintéticos reais. Eles não substituem transações concorrentes PostgreSQL.
Os logs esperados de offline/500 nos cenários de falha não significam falha de suíte.

## Percurso real no Chrome

`frontend/integration_test/reviews_browser_lab.py` sobe a API Django e o build de `main.dart` em
loopback, com banco/storage temporários e contas sintéticas. Usa o Chrome headless shell oficial
151.0.7922.34 via Playwright. O mapa/provedores externos são excluídos; a API do pacote é real.
O único defeito injetado é uma falha de storage no terceiro arquivo; não há resposta de sucesso
fabricada. Novos contextos consultam persistência do servidor; isso não comprova Android↔Chrome.
Não foram capturadas imagens pessoais nem incluídos tokens, banco ou arquivos de mídia na entrega.

1. Partial draft has two v2 and two independent answers, no review persisted.
2. Three local photos selected before review creation or upload.
3. Real one-shot storage failure preserves review, two receipts, partial evidence and 10 points.
4. Retry uploads only remaining photo.
5. Pending image is private for GET and available to its authenticated owner for GET/HEAD.
6. Real CSRF-protected Admin approvals publish bytes and grant exactly one +3 event.
7. Reader opens actual public gallery and closes enlarged photo with Escape.
8. Description revisions hide old bytes; another approved photo preserves bonus, last one revokes it.
9. Safe rejection reason, private moderator notes and correction restore the same +3 event.
10. Removing last approved photograph revokes +3 and blocks the known URL.
11. Independent report is saved from the real editor without stars, review or prior evidence.
12. Stars-only review publishes without requiring resources, comment or photographs.
13. Two real contribution reconciliations keep the ledger and point total unchanged.

## Como reproduzir

Aplicar o pacote com o instalador e `--check` antes de `--apply`; a base precisa conter Cards 42–46.
O aplicador não instala dependências, não migra banco e recusa arquivos locais divergentes.
Conservar backup de banco/mídia conforme o procedimento existente. Depois:

```bash
python -m pip install -r backend/requirements.txt
python manage.py migrate
python manage.py check
python manage.py reconcile_contributions
python manage.py reconcile_contributions --apply
cd frontend
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Iniciar a API com `python manage.py runserver` em outro terminal, usando `.env` local existente.
CORS deve permitir a origem da porta web escolhida (por exemplo `--web-port=7357` com
`CORS_ALLOWED_ORIGINS=http://localhost:7357`). Nenhum segredo é distribuído.
Para Android: instalar a cadeia Android/SDK, conectar aparelho/emulador, usar `flutter devices` e
`flutter run -d <device> --dart-define=API_BASE_URL=<origem_acessivel_ao_aparelho>`.
Não usar localhost do aparelho como endereço do computador. Repetir os fluxos abaixo nos dois.

- Central ou detalhe → avaliar → selecionar apenas estrelas → revisar → confirmar.
- Selecionar dois recursos v2 e os dois adicionais: conferir progresso 2/8, salvar/reabrir e
  consultar fontes. Limpar um recurso explicitamente; omitidos devem permanecer.
- Escolher “Apenas informar acessibilidade, sem estrelas”: enviar um recurso de conta sem avaliação.
- Selecionar três fotos no editor; cancelar/remover seleção, preencher contexto e publicar.
  Em falha parcial, conferir avaliação real e repetir apenas pendências.
- Moderador autorizado: Admin → fotografia → analisar → aprovar/rejeitar com orientação pública.
  Autor: gerenciar fotos → corrigir descrição/arquivo; revisão fica pendente até nova decisão.
- Conferir histórico/saldo: +3 uma vez com primeira elegível, manter com outra aprovada,
  revogar ao perder última, restaurar o mesmo direito após aprovação.
- Reabrir em outra plataforma com a mesma conta/API; conferir versões e bytes. Trocar conta
  durante seleção/envio, expirar sessão, perder resposta depois do commit e provocar conflito.
- TalkBack/leitor de tela real, teclado, texto 200%, tela pequena e recuperação nativa Android:
  preencher e anexar evidências aos critérios pendentes. Duas janelas Chrome não homologam Android.

Laboratório reproduzível (dependência de desenvolvimento opcional `playwright`, não produção):

```bash
python -m pip install playwright
cd frontend
flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:8001
cd ..
python frontend/integration_test/reviews_browser_lab.py --chrome /caminho/chrome-headless-shell --report browser_lab.json
```

O script cria exclusivamente dados temporários e inicia dois servidores no próprio processo.
Para preservar a segurança do ambiente, executá-lo em processo dedicado. As credenciais no código
são fixtures sintéticas e nunca configuram usuário de produção.

Concorrência: configurar `DATABASE_URL` para PostgreSQL descartável de teste (com permissão de criar
banco de testes) e executar o mesmo comando do job `backend-concurrency`. Os testes novos usam
transações independentes e barreiras; não remover skips para fazê-los “passar” em SQLite.

```bash
pytest -q contribuicoes favoritos locais usuarios acessoja evidencias midia modal_avaliacao -k 'postgresql_concurrent or postgresql_restore or catalog'
```

Os jobs existentes também requerem pg_dump/pg_restore compatíveis, requirements de catálogo/geografia
e Redis isolado. Consultar `.github/workflows/quality-gate.yml`. Nenhuma execução remota foi presumida.

## Rastreabilidade dos 54 critérios

“Verificado” significa o nível de evidência documentado na matriz dos cenários abaixo.
“Depende de integração” mantém explícita a parcela PG/dispositivo/AT ainda não executada.
O texto de origem está preservado em `docs/ESPECIFICACAO_CARDS_47_51.md`.

| Card / critério | Requisito | Implementação | Evidência | Situação |
|---|---|---|---|---|
| 47-01 | selecionar e descrever fotos no editor antes de publicar, no Android e Chrome. | review_editor_screen.dart; photo_submission_queue.dart; photo_gallery_screen.dart; midia/services.py/moderation.py; contribuicoes/services.py | T14, T18, T39, T43 | Depende de integração — T39: Não executado: requer aparelho/emulador Android e Chrome com a mesma API.; T43: Guarda conta/local testada; interrupção e recuperação nativa Android não executadas. |
| 47-02 | publicar sem foto continua possível. | review_editor_screen.dart; photo_submission_queue.dart; photo_gallery_screen.dart; midia/services.py/moderation.py; contribuicoes/services.py | T01 | Verificado |
| 47-03 | upload começa somente com avaliação persistida e autoria válida. | review_editor_screen.dart; photo_submission_queue.dart; photo_gallery_screen.dart; midia/services.py/moderation.py; contribuicoes/services.py | T18, T31 | Verificado |
| 47-04 | falha parcial preserva avaliação e arquivos confirmados; retry não duplica. | review_editor_screen.dart; photo_submission_queue.dart; photo_gallery_screen.dart; midia/services.py/moderation.py; contribuicoes/services.py | T18, T19 | Verificado |
| 47-05 | pendentes/rejeitadas só aparecem a quem tem autorização, inclusive por URL direta. | review_editor_screen.dart; photo_submission_queue.dart; photo_gallery_screen.dart; midia/services.py/moderation.py; contribuicoes/services.py | T20, T41 | Verificado |
| 47-06 | rejeição permite correção com nova revisão e histórico preservado. | review_editor_screen.dart; photo_submission_queue.dart; photo_gallery_screen.dart; midia/services.py/moderation.py; contribuicoes/services.py | T22, T23 | Verificado |
| 47-07 | edição de foto não altera conteúdo textual, nota ou questionário. | review_editor_screen.dart; photo_submission_queue.dart; photo_gallery_screen.dart; midia/services.py/moderation.py; contribuicoes/services.py | T23 | Verificado |
| 47-08 | limite de cinco e validações de arquivo funcionam também sob concorrência. | review_editor_screen.dart; photo_submission_queue.dart; photo_gallery_screen.dart; midia/services.py/moderation.py; contribuicoes/services.py | T15, T16, T17, T28 | Depende de integração — T16: Limites sequenciais verificados; disputa concorrente da última vaga depende de PostgreSQL (T28).; T28: Quota sequencial verificada; concorrência PostgreSQL não executada. |
| 47-09 | bônus +3, revogação e restauração são idempotentes e auditáveis. | review_editor_screen.dart; photo_submission_queue.dart; photo_gallery_screen.dart; midia/services.py/moderation.py; contribuicoes/services.py | T21, T24, T25, T29, T34 | Depende de integração — T29: Transações e ledger sequenciais verificados; corridas PostgreSQL não executadas. |
| 47-10 | dados legados, perfil, galeria existente e moderação continuam funcionando. | review_editor_screen.dart; photo_submission_queue.dart; photo_gallery_screen.dart; midia/services.py/moderation.py; contribuicoes/services.py | T09, T44 | Verificado |
| 48-01 | salvar uma ou várias respostas sem completar o restante. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T04 | Verificado |
| 48-02 | dez recursos disponíveis, oito perguntas v2 corretamente identificadas. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T03, T10 | Verificado |
| 48-03 | Sem resposta, Não sei, Não e Não se aplica distintos na API e na UI. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T05, T07 | Verificado |
| 48-04 | PATCH preserva omitidos e remove apenas os recursos explicitamente limpos. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T07 | Verificado |
| 48-05 | relato independente funciona sem estrelas, sem avaliação e sem evidência anterior. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T03 | Verificado |
| 48-06 | seleção dos recursos fora do v2 é persistida pelo fluxo correto, com falhas identificáveis. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T10, T11 | Verificado |
| 48-07 | um autor não aumenta artificialmente contadores por usar dois caminhos. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T12, T13 | Depende de integração — T12: Regra e restrição verificadas em SQLite; corrida de criação independente ainda exige PostgreSQL. |
| 48-08 | fontes, datas, revisões, exclusões e invalidação preservam rastreabilidade. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T07, T13, T26 | Verificado |
| 48-09 | legado v1 não é convertido implicitamente. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T09 | Verificado |
| 48-10 | bônus completo respeita versão e elegibilidade; parcial não pontua como completo. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T06, T08, T09 | Verificado |
| 48-11 | autoria, idempotência, concorrência e estados 401/403/409/429 são validados. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T19, T30, T31, T37 | Depende de integração — T30: Conflito 409 e conservação do rascunho verificados; duas transações PostgreSQL pendentes.; T37: API/controller cobrem erros e cooldown; injeção de todos os estados na interface real por plataforma pendente. |
| 48-12 | fluxo funcional e acessível no Android e Chrome. | modal_avaliacao/serializers.py/views.py; evidencias/observations.py/capture.py/projection.py/query_projection.py | T38, T39 | Depende de integração — T38: Semântica, teclado, Escape, texto 200% e viewport pequeno em widgets; leitor de tela real não executado.; T39: Não executado: requer aparelho/emulador Android e Chrome com a mesma API. |
| 49-01 | uma avaliação somente com estrelas pode ser publicada. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T01, T02 | Verificado |
| 49-02 | comentário, questionário e fotos são opcionais e claramente identificados. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T01, T14, T42 | Verificado |
| 49-03 | respostas parciais usam backend real do Card 48. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T04, T10 | Verificado |
| 49-04 | selecionar fotos no editor usa o fluxo do Card 47, sem tela obrigatória posterior. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T14, T18 | Verificado |
| 49-05 | revisar e editar qualquer seção preserva os dados das demais. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T42 | Verificado |
| 49-06 | não há avaliação, relato ou upload duplicado por duplo toque/timeout/retry. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T11, T18, T19, T27 | Depende de integração — T27: Guard de duplo toque e replay verificados; duas transações independentes pendentes em PostgreSQL. |
| 49-07 | sucesso parcial identifica exatamente o que falta e preserva operações confirmadas. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T11, T18 | Verificado |
| 49-08 | edição respeita autoria, revisão e versão legada. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T09, T30, T31 | Depende de integração — T30: Conflito 409 e conservação do rascunho verificados; duas transações PostgreSQL pendentes. |
| 49-09 | retorno e atualização seletiva usam a origem correta. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T35, T36 | Depende de integração — T35: Central Chrome e widgets de navegação verificados; percurso completo de todas as origens em ambos os dispositivos pendente. |
| 49-10 | troca de conta/local não reaproveita rascunho privado indevido. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T32, T43 | Depende de integração — T43: Guarda conta/local testada; interrupção e recuperação nativa Android não executadas. |
| 49-11 | pontos apresentados são confirmados pelo backend. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T01, T21, T34 | Verificado |
| 49-12 | testes e verificação Android/Chrome correspondem ao fluxo implementado. | review_draft_controller.dart; review_editor_screen.dart; contribution_service.dart; evidence_service.dart | T38, T39, T43 | Depende de integração — T38: Semântica, teclado, Escape, texto 200% e viewport pequeno em widgets; leitor de tela real não executado.; T39: Não executado: requer aparelho/emulador Android e Chrome com a mesma API.; T43: Guarda conta/local testada; interrupção e recuperação nativa Android não executadas. |
| 50-01 | opinião geral e relatos de acessibilidade são distinguíveis. | resource_answer_fields.dart; review_editor_screen.dart; photo_gallery_screen.dart; contribution_help_sheet.dart | T01, T03 | Verificado |
| 50-02 | opcionais, significados das respostas e progresso são claros e verdadeiros. | resource_answer_fields.dart; review_editor_screen.dart; photo_gallery_screen.dart; contribution_help_sheet.dart | T04, T05, T42 | Verificado |
| 50-03 | oito perguntas v2 e dez recursos do catálogo não são confundidos. | resource_answer_fields.dart; review_editor_screen.dart; photo_gallery_screen.dart; contribution_help_sheet.dart | T03, T10 | Verificado |
| 50-04 | edição por seção não perde nem limpa conteúdo de outras seções. | resource_answer_fields.dart; review_editor_screen.dart; photo_gallery_screen.dart; contribution_help_sheet.dart | T42 | Verificado |
| 50-05 | relato independente e correção de foto têm ações contextuais corretas. | resource_answer_fields.dart; review_editor_screen.dart; photo_gallery_screen.dart; contribution_help_sheet.dart | T03, T22, T23 | Verificado |
| 50-06 | falhas de validação, autenticação, conflito e rede são recuperáveis. | resource_answer_fields.dart; review_editor_screen.dart; photo_gallery_screen.dart; contribution_help_sheet.dart | T19, T30, T37 | Depende de integração — T30: Conflito 409 e conservação do rascunho verificados; duas transações PostgreSQL pendentes.; T37: API/controller cobrem erros e cooldown; injeção de todos os estados na interface real por plataforma pendente. |
| 50-07 | fotos privadas e notas internas permanecem protegidas. | resource_answer_fields.dart; review_editor_screen.dart; photo_gallery_screen.dart; contribution_help_sheet.dart | T20, T22, T31, T41 | Verificado |
| 50-08 | feedback de pontos vem do servidor, inclusive quando o delta é zero. | resource_answer_fields.dart; review_editor_screen.dart; photo_gallery_screen.dart; contribution_help_sheet.dart | T01, T21, T25, T34 | Verificado |
| 50-09 | teclado, leitor de tela, texto ampliado e foco foram verificados. | resource_answer_fields.dart; review_editor_screen.dart; photo_gallery_screen.dart; contribution_help_sheet.dart | T38 | Depende de integração — T38: Semântica, teclado, Escape, texto 200% e viewport pequeno em widgets; leitor de tela real não executado. |
| 50-10 | português/inglês e layout Android/Chrome estão consistentes. | resource_answer_fields.dart; review_editor_screen.dart; photo_gallery_screen.dart; contribution_help_sheet.dart | T38, T39 | Depende de integração — T38: Semântica, teclado, Escape, texto 200% e viewport pequeno em widgets; leitor de tela real não executado.; T39: Não executado: requer aparelho/emulador Android e Chrome com a mesma API. |
| 51-01 | avaliação simples e opcionais verificados com backend real. | modal_avaliacao/test_cards_47_51.py; midia/test_cards47_postgresql.py; frontend/test/cards_47_51_test.dart; frontend/integration_test/reviews_browser_lab.py | T01, T04, T14 | Verificado |
| 51-02 | parcial, relato individual e legado v1 verificados. | modal_avaliacao/test_cards_47_51.py; midia/test_cards47_postgresql.py; frontend/test/cards_47_51_test.dart; frontend/integration_test/reviews_browser_lab.py | T03, T04, T09 | Verificado |
| 51-03 | upload, aprovação, rejeição, correção e exclusão verificados. | modal_avaliacao/test_cards_47_51.py; midia/test_cards47_postgresql.py; frontend/test/cards_47_51_test.dart; frontend/integration_test/reviews_browser_lab.py | T18, T21, T22, T23, T25 | Verificado |
| 51-04 | fotos privadas protegidas também por URL direta e cache. | modal_avaliacao/test_cards_47_51.py; midia/test_cards47_postgresql.py; frontend/test/cards_47_51_test.dart; frontend/integration_test/reviews_browser_lab.py | T20, T41 | Verificado |
| 51-05 | revisão, concorrência, timeout e retry sem perda ou duplicação. | modal_avaliacao/test_cards_47_51.py; midia/test_cards47_postgresql.py; frontend/test/cards_47_51_test.dart; frontend/integration_test/reviews_browser_lab.py | T19, T27, T28, T29, T30 | Depende de integração — T27: Guard de duplo toque e replay verificados; duas transações independentes pendentes em PostgreSQL.; T28: Quota sequencial verificada; concorrência PostgreSQL não executada.; T29: Transações e ledger sequenciais verificados; corridas PostgreSQL não executadas.; T30: Conflito 409 e conservação do rascunho verificados; duas transações PostgreSQL pendentes. |
| 51-06 | saldo, histórico, revogação/restauração e reconciliador consistentes. | modal_avaliacao/test_cards_47_51.py; midia/test_cards47_postgresql.py; frontend/test/cards_47_51_test.dart; frontend/integration_test/reviews_browser_lab.py | T06, T08, T21, T25, T34 | Verificado |
| 51-07 | retorno e atualização seletiva verificados nas entradas disponíveis. | modal_avaliacao/test_cards_47_51.py; midia/test_cards47_postgresql.py; frontend/test/cards_47_51_test.dart; frontend/integration_test/reviews_browser_lab.py | T35 | Depende de integração — T35: Central Chrome e widgets de navegação verificados; percurso completo de todas as origens em ambos os dispositivos pendente. |
| 51-08 | tecnologia assistiva, teclado e texto ampliado verificados. | modal_avaliacao/test_cards_47_51.py; midia/test_cards47_postgresql.py; frontend/test/cards_47_51_test.dart; frontend/integration_test/reviews_browser_lab.py | T38 | Depende de integração — T38: Semântica, teclado, Escape, texto 200% e viewport pequeno em widgets; leitor de tela real não executado. |
| 51-09 | PostgreSQL real e Quality Gate aprovados para os cenários aplicáveis. | modal_avaliacao/test_cards_47_51.py; midia/test_cards47_postgresql.py; frontend/test/cards_47_51_test.dart; frontend/integration_test/reviews_browser_lab.py | T27, T28, T29, T30 | Depende de integração — T27: Guard de duplo toque e replay verificados; duas transações independentes pendentes em PostgreSQL.; T28: Quota sequencial verificada; concorrência PostgreSQL não executada.; T29: Transações e ledger sequenciais verificados; corridas PostgreSQL não executadas.; T30: Conflito 409 e conservação do rascunho verificados; duas transações PostgreSQL pendentes. |
| 51-10 | resultados executados separados de pendências, com evidências por plataforma. | modal_avaliacao/test_cards_47_51.py; midia/test_cards47_postgresql.py; frontend/test/cards_47_51_test.dart; frontend/integration_test/reviews_browser_lab.py | T44 | Verificado |

## Matriz dos 44 cenários

As referências nomeiam testes realmente presentes na entrega/base. Um teste de API não comprova
hardware, leitor de tela ou o Quality Gate remoto. Relatórios legíveis por máquina em
`reports/cards_47_51/results.json` e `browser_lab.json`; OpenAPI validado no mesmo diretório.

| ID | Cenário | Teste / evidência | Situação e limite |
|---|---|---|---|
| T01 | Criar somente com estrelas | modal_avaliacao/test_cards_47_51.py::test_t01_t04_partial_creation_never_invents_answers_or_survey_points<br>frontend/test/cards_47_51_test.dart — T01 stars only has no invented answers photographs or points<br>frontend/test/cards_47_51_test.dart — T01 T42 stars-only summary edits preserve comment and no mandatory survey<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T02 | Criar sem estrelas pelo caminho de avaliação | modal_avaliacao/test_cards_47_51.py::test_t02_stars_are_required_and_independent_does_not_create_fake_review<br>frontend/test/cards_47_51_test.dart — T02 no selected rating blocks request | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T03 | Informar recurso pelo caminho independente | modal_avaliacao/test_cards_47_51.py::test_t03_t10_independent_can_start_each_of_the_ten_resources<br>frontend/test/cards_47_51_test.dart — T03 ten-resource standalone path never creates a star review<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T04 | Enviar uma ou duas respostas v2 | modal_avaliacao/test_cards_47_51.py::test_t01_t04_partial_creation_never_invents_answers_or_survey_points<br>frontend/test/cards_47_51_test.dart — T04 T05 partial and unknown remain distinct from unanswered<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T05 | Não sei versus item ignorado | frontend/test/cards_47_51_test.dart — T04 T05 partial and unknown remain distinct from unanswered | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T06 | Oito respostas válidas | modal_avaliacao/test_cards_47_51.py::test_t06_t08_survey_complete_partial_complete_reuses_one_auditable_right | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T07 | PATCH omitindo recurso e limpando outro com null | modal_avaliacao/test_cards_47_51.py::test_t07_patch_omission_empty_map_and_null_have_distinct_meanings<br>frontend/test/cards_47_51_test.dart — T07 PATCH only sends intentional differences and explicit clear | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T08 | Completo → parcial → completo | modal_avaliacao/test_cards_47_51.py::test_t06_t08_survey_complete_partial_complete_reuses_one_auditable_right | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T09 | Editar v1 sem mudar questionário | modal_avaliacao/test_cards_47_51.py::test_t09_legacy_comment_and_photographs_never_convert_v1<br>frontend/test/cards_47_51_test.dart — T09 v1 text edit preserves old questionnaire | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T10 | Piso tátil/sinalização visual pelo editor | modal_avaliacao/test_cards_47_51.py::test_t10_t12_t13_single_effective_author_across_survey_and_independent_paths<br>modal_avaliacao/test_cards_47_51.py::test_t03_t10_independent_can_start_each_of_the_ten_resources<br>frontend/test/cards_47_51_test.dart — T10 T11 extra statement failure preserves review; retry only pending<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T11 | Falhar um relato adicional após salvar avaliação | frontend/test/cards_47_51_test.dart — T10 T11 extra statement failure preserves review; retry only pending | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T12 | Survey e relato avulso do mesmo autor/recurso | modal_avaliacao/test_cards_47_51.py::test_t10_t12_t13_single_effective_author_across_survey_and_independent_paths<br>midia/test_cards47_postgresql.py::test_postgresql_concurrent_independent_statements_begin_without_evidence_once (não executado: requer PostgreSQL) | Depende de integração. Regra e restrição verificadas em SQLite; corrida de criação independente ainda exige PostgreSQL. |
| T13 | Invalidar ou remover relato mais recente | modal_avaliacao/test_cards_47_51.py::test_t10_t12_t13_single_effective_author_across_survey_and_independent_paths<br>modal_avaliacao/test_cards_47_51.py::test_t13_invalidating_latest_statement_does_not_reveal_older_survey<br>modal_avaliacao/test_cards_47_51.py::test_t13_old_report_is_unavailable_after_new_statement_without_punishing_new_content | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T14 | Selecionar, remover e cancelar fotos antes de publicar | frontend/test/cards_47_51_test.dart — T14 photo is selected inside editor before review exists; cancel preserves state<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T15 | JPEG/PNG/WebP válido e arquivo corrompido/disfarçado | midia/test_images.py::test_c45_disguised_corrupt_and_unsupported_inputs_are_not_published<br>midia/test_images.py::test_c45_real_decoder_orients_reencodes_and_removes_exif | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T16 | Sexta foto, arquivo acima de 5 MiB e imagem de dimensões excessivas | midia/test_images.py::test_c45_byte_pixel_and_request_limits_are_distinct<br>midia/test_images.py::test_c42_retry_and_quantity_are_enforced_without_duplicate_files | Depende de integração. Limites sequenciais verificados; disputa concorrente da última vaga depende de PostgreSQL (T28). |
| T17 | Descrição com 9/10/500/501 caracteres | modal_avaliacao/test_cards_47_51.py::test_t17_photo_description_normalizes_whitespace_then_checks_code_points<br>frontend/test/cards_47_51_test.dart — T17 photo context boundary $count before any HTTP write | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T18 | Avaliação salva, duas fotos OK e terceira falha | frontend/test/cards_47_51_test.dart — T18 third photo failure retries only that file with persisted review ID<br>frontend/test/cards_47_51_test.dart — T18 stop preserves a completed review and leaves next photo unstarted<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T19 | Timeout depois de salvar/upload concluído no servidor | modal_avaliacao/test_cards_47_51.py::test_t19_t27_review_lost_response_replay_and_owner_only_receipt<br>modal_avaliacao/test_cards_47_51.py::test_t19_t30_t31_statement_replay_conflict_and_authorization<br>frontend/test/cards_47_51_test.dart — T19 committed review with lost HTTP response is queried before retry<br>frontend/test/cards_47_51_test.dart — T19 malformed success cannot authorize photo upload or claim points | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T20 | Foto pendente | midia/test_images.py::test_c42_valid_upload_is_pending_private_and_changes_no_points<br>midia/test_images.py::test_c42_publication_requires_approval_and_each_direct_variant_is_authorized<br>midia/test_images.py::test_admin_session_can_read_pending_file_and_has_initial_review_surface<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T21 | Foto aprovada e avaliação elegível | modal_avaliacao/test_cards_47_51.py::test_t21_t24_t25_t34_photo_points_grant_revoke_restore_stabilize_one_right<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T22 | Foto rejeitada | modal_avaliacao/test_cards_47_51.py::test_t22_rejection_exports_safe_author_guidance_not_internal_notes_or_reporter<br>frontend/test/cards_47_51_test.dart — T22 rejected context correction validates then creates pending revision without review write<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T23 | Editar arquivo ou descrição de foto aprovada | midia/test_images.py::test_c42_replacement_and_description_require_new_review_without_touching_other_fields<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T24 | Outra foto continua aprovada após edição/remoção | modal_avaliacao/test_cards_47_51.py::test_t21_t24_t25_t34_photo_points_grant_revoke_restore_stabilize_one_right<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T25 | Remover última foto elegível e depois aprovar nova revisão | modal_avaliacao/test_cards_47_51.py::test_t21_t24_t25_t34_photo_points_grant_revoke_restore_stabilize_one_right<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T26 | Editar/excluir/invalidar avaliação | modal_avaliacao/test_cards_47_51.py::test_t26_t33_photo_decision_and_points_are_one_database_transaction<br>midia/test_images.py::test_c42_ineligible_review_revokes_public_file_and_list | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T27 | Duplo toque e duas criações concorrentes | modal_avaliacao/test_cards_47_51.py::test_t19_t27_review_lost_response_replay_and_owner_only_receipt<br>frontend/test/cards_47_51_test.dart — T27 concurrent submit calls share one in-flight form<br>contribuicoes/test_contributions.py::test_postgresql_concurrent_replay_awards_once (não executado: requer PostgreSQL) | Depende de integração. Guard de duplo toque e replay verificados; duas transações independentes pendentes em PostgreSQL. |
| T28 | Dois uploads disputam a última vaga | midia/test_images.py::test_c42_retry_and_quantity_are_enforced_without_duplicate_files<br>midia/test_postgresql.py::test_postgresql_concurrent_media_quota_is_enforced_under_upload_reservations (não executado: requer PostgreSQL) | Depende de integração. Quota sequencial verificada; concorrência PostgreSQL não executada. |
| T29 | Duas aprovações ou aprovação versus exclusão | midia/test_cards47_postgresql.py::test_postgresql_concurrent_two_photo_approvals_grant_one_right; midia/test_cards47_postgresql.py::test_postgresql_concurrent_approval_and_last_photo_delete_stabilize_ledger (não executado: requer PostgreSQL) | Depende de integração. Transações e ledger sequenciais verificados; corridas PostgreSQL não executadas. |
| T30 | Duas edições da mesma revisão | modal_avaliacao/test_cards_47_51.py::test_t19_t30_t31_statement_replay_conflict_and_authorization<br>modal_avaliacao/test_cards_47_51.py::test_t30_expected_revision_prevents_silent_overwrite<br>frontend/test/cards_47_51_test.dart — T30 conflict preserves draft and never silently changes revision<br>midia/test_cards47_postgresql.py::test_postgresql_concurrent_review_edits_use_one_expected_revision (não executado: requer PostgreSQL) | Depende de integração. Conflito 409 e conservação do rascunho verificados; duas transações PostgreSQL pendentes. |
| T31 | Conta B tenta editar avaliação/relato/foto de A | modal_avaliacao/test_cards_47_51.py::test_t19_t30_t31_statement_replay_conflict_and_authorization<br>midia/test_images.py::test_c42_ownership_and_unknown_fields_cannot_be_forged | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T32 | Trocar conta/local durante seleção, busca ou envio | frontend/test/cards_47_51_test.dart — T32 late response after account change cannot become confirmed | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T33 | Falha de storage, rollback e interrupção de processamento | modal_avaliacao/test_cards_47_51.py::test_t26_t33_photo_decision_and_points_are_one_database_transaction<br>midia/test_images.py::test_c42_storage_failure_is_recoverable_and_retry_reuses_operation<br>midia/test_images.py::test_c42_database_failure_rolls_back_and_keeps_durable_cleanup<br>midia/test_images.py::test_c45_cleanup_failure_retries_and_expired_processing_is_reconciled | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T34 | Reconciliador executado repetidamente | modal_avaliacao/test_cards_47_51.py::test_t21_t24_t25_t34_photo_points_grant_revoke_restore_stabilize_one_right<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T35 | Entrada por mapa, Salvos, central e lista de avaliações | frontend/test/map_navigation_contributions_test.dart — preview has direct review and reviews actions without a route<br>frontend/test/frontend_regression_test.dart — route request returns through saved place details to its caller | Depende de integração. Central Chrome e widgets de navegação verificados; percurso completo de todas as origens em ambos os dispositivos pendente. |
| T36 | Local OSM sem vínculo ou ID interno inválido | frontend/test/map_navigation_contributions_test.dart — review editor preloads own review and never treats OSM as internal | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T37 | Offline, 400, sessão expirada, 403, 409, 429 e timeout | frontend/test/cards_47_51_test.dart — T37 Retry-After blocks repeated HTTP writes during cooldown<br>frontend/test/cards_47_51_test.dart — T37 real service reads server Retry-After header | Depende de integração. API/controller cobrem erros e cooldown; injeção de todos os estados na interface real por plataforma pendente. |
| T38 | Teclado, leitor de tela, texto 200% e tela pequena | frontend/test/cards_47_51_test.dart — T38 resources at 200 percent, narrow keyboard, $locale<br>frontend/test/media_cards_42_46_test.dart — gallery viewer handles keyboard, Escape and focus return<br>frontend/test/contributions_central_test.dart — keyboard traversal reaches help and enter activates it | Depende de integração. Semântica, teclado, Escape, texto 200% e viewport pequeno em widgets; leitor de tela real não executado. |
| T39 | Foto enviada no Android e consultada no Chrome, e sentido inverso | Roteiro Android↔Chrome abaixo; não executado em dispositivo | Não executado. Não executado: requer aparelho/emulador Android e Chrome com a mesma API. |
| T40 | Reabrir app e consultar avaliação/fotos salvas | reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T41 | Remoção/ocultação com URL/miniatura previamente conhecida | midia/test_images.py::test_c42_ineligible_review_revokes_public_file_and_list<br>midia/test_images.py::test_c42_old_photo_report_never_rejects_replacement<br>reports/cards_47_51/browser_lab.json — percurso real Chrome/API/storage | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T42 | Voltar da revisão e editar uma seção | frontend/test/cards_47_51_test.dart — T01 T42 stars-only summary edits preserve comment and no mandatory survey | Verificado. Verificado no nível indicado; não equivale a homologação Android. |
| T43 | Recuperar seleção Android interrompida | frontend/lib/media/image_selection_service.dart — recoverableScope/pick guards (código)<br>frontend/test/media_cards_42_46_test.dart — picker result from another account is discarded | Depende de integração. Guarda conta/local testada; interrupção e recuperação nativa Android não executadas. |
| T44 | Regressão dos Cards 38–46 e funcionalidades afetadas | midia/test_images.py::test_c44_avatar_is_processed_preserves_base64_contract_and_remove_is_versioned<br>midia/test_images.py::test_c42_approved_photo_report_uses_existing_queue_and_no_reporter_exposure<br>pytest completo: 692 passed, 29 skipped, 21 subtests<br>flutter test completo: 933 passed | Verificado. Verificado no nível indicado; não equivale a homologação Android. |

## Arquivos e migrations

Contratos e roteiro detalhados em `docs/AVALIACOES_CARDS_47_51.md`. O manifesto da entrega relaciona
cada arquivo modificado/adicionado com seu hash anterior e posterior. Quatro migrations aditivas:

- `evidencias/0006`: recibos de operações individuais e marca de precedência.
- `evidencias/0007`: escolha determinística da afirmação efetiva e unicidade por autor/local/recurso,
  incluindo registros antigos sem revisão, retirados ou inválidos.
- `modal_avaliacao/0008`: detalhes opcionais por resposta e recibos de avaliação.
- `midia/0003`: orientação pública por código, separada da justificativa privada de moderação.

Sem alteração de credenciais, criação de usuários reais ou migração automática na aplicação do ZIP.
Sem Android SDK, dispositivo, leitor de tela e PostgreSQL/Redis real, os respectivos aceites continuam
pendentes. Não foi registrada falha funcional não corrigida nos níveis de teste executados.
