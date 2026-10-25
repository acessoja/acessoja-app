import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<bool> savePersonalData(Uint8List bytes) async {
  final blob = web.Blob([bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = 'acessoja-meus-dados.json';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  // Allow the browser to acquire the blob before releasing the private bytes.
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  return true; // Download requested; this does not claim the user saved the file.
}
