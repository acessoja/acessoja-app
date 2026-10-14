import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/accessibility_catalog.dart';
import 'package:flutter_application_1/models/accessibility_survey.dart';
import 'package:flutter_application_1/models/discovery_filters.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/screens/accessibility_preferences_screen.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/services/accessibility_preferences_service.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/places_service.dart';
import 'package:flutter_application_1/widgets/accessibility_filter_panel.dart';
import 'package:flutter_application_1/widgets/accessibility_results_card.dart';
import 'package:flutter_application_1/widgets/active_discovery_filters.dart';
import 'package:flutter_application_1/widgets/map_search_sheet.dart';

http.Response response(Object value, [int status = 200]) => http.Response(
  jsonEncode(value), status, headers: {'content-type': 'application/json; charset=utf-8'});
Map<String, dynamic> record(int id, Map<String, String> states, {String category = 'cafeteria', String? osmId}) => {
  'id_local': id, 'nome': 'Local $id', 'endereco': 'Rua $id', 'categoria': category,
  'latitude': -16.3267, 'longitude': -48.9528, 'osm_id': osmId,
  'accessibility': {for (final item in states.entries) item.key: {'state': item.value}},
};
MapPlace place(Map<String, String> states, {String category = 'cafeteria'}) => MapPlace.internal(record(1, states, category: category));
class OfflineTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => const AssetImage('assets/map_placeholder.png');
}
class FakePreferences extends AccessibilityPreferencesService {
  Set<String> stored;
  int loads = 0, saves = 0;
  Future<AccessibilityPreferences> Function()? loadHandler;
  Future<AccessibilityPreferences> Function(Set<String>)? saveHandler;
  FakePreferences([Iterable<String> resources = const []]) : stored = Set.from(resources);
  @override
  Future<AccessibilityPreferences> load() async {
    loads++;
    return loadHandler == null ? AccessibilityPreferences(1, stored, const []) : await loadHandler!();
  }
  @override
  Future<AccessibilityPreferences> save(Iterable<String> resources) async {
    saves++;
    final selected = Set<String>.from(resources);
    if (saveHandler != null) { return saveHandler!(selected); }
    stored = selected;
    return AccessibilityPreferences(1, stored, const []);
  }
}
Widget harness(Widget child, {double scale = 1, bool dark = false, String language = 'pt'}) =>
  AppThemeScope(controller: AppThemeController(), child: MaterialApp(
    locale: Locale(language), localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales, theme: dark ? AppThemes.dark() : AppThemes.light(),
    builder: (context, widget) => MediaQuery(data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale)), child: widget!), home: child));
Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).last;
    // A lazy list may have disposed a target above the current position.
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 250, scrollable: scrollable, maxScrolls: 100);
    }
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  expect(finder.hitTestable(), findsOneWidget);
}
Future<void> tap(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
Finder inSearch(String key) => find.descendant(of: find.byType(MapSearchSheet), matching: find.byKey(ValueKey(key)));
Future<void> openSearch(WidgetTester tester) async {
  await tap(tester, find.byKey(const ValueKey('map-open-search')));
}
Future<void> openFilters(WidgetTester tester) async {
  await tap(tester, inSearch('open-discovery-filters'));
}
Future<void> pumpMap(WidgetTester tester, FakePreferences prefs) async {
  AppHttp.client = MockClient((request) async {
    if (request.url.path == '/api/locais/') {
      return response([record(1, {'rampa_acesso': 'presence_reported', 'piso_tatil': 'presence_reported'})]);
    }
    if (request.url.path == '/api/locais/externos/') { return response({'results': [], 'truncated': false}); }
    return response({});
  });
  await tester.pumpWidget(harness(MainScreen(userName: 'prefs', preferencesService: prefs,
    trackLocation: false, tileProvider: OfflineTiles())));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() { AppHttp.clearSession(); AppHttp.token = 'backend-token'; AppHttp.userId = 1; });
  tearDown(() { AppHttp.clearSession(); AppHttp.client.close(); });

  group('resource contract and consolidated evidence', () {
    test('catalog aligns eight existing questions and two new observed resources', () {
      expect(AccessibilityCatalog.ids, hasLength(10));
      expect(SurveyContract.questions.map((q) => q.id).every(AccessibilityCatalog.ids.contains), isTrue);
      expect(AccessibilityCatalog.find('piso_tatil')!.questionId, isNull);
      expect(AccessibilityCatalog.find('sinalizacao_tatil')!.questionId, 'sinalizacao_tatil');
    });
    test('both historical boolean values stay unknown', () {
      for (final flag in [true, false]) {
        final old = MapPlace.internal({'rampa_acesso': flag, 'mesa_acessivel': flag, 'cao_guia': flag});
        expect(old.accessibility('rampa_acesso'), AccessibilityValue.unknown);
        expect(old.accessibilityFeatures, isEmpty);
        expect(old.data['mesa_acessivel'], flag);
      }
    });
    test('AND features, OR categories/sources, AND groups and empty groups', () {
      final filters = DiscoveryFilters(categories: ['cafeteria', 'restaurante'], sources: [PlaceSource.acessoja],
        resources: ['rampa_acesso', 'banheiro_acessivel']);
      expect(filters.matches(place({'rampa_acesso': 'presence_reported'})), isFalse);
      expect(filters.matches(place({'rampa_acesso': 'presence_reported', 'banheiro_acessivel': 'presence_reported'})), isTrue);
      expect(filters.matches(place({'rampa_acesso': 'presence_reported', 'banheiro_acessivel': 'presence_reported'}, category: 'banco')), isFalse);
      expect(DiscoveryFilters().matches(place({})), isTrue);
    });
    test('strict and incomplete modes preserve all six meanings', () {
      for (final state in ['presence_reported', 'absence_reported', 'unknown', 'divergent', 'not_applicable', 'limited']) {
        final candidate = place({'piso_tatil': state});
        expect(DiscoveryFilters(resources: ['piso_tatil']).matches(candidate), state == 'presence_reported');
        final permissive = DiscoveryFilters(resources: ['piso_tatil'], includeUnknown: true);
        expect(permissive.matches(candidate), ['presence_reported', 'unknown'].contains(state));
        if (state == 'unknown') { expect(permissive.missing(candidate), ['piso_tatil']); }
      }
    });
    test('invalid resource or category never becomes an ignored filter', () {
      expect(() => DiscoveryFilters(resources: ['invalid']), throwsFormatException);
      expect(() => DiscoveryFilters(categories: ['invalid']), throwsFormatException);
    });
    test('OSM wheelchair does not imply ramp, toilet, paving or Libras', () {
      final external = MapPlace.external({'external_id': 'osm:node:7', 'accessibility_data': {'wheelchair': 'yes'}});
      for (final key in AccessibilityCatalog.ids) { expect(external.accessibility(key), AccessibilityValue.unknown); }
      final toilet = MapPlace.external({'accessibility_data': {'toilets:wheelchair': 'yes'}});
      expect(toilet.accessibility('banheiro_acessivel'), AccessibilityValue.available);
      expect(toilet.accessibility('rampa_acesso'), AccessibilityValue.unknown);
    });
    test('deduplication precedes final filters and conflicts cannot reappear as external copies', () {
      final internal = MapPlace.internal(record(1, {'banheiro_acessivel': 'absence_reported'}, osmId: 'osm:node:7'));
      final external = MapPlace.external({'internal_id': 1, 'external_id': 'osm:node:7',
        'accessibility_data': {'toilets:wheelchair': 'yes'}, 'latitude': -16.3, 'longitude': -48.9});
      final merged = mergeMapPlaces([internal], [external]);
      expect(merged, hasLength(1));
      expect(merged.single.internalId, 1);
      expect(merged.single.origins, {PlaceSource.acessoja, PlaceSource.openstreetmap});
      expect(merged.single.accessibility('banheiro_acessivel'), AccessibilityValue.divergent);
      expect(merged.where(DiscoveryFilters(resources: ['banheiro_acessivel'], includeUnknown: true).matches), isEmpty);
    });
    test('linked response still consolidates during partial internal failure', () {
      final external = MapPlace.external({'internal_id': 1, 'external_id': 'osm:node:7',
        'linked_local': record(1, {'rampa_acesso': 'absence_reported'}), 'accessibility_data': {'wheelchair': 'yes'}});
      final merged = mergeMapPlaces([], [external]);
      expect(merged, hasLength(1));
      expect(merged.single.isExternal, isFalse);
      expect(DiscoveryFilters(resources: ['rampa_acesso'], includeUnknown: true).matches(merged.single), isFalse);
    });
    test('multiple explicit associated OSM objects cannot overwrite conflicting evidence', () {
      final own = MapPlace.internal(record(1, {}));
      final results = mergeMapPlaces([own], [for (final value in ['no', 'yes']) MapPlace.external({
        'internal_id': 1, 'external_id': 'osm:node:$value', 'accessibility_data': {'toilets:wheelchair': value}})]);
      expect(results, hasLength(1));
      expect(results.single.accessibility('banheiro_acessivel'), AccessibilityValue.divergent);
    });
    test('removing a criterion restores results from the original base', () {
      final base = [place({'rampa_acesso': 'presence_reported'}), place({'rampa_acesso': 'absence_reported'})];
      expect(base.where(DiscoveryFilters(resources: ['rampa_acesso']).matches), hasLength(1));
      expect(base.where(DiscoveryFilters().matches), hasLength(2));
    });
  });

  group('personalization ownership', () {
    test('apply union keeps category, sources, incomplete policy and prior resource', () {
      final prior = DiscoveryFilterState(filters: DiscoveryFilters(categories: ['cafeteria'],
        sources: [PlaceSource.openstreetmap], resources: ['rampa_acesso'], includeUnknown: true));
      final result = prior.applyPreferences(['rampa_acesso', 'piso_tatil']);
      expect(result.filters.resources, {'rampa_acesso', 'piso_tatil'});
      expect(result.addedByPreferences, {'piso_tatil'});
      expect(result.filters.categories, prior.filters.categories);
      expect(result.filters.sources, prior.filters.sources);
      expect(result.filters.includeUnknown, isTrue);
      expect(result.deactivate().filters.resources, {'rampa_acesso'});
    });
    test('manual removal is not automatically reapplied; deactivation preserves later additions', () {
      var state = DiscoveryFilterState().applyPreferences(['rampa_acesso', 'piso_tatil']);
      state = state.manual(state.filters.copyWith(resources: ['piso_tatil', 'sinalizacao_visual']));
      expect(state.adjusted, isTrue);
      expect(state.filters.resources.contains('rampa_acesso'), isFalse);
      expect(state.deactivate().filters.resources, {'sinalizacao_visual'});
    });
    test('a previously selected preference manually removed remains removed on disable', () {
      var state = DiscoveryFilterState(filters: DiscoveryFilters(resources: ['rampa_acesso']));
      state = state.applyPreferences(['rampa_acesso', 'piso_tatil']);
      state = state.manual(state.filters.copyWith(resources: ['piso_tatil']));
      expect(state.deactivate().filters.resources, isEmpty);
    });
    test('explicit off then on within a draft transfers ownership to the user', () {
      final state = DiscoveryFilterState().applyPreferences(['piso_tatil']);
      final manual = state.commitDraft(state.filters, {'piso_tatil'});
      expect(manual.adjusted, isTrue);
      expect(manual.deactivate().filters.resources, {'piso_tatil'});
    });
    test('clear search filters never mutates the saved preference source', () {
      final saved = {'rampa_acesso', 'piso_tatil'};
      final state = DiscoveryFilterState().applyPreferences(saved).clear();
      expect(state.personalized, isFalse);
      expect(state.filters.active, isFalse);
      expect(state.filters.includeUnknown, isFalse);
      expect(saved, {'rampa_acesso', 'piso_tatil'});
    });
    test('only explicit reapply restores removed preferences', () {
      var state = DiscoveryFilterState().applyPreferences(['piso_tatil']);
      state = state.manual(state.filters.copyWith(resources: []));
      expect(state.filters.resources, isEmpty);
      state = state.applyPreferences(['piso_tatil']);
      expect(state.filters.resources, {'piso_tatil'});
      expect(state.adjusted, isFalse);
    });
  });

  group('private service, session changes and paging', () {
    test('reads and saves only the current user endpoint, with server confirmation', () async {
      final requests = <http.Request>[];
      AppHttp.client = MockClient((request) async {
        requests.add(request);
        return response({'catalog_version': 1, 'resources': ['piso_tatil'], 'unavailable_resources': []});
      });
      const service = AccessibilityPreferencesService();
      expect((await service.load()).resources, {'piso_tatil'});
      expect((await service.save(['piso_tatil'])).resources, {'piso_tatil'});
      expect(requests.every((r) => r.url.path == '/api/usuarios/me/accessibility-preferences/'), isTrue);
      expect(requests.last.url.queryParameters, isEmpty);
      expect(jsonDecode(requests.last.body), {'resources': ['piso_tatil']});
      expect(requests.last.headers['Authorization'], 'Token backend-token');
    });
    test('invalid confirmation never pretends a save succeeded', () async {
      AppHttp.client = MockClient((_) async => response({'catalog_version': 1, 'resources': [], 'unavailable_resources': []}));
      await expectLater(const AccessibilityPreferencesService().save(['piso_tatil']), throwsFormatException);
    });
    test('retired or new unknown IDs remain visible for explicit resolution', () {
      final parsed = AccessibilityPreferences.fromJson({'catalog_version': 2, 'resources': ['retired', 'piso_tatil'],
        'unavailable_resources': ['retired']});
      expect(parsed.resources, {'retired', 'piso_tatil'});
      expect(parsed.unavailable, {'retired'});
    });
    test('late response of another session is rejected', () async {
      final pending = Completer<http.Response>();
      AppHttp.client = MockClient((_) => pending.future);
      final loading = const AccessibilityPreferencesService().load();
      final expected = expectLater(loading, throwsA(isA<PreferencesException>()));
      AppHttp.token = 'other-account'; AppHttp.userId = 2;
      pending.complete(response({'catalog_version': 1, 'resources': ['piso_tatil'], 'unavailable_resources': []}));
      await expected;
    });
    test('expired current session clears credentials; no external request receives preferences', () async {
      AppHttp.client = MockClient((request) async {
        expect(request.url.path, '/api/usuarios/me/accessibility-preferences/');
        return response({}, 401);
      });
      await expectLater(const AccessibilityPreferencesService().load(), throwsA(isA<PreferencesException>()));
      expect(AppHttp.authenticated, isFalse);
    });
    test('old logout response cannot clear a newer login', () async {
      final pending = Completer<http.Response>();
      AppHttp.client = MockClient((_) => pending.future);
      final logout = AppHttp.logout();
      AppHttp.clearSession(); AppHttp.token = 'new-login'; AppHttp.userId = 2;
      pending.complete(response({})); await logout;
      expect(AppHttp.token, 'new-login');
      expect(AppHttp.userId, 2);
    });
    test('internal pagination follows all pages without dropping the filter contract', () async {
      AppHttp.client = MockClient((request) async => request.url.queryParameters['page'] == '2'
        ? response({'results': [record(2, {})], 'next': null})
        : response({'results': [record(1, {})], 'next': '?page=2'}));
      final results = await const PlacesService().fetchPlaces(resources: {'piso_tatil'}, includeUnknown: true);
      expect(results.map((r) => r['id_local']), [1, 2]);
    });
    test('foreign or cyclic next page is rejected without forwarding backend credentials', () async {
      for (final next in ['https://third-party.test/api/locais/?page=2', '/api/locais/']) {
        var calls = 0;
        AppHttp.client = MockClient((_) async { calls++; return response({'results': [record(1, {})], 'next': next}); });
        await expectLater(const PlacesService().fetchPlaces(), throwsFormatException);
        expect(calls, 1);
      }
    });
  });

  testWidgets('profile loads empty, edits, preserves failed save, retries and confirms a clear', (tester) async {
    final service = FakePreferences();
    await tester.pumpWidget(harness(AccessibilityPreferencesScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sem preferências cadastradas'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('preference-piso_tatil')));
    service.saveHandler = (_) async => throw const PreferencesException(503);
    await tap(tester, find.byKey(const ValueKey('preferences-save')));
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('preference-piso_tatil'))).value, isTrue);
    expect(service.stored, isEmpty);
    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    service.saveHandler = null;
    await tap(tester, find.byKey(const ValueKey('preferences-save')));
    expect(service.stored, {'piso_tatil'});
    await tap(tester, find.byKey(const ValueKey('preferences-clear')));
    expect(service.stored, {'piso_tatil'});
    await tap(tester, find.byKey(const ValueKey('preferences-save')));
    expect(service.stored, isEmpty);
  });
  testWidgets('details distinguish explicit new resource information from a failed community fetch', (tester) async {
    AppHttp.client = MockClient((_) async => response({}, 503));
    await tester.pumpWidget(harness(const Scaffold(body: SingleChildScrollView(child: AccessibilityResultsCard(
      localId: 1, registeredData: {'accessibility_information': {'piso_tatil': {
        'state': 'presence_reported', 'source': 'acessoja_registration', 'observed_at': null,
        'note': 'Piso de alerta na entrada', 'received_at': '2026-10-13T12:00:00Z'}}})))));
    await tester.pumpAndSettle();
    expect(find.text('Piso tátil'), findsOneWidget);
    expect(find.text('Piso de alerta na entrada'), findsOneWidget);
    expect(find.textContaining('Não foi possível carregar os resultados'), findsOneWidget);
    expect(find.textContaining('Observação informada:'), findsNothing);
  });
  testWidgets('profile load failure has retry and cannot overwrite saved choices', (tester) async {
    final service = FakePreferences(['rampa_acesso']);
    service.loadHandler = () async => throw const PreferencesException(503);
    await tester.pumpWidget(harness(AccessibilityPreferencesScreen(service: service)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('preferences-save')), findsNothing);
    service.loadHandler = null;
    await tap(tester, find.byKey(const ValueKey('preferences-retry')));
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('preference-rampa_acesso'))).value, isTrue);
    expect(service.stored, {'rampa_acesso'});
  });
  testWidgets('retired choice requires an explicit removal', (tester) async {
    final service = FakePreferences(['retired', 'piso_tatil']);
    service.loadHandler = () async => AccessibilityPreferences(2, service.stored, ['retired']);
    await tester.pumpWidget(harness(AccessibilityPreferencesScreen(service: service)));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('preferences-save')));
    expect(service.saves, 0);
    await tap(tester, find.byTooltip('Remover retired'));
    await tap(tester, find.byKey(const ValueKey('preferences-save')));
    expect(service.stored, {'piso_tatil'});
  });
  testWidgets('session change erases profile draft and rejects pending results', (tester) async {
    final service = FakePreferences(); final pending = Completer<AccessibilityPreferences>();
    service.loadHandler = () => pending.future;
    await tester.pumpWidget(harness(AccessibilityPreferencesScreen(service: service)));
    await tester.pump();
    AppHttp.clearSession();
    pending.complete(AccessibilityPreferences(1, ['piso_tatil'], const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('preference-piso_tatil')), findsNothing);
    expect(find.textContaining('Sessão expirada'), findsOneWidget);
  });
  testWidgets('pending save stays unconfirmed and duplicate taps do not send again', (tester) async {
    final service = FakePreferences(); final pending = Completer<AccessibilityPreferences>();
    service.saveHandler = (_) => pending.future;
    await tester.pumpWidget(harness(AccessibilityPreferencesScreen(service: service)));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('preference-rampa_acesso')));
    await reveal(tester, find.byKey(const ValueKey('preferences-save')));
    await tester.tap(find.byKey(const ValueKey('preferences-save'))); await tester.pump();
    await tester.tap(find.byKey(const ValueKey('preferences-save'))); await tester.pump();
    expect(service.saves, 1);
    expect(find.textContaining('Preferências salvas.'), findsNothing);
    pending.complete(AccessibilityPreferences(1, ['rampa_acesso'], const [])); await tester.pumpAndSettle();
    expect(find.textContaining('Preferências salvas.'), findsOneWidget);
  });
  testWidgets('filter panel combines groups and cancellation never calls apply', (tester) async {
    DiscoveryFilters? applied; var cancels = 0;
    await tester.pumpWidget(harness(Scaffold(body: AccessibilityFilterPanel(initial: DiscoveryFilters(),
      onApply: (value, _) { applied = value; }, onCancel: () { cancels++; }))));
    await tap(tester, find.byKey(const ValueKey('filter-category-cafeteria')));
    await tap(tester, find.byKey(const ValueKey('filter-source-openstreetmap')));
    await tap(tester, find.byKey(const ValueKey('filter-resource-rampa_acesso')));
    await tap(tester, find.byKey(const ValueKey('filter-resource-banheiro_acessivel')));
    await tap(tester, find.byKey(const ValueKey('map-cancel-filters')));
    expect(cancels, 1); expect(applied, isNull);
    await tap(tester, find.byKey(const ValueKey('map-apply-filters')));
    expect(applied!.resources, {'rampa_acesso', 'banheiro_acessivel'});
    expect(applied!.categories, {'cafeteria'}); expect(applied!.sources, {PlaceSource.openstreetmap});
  });
  testWidgets('keyboard can select and accessible criteria chips can remove one resource', (tester) async {
    await tester.pumpWidget(harness(Scaffold(body: AccessibilityFilterPanel(initial: DiscoveryFilters(),
      onApply: (_, __) {}, onCancel: () {}))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space); await tester.pump();
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('filter-category-restaurante'))).value, isTrue);
    DiscoveryFilters? changed;
    await tester.pumpWidget(harness(Scaffold(body: ActiveDiscoveryFilters(
      state: DiscoveryFilterState(filters: DiscoveryFilters(resources: ['piso_tatil'])),
      onChange: (value) { changed = value; }, onClear: () {}, onUsePreferences: () {}, onDeactivate: () {}, onConfigure: () {}))));
    await tap(tester, find.byTooltip('Remover Piso tátil'));
    expect(changed!.resources, isEmpty);
  });
  testWidgets('manual search, preference use and clear preserve query and saved profile', (tester) async {
    final service = FakePreferences(['rampa_acesso']); await pumpMap(tester, service);
    expect(service.loads, 0);
    await openSearch(tester);
    await tester.enterText(find.byKey(const ValueKey('map-place-search')), 'Local');
    await tester.pump(const Duration(milliseconds: 350));
    await tap(tester, inSearch('use-accessibility-preferences'));
    expect(service.loads, 1);
    expect(inSearch('active-filter-resource-rampa_acesso'), findsOneWidget);
    await tap(tester, inSearch('clear-discovery-filters'));
    expect(inSearch('active-filter-resource-rampa_acesso'), findsNothing);
    expect(service.stored, {'rampa_acesso'});
    expect(tester.widget<TextField>(find.byKey(const ValueKey('map-place-search'))).controller!.text, 'Local');
  });
  testWidgets('late preferences cannot overwrite a manual draft and applied changes', (tester) async {
    final service = FakePreferences(); final pending = Completer<AccessibilityPreferences>();
    service.loadHandler = () => pending.future;
    await pumpMap(tester, service); await openSearch(tester);
    await tester.ensureVisible(inSearch('use-accessibility-preferences'));
    await tester.tap(inSearch('use-accessibility-preferences')); await tester.pump();
    await openFilters(tester);
    await tap(tester, find.byKey(const ValueKey('filter-resource-piso_tatil')));
    await tap(tester, find.byKey(const ValueKey('map-apply-filters')));
    pending.complete(AccessibilityPreferences(1, ['rampa_acesso'], const [])); await tester.pumpAndSettle();
    expect(inSearch('active-filter-resource-piso_tatil'), findsOneWidget);
    expect(inSearch('active-filter-resource-rampa_acesso'), findsNothing);
  });
  testWidgets('logout removes personalized criteria and pending account responses', (tester) async {
    final service = FakePreferences(['piso_tatil']); await pumpMap(tester, service); await openSearch(tester);
    await tap(tester, inSearch('use-accessibility-preferences'));
    expect(inSearch('active-filter-resource-piso_tatil'), findsOneWidget);
    await openFilters(tester);
    AppHttp.clearSession(); await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('filter-resource-piso_tatil'))).value, isFalse);
    await tap(tester, find.byKey(const ValueKey('map-cancel-filters')));
    expect(inSearch('active-filter-resource-piso_tatil'), findsNothing);
    expect(service.stored, {'piso_tatil'});
  });
  testWidgets('empty preferences, load failure and guest keep manual filters usable', (tester) async {
    final service = FakePreferences(); await pumpMap(tester, service); await openSearch(tester);
    await tap(tester, inSearch('use-accessibility-preferences'));
    expect(find.textContaining('Sem preferências cadastradas.'), findsWidgets);
    service.loadHandler = () async => throw const PreferencesException(503);
    await tap(tester, inSearch('use-accessibility-preferences'));
    expect(find.textContaining('Não foi possível consultar'), findsWidgets);
    AppHttp.clearSession(); await tester.pumpAndSettle();
    await tap(tester, inSearch('use-accessibility-preferences'));
    expect(find.textContaining('A busca e os filtros manuais continuam disponíveis.'), findsWidgets);
    await openFilters(tester);
    await tap(tester, find.byKey(const ValueKey('filter-resource-rampa_acesso')));
    await tap(tester, find.byKey(const ValueKey('map-apply-filters')));
    expect(inSearch('active-filter-resource-rampa_acesso'), findsOneWidget);
  });

  for (final size in [const Size(320, 640), const Size(360, 740), const Size(390, 844),
    const Size(800, 1000), const Size(1280, 800), const Size(640, 320)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('profile and filter layout ${size.width}x${size.height} scale $scale dark $dark', (tester) async {
          tester.view.physicalSize = size; tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
          final service = FakePreferences(['piso_tatil', 'atendimento_libras']);
          await tester.pumpWidget(harness(AccessibilityPreferencesScreen(service: service), scale: scale, dark: dark));
          await tester.pumpAndSettle();
          await tap(tester, find.byKey(const ValueKey('preferences-save')));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(harness(Scaffold(body: AccessibilityFilterPanel(
            initial: DiscoveryFilters(resources: AccessibilityCatalog.ids), onApply: (_, __) {}, onCancel: () {})),
            scale: scale, dark: dark, language: 'en'));
          await tap(tester, find.byKey(const ValueKey('map-apply-filters')));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(harness(Scaffold(body: SingleChildScrollView(child: ActiveDiscoveryFilters(
            state: DiscoveryFilterState(filters: DiscoveryFilters(resources: AccessibilityCatalog.ids)),
            onChange: (_) {}, onClear: () {}, onUsePreferences: () {}, onDeactivate: () {}, onConfigure: () {}))),
            scale: scale, dark: dark));
          await tap(tester, find.byKey(const ValueKey('clear-discovery-filters')));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final dark in [false, true]) {
    testWidgets('preference targets, labels and contrast dark $dark', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(harness(AccessibilityPreferencesScreen(service: FakePreferences()), dark: dark));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        expect(find.bySemanticsLabel(RegExp('Rampa na entrada')), findsWidgets);
      } finally {
        semantics.dispose();
      }
    });
  }
}
