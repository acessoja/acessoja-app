import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/contribution_strings.dart';
import '../l10n/strings.dart';
import '../services/navigation_controller.dart';
import '../models/navigation_route.dart';

class NavigationPanel extends StatelessWidget {
  final NavigationController controller;
  final String destination;
  final String distanceLabel;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onGoogleMaps;
  final VoidCallback onWaze;
  const NavigationPanel({super.key, required this.controller, required this.destination,
    required this.distanceLabel, required this.onStart, required this.onEnd,
    required this.onGoogleMaps, required this.onWaze});

  String instruction(BuildContext context, RouteStep? step) {
    if (step == null) { return context.contributionText('Orientações indisponíveis; use navegação externa.',
        'Directions unavailable; use external navigation.'); }
    final modifier = switch (step.modifier) {
      'left' => context.contributionText('à esquerda', 'left'),
      'right' => context.contributionText('à direita', 'right'),
      'slight left' => context.contributionText('levemente à esquerda', 'slightly left'),
      'slight right' => context.contributionText('levemente à direita', 'slightly right'),
      'sharp left' => context.contributionText('acentuadamente à esquerda', 'sharply left'),
      'sharp right' => context.contributionText('acentuadamente à direita', 'sharply right'),
      'uturn' => context.contributionText('e faça o retorno', 'and make a U-turn'),
      _ => context.contributionText('em frente', 'straight'),
    };
    final action = switch (step.type) {
      'arrive' => context.contributionText('Chegue ao destino', 'Arrive at destination'),
      'depart' => context.contributionText('Siga', 'Depart'),
      'roundabout' || 'rotary' => context.contributionText('Entre na rotatória', 'Enter the roundabout'),
      'merge' => context.contributionText('Entre na via', 'Merge'),
      'on ramp' => context.contributionText('Entre no acesso', 'Take the ramp'),
      'off ramp' => context.contributionText('Saia pelo acesso', 'Exit via the ramp'),
      'fork' => context.contributionText('Mantenha-se', 'Keep'),
      'turn' || 'end of road' => context.contributionText('Vire', 'Turn'),
      'continue' || 'new name' || 'notification' =>
          context.contributionText('Continue', 'Continue'),
      _ => context.contributionText('Siga a orientação da via', 'Follow the road guidance'),
    };
    return '$action${step.type == 'arrive' ? '' : ' $modifier'}'
        '${step.street.isEmpty ? '' : ' · ${step.street}'}';
  }

  @override
  Widget build(BuildContext context) {
    final running = controller.phase == NavigationPhase.running;
    final arrived = controller.phase == NavigationPhase.arrived;
    final interrupted = controller.phase == NavigationPhase.interrupted;
    return Material(elevation: 6, borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.42),
        child: SingleChildScrollView(padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.directions_car_rounded),
                const SizedBox(width: 8),
                Expanded(child: Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(onPressed: onEnd, tooltip: context.l10n.closeRoute, icon: const Icon(Icons.close)),
              ]),
              Text(arrived ? context.contributionText('Destino alcançado', 'Destination reached') :
                  '${(controller.remainingDuration / 60).ceil()} min · $distanceLabel',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (running) ...[
                const SizedBox(height: 4),
                Semantics(liveRegion: true, child: Text(
                    '${instruction(context, controller.nextStep)} · ${controller.nextDistance.round()} m',
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                if (controller.recalculating)
                  Text(context.contributionText('Recalculando rota…', 'Recalculating route…')),
                TextButton.icon(onPressed: () => controller.setFollow(!controller.follow),
                  icon: Icon(controller.follow ? Icons.gps_fixed : Icons.gps_not_fixed),
                  label: Text(controller.follow ? context.contributionText('Acompanhando posição', 'Following position') :
                      context.contributionText('Voltar a acompanhar', 'Follow position again'))),
              ],
              if (controller.problem != null)
                Text(context.contributionText('Verifique o GPS ou use Google Maps/Waze. É possível tentar novamente.',
                    'Check GPS or use Google Maps/Waze. You can try again.')),
              if (!running && !arrived)
                FilledButton.icon(key: const ValueKey('start-navigation'), onPressed: onStart,
                  icon: const Icon(Icons.navigation),
                  label: Text(interrupted ? context.contributionText('Retomar navegação', 'Resume navigation') :
                      context.contributionText('Iniciar navegação', 'Start navigation'))),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: onGoogleMaps, child: const Text('Google Maps')),
                OutlinedButton(onPressed: onWaze, child: const Text('Waze')),
                if (running || interrupted) TextButton(onPressed: onEnd,
                  child: Text(context.contributionText('Encerrar', 'End'))),
              ]),
              Text(context.contributionText('Rota comum do OSRM; acessibilidade do trajeto não verificada.',
                  'Standard OSRM route; accessibility has not been verified.'),
                key: const ValueKey('map-route-accessibility-notice'), style: const TextStyle(fontSize: 11)),
              if (kIsWeb)
                Text(context.contributionText('No navegador, mantenha esta aba aberta. A navegação pausa ao sair.',
                    'In the browser, keep this tab open. Navigation pauses when you leave.'),
                    style: const TextStyle(fontSize: 11)),
            ]),
        ),
      ),
    );
  }
}
