import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationFailure implements Exception {
  final String message;
  const LocationFailure(this.message);
}

/// Keeps permission handling injectable while using the same GPS plugin.
class LocationService {
  const LocationService();

  Future<Position> currentPosition() async {
    if (kIsWeb && Uri.base.scheme != 'https' &&
        Uri.base.host != 'localhost' && Uri.base.host != '127.0.0.1' &&
        Uri.base.host != '[::1]' && Uri.base.host != '::1') {
      throw const LocationFailure('No navegador, abra o app por HTTPS ou localhost '
          'para permitir a localização.');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure('Ative o serviço de localização do dispositivo.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure('Localização bloqueada. Revise as permissões '
          'do aplicativo ou do site no navegador.');
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationFailure('Localização não autorizada. Você pode '
          'continuar pesquisando pelo mapa.');
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10)),
      );
    } on TimeoutException {
      throw const LocationFailure('A localização demorou para responder. '
          'Tente novamente ou pesquise pelo mapa.');
    }
  }

  Stream<Position> positions() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high,
      distanceFilter: 10),
  );
}
