# Auditoria inicial — Cards 62–67

Base consultada antes de qualquer alteração de código: `6684c06ee19a93ccb446c37fbd78c7be6755cb29` da main de acessoja/acessoja-app. Arquivo imutável e hashes individuais preservados em BASE.json e baseline.json. Esta cópia não possui checkout Git; a branch e alterações locais do computador Windows não são acessíveis. Nenhuma operação Git de escrita será realizada.

O prompt completo foi preservado em REQUISITOS.md (73 critérios; 106 cenários planejados). Os seis cards Trello foram consultados somente para leitura; nenhum status foi alterado. Documento de planejamento/testes consultado. Próxima numeração: 68.

| Card | Existente | Lacuna confirmada antes de editar |
|---|---|---|
|62|Preferências privadas; ação explícita; invalidadores de sessão; filtros imutáveis|A aplicação atual insere preferências no AND manual; não há priorização nem descoberta global consolidada.|
|63|Painel persistente; dez recursos/quatro grupos; fontes e histórico; ordenação por preferência|O agrupamento expandido desfaz prioridade global; aviso compacto só cobre divergência.|
|64|Testes de preferências/visibilidade/sessão e proteção de links públicos|Faltam transporte privado da busca aplicada, continuação vinculada à conta e testes dos novos modos.|
|65|Rascunho atômico, cancelar e ownership de toggles, filtros AND legados|Faltam três modos explícitos, OR, ordenação e independência dos blocos pessoal/manual.|
|66|Onze categorias; allowlist Overpass; catálogo municipal persistente|Não há subcategoria estruturada ou validação hierárquica; mapear somente tags reconhecidas sem inferir nomes.|
|67|Gates Flutter/Django, PostgreSQL/Redis e laboratórios de navegador|106 cenários são planejamento; nenhum resultado novo pode ser inferido de execuções antigas.|

Arquitetura auditada: locais/views.py, accessibility.py, discovery.py, models.py, serializers.py, catalog_views.py, catalog_models.py, services/{categories,accessibility,catalog_query,catalog_rules,catalog_import}.py; frontend models/services de descoberta e preferências, MainScreen, AccessibilityFilterPanel, ActiveDiscoveryFilters, ResourceInformationList e MapPlace. APIs de detalhe, confirmação e cadastro serão preservadas. A consulta atual pagina internos e OSM separadamente e MainScreen reordena a mistura por distância; isso impede ranking global correto.

Decisões: serviço consolidado reutilizando projeção pública autorizada; ranking antes da paginação; limite de trabalho explícito e resposta parcial quando necessário; continuação opaca, assinada, expirada e vinculada à consulta/sessão/versão. POST autenticado para snapshot pessoal, GET público para critérios manuais. Nenhuma preferência/score gravado em Local, avaliações, favoritos, contribuições ou pontos. Catálogo hierárquico central, contrato gerado para Flutter e migration aditiva segura para legados.

Ambiente a verificar: Flutter 3.47.4 conforme frontend/.fvmrc e CI; Python/Django 5.2.18; PostgreSQL real descartável; navegador real com Playwright Python como fallback. Não foi encontrado Playwright MCP entre as ferramentas disponíveis. Android físico, TalkBack/leitor real, aparelho Chrome e CI remoto não estão comprovados. Compilação não será tratada como teste de interface.

Referências primárias consultadas em 2026-11-01: docs.djangoproject.com/en/5.2/topics/pagination/; wiki.openstreetmap.org/wiki/Key:amenity; Key:shop; Key:healthcare. healthcare genérico não fornece subtipo hospital. Tags armazenadas em CatalogEntry são allowlisted; classificação será conservadora em conflitos.
