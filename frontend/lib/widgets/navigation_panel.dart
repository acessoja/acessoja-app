import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/route_strings.dart';
import '../services/location_service.dart';
import '../services/navigation_controller.dart';
import '../models/navigation_route.dart';

class NavigationPanel extends StatelessWidget {
  final NavigationController controller;
  final String destination;
  final String destinationAddress;
  final String distanceLabel;
  final String distanceUnit;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onGoogleMaps;
  final VoidCallback onWaze;
  final VoidCallback? onGoogleNavigate;
  final VoidCallback? onCalculate;
  final VoidCallback? onUpdateLocation;
  final VoidCallback? onMapOrigin;
  final VoidCallback? onReviewOrigin;
  final VoidCallback? onRecalculate;
  final VoidCallback? onSettings;
  final LocationIssue? locationIssue;
  final bool locating;
  final double? maxHeight;
  const NavigationPanel(
      {super.key,
      required this.controller,
      required this.destination,
      required this.distanceLabel,
      required this.onStart,
      required this.onEnd,
      required this.onGoogleMaps,
      required this.onWaze,
      this.destinationAddress = '',
      this.distanceUnit = 'KM',
      this.onGoogleNavigate,
      this.onCalculate,
      this.onUpdateLocation,
      this.onMapOrigin,
      this.onReviewOrigin,
      this.onRecalculate,
      this.onSettings,
      this.locationIssue,
      this.locating = false,
      this.maxHeight});

  String _distance(BuildContext context, double meters) =>
      distanceUnit == 'Milha'
          ? '${(meters / 1609.344).toStringAsFixed(2)} mi'
          : meters < 1000
              ? '${meters.round()} m'
              : '${(meters / 1000).toStringAsFixed(2)} km';

