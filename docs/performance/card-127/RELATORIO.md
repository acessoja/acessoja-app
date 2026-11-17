# Card 127 — relatório de desempenho

## Diagnóstico e escopo

Auditoria no branch `feature/card-127-desempenho`, base `d99a581c87c065cbb6e446ca03ce573d0760e923`. O projeto é Flutter/Dart e Django REST Framework; o ambiente de trabalho não tinha configuração autorizada de PostgreSQL, serviço de API ou credenciais. Para medir sem tocar em infraestrutura externa, foi preparada uma bancada temporária com SQLite, WSGI local com concorrência instrumentada, entidades e usuário sintéticos e uma implementação local do serviço Overpass. Os testes da interface bloquearam tráfego do navegador fora de loopback.

Antes de propor otimização funcional, a API foi medida sob carga e os fluxos do mapa e Sugestões foram observados no build real do app. Não foi feita alteração em funcionalidade de produto: os achados não permitem afirmar que uma otimização específica beneficiaria o PostgreSQL ou usuários/dispositivos reais. O trabalho acrescentou instrumentação, scripts de benchmark e evidências reutilizáveis.

## Resultados principais

### API — `GET /api/locais/` com paginação e busca

Executadas 3 repetições por concorrência, com 100 requisições por repetição e 10 aquecimentos fora da amostra (900 requisições medidas). Cada resposta retornou 20 registros sintéticos, média de 54.209 bytes. Todas as 900 respostas foram HTTP 200; nenhum erro ou timeout. A concorrência WSGI observada foi 1, 10 e 100 conforme solicitado.

| Concorrência | p50 mediano das 3 rodadas | p95 mediano das 3 rodadas | Vazão média aproximada | Resultado |
|---:|---:|---:|---:|---|
| 1 | 32,7 ms | 54,7 ms | 25,2 req/s | Dentro do limite operacional de p95 2.000 ms |
| 10 | 305,3 ms | 454,1 ms | 25,9 req/s | Dentro do limite operacional de p95 2.000 ms |
| 100 | 3.170,4 ms | 4.101,3 ms | 23,6 req/s | Acima do limite operacional de p95 2.000 ms |

No probe SQL de diagnóstico foram registradas 6 consultas por resposta (média e máximo). A execução SQLite não mostrou crescimento de consultas por item na página de 20 registros. O resultado aponta saturação/contenda da bancada local em concorrência 100, mas não identifica a causa nem prova que o PostgreSQL ou uma implantação com outros workers terá o mesmo comportamento. A instrumentação mede o servidor WSGI e não representa capacidade de produção.

### Mapa

No fluxo real do Flutter Web, a seleção de um local na lista do mapa levou 475–519 ms nas três repetições (mediana 482,6 ms). O caminho acionou 10 chamadas da API, incluindo descoberta, dados externos, camada de favoritos e detalhe. O stub Overpass local foi usado e não houve tráfego de terceiros ou erro JavaScript.

Em microbench separado de posicionamento de marcadores, a mediana do p95 de layout nas três rodadas foi 0,201 ms para 5 locais, 0,799 ms para 50 e 4,300 ms para 500. O RAF ficou em aproximadamente 35 ms nos casos menores e 50 ms com 500 locais neste Chrome headless; isso não é tempo de rasterização física/GPU nem medição de dispositivo. A seleção acionou 40 reconstruções do pai em 40 quadros instrumentados. O aumento no conjunto de 500 é uma pista para avaliar granularidade de rebuild sob perfil Android/GPU real, mas não justifica uma alteração funcional com esta bancada isolada.

### Sugestões

Tempo até a primeira ação de rota habilitada, usando 25 locais, 9 visitas recentes sintéticas no conjunto, preferências sintéticas e navegador novo por repetição:

| Perfil | Amostras | Mediana | Faixa observada | Chamadas API no fluxo |
|---|---:|---:|---:|---|
| Autenticado | 3 | 4.006 ms | 3.582–4.055 ms | 3: locais, visitas, preferências de acessibilidade |
| Visitante | 3 | 4.317 ms | 4.297–4.360 ms | 1: locais |

As telas chegaram a uma ação habilitada em todas as seis observações, sem erro de página ou tentativa externa. A navegação até o conteúdo leva vários segundos apesar de as chamadas individuais de API capturadas serem bem menores; há custo de carregamento/estado/renderização do Flutter e bootstrap no marco ponta a ponta. A amostra pequena, headless e sem aparelho real não permite atribuir causalidade ou separar exatamente o custo do Flutter do custo da interface.

## Condições, limitações e bloqueios

