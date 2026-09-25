# Conteúdo de Seus direitos

Revisão editorial: 25/09/2026. Escopo: legislação federal brasileira sobre pessoas com deficiência; o tema transporte também contempla mobilidade reduzida. Não há catálogo de regras estaduais/municipais nem concessão automática de benefícios.

Os resumos em português e inglês estão nos arquivos `lib/l10n/app_*.arb`. O catálogo tipado, as fontes e os artigos estão em `lib/data/rights_catalog.dart`; as categorias abrem rotas próprias em `lib/screens/rights_screen.dart`. O conteúdo pode ser lido offline; os links oficiais precisam de conexão e abrem no navegador. As fontes são em português. Há 17 cartões temáticos; uma mesma norma pode aparecer em mais de uma categoria.

## Fontes conferidas

- [Lei nº 13.146/2015 — texto oficial do Planalto](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2015/lei/l13146.htm): transporte, art. 46; edificações de uso coletivo, arts. 56–57; SUS, art. 18; educação, arts. 27–28; trabalho, art. 34; cultura/lazer, arts. 42–44.
- [Disque 100 — serviço oficial do Governo Federal](https://www.gov.br/pt-br/servicos/denunciar-violacao-de-direitos-humanos): denúncias, gratuidade, funcionamento e canais acessíveis.
- [Lei nº 10.048/2000](https://www.planalto.gov.br/ccivil_03/leis/l10048.htm): arts. 1–3 e 5, atendimento prioritário, assentos e veículos.
- [Lei nº 8.899/1994](https://www.planalto.gov.br/ccivil_03/leis/l8899.htm): art. 1, passe livre interestadual com comprovação de carência; não é gratuidade universal.
- [Resolução ANAC nº 280/2013](https://www.anac.gov.br/assuntos/legislacao/legislacao-1/resolucoes/resolucoes-2013/resolucao-no-280-de-11-07-2013): assistência especial no transporte aéreo; condições e prazos devem ser consultados na norma.
- [Lei nº 10.098/2000](https://www.planalto.gov.br/ccivil_03/leis/l10098.htm): arts. 1 e 11, remoção de barreiras e requisitos para edifícios.
- [Lei nº 10.436/2002](https://www.planalto.gov.br/ccivil_03/leis/2002/l10436.htm): arts. 1–4, Libras, saúde e formação educacional.
- [Lei nº 9.394/1996](https://www.planalto.gov.br/ccivil_03/leis/l9394.htm): arts. 58–60, educação especial e apoios.
- [Lei nº 8.213/1991](https://www.planalto.gov.br/ccivil_03/leis/l8213cons.htm): art. 93, cotas conforme número de empregados.
- [Lei nº 12.933/2013](https://www.planalto.gov.br/ccivil_03/_ato2011-2014/2013/lei/l12933.htm): art. 1, §§ 8 e 10, meia-entrada e condições.
- [Coleção de legislação do MDHC](https://www.gov.br/mdh/pt-br/navegue-por-temas/pessoa-com-deficiencia/publicacoes/legislacao): destino do link “Consultar mais leis de acessibilidade”.

O cartão de estacionamento remete ao art. 47 da LBI. A lista contém normas nacionais selecionadas, não todas as leis aplicáveis. Regras locais não são inferidas a partir da localização do usuário.

## Atualizações

Antes de modificar um resumo, conferir o texto vigente, condições, público abrangido e dispositivos alterados ou revogados. Atualizar ambas as traduções, os artigos e a data editorial apenas depois dessa revisão. Não substituir a data por uma data calculada em tempo de execução. Não anunciar gratuidade de transporte, isenções ou benefícios sem verificar seus requisitos e âmbito territorial.

Executar `flutter gen-l10n`, `flutter analyze` e `flutter test`. Os testes da página cobrem navegação por categoria e retorno, links, falha do navegador, acesso sem login e fonte ampliada em cada categoria.
