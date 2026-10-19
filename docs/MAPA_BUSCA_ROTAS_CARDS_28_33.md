# Mapa, busca e cadastro — Cards 28–33

Entrega de 18/10/2026. Código integrado na cópia recuperada do AcessoJá, sem
operações de escrita de Git, publicação, PR ou alterações no Trello.

> Correção posterior: veja [INSTRUCOES_CORRECAO_MAPA_28_33.md](../INSTRUCOES_CORRECAO_MAPA_28_33.md) para o contrato atualizado de estados, área, erros, cache e coordenação. Os resultados históricos deste documento não são a homologação da correção.

## Base e diagnóstico

Base efetiva: `acessoja/acessoja-app`, `develop` de referência
`1e6d59a0d4f3fb9f3d5be5e11070f145bfe339f0`, com os favoritos dos Cards 24–27.
A recuperação combinou os snapshots fornecidos e os dois documentos do commit,
consultados pela API de leitura. Os 417 blobs foram conferidos por hash, sem divergências. A cópia de trabalho não tem `.git`.
Não foi executado clone, fetch, pull, checkout, staging, commit ou push.

Os contratos existentes de avaliações próprias, questionário, evidências de
acessibilidade, favoritos privados, visitas, consentimento, histórico e painel de
leitura foram mantidos. `place_list_screen.dart` continua fora do fluxo real.

As lacunas reproduzidas eram a ordenação de Explorar por `distancia` legado,
busca limitada aos dados em memória, download automático de todas as páginas,
seleção do primeiro resultado geográfico e ausência de cadastro manual protegido
contra repetição. GPS, origem manual, importação assinada OSM e o editor próprio
já existiam e foram reutilizados.

## Correspondência e aceite

