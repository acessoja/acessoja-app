# Evidências de integração — Card 46

Revisão final: 28/10/2026 (America/Sao_Paulo).

Preparado em 27/10/2026 (America/Sao_Paulo). Base develop `e4a8db02dd4aa8a77fe9dfea9c3f0ffb62d280ef`, arquivo-base com 624 arquivos, preservado no manifesto do delta. Código dos cinco cards integrado; o aceite entre dispositivos físicos continua pendente.

## Ambiente e rastreabilidade

Python 3.12.14, Django 5.2.18, Pillow 13.0.0, Flutter 3.47.4/Dart 3.13.3, image_picker 1.2.4. SQLite e FileSystemStorage reais, fixtures sintéticas geradas em teste; Redis 6.2.14 efêmero com processos no mesmo namespace. CI existente usa PostgreSQL 16 e Redis 7. Nenhuma foto pessoal, credencial real ou banco do usuário foi usado.

Backend completo: **666 testes e 21 subtestes aprovados**, **21 skips explícitos**, sem falhas; cobertura combinada de linhas/branches **84,26%**, mínimo preservado em 80%. O app midia tem **32 casos aprovados e três testes PostgreSQL ignorados**. Os outros skips pertencem à concorrência/restauração PostgreSQL anterior. SQLite não comprova SELECT FOR UPDATE.

Frontend: **flutter analyze sem issues**, **908 testes aprovados** na suíte completa final, incluindo **16 testes de mídia**. Após a integração do avatar no mapa/menu, a seleção dirigida de regressão e mapa também passou (**61 testes**). Builds Web passaram com tree-shaking e verificação Wasm padrão; a variante para a lab TLS usou `--no-web-resources-cdn --dart-define=API_BASE_URL=https://localhost:8443`. O comando `flutter build apk --debug` foi tentado e encerrou com **No Android SDK found**: APK e aparelho Android continuam pendentes.

Checks: pip check, manage.py check, makemigrations --check --dry-run, migrate em banco vazio, schema spectacular --fail-on-warn --validate e flake8 passaram. check --deploy foi executado com perfil staging e configuração sintética válida, sem conectar dependências: retorno 0, mantendo os avisos W005/W021 de HSTS de subdomínios/preload que o piloto não habilita deliberadamente. Isso não comprova deploy, DNS, SMTP ou prontidão PostgreSQL/Redis externos.

Após acrescentar o ensaio real TLS/proxy, a cobertura consolidada do código atual é **85.45%**, com o gate de 80% aprovado. O resultado da suíte pytest isolada continua identificado separadamente como 84,26%.

Os relatórios em `reports/cards_42_46/` contêm os casos JUnit convertidos, totais de cobertura, comandos/retornos, resultados de frontend, proxy, navegador e aplicador. Subtestes contam no total JUnit, mas não são nós testcase individuais; os totais os distinguem.

## Navegador e proxy reais

Foram aprovados **13 cenários automatizados em Chrome headless 151.0.7922.34**, com Flutter Web compilado, API Django e filesystem reais, sem respostas HTTP simuladas. Frontend em https://localhost:8444 e API/proxy em https://localhost:8443 exercitaram CORS com Authorization. A CA é privada e temporária; o navegador ignora somente esse certificado de laboratório. A cadeia TLS foi verificada separadamente pelo cliente do roteiro do proxy, sem modificar o trust store do sistema.

Os cenários confirmaram: seleção pelo plugin de um PNG acima de 3 MB, avatar persistido, rejeição real de arquivo corrompido preservando o avatar, cancelamento, campo de descrição com limites semânticos próprios e clique real, upload/revisão pendente privada e orientação corrigida, aprovação inicial pelo Admin e leitura com cookie, GET/HEAD público após aprovação, replay sem nova foto, galeria/visualizador de outra conta em outro contexto desktop, Escape, GET privado com header/CORS corretos, reinício real da API conservando referências/bytes, novo login/reabertura e remoção persistente do avatar, denúncia pela UI referenciando revisão, duplicidade/proteção do protocolo, decisão na fila existente retirando GET/HEAD sem mudar pontos, arquivo >5 MiB/corpo >6 MB recusados e retirada própria da foto pela UI.

