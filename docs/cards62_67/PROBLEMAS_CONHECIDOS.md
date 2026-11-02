# Problemas conhecidos e limitações

- PostgreSQL real, Redis/CI remoto do delta, Android físico, Chrome móvel real e homologação humana com leitor de tela não foram executados. Os critérios correspondentes permanecem pendentes.
- A colisão do botão flutuante com a busca observada em tela pequena/200% foi corrigida e tem teste de geometria e validação no navegador. Se o recorte disponível não comportar o botão sem cobrir um controle, ele é ocultado temporariamente; a entrada de acessibilidade em Configurações permanece. O posicionamento automático não regrava a posição salva. T094 ainda requer aparelhos, orientação/temas e inspeção manual completos.
- O laboratório novo usa ações na árvore semântica Flutter, incluindo element.click(); não comprova hit testing humano de todos os controles. O laboratório de rotas inclui gesto de ponteiro real na abertura externa. Emulação de viewport não substitui aparelho.
- Os mapas de fundo, Overpass, geocoder e provedor externo de rotas/Google não foram homologados ao vivo. Falhas 503/429 do provedor local indisponível são intencionais no laboratório; o mapa sem tiles nas capturas não representa aprovação do provedor.
- A descoberta é limitada e serializa o recorte elegível no servidor para ordenar/versionar. As medidas SQLite não certificam desempenho PostgreSQL/produção. Refinar área/filtros ao atingir limites; não anunciar cobertura completa em fonte indisponível.
- Reverter a migration remove subcategoria e não recupera classificação manual ao reaplicar. Relações antigas foram verificadas em SQLite; migração PostgreSQL ainda deve ser comprovada.
- Datas ausentes permanecem ausentes, informações não são certificações e escolhas pessoais não são scores públicos. Nenhum ponto/recompensa novo foi introduzido.

MATRIZ_CENARIOS registra também cláusulas de cenários sem comprovação integral. Não usar os totais das suítes ou os 45 passos de navegador como aprovação dos 106 cenários.
