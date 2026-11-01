import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/models/evidence.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/models/place_category.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/evidence_service.dart';
import 'package:flutter_application_1/services/contribution_service.dart';
import 'package:flutter_application_1/media/media_service.dart';
import 'package:flutter_application_1/media/media_models.dart';
import 'package:flutter_application_1/widgets/place_reviews_section.dart';
import 'package:flutter_application_1/widgets/feature_provenance.dart';
import 'package:flutter_application_1/widgets/adaptive_place_layer.dart';
import 'package:flutter_application_1/screens/evidence_details_screen.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:http/testing.dart';
import 'package:flutter_application_1/services/place_preview_controller.dart';
import 'package:flutter_application_1/widgets/persistent_place_panel.dart';
import 'map_panel_cards_52_58_test.dart' as panel;
import 'evidence_cards_38_41_test.dart' as evidence;
import 'map_cards_04_06_test.dart' as fixture;

class PagedEvidence extends evidence.FakeEvidence {
  final pages = <Uri?>[];
  @override
  Future<EvidencePage> list({
    int? localId,
    String? externalId,
    required String resource,
    Uri? next,
  }) async {
    pages.add(next);
    if (next == null) {
      return EvidencePage([evidence.fact], Uri.parse('http://localhost/page2'));
    }
    if (pages.length == 2) throw const EvidenceException(503);
    return const EvidencePage([
      EvidenceFact(
        id: 'c0ded000-0000-4000-8000-000000000004',
        resource: 'rampa_acesso',
        revision: evidence.revision,
        state: 'absence_reported',
        source: 'user',
      ),
    ], null);
  }
}

class Reviews extends ContributionService {
  int calls = 0;
  @override
  Future<List<Map<String, dynamic>>> placeReviews(
    int id, {
    String ordering = 'recent',
  }) async {
    calls++;
    return [
      {'estrelas': 4, 'comentario': 'Public review preserved'},
    ];
  }
}

class Photos extends MediaService {
  int calls = 0;
  Completer<PhotoPage>? pending;
  @override
  Future<PhotoPage> photos({
    int? localId,
    int? reviewId,
    bool mine = false,
    Uri? next,
  }) async {
    calls++;
    if (pending != null) return pending!.future;
    if (calls == 1) throw const MediaFailure(503);
    return const PhotoPage([
      ReviewImage(
        id: evidence.id,
        revision: evidence.revision,
        reviewId: 1,
        description: 'Hidden pending photograph',
        state: 'pending',
        imageUrl: '',
        thumbUrl: '',
      ),
      ReviewImage(
        id: evidence.protocol,
        revision: evidence.revision,
        reviewId: 1,
        description: 'Hidden rejected photograph',
        state: 'rejected',
        imageUrl: '',
        thumbUrl: '',
      ),
    ], null);
  }
}

