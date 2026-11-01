# Desempenho — Cards 52–58

Baseline: código original de main 2d3fdd2c7fcc33fb0de3b9a120787173d372a154, extraído do arquivo original antes das alterações. O mesmo harness foi copiado para a baseline e para o código novo. Não se comparou a implementação nova consigo mesma.

Ambiente: Linux-6.18.57-x86_64-with-glibc2.39; Chrome headless 151.0.7922.34; Flutter 3.47.4 / Dart 3.13.3, flutter_map 6.2.1. Servidor de testes em host compartilhado, sem aparelho físico. Dados sintéticos, mesma distribuição de coordenadas, centro/zoom e viewport por método.

## VM — debug/JIT

30 aquecimentos e 80 repetições de layout por volume; 20 mudanças de seleção/pumps por volume. Viewport 900×600 do harness (a superfície de teste aplica suas constraints). O tempo de pump mede o trabalho do teste/widget, não rasterização em GPU ou duração de frame de um aparelho. HttpOverrides conta e rejeita criação de HttpClient; zero tentativas nas duas versões. Fontes e tiles externos não participam. Contenção de CPU e JIT influenciam os números.

| Locais | Layout mediana antes → depois (µs) | Layout p95 antes → depois (µs) | Pump mediana antes → depois (µs) | Reconstruções antes/depois |
|---|---|---|---|---|
| 5 | 103 → 126 | 265 → 350 | 7370 → 4942 | 20 / 20 |
| 50 | 246 → 356 | 678 → 521 | 12904 → 15942 | 20 / 20 |
| 500 | 2078 → 2621 | 3429 → 3617 | 31111 → 32236 | 20 / 20 |

## Chrome — release dart2js / CanvasKit

Três rodadas alternadas antes/depois na mesma sessão/versão de navegador, viewport 1000×740, componente de mapa 900×600. 30 layouts de aquecimento, 80 layouts medidos, 15 callbacks RAF de aquecimento e 40 mudanças de seleção. A tabela apresenta a mediana entre rodadas da mediana/p95 de cada rodada.

O intervalo RAF inclui a programação do harness: ele aguarda o frame Flutter e o callback RAF seguinte. Por isso cerca de 33,3 ms NÃO significa renderização do app a 30 fps nem prova jank de 33 ms. É um indicador comparável de agendamento deste ensaio, sem medição de GPU física. Stopwatch no navegador tem quantização; diferenças pequenas de 100 µs não devem ser interpretadas como ganho/perda preciso.

| Locais | Layout mediana antes → depois (µs) | Layout p95 antes → depois (µs) | RAF mediana antes → depois (ms) | RAF p95 antes → depois (ms) | Reconstruções antes/depois |
|---|---|---|---|---|---|
| 5 | 100.00 → 100.00 | 200.00 → 200.00 | 33.30 → 33.30 | 33.40 → 33.40 | 40 / 40 |
| 50 | 200.00 → 300.00 | 500.00 → 500.00 | 33.30 → 33.30 | 33.40 → 33.40 | 40 / 40 |
| 500 | 1200.00 → 1299.00 | 1500.00 → 2000.00 | 33.30 → 33.30 | 33.40 → 33.50 | 40 / 40 |

Em todas as seis execuções de navegador houve zero tentativas de API e zero recursos externos; os assets locais necessários ao Flutter são tráfego do servidor estático, não descoberta geográfica. Não houve erro JavaScript. A contagem de reconstruções do pai permaneceu 40/40. O ensaio não instrumenta cada RenderObject nem o rasterizador.

A nova geometria valida IDs e interseções com retângulos reservados; a camada agora mantém foco e semântica. Há custo adicional observável em 50/500 locais. Em 500 no Chrome, a mediana de layout passou aproximadamente de 1,2 para 1,3 ms e p95 de 1,5 para 2,0 ms; RAF e número de reconstruções permaneceram próximos na resolução observada. O algoritmo existente foi preservado; não se introduziu uma substituição especulativa para esconder essa diferença.

A baseline não sustenta uma tolerância universal para hardware. Neste ensaio a aceitação objetiva é ausência de reconstruções adicionais no pai, HTTP ou perda de identidade e documentação do custo observado; os tempos não viram um gate arbitrário em ms. Frames físicos, consumo de memória/GPU, bateria e fluidez de Android continuam pendentes. Reexecutar isoladamente em profile/release no aparelho antes de homologar desempenho final.

## Reprodução

No frontend: `flutter test test/map_panel_performance_test.dart`. Defina MAP_BENCH_REPORT para gravar JSON. Compile `integration_test/map_marker_benchmark.dart` em release com `--no-web-resources-cdn --no-tree-shake-icons --no-wasm-dry-run --output=build/bench_after` na versão nova e o mesmo arquivo na baseline, em `build/bench_before`. Execute `integration_test/run_marker_web_benchmark.py --before ... --after ... --chrome ... --report ...` com Playwright instalado. Não trocar SDK, viewport, volume, dados ou modo entre as duas versões.

Arquivos brutos: `evidencias/performance_before.json`, `performance_after.json`, `performance_web.json`, logs de execução e harnesses de reprodução no frontend/integration_test.
