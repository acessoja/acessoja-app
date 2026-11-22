import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/map_strings.dart';
import '../models/map_place.dart';
import '../models/place_category.dart';

class MapClusterSheet extends StatelessWidget {
  final List<MapPlace> members;
  final String? selectedId;
  final bool results;
  const MapClusterSheet({
    super.key,
    required this.members,
    this.selectedId,
    this.results = false,
  });
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    container: true,
                    child: Text(
                      context.mapText(
                        results
                            ? '${members.length} locais nos resultados'
                            : '${members.length} locais no mesmo ponto',
                        results
                            ? '${members.length} places in results'
                            : '${members.length} places at this point',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.mapText('Fechar agrupamento', 'Close group'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              key: const ValueKey('map-cluster-members'),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final place = members[index];
                return ListTile(
                  key: ValueKey('cluster-member-${place.id}'),
                  minVerticalPadding: 16,
                  selected: place.id == selectedId,
                  leading: Icon(
                    categoryVisual(place.category).icon,
                    color: categoryVisual(place.category).color,
                  ),
                  title: Text(context.placeName(place)),
                  subtitle: Text(
                    '${context.placeCategory(place)} · ${place.sourceLabel}\n${context.placeAddress(place)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (place.hasCommunityRecognition)
                        Icon(Icons.accessible_forward, color: colors.success),
                      if (place.hasCommunityHighlight)
                        Icon(Icons.star, color: colors.warning),
                      if (place.id == selectedId)
                        Icon(Icons.check_circle, color: colors.primary),
                    ],
                  ),
                  onTap: () => Navigator.pop(context, place),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MapLegendSheet extends StatelessWidget {
  const MapLegendSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.mapText('Legenda do mapa', 'Map legend'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.mapText('Fechar legenda', 'Close legend'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            context.mapText(
              'Os ícones indicam o tipo de local, não sua acessibilidade.',
              'Icons identify the place category, not its accessibility.',
            ),
          ),
          for (final item in placeCategoryVisuals.values)
            ListTile(
              leading: Icon(item.icon, color: item.color),
              title: Text(context.mapText(item.portuguese, item.english)),
            ),
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(
              context.mapText(
                'Categoria desconhecida: símbolo neutro',
                'Unknown category: neutral symbol',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.layers_outlined),
            title: Text(
              context.mapText(
                'Ícone em camadas: locais na mesma coordenada; toque para escolher um. Os demais permanecem individuais.',
                'Stack icon: places at the same coordinate; tap to choose one. Other places remain individual.',
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.circle, color: colors.primary),
            title: Text(
              context.mapText(
                'Azul: local selecionado',
                'Blue: selected place',
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.accessible_forward, color: colors.success),
            title: Text(
              context.mapText(
                'Verde: reconhecimento comunitário sustentado por evidências',
                'Green: community recognition backed by evidence',
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.star, color: colors.warning),
            title: Text(
              context.mapText(
                'Dourado: destaque comunitário superior',
                'Gold: higher community highlight',
              ),
            ),
          ),
          Text(
            context.mapText(
              'A origem e os recursos informados aparecem no resumo.',
              'The data source and reported features appear in the summary.',
            ),
          ),
        ],
      ),
    );
  }
}
