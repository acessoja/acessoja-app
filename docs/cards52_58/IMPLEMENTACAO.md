# AcessoJá — Cards 52 a 58

Base de revisão: `acessoja/acessoja-app`, main `2d3fdd2c7fcc33fb0de3b9a120787173d372a154`, consultada em 31/10/2026. A comparação com develop (`05972eadad7f6faa7d8c4eb8cad29a068b5421f8`) apresentou zero arquivos diferentes. Esta base já contém os Cards 38–51; não aplique novamente os pacotes antigos. Próximo card novo: **59**.

O pacote entrega código integrado e verificações reproduzíveis. **Homologação assistiva e em Android físico permanece pendente.** Os campos de implementação, automação, inspeção visual e homologação não são equivalentes. Nenhum card foi movido no Trello. Não houve commit, push, PR, merge ou publicação.

## Resultado por card

| Card | Implementação e arquivos principais | Automação | Inspeção / homologação | Pendências concretas |
|---|---|---|---|---|
| 52 | Dez recursos/quatro grupos; até três no compacto, preferências, alerta de divergência fora dos três; estados textuais; expansão de contagens/fontes/datas; menu contextual preservando alvo/revisão. `resource_information_list.dart`, `feature_provenance.dart`, `evidence_details_screen.dart`. | Catálogo/estados/datas estritas; paginação com retry; 401/403/409; testes existentes de evidências e privacidade. Resumo público com 21 relatos e duas páginas no backend. | Capturas de recursos divergentes e fontes na aplicação compilada. | Leitura assistiva humana em PT/EN, sobretudo expansão de históricos longos. |
| 53 | Painel persistente em Stack; móvel arrastável, lateral a partir de 1000 px; Expandir/Recolher/X; Escape/Back; mapa descoberto interativo; scroll conectado ao controlador da folha. `persistent_place_panel.dart`, `main_screen.dart`. | Transições reais no MainScreen, diálogo superior, fechamento tardio, rotação, teclado, texto 200%, dimensões reais. | Chrome real headless, desktop e viewport móvel emulada. | Toque/rotação/teclado de Android físico. |
| 54 | Cabeçalho com favorito e origem; recursos, avaliações/fotos públicas e informações; ausência de nota/GPS honesta; vínculo externo explícito; falhas independentes. `map_place_preview.dart`, `place_reviews_section.dart`, `favorite_button.dart`. | Falha de fotos preserva avaliações e retry não as consulta novamente; estados privados excluídos; suíte servidor de mídia/arquivos/cache. | Galeria integrada consulta Django e armazenamento privado reais; somente imagem aprovada aparece. | Homologação com fotos e conexão de aparelho real. |
| 55 | Uma autoridade de seleção/nível/seção/scroll; tickets por identidade/geração/sessão; retorno de editor/fontes/galeria; dados privados descartados ao trocar conta; retorno de rota pelo coordenador existente. `place_preview_controller.dart`, `navigation.dart`, MainScreen. | A→B→A, registro externo terminando após B, sessão, cache, dispose, erro/retry e integração de rotas/histórico. | Fluxos de fontes e retorno no navegador; focus traversal por Tab e Escape. | Leitor de tela humano; jornadas completas de Salvos/Explorar e retorno de app externo em hardware. |
| 56 | Onze categorias/fallback preservados; pino, seleção/foco e grupo distinguíveis por forma/contorno; alvo real 48×48; legenda PT/EN; rótulo visual sem foco duplicado. `adaptive_place_layer.dart`, `map_cluster_sheet.dart`. | Guideline API Android/label/contraste, identidade e categorias; contraste não textual ≥3:1 entre ícone/borda/foco e superfície opaca em cinco temas. | Marcador/grupo selecionado em capturas reais da aplicação. | Tiles públicos variados, daltonismo e leitura assistiva em hardware; não alterados tema/tiles/versão do flutter_map. |
| 57 | União dos IDs sem duplicação; agrupamento existente; pontos coincidentes acessíveis; lista de resultados usa a mesma seleção; abrir grupo não aproxima câmera; retângulos reais reservados sem deslocar coordenadas. | Geometria/viewport/filtros; alvos encobertos; zoom; zero válido; comparação de rede e reconstruções; mudança móvel↔lateral conserva seções carregadas. | Lista/grupo e escolha de membro no Chrome; mapa continua visível. | Modos Qualquer/Priorizar não existem nesta base: aceites condicionais CT-45/46 registrados como dependência, sem implementá-los. |
| 58 | Matriz CT-01–56, logs, laboratório de navegador e medições antes/depois de 5/50/500. | Analyze, suíte Flutter, backend com gate de 80%, build web, lint/schema/migrations e verificações do instalador. Veja `VALIDACAO.json` para resultados finais. | Capturas sintéticas solicitadas; inspeção visual pelo agente; Chrome headless não equivale a homologação humana. | Android SDK/aparelho/TalkBack, Chrome móvel real e leitor de tela; PostgreSQL/Redis/CI remoto. |

## Contrato de seleção e retorno

`PlacePreviewController` controla `selectedId`, `PlacePanelLevel`, `PlacePanelSection`, origem, scroll e suspensão. A chave interna canônica é `acessoja:{id}`; a origem OSM preserva IDs compostos. Nenhum ID interno é deduzido de coordenadas, nome ou número do objeto OSM. Vínculo/cadastro depende da resposta do servidor e preserva a proveniência disponível.

