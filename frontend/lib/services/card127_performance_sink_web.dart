import 'dart:js_interop';
import 'package:web/web.dart' as web;

void emit(String payload) {
  web.window.dispatchEvent(
    web.CustomEvent(
      'card127-performance',
      web.CustomEventInit(detail: payload.toJS),
    ),
  );
}
