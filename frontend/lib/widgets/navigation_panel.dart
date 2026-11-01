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
  final VoidCallback? onRequestClose;
  final bool sessionStarted;
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
  const NavigationPanel({
    super.key,
    required this.controller,
    required this.destination,
    required this.distanceLabel,
    required this.onStart,
    required this.onEnd,
    this.onRequestClose,
    this.sessionStarted = false,
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
    this.maxHeight,
  });

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
        'Directions unavailable; view the preview or use another app.',
      );
    }
    final modifier = switch (step.modifier) {
      'left' => context.routeText('à esquerda', 'left'),
      'right' => context.routeText('à direita', 'right'),
      'slight left' => context.routeText(
        'levemente à esquerda',
        'slightly left',
      ),
      'slight right' => context.routeText(
        'levemente à direita',
        'slightly right',
      ),
      'sharp left' => context.routeText(
        'acentuadamente à esquerda',
        'sharply left',
      ),
      'sharp right' => context.routeText(
        'acentuadamente à direita',
        'sharply right',
      ),
      'uturn' => context.routeText('e faça o retorno', 'and make a U-turn'),
      'straight' => context.routeText('em frente', 'straight'),
      _ => '',
    };
    final action = switch (step.type) {
      'arrive' => context.routeText(
        'Chegue ao destino',
        'Arrive at destination',
      ),
      'depart' => context.routeText('Siga', 'Depart'),
      'roundabout' || 'rotary' => context.routeText(
        'Entre na rotatória',
        'Enter the roundabout',
      ),
      'exit roundabout' || 'exit rotary' => context.routeText(
        'Saia da rotatória',
        'Exit the roundabout',
      ),
      'merge' => context.routeText('Entre na via', 'Merge'),
      'on ramp' => context.routeText('Entre no acesso', 'Take the ramp'),
      'off ramp' => context.routeText('Saia pelo acesso', 'Exit via the ramp'),
      'fork' => context.routeText('Mantenha-se', 'Keep'),
      'turn' ||
      'end of road' ||
      'roundabout turn' => context.routeText('Vire', 'Turn'),
      _ => context.routeText('Continue', 'Continue'),
    };
    final exit =
        {'roundabout', 'rotary'}.contains(step.type) && step.exit != null
        ? context.routeText(' · saída ${step.exit}', ' · exit ${step.exit}')
        : '';
    return '$action${step.type == 'arrive' || modifier.isEmpty ? '' : ' $modifier'}$exit'
        '${step.street.isEmpty ? '' : ' · ${step.street}'}';
  }

  Widget _actions(
    BuildContext context, {
    required bool choosing,
    required bool running,
    required bool arrived,
    required bool started,
    required String endLabel,
  }) {
    final disabled = controller.busy || locating;
    final fresh =
        controller.lastFix != null &&
        controller.lastFix!.problem(controller.now()) == null;
    final needsRoute =
        controller.manualOrigin ||
        controller.problem == 'recalculate_from_gps' ||
        controller.problem == 'reroute_failed';
    String label, key;
    IconData icon;
    VoidCallback? primary;
    if (arrived || running || controller.phase == NavigationPhase.calculating) {
      label = endLabel;
      key = arrived ? 'route-finish' : 'route-end';
      icon = arrived ? Icons.check : Icons.close;
      primary = onEnd;
    } else if (choosing) {
      if (controller.origin == null && onUpdateLocation != null) {
        label = context.routeText('Atualizar localização', 'Update location');
        key = 'route-update-location';
        icon = Icons.my_location;
        primary = locating ? null : onUpdateLocation;
      } else {
        label = controller.phase == NavigationPhase.failed
            ? context.routeText(
                'Tentar calcular novamente',
                'Retry route calculation',
              )
            : context.routeText('Calcular rota', 'Calculate route');
        key = 'route-calculate';
        icon = Icons.alt_route;
        primary = disabled || controller.origin == null ? null : onCalculate;
      }
    } else if (!fresh && !controller.manualOrigin && onUpdateLocation != null) {
      label = context.routeText('Atualizar localização', 'Update location');
      key = 'route-update-location';
      icon = Icons.my_location;
      primary = disabled ? null : onUpdateLocation;
    } else {
      label = needsRoute
          ? context.routeText(
              'Recalcular da localização atual',
              'Recalculate from current location',
            )
          : controller.phase == NavigationPhase.interrupted
          ? context.routeText('Retomar navegação', 'Resume navigation')
          : context.routeText('Iniciar navegação', 'Start navigation');
      key = 'start-navigation';
      icon = Icons.navigation;
      primary = disabled || controller.route?.canGuide != true
          ? null
          : needsRoute
          ? onRecalculate
          : controller.canStart && fresh
          ? onStart
          : null;
    }
    final items = <PopupMenuEntry<VoidCallback>>[];
    void secondary(
      String itemKey,
      String text,
      IconData itemIcon,
      VoidCallback? callback,
    ) {
      if (itemKey == key) return;
      items.add(
        PopupMenuItem<VoidCallback>(
          key: ValueKey(itemKey),
          height: 48,
          enabled: callback != null,
          onTap: callback,
          child: Row(
            children: [
              Icon(itemIcon),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
    }

    if (!arrived) {
      if (onUpdateLocation != null) {
        secondary(
          'route-update-location',
          context.routeText('Atualizar localização', 'Update location'),
          Icons.my_location,
          locating ? null : onUpdateLocation,
        );
      }
      if (choosing && onMapOrigin != null) {
        secondary(
          'route-map-origin',
          context.routeText(
            'Usar centro do mapa como origem',
            'Use map center as origin',
          ),
          Icons.trip_origin,
          disabled ? null : onMapOrigin,
        );
      }
      if (onReviewOrigin != null) {
        secondary(
          'route-review-origin',
          context.routeText('Revisar origem', 'Review origin'),
          Icons.edit_location_alt,
          disabled ? null : onReviewOrigin,
        );
      }
      if (controller.route != null && onRecalculate != null) {
        secondary(
          'route-recalculate',
          context.routeText('Recalcular rota', 'Recalculate route'),
          Icons.refresh,
          disabled ? null : onRecalculate,
        );
      }
      if (running) {
        secondary(
          'route-follow',
          controller.follow
              ? context.routeText('Explorar mapa', 'Explore map')
              : context.routeText(
                  'Voltar a acompanhar',
                  'Follow position again',
                ),
          Icons.gps_fixed,
          () => controller.setFollow(!controller.follow),
        );
      }
      if (onSettings != null &&
          {
            LocationIssue.denied,
            LocationIssue.blocked,
            LocationIssue.disabled,
          }.contains(locationIssue)) {
        secondary(
          'route-location-settings',
          context.routeText('Abrir configurações', 'Open settings'),
          Icons.settings,
          onSettings,
        );
      }
      secondary(
        'route-google-preview',
        context.routeText(
          'Ver rota no Google Maps',
          'View route in Google Maps',
        ),
        Icons.map_outlined,
        onGoogleMaps,
      );
      if (onGoogleNavigate != null) {
        secondary(
          'route-google-navigate',
          context.routeText(
            'Navegar no Google Maps',
            'Navigate in Google Maps',
          ),
          Icons.navigation_outlined,
          onGoogleNavigate,
        );
      }
      secondary(
        'route-waze',
        context.routeText('Navegar no Waze', 'Navigate in Waze'),
        Icons.navigation_outlined,
        onWaze,
      );
      secondary('route-end', endLabel, Icons.close, onEnd);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.busy)
          const LinearProgressIndicator(key: ValueKey('route-progress')),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: FilledButton.icon(
            key: ValueKey(key),
            onPressed: primary,
            icon: Icon(icon),
            label: Text(label),
          ),
        ),
        if (items.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: PopupMenuButton<VoidCallback>(
              key: const ValueKey('route-more'),
              tooltip: context.routeText(
                'Mais opções de rota',
                'More route options',
              ),
              position: PopupMenuPosition.over,
              itemBuilder: (_) => items,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.more_horiz),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.routeText('Mais opções', 'More options'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.phase == NavigationPhase.ended) {
        return const SizedBox.shrink();
      }
      final colors = AppColors.of(context);
      final running = controller.phase == NavigationPhase.running;
      final arrived = controller.phase == NavigationPhase.arrived;
      final choosing =
          controller.phase == NavigationPhase.choosingOrigin ||
          controller.phase == NavigationPhase.failed;
      final origin = controller.origin;
      final originLabel = origin == null
          ? context.routeText(
              'Escolha um ponto ou atualize sua localização',
              'Choose a point or update your location',
            )
          : controller.manualOrigin
          ? context.routeText(
              'Ponto escolhido no mapa',
              'Point selected on the map',
            )
          : context.routeText('Minha localização', 'My location');
      final started =
          sessionStarted ||
          running ||
          controller.phase == NavigationPhase.interrupted;
      final endLabel = arrived
          ? context.routeText('Concluir e voltar', 'Finish and return')
          : started
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
            maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * .42,
          ),
          child: SingleChildScrollView(
            key: const ValueKey('route-panel-scroll'),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_car_rounded),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.routeText('Percurso de carro', 'Driving route'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('route-cancel'),
                      visualDensity: VisualDensity.standard,
                      onPressed: onRequestClose ?? onEnd,
                      tooltip: endLabel,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  context.routeText('Origem (O)', 'Origin (O)'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(originLabel),
                if (origin != null)
                  Text(
                    '${origin.latitude.toStringAsFixed(5)}, ${origin.longitude.toStringAsFixed(5)}',
                  ),
                const SizedBox(height: 8),
                Text(
                  context.routeText('Destino (D)', 'Destination (D)'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  destination.trim().isEmpty
                      ? context.routeText(
                          'Estabelecimento sem nome',
                          'Unnamed establishment',
                        )
                      : destination,
                ),
                Text(
                  destinationAddress.trim().isEmpty
                      ? context.routeText(
                          'Endereço não informado',
                          'Address not reported',
                        )
                      : destinationAddress,
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: Text(
                    context.routePhase(
                      controller.phase,
                      recalculating: controller.recalculating,
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
                if (controller.route != null)
                  Text(
                    '${context.routeText('Estimativa: ', 'Estimate: ')}${(controller.remainingDuration / 60).ceil()} min · $distanceLabel',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                if (controller.route != null)
                  Text(
                    context.routeText(
                      'Distância do trajeto; sem informação de trânsito em tempo real.',
                      'Route distance; no live traffic information.',
                    ),
                    style: TextStyle(color: colors.muted),
                  ),
                if ((controller.route?.originDisplacement ?? 0) > 25 ||
                    (controller.route?.destinationDisplacement ?? 0) > 25)
                  Text(
                    context.routeText(
                          'O motor ajustou o percurso à rede viária: origem ',
                          'The engine snapped the route to the road network: origin ',
                        ) +
                        _distance(
                          context,
                          controller.route?.originDisplacement ?? 0,
                        ) +
                        context.routeText(', destino ', ', destination ') +
                        _distance(
                          context,
                          controller.route?.destinationDisplacement ?? 0,
                        ) +
                        context.routeText(
                          '. O ponto selecionado foi preservado.',
                          '. The selected point was preserved.',
                        ),
                  ),
                if (running)
                  Semantics(
                    liveRegion: true,
                    container: true,
                    child: Text(instruction(context, controller.nextStep)),
                  ),
                if (running) Text(_distance(context, controller.nextDistance)),
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    container: true,
                    child: Text(error),
                  ),
                if (location != null &&
                    location != error &&
                    locationIssue != LocationIssue.notRequested)
                  Semantics(
                    liveRegion: true,
                    container: true,
                    child: Text(location),
                  ),
                const SizedBox(height: 8),
                Text(
                  context.routeText(
                    'A acessibilidade deste trajeto não foi verificada.',
                    'The accessibility of this route has not been verified.',
                  ),
                  key: const ValueKey('map-route-accessibility-notice'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(
                        context.routeText(
                          'Sobre o percurso',
                          'About the route',
                        ),
                      ),
                      content: SingleChildScrollView(
                        child: Text(
                          context.routeText(
                            'O percurso usa a rede viária para carros. Não há verificação de calçadas, travessias, inclinação ou barreiras. A acessibilidade do estabelecimento não comprova a do caminho até ele.',
                            'This route uses the driving road network. Sidewalks, crossings, slopes and barriers have not been verified. Place accessibility does not establish route accessibility.',
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text(context.routeText('Fechar', 'Close')),
                        ),
                      ],
                    ),
                  ),
                  child: Text(
                    context.routeText(
                      'Entenda a limitação',
                      'Understand the limitation',
                    ),
                  ),
                ),
                _actions(
                  context,
                  choosing: choosing,
                  running: running,
                  arrived: arrived,
                  started: started,
                  endLabel: endLabel,
                ),
                const SizedBox(height: 8),
                Text(
                  context.routeText(
                    'Os aplicativos externos podem escolher outro percurso. Ao navegar, usam a localização atual; o Waze não preserva a origem manual.',
                    'External apps may choose another route. Navigation uses your current location; Waze does not preserve a manual origin.',
                  ),
                ),
                if (kIsWeb)
                  Text(
                    context.routeText(
                      'No navegador, mantenha esta aba aberta. Ao sair, o acompanhamento é interrompido. Revise as permissões de localização nas configurações do site.',
                      'Keep this browser tab open. Following is interrupted when you leave. Review location permission in the site settings.',
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
