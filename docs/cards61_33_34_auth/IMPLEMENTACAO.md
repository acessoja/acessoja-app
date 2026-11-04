# Cards 61, 33, 34, AUTH-WEB-01, AUTH-01 e AUTH-02

Base preservada: `develop`, `402cc9e1d432110f0bc98b74b44c2b2aeaec3ed4`, igual a `origin/develop` na leitura inicial.
As nove modificações locais do Copilot foram continuadas; backups, capturas e worktrees existentes foram preservados. Sem commit/push/merge/reset/clean.
As afirmações anteriores de aceite integral foram substituídas por evidências executadas nesta continuação.

- **61:** Token DRF continua com 43.200 s, revogação por logout/senha/desativação e `/api/usuarios/me/` sem identificador e sem token. A API remove Basic e sessão genérica; o adapter Web aceita apenas sessões marcadas pelo login Web. Admin mantém seu mecanismo; prévias de mídia permitem sessão administrativa somente em leitura. OpenAPI distingue Token/cookie.
- **33:** `AuthSessionController` é a identidade compartilhada e `ChangeNotifier` publicado por Provider; `AppHttp` preserva a fachada e `sessionRevision` usada pelos controllers existentes. Estados, perfil e geração são únicos. Respostas antigas e operações Web aguardando CSRF não podem assumir uma conta nova. Um identificador não secreto em `X-Session-User` vincula cada aba à identidade que ela validou: o servidor apenas compara com request.user, rejeitando aba antiga sem encerrar o cookie da conta nova. Login inválido/403/429/503 não encerram a sessão atual. Filtros, mapas, favoritos, mídia e demais controllers continuam usando suas invalidações existentes.
- **34:** adapter `SecureSessionStore` injetável, plugin nativo e fake nos testes. Bootstrap valida `/me` antes de conteúdo privado; offline preserva credencial e oferece retry. Operações de storage são serializadas; timeout limita a espera da UI sem liberar a ordem da operação nativa ainda pendente. Falhas de persistência/limpeza e revogação remota têm avisos visíveis e reativos. Backup Android desativado. Logout limpa localmente e distingue revogação remota não confirmada.
- **AUTH-WEB-01:** reaproveita `/auth/session/login/` (GET CSRF, POST login), `/auth/session/me/` e `/auth/session/logout/`. Django roda `login/logout`, rotaciona credenciais e registra início absoluto de 12 h. CSRF obrigatório no login e nas operações privadas. Cookie HttpOnly/SameSite=Lax, Secure em staging. Web usa BrowserClient com credentials apenas para API; nunca recebe/grava Token DRF. Login confirma cookie em `/me`; F5 usa bootstrap. Releases exigem HTTPS fora de loopback. No localhost HTTP, Secure é falso por configuração de desenvolvimento.
- **AUTH-01:** regra de senha existente mantém mínimo 8, máximo 4096, sem trim e sem regras de composição. Django valida senhas comuns offline, numéricas e semelhantes a nome/e-mail. Cadastro valida nome latino 3–30/reservados, EmailField 254 e duplicados sem distinguir caixa. Registro PostgreSQL serializa checagem/criação por advisory lock; sem constraints/migrations sobre dados legados não examinados. UI tem orientação, contagem de caracteres, mostrar/ocultar, autofill e erros próximos aos campos, PT/EN.
- **AUTH-02:** mantém throttle base 30/IP e 10/identificador/60 s; falhas reais compartilham contador por identificador+origem entre os três logins. Após 5/8/12: 30/120/900 s, janela 900 s; durações configuráveis. HMAC nas chaves, Lua atômico em Redis, LocMem apenas local, 503 em indisponibilidade. Sucesso limpa somente seu par. Campos extras email/uid não alteram a chave do nome de login; teste com IP rotativo comprova limite agregado. UI 429 acessível tem Retry-After/contagem com relógio injetável e não reenvia automaticamente.

Senha de 8 é decisão do projeto: não representa conformidade plena NIST SP 800-63B-4, cujo mínimo single-factor é 15. Formato de e-mail não comprova posse. Contas legadas não foram renomeadas; concorrência PostgreSQL e imposição de unicidade em escritores legados continuam sem prova local.
Nenhuma migration foi criada/aplicada ao banco habitual. Testes e navegador usam dados sintéticos isolados.

## Arquivos de implementação e testes alterados

- `acessoja/authentication.py`
- `acessoja/security_middleware.py`
- `acessoja/security_settings.py`
- `acessoja/settings.py`
- `acessoja/test_secure_staging.py`
- `acessoja/views.py`
- `frontend/android/app/src/main/AndroidManifest.xml`
- `frontend/lib/config.dart`
- `frontend/lib/main.dart`
- `frontend/lib/screens/login_screen.dart`
- `frontend/lib/screens/register_screen.dart`
- `frontend/lib/services/api_service.dart`
- `frontend/lib/services/app_http.dart`
- `frontend/lib/services/places_service.dart`
- `frontend/lib/widgets/external_place_registration.dart`
- `frontend/macos/Flutter/GeneratedPluginRegistrant.swift`
- `frontend/pubspec.lock`
- `frontend/pubspec.yaml`
- `frontend/test/login_screen_test.dart`
- `frontend/windows/flutter/generated_plugin_registrant.cc`
- `frontend/windows/flutter/generated_plugins.cmake`
- `locais/test_discovery_integrated.py`
- `locais/test_external_places.py`
- `midia/views.py`
- `pytest.ini`
- `usuarios/account_serializers.py`
- `usuarios/account_services.py`
- `usuarios/account_urls.py`
- `usuarios/account_views.py`
- `usuarios/backends.py`
- `usuarios/models.py`
- `usuarios/security_throttles.py`
- `usuarios/test_account_security.py`
- `usuarios/test_security_redis.py`
- `usuarios/urls.py`
- `frontend/lib/screens/session_gate.dart`
- `frontend/lib/services/auth_session_controller.dart`
- `frontend/lib/services/secure_session_store.dart`
- `frontend/lib/services/session_client.dart`
- `frontend/lib/services/session_client_web.dart`
- `frontend/test/auth_session_test.dart`
- `frontend/test/flutter_test_config.dart`
- `usuarios/test_integrated_auth.py`
- `docs/cards61_33_34_auth/IMPLEMENTACAO.md`
- `docs/cards61_33_34_auth/VALIDACAO.md`
- `docs/cards61_33_34_auth/MATRIZ_ACEITE.md`

Relatórios executados: `reports/auth-*`. Estado Git completo: [auth-git-status.txt](../../reports/auth-git-status.txt); inclui também artefatos preexistentes não modificados nesta continuação.
