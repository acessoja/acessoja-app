# Relatório do Card 34 — Catálogo OSM de Anápolis

Implementação reconstruída e validada em 20/10/2026 (America/Sao_Paulo;
registros de execução em UTC podem indicar 21/10). Backend, integração Flutter,
migration, importador, relatórios e aplicador acompanham o delta. A homologação
manual e a concorrência PostgreSQL permanecem pendentes conforme a matriz.
Não houve Git de escrita, PR, mensagem a terceiros ou alteração do banco pessoal.

## Validação executada nesta retomada

| Verificação | Resultado |
| --- | --- |
| Django check / migrations em banco limpo / makemigrations --check | Aprovados |
| OpenAPI --fail-on-warn / Flake8 | Aprovados, sem avisos/violações |
| Backend completo | 496 passaram, 11 pulados e 21 subtestes passaram |
| Cobertura | 90.92% — limite de 80% preservado |
| Redis real isolado | 3 passaram, servidor 6.2.14, processos independentes |
| Flutter analyze | Aprovado, nenhum info/warning/error |
| Flutter test completo | 859 passaram |
| Flutter build web | Aprovado, incluindo dry run Wasm |
| APK debug | Bloqueado: Android SDK ausente |
| Importação real / reimportação | 424 criados / 424 inalterados, mesmo lote |
| Dry-run real | Hash do arquivo SQLite idêntico antes/depois |
| Reversão migration 0011 → 0010 → 0011 | Preservou Local, avaliação e favorito em cópia isolada |
| API sem ferramentas opcionais importáveis | HTTP 200, 424 resultados |
| Wheels Windows Python 3.12 | Disponíveis para todas as cinco ferramentas; runtime Windows não executado |
| Aplicador/reversão | Aprovados em cópias LF e CRLF, restaurando os 453 arquivos da base e preservando arquivo alheio |

Os 11 skips do backend são oito testes dependentes de PostgreSQL e três de Redis;
os três de Redis foram executados separadamente. O CI instala as dependências
opcionais nos jobs de catálogo, preserva PostgreSQL/Redis, Flutter/JDK e limite de
80%. Nenhum workflow remoto foi disparado. A suíte Flutter inclui 12 testes novos
para ID confiável, versão/páginas, atrasos/sessão, retry, cluster com 1.000 membros,
catálogo sem GPS com fontes indisponíveis, escala 200%, login com rascunho e
favorito após descarte do botão original, e atualização do detalhe canônico.
As regressões anteriores de questionário, histórico, consentimento, acessibilidade
e favoritos foram mantidas.

Flutter 3.47.4/Dart 3.13.3 foram preparados a partir da tag e engine oficiais,
sem inicializar Git. O modo CI evita uma sondagem opcional de metadados de VM que
foi bloqueada na primeira tentativa. Os resultados acima são das execuções finais.
Build web e testes de widget não equivalem a uso manual dentro do Chrome.

## Inventário real e cobertura

Fonte Geofabrik de 18/10/2026, cabeçalho `2026-10-18T20:25:06Z`, malha IBGE 2024,
município 5201108, regras `anapolis-poi-v1.3`. URLs, tamanhos, SHA-256, obtenção,
CRS e cobertura estão em `reports/card34/BASE_E_FONTES.json` e `IMPORTACAO_REAL.json`.
O polígono do extrato cobre o município inteiro, incluindo zonas rurais; o lote
continua **parcial** por uma geometria incompleta. Não há promessa de inventário
completo dos estabelecimentos reais.

| Tipo OSM | Examinados | Elegíveis | Aceitos |
| --- | ---: | ---: | ---: |
| node | 35837648 | 17132 | 210 |
| way | 2491179 | 20517 | 204 |
| relation | 56077 | 444 | 10 |
| Total | 38384904 | 38093 | 424 |

Auxiliares/não elegíveis: 38.346.811. Objetos sem tags são auxiliares e não
recebem motivo de rejeição individual. Rejeições por elegibilidade: 3.065.023
sem função suportada, 36.095 privados/restritos e 1.504 inativos. Entre elegíveis:
17.370 fora do polígono, 20.296 fora do bbox, um way aberto, uma relação não
suportada e uma geometria incompleta. A soma 424 + essas rejeições reconcilia os
38.093 elegíveis. Não somar motivos de pré-elegibilidade novamente ao conjunto elegível.

Sem nome: 117. Sem endereço: 304. Fronteira/cruzamento entre aceitos: zero.
210 pontos originais e 214 áreas multipoligonais; área usa ponto sobre a geometria,
não entrada confirmada. Relação incompleta: `osm:relation:20423932`.
Possível duplicata: `osm:node:6800261095` / `osm:way:725178131`, mantidos separados.
Essas duas identidades constam como pendentes de revisão e não foram fundidas.

| Categoria primária | POIs |
| --- | ---: |
| banco | 4 |
| cafeteria | 3 |
| educacao | 29 |
| farmacia | 15 |
| loja | 101 |
| outros | 11 |
| parque | 165 |
| publico | 7 |
| restaurante | 30 |
| saude | 37 |
| supermercado | 22 |
| Total | 424 |

