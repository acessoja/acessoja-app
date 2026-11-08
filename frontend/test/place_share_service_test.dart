import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/services/place_share_service.dart';

class _FakePlatform implements PlaceSharePlatform {
  _FakePlatform(this.result);
  final PlaceShareStatus result;
  String? text;

  @override
  Future<PlaceShareStatus> share(String value) async {
    text = value;
    return result;
  }
}

class _FakeClipboard implements PlaceClipboard {
  String? text;
  bool fail = false;

  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('copy failed');
    text = value;
  }
}

MapPlace _place({Object? latitude = -16.3281, Object? longitude = -48.9534}) =>
    MapPlace.internal({
      'id_local': 7,
      'nome': 'Biblioteca Central',
      'endereco': 'Rua das Flores, 100 — Centro',
      'latitude': latitude,
      'longitude': longitude,
      'nome_usuario': 'não deve aparecer',
      'accessibility_preferences': {'rampa_acesso': true},
      'token': 'secret',
    });

void main() {
  test('builds a public payload with a correctly encoded HTTPS map URL', () {
    final content = const PlaceSharePayloadBuilder().build(_place());

    expect(content.text, contains('Biblioteca Central'));
    expect(content.text, contains('Rua das Flores, 100 — Centro'));
    expect(content.mapUri?.scheme, 'https');
    expect(content.mapUri?.host, 'www.google.com');
    expect(content.mapUri?.queryParameters['query'], '-16.328100,-48.953400');
    expect(content.text, isNot(contains('nome_usuario')));
    expect(content.text, isNot(contains('accessibility_preferences')));
    expect(content.text, isNot(contains('token')));
  });

  test('keeps valid zero coordinates and omits the map link when absent', () {
    expect(
      const PlaceSharePayloadBuilder().build(_place(latitude: 0, longitude: 0)).mapUri,
      isNotNull,
    );
    final missing = const PlaceSharePayloadBuilder().build(
      _place(latitude: null, longitude: null),
    );
    expect(missing.mapUri, isNull);
    expect(missing.text, isNot(contains('google.com')));
  });

  test('rejects malformed coordinates without inventing 0,0', () {
    final invalid = const PlaceSharePayloadBuilder().build(
      _place(latitude: double.nan, longitude: double.infinity),
    );
    expect(invalid.mapUri, isNull);
    expect(invalid.text, isNot(contains('google.com')));
  });

  test('returns platform cancellation and copy outcomes without false success', () async {
    final platform = _FakePlatform(PlaceShareStatus.dismissed);
    final clipboard = _FakeClipboard();
    final service = PlaceShareService(platform: platform, clipboard: clipboard);

    expect((await service.share(_place())).status, PlaceShareStatus.dismissed);
    expect((await service.copy(_place())).status, PlaceShareStatus.copied);
    expect(clipboard.text, contains('Biblioteca Central'));
  });

  test('reports copy failures', () async {
    final clipboard = _FakeClipboard()..fail = true;
    final service = PlaceShareService(clipboard: clipboard);

    expect((await service.copy(_place())).status, PlaceShareStatus.copyFailed);
  });
}
