# AcessoJá — Cards 59–61

Implementação dos três cards, com homologação em dispositivos e carregamento do provedor externo pendentes. Leia VALIDACAO.md para o estado exato das execuções. Base imutável `d7f2a5d068e630001c98b1a6630203dfe0f2f0d1` do repositório acessoja/acessoja-app, consultada em 01/11/2026. O trabalho foi feito sobre arquivo, sem checkout Git local. Os Cards 52–58 já estão integrados à base. Próximo card novo: **62**.

Trello consultado somente em leitura: 59/4A https://trello.com/c/g8eOebx5, 60/4B https://trello.com/c/ZD88mlLo e 61/4C https://trello.com/c/sNkAhxwS. Não foram criados commits, PRs, merges, publicação ou mudanças de cards.

## Card 59 — retorno e saída

`PlaceRouteRequest` transporta destino validado e `RouteReturnContext` tipado. O contexto guarda revisão da conta, caminho de entrada imutável e, quando pertinente, o PlacePanelContext existente. Não guarda BuildContext, State, widgets, respostas completas, credenciais ou persistência. Todos os produtores/consumidores foram migrados juntos para encaminhar o pedido inteiro, sem reduzir a `.place`.

Salvos, Explorar, Sugestões, Detalhes e Histórico encaminham pedidos por callback ao coordenador. RoutePlanningScreen fica acima da pilha real, mantendo busca, filtros, ordenação, scroll e telas anteriores montados. Ela possui somente apresentação/câmera; o NavigationController, GPS e RouteHistoryRecorder continuam sendo os mesmos de MainScreen. Não há outro MainScreen, rastreador, motor ou estado paralelo de navegação.

Cada entrada fica vinculada à conta que abriu a tela. Um callback já renderizado por A não pode criar um pedido de B antes do próximo frame. Troca de conta invalida esse encadeamento e orienta reabrir a origem. Modais, pontos e resultados legados também validam a revisão antes de consumir dados. Uma regressão reproduz especificamente essa corrida.

No mapa, o painel é suspenso com seu ticket existente. O coordenador captura apenas câmera e revisões dos proprietários de câmera/busca/filtros. Ao sair, valida operação, conta, seleção/geração e fase. A câmera anterior volta se a rota a moveu; uma intenção mais recente do usuário prevalece. Não relaxa filtros nem recria marcadores. Um ticket antigo ou de outra conta é rejeitado. Se a origem foi removida da pilha, o Navigator faz fallback à tela ainda montada, sem reconstrução fictícia ou foco em contexto descartado.

Detalhes revalida o local no retorno: 404/410 mostra indisponibilidade; 503/rede mantém os dados anteriores e feedback recuperável. O painel reutiliza a política de indisponibilidade do PlacePreviewController. Recuperação cancelada não inventa coordenadas; a concluída permanece ponto manual e não cadastra o local automaticamente.

A sessão já iniciada é reconhecida por `_navigationSessionStarted`, separada da fase visual. X/Back/Escape abrem uma confirmação única mesmo após revisar origem ou recalcular. Continuar/dispensar não retoma nem inicia nada. Encerrar explícito não exige uma segunda confirmação. Chegada oferece Concluir e voltar. A resposta revalida operação/conta/fase: chegada não vira cancelamento, callback de A não encerra B e logout impede retorno pós-frame antigo. Menus/diálogos recebem o evento antes da rota; sem rota, permanece o comportamento de recolher/fechar painel e retorno normal.

Sair invalida GPS/cálculos pendentes e limpa UI sem esperar a API do histórico. Os testes cobrem a escrita de histórico deliberadamente pendente durante o encerramento.

## Card 60 — consulta e painel

GooglePlaceSearch cria URI Search (`/maps/search/`, api=1, query) com host/caminho fixos e parâmetros estruturados. O adaptador da API atual ignora todos os campos de ID Google, inclusive um booleano dizendo que seria verificado: não existe proveniência correspondente nessa API. Usa nome/endereço/cidade/UF conhecidos; sem contexto textual suficiente, usa coordenadas numéricas finitas e dentro da faixa. Zero é válido. Sem dados suficientes, explica a indisponibilidade. A URI codificada respeita o limite de 2.048 caracteres.

O construtor de baixo nível suporta ID Google vindo de um adaptador realmente confiável; a fixture não é uma associação implantada em produção. Não deriva IDs de prefixos, regex, OSM, catalog_id ou id_local. O link não envia conta, token, preferências ou origem GPS. Um ponto manual é rotulado como localização, sem prometer ficha comercial.

PlaceMapsLink é uma ação textual junto ao endereço em Detalhes e no painel expandido; o detalhe OSM reutiliza a mesma apresentação. Tem área mínima de 48 px e densidade padrão explícita para impedir redução no desktop. Evita duplicar um botão grande. Tem geração própria, isolamento de conta/seleção e guarda de descarte. Invoca o launcher no gesto antes do primeiro await; false/exceção oferecem feedback acessível e permitem tentar novamente.

