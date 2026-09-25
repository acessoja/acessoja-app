import 'dart:convert';
import 'app_http.dart';
import '../config.dart';

/// Resultado de uma tentativa de login.
class LoginResult {
  final bool success;
  final Map<String, dynamic>? user;
  final String? message;

  const LoginResult({required this.success, this.user, this.message});
}

/// Resultado do envio de uma avaliação de acessibilidade.
class SubmitEvaluationResult {
  final bool success;
  final String? message;

  const SubmitEvaluationResult({required this.success, this.message});
}

/// Abstração das chamadas HTTP usadas pelas telas de login e de avaliação.
///
/// Permite que as telas recebam uma implementação real ([HttpApiService])
/// em produção e uma implementação mockada nos testes de widget, sem que
/// `flutter test` precise de um backend Django em execução.
abstract class ApiService {
  Future<LoginResult> login({required String nome, required String password});

  Future<List<dynamic>> fetchEvaluations({required dynamic localId});

  Future<SubmitEvaluationResult> submitEvaluation({
    required dynamic localId,
    required String userName,
    required String pergunta1,
    required String pergunta2,
    required String pergunta3,
    required String pergunta4,
    required int estrelas,
    required String comentario,
  });
}

/// Implementação real do [ApiService], usada em produção.
///
/// O comportamento aqui é o mesmo que já existia diretamente dentro das
/// telas (mesmos endpoints, mesmo formato de corpo/resposta).
class HttpApiService implements ApiService {
  @override
  Future<LoginResult> login({
    required String nome,
    required String password,
  }) async {
    final response = await AppHttp.post(
      Uri.parse('${Config.baseUrl}/api/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nome': nome, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['status'] == 'success') {
        return LoginResult(success: true, user: data['user']);
      }
      return const LoginResult(
        success: false,
        message: 'invalid_credentials',
      );
    } else if (response.statusCode == 401) {
      return const LoginResult(
        success: false,
        message: 'invalid_credentials',
      );
    }
    return const LoginResult(
      success: false,
      message: 'connection_error',
    );
  }

  @override
  Future<List<dynamic>> fetchEvaluations({required dynamic localId}) async {
    final response = await AppHttp.get(Uri.parse(
      '${Config.baseUrl}/api/avaliacoes/modal-avaliacoes/?local_id=$localId',
    ));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    }
    throw StateError('evaluation_load_failed');
  }

  @override
  Future<SubmitEvaluationResult> submitEvaluation({
    required dynamic localId,
    required String userName,
    required String pergunta1,
    required String pergunta2,
    required String pergunta3,
    required String pergunta4,
    required int estrelas,
    required String comentario,
  }) async {
    final response = await AppHttp.post(
      Uri.parse('${Config.baseUrl}/api/avaliacoes/modal-avaliacoes/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'local': localId,
        'nome_usuario': userName,
        'pergunta_1': pergunta1,
        'pergunta_2': pergunta2,
        'pergunta_3': pergunta3,
        'pergunta_4': pergunta4,
        'estrelas': estrelas,
        'comentario': comentario,
      }),
    );

    if (response.statusCode == 201) {
      return const SubmitEvaluationResult(success: true);
    }
    return const SubmitEvaluationResult(
      success: false,
      message: 'evaluation_error',
    );
  }
}
