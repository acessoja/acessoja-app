# Card 174 — painel de acessibilidade

## Auditoria inicial

- Branch local: `feature/card-173-central-moderacao-redesign`. O repositório já continha mudanças locais de moderação, backend, templates e artefatos; esta entrega não os altera.
- `main`, `develop` e `origin/develop` não apontavam para o mesmo commit na auditoria. Nenhuma operação Git de escrita foi executada.
- O painel anterior estava em `frontend/lib/widgets/accessibility_panel.dart`; o botão flutuante está em `accessibility_host.dart` e foi preservado.
- As sete preferências de leitura, a visibilidade e a posição do botão permanecem em `AppPreferences` e `SharedPreferences`.

## Implementação e critérios

| Critério | Resultado |
| --- | --- |
| Painel compacto e avançado | Um modal com seção expansível, inicialmente recolhida |
| Contrastes | Quatro cartões exclusivos com texto, borda e indicador de seleção |
| Tamanho, fonte e espaçamentos | Controles reais ligados às preferências existentes |
| Links e ilustrações | Switches ligados às regras atuais; fotos e mapas permanecem visíveis |
| Posição e visibilidade do botão | Controles avançados; visibilidade recuperável nas Configurações |
| Prévia | Usa o tema de leitura, a escala de texto herdada e o contraste atual |
| Restaurar padrões | Usa `resetReading`; posição e visibilidade independentes |
| Teclado e foco | Mantidos o fechamento por Escape, foco inicial e retorno ao acionador |
| Movimento reduzido | Nenhuma opção fictícia foi adicionada |

## Testes e evidências

- `flutter analyze`: sem problemas.
- `flutter test test/accessibility_panel_test.dart`: 32 testes aprovados.
- `flutter test`: 1.146 testes aprovados.
- Teste adicional cobre expansão, seleção dos quatro contrastes, fonte, espaçamento e restauração.
- `flutter build web --release`: compilação concluída. A aplicação compilada foi aberta no Chrome local com Playwright.
- Capturas reais: [desktop compacto](desktop_compacto.png), [desktop expandido](desktop_expandido.png), [mobile compacto](mobile_compacto.png), [mobile expandido](mobile_expandido.png), [alto contraste](alto_contraste.png), [preto e branco](preto_branco.png), [amarelo e preto](amarelo_preto.png), [tema escuro](tema_escuro.png) e [texto a 200%](texto_200.png).

## Comparação visual com a referência

| Elemento | Observação no Chrome |
| --- | --- |
| Cabeçalho e fechamento | Ícone em cartão azul, título/subtítulo e fechamento no canto superior |
| Tamanho do texto | Controle segmentado com valor central |
| Contrastes | Quatro cartões com representação de cor e seleção identificável |
| Links e ilustrações | Linhas com ícone, descrição e switch |
| Avançados | Expansão no mesmo modal com fonte e controles de espaçamento |
| Prévia e restauração | Presentes no fluxo rolável |

No mobile, os textos localizados existentes são mais longos que os do mockup; a prévia e a restauração ficam abaixo da dobra e são alcançadas por rolagem. A referência mostra o mapa ao fundo, mas a execução local ficou na tela de erro de sessão porque o backend não estava disponível. O botão flutuante continuou acessível nessa tela.

## Limitações e melhorias futuras

- Ainda falta captura de erro de persistência; esse estado foi validado em teste automatizado com armazenamento simulado. A captura amarela foi refeita após corrigir o rótulo e o indicador de seleção.
- A redução global de animações permanece como proposta de outro card.
