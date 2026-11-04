# Matriz de aceite — evidências desta continuação

Comprovado identifica o escopo descrito na evidência; mock/build não prova Android físico ou infraestrutura real.
Comandos, contagens, versões e limitações estão em [VALIDACAO.md](VALIDACAO.md).
As marcações integrais anteriores foram corrigidas: não existiam provas para Provider completo, CSRF obrigatório ou progressão5/8/12.

| Card | Estado resumido | Limite da comprovação |
|---|---|---|
| 61 | Comprovado | Backend/API/OpenAPI e configuração de segurança testados localmente |
| 33 | Comprovado | Controllers/Provider, regressão Flutter e Web Chrome |
| 34 | Parcial | Storage fake e APK aprovados; Android físico/TalkBack pendentes |
| AUTH-WEB-01 | Parcial | Chrome localhost/F5/reabertura/multiabas aprovados; HTTPS staging pendente |
| AUTH-01 | Parcial | Regras e UI automatizadas; concorrência PostgreSQL e revisão manual pendentes |
| AUTH-02 | Parcial | Progressão/429/503/IP rotativo aprovados; Redis real pendente |

## [Token, autorização e identidade — 61](https://trello.com/c/Ydcfu94m)

| ID | Critério | Estado | Evidência |
|---|---|---|---|
| 61-01 | Login Token DRF preservado | Comprovado | Backend completo; test_native_me_and_revocation_remain_token_based |
| 61-02 | TTL absoluto 43.200 s | Comprovado | Testes de expiração Token e sessão no backend |
| 61-03 | Logout revoga credenciais | Comprovado | test_native_me_and_revocation_remain_token_based |
| 61-04 | Troca/reset/desativação revogam | Comprovado | test_account_security + test_deactivation_revokes_token_and_cookie_even_after_reactivation |
| 61-05 | Posse vem de request.user; spoof negado | Comprovado | Testes de perfil, favoritos, contribuições, mídia e preferências na suíte completa |
| 61-06 | /api/usuarios/me/ sem token e no-store | Comprovado | test_cookie_authenticates_product_api_and_requires_csrf_for_mutation |
| 61-07 | 401/403 distintos | Comprovado | Backend completo; CSRF403 e me401 no Chrome |
| 61-08 | Moderação restrita | Comprovado | Testes evidencias/midia/modal_avaliacao completos |
| 61-09 | APIs públicas preservadas | Comprovado | Regressão locais completa |
| 61-10 | Basic/sessões genéricas fora da API de produto; Admin preservado | Comprovado | test_secure_staging; test_admin_session_can_read_pending_file_and_has_initial_review_surface |
| 61-11 | OpenAPI distingue Token e cookies | Comprovado | auth-openapi-clean.txt e auth-openapi.yaml |
| 61-12 | HTTPS obrigatório no staging configurado | Comprovado | test_secure_staging; deploy HTTPS real permanece fora desta comprovação |

## [Estado compartilhado — 33](https://trello.com/c/xCrpCWbQ)

| ID | Critério | Estado | Evidência |
|---|---|---|---|
| 33-01 | Provider publica um AuthSessionController | Comprovado | flutter analyze + suíte Flutter completa |
| 33-02 | Estados de autenticação e bootstrap | Comprovado | auth_session_test + Chrome |
| 33-03 | Web e nativo usam mesma identidade | Comprovado | Adapters condicionais; testes nativos fake + Chrome Web real |
| 33-04 | Geração impede respostas antigas | Comprovado | old account response e late secure-storage read em auth_session_test |
| 33-05 | Favoritos isolados por sessão | Comprovado | favorites_controller/integration tests |
| 33-06 | Mídia privada é invalidada | Comprovado | Regressão Flutter mídia + sessionRevision |
| 33-07 | Perfil/preferências/histórico não retornam de conta antiga | Comprovado | Regressão controllers e navegação Flutter |
| 33-08 | Visitante/filtros/categorias/paginação/mapa preservados | Comprovado | Suíte completa Flutter + backend locais |
| 33-09 | Credenciais restritas à origem da API | Comprovado | external origins never receive private headers; map_navigation_contributions_test |
| 33-10 | 401 atual expira; 403/429/503 não deslogam | Comprovado | auth_session_test; invalid login preserves existing identity |
| 33-11 | Sem retry automático; cadastro/login acessíveis por teclado | Comprovado | login_screen_test com relógio injetado; register_screen_test |
| 33-12 | Troca A→B/retornos privados em widgets | Comprovado | route_stack_history_cards_59_61 e auth_session_test; execução física não inferida |

## [Sessão nativa — 34](https://trello.com/c/knA1R3Bj)

