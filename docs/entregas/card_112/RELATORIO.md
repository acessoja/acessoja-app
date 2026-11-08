# Card 112 — Compartilhamento seguro de estabelecimentos

## Escopo

Implementação Flutter de compartilhamento de informações públicas de um
`MapPlace`, sem nova API, deep link do AcessoJá ou serialização do objeto
completo. A branch auditada foi `feature/cards-36-114-navegacao-sugestoes`,
com 11 commits à frente e 2 atrás de `origin/develop`.

## Auditoria

O worktree já possuía alterações locais e arquivos não rastreados, incluindo
arquivos gerados e documentação de outros cards. Esses itens foram preservados.
O projeto já tinha `MapPlace` como adaptador canônico, `toMap()` com
coordenadas validadas, `url_launcher`, feedback por `SnackBar` e os fluxos de
detalhes de mapa, Explorar, Salvos e Sugestões. Não havia serviço de
compartilhamento nem uso de `Clipboard`.

## Implementação

- `PlaceSharePayloadBuilder` usa somente nome, endereço e latitude/longitude
  públicas já expostas por `MapPlace`.
- Coordenadas são finitas e limitadas aos intervalos geográficos; `0,0` é
  aceito e ausência/valor inválido não gera URL.
- Links são construídos com `Uri.https` para Google Maps.
- `PlaceShareService` separa payload puro, plataforma nativa e clipboard,
  permitindo testes sem navegador ou Android.
- `share_plus 11.1.0` foi escolhido por fornecer a API moderna sem exigir a
  atualização de AGP introduzida pela linha 12.x.
- O painel do mapa e as telas de detalhes exibem Compartilhar e Copiar
  informações. Quando a plataforma nativa informa indisponibilidade, o app
  tenta a cópia e informa o resultado real.

## Privacidade

O payload não serializa `MapPlace.data` e não inclui conta, token, sessão,
preferências de acessibilidade, GPS do usuário, origem de rota, histórico ou
dados de avaliação privada. O teste injeta esses campos no registro original e
confirma sua ausência no texto final.

## Limitações

Chrome com e sem Web Share API, Android físico, TalkBack, teclado, temas,
texto ampliado e builds completos ainda precisam de homologação. O botão do
Flutter não confirma entrega ao destinatário; o feedback se limita ao estado
retornado pela plataforma ou à cópia confirmada.
