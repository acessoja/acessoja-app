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
  Widget build(BuildContext context) => SafeArea(
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
                          : '${members.length} locais neste agrupamento',
                      results
                          ? '${members.length} places in results'
                          : '${members.length} places in this group',
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
                leading: Icon(categoryVisual(place.category).icon),
                title: Text(context.placeName(place)),
                subtitle: Text(
                  '${context.placeCategory(place)} · ${place.sourceLabel}\n${context.placeAddress(place)}',
                ),
                trailing: place.id == selectedId
                    ? const Icon(Icons.check_circle_outline)
                    : null,
                onTap: () => Navigator.pop(context, place),
              );
            },
          ),
        ),
      ],
    ),
  );
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
              leading: Icon(item.icon, color: colors.primaryDark),
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
                'Número: quantidade de locais neste grupo. Abra para escolher um membro.',
                'Number: places in this group. Open to choose a member.',
              ),
            ),
          ),
          Text(
            context.mapText(
              'O local selecionado recebe contorno mais espesso e formato com cantos.',
              'The selected place has a thicker outline and a shape with corners.',
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
