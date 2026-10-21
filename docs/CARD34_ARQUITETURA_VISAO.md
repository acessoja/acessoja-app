# Atualização proposta da arquitetura e visão — Card 34

Complemento textual aos PDFs históricos de visão/arquitetura fornecidos. Os
originais foram preservados. Este texto registra implementação e limites;
não afirma revisão ou aprovação acadêmica.

## Seção de arquitetura: descoberta municipal

A implementação atual usa Flutter e Django 5.1/DRF. A API consulta um catálogo
municipal persistido, separado de Local, questionário, avaliações, favoritos e
histórico de rotas. Um comando administrativo lê arquivo OSM e limite IBGE,
prepara observações e publica um lote. Não há download na migration, inicialização
do servidor, abertura do mapa ou por requisição de descoberta.

Um escopo municipal referencia uma edição ativa e sua revisão. Cada POI tem
identidade OSM estável e vínculo opcional a Local. As observações da fonte são
versionadas por lote, com hashes/datas e indicação de cobertura. Publicação e
reativação alteram a edição da fonte; dados comunitários são preservados.

Flutter consulta a base por área/páginas e mantém limites e contagens visíveis.
Overpass serve como complemento opcional. Geocodificação, tiles e rotas continuam
serviços independentes com suas próprias políticas/disponibilidade. O catálogo
não é navegação offline nem comprovação de acessibilidade do percurso.

## Seção de visão: alcance e jornada

O usuário pode explorar POIs OSM de Anápolis sem fornecer GPS. Pode consultar
prévia, detalhes e planejar rota sem criar cadastro. Uma confirmação explícita
e autenticada associa/cria Local para avaliação/favorito. As correções comunitárias
têm prioridade de apresentação, mantendo a proveniência externa separada.

O catálogo representa objetos elegíveis da extração, com possíveis lacunas,
duplicatas e campos desconhecidos. Não promete todos os estabelecimentos reais.
Cadastro manual dos ausentes permanece disponível. Os resultados de validação,
limitações e homologações pendentes constam em RELATORIO_CARD34.md.
