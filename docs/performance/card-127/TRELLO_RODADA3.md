# Card 127 — atualização sugerida (Rodada 3)

## Concluído

- Corrigido o harness de autenticação: espera da estabilidade do formulário, preenchimento validado, clique por ponteiro dentro das bounds semânticas e confirmação explícita do POST/tela autenticada.
- Corrigida a confirmação do mapa: distingue marcador individual de cluster e exige que o botão esteja habilitado, no viewport e hit-testável. Ajustado apenas o fixture sintético para grade 5×5 com espaçamento de 0,006°.
- Executados apenas os cenários anteriormente falhos, com três repetições cada: autenticação/Sugestões e fluxo do mapa. 6/6 concluídas; login HTTP 200 em todas; marcador “Card127 Principal” utilizável em 3/3.
- Registrados p50/p95, condições, logs sanitizados e instruções de reprodução em CSV, JSON e SVG, além do relatório Markdown.
- Validados testes focados Python e Flutter e análise estática dos arquivos de instrumentação.

## Principais métricas

- Sugestões: tela → ação de rota, p50 408,9 ms / p95 456,7 ms (n=3).
- Mapa: pronto → marcador usável, p50 759,9 ms / p95 760,0 ms (n=3).
- Seleção → detalhe/preview, p50 494,9 ms / p95 501,0 ms (n=3).
- API local SQLite/WSGI: resposta integral p50/p95 49,6/116,4 ms em Sugestões (n=12); 35,3/137,9 ms no fluxo de mapa (n=36).

O intervalo “início da automação → ação” em Sugestões inclui espera/localização Playwright e não representa toque físico. As durações WSGI/SQLite não caracterizam PostgreSQL. Não comparar diretamente com Rodadas 1/2 por diferenças de protocolo e instrumentação.

## Bloqueio e próximo passo

Sem `DATABASE_URL` autorizada, não houve acesso ao serviço PostgreSQL local detectado nem benchmark PostgreSQL. Provisionar uma base isolada autorizada e acrescentar ao runner uma opção explícita de banco de teste com validação de host/base antes de migrations; então repetir a carga com configuração documentada. Nenhuma mudança funcional foi aplicada porque os dados atuais não comprovam gargalo de produto. Nenhum teste Android foi realizado, conforme escopo.

## Evidências

- [Relatório técnico](./RELATORIO.md)
- [Protocolo e reprodução](./README.md)
- [Pacote de resultados](../../../reports/performance/20261116T080000Z-r3-targeted-final/)
