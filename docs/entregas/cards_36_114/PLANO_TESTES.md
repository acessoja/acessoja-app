# Plano de testes

1. `flutter test test/recommendation_engine_test.dart`
2. `flutter analyze` nos arquivos Flutter alterados.
3. `pytest locais/test_discovery_cards.py::test_visit_identity_cannot_be_selected_by_query_parameter`.
4. Regressão dos testes de descoberta, privacidade, rotas e favoritos.
5. Quality Gate completo: Django check, migrations check, schema, pytest, Flutter analyze/test/build web/build APK.
6. Homologação Chrome/Android das jornadas de sugestões, detalhes, favorito, avaliação, mapa e rota.

Os itens 4–6 dependem de uma execução Flutter/ambiente completo e ainda não foram certificados nesta sessão.
