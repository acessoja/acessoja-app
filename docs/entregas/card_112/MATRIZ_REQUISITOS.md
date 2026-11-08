# Matriz de requisitos — Card 112

| Critério | Implementação | Teste/evidência | Situação |
|---|---|---|---|
| CA112-01 Estabelecimento correto | Payload recebe o `MapPlace` selecionado | `place_share_service_test.dart` verifica identidade | Implementado; widgets pendentes |
| CA112-02 Link público válido | `Uri.https` e coordenadas do local | Teste de HTTPS, host e query | Implementado |
| CA112-03 Sem coordenadas | Nome/endereço sem URL geográfica | Teste de ausência de URL | Implementado |
| CA112-04 Fallback | `Clipboard` injetável e cópia automática quando indisponível | Teste de cópia | Implementado |
| CA112-05 Cancelamento/erro | Status distintos e mensagens sem sucesso falso | Teste de cancelamento/cópia; erro de UI pendente | Parcial |
| CA112-06 Privacidade | Lista explícita de getters públicos | Teste com campos privados inseridos | Implementado |
| CA112-07 Plataformas | `share_plus 11.1.0` suporta Android/Web | pub get; homologação manual pendente | Parcial |
| CA112-08 Navegação | Ação sobreposta ao painel/detalhes, sem alterar controllers | Inspeção estática; E2E pendente | Parcial |
