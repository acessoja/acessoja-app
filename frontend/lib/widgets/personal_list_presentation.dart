import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/personal_list.dart';

class PersonalListIconOption {
  const PersonalListIconOption(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

class PersonalListIconCategory {
  const PersonalListIconCategory(this.id, this.label, this.iconIds);
  final String id;
  final String label;
  final List<String> iconIds;
}

/// The selectable catalog follows ACESSOJA_ICONES_FAVORITOS_NOVO.zip.
/// Material glyphs are tinted with the chosen list color at render time.
const personalListIconOptions = <PersonalListIconOption>[
  PersonalListIconOption('heart', 'Favorito', Icons.favorite),
  PersonalListIconOption('star', 'Destaque', Icons.star),
  PersonalListIconOption('flag', 'Quero visitar', Icons.flag),
  PersonalListIconOption('house', 'Casa', Icons.home),
  PersonalListIconOption('briefcase-business', 'Trabalho', Icons.work),
  PersonalListIconOption('graduation-cap', 'Faculdade', Icons.school),
  PersonalListIconOption('users', 'Família', Icons.people),
  PersonalListIconOption('bookmark', 'Salvo', Icons.bookmark),
  PersonalListIconOption('map-pin', 'Lugar especial', Icons.place),
  PersonalListIconOption('hospital', 'Hospital', Icons.local_hospital),
  PersonalListIconOption('cross', 'Farmácia', Icons.local_pharmacy),
  PersonalListIconOption('accessibility', 'Acessível', Icons.accessibility),
  PersonalListIconOption('wheelchair', 'Cadeirante', Icons.accessible),
  PersonalListIconOption('eye', 'Acessibilidade visual', Icons.visibility),
  PersonalListIconOption('ear', 'Acessibilidade auditiva', Icons.hearing),
  PersonalListIconOption('heart-handshake', 'Apoio', Icons.volunteer_activism),
  PersonalListIconOption('shield-check', 'Local seguro', Icons.verified_user),
  PersonalListIconOption('bus', 'Ônibus', Icons.directions_bus),
  PersonalListIconOption('car', 'Estacionamento', Icons.local_parking),
  PersonalListIconOption('train-front', 'Estação', Icons.train),
  PersonalListIconOption('footprints', 'Caminhada', Icons.directions_walk),
  PersonalListIconOption('bike', 'Bicicleta', Icons.directions_bike),
  PersonalListIconOption('route', 'Rota frequente', Icons.alt_route),
  PersonalListIconOption('navigation', 'Destino', Icons.navigation),
  PersonalListIconOption('map', 'Ponto de referência', Icons.map),
  PersonalListIconOption('utensils', 'Restaurante', Icons.restaurant),
  PersonalListIconOption('coffee', 'Cafeteria', Icons.coffee),
  PersonalListIconOption('shopping-cart', 'Mercado', Icons.shopping_cart),
  PersonalListIconOption('shopping-bag', 'Loja', Icons.shopping_bag),
  PersonalListIconOption('landmark', 'Serviço público', Icons.account_balance),
  PersonalListIconOption('trees', 'Parque', Icons.park),
  PersonalListIconOption('dumbbell', 'Academia', Icons.fitness_center),
  PersonalListIconOption('book-open', 'Biblioteca', Icons.menu_book),
  PersonalListIconOption('luggage', 'Mala', Icons.luggage),
  PersonalListIconOption('music_note', 'Música', Icons.music_note),
  PersonalListIconOption('photo_camera', 'Câmera', Icons.photo_camera),
  PersonalListIconOption('check', 'Visitado', Icons.check_circle),
];

const personalListIconCategories = <PersonalListIconCategory>[
  PersonalListIconCategory('popular', 'Mais usados', [
    'heart',
    'star',
    'flag',
    'bookmark',
    'house',
    'briefcase-business',
    'utensils',
  ]),
  PersonalListIconCategory('food', 'Alimentação', [
    'utensils',
    'coffee',
    'shopping-cart',
    'shopping-bag',
  ]),
  PersonalListIconCategory('leisure', 'Lazer e viagens', [
    'luggage',
    'trees',
    'photo_camera',
    'music_note',
    'map-pin',
  ]),
  PersonalListIconCategory('accessibility', 'Acessibilidade', [
    'accessibility',
    'wheelchair',
    'eye',
    'ear',
    'heart-handshake',
    'shield-check',
  ]),
  PersonalListIconCategory('mobility', 'Mobilidade', [
    'bus',
    'car',
    'train-front',
    'footprints',
    'bike',
    'route',
    'navigation',
    'map',
  ]),
  PersonalListIconCategory('services', 'Serviços e pessoal', [
    'hospital',
    'cross',
    'graduation-cap',
    'users',
    'landmark',
    'dumbbell',
    'book-open',
    'check',
    'briefcase-business',
  ]),
];

String _canonicalIconId(String id) => switch (id) {
  'favorite' => 'heart',
  'home' => 'house',
  'restaurant' => 'utensils',
  'shopping_bag' => 'shopping-bag',
  'park' => 'trees',
  'place' => 'map-pin',
  'local_hospital' => 'hospital',
  'menu_book' => 'book-open',
  _ => id,
};

PersonalListIconCategory? personalListIconCategoryFor(String iconId) {
  final id = _canonicalIconId(iconId);
  final matches = personalListIconCategories.where(
    (category) => category.iconIds.contains(id),
  );
  return matches.where((category) => category.id != 'popular').firstOrNull ??
      matches.firstOrNull;
}

const personalListColors = <(String, String, Color)>[
  ('blue', 'Azul', Colors.blue),
  ('teal', 'Verde-azulado', Colors.teal),
  ('orange', 'Laranja', Colors.orange),
  ('purple', 'Roxo', Colors.deepPurple),
  ('red', 'Vermelho', Colors.red),
  ('green', 'Verde', Colors.green),
];

IconData personalListIcon(String key) {
  final id = _canonicalIconId(key);
  return personalListIconOptions
          .where((option) => option.id == id)
          .firstOrNull
          ?.icon ??
      Icons.bookmark;
}

Color personalListColor(BuildContext context, String key) =>
    personalListColors
        .where((entry) => entry.$1 == key)
        .map((entry) => entry.$3)
        .firstOrNull ??
    AppColors.of(context).primary;

class PersonalListIconPicker extends StatefulWidget {
  const PersonalListIconPicker({
    super.key,
    required this.selectedIcon,
    required this.selectedColor,
    required this.onSelected,
  });

  final String selectedIcon;
  final String selectedColor;
  final ValueChanged<String> onSelected;

  @override
  State<PersonalListIconPicker> createState() => _PersonalListIconPickerState();
}

class _PersonalListIconPickerState extends State<PersonalListIconPicker> {
  late String _categoryId =
      personalListIconCategoryFor(widget.selectedIcon)?.id ?? 'popular';
  final _categoryScroll = ScrollController();
  GlobalKey? _activeInitialCategory;

  @override
  void initState() {
    super.initState();
    if (_categoryId == 'popular') return;
    _activeInitialCategory = GlobalKey();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final label = _activeInitialCategory?.currentContext;
      if (!mounted || label == null || !_categoryScroll.hasClients) return;
      final target = label.findRenderObject();
      if (target == null || !target.attached) return;
      _categoryScroll.position.ensureVisible(target, alignment: .2);
    });
  }

