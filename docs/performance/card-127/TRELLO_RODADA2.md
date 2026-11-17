# Card 127 — atualização para o Trello (Rodada 2)

## Resultado

Foi preparada instrumentação opt-in para medir os marcos internos de Sugestões e a recepção completa das respostas, além de uma bancada local reproduzível para API e fluxos Flutter Web. Não foram alteradas funcionalidades de produto.

## Evidências

- API: 1.500 requisições de listagem (100 por repetição; concorrência 1/10/25/50/100) e 75 requisições por rota em dez rotas adicionais. Todas concluíram com HTTP 200, sem erro/timeout. p95 mediano por concorrência: 108,3 / 613,6 / 1.846,1 / 3.135,7 / 6.144,0 ms, em SQLite sintético/WSGI local.
- Sugestões: tela até ação habilitada p50 181,8 ms (visitante), 283,6 ms (autenticado sem visitas, com preferências) e 366,4 ms (sem visitas/preferências), n=3 por perfil. Ranking p50 entre 1,8 e 3,4 ms. Atraso controlado de 750 ms na descoberta levou tela→ação de 181,8 para 928,4 ms.
- Mapa: lista p50 290,7 ms e seleção p50 460,0 ms, n=2. Marcador não ficou visível no viewport, sem métrica de tempo.
- Execução Web parcial: 27 observações concluídas e três timeouts na fase de autenticação; não foram inventados valores para essas falhas.

## Limitações e próximos passos

Os resultados descrevem somente SQLite, dados sintéticos, WSGI e Chrome headless local. PostgreSQL autorizado e Android físico não estavam disponíveis; os critérios literais CA127-01…08 também não acompanharam os arquivos acessíveis. Repetir em homologação com PostgreSQL isolado e massa sintética, coletar perfil Android, completar os três cenários de autenticação e obter os critérios do card antes de declarar aceite ou atribuir causas de produto.

Relatório e protocolo: [`RELATORIO.md`](./RELATORIO.md) e [`README.md`](./README.md). Resultados completos da rodada: [`20261115T225617Z-r2-30b7c3`](../../../reports/performance/20261115T225617Z-r2-30b7c3/). Evidência API original: [`20261115T221100Z-r2-7282db`](../../../reports/performance/20261115T221100Z-r2-7282db/).
