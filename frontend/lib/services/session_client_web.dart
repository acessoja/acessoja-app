import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';
import '../config.dart';

http.Client createSessionClient() => _OriginClient();

class _OriginClient extends http.BaseClient {
  final _api = BrowserClient()..withCredentials = true;
  final _public = BrowserClient();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      (request.url.origin == Uri.parse(Config.baseUrl).origin ? _api : _public)
          .send(request);
  @override
  void close() {
    _api.close();
    _public.close();
  }
}
