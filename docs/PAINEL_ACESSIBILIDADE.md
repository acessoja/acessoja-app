# Painel de acessibilidade — Cards 20–23

Entrega de 15/10/2026 (UTC). Correspondência do painel: Card 23 / [Trello #128](https://trello.com/c/U1U4Rdwl); fonte e contraste: Card 21 / [#25](https://trello.com/c/jnz37keo).

## Acesso e fonte de verdade

O botão circular de 56 × 56 pixels lógicos abre **Ajustes de acessibilidade**, antes ou depois do login. O mesmo painel aparece em **Configurações → Ajustes de acessibilidade** e em Configurações gerais. O atalho da barra de Configurações continua disponível quando a consulta do perfil falha. Não foi criada outra aba de navegação.

`AppPreferences`, `PreferencesScope`, `ChangeNotifier` e `SharedPreferences` existentes foram estendidos. Há uma única instância de preferências e um único painel. Os ajustes são locais ao dispositivo/origem do navegador, não pertencem à API nem acompanham a conta. Outro navegador, perfil do navegador ou origem/porta pode ter um armazenamento diferente. Limpar os dados do site remove essas preferências.

As preferências privadas dos recursos de acessibilidade dos estabelecimentos, filtros, consentimentos, histórico e dados de conta mantêm seus contratos anteriores. O painel de leitura não representa autorização de localização ou de coleta de histórico.

## Controles

| Controle | Padrão | Valores e efeito |
|---|---|---|
| Tamanho do texto | 100% | 100–200%, passos de 25 pontos percentuais. Multiplicador do aplicativo aplicado depois do escalador do sistema. Diminuir/aumentar ficam desabilitados nos limites; há redefinição individual. |
| Contraste e cores | Padrão do aplicativo | Padrão; alto contraste conforme claro/escuro; preto no branco; amarelo no preto. Esquemas completos, sem seletores independentes que permitam texto ilegível. Redefinição individual. |
| Tipo de fonte | Sem serifa — Roboto | Roboto ou DejaVu Serif, ambas incluídas no aplicativo. Redefinição individual. |
| Espaçamento entre letras | 0 px adicional | 0–3 pixels lógicos adicionais, passos de 0,5. Soma ao espaçamento original do estilo. Redefinição individual. |
| Altura de linha | 1,0× | 1,0–1,8×, passos de 0,1. Multiplica a altura original do texto, sem ampliar ícones. Redefinição individual. |
| Destacar links | Desligado | Acrescenta sublinhado e peso visual aos links reais de Direitos e à atribuição OpenStreetMap. Mantém destino, callback e papel semântico de link. |
| Ocultar imagens decorativas | Desligado | Oculta as ilustrações classificadas explicitamente no onboarding por `DecorativeArtwork`. Não filtra imagens globalmente. |
| Mostrar botão de acessibilidade | Ligado | Oculta/mostra apenas o botão móvel. Preferências e acesso por Configurações permanecem. |
| Botões direcionais | Posição atual | Cada toque/clique move 10% da extensão útil em um eixo, limitado à área válida. A alternativa funciona sem arrastar e sem teclado. |
| Restaurar posição | 75% horizontal / 25% vertical | Retorna à posição inicial, sem redefinir ajustes de leitura. |
| Redefinir ajustes de acessibilidade | — | Retorna os sete ajustes de leitura aos padrões. Não muda posição, visibilidade, idioma, tema independente, onboarding ou dados da conta. |

Ilustrações de onboarding são decorativas; mapas, marcadores, ícones de ação, diagramas e fotos dos locais continuam presentes. Fotos ausentes ou inválidas usam uma descrição de imagem indisponível, nunca um anúncio de fotografia real. Ocultar decoração não oculta esse conteúdo informativo.

## Escala do sistema e do aplicativo

`ReadingTextScaler` implementa `TextScaler`. Para cada tamanho original `f`, o tamanho efetivo é:

`escalaDoSistema.scale(f) × multiplicadorDoAplicativo`

A aplicação ocorre uma única vez no `builder` de `MyApp`. A curva original do sistema, inclusive não linear, é preservada. O getter legado é apenas uma estimativa para compatibilidade; os layouts usam `scale()`/`TextScaler`. Não há teto da escala do sistema, redução automática do texto nem `FittedBox` em textos. O `FittedBox` remanescente do onboarding dimensiona somente a ilustração.

Exemplos lineares: sistema 150% com app 150% resulta em 225%; sistema 200% com app 200% resulta em 400%. A suíte verifica matematicamente a composição 400% e uma curva não linear, além de layouts selecionados até 225%. Isso **não comprova todos os fluxos a 400%**. A matriz de layout principal cobre 100%, 150%, 200% e composição 225%.

Estilos herdados vêm de `readingTheme`, com as cores de texto principal e texto sobre primário dos tokens reais de cada esquema; alturas/espaçamentos explícitos de telas auditadas compõem os valores locais por `readingHeight`/`readingSpacing`. Campos, botões e listas crescem ou rolam. As cores personalizadas preservam a escolha independente de tema; voltar a “Padrão do aplicativo” a revela novamente. A solicitação de alto contraste do sistema também recebe temas claro/escuro próprios, sem gravar uma preferência nova.

## Movimento, barras e teclado

`AccessibilityHost` fica dentro da aplicação. Não usa permissão de overlay do sistema. Apenas a área do botão captura o gesto; mapa e rolagem fora dela continuam recebendo eventos.

- Arrastar permite qualquer posição válida, sem encaixe obrigatório em cantos. Soltar após arraste não abre o painel. Toque/clique abre.
- A posição é normalizada entre 0 e 1 em cada eixo. Não são salvas coordenadas absolutas de tela.
- A área útil considera SafeArea, margem de 12 px, diâmetro de 56 px e reserva inferior mínima de 92 px. `AccessibilityBottomBoundary` mede a barra inferior e o painel real de navegação, incluindo quebra de linhas.
- A posição inicial deixa a coluna direita de centralização do mapa livre a partir de 320 px. Ela pode ser ajustada pelo usuário; “Restaurar posição” recupera esse ponto.
- Redimensionamento e rotação recalculam a posição. O teclado virtual limita temporariamente a posição visual ao espaço acima dele; abrir/fechar teclado não grava outra posição.
- O arraste grava somente ao terminar, não a cada movimento. Cada operação de persistência escreve as três preferências locais em sequência; o teste contabiliza três gravações ao soltar.
- Com o botão focado, setas do teclado movem 24 pixels por acionamento. Não são atalhos globais e não interceptam setas de campos ou do mapa.

## Modal, semântica e foco

O painel é um diálogo de até 680 px de largura, com margem de 12 px. O botão Fechar permanece fora da lista rolável, inclusive com fonte grande. Conteúdo e título rolam; não se reduz a fonte para fazê-los caber.

O observador de rotas oculta o botão móvel durante modais, menus e a animação de fechamento, evitando um controle acionável por baixo do modal. Há proteção contra abertura duplicada. Tab/Shift+Tab percorrem o diálogo em circuito fechado; Enter/Espaço usam ações nativas; Escape e Voltar fecham. O foco retorna ao controle de origem quando ele continua visível. Ocultar o botão não devolve foco a um controle invisível. Nas páginas normais, o percurso de foco alcança o botão fora do Navigator.

O botão tem um único nome semântico localizado; o tooltip não o repete. Controles nativos anunciam valores, limites, seleção e desabilitação. A falha ao salvar aparece como mensagem de erro com ação **Tentar salvar novamente**.

## Persistência e falhas

| Chave | Conteúdo |
|---|---|
| `reading_preferences_v1` | JSON com `textSize`, `letterSpacing`, `lineHeight`, `contrast`, `serif`, `highlightLinks`, `hideDecorativeImages`. |
| `accessibility_button_visible_v1` | Booleano independente. Ausência mantém o botão visível. |
| `accessibility_button_position_v1` | JSON com `x` e `y` normalizados. Padrão `{x: 0.75, y: 0.25}`. |

As chaves anteriores `language`, `appearance` e `onboarding_completed` permanecem. Tipos incompatíveis, JSON inválido, enum desconhecido e números fora dos limites/NaN/infinito retornam ao padrão do campo. Não são interpretadas strings como booleanos verdadeiros. A posição recebida por interação é limitada à área válida.

As alterações aparecem imediatamente em memória. Gravações são serializadas para que mudanças rápidas não terminem em ordem inversa. Retorno `false` ou exceção do armazenamento gera estado de falha; a interface não anuncia sucesso fictício. “Tentar salvar novamente” persiste os valores atuais de leitura, posição e visibilidade. As três gravações não são uma transação atômica: após falha parcial e fechamento do navegador podem restar os últimos valores que efetivamente foram salvos. Os valores válidos são relidos normalmente na próxima abertura.

## Fontes e licenças

- **Roboto** regular, medium, bold e black: arquivos não modificados do conjunto de fontes do SDK Flutter usado na validação. Licença Apache 2.0 em `frontend/assets/fonts/LICENSE_Roboto.txt`. Fonte upstream: https://github.com/googlefonts/roboto.
- **DejaVu Serif** regular e bold: arquivos não modificados do pacote `fonts-dejavu-core`. Licença Bitstream Vera, com alterações DejaVu em domínio público, em `LICENSE_DejaVu.txt`. Upstream: https://dejavu-fonts.github.io/.
- Ambas estão registradas uma única vez em `pubspec.yaml`; não dependem de baixar fontes durante a leitura. Não foi adicionada biblioteca de estado nem de fontes remotas. O lockfile mantém as mesmas dependências.

A opção com serifa é uma escolha de apresentação, sem promessa de eficácia clínica ou tratamento de dislexia.

## Verificação e manutenção

Testes: `reading_preferences_test.dart`, `accessibility_panel_test.dart`, `reading_layouts_test.dart` e `place_media_accessibility_test.dart`. A suíte completa cobre também questionário, rotas, teclado, contribuições, Salvos e histórico anteriores. Resultados finais e comandos estão em [INSTRUCOES_APLICACAO.txt](../INSTRUCOES_APLICACAO.txt).

Relatório: [Auditoria dos Cards 20–23](AUDITORIA_ACESSIBILIDADE_20_23.md). Testes automatizados e renderizações de widgets não substituem leitor de tela real; o roteiro manual permanece indicado no relatório.
