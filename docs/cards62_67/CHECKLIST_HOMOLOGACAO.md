# Checklist de homologação

Código pronto para revisão; os itens pendentes impedem homologação integral dos cards. Registrar responsável, data, dispositivo/build/API e evidência sanitizada ao executar cada item. Não transformar uma etapa planejada em aprovação.

| Plataforma/verificação | Estado | Roteiro / resultado esperado |
|---|---|---|
|Chrome desktop Linux automatizado|Executado nos laboratórios, dentro do escopo dos relatórios|Visitante e conta; três modos; paginação; perfil salvo/reaplicar; pai/filho e legado; logout/troca com resposta atrasada; painel/rotas.|
|Web, conta A/B e privacidade|Automação parcial executada|Conferir rede/histórico/referrer ao compartilhar e voltar; nenhuma escolha pessoal/token fora do canal privado; concluir todas as cláusulas T075–T080.|
|Web, teclado humano|Pendente|Tab/Shift+Tab/Enter/Escape em modos, expansão de pais/filhos, chips, resultados e painel; verificar foco de retorno e alternativa ao arraste.|
|Web, leitor de tela humano|Pendente|Ler nomes/estados/grupos/quantidades; anúncios sem repetição; recurso importante oculto no compacto continua anunciável. T093/T101.|
|Chrome em celular real|Pendente|Identificar aparelho/SO/Chrome; teclado virtual, toque, orientação, rolagem, filtros/painel, texto 200%, temas e retorno de foco. T100.|
|Android físico, APK|Bloqueado neste ambiente|Preparar Android SDK e build na máquina apropriada; instalar em aparelho real. Registrar modelo/SO/build/API. Nenhum APK foi produzido aqui.|
|Android físico, fluxo de negócio|Pendente|Executar T096–T099 e T105: prefs off por padrão; priorizar/all/any; filhos; foto/avaliação/favorito/rota; Back e contexto preservados.|
|Android, TalkBack e escala|Pendente|T102: modos e filhos, background/retorno, Back, texto 200%, rede perdida/restaurada, sessão alterada; registrar leitura e foco reais.|
|PT/EN integral no navegador e Android|Pendente|Comparar rótulos, semântica, erros e estados, mantendo IDs e consultas; widgets e regressões automatizados são complementares.|
|PostgreSQL real descartável|Bloqueado neste ambiente|Executar o job atual com novos testes discovery_integrated/category_migration, JSON/projeção e migrations forward/reverse/reapply. Não usar skip/SQLite como aprovação.|
|Redis e CI remoto do delta|Pendente|Executar jobs atuais no commit que vier a ser autorizado; anexar run/job e cobertura. Nenhum push/commit foi realizado aqui.|
|Regressão integrada combinada|Parcial|Completar T105 com preferência/filtro → detalhe → avaliação/foto/favorito → Google Maps/rota → retorno, incluindo dados/pontos/histórico e aparelho nativo.|

Comando PostgreSQL em ambiente de teste já configurado: `pytest -q contribuicoes favoritos locais usuarios acessoja evidencias midia modal_avaliacao -k 'postgresql_concurrent or postgresql_restore or catalog or discovery_integrated or category_migration'`. Confirmar conexão PostgreSQL real antes de executar. A coleta local selecionou 152 testes, mas não os executou nesse banco.

O runtime só mapeia UID 0; postgres/initdb e Android SDK/adb não estavam disponíveis. Não foram contornadas as restrições de execução do PostgreSQL. O package mantém a exigência do job, sem reduzir cobertura nem ocultar testes.
