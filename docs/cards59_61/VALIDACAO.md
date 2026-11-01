# Validação — Cards 59–61

Estado: **implementação com homologação pendente**. Base `d7f2a5d068e630001c98b1a6630203dfe0f2f0d1` + delta. Ambiente Linux, Flutter 3.47.4/Dart 3.13.3. Próximo card: 62.

| Verificação | Resultado | Evidência |
| --- | --- | --- |
| flutter analyze | aprovado | evidencias/flutter_analyze.log |
| Suite Flutter completa | 1029 testes aprovados | evidencias/flutter_test.log |
| Build Web release | aprovado | evidencias/build_web.log |
| Django check/migrations | Sem issues / nenhuma migration pendente | evidencias/backend_contrato.log |
| Histórico backend | 36 testes em SQLite, sem alteração backend | evidencias/backend_contrato.log |
| Flake8 árvore do projeto | aprovado, conforme regras do workflow | evidencias/flake8.log |
| Chrome for Testing | 156.0.8078.80; 13 verificações, status passed | evidencias/chrome/relatorio.json |
| Search nativo | Clique real/ativação/nova aba/URL observados; não comprova conteúdo do provedor | external_launch no relatório |
| Google Maps externo | Carregamento final não homologado; ambiente retornou chrome-error | external_launch no relatório |
| APK | SDK ausente; sem APK entregue | evidencias/build_apk.log |
| Instalador | 7 testes aprovados: aplicação/backup, idempotência, CRLF, conflito, integridade, traversal/symlink e rollback | script test_instalador.py |
| Aparelhos/AT | Android físico, celular real, apps instalados e leitor humano pendentes | CT092–095 e limites abaixo |
| CI remota | Cobertura integral backend/PG/Redis não executados; gate 80% preservado | Nenhum workflow/backend alterado |

O laboratório executa main.dart.js real + API Django/SQLite, com dados sintéticos e OSRM/geolocalização controlados. Viewport emulado não é aparelho. O teste da consulta usa ponteiro real e observa a nova aba separadamente do retorno do plugin noopener/noreferrer. A página do Google não carregou no ambiente; o status aprovado refere-se aos passos da aplicação, não ao provedor externo. Não se afirma ficha comercial confirmada, viagem física ou acessibilidade do trajeto.

A suite final inclui a corrida de botão de A executado após troca para B, origem removida, chegada durante diálogo, câmera com/sem gesto novo, escrita de histórico pendente e regressões anteriores. As falhas esperadas na base e antes do ajuste de conta são logs separados. Não são testes finais reprovados.

A matriz tem 76 cenários com evidência automatizada, 20 com homologação complementar e 4 dependentes de dispositivo. São classificações de requisitos, não quantidades de execuções ou viagens. O JSON preserva preparação e resultado esperado de cada cenário recebido.

