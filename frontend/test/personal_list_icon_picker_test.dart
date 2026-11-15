import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/personal_list.dart';
import 'package:flutter_application_1/widgets/personal_list_presentation.dart';

void main() {
  Future<void> tapCategory(WidgetTester tester, String id) async {
    final category = find.byKey(ValueKey('personal-list-category-$id'));
    await tester.ensureVisible(category);
    await tester.pumpAndSettle();
    await tester.tap(category);
    await tester.pumpAndSettle();
  }

  Future<Future<Map<String, Object>?> Function()> openEditor(
    WidgetTester tester, {
    PersonalList? current,
  }) async {
    Future<Map<String, Object>?>? pending;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () =>
                    pending = showPersonalListEditor(context, current: current),
                child: const Text('Abrir editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir editor'));
    await tester.pumpAndSettle();
    return () => pending!;
  }

  testWidgets('abre em Mais usados e exibe somente a categoria ativa', (
    tester,
  ) async {
    await openEditor(tester);

    expect(
      find.byKey(const ValueKey('personal-list-category-popular')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('personal-list-icon-grid-popular')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('personal-list-icon-wheelchair')),
      findsNothing,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('personal-list-category-popular')),
          )
          .selected,
      isTrue,
    );

    await tapCategory(tester, 'accessibility');
    expect(
      find.byKey(const ValueKey('personal-list-icon-grid-accessibility')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('personal-list-icon-wheelchair')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('personal-list-icon-grid-popular')),
      findsNothing,
    );
  });

  testWidgets('preserva ícone escolhido ao navegar entre categorias', (
    tester,
  ) async {
    final editor = await openEditor(tester);
    await tapCategory(tester, 'accessibility');
    await tester.tap(
      find.byKey(const ValueKey('personal-list-icon-wheelchair')),
    );
    await tester.pumpAndSettle();
    await tapCategory(tester, 'mobility');
    await tapCategory(tester, 'accessibility');
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('personal-list-icon-wheelchair')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await editor(), isNull);
  });

  testWidgets('abre edição na categoria do ícone existente', (tester) async {
    const current = PersonalList(
      id: 1,
      name: 'Acessíveis',
      icon: 'wheelchair',
      color: 'green',
      system: false,
      visibleOnMap: true,
      count: 0,
    );
    await openEditor(tester, current: current);

    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('personal-list-category-accessibility')),
          )
          .selected,
      isTrue,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('personal-list-icon-wheelchair')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
      ),
      findsOneWidget,
    );
  });

  test('cada categoria exibe um único símbolo e mantém os IDs legados', () {
    final thematicIds = <String>{};
    for (final category in personalListIconCategories) {
      if (category.id != 'popular') {
        for (final id in category.iconIds) {
          expect(thematicIds.add(id), isTrue, reason: id);
        }
      }
      final glyphs = category.iconIds.map(personalListIcon).toList();
      expect(glyphs.toSet().length, glyphs.length, reason: category.label);
    }
    expect(personalListIcon('favorite'), personalListIcon('heart'));
    expect(personalListIcon('shopping_bag'), personalListIcon('shopping-bag'));
    expect(personalListIconCategoryFor('map-pin')?.id, 'leisure');
    expect(personalListIconCategoryFor('place')?.id, 'leisure');
  });

  testWidgets('abre edição do marcador em Lazer e viagens', (tester) async {
    await openEditor(
      tester,
      current: const PersonalList(
        id: 2,
        name: 'Passeios',
        icon: 'map-pin',
        color: 'teal',
        system: false,
        visibleOnMap: true,
        count: 0,
      ),
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('personal-list-category-leisure')),
          )
          .selected,
      isTrue,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('personal-list-icon-map-pin')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cria lista com ícone e cor escolhidos', (tester) async {
    final editor = await openEditor(tester);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Passeios acessíveis',
    );
    await tapCategory(tester, 'accessibility');
    await tester.tap(
      find.byKey(const ValueKey('personal-list-icon-wheelchair')),
    );
    final red = find.byKey(const ValueKey('personal-list-color-red'));
    await tester.ensureVisible(red);
    await tester.pumpAndSettle();
    await tester.tap(red);
    await tester.pumpAndSettle();
    final selectedIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('personal-list-icon-wheelchair')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Icon && widget.icon == Icons.accessible,
        ),
      ),
    );
    expect(selectedIcon.color, Colors.red);
    final save = find.text('Salvar');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(await editor(), {
      'nome': 'Passeios acessíveis',
      'descricao': '',
      'icone': 'wheelchair',
      'cor': 'red',
    });
  });

  testWidgets('não estoura em 320 px com texto ampliado a 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showPersonalListEditor(context),
                  child: const Text('Abrir editor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir editor'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('personal-list-category-popular')),
      findsOneWidget,
    );
    expect(find.text('Salvar'), findsOneWidget);
  });
}
