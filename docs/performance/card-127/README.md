# Card 127 — protocolo e reprodução

Este diretório descreve a bancada e liga aos resultados reais registrados em [`RELATORIO.md`](./RELATORIO.md). O prompt menciona CA127-01…08, mas o texto original desses critérios não estava disponível para confronto; a tabela do relatório é um mapeamento operacional, não uma transcrição do Trello.

## Bancada e segurança

- API local: Django/DRF em WSGI com threads e SQLite descartável; 200 locais sintéticos, seed 127; sem dados ou credenciais reais.
- UI: build Flutter Web em release e Chrome headless; API SQLite local, dados sintéticos e serviço Overpass substituído por stub em loopback que responde zero elementos. Requisições externas do navegador são abortadas.
- A API de destino do script só aceita loopback por padrão. Para host controlado não local, informe explicitamente `--authorized-host HOST` e nunca coloque credenciais na URL, nos argumentos ou nos relatórios.
- O conjunto completo de testes do produto não foi executado. Só se executa a suíte focada desta bancada.

## Reprodução

Na raiz do projeto, com dependências do backend já instaladas:

```powershell
# API: 100 amostras por cenário, três repetições, concorrência 1/10/100
python scripts/performance/card127_local_api.py --samples 100 --repetitions 3 --warmup 10 --locals 200 --seed 127

# Marcadores: build release existente e Chrome instalado
python scripts/performance/card127_map_web.py --chrome "C:\Program Files\Google\Chrome\Application\chrome.exe" --rounds 3 --report reports/performance/NOVO-ID-map

# Fluxos reais de lista do mapa e Sugestões: usa o build release principal existente
python scripts/performance/card127_web_flows.py --chrome "C:\Program Files\Google\Chrome\Application\chrome.exe" --rounds 3 --report reports/performance/NOVO-ID-web

# Testes focados dos utilitários de benchmark
python -m unittest discover -s scripts/performance -p "test_*.py" -v
```

Para compilar o app principal na mesma bancada, da pasta `frontend`:

```powershell
flutter build web --release --no-pub --no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:8001 --dart-define=STADIA_MAPS_ENABLED=false --dart-define=ROUTE_BASE_URL=http://127.0.0.1:9
```

Dependências observadas nesta execução: Python 3.15.2 (o projeto documenta Python 3.12), Django/DRF do ambiente, Playwright Python 1.65.2, Chrome 157.0.8103.52 e Flutter SDK 3.47.5/Dart 3.13.4 (o projeto fixa Flutter 3.47.4). Use um ambiente compatível com as versões fixadas para comparação formal. Os scripts guardam os parâmetros, hash do código da bancada e do build, protocolo e artefatos por rodada.

## Limites da evidência

SQLite e servidor WSGI local permitem diagnóstico e reprodução do protocolo, mas não substituem PostgreSQL, workers e massa de homologação. A medição do mapa tem duas partes: marcos de fluxo real no browser e microbench de layout de marcadores/RAF. Headless Chrome não mede GPU física, Android, tiles ou uma experiência de usuário em dispositivo. Os números de Sugestões cobrem o tempo de entrada até a primeira ação habilitada e devem ser lidos com as condições e limitações do JSON.

## Rodada 2 — diagnóstico segmentado

O pacote final é [`20261115T225617Z-r2-30b7c3`](../../../reports/performance/20261115T225617Z-r2-30b7c3/). As evidências brutas da API foram reaproveitadas sem alteração de [`20261115T221100Z-r2-7282db`](../../../reports/performance/20261115T221100Z-r2-7282db/); a Web foi executada em três repetições por perfil. O status global é parcial: houve 27 observações Web concluídas e três timeouts de automação em autenticação (sem valores inventados), e PostgreSQL homologado/Android físico não estavam disponíveis.

Na API, foram medidos 1.500 requests na listagem sintética (100 por repetição em concorrência 1/10/25/50/100), sem erros nem timeouts, e 75 requests por cada uma de dez rotas adicionais. O p95 mediano das três repetições foi 108,3 / 613,6 / 1.846,1 / 3.135,7 / 6.144,0 ms, respectivamente. Cada listagem retornou em média 54.349 bytes e executou sete consultas SQL no probe SQLite/DEBUG. Isso confirma crescimento da cauda apenas nessa bancada; não localiza a causa em um deployment PostgreSQL.

