import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/places_service.dart';

void main() {
  const service = PlacesService();

  tearDown(() {
    AppHttp.client.close();
  });

  test('fetchPlaces envia filtros ativos e normaliza a resposta em mapas',
      () async {
    late Uri requestedUri;
    AppHttp.client = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode([
          {
            'id_local': 7,
            'nome': 'Local Teste',
            'latitude': -16.32,
            'longitude': -48.95,
          }
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final places = await service.fetchPlaces(
      caoGuia: true,
      rampaAcesso: true,
    );

    expect(requestedUri.path, '/api/locais/');
    expect(requestedUri.queryParameters['cao_guia'], 'true');
    expect(requestedUri.queryParameters['rampa_acesso'], 'true');
    expect(requestedUri.queryParameters.containsKey('mesa_acessivel'), isFalse);
    expect(places, hasLength(1));
    expect(places.single['id_local'], 7);
  });

  test('registerVisit envia o local e o usuário no corpo', () async {
    late http.Request captured;
    AppHttp.client = MockClient((request) async {
      captured = request;
      return http.Response('{}', 201);
    });

    await service.registerVisit(localId: 3, userName: 'gabriel');

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/visitas/');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['local'], 3);
    expect(body['nome_usuario'], 'gabriel');
  });
}
