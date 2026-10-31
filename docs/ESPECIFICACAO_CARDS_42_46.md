# Adendo ao Documento de Especificação — Cards 42–46

Revisão final: 28/10/2026 (America/Sao_Paulo).

27/10/2026. Base develop e4a8db02dd4aa8a77fe9dfea9c3f0ffb62d280ef. Este é um adendo aplicável às seções indicadas: não foi fornecida uma versão editável consolidada para substituir silenciosamente o documento oficial.

| Seção | Atualização |
| --- | --- |
| 20 — requisitos/funcionalidades | Fotos opcionais da avaliação com contexto, revisão/moderação, galeria autorizada; troca/remoção de avatar Android/Web; nenhum ponto/afirmação de acessibilidade por imagem |
| 22 — dados/arquitetura | Midia.ImageAsset/ReviewPhoto/PhotoRevision/ImageOperation/ImageDecision/ImageCleanup; Usuario.avatar_asset/avatar_version; denúncia de revisão de foto; migrations preservam legado |
| 24 — segurança/privacidade/operação | Decodificação limitada, derivados JPEG sem metadados, storage privado persistente, autorização GET/HEAD, isolamento de sessão/cache, fila de limpeza, exportação/anonimização, backup com janela sem escritores |
| 25 — testes e qualidade | API/storage/processing e widgets executados; gate de cobertura preservado em 80%; execução Web e limitações em EVIDENCIAS_CARD_46.md; Android físico/Chrome móvel/tecnologia assistiva/PostgreSQL não podem ser declarados aprovados por mocks |

Planejamento: Cards 42 (#121), 43 (#122), 44 (#131), 45 (#132) e 46 (#133) integram um pacote. Código fica pronto para revisão/aplicação; aceite integrado requer a matriz física e ensaio PostgreSQL/backup ainda pendentes. Manter cartões, atribuições e status existentes; nenhum commit, push, PR, publicação ou mensagem automática foi feito.

Histórico: pacote 42–46 de 27/10/2026 adiciona imagens reais e corrige o avatar, preservando arquitetura, traduções, questionário, catálogo, favoritos, rotas, privacidade, evidências e pontuação dos Cards anteriores. Contratos e evidências estão nos quatro documentos específicos e reports/cards_42_46. As falhas corrigidas e limitações de execução são registradas sem converter compatibilidade teórica em homologação.