  @override
  void dispose() {
    _categoryScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = personalListIconCategories.firstWhere(
      (entry) => entry.id == _categoryId,
    );
    final options = category.iconIds
        .map(
          (id) =>
              personalListIconOptions.firstWhere((option) => option.id == id),
        )
        .toList();
    final theme = Theme.of(context);
    final appColors = AppColors.of(context);
    final selectedColor = personalListColor(context, widget.selectedColor);

    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escolha um ícone',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            label: 'Categorias de ícones',
            child: SizedBox(
              height: (MediaQuery.textScalerOf(context).scale(14) + 34)
                  .clamp(48.0, double.infinity)
                  .toDouble(),
              child: SingleChildScrollView(
                controller: _categoryScroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in personalListIconCategories)
                      Padding(
                        key: entry.id == _categoryId
                            ? _activeInitialCategory
                            : null,
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          key: ValueKey('personal-list-category-${entry.id}'),
                          label: Text(entry.label),
                          selected: _categoryId == entry.id,
                          showCheckmark: false,
                          selectedColor: appColors.primary,
                          labelStyle: theme.textTheme.labelMedium?.copyWith(
                            color: _categoryId == entry.id
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) =>
                              setState(() => _categoryId = entry.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 280 ? 3 : 4;
              return GridView.builder(
                key: ValueKey('personal-list-icon-grid-${category.id}'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final selected = _canonicalIconId(widget.selectedIcon) == option.id;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: 'Ícone ${option.label}',
                    child: Tooltip(
                      message: option.label,
                      child: Material(
                        color: selected
                            ? selectedColor.withValues(alpha: .12)
                            : theme.colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: selected ? selectedColor : appColors.border,
                            width: selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('personal-list-icon-${option.id}'),
                          onTap: () => widget.onSelected(option.id),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(option.icon, color: selectedColor, size: 28),
                              if (selected)
                                PositionedDirectional(
                                  top: 2,
                                  end: 2,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: appColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.check,
                                        size: 14,
                                        color: theme.colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

Future<Map<String, Object>?> showPersonalListEditor(
  BuildContext context, {
  PersonalList? current,
}) async {
  final name = TextEditingController(text: current?.name ?? '');
  final description = TextEditingController(text: current?.description ?? '');
  var icon = current?.icon ?? 'heart';
  var color = current?.color ?? 'blue';
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<Map<String, Object>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialog) => AlertDialog(
        title: Text(current == null ? 'Nova lista' : 'Editar lista'),
        content: SizedBox(
          width: 460,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .72,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: name,
                      autofocus: true,
                      maxLength: 80,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nome'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Informe o nome da lista.'
                          : null,
                    ),

                    PersonalListIconPicker(
                      selectedIcon: icon,
                      selectedColor: color,
                      onSelected: (value) => setDialog(() => icon = value),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cor do ícone e da lista',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final option in personalListColors)
                          Semantics(
                            button: true,
                            selected: color == option.$1,
                            label: 'Cor ${option.$2}',
                            child: ChoiceChip(
                              key: ValueKey('personal-list-color-${option.$1}'),
                              tooltip: option.$2,
                              avatar: Icon(
                                Icons.circle,
                                color: option.$3,
                                size: 18,
                              ),
                              label: Text(option.$2),
                              selected: color == option.$1,
                              onSelected: (_) =>
                                  setDialog(() => color = option.$1),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: description,
                      maxLength: 240,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, {
                'nome': name.text.trim(),
                'descricao': description.text.trim(),
                'icone': icon,
                'cor': color,
              });
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
  // showDialog completes when pop starts; keep controllers alive through the
  // route's reverse transition because TextFormField is still mounted then.
  await Future<void>.delayed(kThemeAnimationDuration);
  name.dispose();
  description.dispose();
  return result;
}
