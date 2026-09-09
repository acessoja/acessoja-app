import 'package:mocktail/mocktail.dart';
import 'package:flutter_application_1/services/api_service.dart';

/// Mock de [ApiService] usado nos testes de widget, para que nenhuma
/// chamada HTTP real seja feita durante `flutter test`.
class MockApiService extends Mock implements ApiService {}