Em Sugestões, após o marco `suggestions_screen_enter`, a mediana até a ação de rota ficou em 181,8 ms para visitante, 283,6 ms para autenticado sem visitas com preferências e 366,4 ms sem visitas nem preferências (n=3 por perfil). O ranking levou 1,8–3,4 ms de mediana nesses perfis; transformação e resposta da descoberta foram registradas separadamente em `metricas_resumidas.json`. A descoberta com atraso artificial de 750 ms elevou a mediana tela→ação de 181,8 para 928,4 ms; é uma intervenção controlada no stub local, não uma propriedade do serviço real. O tempo click→ação totalizou 4,36–5,10 s nos perfis frios; a diferença derivada indica que a maior parcela ocorre antes do marco de entrada da tela, mas a bancada ainda precisa de um marco explícito no início do click para atribuir essa espera à navegação/transição.

No mapa, em duas observações completas, a lista ficou utilizável em mediana de 290,7 ms e a seleção local em 460,0 ms. Foram 10 requests no bootstrap/autenticação: nove pares distintos de método/rota; o único par repetido é `GET /api/usuarios/me/`, com 401 de bootstrap seguido de 200 autenticado. As dez respostas foram completas, sem erro não esperado. A seleção acionou mais duas rotas, ambas 200. O marcador sintético não ficou visível no viewport em 0/2 observações, portanto não há número de tempo para esse marco.

Os detalhes e os motivos de status parcial ficam em [`resumo.json`](../../../reports/performance/20261115T225617Z-r2-30b7c3/resumo.json), [`metricas_resumidas.json`](../../../reports/performance/20261115T225617Z-r2-30b7c3/metricas_resumidas.json), [`web.json`](../../../reports/performance/20261115T225617Z-r2-30b7c3/web.json), [`api.json`](../../../reports/performance/20261115T225617Z-r2-30b7c3/api.json) e [`p95.svg`](../../../reports/performance/20261115T225617Z-r2-30b7c3/p95.svg). O ambiente e a origem separada da API estão em [`ambiente.json`](../../../reports/performance/20261115T225617Z-r2-30b7c3/ambiente.json).

### Reproduzir

Na raiz do repositório, com dependências instaladas e Chrome/Flutter disponíveis:

```powershell
python -m unittest discover -s scripts/performance -p "test_card127_round2*.py" -v
python scripts/performance/card127_round2.py --chrome "C:\Program Files\Google\Chrome\Application\chrome.exe" --flutter "C:\Users\User\develop\flutter\bin\flutter.bat" --repetitions 3 --route-samples 25 --concurrency-samples 100
```

O comando cria um `run_id` novo e único em `reports/performance/`; não reutilize diretórios existentes. Para reexecutar somente o browser com uma API já concluída, acrescente `--reuse-api-report reports/performance/<API-RUN-ID>` e aponte para uma pasta que contenha `api.json` e `api.csv`. O campo `api_source_run_id` preserva a proveniência dos dados.

Para validar a comparabilidade (o programa recusa diferenças de banco, Flutter, Chrome, viewport e cache):

```powershell
python scripts/performance/compare_card127_round2.py reports/performance/<RUN-A> reports/performance/<RUN-B>
```

### Bloqueios e próxima coleta

- **PostgreSQL homologado bloqueado:** o serviço local estava ligado, mas não havia `DATABASE_URL` autorizada; não foram tentadas credenciais presumidas. Provisionar base isolada com massa sintética, usuário de benchmark e workers documentados; executar a API contra esse host em uma continuação autorizada.
- **Android físico bloqueado:** `adb`/dispositivo indisponível. Em aparelho autorizado, gerar build `profile` e executar `flutter run --profile -d <DEVICE_ID> --dart-define=CARD127_BENCHMARK=true --dart-define=API_BASE_URL=https://<HOST-DE-HOMOLOGACAO-AUTORIZADO>`; registrar modelo/OS, frame/raster e rede.
- **Critérios CA127-01…08:** texto literal não anexado; confirmar antes de declarar aceite.
- Não comparar a Rodada 1 e a Rodada 2 como antes/depois. O comparador sinalizou ambiente/metadados diferentes e a Rodada 2 mudou a instrumentação de lifecycle. Nenhuma otimização funcional foi aplicada porque o benchmark não prova uma causa de produto.

