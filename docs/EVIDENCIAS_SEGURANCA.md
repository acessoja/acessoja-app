# Evidências — Cards 35, 36 e 37

Execuções locais de **21/10/2026**, com contas, senhas e endereços sintéticos.
Base develop `03f9722752aba4d452867e49e0dde89d8be031f9`, Card 34 preservado.
Nenhum serviço foi publicado e nenhuma conta real foi alterada.

## Resultado por card

| Card | Implementado e verificado localmente | Aceite real ainda pendente |
| --- | --- | --- |
| 35 | Recuperação Django/Djoser integrada, e-mail em memória, link confiável, TTL/validação/revogação/limites e formulário Web. | Entrega no SMTP real, navegador móvel e concorrência PostgreSQL no ambiente/CI. |
| 36 | Inventário/consentimentos, exportação própria, autorização/reautenticação, limpeza/exclusão recuperável, integridade do catálogo, UI e bridge de salvamento. | Ratificação do controlador, salvamento nativo Android e execução de PostgreSQL/restore com diário atual. |
| 37 | Configuração restrita, infraestrutura/scripts, logs/probe e TLS/proxy em laboratório real local. | **Preparado para implantação; validação externa pendente**. Domínio/certificado público, persistência, operação e restauração real ainda não comprovados. |

## Comandos e resultados executados

Ambiente: Linux, Python 3.12.14; Django 5.2.18/DRF 3.16.1/Djoser 2.3.5;
Flutter 3.47.4/Dart 3.13.3. Banco dos testes gerais: SQLite isolado. Redis real
local 6.2.14 usado para os testes multiprocesso; Compose referencia Redis 7.4,
que ainda precisa de validação na implantação. Não há Docker/PostgreSQL executável
sob usuário não-root nem Android SDK neste ambiente. `initdb` exige não-root;
os testes que dependem dessas garantias não foram substituídos por SQLite.

| Comando/execução | Resultado | Evidência |
| --- | --- | --- |
| `python -m pip check` | Sem dependências quebradas | reports/cards_35_37/VALIDACAO.json |
| `python manage.py check` | Sem issues | Relatório de validação |
| `python manage.py makemigrations --check --dry-run` | Nenhuma alteração pendente | Relatório de validação |
| `python manage.py migrate --noinput` em SQLite novo | Todas as migrations aplicadas | Relatório de validação; migration test real de 0005→0006 |
| `python manage.py spectacular --fail-on-warn` | Gerado sem avisos | Schema derivado das views/serializers, incluindo exportação JSON |
| Flake8 do CI, sem mudar limite/exclusões | Zero violações | Relatório de validação |
| `pytest --cov=. --cov-report=term-missing --cov-fail-under=80 -q` | **586 passed, 15 skipped, 21 subtests passed**, 136,62 s; cobertura **84,56%** | coverage no relatório; gate de 80% mantido |
| `pytest usuarios/test_security_redis.py locais/test_geographic_redis.py -q`, com Redis isolado | **4 passed**, 2,36 s | Oito processos na segurança: cinco admissões para o mesmo e-mail, sem identificador em claro nas chaves |
| `python manage.py check --deploy` com settings_staging e variáveis sintéticas restritas | Exit 0, **dois avisos não silenciados**, W005/W021 | reports/cards_35_37/check_deploy.txt |
| `scripts/verify_proxy_lab.py` com Gunicorn 26.2.2 + Caddy 2.11.7 reais | TLS/redirect/cookie/proxy/schema/503/logs/fallback aprovados | reports/cards_35_37/proxy_lab.json |
| `flutter analyze --no-pub` | **No issues found**, 4,4 s | Relatório de validação |
| `flutter test --no-pub --reporter expanded` | **877 tests passed**, aproximadamente 78 s | Suíte completa, incluindo 15 casos novos de conta e 2 capturas/guidelines |
| `flutter build web --no-pub` | **Built build/web**, compilação 48,7 s; dry run Wasm passou | Relatório de validação. Build não incluído no delta. |
| `flutter build apk --debug --no-pub` | **Bloqueado: No Android SDK found** | Não aprovado; executar em CI/máquina com SDK e dispositivo |

Os 15 skipped incluem concorrência PostgreSQL, restauração PostgreSQL e casos
opcionais já existentes. Redis foi exercitado separadamente de verdade. O CI foi
preparado, mas não foi disparado, pois não houve push/PR. Um job escrito não é
uma execução aprovada. Não houve redução do gate nem remoção de regressões.

## Matriz requisito → cenário → resultado

