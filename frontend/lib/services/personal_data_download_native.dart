import 'package:flutter/services.dart';

/// Android's Storage Access Framework lets the owner choose a destination;
/// no broad storage permission or permanent temporary export is needed.
Future<bool> savePersonalData(Uint8List bytes) async =>
    await const MethodChannel('acessoja/personal_data').invokeMethod<bool>(
      'saveJson',
      {'bytes': bytes},
    ) ??
    false;
