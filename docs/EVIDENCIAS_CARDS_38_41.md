# Evidências — Cards 38, 39, 40 e 41

Execução em 25/10/2026, com dados sintéticos e base develop `f13ba0270b5a808caf8611ea1f504ff2f6cb55f5`. Nenhum banco pessoal, credencial real, dump OSM grande ou estado de conta acompanha a entrega. Código foi confrontado com a develop efetiva, que já integrou os Cards 35–37. Não houve commit, push, PR, publicação, envio de mensagens ou alteração de Trello.

## Ambiente e resultados

Python 3.12.14, Django 5.2.18, SQLite, Redis real local 6.2.14; Flutter 3.47.4/Dart 3.13.3. Jobs existentes PostgreSQL 16 e Redis 7 preservados; os novos testes de concorrência foram incluídos no job PostgreSQL. O Redis local foi iniciado em instância temporária dedicada, sem persistência, com testes em processos independentes.

Backend: **628 testes e 21 subtestes aprovados**, **18 ignorados** e zero falhas. Cobertura de linhas/branches pelo gate: **85.30%** (mínimo 80%). Desses, **38 cenários novos do app evidencias passaram**; os **7 cenários novos de PostgreSQL** foram explicitamente ignorados por indisponibilidade desse banco. Os demais skips são testes anteriores específicos de PostgreSQL/restauração.

Frontend: **892 testes passaram**, `flutter analyze` sem apontamentos e `flutter build web` concluído. Os **15 testes novos** de `evidence_cards_38_41_test.dart` fazem parte dessa execução. A tentativa de `flutter build apk --debug` terminou com **No Android SDK found**; não houve APK aprovado. O Chromium não estava instalado e a tentativa de preparar o navegador retornou arquivo de download inválido/truncado. Portanto, roteiro manual Chrome, Android e leitor de tela real permanecem pendentes.

| Comando/check executado | Resultado | Evidência |
| --- | --- | --- |
| `python -m pip check` | Passou | `reports/cards_38_41/checks.json` |
| `python manage.py check` | Sem problemas | Mesmo relatório |
| `python manage.py makemigrations --check --dry-run` | Sem migrations pendentes | Mesmo relatório; migrations novas incluídas no delta |
| `python manage.py migrate --noinput` em banco limpo | Passou | Mesmo relatório; testes de backfill adicionais |
| `python manage.py spectacular --fail-on-warn --validate --file ...` | Schema validado sem avisos | `reports/cards_38_41/openapi.yaml` e checks |
| Flake8, plugins e limite 120 do job existente | Zero violações | `checks.json` |
| `pytest --cov=. --cov-report=term-missing --cov-fail-under=80` com Redis dedicado | Resultado exato acima; gate 80% preservado | `backend_tests.json`, com nome/status/duração de cada cenário e totais de cobertura |
| `flutter analyze` | Sem infos, warnings ou erros | `flutter_analyze.txt` |
| `flutter test` | 892 passaram | `frontend_tests.json` |
| `flutter build web` | Build concluído | `flutter_web.txt` |
| `flutter build apk --debug` | Bloqueado por falta do Android SDK | `flutter_apk_attempt.txt` |
| Aplicação do delta em cópia limpa da base | Cinco cenários passaram | `installer_tests.json`; repetir na cópia de revisão |

Arquivos de relatório são resumos de execução real, sem publicar corpos de requisição, tokens, senhas ou dados pessoais. Contagens do JUnit incluem subtestes, conforme indicado. A compilação Web não é prova de roteiro manual de navegador.

## Matriz por requisito

Nos módulos abaixo, `flow` significa `evidencias/test_flow.py`, `integrity` significa `evidencias/test_integrity.py`, `PG` significa `evidencias/test_postgresql.py`, e `widgets` significa `frontend/test/evidence_cards_38_41_test.dart`. Os relatórios listam os nomes completos efetivamente executados.