Primeira carga: 424 criados, zero atualizados/vinculados/reativados/não vistos,
dois pendentes de revisão (contador sobreposto aos aceitos). Reimportação: zero
criados/atualizados e 424 inalterados; mesmo ID de lote. O domínio comunitário
continuou com zero Locais, visitas, avaliações, favoritos e usuários no banco
de importação isolado. Os testes de preservação usam fixtures separadas e
identificadas como sintéticas.

Duração da carga: 138.469 s; pico RSS medido: 953393152 bytes;
intermediários em disco: 589840928 bytes. Não é memória constante
independente do extrato: Pyosmium mantém estruturas de montagem; o índice de
localizações e staging ficam em disco, sem lista regional de objetos Python.

## Armazenamento e consultas

SQLite: 970752 bytes de arquivo total, 647168
bytes atribuídos a tabelas/índices do catálogo, zero páginas livres e
323584 bytes não atribuídos ao catálogo. Isso não é todo
um banco de produção atribuído ao recurso. `MEDICAO_REAL_SQLITE.json` detalha cada
tabela, índices e plano de consulta. Dados regionais/SDK/banco não integram o ZIP.

Projeções a partir dos 424 POIs reais, incluindo índices, observações, identidades,
metadados e margem de 40%. Densidade/tamanho de tags e fragmentação podem variar;
são estimativas, não contagens municipais ou compromissos de capacidade.

| POIs hipotéticos | Uma edição, bytes | Duas edições, bytes |
| --- | ---: | ---: |
| 10000 | 20332668 | 37689939 |
| 30000 | 60906253 | 112886316 |
| 50000 | 101479837 | 188082694 |

Medições HTTP por cliente Django no mesmo processo, cinco amostras, Linux
6.18.55 x86_64/glibc 2.39, Python 3.12.14, nove CPUs visíveis ao contêiner. Incluem
count e serialização da página, sem transporte HTTP real, navegador, frames ou SLA.

| Consulta | Count | Itens da página | SQL | Mediana ms |
| --- | ---: | ---: | ---: | ---: |
| municipal | 424 | 20 | 4 | 7.19 |
| bbox | 412 | 20 | 4 | 7.49 |
| farmacia | 15 | 15 | 4 | 6.57 |
| term | 7 | 7 | 4 | 4.74 |
| proximity | 424 | 20 | 4 | 13.20 |

A fixture de volume tem 10.000 POIs sintéticos adicionais mais quatro objetos de
topologia, com 20 resultados e quatro consultas SQL. O relatório registra medição
de armazenamento antes de adicionar mil Locals de matching; o plano de matching
foi medido após essas mil fixtures e usa `local_source_match_point`.
O agrupamento Flutter preservou as mil identidades coincidentes no teste.
Isso comprova o orçamento/contratos controlados, não fluidez em dispositivo físico.
Busca por substring e distância ainda podem percorrer candidatos SQL; nenhum
índice B-tree foi apresentado como substituto de índice espacial/full-text.

## Aceites e homologação pendente

Implementados: importação/manifestos, identidade estável, edição transacional,
conservação de comunidade, consulta SQL/página/versão, Mapa/Explorar, confirmação
pelo ID do catálogo, avaliação/favorito, continuidade de rascunho e proveniência.
O lote real parcial é servido com cobertura explicitamente incompleta; não
reconcilia ausências. Cadastro manual permanece disponível para lacunas.

Pendentes: concorrência crítica e medição de armazenamento em PostgreSQL real;
execução nativa Windows; jornada manual no Chrome/Android com fontes externas
indisponíveis; GPS, NVDA/TalkBack e orçamento de frames/memória em hardware alvo.
Não há APK, Android SDK/aparelho ou homologação assistiva nesta entrega.

Roteiro no navegador: iniciar a API no banco de validação; abrir Anápolis sem
GPS; explorar regiões diferentes, carregar páginas e abrir clusters/lista;
desativar provedores em configuração de teste; consultar detalhe/rota manual;
confirmar um POI com login intermediário; avaliar/favoritar e conferir prévia,
detalhes, marcadores e Salvos. Trocar conta e confirmar que dados privados não
persistem. Publicar outro lote entre páginas e validar reinício em 409.
Testar teclado, tela estreita, texto 200%, temas e leitor real.

O aplicador também recusou alteração local, pacote adulterado e reversão após
edição posterior, antes de sobrescrever arquivos. Evidência: `reports/card34/VALIDACAO_APLICADOR.json`.
Aplicação/reversão de arquivos: `META_CARD34/APLICACAO_WINDOWS.md` no ZIP.
Operação da fonte, comandos e licenças: [CATALOGO_OSM_ANAPOLIS.md](CATALOGO_OSM_ANAPOLIS.md).
Relatórios legíveis por máquina acompanham `docs/reports/card34/`.
