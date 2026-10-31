import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/app_http.dart';

/// Evicts only image providers registered by the account/media flows.
class MediaSessionCache {
  static final _providers = <ImageProvider>[];
  static final avatarChanged = ValueNotifier<int>(0);
  static bool _started = false;
  static T track<T extends ImageProvider>(T provider) {
    if (!_started) {
      _started = true;
      AppHttp.sessionRevision.addListener(clear);
    }
    _providers.add(provider);
    if (_providers.length > 32) {
      _providers.removeAt(0).evict();
    }
    return provider;
  }

  static void discard(ImageProvider? provider) {
    if (provider != null) {
      _providers.remove(provider);
      provider.evict();
    }
  }

  static void clear() {
    for (final provider in _providers) {
      provider.evict();
    }
    _providers.clear();
  }

  static ImageProvider? legacyAvatar(String raw) {
    if (raw.isEmpty) {
      return null;
    }
    try {
      return track(
        MemoryImage(
          base64Decode(
            raw.startsWith('data:image/') ? raw.split(',').last : raw,
          ),
        ),
      );
    } on FormatException {
      return null;
    }
  }
}