| Requisito | Cenário/evidência automatizada | Resultado e limite |
| --- | --- | --- |
| C38-01 | Backfill de duas avaliações com UUIDs distintos; envio conhecido não vira observação; teste histórico de flags/autores/datas preservado | Passou em SQLite, inclusive execução dos dois testes de migração em sequência |
| C38-02 | Origens por recurso, referências OSM, ausência de identidade pessoal; fontes mistas e legado | Passou em flow/integrity e testes anteriores de acessibilidade/catálogo |
| C38-03 | Editar rampa conserva revisão/data do banheiro; mudança recebe nova data por recurso | Passou em flow/integrity |
| C38-04 | Retry conserva confirmação, contagens, estrelas, pontos, visitas e histórico de rota | Sequencial passou; concorrência real é um dos sete testes PG pendentes |
| C38-05 | Revisão anterior retorna 409 e não confirma novo valor | Passou no backend e widgets |
| C38-06 | Relógio controlado, limiar, data desconhecida, futura, sem fuso e somente dia | Passou, sem fabricar hora para data de calendário |
| C38-07 | Presença/ausência, desconhecido, não aplicável, resposta efetiva por autor e confirmação sem novos votos | Passou em flow e agregação anterior preservada |
| C38-08 | Perfil privado, avaliação inválida/arquivada e histórico de outra pessoa fora da projeção pública | Passou, também para a própria conta privada consultando indicadores públicos |
| C39-01 | Parsing de campos ausentes/nulos, legado sem origem/data | Passou em widgets |
| C39-02 | Fontes mistas, registro recente sem observação, confirmação antiga | Backend temporal e widgets de rótulos passaram |
| C39-03 | Divergência descrita por texto, sem depender da cor | Passou em widgets e regras de agregação |
| C39-04 | Confirmação explícita, relato próprio, falha com rascunho, 401 e 409 | Passou; login de retorno simulado em widget, não autenticação E2E de navegador |
| C39-05 | Resposta atrasada de outro local/conta e limpeza de formulário na troca de conta | Passou em serviço/widgets |
| C39-06 | Formulário estreito 320 px, texto 200%, tema escuro, teclado e semântica; diretrizes Flutter anteriores de prévia preservadas | Passou; não equivale a leitor de tela real |
| C40-01 | Denúncia de avaliação e recurso, inclusive OSM sem Local, recibo real | Passou em flow/integrity |
| C40-02 | Visitante, conta/token e alvo privado; consulta de outra conta | Backend recusa; fluxo visitante oferece login |
| C40-03 | Tipo/alvo incompatíveis, motivo inválido, outro sem contexto, limite e campos de autoridade injetados | Passou em flow/integrity |
| C40-04 | Autodenúncia recusada e edição própria preservada | Passou |
| C40-05 | Retry mudando motivo, inclusive após manter/encerrar | Passou sequencial; corrida PostgreSQL pendente |
| C40-06 | 429/Retry-After, cache de segurança indisponível e rede sem protocolo fictício | Passou em backend/serviço/widgets; Redis compartilhado da base também foi exercitado |
| C40-07 | Titular A não consulta B; exportação própria e orientação ao autor sem denunciante | Passou |
| C40-08 | Receber denúncia não muda notas, pontos, recursos ou visibilidade | Passou |
| C40-09 | Alteração/remoção preserva UUID histórico e informa changed/unavailable | Passou, incluindo remoção de cadastro e exclusão da conta |
| C41-01 | Staff sem permissão e usuário comum não leem fila/decidem | Passou em serviços e Admin |
| C41-02 | Justificativa obrigatória, formulário e histórico | Passou; mensagem livre ao autor é recusada |
| C41-03 | Invalidar avaliação reconcilia ledger; recurso isolado não penaliza estrelas/comentário | Passou na mesma transação |
| C41-04 | Operação repetida e múltiplos denunciantes geram uma medida, trilha por protocolo | Passou sequencial; mesma operação concorrente consta em PG |
| C41-05 | Dois moderadores, edição e exclusão durante análise | Sete testes PG preparados; não executados sobre PostgreSQL local |
| C41-06 | Revisão antiga, avaliação alterada e alvo removido | Passou; nova revisão não é punida por formulário antigo |
| C41-07 | Falha intermediária reverte validade/estado/pontos; callbacks só após commit; cache pode falhar sem publicar conteúdo inválido | Passou em flow/integrity |
| C41-08 | POST no Admin usa serviço único; validade e histórico não editáveis/excluíveis no fluxo comum | Passou |
| C41-09 | Mesmo lote/nome novo não renovam revisão; retorno a valor invalidado continua bloqueado; canais OSM compartilham restrição | Passou com PBF sintético e provedor simulado; corrida entre canais em PG pendente |
| C41-10 | Sem identidade do denunciante em respostas públicas, mensagens ao autor ou exportação de terceiros; anonimização da trilha | Passou |

Os testes anteriores que esperavam misturar a própria avaliação privada no indicador público foram ajustados à nova regra explícita. A combinação de cadastro e OSM agora espera divergência real, em vez de esconder uma fonte. O teste de migração mantém suas verificações originais e usa alvos históricos compatíveis, desaplicando apps dependentes. Nenhum limite de consultas, cobertura ou job foi relaxado.

## Consultas e paginação

