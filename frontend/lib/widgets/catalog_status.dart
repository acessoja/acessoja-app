import 'package:flutter/material.dart';

import '../l10n/map_strings.dart';
import '../services/discovery_controller.dart';

/// Counts belong to the catalog query only; loaded sources have no global ranking.
class CatalogStatus extends StatelessWidget {
  final DiscoveryController controller;
  final bool compact;
  const CatalogStatus({
    super.key,
    required this.controller,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.mapText(
              'Catálogo OSM de Anápolis: ${controller.places.length} / ${controller.count} carregados.',
              'Anápolis OSM catalog: ${controller.places.length} / ${controller.count} loaded.',
            ),
          ),
          if (!compact)
            Text(
              context.mapText(
                'Contagem independente de locais comunitários. Ordenação entre fontes vale para os itens carregados.',
                'Count independent of community places. Ordering across sources applies to loaded items.',
              ),
            ),
          if (controller.loading) const LinearProgressIndicator(),
          if (!controller.available &&
              !controller.loading &&
              controller.error == null)
            Text(context.mapText('Catálogo ainda não importado neste servidor.',
                'Catalog has not been imported on this server.')),
          if (controller.available &&
              !controller.complete &&
              controller.error == null &&
              !controller.loading)
            Text(
              context.mapText(
                'Cobertura parcial da extração OSM.',
                'Partial OSM extract coverage.',
              ),
            ),
          if (controller.error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                context.mapText(
                  controller.restartRequired
                      ? 'O catálogo mudou. Reinicie a busca para continuar.'
                      : 'Não foi possível atualizar o catálogo. Os itens anteriores foram preservados.',
                  controller.restartRequired
                      ? 'The catalog changed. Restart the search to continue.'
                      : 'Could not refresh the catalog. Earlier items were retained.',
                ),
              ),
            ),
          if (controller.atLimit)
            Text(
              context.mapText(
                'Limite de 1.000 carregados. Aproxime ou refine a busca; os membros dos grupos continuam na lista.',
                '1,000 loaded limit. Zoom in or refine search; cluster members remain in the list.',
              ),
            ),
          if (controller.next != null || controller.error != null)
            TextButton(
              onPressed: controller.loading ||
                      controller.loadingRemaining ||
                      controller.atLimit && !controller.restartRequired
                  ? null
                  : () => controller.restartRequired
                      ? controller.reset(controller.query)
                      : controller.error != null
                          ? controller.load()
                          : controller.loadRemaining(),
              child: Text(
                context.mapText(
                  controller.restartRequired
                      ? 'Reiniciar catálogo'
                      : controller.error != null
                          ? 'Tentar catálogo novamente'
                          : 'Carregar os locais restantes',
                  controller.restartRequired
                      ? 'Restart catalog'
                      : controller.error != null
                          ? 'Retry catalog'
                          : 'Load remaining places',
                ),
              ),
            ),
        ],
      );
}
