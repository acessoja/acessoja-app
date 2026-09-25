import 'package:flutter/material.dart';

/// Discards late notifications from an HTTP request after its screen is closed.
/// Callers must still check mounted before using context following an await.
abstract class SafeState<T extends StatefulWidget> extends State<T> {
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }
}
