import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:flutter_application_1/screens/saved_places_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/widgets/place_media.dart';
import 'package:flutter_application_1/widgets/local_card.dart';
import 'frontend_regression_test.dart' show harness;
import 'helpers/favorite_fixture.dart';

void main() {
  for (final hasKnownRatings in [true, false]) {
    testWidgets(
        'saved public rating is per venue, never overall: $hasKnownRatings',
        (tester) async {
      final original = AppHttp.client;
      AppHttp.token = 'media-favorites';
      AppHttp.client = MockClient((_) async => favoriteResponse([
            favoriteJson(place: favoritePlace(count: hasKnownRatings ? 2 : 0)),
          ]));
      try {
        await tester
            .pumpWidget(harness(const SavedPlacesScreen(userName: 'teste')));
        await tester.pumpAndSettle();
        expect(find.text('Nota pública'), findsOneWidget);
        expect(find.text('0,0'), findsNothing);
        expect(find.text('2,0'), findsNothing);
        expect(find.textContaining('Média geral'), findsNothing);
        if (hasKnownRatings) {
          expect(find.text('2 avaliações'), findsOneWidget);
        } else {
          expect(find.text('Sem avaliações'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        AppHttp.client.close();
        AppHttp.client = original;
        AppHttp.clearSession();
      }
    });
  }
  for (final language in ['pt', 'en']) {
    for (final entry in [
      (value: null, count: null),
      (value: 0, count: 0),
      (value: 0, count: 1),
      (value: 4.5, count: 3),
      (value: double.nan, count: null),
    ]) {
      testWidgets('rating is one honest description: $language $entry',
          (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(harness(
              Scaffold(
                  body: ReportedPlaceRating(
                      rating: entry.value, count: entry.count)),
              language: language));
          final semantic = find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label != null);
          final labels = tester
              .widgetList<Semantics>(semantic)
              .map((w) => w.properties.label!)
              .toList();
          if (entry.count == 0) {
            expect(labels,
                contains(language == 'pt' ? 'Sem avaliações' : 'No reviews'));
            expect(find.text('0,0'), findsNothing);
          } else if (entry.value == null || !entry.value!.isFinite) {
            expect(
                labels,
                contains(language == 'pt'
                    ? 'Avaliação não informada'
                    : 'Rating not reported'));
            expect(find.byIcon(Icons.star_rounded), findsNothing);
          } else {
            final label = labels.singleWhere((label) => label.startsWith(
                language == 'pt' ? 'Avaliação média' : 'Average rating'));
            expect(find.bySemanticsLabel(label), findsOneWidget);
            final node = tester.getSemantics(find.bySemanticsLabel(label));
            var namedChildren = 0;
            node.visitChildren((child) {
              if (child.label.isNotEmpty) namedChildren++;
              return true;
            });
            expect(namedChildren, 0);
            expect(label, contains(entry.count == 1 ? '1' : '3'));
          }
        } finally {
          handle.dispose();
        }
      });
    }
  }
  for (final path in [null, 'assets/invalid-photo.png', 77]) {
    testWidgets('venue image fallback never claims a real photo: $path',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(harness(Scaffold(
            body: InformativePlaceImage(path: path, name: 'Biblioteca'))));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp('Imagem indisponível')),
            findsOneWidget);
        expect(find.bySemanticsLabel('Imagem de Biblioteca'), findsNothing);
      } finally {
        handle.dispose();
      }
    });
  }
  testWidgets('missing opening state is not announced as open', (tester) async {
    await tester.pumpWidget(harness(Scaffold(
        body: LocalCard(
            place: const {'nome': 'Local de teste'},
            distanceLabel: '1 km',
            displayNameBuilder: (name) => name))));
    expect(find.text('1 km - Horário não informado'), findsOneWidget);
    expect(find.textContaining('Aberto'), findsNothing);
  });
}