- Máquina Windows 11, Python 3.15.2, Django/DRF instalados; Flutter 3.47.5/Dart 3.13.4, embora o projeto fixe Flutter 3.47.4; Chrome 157.0.8103.52, Playwright Python 1.65.2.
- SQLite temporário e descartado ao fim da execução; dataset sintético. Cache de disco/OS não foi controlado. Nas medições Web, cada repetição usou contexto novo do navegador.
- Build release Flutter Web, viewport 1280×900 no fluxo UI e 1000×740 no microbench de marcadores, escala 1. Chrome headless; não Android, GPU física, rede móvel ou usuários reais.
- O cliente recebe HTTP 401 de `/api/usuarios/me/` durante o bootstrap visitante antes da autenticação; isso foi esperado e não contado como falha de fluxo. Chamadas autenticadas/visitantes funcionaram.
- PostgreSQL e ambiente de homologação autorizados indisponíveis; logo não houve plano `EXPLAIN`, dados reais, perfil de workers do deploy nem Rodada B após otimização.
- Os limiares do prompt foram tratados como referência operacional (API p95 ≤ 2.000 ms e erro ≤ 1%; mapa ≤ 3.000 ms). As medições locais não são certificação de aceite em homologação.
- O texto literal dos critérios CA127-01…08 do Trello não foi fornecido; confirmar o mapeamento antes do encerramento formal.

## Melhorias entregues

- Script de API com proteção de destino, fase fria separada, aquecimento, carga sincronizada, instrumentação de concorrência observada, contagem de status/erros, validação de paginação, payload, CSV/JSON e comparação de rodadas.
- Bancada API com SQLite temporário e dataset sintético determinístico; testes unitários focados para percentil, segurança de host e comparabilidade.
- Coletor Playwright para fluxo real de lista do mapa e Sugestões com/sem conta sintética, bloqueio de rede externa, inventário das chamadas API, status, duração e erros JS.
- Coletor Web de layout de marcadores existente, resultados e protocolos documentados, mais dados reutilizáveis CSV/JSON/Markdown.
- Nenhuma mudança nas funcionalidades do app/backend, migrations ou contratos de API. Nenhum commit, push ou merge.

## Validação executada

- `python -m unittest discover -s scripts/performance -p "test_*.py" -v` — 3 testes focados passaram.
- `python manage.py check` — passou em configuração descartável SQLite.
- `python -m py_compile ...` — utilitários Python compilaram.
- Builds Flutter Web release do app principal e do alvo de benchmark de marcadores passaram; o SDK real ficou uma revisão acima do pin do projeto.
- Benchmarks reais API, marcadores e fluxo Web executados conforme evidências abaixo. A suíte completa não foi executada.

## Próximas tarefas recomendadas

1. Repetir API em PostgreSQL autorizado com versão/configuração, workers, tamanho da massa, índices e cache documentados; capturar `EXPLAIN (ANALYZE, BUFFERS)` em ambiente seguro para explicar a cauda de latência.
2. Repetir concorrência em escala gradual (1/10/25/50/100), monitorando CPU, memória, pool/conexões e latência do banco para achar o ponto de saturação sem inferir causa pelo SQLite.
3. Repetir Sugestões e mapa com dispositivo Android e build/profile adequado, medir quadro/raster e separar bootstrap, chamadas e renderização com marcos de instrumentação explícitos.
4. Ampliar amostras e adicionar cenário de sugestões sem resultados; confirmar critérios literais do Card 127 e limites de aceite com a equipe.
5. Só então avaliar mudança funcional e fazer Rodada B sob protocolo e infraestrutura equivalentes.

## Evidências e reprodução

- API completa: [`resumo.json`](../../../reports/performance/20261115T190808Z-901940/resumo.json), [`resultados.csv`](../../../reports/performance/20261115T190808Z-901940/resultados.csv), [`ambiente.json`](../../../reports/performance/20261115T190808Z-901940/ambiente.json).
- Marcadores: [`mapa.json`](../../../reports/performance/20261115T201000Z-map/mapa.json), [`mapa.csv`](../../../reports/performance/20261115T201000Z-map/mapa.csv). A primeira execução foi substituída porque o build ativo era o app principal e não o alvo de benchmark; a coleta final usa o alvo dedicado e registra Flutter 3.47.5/Dart 3.13.4.
- Fluxo real de mapa e Sugestões: [`web.json`](../../../reports/performance/20261115T194000Z-web/web.json), [`web.csv`](../../../reports/performance/20261115T194000Z-web/web.csv).
- Instruções: [`README.md`](./README.md); scripts em [`scripts/performance/`](../../../scripts/performance/).

## Rodada 3 — correção dos cenários que falharam

A coleta focada final é [`20261116T080000Z-r3-targeted-final`](../../../reports/performance/20261116T080000Z-r3-targeted-final/). Foram repetidos somente `auth_visits_preferences` e `production_map_flow`, três vezes cada. O resultado final teve seis observações concluídas e nenhuma falha. As pastas brutas das Rodadas 1 e 2 e os smokes/diagnósticos intermediários da Rodada 3 foram preservados.

### Diagnóstico e correções

