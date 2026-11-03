# Matriz de aceite — Cards 5A/5B/5C

Os critérios abaixo organizam a lista de aceite fornecida para esta continuação; não substituem o texto original dos cards. **Comprovado** significa que o comportamento tem implementação e evidência executada nesta sessão. **Parcial** indica requisito implementado ou coberto apenas em parte. **Bloqueado** indica dependência de ambiente não disponível.

## Card 5A — recompensa por denúncia procedente

| ID | Critério | Estado | Evidência / limite |
|---|---|---|---|
| 5A-01 | Só conceder em `invalidate` efetivo sobre a revisão exata de avaliação | Comprovado | `process_report_reward_for_decision()` em `contribuicoes/services.py`; teste de concessão e rollback em `contribuicoes/test_contributions.py` |
| 5A-02 | Escolher o denunciante elegível mais antigo, mesmo moderando protocolo mais novo | Comprovado | Dois denunciantes e ordem controlada no teste de `test_contributions.py` |
| 5A-03 | Limite de uma recompensa por revisão e por usuário/local/ação | Comprovado | Constraints em `contribuicoes/models.py` e migrations 0004; teste de segunda revisão no mesmo local |
| 5A-04 | Excluir autor da avaliação, conta inativa, foto, OSM e alvo sem local interno | Parcial | Teste exclui denúncia própria/inativa e denúncia de foto; faltam casos separados para OSM/alvo sem local |
| 5A-05 | Denunciante sem avaliação própria recebe e mantém o bônus, sem avaliação fictícia | Comprovado | Evento permanece sem `evaluation`; reconciliação e reparo testados |
| 5A-06 | Não premiar retroativamente conteúdo antigo | Parcial | Não há backfill na migration; concessão é disparada pela criação da decisão. Dados legados de produção não foram inspecionados |
| 5A-07 | Decisão, atribuição, evento e ledger são atômicos/recuperáveis | Comprovado | Falha injetada reverte invalidação; dry-run e reparo do evento/atividade testados |
| 5A-08 | Revogação/restauração formal autorizada, idempotente e auditável | Parcial | Serviço exige `evidencias.moderate_content`; sequência sintética `+5/-5/+5` foi executada no SQLite isolado e refletida no painel/histórico. A ação do Django Admin não teve teste HTTP próprio |
| 5A-09 | Histórico da denúncia não aparece como avaliação excluída | Comprovado | `ContributionHistoryCard` e widget test com evento sem avaliação |
| 5A-10 | API de próprias denúncias informa recompensa sem vazar dados internos | Comprovado | `ReportReadSerializer`, prefetch privado e teste de resposta do próprio denunciante |
| 5A-11 | Chaves e constraints impedem duplicação em replay | Comprovado | Retry após rollback e repetição do mesmo `operation_id` no teste; constraints validadas no SQLite de teste |
| 5A-12 | Concorrência real sem deadlock em PostgreSQL | Bloqueado | Adiado por decisão da equipe; não executado nesta etapa. SQLite não comprova concorrência real |

## Card 5B — Meu impacto e histórico

| ID | Critério | Estado | Evidência / limite |
|---|---|---|---|
| 5B-01 | Saldo atual usa pontos ativos do servidor, sem pontuação fictícia | Comprovado | `impact()` e testes do resumo/erro em `contributions_central_test.dart` |
| 5B-02 | Nível, progresso, próximo marco e estado máximo corretos | Comprovado | Widget tests de progresso e nível máximo |
| 5B-03 | Ações, saldo, avaliações e operações do histórico não se confundem | Parcial | Contadores separados no resumo; não há teste específico de todos os contadores |
| 5B-04 | Histórico identifica denúncia, data, local, delta, operação, estado e motivo | Comprovado | Homologação sintética exibiu local, data, `+5/-5/+5`, concessão/retirada/restauração, situação e razão no histórico; cobertura de todas as traduções permanece limitada |
| 5B-05 | Concessão, revogação e restauração são movimentos diferentes | Comprovado | Sequência `+5/-5/+5` observada separadamente no painel e no histórico da interface Web, após cada atualização |
| 5B-06 | Minhas denúncias separa andamento do protocolo e estado da recompensa | Comprovado | Campo privado `reward_status`, UI e widget test |
| 5B-07 | Cinco conquistas existentes preservam progresso e estado | Parcial | Tela mantém os cinco códigos existentes; suíte focalizada testa expansão, não todos os critérios de cada conquista |
| 5B-08 | Ajuda lista as cinco ações com valores atuais do backend | Comprovado | Teste cobre valores API de review, survey, comentário, foto e denúncia |
| 5B-09 | Pendências não pontuam e `Não sei` conta como resposta | Parcial | Regras e testes de questionário legado/completo existentes; sem teste integrado de cada estado da denúncia |
| 5B-10 | Loading, vazio, erro, retry, refresh e paginação | Comprovado | Cenários da suíte Flutter focalizada |
| 5B-11 | Logout/troca de conta limpa dados privados e respostas antigas | Parcial | Limpeza da tela de denúncias testada; cenários de troca em todos os fluxos não foram repetidos |
| 5B-12 | PT/EN, responsividade, 200%, teclado, foco e semântica | Parcial | Web verificada em 929×1500 e 390×844, sem overflow horizontal; snapshot semântico e ativação Tab/Enter confirmados; testes Flutter cobrem escala de texto até 200%. TalkBack/dispositivo físico não executados |

