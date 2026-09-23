# Front-end: temas, idiomas e verificação

## Comportamento

- Tema claro, escuro (cinzas neutros) ou do dispositivo. A preferência é local.
- Português e inglês disponíveis antes do login e nas configurações. A escolha
  local não é perdida ao reabrir o aplicativo. Nas configurações de uma conta,
  a API existente continua recebendo `pt_BR` ou `en_US`.
- A troca de idioma não traduz nomes, endereços e comentários dos usuários.
- Navegação devolve pedidos de rota até o mapa; sair substitui a pilha por login.
- Falhas de carregamento oferecem nova tentativa. Falhas ao salvar preferências
  mantêm o valor anterior. Login/cadastro impedem envios simultâneos.
- Os mapas continuam usando a fonte original. Compartilhamento, favoritos
  sincronizados, recuperação de senha e login social não foram implementados.
- Rotas continuam sendo de carro. Não há validação de acessibilidade do trajeto.
- A semântica e os valores das perguntas de avaliação foram preservados. A
  divergência preexistente entre perguntas e flags precisa de revisão própria
  das regras de negócio. Permissões da API também não foram alteradas.

## Adicionar um idioma

1. Adicione `lib/l10n/app_<idioma>.arb` com as mesmas chaves de `app_pt.arb`.
2. Preserve placeholders e plurais ICU; traduza também labels semânticos e erros.
3. Rode `flutter gen-l10n` e acrescente a opção ao seletor e ao controlador
   `AppPreferences`. Mantenha explícita a conversão para os códigos aceitos
   atualmente pelo perfil no servidor; não envie códigos novos sem suporte.
4. Teste telas pequenas, fontes ampliadas, ambos os temas e todas as rotas.

Os arquivos em `lib/l10n/generated/` são gerados, não devem ser editados à mão.
Valores da API como `Sim`, `Não`, `Não sei`, `KM` e `Milha` não são textos de UI:
o questionário traduz a apresentação, mas mantém esses valores nas requisições.

## Desenvolvimento e validação

Validação desta implementação: Flutter 3.47.4 / Dart 3.13.3.

Resultado: 55 testes aprovados e build web JavaScript gerado. A análise estática
reportou 102 apontamentos informativos de estilo/depreciação, sem erros ou
warnings de código. O build Android não foi validado; a configuração Gradle
original foi preservada.

```sh
flutter pub get
flutter gen-l10n
flutter analyze --no-fatal-infos
flutter test
flutter build web
```

`test/frontend_regression_test.dart` usa HTTP simulado para testar falhas,
contratos, navegação, persistência e layouts. Não grava dados em um backend real.
`test/ui_preview_test.dart` gera imagens de revisão em `build/qa/`.

O cliente aceita `--dart-define=API_BASE_URL=<endereco>`; sem ele, mantém os
endereços locais anteriores. Isso não muda o servidor nem sua configuração.

Os testes de widgets não substituem a verificação em aparelhos reais de GPS,
permissões do sistema e upload de fotos pela web. A integração ao backend real
e leitores de tela em dispositivos também devem ser verificados antes de publicar.