A navegação do ensaio usa os controles semânticos do Flutter quando a barra do mapa ainda está sendo atualizada. O seletor de arquivo foi automatizado pelo file input real do navegador; não se afirma execução de uma janela nativa do Windows, de câmera ou permissão do aparelho. Os detalhes e o escopo de cada cenário estão em `reports/cards_42_46/browser_tests.json`. Dois contextos são contas isoladas no mesmo desktop, não outros aparelhos.

O ensaio anterior do proxy também passou: TLS com cadeia verificada por CA temporária, redirecionamento HTTP, reescrita dos headers de proxy, cookie CSRF Secure no Admin, proteção do schema, readiness 503 quando dependências estão indisponíveis, fallback SPA e ausência de canários de credencial/PII nos logs. Isso usa Gunicorn real e o perfil staging, com banco indisponível intencionalmente, e é separado do fluxo funcional SQLite.

Não são comprovados aparelho/câmera Android, Chrome em celular, leitor de tela real, Safari/iPhone, DNS/certificado público, SMTP externo ou restauração PostgreSQL. Dois contextos desktop ou largura de celular não representam dois aparelhos.

## Matriz E01–E16

| ID | Card / prova executada | Resultado e pendência |
| --- | --- | --- |
| E01 | 42/43: suíte existente de avaliações e editor, sem imagem obrigatória | API/widgets aprovados; não depende de foto nem concede ponto por imagem |
| E02 | 42/43: upload multipart real, processamento e arquivo privado | API/storage aprovados; seleção/envio no Android real pendentes |
| E03 | 42/43: aprovação inicial versionada, autorização de galeria/arquivo | API aprovada; navegador no relatório; consulta em outro aparelho pendente |
| E04 | 42: denúncia de revisão, contexto alterado, invalidação e trilha | API aprovada; denuncia protegida/duplicidade e revisão antiga cobertas |
| E05 | 43: uma foto falha e apenas ela repete com mesmo ID | Widget com serviço controlado aprovado; falhas reais de storage/DB testadas por injeção na API, não rede física |
| E06 | 43/44: cancelar/seleção inválida/arquivo indisponível | Widgets aprovados; comportamento de permissão/câmera do aparelho pendente |
| E07 | 43/44: contexto de recuperação Android, conta/alvo, processo interrompido | Serviço/estado cobertos; destruição e retomada de Activity em aparelho pendentes |
| E08 | 42–45: credencial revogada após processamento, troca de conta e retorno tardio | API/widgets aprovados; nenhum token em URL; ensaio físico em upload pendente |
| E09 | 42/44: upload, decisão, remoção e retry identificados | API aprovada sem duplicar ponto/registro; concorrência entre conexões PostgreSQL pendente |
| E10 | 42/45: arquivo falso/corrompido/animado, bytes/pixels/corpo | Validações reais API/processamento aprovadas; ensaio do proxy registrado separadamente |
| E11 | 44: Android → Chrome | Não executado: requer Android SDK e aparelho; persistência desktop é evidência parcial |
| E12 | 44: Chrome → Android | Não executado: requer aparelho; não substituir por widget |
| E13 | 44: substituição falha conserva anterior; remover persiste ausência | API/widgets aprovados; navegador no relatório |
| E14 | 42/45: tornar privada, invalidar/arquivar, excluir foto/avaliação/conta | API/storage aprovados em listagem, detalhe, GET e HEAD, ambas as variantes |
| E15 | 43: teclado, Escape, foco, texto 200%, tela pequena e semântica | Widgets aprovados; navegador no relatório; TalkBack/leitor real pendente |
| E16 | 45: lease, limpeza recuperável, storage/banco, reinício/backup | API/FS e testes de integridade aprovados; reinício no relatório; restauração isolada PostgreSQL/Compose pendente |

## Falhas encontradas e correções verificadas

