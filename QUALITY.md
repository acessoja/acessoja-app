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

**Módulos cobertos:** `locais`, `avaliacao`, `modal_avaliacao`, `usuarios`, `acessoja`.

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