void main() {
  tearDown(AppHttp.clearSession);
  testWidgets(
    'CT-21 CT-44 desktop reparent keeps loaded sections; resource refresh is selective',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      AppHttp.client = MockClient((request) async {
        requests.add(request.url.path);
        return fixture.jsonResponse(
          request.url.path.endsWith('/recursos/')
              ? panel.resources()
              : {'count': 0, 'next': null, 'results': []},
        );
      });
      final c = PlacePreviewController(service: fixture.FakePreviewService());
      await c.select(MapPlace.internal(panel.responsePlace(1)));
      c.expand();
      await tester.pumpWidget(
        fixture.harness(
          Scaffold(
            body: Stack(
              children: [
                PersistentPlacePanel(
                  controller: c,
                  distanceLabel: (_) => '',
                  onAction: (_) {},
                  onGeometry: (_) {},
                  onClose: c.close,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      c.showSection(PlacePanelSection.reviews);
      await tester.pumpAndSettle();
      final beforeResize = [...requests];
      expect(beforeResize.where((p) => p.endsWith('/recursos/')), hasLength(1));
      expect(
        beforeResize.where((p) => p.contains('midia/fotos')),
        hasLength(1),
      );
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      expect(requests, beforeResize);
      c.changedResource();
      await tester.pumpAndSettle();
      expect(requests.where((p) => p.endsWith('/recursos/')), hasLength(2));
      expect(requests.where((p) => p.contains('midia/fotos')), hasLength(1));
      expect(c.section, PlacePanelSection.reviews);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      AppHttp.client.close();
    },
  );
  test(
    'CT-36 marker icon, border and focus contrast against their opaque surface is at least 3:1',
    () {
      for (final theme in [
        AppThemes.light(),
        AppThemes.dark(),
        AppThemes.highContrast(Brightness.light),
        AppThemes.highContrast(Brightness.dark),
        AppThemes.highContrast(Brightness.dark, yellow: true),
      ]) {
        final colors = theme.extension<AppColors>()!;
        final background = colors.surface.computeLuminance();
        for (final foreground in [colors.primaryDark, colors.text]) {
          final value = foreground.computeLuminance();
          final ratio =
              (value > background ? value + .05 : background + .05) /
              (value > background ? background + .05 : value + .05);
          expect(ratio, greaterThanOrEqualTo(3));
        }
      }
    },
  );
  testWidgets(
    'CT-05 observed, received, confirmed and OSM import dates stay distinct',
    (tester) async {
      await tester.pumpWidget(
        fixture.harness(
          const Scaffold(
            body: FeatureProvenance(
              compact: false,
              information: {
                'evidence': [
                  {
                    'source_kind': 'openstreetmap',
                    'observed_on': '2026-01-01',
                    'received_at': '2026-02-02',
                    'confirmed_at': null,
                    'reference': {
                      'imported_at': '2026-03-03',
                      'osm_modified_at': '2026-04-04',
                      'snapshot_at': '2026-05-05',
                    },
                  },
                ],
              },
            ),
          ),
        ),
      );
      final format = MaterialLocalizations.of(
        tester.element(find.byType(FeatureProvenance)),
      );
      for (final pair in [
        ('Observado em', 1),
        ('Registrado em', 2),
        ('Importado em', 3),
        ('Objeto OSM editado em', 4),
      ]) {
        final date = format.formatShortDate(DateTime(2026, pair.$2, pair.$2));
        expect(find.textContaining('${pair.$1}: $date'), findsOneWidget);
      }
      expect(
        find.textContaining('Confirmado em: não informado'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'CT-06 failed second page is retryable and retains the first source',
    (tester) async {
      final service = PagedEvidence();
      await tester.pumpWidget(
        evidence.app(
          EvidenceDetailsScreen(
            localId: 1,
            resource: 'rampa_acesso',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await fixture.tapVisible(tester, find.text('Carregar mais fontes'));
      expect(service.pages.length, 2);
      expect(find.text('Presença relatada'), findsOneWidget);
      await fixture.tapVisible(tester, find.text('Carregar mais fontes'));
      expect(service.pages.length, 3);
      expect(service.pages[1], service.pages[2]);
      expect(find.text('Presença relatada'), findsOneWidget);
      expect(find.text('Ausência relatada'), findsOneWidget);
    },
  );
  testWidgets(
    'CT-21 CT-22 photos retry does not refetch reviews or expose private states',
    (tester) async {
      final reviews = Reviews(), photos = Photos();
      await tester.pumpWidget(
        fixture.harness(
          Scaffold(
            body: SingleChildScrollView(
              child: PlaceReviewsSection(
                place: MapPlace.internal(fixture.own(1)),
                reviews: reviews,
                media: photos,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Public review preserved'), findsOneWidget);
      expect(
        find.textContaining('Não foi possível consultar as fotos públicas'),
        findsOneWidget,
      );
      await fixture.tapVisible(tester, find.text('Tentar novamente: fotos'));
      expect(reviews.calls, 1);
      expect(photos.calls, 2);
      expect(find.textContaining('Hidden'), findsNothing);
      expect(find.text('Nenhuma foto pública disponível.'), findsOneWidget);
    },
  );
  testWidgets('CT-23 CT-56 disposed gallery ignores an old request', (
    tester,
  ) async {
    final media = Photos()..pending = Completer<PhotoPage>();
    await tester.pumpWidget(
      fixture.harness(
        Scaffold(
          body: PlaceReviewsSection(
            place: MapPlace.internal(fixture.own(1)),
            reviews: Reviews(),
            media: media,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    AppHttp.clearSession();
    media.pending!.complete(const PhotoPage([], null));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'CT-33 CT-34 CT-38 CT-40 CT-49 marker target/semantics/guidelines dark=$dark',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final p = MapPlace.internal({
            ...fixture.own(1),
            'nome': 'Full accessible marker name',
          });
          await tester.pumpWidget(
            fixture.harness(
              Scaffold(
                body: Semantics(
                  label: 'Interactive map results',
                  child: FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(-16.3267, -48.9528),
                      initialZoom: 18,
                    ),
                    children: [
                      AdaptivePlaceLayer(
                        places: [p],
                        selectedId: p.id,
                        onSelect: (_) {},
                        onCluster: (_, __) {},
                      ),
                    ],
                  ),
                ),
              ),
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();
          final target = find.byKey(ValueKey('map-place-${p.id}'));
          expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          expect(
            find.bySemanticsLabel(
              RegExp('Full accessible marker name.*Abrir local'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: target, matching: find.byType(Icon)),
            findsOneWidget,
          );
          expect(placeCategoryVisuals.length, 11);
          expect(categoryVisual('new-code'), same(unknownPlaceCategory));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
