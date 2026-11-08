// @TestOn('chrome')
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/config.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/app_http.dart';

void main() {
  late http.Client original;

  setUp(() {
    original = AppHttp.client;
    AppHttp.csrfToken = null;
    AppHttp.clearSession();
  });

  tearDown(() {
    AppHttp.client = original;
    AppHttp.csrfToken = null;
    AppHttp.clearSession();
  });

  test('web login keeps CSRF proof on the public POST', () async {
    final requests = <http.BaseRequest>[];
    AppHttp.client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(jsonEncode({'csrfToken': 'csrf-synthetic'}), 200);
      }
      return http.Response('{}', 401);
    });

    final response = await AppHttp.postPublic(
      Uri.parse('${Config.baseUrl}/auth/session/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nome': 'synthetic', 'password': 'wrong'}),
    );

    expect(response.statusCode, 401);
    expect(requests.map((request) => request.method), ['GET', 'POST']);
    expect(requests.last.headers['X-CSRFToken'], 'csrf-synthetic');
    expect(requests.last.headers.keys, isNot(contains('Cookie')));
  });

  test('web login maps CSRF rejection separately from connectivity failure', () async {
    AppHttp.client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode({'csrfToken': 'csrf-synthetic'}), 200);
      }
      return http.Response('{}', 403);
    });

    final result = await HttpApiService().login(
      nome: 'synthetic',
      password: 'wrong',
    );

    expect(result.success, isFalse);
    expect(result.message, 'csrf_error');
  });
}
