import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'app_http.dart';
import 'navigation_controller.dart';

/// One accepted position shared by screens. The map owns the sole GPS stream.
class CurrentPosition extends ChangeNotifier {
  final DateTime Function() now;
  CurrentPosition({DateTime Function()? clock}) : now = clock ?? DateTime.now {
    AppHttp.sessionRevision.addListener(clear);
  }
  NavigationFix? _fix;
  Timer? _expiry;
  String _unit = 'KM';
  String get unit => _unit;
  set unit(String value) {
    if (_unit == value) {
      return;
    }
    _unit = value;
    notifyListeners();
  }

  LatLng? get point => _fix?.problem(now()) == null ? _fix?.point : null;
  void accept(NavigationFix fix) {
    if (fix.problem(now()) != null) {
      clear();
      return;
    }
    if (_fix != null && fix.timestamp.isBefore(_fix!.timestamp)) {
      return;
    }
    _expiry?.cancel();
    _fix = fix;
    _expiry = Timer(
        const Duration(seconds: 30) - now().difference(fix.timestamp), clear);
    notifyListeners();
  }

  void clear() {
    _expiry?.cancel();
    _fix = null;
    notifyListeners();
  }

  @override
  void dispose() {
    AppHttp.sessionRevision.removeListener(clear);
    _expiry?.cancel();
    super.dispose();
  }
}

class PositionScope extends InheritedNotifier<CurrentPosition> {
  const PositionScope(
      {super.key, required CurrentPosition controller, required super.child})
      : super(notifier: controller);
  static CurrentPosition? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PositionScope>()?.notifier;
  static CurrentPosition? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PositionScope>()?.notifier;
}
