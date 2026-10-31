import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_http.dart';
import 'media_models.dart';

class ImageSelectionService {
  ImageSelectionService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;
  static const maxBytes = 5 * 1024 * 1024;
  static const _contextKey = 'acessoja.image-picker.context.v1';

  Future<String?> recoverableScope(String prefix) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        !AppHttp.authenticated) {
      return null;
    }
    try {
      final stored = (await SharedPreferences.getInstance()).getString(
        _contextKey,
      );
      final data = stored == null ? null : jsonDecode(stored);
      if (data is Map &&
          data['owner'] == AppHttp.userId &&
          data['scope'] is String &&
          (data['scope'] as String).startsWith(prefix) &&
          data['at'] is int &&
          DateTime.now().millisecondsSinceEpoch - (data['at'] as int) <=
              86400000) {
        return data['scope'] as String;
      }
    } on Exception {
      return null;
    }
    return null;
  }

  Future<SelectedImage> _read(XFile file) async {
    if (await file.length() > maxBytes) {
      throw const MediaFailure(413);
    }
    final name = file.name.toLowerCase();
    final mime = name.endsWith('.jpg') || name.endsWith('.jpeg')
        ? 'image/jpeg'
        : name.endsWith('.png')
        ? 'image/png'
        : name.endsWith('.webp')
        ? 'image/webp'
        : null;
    if (mime == null) {
      throw const MediaFailure(422);
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const MediaFailure(413);
    }
    return SelectedImage(bytes: bytes, name: file.name, mime: mime);
  }

  Future<SelectedImage?> pick({
    required String scope,
    bool camera = false,
  }) async {
    if (!AppHttp.authenticated) {
      throw const MediaFailure(401);
    }
    final session = AppHttp.sessionRevision.value;
    final preferences = await SharedPreferences.getInstance();
    final recoveryContext = jsonEncode({
      'owner': AppHttp.userId,
      'scope': scope,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    await preferences.setString(_contextKey, recoveryContext);
    try {
      final file = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (session != AppHttp.sessionRevision.value) {
        throw const MediaFailure(401);
      }
      return file == null ? null : await _read(file);
    } on PlatformException catch (error) {
      throw MediaFailure(
        error.code.contains('denied') ? 403 : 503,
        'selection',
      );
    } finally {
      if (preferences.getString(_contextKey) == recoveryContext) {
        await preferences.remove(_contextKey);
      }
    }
  }

  Future<SelectedImage?> recover(String scope) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_contextKey);
    final session = AppHttp.sessionRevision.value;
    try {
      final lost = await _picker.retrieveLostData();
      if (stored == null ||
          !AppHttp.authenticated ||
          session != AppHttp.sessionRevision.value ||
          lost.isEmpty) {
        return null;
      }
      final context = jsonDecode(stored);
      if (context['owner'] != AppHttp.userId ||
          context['scope'] != scope ||
          DateTime.now().millisecondsSinceEpoch - (context['at'] as int) >
              86400000) {
        return null;
      }
      if (lost.exception != null) {
        throw const MediaFailure(503, 'selection');
      }
      return lost.files?.isNotEmpty == true
          ? await _read(lost.files!.first)
          : null;
    } on FormatException {
      return null;
    } finally {
      if (preferences.getString(_contextKey) == stored) {
        await preferences.remove(_contextKey);
      }
    }
  }
}
