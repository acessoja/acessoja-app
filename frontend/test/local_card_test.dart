import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/local_card.dart';

void main() {
  final place = <String, dynamic>{
    'nome': 'UniEVANGÉLICA',
    'distancia': 1.2,
    'aberto': true,
    'media_estrelas': 4.0,
  };

  Widget buildCard({
    Map<String, dynamic>? overridePlace,
    VoidCallback? onRoute,
    VoidCallback? onDetails,
    String language = 'pt',
    bool dark = false,
    double scale = 1,
  }) {
    return MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: dark ? AppThemes.dark() : AppThemes.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: LocalCard(
          place: overridePlace ?? place,
          distanceLabel: '1,2 km',
          displayNameBuilder: (nome) => nome,
          onRoutePressed: onRoute,
          onDetailsPressed: onDetails,
        ),
      ),
    );
  }

  testWidgets('exibe nome, distância e status do local', (tester) async {
    await tester.pumpWidget(buildCard());

    expect(find.text('UniEVANGÉLICA'), findsOneWidget);
    expect(find.text('1,2 km - Aberto'), findsOneWidget);
  });

  testWidgets('exibe "Fechado" quando o local não está aberto', (tester) async {
    await tester.pumpWidget(
      buildCard(overridePlace: {...place, 'aberto': false}),
    );

    expect(find.text('1,2 km - Fechado'), findsOneWidget);
  });

  testWidgets(
    'exibe ícone de estabelecimento quando não há imagem cadastrada',
    (tester) async {
      await tester.pumpWidget(buildCard());

      expect(find.byIcon(Icons.business), findsOneWidget);
    },
  );

  testWidgets('exibe as estrelas preenchidas de acordo com a média do local', (
    tester,
  ) async {
    await tester.pumpWidget(buildCard());

    final stars = tester.widgetList<Icon>(find.byIcon(Icons.star)).toList();
    expect(stars.length, 5);

    final filled = stars.where((icon) => icon.color == Colors.amber).length;
    expect(filled, 4);
  });

  testWidgets('aciona o callback de Rota ao tocar no botão Rota', (
    tester,
  ) async {
    var routeTapped = false;
    await tester.pumpWidget(buildCard(onRoute: () => routeTapped = true));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Rota'));
    await tester.pump();

    expect(routeTapped, isTrue);
  });

  testWidgets('aciona o callback de Avaliações ao tocar no botão Avaliações', (
    tester,
  ) async {
    var detailsTapped = false;
    await tester.pumpWidget(buildCard(onDetails: () => detailsTapped = true));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Avaliações'));
    await tester.pump();

    expect(detailsTapped, isTrue);
  });

  for (final language in ['pt', 'en']) {
    testWidgets('semântica única, tooltips e callbacks $language', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        var routes = 0, reviews = 0;
        await tester.pumpWidget(
          buildCard(
            language: language,
            onRoute: () => routes++,
            onDetails: () => reviews++,
          ),
        );
        final t = lookupAppLocalizations(Locale(language));
        final label = t.ratingValue(language == 'pt' ? '4,0' : '4.0');
        expect(find.bySemanticsLabel(label), findsOneWidget);
        final rating = tester.getSemantics(find.bySemanticsLabel(label));
        expect(rating.getSemanticsData().label, label);
        final childLabels = <String>[];
        rating.visitChildren((node) {
          childLabels.add(node.getSemanticsData().label);
          return true;
        });
        expect(childLabels.where((value) => value.isNotEmpty), isEmpty);
        expect(
          find.bySemanticsLabel(t.placeImagePlaceholder('UniEVANGÉLICA')),
          findsOneWidget,
        );
        for (final action in [
          t.routeTo('UniEVANGÉLICA'),
          t.reviewsOf('UniEVANGÉLICA'),
        ]) {
          expect(find.byTooltip(action), findsOneWidget);
          final node = tester.getSemantics(find.bySemanticsLabel(action));
          expect(node.getSemanticsData().label, action);
          expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
          expect(
            node.getSemanticsData().flagsCollection.isEnabled.toBoolOrNull(),
            isTrue,
          );
        }
        await tester.tap(find.widgetWithText(ElevatedButton, t.route));
        await tester.tap(find.widgetWithText(ElevatedButton, t.reviews));
        expect(routes, 1);
        expect(reviews, 1);
      } finally {
        handle.dispose();
      }
    });
  }
  testWidgets('ações desabilitadas preservam a semântica', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(buildCard());
      final t = lookupAppLocalizations(const Locale('pt'));
      for (final label in [
        t.routeTo('UniEVANGÉLICA'),
        t.reviewsOf('UniEVANGÉLICA'),
      ]) {
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        expect(
          node.getSemanticsData().flagsCollection.isEnabled.toBoolOrNull(),
          isNotNull,
        );
        expect(
          node.getSemanticsData().flagsCollection.isEnabled.toBoolOrNull(),
          isFalse,
        );
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      }
    } finally {
      handle.dispose();
    }
  });
  testWidgets(
    'nota zero conhecida difere de ausência e imagem inválida é placeholder',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          buildCard(
            overridePlace: {
              ...place,
              'media_estrelas': 0,
              'quantidade_avaliacoes': 1,
              'imagem': 'assets/does-not-exist.png',
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel('Avaliação média 0,0 de 5. 1 avaliação'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('Imagem indisponível')),
          findsOneWidget,
        );
        await tester.pumpWidget(
          buildCard(
            overridePlace: {
              ...place,
              'media_estrelas': 0,
              'quantidade_avaliacoes': 0,
            },
          ),
        );
        expect(find.bySemanticsLabel('Sem avaliações'), findsOneWidget);
        expect(find.text('(0,0)'), findsNothing);
        await tester.pumpWidget(
          buildCard(overridePlace: {'nome': 'Sem informação'}),
        );
        expect(
          find.bySemanticsLabel('Avaliação não informada'),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    },
  );
  testWidgets('asset válido mantém descrição da imagem', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        buildCard(
          overridePlace: {...place, 'imagem': 'assets/unievangelica.png'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Imagem de UniEVANGÉLICA'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });
  for (final size in [
    const Size(320, 640),
    const Size(360, 740),
    const Size(390, 844),
    const Size(1280, 800),
    const Size(640, 320),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('card longo $size escala $scale tema $dark', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            buildCard(
              dark: dark,
              scale: scale,
              overridePlace: {
                ...place,
                'nome': 'Biblioteca com um nome bastante longo em Anápolis',
              },
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.byIcon(Icons.business), findsOneWidget);
        });
      }
    }
  }
}