| ID | Cenário | Status | Evidência e limite |
| --- | --- | --- | --- |
| CT-59-61-001 | Mapa/painel compacto | Automatizado | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-002 | Painel expandido | Automatizado | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-003 | Detalhes a partir do mapa | Parcial / homologação complementar | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. O detalhe do mapa usa painel persistente; homologar o detalhe OSM isolado completo. |
| CT-59-61-004 | Salvos → detalhes | Automatizado | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-005 | Rota direta de Salvos | Automatizado | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-006 | Explorar → local | Automatizado | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-007 | Busca com filtros | Automatizado | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-008 | Histórico pelas Configurações | Automatizado | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-009 | Ponto manual | Parcial / homologação complementar | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Fluxo manual com provedores controlados; homologar retorno de ponto em aparelho. |
| CT-59-61-010 | Recuperação de coordenada cancelada | Parcial / homologação complementar | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Picker preservado; homologar cancelamento em aparelho. |
| CT-59-61-011 | Recuperação de coordenada concluída | Parcial / homologação complementar | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Ponto manual e guardas preservados; homologar recuperação integral no aparelho. |
| CT-59-61-012 | Encaminhamento entre telas | Automatizado | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-013 | Painel já montado | Automatizado | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-014 | Redimensionamento durante rota | Parcial / homologação complementar | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Layouts e retorno cobertos; redimensionamento durante viagem requer homologação adicional. |
| CT-59-61-015 | Identidades de fontes distintas | Parcial / homologação complementar | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Identidades/callbacks A/B cobertos; repetir colisão numérica no aparelho. |
| CT-59-61-016 | Repetição do percurso de telas | Automatizado | route_stack_history_cards_59_61_test; map_panel_cards_52_58_test; route_history_map_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-017 | Escolha inicial de origem | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-018 | Cálculo inicial pendente | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-019 | Prévia nunca iniciada | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-020 | Falha no primeiro cálculo | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-021 | X ativo → continuar | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-022 | Back ativo → encerrar | Parcial / homologação complementar | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Back de widget/encerramento verificados; gesto Android físico pendente. |
| CT-59-61-023 | Interrompida → continuar | Parcial / homologação complementar | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Interrupção/retomada/confirmacão cobertas; homologar sequência completa em aparelho. |
| CT-59-61-024 | Encerrar deliberadamente | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-025 | Chegada → concluir | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-026 | Planejamento após início | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-027 | Desistência do diálogo | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-028 | Menu sobre a rota | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-029 | Escape sem rota | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-030 | Voltar normal | Parcial / homologação complementar | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Retorno normal permitido; saída/gesto do sistema Android pendente. |
| CT-59-61-031 | Traçar rota em duplo toque | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-032 | Iniciar em duplo toque | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-033 | Encerrar/Concluir repetidos | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-034 | X + Back + Escape | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-035 | Chegada durante confirmação | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-036 | Logout durante confirmação | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-037 | Diálogo antigo de A | Parcial / homologação complementar | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Callback antigo rejeitado após B; modal impede seleção nova; homologar substituição externa durante diálogo. |
| CT-59-61-038 | OSRM responde após cancelar | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-039 | Recálculo seguido de fim | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-040 | Destino A responde depois de B | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-041 | Descarte com GPS pendente | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-042 | Callback de restauração após conta trocada | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-043 | Filtro alterado durante a operação | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-044 | Local removido | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-045 | Erro transitório ao restaurar | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-046 | Tela de origem descartada | Automatizado | route_stack_history_cards_59_61_test; route_return_cards_59_61_test; route_cards_07_08_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-047 | Consulta textual contextualizada | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-048 | Google Place ID pertinente | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-049 | Identidade OSM | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-050 | Identidade interna | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-051 | Só coordenadas | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-052 | Sem coordenada, com endereço | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-053 | Dados insuficientes | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-054 | Coordenada zero válida | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-055 | Coordenadas inválidas | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-056 | Ordem geográfica | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-057 | Codificação de texto | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-058 | Injeção por nome/endereço | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-059 | Minimização de dados do link | Automatizado | place_google_search_cards_60_test. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-060 | Prévia Google preservada | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-061 | Navegação Google preservada | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-062 | Waze preservado | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-063 | Consulta e cálculo simultâneos | Parcial / homologação complementar | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Geração do link independente e sem acesso ao contador de rota; sequência concorrente específica requer homologação adicional. |
| CT-59-61-064 | Resultado externo tardio | Parcial / homologação complementar | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Identidade/conta possuem guardas e atraso/seleção testado; variante integral de troca de conta na superfície pendente. |
| CT-59-61-065 | Ações por todas as fases | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-066 | Origem manual | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-067 | Instruções indisponíveis | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-068 | GPS inválido/expirado | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-069 | Launcher retorna false | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-070 | Launcher lança exceção | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-071 | Abertura pelo gesto Web | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-072 | Consulta sem segundo plano | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-073 | Segundo plano real | Parcial / homologação complementar | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Lifecycle simulado/recorder cobertos; segundo plano físico pendente. |
| CT-59-61-074 | Retorno do app externo | Parcial / homologação complementar | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. GPS expirado/retomada explícita cobertos; retorno de app instalado pendente. |
| CT-59-61-075 | Consulta discreta e distinta | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-076 | Medidas e limitação do percurso | Automatizado | place_google_search_cards_60_test; route_cards_07_08_test; Chrome quando indicado. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-077 | Cancelamento inicial sem histórico | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-078 | Um início autorizado | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-079 | Retomada da mesma sessão | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-080 | Recálculo da mesma sessão | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-081 | Encerramento voluntário | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-082 | Chegada única | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-083 | Saída externa não comprova chegada | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-084 | Histórico desligado | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-085 | Autorização desconhecida | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-086 | Revogação com fila pendente | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-087 | Troca de conta e resposta antiga | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-088 | Sessão apagada e retry | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-089 | Falha de gravação do histórico | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-090 | Traçar novamente com privacidade | Automatizado | route_history_service_test; route_history_map_test; route_stack_history_cards_59_61_test; backend_contrato.log. Evidência automatizada local. Não certifica execução manual ou aparelho. |
| CT-59-61-091 | Teclado Chrome desktop | Parcial / homologação complementar | reading_layouts_test; route_cards_07_08_test; Chrome e logs finais. Escape e entrada reais no Chrome/menu em widget; percurso completo Tab/Shift+Tab/foco requer revisão humana. |
| CT-59-61-092 | Chrome em celular real | Pendente em dispositivo | reading_layouts_test; route_cards_07_08_test; Chrome e logs finais. Chrome em celular físico indisponível; viewport não substitui. |
| CT-59-61-093 | Android Back/gesto físico | Pendente em dispositivo | reading_layouts_test; route_cards_07_08_test; Chrome e logs finais. Android físico/predictive Back indisponível; SDK ausente. |
| CT-59-61-094 | Aplicativos externos instalados/ausentes | Pendente em dispositivo | reading_layouts_test; route_cards_07_08_test; Chrome e logs finais. Google Maps/Waze instalados/ausentes indisponíveis; popup observado, página externa não carregada no laboratório. |
| CT-59-61-095 | Leitor de tela | Pendente em dispositivo | reading_layouts_test; route_cards_07_08_test; Chrome e logs finais. TalkBack/leitor humano indisponível; semântica automatizada é parcial. |
| CT-59-61-096 | Texto 200% e temas | Parcial / homologação complementar | reading_layouts_test; route_cards_07_08_test; Chrome e logs finais. Widgets 200%/temas e capturas; contraste e percepção final requerem revisão humana. |
| CT-59-61-097 | Paisagem e teclado aberto | Parcial / homologação complementar | reading_layouts_test; route_cards_07_08_test; Chrome e logs finais. Paisagem/teclado em widgets; teclado/safe areas em aparelho pendentes. |
| CT-59-61-098 | PT/EN e estados de erro | Parcial / homologação complementar | reading_layouts_test; route_cards_07_08_test; Chrome e logs finais. PT/EN e erros em widgets; revisão linguística humana completa pendente. |
| CT-59-61-099 | Reinicialização segura | Parcial / homologação complementar | reading_layouts_test; route_cards_07_08_test; Chrome e logs finais. Reload Chrome verificado; reabertura de processo Android pendente. |
| CT-59-61-100 | Regressão integrada da base final | Parcial / homologação complementar | reading_layouts_test; route_cards_07_08_test; Chrome e logs finais. Frontend local/backend focado; CI remoto/PG/Redis e homologação física pendentes. |