| ID | Verificação/evidência | Resultado e limite |
| --- | --- | --- |
| R01 | `usuarios/test_account_security.py`: fila e PasswordResetEmail em memória; host recebido não escolhe destino | Passou local. Entrega real pendente. |
| R02 | Conta existente/inexistente/inativa/inutilizável; resposta 204 e falhas SMTP fora da requisição | Passou; sem promessa de duração exatamente constante. |
| R03 | Reset válido, nova senha aceita e antiga recusada | Passou. |
| R04 | UID inválido/muito grande, token adulterado/expirado/reutilizado; relógio controlado | Passou, senha preservada na rejeição. |
| R05 | Senha fraca e repetição divergente; validadores Django também nas rotas customizadas | Passou. |
| R06 | Tokens/sessões revogados; rotas Djoser/customizadas; foto/perfil com snapshot autenticado antigo | Passou. Não houve JWT novo. |
| R07 | Limites IP+identificador, JSON inválido, cache indisponível, timeout/retry SMTP; Redis multiprocesso | Passou local; TLS/entrega do SMTP real pendentes. |
| R08 | Teste `postgresql_concurrent` de duas confirmações com o mesmo token | Preparado e skipped aqui; executar no job PostgreSQL. Não comprovado por SQLite. |
| R09 | `frontend/test/account_privacy_test.dart`: rota fria/rebuild sem onboarding, recovery público; build Web; proxy fallback | Passou no harness e servidor local. Caixa de e-mail→navegador real/móvel pendente. Laboratório usa página sintética de fallback, não sessão de navegador real. |
| P01 | Preferências próprias, concessão/revogação idempotente, falha/retry UI e origem separada | Passou. Versão atual obrigatória para concessão; revogação não exige nova concordância. |
| P02 | `test_privacy_migration.py`: migra 0005→0006 com usuários legados, UUIDs distintos e sem consentimento criado | Passou; flags antigas preservadas e coleta efetiva pausada. |
| P03 | Exportação de categorias reais/datas e metadados próprios; sem credenciais/PII privada da outra conta | Passou; omissões e limite documentados no JSON/aviso. |
| P04 | Visitante, ID/nome injetado, campos desconhecidos e acesso a outro usuário | Passou; servidor deriva titular da autenticação. |
| P05 | Exclusão com senha incorreta, confirmação ausente/falsa; dois caminhos da API | Passou, sem apagar dados na rejeição. |
| P06 | Exclusão e limpeza no cliente; tokens, dados próprios e avaliações removidos; catálogo/terceiros preservados | Passou; estabelecimento legado SET_NULL, sem autor genérico. |
| P07 | Média passa a refletir só avaliações restantes; eventos/pontos da outra conta preservados | Passou com os serviços/signals existentes. |
| P08 | Falha após apagar → rollback; falha de diário antes →503; após commit →202/reconciliação; repetição | Passou local. Concorrência de exclusão PostgreSQL ainda pendente. |
| P09 | Tar privado/hash/travessia/links; diário ausente/substituído bloqueia; comando de supressão | Guardas e mídia local passaram. Restauração integral PostgreSQL/smoke preparada, skipped aqui. Cópia atual independente do diário é obrigação operacional. |
| I01 | `acessoja/test_secure_staging.py`: configurações inválidas, hosts, CORS, segredo, cache/banco/SMTP/proxy | Passou. Settings reais do host ainda precisam de revisão. |
| I02 | Proxy real local com CA temporária, HTTP→HTTPS, cookie secure, forged XFP direto recusado; CSRF/Admin e docs restritas | Passou local. Certificado público/DNS, restrição CIDR no host e conteúdo misto reais pendentes. |
| I03 | Canários de token/Authorization/cookie/e-mail/coordenadas em app/proxy; audit metadata minimizado | Passou no logger e laboratório. Retenção/rotação no host ainda precisa ser ativada. |
| I04 | DB/cache/fila/diário afetam prontidão; probe HTTP real 503→200; volumes configurados | Falha/recuperação local passou. Reinício/recriação persistente em Docker/provedor e alertas reais pendentes. |
| I05 | `acessoja/test_backup_restore.py`: integridade/retensão/fingerprint/target e teste PostgreSQL de dump→restore→supressão→smoke | Guardas locais passaram; teste real PostgreSQL skipped. Nenhum dump/restauração real foi declarado executado. |
| U01 | Widget tests a 320×640, teclado 240 px, escalas 1/2 e claro/escuro; labels/touch guidelines e capturas com Roboto | Passou. Leitor de tela real e Android físico pendentes; captura não é screenshot de dispositivo. |
| G01 | Suítes gerais preservadas de cadastro/login, perfil, mapa, favoritos, avaliações, contribuições e histórico | 586 backend e 877 Flutter aprovados; integrações externas do provedor seguem dependentes do ambiente. |

## Evidência visual

Capturas sintéticas produzidas pelo renderer de widgets, com fontes reais do
projeto e sem dados pessoais. São apoio à revisão de legibilidade; não substituem
teste assistivo/dispositivo ou navegador real.

- `capturas/cards_35_37/recuperacao_claro.png`: solicitação em tema claro.
- `capturas/cards_35_37/privacidade_200_escuro.png`: texto 200%, tema escuro,
  quebra de linhas e página rolável. A imagem mostra somente o viewport inicial.

## Aplicação do pacote

O aplicador foi exercitado sobre cópia limpa da base, com validação sem escrita,
aplicação com backup, reaplicação idempotente, aceitação de LF/CRLF, rejeição
de alteração local antes de escrever e bloqueio de caminho fora do projeto.
Não executa migrations ou Git. O ZIP final passa por CRC e conferência dos hashes
de todos os arquivos do manifesto; arquivos removidos: nenhum.

## Próxima validação externa, por responsável

1. Equipe de conta: SMTP real em caixa sintética; fluxo completo link→nova senha→
   login e recusa das credenciais anteriores, nos navegadores usados pelo piloto.
2. CI/operação: rodar job PostgreSQL com pg_dump/pg_restore 16; demonstrar
   concorrência, restauração isolada, contagens, supressão e smoke; registrar duração.
3. Operação: domínio/TLS público, restrição piloto/Admin/docs, persistência após
   recriação, diário atual fora do host, backups externos/expurgo, logs e probes/alertas.
4. Mobile/acessibilidade: build APK, salvar/cancelar JSON em Android, browser
   fallback da recuperação e leitor de tela real; desktop Web com teclado/foco.
5. Controlador: validar finalidades/bases/prazos, contato e processo assistido;
   conciliar referências da especificação conforme o adendo.

Não marcar esses passos como atendidos apenas porque os testes locais passaram.
