# Manifesto de Qualidade — AcessoJá

**Projeto:** AcessoJá — Plataforma de Acessibilidade Urbana  
**Stack:** Python 3.12 / Django 5.1 / Django REST Framework  
**Versão:** 1.0 | **Data:** Junho/2025

---

## 1. Analisador Estático (Linter)

| Ferramenta | Versão | Finalidade |
|---|---|---|
| **Flake8** | ≥ 7.x | Conformidade PEP 8, erros de sintaxe e importações não utilizadas |
| **flake8-django** | plugin | Regras específicas para projetos Django |

**Configuração:** arquivo `.flake8` na raiz do repositório com `max-line-length = 120` e exclusão de pastas `migrations/`.

---

## 2. Suíte de Testes Automatizados

| Ferramenta | Finalidade |
|---|---|
| **pytest** | Runner principal de testes |
| **pytest-django** | Integração com o ORM e fixtures do Django |
| **pytest-cov** | Relatório de cobertura de código |

**Módulos cobertos:** `locais`, `avaliacao`, `modal_avaliacao`, `usuarios`, `acessoja`, `contribuicoes`.

---

## 3. Threshold de Cobertura de Testes

| Métrica | Valor Mínimo |
|---|---|
| **Cobertura global de linhas** | **80%** |
| Cobertura de branches (desvios) | 70% |

> O limite de 80% segue a recomendação padrão de SQA para aplicações CRUD/REST (Bernardo et al., 2024).  
> Em caso de introdução de componentes probabilísticos (ex: recomendação de locais por ML), o threshold será recalibrado para **60%** conforme orientação acadêmica.

**Falha de build:** qualquer Pull Request que reduza a cobertura abaixo do threshold será **bloqueado automaticamente** pelo Quality Gate definido em `.github/workflows/quality-gate.yml`.

---

*Este documento é um artefato vivo e deve ser atualizado a cada sprint conforme a equipe evolui os critérios de qualidade.*

## Validações da evolução do mapa e contribuições

O CI mantém os checks Django, migrations, flake8 e cobertura, agora com
`--cov-fail-under=80` alinhado ao limite deste documento. Também valida OpenAPI,
Flutter analyze/test, build web e APK debug. Um job PostgreSQL 16 executa o teste
de concorrência com transações reais e participa do check final Quality Gate.

Para rodar esse teste localmente, configure DATABASE_URL para um PostgreSQL de
teste com permissão de criar banco e execute:

```bash
pytest -q contribuicoes/test_contributions.py -k postgresql_concurrent
```

Em SQLite ele é explicitamente ignorado: SQLite não prova o bloqueio de linha
usado em produção. Resultados desta entrega e comandos que não puderam ser
executados estão em INSTRUCOES_APLICACAO.txt. A análise sintática de Dart não
substitui flutter analyze, flutter test ou a compilação.

## Cards 01–03 — contribuições e Central Avaliar

As regressões de integridade, reconciliação e migração de histórico ficam em
`contribuicoes/test_integrity.py` e `contribuicoes/test_activity_migration.py`.
O job PostgreSQL agora seleciona todos os testes `postgresql_concurrent` em
`contribuicoes`, incluindo criação duplicada, conclusão simultânea de pesquisa,
exclusão versus processamento antigo e leitura coerente do resumo.

`frontend/test/contributions_central_test.dart` inclui falhas parciais, paginação,
respostas atrasadas, feedback confirmado, teclado, semântica, estados vazios e
matriz de larguras 320/360/390/800/1280 com escalas 1/1,5/2 nos temas claro e escuro.
Inclui as guidelines Flutter de alvos, rótulos e contraste. A suíte do frontend
permanece exigida no CI; os comandos de cobertura e os limites não foram reduzidos.

Resultados comprovados e pendências de execução estão em `INSTRUCOES_APLICACAO.txt`.


## Cards 35–37

Django atualizado para 5.2.18 com DRF/Djoser compatíveis; gate de cobertura
continua em 80%, sem novas omissões. Testes de recuperação/privacidade usam contas
sintéticas, relógio controlado e e-mail em memória. O job PostgreSQL inclui
confirmações/exclusões concorrentes e dump/restore com supressão e smoke sintético;
o job Redis inclui orçamento de segurança entre processos independentes.
Não contar skipped de PostgreSQL como aprovados em SQLite. Flutter continua com
analyze, suíte inteira, Web e tentativa APK; SDK ausente não equivale a build aprovado.
Resultados e matriz de aceite: docs/EVIDENCIAS_SEGURANCA.md.