## Rodada 3 — correções do harness, sem Android

O smoke deve selecionar somente os perfis que falharam na Rodada 2. O runner aceita `--scenario` repetido, espera a árvore de semântica do login estabilizar por quadros de layout, preenche os campos por teclado, clica dentro das bounds validadas do botão e confirma o POST de login e a tela autenticada. O 401 de `GET /api/usuarios/me/` só é esperado antes do POST de login; um 401 posterior é erro HTTP.

Para o mapa, o coletor procura o botão semântico do local ou, como diagnóstico, um cluster visível. A confirmação exige botão habilitado, bounds dentro do viewport e hit-test Playwright. O fixture de 25 locais usa grade sintética 5×5 centrada na câmera, com 0,006° entre pontos; não altera coordenadas nem comportamento do produto. `map_ready` é um marco opt-in. Os intervalos do browser usam `performance.now()`; tempos de lista/seleção usam `time.perf_counter()` como durações independentes, sem subtração entre relógios.

### Reproduzir somente os cenários corrigidos

Na raiz do repositório, com dependências já instaladas:

```powershell
$run = 'reports/performance/ID-UNICO'
python scripts/performance/card127_round2_web.py --report $run --chrome 'C:\Program Files\Google\Chrome\Application\chrome.exe' --flutter 'C:\Users\User\develop\flutter\bin\flutter.bat' --repetitions 1 --smoke --scenario auth_visits_preferences --scenario production_map_flow
```

Depois do smoke passar, executar três repetições focadas:

```powershell
$run = 'reports/performance/ID-UNICO'
python scripts/performance/card127_round2_web.py --report $run --chrome 'C:\Program Files\Google\Chrome\Application\chrome.exe' --flutter 'C:\Users\User\develop\flutter\bin\flutter.bat' --repetitions 3 --scenario auth_visits_preferences --scenario production_map_flow
```

Cada comando deve usar uma pasta nova. O runner grava `web.json`, `resultados.csv`, `resumo.json`, `ambiente.json`, `logs_sanitizados.json` e `p95.svg`. O fluxo de Sugestões mede a partir do início da busca/ação pelo seletor de aba; por isso inclui a espera de prontidão/localização do controle e não representa o instante físico do clique do usuário. API registra resposta WSGI até o consumo integral do corpo e deixa requests pendentes explícitos.

Validação de regressão e instrumentação:

```powershell
python -m unittest discover -s scripts/performance -p "test_card127_round*.py" -v
python -m py_compile scripts/performance/card127_round2_web.py scripts/performance/test_card127_round3.py
cd frontend
flutter test --no-pub test/card127_performance_probe_test.dart
flutter test --no-pub --dart-define=CARD127_BENCHMARK=true test/card127_performance_probe_test.dart
flutter test --no-pub test/recommendation_engine_test.dart
flutter analyze lib/screens/main_screen.dart lib/services/card127_performance_probe.dart
```

### PostgreSQL

Nesta rodada não havia `DATABASE_URL` autorizada; o serviço Windows detectado não foi acessado. O benchmark atual de API define SQLite descartável diretamente em `card127_round2_api.py`, portanto exportar uma URL PostgreSQL não muda esse script. Para uma coleta PostgreSQL futura, provisionar primeiro um banco isolado e autorizado, configurar `DATABASE_URL` e `SECRET_KEY` em variáveis locais a partir do gerenciador de segredos e adicionar suporte explícito de banco ao runner, com validação de hostname/base de teste antes de `migrate`. Só então executar, por exemplo, `python manage.py migrate --noinput` e o benchmark com a opção explícita de banco de teste. Não passar a URL como argumento, não executar isso no serviço local observado e não usar produção. Esta etapa permaneceu bloqueada e não produziu métrica PostgreSQL.

A Rodada 3 não executa nem prepara testes Android. Veja o diagnóstico e os resultados em [`RELATORIO.md`](./RELATORIO.md) e o texto para o card em [`TRELLO_RODADA3.md`](./TRELLO_RODADA3.md).

