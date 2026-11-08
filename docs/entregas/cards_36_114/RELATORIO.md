# Cards 36 e 114 — navegação e sugestões

## Escopo executado

Esta entrega foi feita sobre a branch `feature/cards-32-115-design-stadia-fixes`, no HEAD `f633b60`. O worktree já possuía alterações e arquivos não rastreados de outras entregas; eles não foram descartados nem incorporados ao escopo.

Foram implementados:

- troca de destino principal sem interromper silenciosamente a navegação ativa;
- sugestões carregadas pela descoberta paginada existente;
- preferências explícitas privadas carregadas pelo endpoint derivado da sessão;
- ranking determinístico com desempate por nota real, nome e identidade estável;
- explicações baseadas somente em recursos confirmados e avaliações existentes;
- remoção do histórico de visitas como inferência de necessidade de acessibilidade;
- remoção de status de funcionamento e distância legados do cartão de recomendação;
- rejeição de identidade enviada por query string no endpoint privado de visitas;
- registro de visita sem enviar `nome_usuario` no corpo, preservando a sessão como autoridade.

## Arquivos principais

- `frontend/lib/screens/main_screen.dart`
- `frontend/lib/screens/sugestoes_screen.dart`
- `frontend/lib/services/recommendation_engine.dart`
- `frontend/lib/services/places_service.dart`
- `locais/views.py`
- `locais/test_discovery_cards.py`
- `frontend/test/recommendation_engine_test.dart`

## Limitações

Esta etapa não certifica o Quality Gate completo, Android físico, Chrome E2E ou homologação visual. Os comandos Flutter executados no ambiente não produziram saída e foram interrompidos; os diagnósticos do editor não apontaram erros nos arquivos alterados.
