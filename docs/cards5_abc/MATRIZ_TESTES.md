# Matriz de testes — Cards 5A/5B/5C

## Backend — executado nesta sessão

Com `DATABASE_URL` apontando para SQLite temporário isolado:

- Migration limpa, `manage.py check`, `makemigrations --check --dry-run`, OpenAPI (`spectacular --fail-on-warn`) e Flake8 passaram.
- A execução integral inicial terminou com **780 passed, 30 skipped, 21 subtests passed e 3 failed**; cobertura medida: **84,41%**. As falhas eram testes de migrations históricas que recuavam `evidencias`/`locais` sem recuar `contribuicoes.0003_report_reward`, dependente dos schemas mais novos. Os alvos históricos foram corrigidos para `contribuicoes.0002_activity_context`.
- Após essa correção, a suíte focalizada passou: **57 passed, 3 skipped em 77,43 s**. O módulo `contribuicoes/test_contributions.py` passou novamente com **33 passed, 2 skipped em 44,65 s**.
- A suíte integral pós-correção passou: **784 passed, 31 skipped, 21 subtests passed em 633,10 s**; cobertura **84,37%**, acima do mínimo de 80%. O log dessa execução é `evidencias\pytest-full-postfix.log`.

Cobertura relevante:

- denúncia procedente, denunciante elegível mais antigo e protocolo mais novo analisado primeiro;
- falha durante gravação do ledger reverte decisão e invalidação; retry e repetição do `operation_id` não duplicam pontos;
- denunciante sem avaliação própria mantém os 5 pontos após reconciliação; a descoberta padrão do comando inclui beneficiários que só existem em atribuições, cobrindo dry-run, aplicação e repetição idempotente;
- segundo alvo no mesmo local não concede outro bônus ao mesmo usuário;
- API privada mostra o estado da própria recompensa sem expor campos de moderação;
- anulação por fraude `+5/-5`, restauração `+5` e repetições sem novos deltas;
- dry-run sem gravação e reparo convergente do evento/atividade ausentes;
- decisões pendentes/não efetivas e denúncia de foto não geram recompensa;
- denúncia própria/inativa é ignorada, fingerprint conflitante é rejeitado e correção posterior não retira bônus;
- integridade e questionário legado continuam cobertos pelos módulos existentes.

Os skips incluem os testes que exigem PostgreSQL para validar locks/migrations, inclusive a regressão de criação concorrente do evento de recompensa. O skip não é contado como aprovação; a concorrência PostgreSQL permanece não demonstrada.

## Flutter — executado nesta sessão

```text
flutter test
1.086 testes aprovados
```

Também passaram `flutter analyze` completo, build Web e build APK debug, em Flutter 3.47.5. Os dois arquivos focados relacionados aos Cards 5A–5C tiveram **76 testes aprovados**; cobrem ajuda, histórico, tela privada de denúncias, carregamento/erro/refresh, teclado, escalas até 200% e larguras de telefone/tablet/desktop.

## Homologação Web — executada

Usando API local em `127.0.0.1:8001`, build Web em `127.0.0.1:7358` e somente o SQLite isolado:

- Dados sintéticos percorreram zero pontos, invalidação efetiva com +5, revogação com −5 e restauração com +5.
- O painel e o histórico mostraram operações distintas; a tela privada mostrou estado do protocolo e da recompensa, inclusive após revogação.
- Viewports 929×1500 e 390×844; sem overflow horizontal em 390 px. Snapshot semântico e ativação de controle por Tab/Enter foram verificados.
- A consulta de locais externos retornou 504; não impediu acesso ao local sintético da base local. O browser também registrou um 401 da tentativa inicial com usuário incorreto durante a preparação, não uma falha no fluxo válido.

## Não executado / bloqueado

- **Adiado por decisão da equipe:** os testes de concorrência PostgreSQL 16 (transações/locks) não foram executados nesta etapa. A validação real permanece pendente; SQLite não a substitui.
- TalkBack em dispositivo Android físico: não executado.

Os comandos exatos, ambientes e limites estão em [VALIDACAO.md](./VALIDACAO.md).
