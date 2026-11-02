# Padrão de documentação — AcessoJá

**Card:** DOC-02 / Trello #159. **Idioma:** português brasileiro, termos técnicos explicados na primeira ocorrência. **Público:** equipe, avaliadores, colaboradores novos e mantenedores.

## Objetivo e organização

Cada página deve responder a uma pergunta: **o que é**, **como fazer**, **por que foi decidido** ou **o que ocorreu em uma entrega**. Use um H1, seções H2/H3, parágrafos curtos, datas `AAAA-MM-DD` quando comprovadas e links relativos ao repositório.

| Tipo de página | Conteúdo e tempo verbal | Fonte |
|---|---|---|
| Documentação vigente | Comportamento observado/contrato vigente, sem prometer o que não foi verificado | Código e API da versão referida |
| Procedimento | Passos reproduzíveis, sistema operacional e pré-requisitos | Scripts realmente existentes |
| Histórico / card | Contexto no momento da entrega, base, alterações e limitações | Relatórios e PRs atribuíveis |
| Evidência | Resultado com comando, ambiente, data e versão | Logs/JSON/prints originais, nunca reescritos |
| Especificação | Requisito planejado, critérios de aceite, decisões e riscos | Fonte aprovada pelo time |

## Terminologia consistente

- **Local:** ponto de interesse exibido ou cadastrado no projeto.
- **Local externo:** registro obtido de fonte externa; a origem não equivale à validação comunitária.
- **Recurso de acessibilidade:** atributo ou condição avaliada com resposta/estado documentado.
- **Avaliação:** registro de usuário; não é certificação de acessibilidade.
- **Evidência:** artefato ligado a um teste/decisão e à versão de execução.
- **Homologado:** aprovado conforme critérios documentados e evidência explícita.

## Exemplos concretos (antes e depois)

**Antes:** “Eu rodei os testes e ficou tudo ok.”

**Depois:** “Na base `[SHA]`, a suíte `[comando]` registrou `[resultado]` em `[data/ambiente]`, conforme `[link para log]`.”

**Antes:** “O Android foi validado” (com apenas screenshot Web).

**Depois:** “A interface foi inspecionada no navegador. A validação em dispositivo Android físico não consta das evidências desta entrega.”

**Antes:** “O agente não tinha acesso ao código, então ficou pendente.”

**Depois:** “Esta etapa foi registrada como não executada na entrega de `[data/base]`; permanece sem comprovação adicional nas fontes consultadas.”

## Estados e histórico

Use `Planejado`, `Implementado`, `Testado automaticamente`, `Inspecionado no navegador`, `Validado em Android físico`, `Homologado` ou `Não comprovado`, indicando data/versão. **Nunca** converta testes `NÃO EXECUTADOS`, `skipped` ou bloqueados em testes aprovados. Um documento antigo pode representar uma situação já corrigida; preserve o registro e referencie a correção datada.

## Comandos, links e nomes

- Separe trechos PowerShell (`powershell`) de Linux/macOS (`bash`). Não misture sintaxe de ativação de venv.
- Use crases para nomes de classe, caminhos e comandos; nunca transcreva credenciais, valores reais de `.env` ou dados pessoais.
- Prefira links relativos para documentos internos e URL do Trello/PR quando identificada.
- Não mude âncoras públicas sem redirecionamento ou atualização comprovada de referências.
- Não renomeie ou apague logs, JSON, capturas e YAML gerados em entregas anteriores durante revisão editorial.

## Revisão mínima

1. Confrontar trechos sobre versões, API e limites de CI com arquivos da base atual.
2. Verificar links relativos, imagens, títulos e histórico preservado.
3. Marcar fatos sem fonte como pendentes de verificação; não preenchê-los com suposições.
4. Documentar impacto em arquivos canônicos, manifestação de alterações, PR e critérios restantes.

Modelos: [`FUNCIONALIDADE.md`](modelos/FUNCIONALIDADE.md), [`PROCEDIMENTO.md`](modelos/PROCEDIMENTO.md), [`REGISTRO_CARD.md`](modelos/REGISTRO_CARD.md) e [`EVIDENCIA.md`](modelos/EVIDENCIA.md).
