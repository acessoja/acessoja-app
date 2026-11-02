import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/models/accessibility_catalog.dart';
import 'package:flutter_application_1/models/discovery_filters.dart';
import 'package:flutter_application_1/models/discovery_query.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/models/place_subcategories.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/discovery_controller.dart';
import 'package:flutter_application_1/services/places_service.dart';
import 'package:flutter_application_1/widgets/accessibility_filter_panel.dart';
import 'package:flutter_application_1/widgets/resource_information_list.dart';
import 'package:flutter_application_1/widgets/map_place_preview.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'accessibility_cards_09_12_test.dart' as f;

const ramp = 'rampa_acesso', toilet = 'banheiro_acessivel';
MapPlace candidate(
  String first,
  String second, {
  String category = 'saude',
  String child = '',
}) => MapPlace.internal({
  'id_local': 1,
  'nome': 'Sintético',
  'categoria': category,
  'subcategoria': child,
  'accessibility': {
    ramp: {'state': first},
    toilet: {'state': second},
  },
});
Map<String, dynamic> envelope([int id = 1]) => {
  'count': 1,
  'next': null,
  'version': 'version-1',
  'scope': {'coverage_complete': true},
  'results': [
    {'id_local': id, 'canonical_id': 'acessoja:$id', 'nome': 'Synthetic $id'},
  ],
};
void main() {
  final truth =
      jsonDecode(
            File('../locais/data/discovery_examples.json').readAsStringSync(),
          )
          as Map;
  for (final raw in truth['cases'] as List) {
    final c = raw as Map;
    test('T006 T008 T009 T010 T011 shared truth ${c['name']}', () {
      final p = candidate(c['states'][0] as String, c['states'][1] as String);
      final manual = DiscoveryFilters(
        resources: [ramp, toilet],
        includeUnknown: c['unknown'] as bool,
      );
      expect(manual.matches(p), c['all']);
      expect(
        manual.copyWith(resourceMode: ResourceMode.any).matches(p),
        c['any'],
      );
      final ranking = DiscoveryFilterState(
        filters: manual.copyWith(resourceMode: ResourceMode.prioritize),
      );
      expect(ranking.score(p), c['score']);
      expect(ranking.matches(p), isTrue);
    });
  }

  setUp(() {
    AppHttp.clearSession();
    AppHttp.token = 'synthetic-token';
  });
  tearDown(AppHttp.clearSession);
  test('T005 exact three-feature scores deduplicate repeated resource IDs', () {
    final keys = [ramp, toilet, 'piso_tatil'];
    final filters = DiscoveryFilters(
      resources: [...keys, ramp],
      resourceMode: ResourceMode.prioritize,
    );
    for (var count = 0; count <= 3; count++) {
      final p = MapPlace.internal({
        'id_local': count + 1,
        'nome': 'Synthetic',
        'accessibility': {
          for (final key in keys.take(count))
            key: {'state': 'presence_reported'},
        },
      });
      expect(DiscoveryFilterState(filters: filters).score(p), count);
      expect(filters.matches(p), isTrue);
    }
  });
  test(
    'T059 consolidated unknown cannot be resurrected by a legacy OSM tag',
    () {
      final p = MapPlace.external({
        'external_id': 'osm:node:99',
        'name': 'Synthetic',
        'accessibility': {
          toilet: {'state': 'unknown'},
        },
        'accessibility_data': {'toilets:wheelchair': 'yes'},
      });
      expect(p.accessibility(toilet), AccessibilityValue.unknown);
      expect(DiscoveryFilterState().applyPreferences([toilet]).score(p), 0);
    },
  );
  test(
    'T063 T064 unified controller requires restart after a changed or expired page',
    () async {
      var calls = 0;
      AppHttp.client = MockClient(
        (_) async => calls++ == 0
            ? f.response({
                ...envelope(),
                'next':
                    '/api/locais/descoberta/?paginated=true&page_size=20&ordering=name&cursor=valid',
              })
            : f.response({'code': 'discovery_changed'}, 409),
      );
      final controller = DiscoveryController();
      addTearDown(controller.dispose);
      controller.reset(DiscoveryQuery(unified: true));
      await Future<void>.delayed(Duration.zero);
      expect(controller.places.length, 1);
      await controller.load();
      expect(controller.restartRequired, isTrue);
      expect(controller.places.length, 1);
      await controller.load();
      expect(calls, 2);
    },
  );
  for (final mode in ResourceMode.values) {
    test('T013 empty manual selection is neutral in ${mode.name}', () {
      expect(
        DiscoveryFilters(
          resourceMode: mode,
        ).matches(candidate('absence_reported', 'limited')),
        isTrue,
      );
    });
  }
  for (final state in [
    'presence_reported',
    'absence_reported',
    'unknown',
    'divergent',
    'limited',
    'not_applicable',
  ]) {
    for (final unknown in [false, true]) {
      test('T006 T009 T010 exact states $state unknown=$unknown', () {
        final p = candidate(state, 'absence_reported');
        final stateOnly = DiscoveryFilterState(
          filters: DiscoveryFilters(
            resources: [ramp, ramp],
            resourceMode: ResourceMode.prioritize,
          ),
        );
        expect(stateOnly.score(p), state == 'presence_reported' ? 1 : 0);
        final eligible =
            state == 'presence_reported' || (unknown && state == 'unknown');
        expect(
          DiscoveryFilters(
            resources: [ramp, toilet],
            includeUnknown: unknown,
          ).matches(p),
          isFalse,
        );
        expect(
          DiscoveryFilters(
            resources: [ramp, toilet],
            resourceMode: ResourceMode.any,
            includeUnknown: unknown,
          ).matches(p),
          eligible,
        );
        expect(stateOnly.matches(p), isTrue);
      });
    }
  }
  test(
    'T021 T022 independent manual restriction and deduplicated priorities',
    () {
      final manual = DiscoveryFilters(resources: [ramp]);
      final applied = DiscoveryFilterState(
        filters: manual,
      ).applyPreferences([ramp, toilet]);
      expect(applied.filters.resources, {ramp});
      expect(
        applied.matches(candidate('absence_reported', 'presence_reported')),
        isFalse,
      );
      expect(
        applied.matches(candidate('presence_reported', 'absence_reported')),
        isTrue,
      );
      expect(applied.deactivate().filters.resources, {ramp});
      final both = DiscoveryFilterState(
        filters: manual.copyWith(resourceMode: ResourceMode.prioritize),
      ).applyPreferences([ramp, toilet]);
      expect(both.priorityResources, {ramp, toilet});
      expect(
        both.score(candidate('presence_reported', 'presence_reported')),
        2,
      );
    },
  );
  test(
    'T023 personal strict all and explicit any do not alter manual mode',
    () {
      final applied = DiscoveryFilterState().applyPreferences([ramp, toilet]);
      expect(applied.personalMode, PersonalizationMode.prioritize);
      final all = applied.withPersonalMode(PersonalizationMode.all);
      expect(
        all.matches(candidate('presence_reported', 'absence_reported')),
        isFalse,
      );
      final any = all.withPersonalMode(PersonalizationMode.any);
      expect(
        any.matches(candidate('presence_reported', 'absence_reported')),
        isTrue,
      );
      expect(any.filters.resourceMode, ResourceMode.all);
    },
  );
  test('T028 T035 immutable snapshot and twice touched manual ownership', () {
    final saved = {ramp, toilet};
    final state = DiscoveryFilterState().applyPreferences(saved);
    saved.remove(toilet);
    expect(state.appliedPreferences, {ramp, toilet});
    final owned = state.commitDraft(state.filters, {ramp});
    expect(owned.preferenceSnapshot, {ramp, toilet});
    expect(owned.appliedPreferences, {toilet});
    expect(owned.withPersonalMode(PersonalizationMode.all).appliedPreferences, {
      toilet,
    });
    expect(owned.deactivate().filters.resources, isEmpty);
    expect(owned.applyPreferences([ramp]).appliedPreferences, {ramp});
  });
  test('T038 T039 T040 T045 hierarchy derives parents and clears children', () {
    final broad = DiscoveryFilters(
      categories: ['saude', 'educacao'],
      subcategories: ['hospital'],
    );
    expect(
      broad.matches(candidate('unknown', 'unknown', child: 'hospital')),
      isTrue,
    );
    expect(broad.matches(candidate('unknown', 'unknown', child: '')), isFalse);
    expect(
      broad.matches(candidate('unknown', 'unknown', category: 'educacao')),
      isTrue,
    );
    expect(DiscoveryFilters(subcategories: ['hospital']).categories, {'saude'});
    expect(broad.copyWith(categories: ['educacao']).subcategories, isEmpty);
    expect(
      () => DiscoveryFilters(
        categories: ['educacao'],
        subcategories: ['hospital'],
      ),
      throwsFormatException,
    );
    expect(placeSubcategories['biblioteca']!['parent'], 'outros');
  });
  test(
    'T030 T075 private snapshot excluded from URL parameters and identity changes',
    () {
      final state = DiscoveryFilterState().applyPreferences([toilet]);
      final query = DiscoveryQuery(state: state, unified: true);
      expect(query.parameters.toString(), isNot(contains(toilet)));
      expect(query.privateBody!['personalization']['resources'], [toilet]);
      expect(
        query.identity,
        isNot(
          DiscoveryQuery(
            state: state.withPersonalMode(PersonalizationMode.all),
            unified: true,
          ).identity,
        ),
      );
      expect(
        DiscoveryQuery(
          filters: DiscoveryFilters(
            resources: [ramp],
            resourceMode: ResourceMode.prioritize,
            includeUnknown: true,
          ),
        ).parameters.containsKey('incluir_desconhecidos'),
        isFalse,
      );
    },
  );
  test('T075 T078 private POST pages carry snapshot only in JSON', () async {
    final calls = <http.Request>[];
    AppHttp.client = MockClient((request) async {
      calls.add(request);
      return f.response(envelope());
    });
    final query = DiscoveryQuery(
      unified: true,
      state: DiscoveryFilterState().applyPreferences([toilet]),
    );
    await const PlacesService().fetchDiscoveryPage(
      query: query,
      next: 'opaque:signed-token',
    );
    expect(calls.single.method, 'POST');
    expect(calls.single.url.query, isEmpty);
    expect(calls.single.url.fragment, isEmpty);
    expect(calls.single.url.toString(), isNot(contains(toilet)));
    expect(jsonDecode(calls.single.body)['personalization']['resources'], [
      toilet,
    ]);
    expect(jsonDecode(calls.single.body)['cursor'], 'opaque:signed-token');
  });
  for (final link in [
    'https://foreign.invalid/token',
    '//foreign.invalid/token',
    '/external/path',
    'token?resource=private',
  ]) {
    test(
      'T079 rejects unsafe private continuation $link before any HTTP',
      () async {
        var calls = 0;
        AppHttp.client = MockClient((_) async {
          calls++;
          return f.response(envelope());
        });
        final query = DiscoveryQuery(
          unified: true,
          state: DiscoveryFilterState().applyPreferences([toilet]),
        );
        await expectLater(
          const PlacesService().fetchDiscoveryPage(query: query, next: link),
          throwsFormatException,
        );
        expect(calls, 0);
      },
    );
  }
  test(
    'T079 public continuation validates host, path and exact criteria',
    () async {
      var calls = 0;
      AppHttp.client = MockClient((_) async {
        calls++;
        return f.response(envelope());
      });
      final query = DiscoveryQuery(unified: true, search: 'Sintético');
      for (final link in [
        'https://foreign.invalid/api/locais/descoberta/',
        '/api/locais/descoberta/?search=changed',
        '/api/other/',
      ]) {
        await expectLater(
          const PlacesService().fetchDiscoveryPage(query: query, next: link),
          throwsFormatException,
        );
      }
      expect(calls, 0);
    },
  );
  test('T071 T073 late success after session change is discarded', () async {
    final pending = Completer<http.Response>();
    AppHttp.client = MockClient((_) => pending.future);
    final query = DiscoveryQuery(
      unified: true,
      state: DiscoveryFilterState().applyPreferences([ramp]),
    );
    final load = const PlacesService().fetchDiscoveryPage(query: query);
    final expectation = expectLater(load, throwsA(isA<PlacesException>()));
    AppHttp.clearSession();
    pending.complete(f.response(envelope()));
    await expectation;
  });
  test(
    'T072 private 401 clears session; public discovery remains usable',
    () async {
      AppHttp.client = MockClient((request) async => f.response({}, 401));
      await expectLater(
        const PlacesService().fetchDiscoveryPage(
          query: DiscoveryQuery(
            unified: true,
            state: DiscoveryFilterState().applyPreferences([ramp]),
          ),
        ),
        throwsA(isA<PlacesException>()),
      );
      expect(AppHttp.authenticated, isFalse);
      AppHttp.client = MockClient((_) async => f.response(envelope()));
      final page = await const PlacesService().fetchDiscoveryPage(
        query: DiscoveryQuery(unified: true),
      );
      expect(page.places.single.id, 'acessoja:1');
    },
  );
  test('T031 T073 query B owns list and loading after late A', () async {
    final old = Completer<http.Response>(),
        current = Completer<http.Response>();
    var calls = 0;
    AppHttp.client = MockClient(
      (_) => calls++ == 0 ? old.future : current.future,
    );
    final controller = DiscoveryController();
    addTearDown(controller.dispose);
    controller.reset(DiscoveryQuery(unified: true, search: 'A'));
    controller.reset(DiscoveryQuery(unified: true, search: 'B'));
    old.complete(f.response(envelope(1)));
    await Future<void>.delayed(Duration.zero);
    expect(controller.loading, isTrue);
    expect(controller.places, isEmpty);
    current.complete(f.response(envelope(2)));
    await Future<void>.delayed(Duration.zero);
    expect(controller.places.single.id, 'acessoja:2');
    expect(controller.loading, isFalse);
  });
  testWidgets(
    'T081 T083 preferred groups precede other groups without duplicate resources',
    (tester) async {
      await tester.pumpWidget(
        f.harness(
          const Scaffold(
            body: SingleChildScrollView(
              child: ResourceInformationList(preferred: {'piso_tatil'}),
            ),
          ),
        ),
      );
      expect(find.text('Recursos importantes para sua busca'), findsOneWidget);
      expect(find.text('Outros recursos de acessibilidade'), findsOneWidget);
      final first = tester
          .getTopLeft(
            find.byKey(const ValueKey('resource-information-piso_tatil')),
          )
          .dy;
      final other = tester
          .getTopLeft(
            find.byKey(const ValueKey('resource-information-rampa_acesso')),
          )
          .dy;
      expect(first, lessThan(other));
      for (final id in AccessibilityCatalog.ids) {
        expect(
          find.byKey(ValueKey('resource-information-$id')),
          findsOneWidget,
        );
      }
    },
  );
  for (final warning in ['divergent', 'absence_reported', 'limited']) {
    testWidgets('T085 T086 compact preserves hidden warning $warning', (
      tester,
    ) async {
      await tester.pumpWidget(
        f.harness(
          Scaffold(
            body: ResourceInformationList(
              compact: true,
              preferred: const {ramp, toilet, 'cao_guia'},
              information: {
                'piso_tatil': {'state': warning},
              },
              onViewAll: () {},
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Há alertas em 1 outros recursos'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('preview-accessibility-more')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('resource-information-piso_tatil')),
        findsNothing,
      );
    });
  }
  testWidgets(
    'T081 T083 actual expanded internal panel passes only applied personal selection',
    (tester) async {
      AppHttp.client = MockClient((_) async => f.response({}, 503));
      await tester.pumpWidget(
        f.harness(
          Scaffold(
            body: MapPlacePreview(
              place: f.record(1, {'piso_tatil': 'presence_reported'}),
              distanceLabel: '',
              onDetailsPressed: () {},
              onRoutePressed: null,
              detailed: true,
              preferredResources: const {'piso_tatil'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recursos importantes para sua busca'), findsOneWidget);
      final personal = tester
          .getTopLeft(
            find.byKey(const ValueKey('resource-information-piso_tatil')),
          )
          .dy;
      final other = tester
          .getTopLeft(
            find.byKey(const ValueKey('resource-information-rampa_acesso')),
          )
          .dy;
      expect(personal, lessThan(other));
    },
  );
  testWidgets(
    'T036 T067 guest entry clears private session without authenticating',
    (tester) async {
      var entered = 0;
      await tester.pumpWidget(f.harness(LoginScreen(onGuest: () => entered++)));
      await f.tap(tester, find.byKey(const ValueKey('login-explore-guest')));
      expect(entered, 1);
      expect(AppHttp.authenticated, isFalse);
    },
  );
  testWidgets(
    'T049 hidden selected children survive accent-insensitive chooser search',
    (tester) async {
      DiscoveryFilters? applied;
      await tester.pumpWidget(
        f.harness(
          Scaffold(
            body: AccessibilityFilterPanel(
              initial: DiscoveryFilters(
                categories: ['saude', 'educacao'],
                subcategories: ['hospital'],
              ),
              onApply: (value, _) => applied = value,
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('category-picker-search')),
        'clinica',
      );
      await tester.pumpAndSettle();
      final group = find.byKey(
        const PageStorageKey('filter-category-group-saude'),
      );
      expect(group, findsOneWidget);
      final arrow = find.descendant(
        of: group,
        matching: find.byIcon(Icons.expand_more),
      );
      await f.tap(tester, arrow);
      await f.tap(
        tester,
        find.byKey(const ValueKey('filter-subcategory-clinica')),
      );
      await f.tap(tester, find.byKey(const ValueKey('map-apply-filters')));
      expect(applied!.subcategories, {'hospital', 'clinica'});
      expect(applied!.categories, {'saude', 'educacao'});
    },
  );
  testWidgets(
    'category search empty state is accessible and clearing restores draft selections',
    (tester) async {
      DiscoveryFilters? applied;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          f.harness(
            Scaffold(
              body: AccessibilityFilterPanel(
                initial: DiscoveryFilters(
                  categories: ['saude', 'educacao'],
                  subcategories: ['hospital'],
                  resources: [ramp],
                  resourceMode: ResourceMode.prioritize,
                ),
                onApply: (value, _) => applied = value,
                onCancel: () {},
              ),
            ),
          ),
        );

        await tester.enterText(
          find.byKey(const ValueKey('category-picker-search')),
          'xyz-nonexistent-qwerty',
        );
        await tester.pumpAndSettle();
        final emptyState = find.byKey(const ValueKey('category-search-empty'));
        expect(
          find.text(
            'Nenhuma categoria encontrada. Ajuste ou limpe a pesquisa.',
          ),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(emptyState).label,
          contains('Nenhuma categoria encontrada'),
        );
        expect(
          find.byKey(const ValueKey('filter-category-saude')),
          findsNothing,
        );
        expect(applied, isNull);

        await tester.enterText(
          find.byKey(const ValueKey('category-picker-search')),
          '',
        );
        await tester.pumpAndSettle();
        expect(emptyState, findsNothing);
        expect(
          find.byKey(const ValueKey('filter-category-saude')),
          findsOneWidget,
        );
        final saudeGroup = find.byKey(
          const PageStorageKey('filter-category-group-saude'),
        );
        await f.tap(
          tester,
          find.descendant(
            of: saudeGroup,
            matching: find.byIcon(Icons.expand_more),
          ),
        );
        final hospital = tester.widget<CheckboxListTile>(
          find.byKey(const ValueKey('filter-subcategory-hospital')),
        );
        expect(hospital.value, isTrue);

        await f.tap(tester, find.byKey(const ValueKey('map-apply-filters')));
        expect(applied!.categories, {'saude', 'educacao'});
        expect(applied!.subcategories, {'hospital'});
        expect(applied!.resources, {ramp});
        expect(applied!.resourceMode, ResourceMode.prioritize);
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets('category search empty state is localized in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      f.harness(
        Scaffold(
          body: AccessibilityFilterPanel(
            initial: DiscoveryFilters(),
            onApply: (_, _) {},
            onCancel: () {},
          ),
        ),
        language: 'en',
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('category-picker-search')),
      'xyz-nonexistent-qwerty',
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No categories found. Adjust or clear your search.'),
      findsOneWidget,
    );
  });
  testWidgets('T025 T026 mode and child draft remain uncommitted until Apply', (
    tester,
  ) async {
    DiscoveryFilters? applied;
    var cancels = 0;
    await tester.pumpWidget(
      f.harness(
        Scaffold(
          body: AccessibilityFilterPanel(
            initial: DiscoveryFilters(),
            onApply: (value, _) => applied = value,
            onCancel: () => cancels++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('filter-resource-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Priorizar').last);
    await tester.pumpAndSettle();
    expect(applied, isNull);
    await f.tap(tester, find.byKey(const ValueKey('map-cancel-filters')));
    expect(cancels, 1);
    expect(applied, isNull);
    await f.tap(tester, find.byKey(const ValueKey('map-apply-filters')));
    expect(applied!.resourceMode, ResourceMode.prioritize);
  });
}