Na Rodada 2, `auth_visits_preferences` falhou nas repetições 2 e 3 e `production_map_flow` na repetição 1, todas por `TimeoutError` na fase genérica `authentication`; aquele relatório não registrou subfase nem mensagem específica. Os diagnósticos focados mostraram que a árvore semântica do formulário ainda estava instável quando a automação interagia, e em tentativas não houve POST de login. O harness agora aguarda estabilidade de layout, preenche e valida os campos, testa as bounds do botão e clica com ponteiro; também espera o POST explícito e a tela autenticada. O login respondeu HTTP 200 e a aba principal ficou visível em 6/6 fluxos finais. Isso corrigiu sincronização da automação, sem mudança de funcionalidade de autenticação.

No mapa, um smoke inicial identificou um cluster hit-testável com 20 locais, mas não o marcador individual esperado. A causa observada foi a combinação de fixture muito concentrado e coletor que não distinguiu o cluster do botão do local; não era evidência de falha do mapa do produto. O fixture final distribui 25 pontos em uma grade 5×5 com espaçamento sintético de 0,006°. A confirmação do local agora exige semântica de botão, estado habilitado, bounds no viewport e hit-test. O marcador “Card127 Principal” foi confirmado como local individual em 3/3 repetições.

### Resultados focados

| Métrica | n | p50 | p95 | Interpretação |
|---|---:|---:|---:|---|
| Sugestões: tela visível → ação de rota | 3 | 408,9 ms | 456,7 ms | Inclui a etapa medida após entrada na tela; ambiente Web local sintético |
| Sugestões: início da automação → ação de rota | 3 | 4.620,2 ms | 4.732,7 ms | Inclui busca/prontidão do seletor Playwright; não equivale a toque físico |
| Bootstrap → primeiro frame | 3 | 218,8 ms | 256,5 ms | Evento do probe no navegador |
| Mapa pronto → primeiro marcador usável | 3 | 759,9 ms | 760,0 ms | Marcador individual visível, habilitado e hit-testável em todas as repetições |
| Tela principal → primeiro marcador usável | 3 | 938,8 ms | 941,5 ms | Inclui prontidão da tela e do mapa |
| Lista de locais utilizável | 3 | 350,0 ms | 354,0 ms | Intervalo independente do relógio do navegador |
| Seleção → detalhe/preview pronto | 3 | 494,9 ms | 501,0 ms | Título do detalhe visível e chamadas associadas concluídas |
| Resposta completa WSGI da API — Sugestões | 12 | 49,6 ms | 116,4 ms | SQLite descartável local |
| Resposta completa WSGI da API — mapa | 36 | 35,3 ms | 137,9 ms | SQLite descartável local |

Os eventos do Flutter usam `performance.now()` no browser. Durações isoladas de lista, seleção e detalhe usam relógio monotônico Python e não devem ser subtraídas dos eventos do browser. O tempo de API inclui consumo do corpo WSGI. A sessão de mapa teve 10 respostas completas no bootstrap por repetição, sem requests pendentes, erros HTTP não esperados, chamadas externas ou erros JavaScript; a seleção emitiu duas chamadas concluídas. A listagem não emitiu chamadas adicionais porque os resultados já estavam em cache no fluxo.

Os artefatos completos são [`web.json`](../../../reports/performance/20261116T080000Z-r3-targeted-final/web.json), [`resultados.csv`](../../../reports/performance/20261116T080000Z-r3-targeted-final/resultados.csv), [`resumo.json`](../../../reports/performance/20261116T080000Z-r3-targeted-final/resumo.json), [`ambiente.json`](../../../reports/performance/20261116T080000Z-r3-targeted-final/ambiente.json), [`logs_sanitizados.json`](../../../reports/performance/20261116T080000Z-r3-targeted-final/logs_sanitizados.json) e [`p95.svg`](../../../reports/performance/20261116T080000Z-r3-targeted-final/p95.svg). O ambiente foi Windows 11, Flutter 3.47.5/Dart 3.13.4, Chrome 157.0.8103.52, Playwright 1.65.2, viewport 1280×900, escala 1, navegador frio por perfil, dados sintéticos e tráfego externo bloqueado.

### Validação, limites e próximas tarefas

Passaram 9 testes unitários focados do harness; `py_compile`; o teste Flutter focado de instrumentação com a flag `CARD127_BENCHMARK` desligada e ligada; 5 testes focados do motor de recomendações; e `flutter analyze` nos arquivos de instrumentação/mapa. Não foi executada a suíte completa. Não houve mudança funcional do produto nem otimização antes de prova de gargalo.

PostgreSQL continua bloqueado: não havia `DATABASE_URL` autorizada. O serviço Windows detectado não foi acessado. O benchmark API existente define SQLite descartável e não suporta simplesmente receber uma URL PostgreSQL; portanto não há resultado PostgreSQL nesta rodada. Próximo passo é implementar opção explícita e protegida de backend de teste no runner, validar host/base antes de migrations, obter banco isolado autorizado e então repetir carga com configuração/concorrência documentadas. Não comparar estes resultados com R1/R2 como antes/depois: fixture, instrumentação e protocolo diferem. Testes Android não foram executados nesta rodada, conforme escopo solicitado.

O texto pronto para atualização manual do card está em [`TRELLO_RODADA3.md`](./TRELLO_RODADA3.md); não foi publicado no Trello.