  String instruction(BuildContext context, RouteStep? step) {
    if (step == null || !step.hasInstruction) {
      return context.routeText(
          'Orientações indisponíveis; consulte a prévia ou outro aplicativo.',
          'Directions unavailable; view the preview or use another app.');
    }
    final modifier = switch (step.modifier) {
      'left' => context.routeText('à esquerda', 'left'),
      'right' => context.routeText('à direita', 'right'),
      'slight left' =>
        context.routeText('levemente à esquerda', 'slightly left'),
      'slight right' =>
        context.routeText('levemente à direita', 'slightly right'),
      'sharp left' =>
        context.routeText('acentuadamente à esquerda', 'sharply left'),
      'sharp right' =>
        context.routeText('acentuadamente à direita', 'sharply right'),
      'uturn' => context.routeText('e faça o retorno', 'and make a U-turn'),
      'straight' => context.routeText('em frente', 'straight'),
      _ => '',
    };
    final action = switch (step.type) {
      'arrive' =>
        context.routeText('Chegue ao destino', 'Arrive at destination'),
      'depart' => context.routeText('Siga', 'Depart'),
      'roundabout' ||
      'rotary' =>
        context.routeText('Entre na rotatória', 'Enter the roundabout'),
      'exit roundabout' ||
      'exit rotary' =>
        context.routeText('Saia da rotatória', 'Exit the roundabout'),
      'merge' => context.routeText('Entre na via', 'Merge'),
      'on ramp' => context.routeText('Entre no acesso', 'Take the ramp'),
      'off ramp' => context.routeText('Saia pelo acesso', 'Exit via the ramp'),
      'fork' => context.routeText('Mantenha-se', 'Keep'),
      'turn' ||
      'end of road' ||
      'roundabout turn' =>
        context.routeText('Vire', 'Turn'),
      _ => context.routeText('Continue', 'Continue'),
    };
    final exit =
        {'roundabout', 'rotary'}.contains(step.type) && step.exit != null
            ? context.routeText(' · saída ${step.exit}', ' · exit ${step.exit}')
            : '';
    return '$action${step.type == 'arrive' || modifier.isEmpty ? '' : ' $modifier'}$exit'
        '${step.street.isEmpty ? '' : ' · ${step.street}'}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final colors = AppColors.of(context);
        final running = controller.phase == NavigationPhase.running;
        final arrived = controller.phase == NavigationPhase.arrived;
        final choosing = controller.phase == NavigationPhase.choosingOrigin ||
            controller.phase == NavigationPhase.failed;
        final origin = controller.origin;
        final originLabel = origin == null
            ? context.routeText('Escolha um ponto ou atualize sua localização',
                'Choose a point or update your location')
            : controller.manualOrigin
                ? context.routeText(
                    'Ponto escolhido no mapa', 'Point selected on the map')
                : context.routeText('Minha localização', 'My location');
        final endLabel = running ||
                controller.phase == NavigationPhase.interrupted ||
                arrived
            ? context.routeText('Encerrar navegação', 'End navigation')
            : context.routeText('Cancelar rota', 'Cancel route');
        final error = controller.problem == null
            ? null
            : context.routeProblem(controller.problem!);
        final location = locationIssue == null
            ? null
            : context.locationIssue(locationIssue!);
        return Material(
            elevation: 6,
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight:
                        maxHeight ?? MediaQuery.sizeOf(context).height * .42),
                child: SingleChildScrollView(
                    key: const ValueKey('route-panel-scroll'),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            const Icon(Icons.directions_car_rounded),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    context.routeText(
                                        'Percurso de carro', 'Driving route'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16))),
                            IconButton(
                                key: const ValueKey('route-cancel'),
                                onPressed: onEnd,
                                tooltip: endLabel,
                                constraints: const BoxConstraints(
                                    minWidth: 48, minHeight: 48),
                                icon: const Icon(Icons.close)),
                          ]),
                          Text(context.routeText('Origem (O)', 'Origin (O)'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(originLabel),
                          if (origin != null)
                            Text(
                                '${origin.latitude.toStringAsFixed(5)}, ${origin.longitude.toStringAsFixed(5)}'),
                          const SizedBox(height: 8),
                          Text(
                              context.routeText(
                                  'Destino (D)', 'Destination (D)'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(destination.trim().isEmpty
                              ? context.routeText('Estabelecimento sem nome',
                                  'Unnamed establishment')
                              : destination),
                          Text(destinationAddress.trim().isEmpty
                              ? context.routeText('Endereço não informado',
                                  'Address not reported')
                              : destinationAddress),
                          const SizedBox(height: 8),
                          Semantics(
                              liveRegion: true,
                              container: true,
                              child: Text(
                                  context.routePhase(controller.phase,
                                      recalculating: controller.recalculating),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary))),
                          if (controller.route != null)
                            Text(
                                '${context.routeText('Estimativa: ', 'Estimate: ')}${(controller.remainingDuration / 60).ceil()} min · $distanceLabel',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                          if (controller.route != null)
                            Text(
                                context.routeText(
                                    'Distância do trajeto; sem informação de trânsito em tempo real.',
                                    'Route distance; no live traffic information.'),
                                style: TextStyle(color: colors.muted)),
                          if ((controller.route?.originDisplacement ?? 0) >
                                  25 ||
                              (controller.route?.destinationDisplacement ?? 0) >
                                  25)
                            Text(context.routeText(
                                    'O motor ajustou o percurso à rede viária: origem ',
                                    'The engine snapped the route to the road network: origin ') +
                                _distance(context,
                                    controller.route?.originDisplacement ?? 0) +
                                context.routeText(
                                    ', destino ', ', destination ') +
                                _distance(
                                    context,
                                    controller.route?.destinationDisplacement ??
                                        0) +
                                context.routeText(
                                    '. O ponto selecionado foi preservado.',
                                    '. The selected point was preserved.')),
                          if (running)
                            Semantics(
                                liveRegion: true,
                                container: true,
                                child: Text(
                                    '${instruction(context, controller.nextStep)} · ${_distance(context, controller.nextDistance)}')),
                          if (error != null)
                            Semantics(
                                liveRegion: true,
                                container: true,
                                child: Text(error)),
                          if (location != null &&
                              location != error &&
                              locationIssue != LocationIssue.notRequested)
                            Semantics(
                                liveRegion: true,
                                container: true,
                                child: Text(location)),
                          const SizedBox(height: 8),
                          Text(
                              context.routeText(
                                  'A acessibilidade deste trajeto não foi verificada.',
                                  'The accessibility of this route has not been verified.'),
                              key: const ValueKey(
                                  'map-route-accessibility-notice'),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          TextButton(
                              onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                          title: Text(context.routeText(
                                              'Sobre o percurso',
                                              'About the route')),
                                          content: SingleChildScrollView(
                                              child: Text(context.routeText(
                                                  'O percurso usa a rede viária para carros. Não há verificação de calçadas, travessias, inclinação ou barreiras. A acessibilidade do estabelecimento não comprova a do caminho até ele.',
                                                  'This route uses the driving road network. Sidewalks, crossings, slopes and barriers have not been verified. Place accessibility does not establish route accessibility.'))),
                                          actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(
                                                    dialogContext),
                                                child: Text(context.routeText(
                                                    'Fechar', 'Close')))
                                          ])),
                              child: Text(context.routeText(
                                  'Entenda a limitação',
                                  'Understand the limitation'))),
                          LayoutBuilder(builder: (context, constraints) {
                            final width = constraints.maxWidth < 440
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 8) / 2;
                            Widget action(String label, IconData icon,
                                VoidCallback? callback,
                                {String? key, bool primary = false}) {
                              final child = primary
                                  ? FilledButton.icon(
                                      key: key == null ? null : ValueKey(key),
                                      onPressed: callback,
                                      icon: Icon(icon),
                                      label: Text(label))
                                  : OutlinedButton.icon(
                                      key: key == null ? null : ValueKey(key),
                                      onPressed: callback,
                                      icon: Icon(icon),
                                      label: Text(label));
                              return SizedBox(
                                  width: width,
                                  child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(minHeight: 48),
                                      child: child));
                            }

                            return Wrap(spacing: 8, runSpacing: 8, children: [
                              if (choosing)
                                action(
                                    context.routeText(
                                        'Calcular rota', 'Calculate route'),
                                    Icons.alt_route,
                                    controller.busy || locating
                                        ? null
                                        : onCalculate,
                                    key: 'route-calculate',
                                    primary: true),
                              if (!running &&
                                  !arrived &&
                                  !choosing &&
                                  controller.phase !=
                                      NavigationPhase.calculating)
                                action(
                                    controller.manualOrigin ||
                                            controller.problem ==
                                                'recalculate_from_gps' ||
                                            controller.problem ==
                                                'reroute_failed'
                                        ? context.routeText(
                                            'Recalcular da localização atual',
                                            'Recalculate from current location')
                                        : controller.phase ==
                                                NavigationPhase.interrupted
                                            ? context.routeText(
                                                'Retomar navegação',
                                                'Resume navigation')
                                            : context.routeText(
                                                'Iniciar navegação',
                                                'Start navigation'),
                                    Icons.navigation,
                                    controller.busy ||
                                            locating ||
                                            controller.route?.canGuide != true
                                        ? null
                                        : controller.manualOrigin ||
                                                controller.problem ==
                                                    'recalculate_from_gps' ||
                                                controller.problem ==
                                                    'reroute_failed'
                                            ? onRecalculate
                                            : onStart,
                                    key: 'start-navigation',
                                    primary: true),
                              if (onUpdateLocation != null)
                                action(
                                    context.routeText('Atualizar localização',
                                        'Update location'),
                                    Icons.my_location,
                                    locating ? null : onUpdateLocation,
                                    key: 'route-update-location'),
                              if (onMapOrigin != null && choosing)
                                action(
                                    context.routeText(
                                        'Usar centro do mapa como origem',
                                        'Use map center as origin'),
                                    Icons.trip_origin,
                                    controller.busy || locating
                                        ? null
                                        : onMapOrigin,
                                    key: 'route-map-origin'),
                              if (onReviewOrigin != null)
                                action(
                                    context.routeText(
                                        'Revisar origem', 'Review origin'),
                                    Icons.edit_location_alt,
                                    controller.busy || locating
                                        ? null
                                        : onReviewOrigin,
                                    key: 'route-review-origin'),
                              if (controller.route != null &&
                                  onRecalculate != null)
                                action(
                                    context.routeText(
                                        'Recalcular rota', 'Recalculate route'),
                                    Icons.refresh,
                                    controller.busy || locating
                                        ? null
                                        : onRecalculate,
                                    key: 'route-recalculate'),
                              if (running)
                                action(
                                    controller.follow
                                        ? context.routeText(
                                            'Explorar mapa', 'Explore map')
                                        : context.routeText(
                                            'Voltar a acompanhar',
                                            'Follow position again'),
                                    Icons.gps_fixed,
                                    () => controller
                                        .setFollow(!controller.follow),
                                    key: 'route-follow'),
                              if (onSettings != null &&
                                  {
                                    LocationIssue.denied,
                                    LocationIssue.blocked,
                                    LocationIssue.disabled
                                  }.contains(locationIssue))
                                action(
                                    context.routeText(
                                        'Abrir configurações', 'Open settings'),
                                    Icons.settings,
                                    onSettings),
                              action(
                                  context.routeText('Consultar no Google Maps',
                                      'Preview in Google Maps'),
                                  Icons.map_outlined,
                                  onGoogleMaps,
                                  key: 'route-google-preview'),
                              if (onGoogleNavigate != null)
                                action(
                                    context.routeText('Navegar no Google Maps',
                                        'Navigate in Google Maps'),
                                    Icons.navigation_outlined,
                                    onGoogleNavigate,
                                    key: 'route-google-navigate'),
                              action(
                                  context.routeText(
                                      'Navegar no Waze', 'Navigate in Waze'),
                                  Icons.navigation_outlined,
                                  onWaze,
                                  key: 'route-waze'),
                              action(endLabel, Icons.close, onEnd,
                                  key: 'route-end'),
                            ]);
                          }),
                          const SizedBox(height: 8),
                          Text(context.routeText(
                              'Os aplicativos externos podem escolher outro percurso. Ao navegar, usam a localização atual; o Waze não preserva a origem manual.',
                              'External apps may choose another route. Navigation uses your current location; Waze does not preserve a manual origin.')),
                          if (kIsWeb)
                            Text(context.routeText(
                                'No navegador, mantenha esta aba aberta. Ao sair, o acompanhamento é interrompido. Revise as permissões de localização nas configurações do site.',
                                'Keep this browser tab open. Following is interrupted when you leave. Review location permission in the site settings.')),
                        ]))));
      });
}