## Card 5C — integridade e cobertura

| ID | Critério | Estado | Evidência / limite |
|---|---|---|---|
| 5C-01 | `pending`, `keep`, `request_review`, `unavailable` e invalidação inefetiva pontuam zero | Comprovado | Testes parametrizados cobrem ações não efetivas e invalidação sem efeito; denúncia de foto efetiva também não pontua |
| 5C-02 | Invalidação efetiva concede exatamente uma vez | Comprovado | Teste de decisão, replay e contagem do evento/atividade |
| 5C-03 | Protocolos múltiplos escolhem o denunciante mais antigo | Comprovado | Teste moderando o protocolo mais novo primeiro |
| 5C-04 | Limites por usuário/local e por revisão | Comprovado | Constraints de banco e cenário de segunda revisão para o mesmo beneficiário/local |
| 5C-05 | Retry, `operation_id`, fingerprint conflitante e concorrência | Parcial | Retry/fingerprint conflitante cobertos e teste de corrida PostgreSQL adicionado; a execução da corrida foi adiada por decisão da equipe e permanece pendente |
| 5C-06 | Anulação `-5`, repetição zero, restauração `+5`, repetição zero | Comprovado | Serviço autorizado e ledger `+5/-5/+5` testados |
| 5C-07 | Correção legítima posterior preserva recompensa | Comprovado | Teste restaura a validade da avaliação e confirma que a atribuição concedida mantém os pontos |
| 5C-08 | Reconciliação sem avaliação própria; dry-run e convergência | Comprovado | Testes validam preview sem gravação, aplicação, descoberta global de beneficiário por atribuição e vínculo reparado |
| 5C-09 | Interrupção/rollback não deixa decisão ou atividade órfã | Comprovado | Falha simulada dentro da transação reverte a decisão e a invalidação |
| 5C-10 | Survey legado, comentários, fotos e regras anteriores preservados | Parcial | Módulos focalizados passaram; cenários completos não foram executados em PostgreSQL |
| 5C-11 | Permissão, privacidade, 401/403 e troca de sessão | Parcial | Serviço rejeita usuário sem permissão e API não expõe moderador; suíte completa de segurança/sessão não foi repetida |
| 5C-12 | Widget tests de ajuda, histórico, denúncias e estados de UI | Parcial | Testes focalizados cobrem os novos rótulos e fluxos existentes, não todas as combinações do aceite |
| 5C-13 | PostgreSQL real, locks e concorrência | Bloqueado | Adiado por decisão da equipe; não executado nesta etapa |
| 5C-14 | Quality Gate integral, cobertura mínima, lint e builds | Comprovado | Suíte backend completa pós-correções: 784 passed, 31 skipped, 21 subtests; 84,37% de cobertura. Flake8, Django check/migrations/OpenAPI, Flutter analyze/testes e builds passaram localmente; Flutter 3.47.5 difere da 3.47.4 fixada na CI |
| 5C-15 | Homologação visual, browser e leitor de tela | Parcial | Web homologada em viewport desktop/mobile com dados sintéticos e sem overflow horizontal; console registrou indisponibilidade 504 da fonte externa. TalkBack/dispositivo físico não executados |

## Síntese

Há implementação e evidência significativa nos três cards, mas o conjunto permanece **parcialmente aceito** até executar PostgreSQL/concurrency e validar TalkBack/dispositivo físico. O Quality Gate local pós-correções e a homologação Web em SQLite isolado passaram; isso não demonstra concorrência PostgreSQL.
