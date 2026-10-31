# Fotografias de avaliações — Cards 42 e 43

Revisão final: 28/10/2026 (America/Sao_Paulo).

Preparado em 27/10/2026. Base: `develop` e4a8db02dd4aa8a77fe9dfea9c3f0ffb62d280ef. Resultados e limites da homologação estão em EVIDENCIAS_CARD_46.md.

## Diagnóstico e integração

A base tinha avaliações, questionário versionado, denúncia de avaliações/evidências e moderação auditada dos Cards 35–41. Não havia upload persistente nem galeria de fotos da avaliação. As imagens ilustrativas do catálogo não foram convertidas em evidências. O novo app `midia` reutiliza autor, revisão, revogação, privacidade, moderação e transporte HTTP existentes.

No editor existente, fotos são opcionais. A avaliação salva primeiro pelo serviço original; só depois, com seu ID e revisão reais, abre o gerenciador de fotografias. Se o envio falhar, a avaliação permanece salva. O detalhe do local abre a galeria pública; a lista de avaliações abre a galeria daquela avaliação e permite gerenciar as próprias fotos. Não há avaliação/nota fictícia e nenhuma foto certifica acessibilidade.

## Dados, revisão e estados

- `ImageAsset`: UUID, titular, finalidade, chaves privadas geradas pelo servidor, dimensões, MIME `image/jpeg`, tamanho/hash e estado preparing/ready/retired.
- `ReviewPhoto`: identidade estável ligada à avaliação e ao titular, revisão atual e exclusão lógica.
- `PhotoRevision`: identidade imutável da imagem/contexto, data de submissão do servidor, asset, descrição de 10–500 caracteres e estado pending/approved/rejected. A submissão não comprova data da fotografia ou da visita.
- `ImageOperation`: identidade fornecida pelo cliente, assinatura de conteúdo/campos, reserva de até 120 segundos, resultado e estado processing/committed/failed. O resultado committed significa escrita concluída, não aprovação pública.
- `ImageDecision`: aprovação/rejeição inicial ou decorrente de denúncia, moderador, motivo e versão, sem necessidade de denúncia fictícia. Trilha imutável, exceto anonimização/retenção autorizada.
- `ImageCleanup`: fila persistente de remoção física recuperável.

Substituir arquivo ou mudar descrição cria outra `PhotoRevision` pendente; não move a foto de avaliação. Uma edição comum do questionário/comentário não apaga a foto: sua visibilidade continua condicionada à avaliação atual/válida. Arquivamento, invalidação, exclusão ou privacidade retiram a leitura pública em todas as variantes. O titular pode consultar/remover as próprias fotos pendentes, rejeitadas ou de uma avaliação arquivada; novos anexos exigem avaliação atual e válida. Ter `is_staff` isoladamente não permite moderar.

## API real

Prefixo `/api/`; token no header `Authorization: Token …`. Escritas, avatar e consulta de operações exigem autenticação; nunca há token em URL. Leituras públicas continuam verificando a elegibilidade a cada requisição.

| Método e rota | Entrada | Resultado |
| --- | --- | --- |
| POST `midia/fotos/enviar/` | multipart: file, operation_id UUID, review_id, review_revision UUID, description; substituição adiciona photo_id e expected_revision | 201 committed ou 202 processing, operation_id, photo_id, revision, can_retry |
| GET `midia/fotos/?review_id=…` | Uma avaliação; página de 20 | Fotos públicas e pendências autorizadas do titular/moderador |
| GET `midia/fotos/?local_id=…` | Um local; página de 20 | Somente fotos públicas; não combina os dois filtros |
| GET `midia/fotos/{UUID}/` | Foto | Estado, contexto, envio, IDs, dimensões/MIME, URLs relativas e capacidades |
| PATCH `midia/fotos/{UUID}/` | JSON operation_id, expected_revision, description | Nova revisão pendente do contexto, mesmo arquivo processado |
| DELETE `midia/fotos/{UUID}/` | JSON operation_id, expected_revision | Retirada lógica e operação confirmada; limpeza persistente |
| GET `midia/operacoes/{operation_id}/` | UUID próprio | Estado real; operação de outra conta é 404 |
| GET/HEAD `midia/arquivos/{asset_UUID}/{image ou thumb}/` | Sem query string | JPEG processado somente se autorizado; original/variante arbitrária é 404 |

