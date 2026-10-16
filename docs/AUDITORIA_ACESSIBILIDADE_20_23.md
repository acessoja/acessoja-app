# Auditoria de acessibilidade — Cards 20–23

Data da entrega: 15/10/2026 UTC. Implementação Flutter sobre os arquivos recebidos do AcessoJá, preservando as alterações locais dos Cards 17–19. Este relatório registra evidência automatizada e inspeção de renderizações; os aceites com leitores de tela reais continuam pendentes.

## Correspondência e diagnóstico inicial

| Roteiro / Trello | O que existia na base | Lacuna e correção desta entrega | Evidência |
|---|---|---|---|
| 20 / [#53](https://trello.com/c/x8K85t86) | LocalCard, onboarding, mapa e histórico já tinham semântica parcial; formulários tinham navegação por teclado. | Detalhes anunciavam placeholder como foto; notas/estrelas tinham leitura separada; links não tinham papel explícito. Unificação de notas/contagens, fallback honesto de imagens/horário, links e respostas selecionadas do questionário. | Árvores semânticas, ações nativas, guidelines e regressões anteriores. Leitor real pendente. |
| 21 / [#25](https://trello.com/c/jnz37keo) | Temas claro/escuro e escala do sistema em grande parte do app. | Não havia preferência local compartilhada de leitura/alto contraste. Contornos fracos, texto com opacidade e alturas fixas. Acrescentados estados persistentes, temas, fontes, contornos e reflow. | Pares de contraste abaixo; matriz 100/150/200%, composição 225% e curva não linear. |
| 22 / [#116](https://trello.com/c/QsChPDoz) | Prévia externa, busca e filtros já tinham rolagem/Wrap; marcadores já eram agrupados. | Status expandido ocupava mapa; busca não considerava altura real; nomes/ações internos limitados. Status recolhível/modal horizontal, medidas reais e listas que rolam. | Matriz do mapa/detalhes; testes antigos de sheets, seleção, agrupamento e teclado. |
| 23 / [#128](https://trello.com/c/U1U4Rdwl) | AppPreferences/SharedPreferences e Configurações existentes. | Não existiam botão/painel de leitura, posição nem alternativa ao arraste. Implementação compartilhada, persistência defensiva, movimento livre, botões/setas, foco e acesso alternativo. | Testes de armazenamento, gestos, teclado, modais, foco e preservação de estado. |

Não foi aplicada a afirmação histórica de que nenhuma tela possuía Semantics. A semântica e os fluxos dos Cards 17–19 foram preservados e ampliados onde necessário. `login_screen_redesigned.dart` não é a tela roteada pelo aplicativo e não foi refeito como um fluxo paralelo.

README, CONTRIBUTING, instruções anteriores e `.github/workflows/quality-gate.yml` foram consultados. Não havia AGENTS.md no checkout. As imagens de referência do painel não estavam disponíveis; foi usada a descrição funcional do roteiro, sem afirmar inspeção dessas imagens.

## Inventário dos fluxos reais

| Fluxo | Achados / tratamento | Verificação e limite |
|---|---|---|
| Login e Cadastro | Rótulos nativos e next/done preservados. Botões podem crescer, texto quebra, contorno de campo usa contraste maior e foco de 2,5 px. Guarda de envio e endpoints preservados. | Matriz nova em cinco viewports e cinco variantes; testes antigos de teclado/envio/formulário. |
| Onboarding | Arte explicitamente decorativa; ocultação não afeta controles. Texto respeita tema/fonte/altura. | Onboarding anterior e casos 320/1280 a 200%; imagem decorativa ausente da semântica. |
| Menu e navegação principal | Mesmas ações, sem nova aba. Barra inferior reagrupa rótulos grandes em botões com quebra e rolagem limitada. | Layouts e callbacks anteriores; rodapé medido para posicionar o botão móvel. |
| Explorar, mapa, status, filtros e busca | Status compacto/expansível; em horizontal vira ação que abre painel rolável. Busca exibe rótulo curto localizado, mantendo nome semântico completo. Reservas de rótulos usam medidas reais. Atribuição é link. | Cinco viewports a 200%, regressões de mapa/sheets/teclado e acesso por lista. A posição inicial do botão deixa busca e centralização acionáveis. |
| Marcadores, agrupamentos e prévia externa | Cálculo de nomes inclui estilo, fonte, altura, espaçamento e TextScaler no cache. Dimensões de origem/destino crescem. Mantidos agrupamentos, seleção e callbacks de Detalhes/Avaliar/Ver avaliações/Contribuir/Rota. | Testes existentes e matriz nova que aciona as cinco ações disponíveis na prévia. |
| Detalhes internos e externos | Nome completo e endereço consultáveis em rolagem; ação de rota cresce e anuncia planejamento. Nota/quantidade em leitura única. Placeholder não é anunciado como foto real. Tags conhecidas continuam localizadas; informação desconhecida permanece desconhecida. | Matriz, nomes/endereço longos, estados ausentes e testes dos detalhes/questionário. |
| LocalCard | Trabalho do Card 17 mantido. Nota real zero continua distinta de ausência; contagem acrescentada quando informada; horário ausente não vira “aberto”. | Suíte do LocalCard, semântica PT/EN e testes de mídia. |
| Salvos e Sugestões | Header/lista de Salvos passam a rolar juntos, com SliverList. Notas e rótulos do resumo quebram linha; imagem inválida recebe placeholder descritivo. O resumo calcula média apenas das notas informadas, preservando zero real; não converte ausência em zero. Sugestões mantém visitas, não passa a representar sessões de rota. | Estados de rede/vazio/retry anteriores; casos estreitos a 200%, testes de mídia e resumo com/sem notas reais. |
| Avaliações, editor e questionário | Resposta tem uma unidade semântica com pergunta, opção, seleção e ação nativa. Cor não substitui texto. Mantidas opções desconhecido/não aplicável/relatos e critérios de pontuação. | Suítes do questionário, modal e contribuições; teste conserva respostas ao alterar leitura. |
| Central Avaliar | Apresentação herda os mesmos ajustes. Autoria, formulário e regras de contribuição não foram alterados. | Suítes antigas e casos 320/1280 a 200%. |
| Histórico e navegação de rota | Mesmos consentimentos, estados, registros e exclusões. Ajustar leitura não recria controlador/Navigator nem inicia outra sessão. | Testes de histórico anteriores, cinco casos com composição 225% e sessão ativa preservada. |
| Perfil, Configurações, gerais, privacidade e ajuda | Entrada de leitura e atalho da barra em Configurações; indisponibilidade do perfil não impede uso local. Alvos de voltar ampliados nas telas corrigidas e appbars adaptáveis. | Casos de layout, perfil offline e estado compartilhado com painel. |
| Direitos | Links reais recebem papel semântico e destaque adicional quando solicitado, com destinos e tratamento de erro preservados. | Testes de URL/voltar, semântica de link e casos a 200%. |
| Painel móvel | Um único controle, alvo 56 px, gesto restrito à sua área, valores e limites reais, persistência com erro/retry, foco devolvido. | Arraste/clique, teclado, direções por toque, teclado virtual, resize, foco/modal e guidelines. |

## Problemas reproduzidos e regressões corrigidas

- **Base recebida, antes da correção:** Cadastro em 320 × 640 com texto a 200% produziu overflow horizontal de 85 px. Botões/textos flexíveis eliminaram o corte, sem reduzir a escala.
- **Durante a aplicação da matriz ampliada:** Salvos a 200% deixava o cabeçalho sem espaço para a lista e produziu overflow inferior de 297 px. Header e lista agora compartilham um CustomScrollView com lista preguiçosa.
- A composição nota/estrelas de Salvos produziu overflow horizontal de 5 px; passou a usar Wrap. O marcador de origem/destino produziu overflow de 3 px; a caixa passou a usar métricas efetivas do texto.
- Um status excessivamente alto encobriu um marcador em regressão antiga. O painel agora respeita a altura real disponível e um teto de 22% da altura da tela (até 240 px), com conteúdo rolável. Em horizontal não permanece sobre o mapa.
- A inspeção das capturas mostrou colisão da posição inicial do botão com a centralização em horizontal. A posição padrão foi deslocada para 75% / 25%; o teste verifica a ausência de interseção com busca e centralização nas cinco viewports.
- A validação final do manifesto de fontes corrigiu uma família com serifa sem assets registrados. Os assets Roboto/DejaVu passaram a ter registros únicos; as capturas foram geradas com as fontes reais e o build inclui ambas.
- A inspeção visual corrigiu texto herdado do TextTheme que ainda ficava branco no esquema amarelo no preto. O tema de texto agora usa os tokens reais de cada esquema; os testes conferem também as cores do TextTheme, além da extensão AppColors. Rótulos do resumo de Salvos deixam de usar ellipsis com fonte ampliada.
- A mensagem de boas-vindas do mapa pode cobrir controles temporariamente. Os testes novos aguardam sua duração antes de acionar esses controles; não foram desabilitados avisos de hit test ou assertions de layout.

Os três primeiros problemas de ampliação não foram classificados todos como preexistentes: somente o overflow de 85 px foi reproduzido na cópia inicial desta tarefa. Os demais foram encontrados durante a integração e corrigidos antes da entrega.

## Contraste

Critério: razão de luminância relativa sRGB `(LmaisClara + 0,05) / (LmaisEscura + 0,05)`. Superfícies translúcidas são compostas com o fundo efetivo antes de calcular. Texto comum usa **mínimo 4,5:1**; texto grande poderia usar 3:1 (18 pt regular ou 14 pt negrito), mas os pares listados passam também em 4,5:1. Contornos de campos e indicadores de foco verificados usam **mínimo 3:1** contra o fundo adjacente. Bordas puramente decorativas não são tratadas como indicação funcional de estado.

As cores vêm das instâncias reais de `AppColors`/`readingTheme`, não de uma paleta paralela no relatório. `reading_preferences_test.dart` verifica texto principal/secundário em página, superfície, superfície elevada e campos; primário, botões e estados; contorno e foco. O painel tem testes de guidelines de rótulo, tamanho de alvo e contraste nos temas claro/escuro, normal/alto contraste. Isso não equivale a medir cada pixel de toda a aplicação ou cada fundo de tile externo.

| Tema de origem / ajuste | Texto / superfície | Secundário / elevada | Primário / suave | Texto / botão | Erro / suave | Sucesso / suave | Aviso / suave |
|---|---:|---:|---:|---:|---:|---:|---:|
| Claro / Padrão | 14.63:1 | 6.20:1 | 5.63:1 | 6.49:1 | 5.85:1 | 5.52:1 | 5.94:1 |
| Escuro / Padrão | 11.85:1 | 5.91:1 | 5.85:1 | 8.61:1 | 5.67:1 | 6.18:1 | 7.07:1 |
| Claro / Alto contraste | 21.00:1 | 14.11:1 | 9.22:1 | 10.84:1 | 7.29:1 | 7.35:1 | 8.86:1 |
| Escuro / Alto contraste | 19.03:1 | 13.71:1 | 10.11:1 | 13.48:1 | 10.05:1 | 13.01:1 | 13.87:1 |
| Claro / Preto no branco | 21.00:1 | 14.11:1 | 9.22:1 | 10.84:1 | 7.29:1 | 7.35:1 | 8.86:1 |
| Escuro / Preto no branco | 21.00:1 | 14.11:1 | 9.22:1 | 10.84:1 | 7.29:1 | 7.35:1 | 8.86:1 |
| Claro / Amarelo no preto | 17.72:1 | 17.07:1 | 14.67:1 | 19.56:1 | 10.05:1 | 13.01:1 | 13.87:1 |
| Escuro / Amarelo no preto | 17.72:1 | 17.07:1 | 14.67:1 | 19.56:1 | 10.05:1 | 13.01:1 | 13.87:1 |

Nos temas padrão, por exemplo, texto principal é `#1E293B` sobre branco e `#F1F1F1` sobre `#2F2F2F`. Texto secundário é `#52627A` sobre branco e `#B8B8B8` sobre `#383838`. Contornos funcionais dos campos usam o token secundário; foco usa primário. Cabeçalhos, aviso de erro e borda de logout corrigidos não atenuam texto funcional com opacidade. Cores e estados semânticos continuam acompanhados de rótulos/ícones.

O esquema preto no branco usa a mesma paleta clara de alto contraste em ambos os temas. Amarelo no preto usa a mesma paleta escura amarela em ambos. “Alto contraste” acompanha a escolha claro/escuro; “Padrão” preserva os temas e também atende à solicitação nativa de alto contraste do sistema. Todos os oito pares de tema/modo foram calculados.

## Matriz e evidência automatizada

| Dimensão | Cobertura executada |
|---|---|
| Viewports lógicas | 320 × 640, 360 × 740, 390 × 844, 640 × 320 e 1280 × 800. Telas auxiliares também em 320/1280 × 900. |
| Texto | App 100/150/200%; sistema 200% com app 100%; sistema 150% com app 150% = 225%. Curva não linear e composição 400% verificadas no nível do escalador. |
| Aparência | Claro/escuro padrão, alto contraste claro/escuro, preto no branco, amarelo no preto; preferência nativa de alto contraste. Serifa, letras e linhas aumentadas em cenários de risco. |
| Painel | Quinze combinações de cinco viewports × 100/150/200%, mais guidelines claro/escuro normal/alto contraste. Fechar permanece acessível. |
| Estado | Campos digitados, respostas do questionário, Navigator e controlador de rota preservados ao alterar leitura. Falha de armazenamento e retry explícitos. |
| Interação | Eventos de toque/drag, tap fora do botão, Tab/Shift+Tab, Enter/Espaço, Escape/Voltar, setas e direções por botões. Insets de teclado e resize simulados. |
| Regressão | Suíte Flutter inteira, incluindo mapas 04–06/Sprint 1/Sprint 2, rotas 07–08, acessibilidade 09–12, contribuições, questionário 13–15 e Cards 17–19. |

Essa seleção cobre riscos e regressões, não o produto cartesiano de todas as telas × escalas × esquemas × plataformas. Resultados finais, ambiente e Quality Gate estão em [INSTRUCOES_APLICACAO.txt](../INSTRUCOES_APLICACAO.txt). Backend foi validado sem mudança de fonte ou migration nova.

## Capturas

Renderizações dos widgets reais, com fontes locais reais e fixtures fictícias; pixel ratio 2. Não são capturas de uma sessão manual em Chrome ou Android. O mapa usa tiles de teste offline e não comprova GPS, cobertura geográfica ou serviço externo.

| Arquivo em `docs/capturas/cards_20_23/` | Cenário lógico |
|---|---|
| `painel_claro_inicio.png` | 390 × 844, 100%, controles iniciais. |
| `painel_claro_posicao_redefinicao.png` | Mesmo painel rolado até alternativas de movimento/redefinição. |
| `painel_escuro_200_serifa.png` | 390 × 844, alto contraste escuro, serifa, 200%; Fechar fora da rolagem. |
| `cadastro_150_360px.png` | 360 × 740, 150%, campos e conteúdo rolável. |
| `detalhes_amarelo_150_sem_foto.png` | 390 × 844, amarelo no preto, serifa, 150%, imagem ausente identificada. |
| `salvos_200_320px.png` | 320 × 640, alto contraste, 200%, header e lista em uma rolagem. |
| `mapa_horizontal_150_offline.png` | 640 × 320, 150%, busca/atribuição/centralização, status por ação e navegação inferior. |

## Roteiro manual ainda pendente

1. Executar no Chrome com backend de desenvolvimento e dados fictícios. Redimensionar para as cinco viewports; repetir a seleção de fluxos com 100/150/200%, claro/escuro e cada esquema de cores. Abrir teclado virtual em dispositivo/DevTools quando disponível.
2. Usar leitor da web (por exemplo NVDA com Chrome) e TalkBack em Android. Conferir uma leitura por controle, papel de link, nota/quantidade, ausência/placeholder, selecionado/desabilitado e mensagens de erro/carregamento. Verificar mapa pela alternativa em lista.
3. Percorrer Tab/Shift+Tab, foco visível, Enter/Espaço, Escape e Voltar. Abrir e fechar painel, dropdown, filtros e questionário; conferir foco inicial/retorno sem alcançar controles cobertos.
4. Arrastar com toque e mouse para posições intermediárias. Confirmar que soltar não abre. Clicar/rolar fora do círculo, girar a tela, abrir teclado e redimensionar. Usar direções por toque/clique, setas com foco e Restaurar posição.
5. Ajustar tamanho, fonte, cores, letras, linhas, links e decoração; reabrir o app na mesma origem para confirmar persistência. Ocultar botão e voltar por Configurações. Redefinir leitura e confirmar idioma/tema/posição/visibilidade e dados de conta preservados.
6. Manter formulário e questionário preenchidos enquanto altera ajustes. Iniciar uma rota autorizada e ajustar leitura sem criar outra sessão. Confirmar ações do mapa/detalhes, filtros, Salvos e histórico.
7. Em Android com SDK/dispositivo, executar build/APK, TalkBack, teclado, rotação e configurações nativas de texto/alto contraste. Executar também o job PostgreSQL 16 do Quality Gate para os quatro testes de concorrência.

Chrome/Android/leitores de tela não estavam disponíveis para essa rodada manual. O build web e os testes nativos de widget têm resultados próprios; não os substituem. Não se declara conformidade completa com WCAG nem encerramento automático dos aceites manuais dos cards.

## Referências oficiais consultadas

- Flutter: [acessibilidade](https://docs.flutter.dev/ui/accessibility), [testes](https://docs.flutter.dev/ui/accessibility/accessibility-testing), [foco](https://docs.flutter.dev/ui/interactivity/focus), [TextScaler](https://api.flutter.dev/flutter/painting/TextScaler-class.html), [showDialog](https://api.flutter.dev/flutter/material/showDialog.html).
- W3C WCAG 2.2: [contraste mínimo](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [redimensionar texto](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html), [espaçamento](https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html), [alternativa ao arraste](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html).

Nenhum card do Trello foi criado, alterado ou marcado concluído. Nenhuma mensagem foi enviada. Preparação de branch, integração e publicação não fazem parte desta entrega local.
