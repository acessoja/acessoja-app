# Adendo técnico da especificação — Cards 35–37

Base: develop `03f9722752aba4d452867e49e0dde89d8be031f9`; Card 34 preservado.
Rastreabilidade: Card 35/Trello #124, Card 36/#125, Card 37/#126.
Este adendo prepara a incorporação à especificação oficial. A versão editável
com as seções 20/22/24/25 não foi fornecida; não se declara esse documento oficial
alterado nem aprovado.

## Alterações a incorporar

| Seção solicitada | Conteúdo técnico para incorporação | Evidência/artefato |
| --- | --- | --- |
| 20 | Fluxos de recuperação sem login, link temporário Web, retorno ao login; acesso a Privacidade e meus dados, escolhas separadas, exportação e exclusão com senha/checkbox. Manter telas/tema/leitura existentes. | Telas `password_recovery_screen`/`personal_data_screen`; testes Flutter de contrato, navegação e acessibilidade. |
| 22 | Contratos das rotas Djoser/customizadas, token DRF preservado; consentimento por finalidade/versão/data; limite/exportação, transação e revogação; novas entidades e SET_NULL legado. | Schema OpenAPI gerado e `SEGURANCA_CONTA_PRIVACIDADE.md`; migrations usuarios/0006 e avaliacao/0003. |
| 24 | Homologação restrita: Django 5.2, SMTP, HTTPS/proxy, PostgreSQL, Redis, logs mínimos, prontidão, backups e supressão antes da restauração. | `HOMOLOGACAO_SEGURA.md`, deploy/staging e scripts operacionais. |
| 25 | Matriz R01–R09/P01–P09/I01–I05/U01/G01; separar automação local, serviço real local, CI preparado e validação externa pendente. Gate de 80% mantido. | `EVIDENCIAS_SEGURANCA.md` e docs/reports/cards_35_37. |

Os números acima são os pontos de incorporação pedidos, sem inventar os títulos
originais dessas seções. A equipe deve conferir a versão oficial antes de editar.

## Requisitos e limites de rastreabilidade

Mantidas as referências do pedido: RF-006, RNF-002, RNF-005, RNF-006 e RNE-007.
O Documento de Visão de 3º período fornecido tem uma numeração própria: RF006
trata cadastro, RNF002 trata desempenho/carregamento e RNF005 escalabilidade;
não se deve renumerar silenciosamente a especificação para encaixar estes cards.
As referências RNF006/RNE007 do pedido precisam de conciliação na versão oficial.
Os controles implementados preservam cadastro e oferecem segurança/privacidade,
mas não demonstram por si só meta de tempo de carregamento ou disponibilidade.

## Planejamento e aceite

| Card | Entrega de desenvolvimento | Etapa ainda necessária para aceite real |
| --- | --- | --- |
| 35 — Recuperação | Serviço único, fila/retries, link Django/Djoser, política/limites/revogação, interface Web e testes. | E-mail entregue em conta sintética pelo SMTP real; navegador móvel; concorrência PostgreSQL na instalação/CI. |
| 36 — Dados pessoais | Inventário, decisões específicas/legado honesto, JSON próprio, download Web/bridge Android, exclusão e diário recuperável. | Controlador ratificar bases/prazos/contato; exercício em PostgreSQL/restauração e salvamento Android real. |
| 37 — Homologação | Perfil restrito, Compose/proxy/volumes, logs/probe, backup/restauração e laboratório TLS local. | **Preparado para implantação; validação externa pendente**: domínio/certificado, persistência, operação/alerta, cópia externa, restauração comprovada. |

Não há atualização automática de Trello, commit, push, PR ou publicação.

## Histórico de versão

| Data | Versão | Alteração |
| --- | --- | --- |
| 21/10/2026 | Cards 35–37 / aviso 2026-10-21 | Recuperação, dados pessoais, migrações e infraestrutura de homologação. Pacote delta para revisão/aplicação; resultados efetivamente executados e pendências ficam no relatório de evidências. |

## Revisão antes do piloto

Confirmar responsáveis de privacidade/operação e contatos; conciliar referências
com especificação oficial; testar SMTP e domínio reais; executar job PostgreSQL
com clientes compatíveis e restauração isolada; validar Web/Android e leitor de
tela; aprovar política de dados/retenção e ativar cópias/rotação/alertas. Cada
pendência deve receber evidência antes de atualizar o aceite correspondente.
