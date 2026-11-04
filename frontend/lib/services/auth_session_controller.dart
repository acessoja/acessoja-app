import 'package:flutter/foundation.dart';

enum AuthStatus {
  initializing,
  guest,
  unauthenticated,
  authenticating,
  authenticated,
  expired,
  offlineRetry,
  loggingOut,
}

class AuthSessionController extends ChangeNotifier {
  AuthStatus status = AuthStatus.unauthenticated;
  String? token;
  String? userName;
  int? userId;
  String? _warning;
  String? get warning => _warning;
  set warning(String? value) {
    if (_warning == value) return;
    _warning = value;
    notifyListeners();
  }

  Map<String, dynamic>? profile;
  final revision = ValueNotifier<int>(0);
  bool get authenticated => status == AuthStatus.authenticated;

  void update(AuthStatus next, {bool invalidate = false}) {
    status = next;
    if (invalidate) revision.value++;
    notifyListeners();
  }

  void clear([AuthStatus next = AuthStatus.unauthenticated]) {
    token = null;
    userName = null;
    userId = null;
    profile = null;
    update(next, invalidate: true);
  }
}