O schema gerado e validado está em `docs/reports/cards_42_46/openapi.yaml`. Campos desconhecidos e multipart com campos repetidos são recusados. Autoria vem exclusivamente de request.user. Referências de revisão são obrigatórias nas escritas; o cliente precisa atualizar e confirmar de novo diante de 409.

| Status | Significado |
| --- | --- |
| 400 | Campos/contexto inválidos, limite de cinco fotos, filtro inválido |
| 401 | Credencial ausente, expirada ou revogada |
| 403 | Permissão insuficiente |
| 404 | Alvo ausente ou não disponível àquela pessoa |
| 409 | Revisão/operação mudou, outro envio ativo ou identidade usada com outro conteúdo |
| 413 | Arquivo acima de 5 MiB ou corpo acima de 6.000.000 bytes |
| 422 | Decodificação/formato/dimensões/tempo de processamento inválidos |
| 429 | Limite temporário de uso; observar Retry-After |
| 503 | Capacidade de processamento ou gravação indisponível; consultar operação |

A mesma identidade+conteúdo devolve o recibo anterior antes de exigir a versão atual, sem restaurar conteúdo antigo. Reutilizá-la com outro corpo/arquivo retorna 409. Upload de um arquivo por requisição, uma operação ativa por conta, reserva sob bloqueio do autor e limite de cinco fotos também no banco. Decodificação e escrita dos derivados ocorrem fora da transação; a finalização revalida a credencial e bloqueia autor antes da avaliação. Não há pontos por envio, aprovação, denúncia, remoção ou retry.

## Moderação e denúncias

Admin → Mídia → Fotografias → Analisar imagem. Exige login de staff e permissão efetiva `evidencias.moderate_content` (ou superusuário ativo), decisão versionada e justificativa de 10–1.000 caracteres. A imagem privada no formulário usa autenticação de sessão same origin. A aprovação inicial registra `ImageDecision`, sem protocolo fictício.

A interface de denúncia existente recebe photo_id e a revisão exibida no endpoint de denúncias dos Cards 40/41. Somente fotografia aprovada/publicável de outra pessoa pode ser denunciada. Duplicidade continua controlada pelo serviço existente; o denunciante não aparece na galeria, no autor ou no protocolo de terceiros. A fila existente recebe as denúncias de fotos; invalidar retira a imagem daquela revisão e registra o vínculo entre as trilhas. Se houve substituição, a denúncia antiga não invalida a nova imagem. Retry/decisões concorrentes usam os bloqueios e versões existentes e não criam pontos ou efeitos repetidos.

## Interface e acessibilidade

Seletor compartilhado image_picker: arquivo/galeria ou câmera quando disponível; o cancelamento não é erro de rede. JPEG, PNG ou WebP estático até 5 MiB. HEIC/HEIF é recusado com orientação para exportar para JPEG/PNG. A prévia é local e explicitamente ainda não enviada. Cada foto exige contexto útil, sem descrição automática; a tela orienta evitar pessoas, documentos e dados pessoais.

A fila sequencial mostra selecionada, enviando, recebida/aguardando análise, processing, failed ou resultado incerto. Não simula porcentagem. A tentativa confirmada libera seus bytes; retry reutiliza a operação apenas dos arquivos não confirmados. Falha com resultado incerto exige consultar a operação; cancelar a sequência interrompe os próximos envios e não promete desfazer o que já chegou. Ao sair durante envio, há aviso e as identidades ficam disponíveis para consulta ao retornar.

SharedPreferences guarda apenas IDs de operações e contexto do seletor por conta/avaliação e prazo; não armazena senha/token, arquivo bruto ou caminho pessoal. Logout/troca de conta limpa a apresentação e invalida respostas tardias. A recuperação Android via retrieveLostData é explícita, vinculada à conta/alvo original e limitada a 24 horas; não envia automaticamente. Se os bytes se perderam após encerramento do processo, consultar a operação/galeria antes de selecionar novamente.

Miniaturas sob demanda têm altura estável; o visualizador carrega a versão maior e tem descrição, anterior/próxima, ampliar/reduzir, fechar, Escape/setas e retorno do foco à origem. Usa bytes autenticados, sem depender de Image.network/estratégia HTML para arquivos privados. Texto 200%, tela estreita, teclado e anúncios de resultados são verificados por widgets; leitor de tela e dispositivos físicos exigem a homologação pendente registrada.
