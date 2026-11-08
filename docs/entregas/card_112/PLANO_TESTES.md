# Plano de testes — Card 112

- Unitário: payload com locais internos/externos, acentos, endereço ausente,
  coordenadas inválidas, `NaN`, `Infinity`, zero, negativos e campos privados.
- Serviço: sucesso, cancelamento, indisponibilidade, exceção, cópia e falha de
  cópia com gateways falsos.
- Widget: detalhes, painel do mapa, Semantics, tooltip, estados e retorno.
- Regressão: mapa, favoritos, Explorar, Sugestões, rotas, temas e leitura.
- Web: Chrome com Web Share API, sem API, cópia, permissões, teclado e 200%.
- Android: seletor nativo, retorno, cópia, rota ativa e TalkBack em dispositivo.

O Android físico e a homologação Chrome devem ser executados separadamente;
compilar não será considerado prova desses cenários.
