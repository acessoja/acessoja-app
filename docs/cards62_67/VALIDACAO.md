# Resultados reais de validação

Versão-base `6684c06ee19a93ccb446c37fbd78c7be6755cb29` mais o delta identificado em VERSAO.json. Execuções finais registradas em UTC nos JSONs de comandos; data de trabalho do usuário: 01/11/2026, America/Sao_Paulo. Ambiente: Python 3.12.14, Django 5.2.18, Flutter 3.47.4, Chrome for Testing 156.0.8078.80, Linux e SQLite descartável. Dependências de catálogo/geografia opcionais foram instaladas; Gunicorn de produção não foi necessário ao laboratório WSGI. Arquivos de dependências do projeto foram preservados.

| Verificação | Resultado observado | Evidência |
|---|---|---|
|Pytest completo, com branches e mínimo 80%|776 passaram; 30 ignorados; 21 subtestes passaram; cobertura 84,56%|evidencias/pytest.log, pytest.xml, coverage.xml, backend-commands.json|
|Flutter analyze --no-pub|Sem problemas|evidencias/flutter-analyze.log|
|Flutter test --no-pub|1.083 passaram|evidencias/flutter-test.log|
|Flutter build web|Concluiu; JS de release usado no navegador|evidencias/flutter-web-build.log|
|Flutter build apk --debug --no-pub|Falhou por ausência de Android SDK; sem APK|evidencias/flutter-apk-build.log|
|Flake8, limite 120|0 violações na verificação final|evidencias/flake8-final.log|
|Django check|Sem problemas|evidencias/django-check.log|
|makemigrations --check --dry-run|Sem mudanças pendentes|evidencias/migrations.log|
|OpenAPI --fail-on-warn|Exit 0 sem avisos|evidencias/openapi.log, quality-commands.json|
|migrate em SQLite limpo|Concluiu|evidencias/migrate-clean-sqlite.log|
|Migration forward/reverse/reapply em SQLite com legado|Passou, incluindo fotos/metadados, evidências, avaliações, favoritos, visitas e pontos; PostgreSQL ignorado|locais/test_category_migration.py e logs migration-stale-after-fix|
|Seleção do job PostgreSQL -k|152/799 testes coletados, 647 desmarcados; somente coleta, nenhuma execução PG|evidencias/postgresql-job-collection.log|
|Contrato de categorias gerado|11 pais e 22 filhos conferidos|evidencias/catalog-contract.log|
|Laboratório descoberta|17 etapas aprovadas|evidencias/browser-discovery/REPORT.json|
|Laboratório painel|15 etapas aprovadas|evidencias/browser-panel/REPORT.json|
|Laboratório retorno de rotas|13 etapas aprovadas|evidencias/browser-routes/REPORT.json|

Os 30 skips não são aprovações. Os motivos individuais constam no JUnit; incluem PostgreSQL, Redis/serviços e condições específicas dos testes legados. Os testes Django/API usam persistência SQLite real. Flutter Test usa VM/widgets e mocks HTTP explícitos; não comprova sozinho integração com o servidor.

## Navegador

O laboratório novo executa o JS compilado em `http://127.0.0.1:8002` e Django real em `8001`, com migrações e dados sintéticos descartáveis. Não substitui a própria API por mocks. Apenas terceiros são bloqueados. A resposta atrasada de A é obtida de fato do Django e retida na fronteira do navegador até B entrar; a interface deve descartá-la. As capturas são de contas sintéticas.

O hash JS congelado é `333723212c857e3636b9b9920399b3c6897e3b50484c31fa1d7e9742aa388cae`. Os três laboratórios usaram esse build, sem recompilação concorrente. Playwright Python foi a ferramenta efetiva: Playwright MCP não estava disponível. Não houve homologação em Chrome de celular real nem Android físico. Viewport 390×844 e ajuste real de texto 200% são emulação no Chrome Linux. Capturas e semântica não substituem leitura humana com leitor de tela nem comprovam todos os alvos de toque. A sobreposição observada do botão flutuante foi corrigida com desvio dos controles medidos do mapa, sem alterar a posição salva; o novo teste e o navegador verificam a separação das áreas. T094 continua parcial quanto a aparelho real/orientação/temas e homologação manual.

Painel comprova seleção, compacto/expandido, fontes, fotos públicas aprovadas, clusters, Escape, foco e escalas. Rotas usa fronteira determinística de roteamento, GPS emulado e histórico desligado. Google Maps comprova gesto/URL/abertura nativa de Search; não comprova página carregada no provedor externo. Consulte os passos de cada relatório para o alcance exato.

## Desempenho e limites

O script `tools/benchmark_discovery.py`, na raiz do pacote, é reproduzível em Linux e usa banco temporário próprio. O relatório mediu 125, 625 e 1.250 locais internos/OSM. Depois da consulta inicial: 6 SQL por requisição; a primeira medição incluiu inicializações (9 SQL). Para 1.250 locais, a latência foi 813–908 ms e o pico do processo 107.188 KiB, incluindo montagem dos dados. Outras suítes rodavam simultaneamente. Não é perfil de PostgreSQL, produção ou aparelho, e não define SLA.

## Falhas, correções e comprovação

A primeira reserva visual ampla ocultou o botão em 320 px: a regressão detectou o problema. A reserva foi restringida aos controles, e os cinco tamanhos direcionados e a suíte final foram executados novamente. O teste negativo de catálogo não observado falhou antes da correção e passou depois; o Pytest completo foi repetido após a mudança. A primeira verificação Flake8 apontou E203 em um slice formatado; foi corrigido e o check final retornou zero. A execução direcionada Flutter anterior falhou porque o next da fixture omitia os critérios obrigatórios; o contrato corretamente o recusou. A fixture foi corrigida e a suíte completa passou. Os dois erros de roteiro Playwright constam em evidencias/historico. Resultados antigos recuperados do checkpoint foram tratados como histórico, não como prova da versão final.

Os resultados acima não significam “106 cenários aprovados”. MATRIZ_CENARIOS.json/CSV preserva o escopo e a pendência de cada cenário; MATRIZ_ACEITE liga cada um dos 73 critérios. Os testes do instalador são registrados separadamente em EVIDENCIAS_INSTALADOR.log na raiz do pacote, depois da montagem do payload final.