| Roteiro / Trello | Integração entregue e evidência automatizada | Homologação pendente |
| --- | --- | --- |
| 28 / [#49](https://trello.com/c/xHcpBMlr) | Posição compartilhada, expiração, zero distinto de ausência, unidades e ordenação global anterior à página. Testes de duas origens, qualidade e logout. | GPS e atualização de permissões em dispositivos reais. |
| 29 / [#48](https://trello.com/c/TodyShwy) | Busca remota com debounce, filtros, ordenação, uma página por chamada, retry e descarte de respostas antigas. Regressões de Salvos preservadas. | Medir desempenho com a base de produção e concorrência de alterações durante paginação. |
| 30 / [#108](https://trello.com/c/CV4XKYIU) | Validação de pares, recuperação temporária sem PATCH, causas tipadas de rota, prioridade de HTTP 429/5xx e ajustes à rede viária informados. | Cobertura do perfil de carro e testes de navegação em aparelho real. |
| 31 / [#109](https://trello.com/c/ev15ogLr) | Candidatos tipados, escolha explícita, POI distante independente da consulta da vizinhança, regiões e busca por área limitada. Jornada controlada com vizinhança indisponível. | Provedor configurado e consultas reais em outra cidade no Chrome. |
| 32 / [#46](https://trello.com/c/b6gFAV1n) | Formulário contextual, login sem perder rascunho, UUID, recibos no banco, matching conservador e justificativa de duplicata. Migração com preservação de dados testada. | Executar o teste concorrente novo no PostgreSQL real, além dos cinco anteriores. |
| 33 / [#129](https://trello.com/c/hh1V1a5n) | Mira, controles por teclado/toque, coordenadas, cancelar/substituir, ponto temporário e rota sem cadastro; detalhes e avaliação continuam integrados. | TalkBack/NVDA e uso físico com teclado/toque e GPS. |

Build e testes controlados comprovam as regras implementadas; não comprovam
cobertura mundial, acessibilidade do percurso ou homologação assistiva real.

## Posição e distância

`CurrentPosition` compartilha uma única posição aceita entre mapa, Explorar,
Salvos, Sugestões, contribuições e detalhes do mapa. O mapa mantém o stream GPS;
não há consulta de posição por item. O seletor só solicita GPS pelo botão
“Usar minha localização”. A posição sugerida precisa ser confirmada.

É reutilizada a política de `NavigationFix`: par finito e em faixa, precisão
maior que zero e até 50 m, idade entre zero e 30 segundos. Amostra futura,
imprecisa ou antiga invalida a posição compartilhada. Há timer de expiração;
logout/troca de sessão e perda de localização também a invalidam. Respostas de
GPS iniciadas na sessão anterior são descartadas.

O centro inicial de Anápolis e o centro da câmera são referências de área.
Origem manual, ponto selecionado e ponto ajustado pelo motor são identidades
separadas. Nenhum deles passa a ser posição atual do usuário.

`MapPlace.distanceMetersFrom`/`mapDistanceMeters` continuam sendo a fórmula
compartilhada. A UI mostra distância aproximada em linha reta, em m/km ou mi,
com PT/EN. Zero real permanece zero. Sem origem ou par válido, mostra
“Distância indisponível”. Distância de percurso usa a métrica retornada pelo motor.
O campo `Local.distancia` foi preservado por compatibilidade, sem uso como GPS.

Proximidade tem desempate por nome normalizado e identidade. Sem origem válida,
a descoberta ordena por nome; locais sem coordenadas ficam depois dos válidos
na ordenação por distância. Uma nova origem reinicia as páginas. Ordenação de
resultados externos se refere somente ao lote carregado.

## API de descoberta e compatibilidade

`GET /api/locais/` continua retornando a lista legada por padrão, em ordem de ID.
Não foi ativada paginação global em favoritos, contribuições ou outros endpoints.

| Parâmetro | Regra |
| --- | --- |
| `paginated` | Exatamente `true` ou `false`; padrão `false`. |
| `page`, `page_size` | Inteiros positivos; tamanho padrão 20, máximo 50. |
| `ordering` | `name`, `proximity`, `rating`; proximidade exige origem explícita. |
| `origin_lat`, `origin_lon` | Par finito em faixa; usado na consulta, nunca gravado no Local. |
| `search` | Nome/endereço, até 180 caracteres, codificado pelo cliente. |
| `bbox` | `sul,oeste,norte,leste`; área opcional, aceita cruzamento do antimeridiano. |
| `categorias`, `origens`, `recursos`, `incluir_desconhecidos` | Contratos existentes: OR em categoria/origem, AND em recursos e desconhecidos opcionais. |

Parâmetros desconhecidos, repetidos e valores inválidos retornam 400. Página
fora do conjunto retorna 404. A resposta paginada tem `count`, `next`, `previous`
e `results`. Filtros textuais, área, evidências e estatísticas válidas/visíveis
são aplicados antes da ordenação e paginação. Melhor avaliação considera média
e quantidade válidas; não inclui avaliações privadas alheias.

O OpenAPI em `locais/views.py` descreve as duas respostas e os novos parâmetros.
`opening_status: unknown` é somente leitura. `aberto` legado não comprova
“aberto agora”; esse filtro não foi inventado.

Explorar usa debounce de 350 ms, o mapa reutiliza 300 ms. Cada consulta tem termo,
filtros, ordenação, área, origem e revisão de sessão. Alterar critérios reinicia
as páginas. Erro na próxima página preserva os itens e permite retry.
`PlacesService.fetchDiscoveryPage` faz um GET por vez; o método antigo que baixa
todas as páginas permanece para consumidores legados.

`next` precisa conservar origem, caminho e critérios. Não aceita credenciais
na URL, fragmentos, parâmetros duplicados ou outra consulta. Ciclos são
detectados por uma identidade canônica de página, inclusive `page=01`.
Salvos continua exclusivamente em `/api/favoritos/`, com isolamento por conta.

Limite de implementação: a ordenação global e as agregações de evidência
materializam os candidatos filtrados no backend. Isso tem custo proporcional à
base consultada; não é uma promessa de escala geoespacial. PageNumberPagination
é determinística para conjunto estável, mas inclusões/remoções concorrentes
podem deslocar fronteiras. Não foi usado cursor baseado em ponto flutuante.

## Pesquisa geográfica e área

O geocodificador é consultado por submissão explícita. Digitação e pan/zoom não
disparam autocomplete ou consultas externas. Coordenadas decimais usam
`latitude, longitude`, com ponto decimal; zero é válido. Endereços numéricos
como `123 Main St, City` continuam sendo endereços.

Cada candidato preserva nome, coordenadas, tipo (`region`, `address`, `place`),
identificador do provedor e bounding box quando disponíveis. O usuário escolhe
entre homônimos. Selecionar região ajusta a câmera e oferece exploração;
selecionar endereço/coordenadas mantém um ponto roteável. Um estabelecimento
específico abre a própria prévia, mesmo que Overpass falhe na vizinhança.

POIs só recebem representação de estabelecimento e token assinado quando o
provedor informa nome, classe comercial/pública e identidade OSM válida.
Centroide de cidade, endereço ou coordenada não comprova identidade comercial.
Consulta e leitura não importam nem cadastram automaticamente.

“Buscar nesta área” consulta a base por bounding box e o Overpass por raio
limitado a 3 km. Área maior pede aproximação, sem impedir deslocamento do mapa
para outra região. Overpass mantém máximo de 100 resultados apresentados,
500 elementos brutos, timeout, limite de bytes, cache e bloqueio de chamadas.
Loaded/visível e truncamento descrevem o lote; não representam um total mundial.
Associação interna/OSM é conservadora e antecede os filtros finais, preservando
ID interno, evidências, notas e favoritos.

## Ponto livre e recuperação de coordenadas

Há toque prolongado e a ação “Escolher ponto no mapa” na pesquisa. O componente
compartilhado tem mira central, confirmação, cancelar, setas/zoom acionáveis por
teclado, campos decimais e pesquisa de endereço. Em altura pequena, mapa e
controles ficam numa rolagem; os botões continuam alcançáveis com texto 200%.

O ponto confirmado tem marcador temporário e prévia para rotear, substituir,
descartar ou iniciar cadastro explícito. Fechar a prévia permite reabrir o
marcador. Endereço reverso não é obrigatório. Rota até ponto não exige cadastro,
avaliação, favorito, visita ou chegada.

Dados legados sem coordenadas permanecem consultáveis. A ação de rota oferece
confirmar um ponto temporário. O destino de planejamento recebe `source: manual`,
sem ID interno; não modifica o cadastro, preserva a identidade original e não
oferece PATCH a quem não tem permissão. Alteração de Local continua restrita às
permissões existentes. Não há backfill de geocodificação durante migração.

## Cadastro e migração

`POST /api/locais/cadastro-manual/` exige autenticação atual e aceita somente:
`request_id` UUID, `nome`/`endereco` não vazios até 255 caracteres, categoria do
catálogo, latitude/longitude válidas, `point_confirmed` literalmente `true` e
`distinct_reason` opcional de 10 a 500 caracteres. O proprietário vem da sessão.

`0010_manual_registration` adiciona `ManualPlaceRegistration` e o guard singleton,
com seed transacional. Não transforma Local, evidências, avaliações, favoritos,
visitas, histórico, ledger ou conquistas. O teste de migração verifica esses
domínios antes/depois. Faça backup do banco antes da aplicação normal de migrations.

| Situação | Resultado |
| --- | --- |
| Primeira tentativa válida | 201 com Local; recibo por proprietário/UUID. |
| Retry com os mesmos dados normalizados | 200 com o mesmo ID. |
| UUID já usado com outros dados | 409, sem nova criação. |
| Local da tentativa removido | 410, recibo preservado como tombstone. |
| Possível duplicata | 409 com candidatos para revisão; criação distinta exige justificativa. |
| Contenção SQLite | 503 com Retry-After; repetir a mesma tentativa. |

O guard de banco serializa comparação/criação entre workers e usuários; a
importação OSM também participa do guard. A restrição única de proprietário/UUID
permanece no banco. Matching exige nome e endereço normalizados, categoria
compatível e distância até 25 m; proximidade ou homônimo isolado não fundem dados.
A justificativa é privada no recibo, sem expor o autor na descoberta.

O frontend bloqueia toques simultâneos. Depois de resposta incerta, congela
corpo/UUID para retry e exige a mesma conta. Login intermediário mantém os
campos em memória e usa a sessão atual; nenhuma senha é persistida. Um novo
rascunho é uma ação explícita. Após salvar, mapa/prévia/detalhes recebem o novo
registro e oferecem avaliação opcional pelo editor próprio existente.

`ExternalPlaceRegistration` e a importação por token assinado continuam ativos.
Há “Entrar e continuar” sem perder os campos. O token expira conforme o contrato
existente; coordenadas livres não substituem a validação da importação.
Cadastro sozinho não acrescenta nota, pontos, favorito, visita ou histórico.

Reverter a migration remove recibos e guard, perdendo a memória de idempotência.
Não use reversão como procedimento rotineiro para corrigir dados. Locais criados
continuam sendo registros públicos e exigem tratamento explícito apropriado.

## Rotas e provedores

O modo exibido continua **carro**. `ROUTE_BASE_URL` e `ROUTE_PROFILE` configuram
um endpoint/perfil realmente preparado. Alterar o nome para `foot` não prepara
um grafo de caminhada e não torna o percurso acessível. O padrão continua OSRM
público, perfil driving; cobertura e disponibilidade dependem do serviço.

Há causas distintas para origem/destino inválidos, GPS negado/desativado,
antigo/impreciso, rede, timeout, 429, 5xx, resposta inválida, NoRoute e NoSegment.
429/5xx têm prioridade sobre um corpo inconsistente que diga NoRoute. Retry
preserva origem/destino; cálculos antigos são descartados. Não existe linha reta
de fallback. Waypoints ajustados e deslocamentos são preservados; acima de 25 m,
o painel avisa sem mover o Local nem o ponto escolhido.

Prévia com origem manual não inicia navegação acompanhada. Início exige ação e
GPS apropriado, seguindo o controlador anterior. Links Google Maps/Waze continuam
por ação explícita, com modo/ordem de coordenadas coerentes. Abertura externa não
registra início, chegada ou conclusão fictícios no AcessoJá.

| Configuração | Comportamento |
| --- | --- |
| `NOMINATIM_URL` vazia | Busca por endereço informa indisponibilidade; mapa e coordenadas continuam utilizáveis. |
| Instância Nominatim compatível configurada | Busca explícita, cache de 24 h, orçamento/timeout existentes. |
| Nominatim público | Exige `NOMINATIM_PUBLIC_OPT_IN=True` e backend de cache Redis compartilhado por todos os workers. Gate único e cooldown de 2 s; sem autocomplete. Configure identificação/contato reais em `GEO_USER_AGENT`. |
| `OVERPASS_URL` | Consulta limitada/cacheada; 429 ou indisponibilidade exigem ação posterior, sem loop automático. |
| `MAP_TILE_URL` | Padrão OSM, atribuição preservada, identificação do app; sem download em massa/offline. |
| `API_BASE_URL` | Backend do Flutter; padrão web `http://localhost:8000`. |

Cache público guarda somente dados do provedor; token é renovado e matching,
evidências visíveis e vínculo interno são calculados na leitura. Respostas de
descoberta/geocodificação são privadas, sem armazenamento compartilhado da conta.
Credenciais de AppHttp seguem somente para a origem da API.

Coordenadas de proximidade não são gravadas no Local. O filtro de `django.server`
mascara latitude/longitude nos logs de acesso de desenvolvimento. Configure a
mesma proteção no proxy/servidor de produção e sua retenção; o filtro Django
não controla logs de infraestrutura ou do provedor externo.

## Arquivos principais

| Área | Arquivos e finalidade |
| --- | --- |
| Backend | `locais/discovery.py`, `views.py`, `serializers.py`: consulta, paginação e pares válidos. `manual_registration.py`, `models.py`, migration 0010: escrita e recibos. Serviços geográficos/matching, serializers/views externos: resultados tipados e importação. |
| Frontend compartilhado | `current_position.dart`, `place_distance.dart`, `discovery_query.dart`, `discovery_controller.dart`, `geo_candidate.dart`, `places_service.dart`: estado, contratos e HTTP. |
| Jornada | `main_screen.dart`, `explorar_screen.dart`, `geographic_search_screen.dart`, `map_point_picker.dart`, `manual_registration_screen.dart`: fluxos reais; telas de Salvos/Sugestões/contribuições/detalhes e preferências: propagação. |
| Rotas/identidade | `route_service.dart`, `navigation_route.dart`, `route_failure.dart`, `navigation_panel.dart`, `app_http.dart`, `api_service.dart`, traduções PT/EN: causas, perfil, snaps e sessão. |
| Testes | `locais/test_discovery_cards.py`, `discovery_cards28_33_test.dart`, `discovery_evidence_test.dart`; teste antigo de HTTP 503 atualizado para causa `unavailable`, mantendo a verificação. |

O manifesto no ZIP lista cada arquivo e hashes antes/depois. Dependências da
aplicação e arquivos gerados de registrantes/lock não precisam mudar.

## Verificações executadas

Ambiente Linux isolado, Python 3.12.14, Django 5.1.3, Flutter 3.47.4,
Dart 3.13.3 e SQLite de teste, fora do repositório. Provedores HTTP, GPS e tiles
são controlados nos testes. Nenhum teste de CI chama servidores públicos.

| Comando | Resultado desta entrega |
| --- | --- |
| `python -m pytest --cov=. --cov-report=term --cov-fail-under=80 -q` | 425 passaram, 6 ignorados por exigirem PostgreSQL real, 21 subtests; cobertura 96,02%. |
| `flake8 . --exclude=migrations,__pycache__,.venv,venv` | 0 ocorrências. |
| `python manage.py check` | Sem problemas. |
| `python manage.py makemigrations --check --dry-run` | Nenhuma mudança sem migration. |
| `python manage.py spectacular --fail-on-warn` | Sem avisos; schema gerado e validado. |
| `flutter analyze --no-pub` | Sem problemas. |
| `flutter test --no-pub` | 831 passaram; 196 regressões de rotas/leitura/contribuições e 39 testes específicos repetidos após os ajustes finais. |
| `flutter build web --release --no-pub` | Build web aprovado; dry run Wasm aprovado. |
| `CARDS28_CAPTURES=1 flutter test --no-pub test/discovery_evidence_test.dart` | Jornada controlada aprovada; sete capturas renderizadas e inspecionadas. |

Os seis testes ignorados são quatro de concorrência de contribuições, um de
favoritos e o novo de cadastro manual. O job PostgreSQL da CI agora seleciona
`contribuicoes favoritos locais -k postgresql_concurrent`. Execução real desse
job, Android/Chrome com GPS e homologação assistiva estão pendentes; não foram
presumidos aprovados. Android SDK não é necessário para rodar a versão web.

## Evidências

As imagens abaixo são renders de widgets reais com dados fictícios, sem GPS.
O mapa usa a imagem estática de apoio já existente no projeto; o trajeto é
resposta sintética de teste. Não são captura de cobertura geográfica real ou
homologação em navegador/dispositivo. O teste verifica que pesquisar, selecionar
e planejar não enviam POST; cadastro e editor são mostrados sem publicar avaliação.

| Cena | Captura |
| --- | --- |
| Mapa sem GPS | [01_mapa_sem_gps.png](capturas/cards_28_33/01_mapa_sem_gps.png) |
| Escolha de estabelecimento distante | [02_busca_distante.png](capturas/cards_28_33/02_busca_distante.png) |
| Prévia independente de vizinhança | [03_previa_estabelecimento.png](capturas/cards_28_33/03_previa_estabelecimento.png) |
| Mira e ponto livre | [04_ponto_livre.png](capturas/cards_28_33/04_ponto_livre.png) |
| Planejamento manual controlado | [05_rota_controlada.png](capturas/cards_28_33/05_rota_controlada.png) |
| Cadastro no tema escuro | [06_cadastro_escuro.png](capturas/cards_28_33/06_cadastro_escuro.png) |
| Editor opcional existente | [07_avaliacao_opcional.png](capturas/cards_28_33/07_avaliacao_opcional.png) |

Os testes incluem 320/360/390 px, horizontal, temas claro/escuro, texto 200%,
ações acima do teclado, GPS pendente após sessão, retry incerto em outra conta,
debounce, páginas antigas/cíclicas, zero, ausência e causas HTTP inconsistentes.
As regressões anteriores permanecem na suíte completa.

## Aplicação e roteiro manual

1. Faça backup do banco e preserve mudanças locais de terceiros. Compare a base
   e o manifesto antes de copiar o delta; não substitua arquivos divergentes às cegas.
2. Instale os requisitos existentes e mantenha `.env` e credenciais locais.
   Execute `python manage.py migrate`, depois `python manage.py check`.
3. No frontend, com Flutter 3.47.4, execute `flutter pub get`, `flutter analyze`,
   `flutter test` e `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000`.
4. Sem GPS, consulte a base, limpe a busca, carregue outra página e altere filtros.
   Pesquise outra cidade com provedor configurado, escolha um homônimo e explore
   a área explicitamente. Falta de provedor deve informar o estado apropriado.
5. Escolha um ponto sem marcador, confirme, feche/reabra e planeje com origem
   manual. Cancele e substitua. Confira que não aparece visita/histórico fictício.
6. Cadastre um estabelecimento fictício autorizado, interrompa com login e
   retome; confira candidato duplicado e retry. Abra o detalhe, avalie e edite a
   avaliação própria. Confira mapa, contagem e favorito na conta correta.
7. Com GPS real autorizado, compare duas posições, milhas/km, expiração e
   revogação. Teste NoRoute/NoSegment/429 sem perder destino. Use teclado e leitor
   de tela, fonte 200% e janela pequena. Registre ambiente/resultado da homologação.

## Referências oficiais consultadas

- [DRF — paginação](https://www.django-rest-framework.org/api-guide/pagination/): opt-in local e ordem determinística.
- [OSRM API 5.24](https://project-osrm.org/docs/v5.24.0/api/): ordem longitude/latitude, erros e waypoints.
- [Nominatim](https://operations.osmfoundation.org/policies/nominatim/): adesão deliberada, identificação, cache e limite agregado.
- [Tiles OSM](https://operations.osmfoundation.org/policies/tiles/): atribuição e ausência de varredura/offline em massa.
- [Overpass](https://dev.overpass-api.de/overpass-doc/en/preface/commons.html): orçamento de consulta em serviço compartilhado.
- [Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started): ações externas explícitas e modo driving.
- [Flutter — acessibilidade](https://docs.flutter.dev/ui/accessibility/accessibility-testing): testes de widgets complementam homologação assistiva.
