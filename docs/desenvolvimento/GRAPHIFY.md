# Graphify no AcessoJá

O projeto usa o Graphify para gerar um mapa local de relações entre código e
documentação. A integração é específica do projeto e não altera configurações
pessoais do Codex.

## Instalação

No PowerShell, a partir da raiz do repositório:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install graphifyy
.\.venv\Scripts\graphify.exe install --project --platform codex
```

O instalador mantém as instruções existentes em `AGENTS.md` e instala a skill
compartilhada em `.codex/skills/graphify/`. Em ambientes onde `graphify` já
está no `PATH`, o executável pode ser chamado diretamente.

## Uso

Depois da instalação, uma pergunta sobre a arquitetura deve consultar o grafo:

```powershell
.\.venv\Scripts\graphify.exe query "Como o fluxo de autenticação chega à API?"
```

Para atualizar o índice local após mudanças de código:

```powershell
.\.venv\Scripts\graphify.exe update .
```

O arquivo `.graphifyignore` exclui credenciais, bancos, backups, dados
privados, caches e temporários. Não forneça chaves de API para o Graphify e não
execute a análise contra produção.

## Versionamento

Devem ser versionados a skill em `.codex/skills/graphify/`, suas referências,
o `.graphifyignore`, este guia e o trecho Graphify já existente em `AGENTS.md`.
Os resultados em `graphify-out/` são derivados e específicos da cópia local;
por padrão, não devem ser publicados. Se a equipe decidir compartilhar um
snapshot do grafo, revise-o antes e publique somente `graph.json`/relatório
sem caminhos locais, segredos ou dados privados.

As sete skills AcessoJá (`acessoja-auditoria`, `acessoja-busca-codigo`,
`acessoja-debugging`, `acessoja-desenvolvimento`, `acessoja-handoff`,
`acessoja-qualidade` e `acessoja-seguranca`) atualmente vivem fora deste
repositório, em `.agents/skills/`. Elas não foram duplicadas: podem ser
compartilhadas futuramente sob `.codex/skills/` com os mesmos nomes, após
revisão humana de licença, conteúdo e precedência das instruções.