| ID | Critério | Estado | Evidência |
|---|---|---|---|
| 34-01 | Plugin de armazenamento protegido integrado | Parcial | APK debug compila; keystore físico não exercitado |
| 34-02 | SecureSessionStore injetável com fake | Comprovado | auth_session_test + flutter_test_config |
| 34-03 | Bootstrap valida antes da identidade privada | Comprovado | native bootstrap validates before publishing identity |
| 34-04 | Token inválido limpa storage | Comprovado | confirmed invalid bootstrap erases protected token |
| 34-05 | Offline/503 mantém token sem liberar privado | Comprovado | offline bootstrap preserves protected token |
| 34-06 | Falha de storage mantém memória e aviso | Comprovado | storage failure retains session in memory with explicit warning; teste de aviso visível/reativo |
| 34-07 | Logout local e geração segura | Comprovado | Regressão AppHttp/logout; sessão anterior não encerra nova conta |
| 34-08 | Senha/revogação detectadas pelo endpoint de validação | Comprovado | Backend reset/logout/me e bootstrap fake; sem simular prova física |
| 34-09 | Web não grava Token DRF | Comprovado | Chrome real e Token.objects ausente após login Web |
| 34-10 | Backup Android desativado | Parcial | Manifest + build APK; restauração de backup não exercitada |
| 34-11 | Tema/onboarding/deep links preservados | Comprovado | Regressão Flutter completa |
| 34-12 | Reabrir Android dentro de 12 h | Bloqueado | Dispositivo físico indisponível |
| 34-13 | TalkBack e foco no Android físico | Bloqueado | Sem execução física |

## [AUTH-WEB-01 — WEB](https://trello.com/c/YwBEuKJu)

| ID | Critério | Estado | Evidência |
|---|---|---|---|
| WEB-01 | Login Web não emite Token DRF | Comprovado | Chrome real + verificação no banco isolado |
| WEB-02 | Cookie HttpOnly/SameSite=Lax/TTL | Comprovado | Chrome real localhost: Secure=false; configuração staging exige Secure=true |
| WEB-03 | CSRF no login e mutações reais | Comprovado | test_cookie_login_requires_csrf_and_rejects_external_origin; Chrome403/200 |
| WEB-04 | Sessão autentica APIs privadas e mídia | Comprovado | test_cookie_authenticates_product_api_and_requires_csrf_for_mutation; suíte mídia |
| WEB-05 | TTL absoluto em todos os endpoints | Comprovado | test_absolute_cookie_ttl_applies_to_every_private_endpoint; adapter mídia também valida |
| WEB-06 | F5 e reabertura Chrome preservam login | Comprovado | auth-chrome-multitab-verified.txt: Flutter real e perfil persistente |
| WEB-07 | Logout/reset/desativação invalidam | Comprovado | Chrome logout204/me401 + testes backend |
| WEB-08 | Offline/429/503, no-store e retry controlado | Comprovado | auth_session_test + backend + login_screen_test |
| WEB-09 | HTTPS staging, multiabas/troca de conta e revisão manual completa | Parcial | Chrome: duas abas negam identidade antiga sem revogar cookie novo; execução HTTPS e jornada manual completas pendentes |

## [AUTH-01 — REG](https://trello.com/c/rZ7bDRQ7)

| ID | Critério | Estado | Evidência |
|---|---|---|---|
| REG-01 | Mínimo8 sem trim e sem composição obrigatória | Comprovado | test_registration_password_policy; validators Django |
| REG-02 | 7/fraca/números rejeitados; 8 forte/64+/Unicode/espaços aceitos | Comprovado | Casos parametrizados test_registration_password_policy |
| REG-03 | Similaridade/comuns offline; reset/troca uniformes | Comprovado | test_account_security + configuração de similaridade para nome/email |
| REG-04 | Nome3–30/reservados/duplicados case-insensitive | Comprovado | test_registration_rejects_invalid_new_names + test_case_insensitive_name_and_email_duplicates |
| REG-05 | EmailField254 e normalização; sem alegar posse verificada | Comprovado | Regressão cadastro/perfil backend |
| REG-06 | Corridas PostgreSQL e compatibilidade de escritores legados | Parcial | Advisory lock implementado; concorrência PostgreSQL permanece adiada, sem novas constraints |
| REG-07 | Feedback PT/EN, autofill, visibilidade, erros e teclado | Comprovado | Regressão login/register/readability Flutter |
| REG-08 | 320px/zoom200 e leitura de tela real | Parcial | Layouts widget aprovados; revisão humana/TalkBack pendente |

## [AUTH-02 — THR](https://trello.com/c/Ez48u5TM)

| ID | Critério | Estado | Evidência |
|---|---|---|---|
| THR-01 | Throttle base preservado e falhas separadas | Comprovado | security_throttles + regressão backend |
| THR-02 | Progressão5/8/12 e cooldown30/120/900 | Comprovado | test_failure_progression_and_cooldowns_without_sleep; cache local controlado |
| THR-03 | Três contratos compartilham orçamento de falhas | Comprovado | test_login_contracts_share_failed_credential_budget |
| THR-04 | Sucesso limpa somente par apropriado | Parcial | Adapter local testado; prova Redis por processos implementada mas não executada |
| THR-05 | 429/Retry-After/no-store; cache indisponível503 | Comprovado | test_cache_failure_is_503_not_credential_failure + testes API |
| THR-06 | Sem penalizar CSRF/missing password/429/5xx como falha de senha | Comprovado | Fluxo de validação e regressão backend; CSRF real403 |
| THR-07 | Lua atômico/HMAC/TTL em Redis real | Bloqueado | SECURITY_REDIS_TEST_URL não disponível; teste real ignorado explicitamente |
| THR-08 | UX429 PT/EN/countdown sem retry e recuperação acessível | Comprovado | Novo login_screen_test com relógio injetado + auth_session_test |
| THR-09 | IP rotativo/NAT/proxies/observabilidade distribuída | Parcial | ProxyGuard, HMAC e IP rotativo/campos extras testados; validação operacional distribuída/NAT pendente |
