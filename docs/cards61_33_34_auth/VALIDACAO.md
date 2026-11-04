# Validação executada — 03/11/2026

Resultados desta continuação substituem as afirmações anteriores sem prova.

| Comando/ambiente | Resultado | Evidência |
|---|---|---|
| `python -m pytest usuarios/test_integrated_auth.py usuarios/test_account_security.py usuarios/test_security_regressions.py usuarios/test_security_redis.py -q` | 61 passou, 2 ignorados, antes de adicionar revogação na desativação e teste Redis progressivo | `reports/auth-backend-focused-run4.txt` |
| `.venv/auth-runtime/Scripts/python.exe -m pytest --cov=. --cov-report=term --cov-report=xml:reports/auth-coverage-final.xml --cov-fail-under=80 -q -p no:cacheprovider --basetemp=.venv/auth-runtime/pytest-full-final` | **806 passou, 32 ignorados, 21 subtests passaram, 1 warning; 84,33%** | `reports/auth-pytest-final.txt`, `reports/auth-coverage-final.xml` |
| Após reforços finais: `... -m pytest usuarios/test_integrated_auth.py usuarios/test_security_redis.py acessoja/test_secure_staging.py -q` | **60 passou, 2 ignorados**, inclui desativação, multiabas, IP rotativo e ausência de contagem em erros não credenciais | `reports/auth-backend-verified.txt` |
| `manage.py check` / `makemigrations --check --dry-run` | sem issues / sem migrations | `reports/auth-check-final-confirmed.txt`, `reports/auth-migrations-final-confirmed.txt` |
| `manage.py spectacular --file reports/auth-openapi.yaml --validate` / `flake8 .` | sucesso, sem mensagens / 0 violações | `reports/auth-openapi-final-confirmed.txt`, `reports/auth-flake8-final-confirmed.txt` |
| `flutter analyze` | sem issues | `reports/auth-analyze-gate.txt` |
| `flutter test` | **1.099 passou** | `reports/auth-flutter-completed.txt` |
| Últimos casos Flutter: fila de storage tardia, avisos reativos, 429 com relógio fake e login | **22 passou** | `reports/auth-test-notices-verified.txt` |
| `flutter build web` e build Web com `API_BASE_URL=http://localhost:17201` | sucesso | `reports/auth-web-completed.txt`, `reports/auth-web-identity.txt` |
| `flutter build apk --debug` | sucesso; avisos de AGP/Kotlin/SDK existentes | `reports/auth-apk-completed.txt` |
| Playwright + Chrome instalado, Flutter real 390×844, API/banco/perfil isolados | **6 verificações passaram:** login; cookie HttpOnly/Lax/12 h sem Token DRF; F5; fechar/reabrir perfil; duas abas/conta antiga401 sem revogar conta nova200; CSRF mutação 403/200 + logout204/me401 | `reports/auth-chrome-multitab-verified.txt` |

O navegador executou HTTP localhost: `Secure=false` esperado nesse ambiente. Asserções de F5 observaram `/me` 200 do bootstrap Flutter. Não equivalem a comprovação HTTPS de staging nem a TalkBack/Android físico.
Runner local do navegador: `.venv/auth-runtime/browser_check.py`; servidores, SQLite e perfil Chrome exclusivos sob `.venv/auth-runtime/`. Nenhuma credencial real foi usada. Tokens, senhas e valores de cookies não foram impressos como resultado de teste.

## Ambiente e bloqueios reais

- O Python disponível é 3.15. A primeira execução completa falhou na coleta sem `osmium`; outra execução parcial apresentou 35 falhas, inclusive mídia por Pillow inacessível ao subprocesso e contratos de autenticação antigos. Essas falhas não foram escondidas: os contratos foram atualizados e um runtime novo foi provisionado para permitir a execução completa acima.
- `.venv/auth-runtime` é um ambiente novo com system-site-packages; Pillow 13 instalado nele permite o worker de imagens. Shapely 2.2.0 e pyproj 3.8.0 foram usados localmente porque os pins 2.1.2/3.7.2 não têm wheels para Python 3.15. Requirements do repositório permanecem intactos. **A execução local não substitui CI Python 3.12 com pins.**
- A revisão automática rejeitou instalação na `.venv` compartilhada. Foi adotado o runtime novo isolado, sem substituir os pacotes compartilhados.
- Redis real ausente: testes de processos independentes implementados, mas ignorados sem `SECURITY_REDIS_TEST_URL`; atomicidade distribuída não aprovada. PostgreSQL/concorrência continua adiado pela equipe. Os demais skips também permanecem explícitos no relatório completo.
- Persistência após encerramento/reabertura em Android físico, TalkBack, cookies em HTTPS de staging e revisão manual de acessibilidade permanecem pendentes. Build APK e storage fake não comprovam dispositivo físico.
- `pytest.ini` exclui somente diretórios gerados/protegidos (reports/private-media/frontend e caches) da descoberta; nenhum módulo de testes do backend foi desativado. Gate de cobertura continua 80%.

A última rodada completa Flutter aprovou 1.099 testes em `reports/auth-flutter-completed.txt`. Após manter o aviso também na área autenticada, o escopo de login/sessão aprovou novamente 22 testes em `reports/auth-test-gate-scope.txt`, com analyze e build APK aprovados. As execuções intermediárias com falhas permanecem em reports; as expectativas de idioma dos avisos foram corrigidas.