Um `PlacePanelContext` captura identidade, geração de seleção, revisão da sessão, nível, seção, offset e origem. `owns()` é obrigatório após await; voltar de uma ação de A nunca restaura A sobre B. A geração do fetch é separada da geração da seleção para permitir atualização parcial sem perder o ticket de retorno. Fechar, dispose e trocar conta invalidam operações antigas. Um erro 401/403/404/410 na consulta do local retira os detalhes e desabilita mutações até revalidação.

Expandir/recolher/fechar, escolher um membro ou abrir um agrupamento não movem a câmera. Rota e “Ver no mapa” continuam usando suas políticas existentes. O retorno de rota é guardado pelo MainScreen e restaurado ao encerramento pelo `NavigationController`; não há outro coordenador de cancelamento. Dados válidos permanecem quando a atualização de uma fonte falha. Se um filtro excluir a seleção, o painel informa a exclusão; nenhum pino extra é inserido.

As entradas de busca e lista usam o mesmo controlador. Salvos/Explorar e links antigos mantêm seus contratos de navegação e reutilizam os componentes de informação; `PlaceDetailScreen` e `MapPlaceDetailsScreen` continuam compatíveis. O `ReviewEditorScreen`, upload e regras de pontuação dos Cards 38–51 não foram redesenhados.

## Scroll, geometria, acessibilidade e rede

O `ScrollController` do DraggableScrollableSheet é conectado ao SingleChildScrollView real. O conteúdo mantém uma GlobalKey por identidade ao mudar entre folha e lateral; as seções visitadas ficam Offstage para preservar estado e evitar fetch por resize. Novas seleções ganham outra chave. Cada seção tem offset salvo; ações canceladas recuperam o contexto e o foco quando o nó ainda existe. Se o marcador foi descartado/agrupado, o foco retorna ao botão da lista.

O painel fornece seu retângulo efetivo; barras, legenda, busca, lista e menu também são medidos. A geometria marca alvos encobertos, conserva seus IDs no layout e disponibiliza os membros na lista. Não empurra a coordenada do estabelecimento para uma área livre. A folha usa cerca de 38% em compacto e até 90% em expandido, conservando espaço para os controles em telas baixas; a posição intermediária de arraste não cria um novo estado de negócio. Snap e comandos por botão são separados. As proporções são escolhas de layout, não novos requisitos do domínio.

As medidas são publicadas após o frame, somente quando mudam. Resize/teclado não chama setState durante a construção. O botão global de leitura respeita a altura/largura real dos painéis; se não houver espaço seguro, os ajustes existentes continuam acessíveis pelas configurações. Sua preferência de posição não é sobrescrita por esse ajuste transitório. Marcadores e esse botão têm uma única ação semântica rotulada.

Cache de detalhe: até 50 internos e 50 entradas de catálogo, TTL de um minuto, invalidação explícita e por sessão. Expansão/rebuild não faz descoberta geográfica. Descoberta mantém seu próprio debounce, cache e cancelamento. O benchmark usa contadores/guardas para detectar rede; consulte as limitações das medições em `DESEMPENHO.md`.

## Adição mínima ao backend

O GET existente de evidências aceita `include_summary=true`. Quando solicitado, retorna `summary` com a mesma projeção pública do detalhe do local, calculada sobre **todas** as páginas do recurso/escopo, inclusive OSM sem local vinculado. O corpo legado não muda sem o parâmetro. O resumo não nasce da contagem da página visível; conteúdo privado, retirado, inválido e substituído segue as regras existentes. O frontend aplica a projeção apenas à seleção/sessão vigentes.

Esse ajuste evita um recurso externo continuar divergente/incorreto após uma contribuição porque não existe outro endpoint de resumo por recurso não vinculado. Sem ele, inferir totais da primeira página seria incorreto. Não há endpoint novo, migration ou mudança de pontos. Continuam `Cache-Control: private, no-store` e `Vary: Authorization, Cookie`.

Fotos públicas continuam protegidas no servidor, incluindo miniatura, arquivo e cache; uma filtragem visual de `approved` é apenas defesa adicional. A integração usa os contratos existentes de mídia e idempotência. Nenhuma mutação é reaplicada automaticamente após login/409. A pontuação continua baseada nas confirmações do backend.

## Manutenção e validação

Os requisitos completos estão em `REQUISITOS.md`; o retrato somente leitura do Trello está em `REQUISITOS_TRELLO.json`. A matriz identifica testes, inspeção e dependências, sem transformar 56 cenários em 56 testes redundantes. Logs e medições brutas ficam em `evidencias/`.

Leia `LEIA-ME_CARDS_52_58.md` na raiz do pacote para aplicar e executar no Windows/Chrome. A validação é da base indicada mais este delta, não de um checkout remoto que continue mudando. Gere PR apenas após inspecionar o diff na sua branch e executar os checks do ambiente real.

Referências técnicas consultadas: [DraggableScrollableSheet](https://api.flutter.dev/flutter/widgets/DraggableScrollableSheet-class.html), [controlador](https://api.flutter.dev/flutter/widgets/DraggableScrollableController-class.html), [Guideline API](https://docs.flutter.dev/ui/accessibility/accessibility-testing), [alternativa a arrastar](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html), [contraste não textual](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html), [flutter_map 6.2.1](https://pub.dev/packages/flutter_map/versions/6.2.1) e [MarkerLayer v6](https://docs.fleaflet.dev/v6/layers/marker-layer). O pacote preserva flutter_map 6.2.1 e o algoritmo de agrupamento existente.