- A base bloqueava foto de perfil fora da Web e tinha limites base64/arquivo incompatíveis. Nova rota multipart e seletor compartilhado, preservando leitura base64 e validação também da rota antiga/perfil genérico.
- Um teste legado chamava texto falso de avatar válido. A fixture agora é um raster sintético real e verifica JPEG processado, sem relaxar a validação.
- Testes de migrations voltavam para versões intermediárias e deixavam novos dependentes ausentes. Agora isolam a migração histórica e restauram todos os leaf nodes atuais; sequência dirigida passou antes da suíte completa.
- Ajustes de testes multipart usam bytes/latin1 para inspecionar campos, sem tratar PNG binário como UTF-8. Listas lazy são roladas antes das ações; nenhum teste foi retirado.
- A primeira build teve artefato kernel inválido no tree-shaker; uma nova compilação limpa de saída passou com tree-shaking normal. Não se reduziu lint/gate nem se ocultou exceção.
- O ensaio real detectou que o respond de diretórios privados perdia precedência para o fallback SPA (200 com index.html). Foi convertido em handle próprio; o roteiro TLS agora verifica 404 para mídia, diário e backups. Não havia volume de mídia exposto no proxy.
- O primeiro navegador não iniciou por renderer em CDN inacessível à rede do laboratório. Bootstrap agora aponta para CanvasKit do próprio build. Ativação de semântica usa o controle de acessibilidade do Flutter; a automação foi ajustada para o elemento auxiliar fora do viewport.
- O campo de descrição era agrupado semanticamente com o card da prévia. Os cards agora explicitam filhos separados; teste verifica rótulo/limites do campo e o Chrome confirmou clique e digitação reais.
- Retorno do seletor nativo não dispara recarga que descarte a seleção; upload incerto/remoção do avatar guardam identidade para consulta. Uma resposta tardia da reconciliação não anuncia sucesso nem reexibe avatar em outra conta; teste específico aprovado.

## Execuções que ainda precisam ocorrer

1. Com PostgreSQL 16/Redis do CI ou ambiente de teste isolado, executar `pytest -q contribuicoes favoritos locais usuarios acessoja evidencias midia -k 'postgresql_concurrent or postgresql_restore or catalog'` (a seleção do job backend-concurrency). Verificar duas conexões independentes para quota 4→5, dois avatares da mesma versão e duas decisões da mesma revisão. Nenhum desses testes deve ser convertido em SQLite para aprovação.
2. Instalar Android SDK/Java compatíveis, executar flutter doctor e flutter build apk --debug; instalar em aparelho Android API 24+. Executar E01–E16: arquivo/câmera, permissão negada, JPEG/PNG/HEIC, atividade destruída na seleção e sessão trocada durante envio, texto ampliado/TalkBack. Registrar modelo, API Android, versão do app e passos/resultados.
3. Chrome desktop e Chrome móvel reais contra HTTPS do piloto: alternar avatar nos dois sentidos, aprovar foto no Admin e consultar no outro aparelho, reabrir/relogar, testar conexão lenta/queda real, remoção e visibilidade privada. O endereço precisa ser acessível aos aparelhos; não usar localhost do computador como endpoint permanente.
4. Manter Safari/iPhone como não homologado enquanto não houver execução/escopo declarado. Não existe alvo iOS nativo neste repositório.
5. Aplicar procedimento do Card 45: backup em janela sem escritores/limpeza, restaurar em PostgreSQL acessoja_restore_* com mídia separada e recibos de exclusão vigentes; executar supressão e limpeza antes do tráfego. Registrar checksum, referências, arquivos, estado de conta removida, acesso negado e reinício/recriação do volume. Testes de empacotamento ou reinício SQLite não equivalem a essa restauração.
6. Registrar validação com tecnologia assistiva e participantes do cartão #123 separadamente; o Card 46 não substitui essa atividade.

## Aplicação e revisão

O ZIP contém apenas arquivos novos/alterados, manifesto SHA-256 (e normalização LF para Windows), lista de exclusões vazia, instruções e aplicador com dry-run/backup. Cinco cenários do aplicador passaram: dry-run sem escrita, conflito local aborta tudo, CRLF aceito com hashes finais corretos, reaplicação idempotente e path traversal recusado. Não inclui .env, tokens, bancos, uploads, venv, caches ou builds. Código preparado para revisão/aplicação; pacote não está totalmente homologado nas plataformas obrigatórias.
