import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/map_place.dart';

enum PlaceShareStatus { shared, dismissed, unavailable, error, copied, copyFailed }

class PlaceShareOutcome {
  const PlaceShareOutcome(this.status, this.content, {this.error});

  final PlaceShareStatus status;
  final PlaceShareContent content;
  final Object? error;
}

class PlaceShareContent {
  const PlaceShareContent({required this.text, this.mapUri});

  final String text;
  final Uri? mapUri;
}

/// Builds a deliberately small public payload. Never serialize MapPlace.data.
class PlaceSharePayloadBuilder {
  const PlaceSharePayloadBuilder();

  PlaceShareContent build(MapPlace place) {
    final name = _publicLine(place.name);
    final address = _publicLine(place.address);
    final mapUri = _mapUri(place.latitude, place.longitude);
    final lines = <String>[
      'Conheça este lugar:',
      if (name.isNotEmpty) name,
      if (address.isNotEmpty) address,
      if (mapUri != null) '',
      if (mapUri != null) 'Ver localização no mapa:',
      if (mapUri != null) mapUri.toString(),
    ];
    return PlaceShareContent(text: lines.join('\n'), mapUri: mapUri);
  }

  static Uri? _mapUri(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
    });
  }

  static String _publicLine(String value) =>
      value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
}

abstract interface class PlaceSharePlatform {
  Future<PlaceShareStatus> share(String text);
}

class NativePlaceSharePlatform implements PlaceSharePlatform {
  const NativePlaceSharePlatform();

  @override
  Future<PlaceShareStatus> share(String text) async {
    try {
      final result = await SharePlus.instance.share(ShareParams(text: text));
      return switch (result.status) {
        ShareResultStatus.success => PlaceShareStatus.shared,
        ShareResultStatus.dismissed => PlaceShareStatus.dismissed,
        ShareResultStatus.unavailable => PlaceShareStatus.unavailable,
      };
    } catch (_) {
      return PlaceShareStatus.error;
    }
  }
}

abstract interface class PlaceClipboard {
  Future<void> write(String text);
}

class SystemPlaceClipboard implements PlaceClipboard {
  const SystemPlaceClipboard();

  @override
  Future<void> write(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

class PlaceShareService {
  const PlaceShareService({
    this.payloadBuilder = const PlaceSharePayloadBuilder(),
    this.platform = const NativePlaceSharePlatform(),
    this.clipboard = const SystemPlaceClipboard(),
  });

  final PlaceSharePayloadBuilder payloadBuilder;
  final PlaceSharePlatform platform;
  final PlaceClipboard clipboard;

  Future<PlaceShareOutcome> share(MapPlace place) async {
    final content = payloadBuilder.build(place);
    try {
      final status = await platform.share(content.text);
      return PlaceShareOutcome(status, content);
    } catch (error) {
      return PlaceShareOutcome(PlaceShareStatus.error, content, error: error);
    }
  }

  Future<PlaceShareOutcome> copy(MapPlace place) async {
    final content = payloadBuilder.build(place);
    try {
      await clipboard.write(content.text);
      return PlaceShareOutcome(PlaceShareStatus.copied, content);
    } catch (error) {
      return PlaceShareOutcome(PlaceShareStatus.copyFailed, content, error: error);
    }
  }
}
