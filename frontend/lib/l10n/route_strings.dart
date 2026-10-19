import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/navigation_controller.dart';

extension RouteStrings on BuildContext {
  String routeText(String pt, String en) =>
      Localizations.localeOf(this).languageCode == 'en' ? en : pt;

  String routePhase(NavigationPhase phase, {bool recalculating = false}) {
    if (recalculating) { return routeText('Recalculando rota…', 'Recalculating route…'); }
    return switch (phase) {
      NavigationPhase.choosingOrigin => routeText('Escolha ou revise a origem', 'Choose or review the origin'),
      NavigationPhase.calculating => routeText('Calculando rota…', 'Calculating route…'),
      NavigationPhase.preview => routeText('Prévia do percurso', 'Route preview'),
      NavigationPhase.running => routeText('Navegação ativa', 'Navigation active'),
      NavigationPhase.interrupted => routeText('Navegação interrompida', 'Navigation interrupted'),
      NavigationPhase.arrived => routeText('Destino alcançado', 'Destination reached'),
      NavigationPhase.failed => routeText('Não foi possível calcular a rota', 'Unable to calculate the route'),
      NavigationPhase.ended => routeText('Rota encerrada', 'Route ended'),
    };
  }

  String locationIssue(LocationIssue value) => switch (value) {
    LocationIssue.notRequested => routeText('Sua localização ainda não foi solicitada. Atualize-a para navegar.',
      'Your location has not been requested yet. Update it to navigate.'),
    LocationIssue.obtaining => routeText('Obtendo sua localização…', 'Getting your location…'),
    LocationIssue.denied => routeText('Permissão de localização negada. Você pode continuar consultando o mapa.',
      'Location permission denied. You can keep browsing the map.'),
    LocationIssue.blocked => routeText('A localização está bloqueada nas permissões. Revise as configurações.',
      'Location permission is blocked. Review the settings.'),
    LocationIssue.disabled => routeText('Ative o serviço de localização do dispositivo para navegar.',
      'Enable the device location service to navigate.'),
    LocationIssue.stale => routeText('A posição está antiga. Atualize sua localização antes de navegar.',
      'The position is out of date. Update your location before navigating.'),
    LocationIssue.imprecise => routeText('A localização está pouco precisa. Aguarde uma atualização ou tente novamente.',
      'Location accuracy is low. Wait for an update or try again.'),
    LocationIssue.invalid => routeText('A posição recebida não é válida. Tente atualizar sua localização.',
      'The received position is invalid. Try updating your location.'),
    LocationIssue.timeout => routeText('A localização demorou para responder. Tente novamente.',
      'Location took too long to respond. Try again.'),
    LocationIssue.unavailable => routeText('Sinal de localização indisponível. Tente novamente.',
      'Location signal unavailable. Try again.'),
    LocationIssue.insecureContext => routeText('No navegador, abra o aplicativo por HTTPS ou localhost para usar a localização.',
      'In the browser, open the app over HTTPS or localhost to use location.'),
  };

  String routeProblem(String code) {
    if (code.startsWith('location_')) {
      for (final issue in LocationIssue.values) {
        if (code == 'location_${issue.name}') { return locationIssue(issue); }
      }
    }
    return switch (code) {
      'gps_missing' || 'gps_unavailable' || 'gps_or_steps_unavailable' =>
        routeText('Precisamos da sua localização para iniciar a navegação.',
          'We need your location to start navigation.'),
      'gps_stale' => locationIssue(LocationIssue.stale),
      'gps_imprecise' => locationIssue(LocationIssue.imprecise),
      'gps_invalid' => locationIssue(LocationIssue.invalid),
      'steps_unavailable' => routeText('Este percurso não tem orientações completas. Consulte a prévia ou abra outro aplicativo.',
        'This route has no complete directions. View the preview or open another app.'),
      'recalculate_from_gps' => routeText('Recalcule a partir da localização atual antes de acompanhar sua posição.',
        'Recalculate from your current location before following your position.'),
      'route_invalidOrigin' => routeText('A origem não tem coordenadas válidas. Escolha outro ponto.',
        'The origin has no valid coordinates. Choose another point.'),
      'route_invalidDestination' => routeText('O destino não tem coordenadas válidas. Escolha outro estabelecimento.',
        'The destination has no valid coordinates. Choose another place.'),
      'route_noSegment' => routeText('Não há via próxima para conectar um dos pontos. Revise a origem ou o destino.',
        'No nearby road can connect one of the points. Review the origin or destination.'),
      'route_noRoute' => routeText('Não foi possível encontrar um percurso entre estes pontos.',
        'No route could be found between these points.'),
      'route_timeout' => routeText('O cálculo demorou para responder. Tente novamente.',
        'The route request took too long. Try again.'),
      'route_invalidResponse' => routeText('O serviço retornou um percurso inválido. Tente novamente.',
        'The service returned an invalid route. Try again.'),
      'route_rateLimited' => routeText('Limite de consultas atingido. Aguarde antes de tentar novamente.',
        'Request limit reached. Wait before retrying.'),
      'route_unavailable' || 'route_http' || 'route_network' => routeText('O serviço de rotas está indisponível. Tente novamente.',
        'The routing service is unavailable. Try again.'),
      'reroute_failed' => routeText('Não foi possível recalcular agora. O trajeto anterior não foi atualizado. Tente novamente.',
        'Unable to recalculate now. The previous route was not updated. Try again.'),
      'tab_inactive' || 'screen_changed' => routeText('A operação da rota foi interrompida. Revise a localização antes de continuar.',
        'The route operation was interrupted. Review your location before continuing.'),
      _ => routeText('Não foi possível continuar esta operação. Tente novamente.',
        'Unable to continue this operation. Try again.'),
    };
  }
}