Foram preservados os testes anteriores: lista de 12 locais até 3 consultas; catálogo até 4, inclusive massa de 10 mil entradas; resumo por recurso até 4; lista de avaliações até 5. As revisões atuais/contagens de confirmação são incorporadas à consulta SQL de origem ou buscadas em lote, sem uma consulta por recurso. Históricos, fontes e protocolos novos usam páginas de 20. São limites de testes com massa sintética, não promessa de latência em produção.

## Roteiros ainda necessários

### PostgreSQL 16 e Redis 7

Usar ambiente de teste e papel com permissão de criar o banco temporário de pytest. Não usar um Redis/banco pessoal. No PowerShell, definir conexão de teste e executar:

```powershell
$env:DATABASE_URL = "postgresql://USUARIO:SENHA@127.0.0.1:5432/acessoja_testes"
pytest -q evidencias/test_postgresql.py
pytest -q contribuicoes favoritos locais usuarios acessoja evidencias -k "postgresql_concurrent or postgresql_restore or catalog"
$env:GEOGRAPHIC_REDIS_TEST_URL = "redis://127.0.0.1:6379/15"
$env:SECURITY_REDIS_TEST_URL = "redis://127.0.0.1:6379/14"
pytest -q locais/test_geographic_redis.py usuarios/test_security_redis.py
```

Esperado: duas tentativas da mesma denúncia retornam um protocolo; confirmação é única; dois moderadores produzem aplicação+conflito, ou a mesma decisão para o mesmo operation_id; edição/exclusão não causam deadlock nem atingem versão nova; canais OSM compartilham restrição. SQLite não aprova essas garantias de locks. Os jobs existentes fornecem serviços PostgreSQL/Redis e já incluem o módulo novo, mas não foram disparados/publicados por esta entrega.

### Chrome, contas e moderação integrada

1. Em ambiente isolado, aplicar migrations e criar contas sintéticas A/B e moderador autorizado. Sem nomes, endereços ou experiências reais.
2. Terminal backend: `python manage.py runserver`. Em `frontend`: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000`.
3. Criar local sintético e avaliações públicas com rampa Sim/Não; deixar a observação desconhecida. Conferir prévia, detalhes e resultados: as duas fontes e divergência continuam compreensíveis por texto.
4. Como visitante, abrir fontes e iniciar confirmar/denunciar; cancelar login e depois entrar. Verificar retorno ao mesmo alvo e nova confirmação explícita, sem envio automático.
5. Confirmar Sim: data real aparece; Não continua válido e divergência permanece. Conferir que pontos, estrelas, visita e rota não aumentaram.
6. Como B, denunciar uma avaliação/evidência de A. Anotar protocolo real e consultar em configurações. Repetir com outro motivo: mesmo protocolo. A não pode consultar esse protocolo.
7. No Admin autorizado, solicitar revisão: A recebe somente orientação padronizada. Manter/invalidar com justificativa e conferir efeitos exatos em cada recurso, média, contagens e ledger. Staff sem permissão deve receber recusa.
8. Editar a avaliação antes de submeter o formulário antigo de moderação: receber conflito, preservar versão nova e encerrar a antiga por indisponibilidade. Reimportar a mesma evidência OSM: restrição deve permanecer.
9. Simular 401, 429 e rede indisponível; conservar rascunho na mesma conta e nunca mostrar protocolo fictício. Trocar local/conta rapidamente e conferir ausência de dados privados anteriores.
10. Exportar/excluir conta sintética pelo fluxo do Card 36 e verificar minimização, trilha técnica e ausência de conteúdo oculto nos resultados públicos.

### Android e acessibilidade manual

Em estação com Android SDK/Java configurados, executar `flutter doctor -v`, `flutter build apk --debug` e o mesmo roteiro em dispositivo/emulador com API de homologação configurada. Verificar 320 px, orientação, texto 200%, teclado, foco de retorno, temas e contraste. Usar leitor de tela real (TalkBack no Android; NVDA/VoiceOver no navegador), registrando dispositivo/versão/ferramenta, cenário e resultado. Sem execução nesta entrega; não há declaração de conformidade WCAG ou aceite manual.

## Aplicação e verificação do pacote

O ZIP é delta relativo à base declarada e contém manifesto de hashes, migrations, código e documentos. `removed` está vazio. Extraí-lo **fora** do projeto e executar `aplicar_cards_38_41.py --project PASTA --check`; somente depois usar `--apply`. O instalador recusa conflito, preserva backup e não executa dependências, migração, Git ou publicação. Cinco testes: dry-run sem escrita; conflito aborta toda aplicação; base CRLF aceita; reaplicação idempotente; caminho inseguro recusado. Hashes conferem os arquivos exatos do pacote; não substituem revisão de código.
