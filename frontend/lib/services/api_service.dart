import 'package:flutter/foundation.dart';
import 'auth_session_controller.dart';
import 'dart:convert';
import 'app_http.dart';
import '../config.dart';
import 'contribution_service.dart';

/// Resultado de uma tentativa de login.
class LoginResult {
  final bool success;
  final Map<String, dynamic>? user;
  final String? message;
  final int? retryAfter;

  const LoginResult({
    required this.success,
    this.user,
    this.message,
    this.retryAfter,
  });
}

/// Resultado do envio de uma avaliação de acessibilidade.
class SubmitEvaluationResult {
  final bool success;
  final String? message;
  final int pointsDelta;

  const SubmitEvaluationResult({
    required this.success,
    this.message,
    this.pointsDelta = 0,
  });
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
  static int _loginAttempt = 0;
  @override
  Future<LoginResult> login({
    required String nome,
    required String password,
  }) async {
    final attempt = ++_loginAttempt;
    final generation = AppHttp.sessionRevision.value;
    final previousStatus = AppHttp.session.status;
    if (!AppHttp.authenticated) {
      AppHttp.session.update(AuthStatus.authenticating);
    }
    try {
      if (kIsWeb) AppHttp.csrfToken = null;
      final response = await AppHttp.postPublic(
        Uri.parse(
          '${Config.baseUrl}${kIsWeb ? '/auth/session/login/' : '/api/login/'}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nome': nome, 'password': password}),
      );
      if (attempt != _loginAttempt ||
          generation != AppHttp.sessionRevision.value) {
        return const LoginResult(success: false, message: 'connection_error');
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success' &&
            (kIsWeb || data['token'] is String)) {
          AppHttp.clearSession();
          final loginGeneration = AppHttp.sessionRevision.value;
          if (kIsWeb) {
            AppHttp.csrfToken = data['csrfToken'] as String?;
            final me = await AppHttp.get(
              Uri.parse('${Config.baseUrl}/api/usuarios/me/'),
            );
            final meUser = me.statusCode == 200
                ? jsonDecode(utf8.decode(me.bodyBytes))
                : null;
            if (me.statusCode != 200 ||
                meUser['id_usuario'] != data['user']['id_usuario'] ||
                attempt != _loginAttempt ||
                loginGeneration != AppHttp.sessionRevision.value) {
              return const LoginResult(
                success: false,
                message: 'connection_error',
              );
            }
          }
          AppHttp.session.userName = data['user']['nome'] as String?;
          AppHttp.session.token = kIsWeb ? null : data['token'] as String?;
          AppHttp.session.userId = (data['user']['id_usuario'] as num?)
              ?.toInt();
          AppHttp.session.profile = Map<String, dynamic>.from(data['user']);
          AppHttp.session.update(AuthStatus.authenticated, invalidate: true);
          final savedGeneration = AppHttp.sessionRevision.value;
          await AppHttp.saveSession();
          if (attempt != _loginAttempt ||
              savedGeneration != AppHttp.sessionRevision.value) {
            return const LoginResult(
              success: false,
              message: 'connection_error',
            );
          }
          return LoginResult(success: true, user: data['user']);
        }
      }
      AppHttp.session.update(previousStatus);
      if (response.statusCode == 429) {
        return LoginResult(
          success: false,
          message: 'rate_limited',
          retryAfter: int.tryParse(response.headers['retry-after'] ?? '') ?? 30,
        );
      }
      return LoginResult(
        success: false,
        message: response.statusCode == 401
            ? 'invalid_credentials'
            : 'connection_error',
      );
    } catch (_) {
      if (generation == AppHttp.sessionRevision.value) {
        AppHttp.session.update(previousStatus);
      }
      return const LoginResult(success: false, message: 'connection_error');
    }
  }

  @override
  Future<List<dynamic>> fetchEvaluations({required dynamic localId}) async {
    if (localId is! num) {
      throw const FormatException('invalid_local_id');
    }
    return const ContributionService().placeReviews(localId.toInt());
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
    final payload = {
      'local': localId,
      'nome_usuario': userName,
      'pergunta_1': pergunta1,
      'pergunta_2': pergunta2,
      'pergunta_3': pergunta3,
      'pergunta_4': pergunta4,
      'estrelas': estrelas,
      'comentario': comentario,
    };
    try {
      int? reviewId;
      if (AppHttp.authenticated && localId is num) {
        final existing = await const ContributionService().ownReview(
          localId.toInt(),
        );
        reviewId = (existing?['id'] as num?)?.toInt();
      }
      final result = await const ContributionService().saveReview(
        payload,
        id: reviewId,
      );
      return SubmitEvaluationResult(
        success: true,
        pointsDelta: (result['points_delta'] as num?)?.toInt() ?? 0,
      );
    } on ContributionException {
      return const SubmitEvaluationResult(
        success: false,
        message: 'evaluation_error',
      );
    }
  }
}
