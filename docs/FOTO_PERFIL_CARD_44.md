# Foto de perfil — Card 44

Revisão final: 28/10/2026 (America/Sao_Paulo).

Preparado em 27/10/2026. O defeito foi confirmado na base: `_pickPhoto` retornava fora da Web e dependia de input HTML. O frontend anunciava 5 MiB enquanto a rota antiga limitava uma string base64 a 2.000.000 caracteres.

## Correção e compatibilidade

Informações pessoais agora abre `AvatarEditorScreen`, usando o mesmo `ImageSelectionService` e processador do Card 45. Galeria/arquivo está disponível e câmera é uma alternativa quando o sistema a oferece. XFile/bytes substituem o seletor HTML; código compartilhado não importa dart:io/dart:html. O alvo Android já usa minSdk do Flutter 3.47.4 (24); nenhuma permissão ampla de arquivos/câmera foi adicionada. INTERNET permanece no manifesto principal. Não existe alvo iOS nativo neste repositório; Safari/iPhone Web não foi homologado.

Selecionar mostra uma prévia e exige confirmação explícita. Cancelar ou receber arquivo inválido conserva a foto anterior. Remover tem confirmação, versão esperada e operação identificada. Se a rede não permite saber o resultado, consultar a operação; a remoção não é repetida silenciosamente. Reiniciar a tela consulta o avatar do servidor e operações lembradas, não considera a prévia como persistência.

O campo legado `foto_perfil` continua sendo base64, nunca uma URL. A migration adiciona avatar_asset e avatar_version sem apagar avatares antigos. Novas gravações processam o arquivo e mantêm também a miniatura JPEG de até 160 px em base64 para os leitores legados. Informações pessoais, configurações e o mapa/menu principal continuam lendo esse contrato e recebem notificação de atualização. Logout troca o contexto/geração e remove provedores de imagem da conta; respostas antigas são descartadas.

## Contratos e caminhos de escrita

| Método/rota | Corpo | Comportamento |
| --- | --- | --- |
| GET `/api/usuarios/me/avatar/` | — | version UUID, has_avatar, foto_perfil base64 e URLs relativas privadas, quando houver asset |
| PUT mesma rota | multipart file, operation_id UUID, expected_version UUID | Processa arquivo; 200 committed ou 202 processing |
| DELETE mesma rota | JSON operation_id, expected_version | Remove referência/avatar base64, muda versão e agenda limpeza do arquivo anterior |
| POST `/api/usuarios/foto/` legado | JSON foto_perfil base64 | Continua compatível, mas valida/decodifica pelo mesmo processador, até 2.000.000 caracteres; retry identificado pelo conteúdo |
| PUT perfil genérico | Campos de perfil existentes | Não permite foto_perfil, avatar_asset ou avatar_version; não contorna validação |

Os endpoints novos usam 5 MiB de arquivo e corpo multipart até 6.000.000 bytes. O limite legado em caracteres é intencionalmente separado; a interface nova não o usa. GET/HEAD das URLs de avatar exigem o titular autenticado e a referência atual. Um avatar substituído/retirado deixa de ser entregue antes da limpeza física. Não há fetch de URLs arbitrárias, exposição estática ou token na URL.

O controle de versão impede que substituição/remoção antiga restaure uma foto. Mesma operação confirmada devolve seu recibo; não reaplica uma mudança ultrapassada. Uma falha de processamento/storage conserva a referência e o base64 anteriores. Duas substituições de uma mesma versão não devem ambas concluir: há teste com conexões PostgreSQL independentes, ainda pendente de execução local em PostgreSQL.

## Validação e retomada

Testes reais de API/processing/storage cobrem avatar válido, compatibilidade do campo, rota legada real, bloqueio no perfil genérico, remoção, concorrência de versão, credencial revogada após processamento e falhas de storage/banco. Widgets cobrem cancelar, confirmar, falhar, remover e reconciliar resultado incerto sem repetir DELETE. A evidência real do navegador e os resultados gerais estão em EVIDENCIAS_CARD_46.md.

No aparelho real ainda é necessário selecionar da galeria/câmera, negar permissão, recuperar atividade destruída e comprovar troca Android → Chrome e Chrome → Android, com login da mesma conta e consulta posterior. Nenhum teste de widget, emulação de largura ou segundo contexto desktop substitui essa comprovação.