Search é separado de Directions/Waze. Mais opções mantém Ver rota no Google Maps, Navegar no Google Maps e Navegar no Waze. O callback externo não incrementa geração de cálculo/GPS nem chama interrupt antecipadamente. Somente o lifecycle real conserva a política central de segundo plano, com retomada explícita. Um link não comprova viagem, chegada, visita ou pontos.

NavigationPanel usa uma principal por fase e agrupa secundárias. Cálculo tem progresso/saída; prévia só inicia com condições válidas; origem manual exige recalcular da localização atual para guiar; running oferece encerramento; interrupção oferece recuperação pertinente; chegada oferece conclusão; ended oculta o painel. Permanecem métricas reais, unidade configurada e aviso de percurso de carro sem acessibilidade certificada. A instrução viva foi separada da distância variável para não anunciar cada atualização de GPS como nova manobra. Textos seguem routeText PT/EN.

## Card 61 — contrato preservado

Nenhum backend, migration, dependência, lockfile ou Quality Gate foi alterado. Permanecem preferências save_history/save_origin/revision e UUID por sessão. Eventos: started, recalculated, resumed, interrupted, arrived, cancelled. Estados persistidos: in_progress, interrupted, completed, cancelled. Não foram criados eventos ended/completed/viewed_google_maps. Concluir após arrived não produz cancelled. Traçar novamente cria planejamento novo, usa GPS atual e não reativa UUID nem origem antiga. Consentimento de histórico, origem e visitas permanece separado de permissão de GPS; origem aproximada só quando autorizada, sem rastro de posições.

VALIDACAO.md e matriz_cenarios.json relacionam os 100 cenários, com evidências e limites. Uma lista de critérios não é log de 100 execuções manuais.

## Aplicação no Windows e execução com Chrome

Extraia o ZIP fora do repositório. Com Python 3.10+ na pasta extraída:

```powershell
py .\aplicar_cards59_61.py --repo C:\Users\USER\acessoja-app --check
py .\aplicar_cards59_61.py --repo C:\Users\USER\acessoja-app
```

O primeiro comando é leitura. O segundo verifica todos os arquivos antes de escrever, cria backup, preserva CRLF e recusa conflitos, caminhos inseguros, symlinks e payload adulterado. Reaplicação é segura e falha intermediária faz rollback. Não restaure trabalho local para forçar a aplicação: compare/mescle cada divergência indicada. Manifesto e diff permitem revisar a mudança.

Use Flutter **3.47.4**, fixado em frontend/.fvmrc. Configure backend/CORS pelo README/setup-dev.ps1 existente; para API local em 8000:

```powershell
cd C:\Users\USER\acessoja-app\frontend
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Com FVM, prefixe com fvm. Chrome não exige Android SDK. Geolocalização Web usa localhost ou HTTPS apropriado. Ajuste a API ao ambiente; não publique o loopback de teste. O build validado usa recursos locais e API localhost:8001 num laboratório descartável, não é configuração de produção. O ZIP entrega fontes/delta, sem SDK, caches, venv ou builds.

Para reproduzir o laboratório, buildar com `--no-web-resources-cdn --dart-define=API_BASE_URL=http://127.0.0.1:8001`, instalar Playwright e dependências backend, e executar frontend/integration_test/route_return_browser_lab.py com --chrome CAMINHO_CHROME --report CAMINHO_RELATORIO. Portas 8001/8002 devem estar livres. Banco, usuário e dados são sintéticos; OSRM/GPS são fixtures. O script cria e remove seu ambiente temporário.

Para testar o instalador, obtenha o ZIP da [base imutável](https://github.com/acessoja/acessoja-app/archive/d7f2a5d068e630001c98b1a6630203dfe0f2f0d1.zip), confira o SHA do manifesto, defina ACESSOJA_BASE_ZIP para ele e execute `py test_instalador.py`. Não se inclui outro repositório completo no pacote.

## Limites

Android físico/predictive Back, Chrome em celular real, TalkBack/leitor humano e Google Maps/Waze instalados permanecem pendentes. Emulação de viewport não substitui aparelho. APK não foi gerado sem Android SDK. CI remota, concorrência PostgreSQL, Redis e cobertura integral backend não foram executadas; o gate de 80% permanece intacto.

No Chrome for Testing, o clique real abriu nova aba Search com ativação preservada e URL correta. A página externa chegou a chrome-error no laboratório: seu carregamento final não foi homologado. Não se afirma identificação de ficha comercial. O plugin Web usa noopener/noreferrer, e seu retorno não certifica popup ou conteúdo carregado. O teste observa a aba separadamente; a aplicação não inventa sucesso de conteúdo, início ou chegada por esse retorno.

Referências primárias consultadas: Google Maps URLs (https://developers.google.com/maps/documentation/urls/get-started), url_launcher 6.3.2 (https://pub.dev/packages/url_launcher/versions/6.3.2), Flutter PopScope (https://api.flutter.dev/flutter/widgets/PopScope-class.html), Waze (https://developers.google.com/waze/deeplinks) e o contrato existente docs/HISTORICO_DE_ROTAS.md. A instrução integral recebida está em REQUISITOS.md.
