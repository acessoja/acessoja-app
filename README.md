# ♿ AcessoJá — tecnologia para acessibilidade

[![Quality Gate](https://github.com/acessoja/acessoja-app/actions/workflows/quality-gate.yml/badge.svg)](https://github.com/acessoja/acessoja-app/actions/workflows/quality-gate.yml)

![Logotipo AcessoJá](frontend/assets/logo.png)

O **AcessoJá** é um aplicativo Flutter com API Django/DRF para buscar locais, consultar informações de acessibilidade, avaliar e contribuir com o catálogo comunitário. A origem de dados externos e o estado da validação de cada informação devem ser apresentados de forma distinguível.

## Tecnologias e requisitos

- **App:** Flutter e Dart; versão Flutter `3.47.4` definida em [`frontend/.fvmrc`](frontend/.fvmrc).
- **API:** Python 3.12, Django, Django REST Framework; dependências em [`backend/requirements.txt`](backend/requirements.txt).
- **Banco:** SQLite no ambiente inicial de desenvolvimento; PostgreSQL disponível conforme configuração de ambiente. Não versionar `.env`.
- **Android:** Java 17; conferir SDK e NDK nas configurações do projeto.

## Início rápido (Windows / PowerShell)

```powershell
git clone https://github.com/acessoja/acessoja-app.git
cd acessoja-app
.\scripts\setup-dev.ps1
.\scripts\dev.ps1
```

**Sem Android SDK/NDK?** O script `setup-dev.ps1` verifica também a cadeia Android; para usar somente o Chrome, siga o [procedimento Web-only no PowerShell](docs/desenvolvimento/INICIO_RAPIDO.md#alternativa-windows--somente-flutter-webchrome-sem-android-sdk).

Para execução manual, Linux, emulador Android, dispositivo físico, carga do catálogo de Anápolis e resolução de erros, consulte o [guia de execução](docs/desenvolvimento/INICIO_RAPIDO.md). Confira sua branch antes de desenvolver; mudanças passam por PR para `develop`.

## Onde encontrar informações

- [Índice central da documentação](docs/README.md) — produto, áreas técnicas, histórico e evidências.
- [Como contribuir](CONTRIBUTING.md) — branches, commits e PRs.
- [Qualidade e checks atuais](QUALITY.md) — controles exigidos no pipeline.
- [Auditoria e origem da reorganização](docs/organizacao/DIAGNOSTICO_DOCUMENTAL.md) — decisões e limites.
- [Documentação da API](docs/desenvolvimento/INICIO_RAPIDO.md#api-openapi) — Swagger, ReDoc e schema.

## Documentação histórica

A versão anterior do README, que incluía explicações longas por sprint/card, permanece no [GitHub no commit anterior à revisão documental](https://github.com/acessoja/acessoja-app/blob/46e55d4e5ddd65a25ff630f72b0389fbf80547c5/README.md). As especificações e evidências originais continuam preservadas nos caminhos identificados no [inventário](docs/organizacao/INVENTARIO_DOCUMENTAL.md). O estado descrito por uma entrega antiga não substitui a verificação na versão atual.

## Compatibilidade com seções do README antigo

Os títulos originais foram mantidos como pontos de entrada para reduzir a quebra de links por âncora. O conteúdo extenso permanece no [README histórico](https://github.com/acessoja/acessoja-app/blob/46e55d4e5ddd65a25ff630f72b0389fbf80547c5/README.md). A compatibilidade com links externos ainda depende de revisão de seus consumidores.

### 🚀 Funcionalidades Principais

Consulte [a documentação relacionada](docs/README.md#documentação-por-área).

### 🛠️ Tecnologias Utilizadas

Consulte [a documentação relacionada](#tecnologias-e-requisitos).

### **Frontend**

Consulte [a documentação relacionada](frontend/README.md).

### **Backend**

Consulte [a documentação relacionada](backend/requirements.txt).

### 🛠️ Configuração e Instalação

Consulte [a documentação relacionada](docs/desenvolvimento/INICIO_RAPIDO.md).

### **Versões oficiais**

Consulte [a documentação relacionada](frontend/.fvmrc).

### **Primeira instalação**

Consulte [a documentação relacionada](docs/desenvolvimento/INICIO_RAPIDO.md).

### **Executar o projeto**

Consulte [a documentação relacionada](docs/desenvolvimento/INICIO_RAPIDO.md).

### **Passo a passo manual**

Consulte [a documentação relacionada](docs/desenvolvimento/INICIO_RAPIDO.md#execução-manual-a-partir-da-raiz).

#### **1. Backend**

Consulte as [instruções de backend](docs/desenvolvimento/INICIO_RAPIDO.md#execução-manual-a-partir-da-raiz), com configuração do `.env`, dependências e migrations.

#### **2. Frontend**

Consulte as [instruções de Flutter](docs/desenvolvimento/INICIO_RAPIDO.md#execução-manual-a-partir-da-raiz) e o [modo somente Web](docs/desenvolvimento/INICIO_RAPIDO.md#alternativa-windows--somente-flutter-webchrome-sem-android-sdk).

### **Por que `10.0.2.2` e não `localhost`?**

Consulte [a documentação relacionada](docs/desenvolvimento/INICIO_RAPIDO.md#android-e-endereço-da-api).

### **Problemas comuns**

Consulte [a documentação relacionada](docs/desenvolvimento/INICIO_RAPIDO.md#problemas-conhecidos-e-diagnóstico).

### 🏗️ Arquitetura do Sistema

Consulte [a documentação relacionada](docs/README.md#documentação-por-área).

### 📖 Documentação da API

Consulte [a documentação relacionada](docs/desenvolvimento/INICIO_RAPIDO.md#api-openapi).

### 👥 Contribuindo

Consulte [a documentação relacionada](CONTRIBUTING.md).

### 📝 Licença

Consulte [a documentação relacionada](https://github.com/acessoja/acessoja-app/blob/46e55d4e5ddd65a25ff630f72b0389fbf80547c5/README.md).

### Sprint 2 — descoberta de estabelecimentos externos

Consulte [a documentação relacionada](docs/CATALOGO_OSM_ANAPOLIS.md).

### Funcionamento

Consulte [a documentação relacionada](docs/MAPA_BUSCA_ROTAS_CARDS_28_33.md).

### Configuração e limites dos serviços

Consulte [a documentação relacionada](https://github.com/acessoja/acessoja-app/blob/46e55d4e5ddd65a25ff630f72b0389fbf80547c5/README.md).

### Deduplicação e compatibilidade

Consulte [a documentação relacionada](docs/CATALOGO_OSM_ANAPOLIS.md).

### Validação da entrega

Consulte [evidências históricas do Card 51](docs/EVIDENCIAS_CARD_51.md).

### Mapa inteligente, navegação e Avaliar

Consulte [a documentação relacionada](docs/MAPA_BUSCA_ROTAS_CARDS_28_33.md).

### Autenticação e pontos

Consulte [a documentação relacionada](docs/CONTRIBUICOES.md).

### API e validação

Consulte [a documentação relacionada](QUALITY.md).

### Contribuições e Central Avaliar — revisão dos Cards 01–03

Consulte [documentos históricos de contribuições](docs/CONTRIBUICOES.md).

### Cards 17–19 — Acessibilidade, teclado e histórico de rotas

Consulte [instruções históricas dos Cards 17–19](docs/INSTRUCOES_CARDS_17_19.txt).

### Cards 20–23 — Leitura, acessibilidade e layouts adaptáveis

Consulte [a documentação relacionada](docs/AUDITORIA_ACESSIBILIDADE_20_23.md).

### Favoritos privados e Locais Salvos — Cards 24–27

Consulte [a documentação relacionada](docs/FAVORITOS_E_LOCAIS_SALVOS.md).

### Cards 28–33 — Busca, pontos no mapa e cadastro

Consulte [a documentação relacionada](docs/MAPA_BUSCA_ROTAS_CARDS_28_33.md).

### Correção do mapa após os Cards 28–33

Consulte [a documentação relacionada](INSTRUCOES_CORRECAO_MAPA_28_33.md).

### Card 34 — Catálogo municipal OSM

Consulte [a documentação relacionada](docs/CATALOGO_OSM_ANAPOLIS.md).

### Cards 35–37: recuperação, meus dados e homologação

Consulte [a documentação relacionada](docs/ESPECIFICACAO_CARDS_35_36_37.md).

### Cards 38–41: fontes, atualidade, denúncias e moderação

Consulte [a documentação relacionada](docs/PROVENIENCIA_ACESSIBILIDADE_CARDS_38_39.md).

### Fotografias e avatar — Cards 42 a 46 (27/10/2026)

Consulte [a documentação relacionada](docs/EVIDENCIAS_CARD_46.md).

### Cards 47–51: avaliações, fotos e relatos parciais

Consulte [a documentação relacionada](docs/EVIDENCIAS_CARD_51.md).

### Cards 52–58 — painel integrado ao mapa

Consulte [a documentação relacionada](docs/cards52_58/IMPLEMENTACAO.md).
