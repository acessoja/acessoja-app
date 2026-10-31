import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/media/avatar_editor_screen.dart';
import 'package:flutter_application_1/media/image_selection_service.dart';
import 'package:flutter_application_1/media/media_cache.dart';
import 'package:flutter_application_1/media/media_models.dart';
import 'package:flutter_application_1/media/media_service.dart';
import 'package:flutter_application_1/media/photo_gallery_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';

const id = '01010101-1111-4111-8111-111111111111';
const rev = '02020202-2222-4222-8222-222222222222';
const changed = '03030303-3333-4333-8333-333333333333';
const pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIW2P4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==';
SelectedImage selected([String name = 'test.png']) =>
    SelectedImage(bytes: base64Decode(pixel), name: name, mime: 'image/png');
const photo = ReviewImage(
  id: id,
  revision: rev,
  reviewId: 1,
  description: 'Rampa na entrada principal do local.',
  state: 'approved',
  imageUrl: '/api/midia/arquivos/$id/image/',
  thumbUrl: '/api/midia/arquivos/$id/thumb/',
  canDelete: true,
);

class FakePicker extends ImageSelectionService {
  SelectedImage? next = selected();
  Future<SelectedImage?> Function()? onPick;
  @override
  Future<SelectedImage?> pick({
    required String scope,
    bool camera = false,
  }) async => onPick == null ? next : onPick!();
  @override
  Future<SelectedImage?> recover(String scope) async => next;
}

class MockPicker extends Mock implements ImagePicker {}

class FakeMedia extends MediaService {
  AvatarData data = const AvatarData(version: rev, hasAvatar: false);
  List<ReviewImage> rows = [];
  final uploads = <String>[];
  final fileNames = <String>[];
  int avatarSaves = 0, avatarRemoves = 0;
  Object? error;
  Future<PhotoPage> Function()? onPhotos;
  Future<AvatarData> Function()? onAvatar;
  String operationState = 'failed';
  bool failSecond = false;
  @override
  Future<AvatarData> avatar() async => onAvatar == null ? data : onAvatar!();
  @override
  Future<ImageReceipt> saveAvatar(
    SelectedImage file, {
    required String operation,
    required String version,
  }) async {
    if (error != null) {
      throw error!;
    }
    avatarSaves++;
    data = const AvatarData(version: changed, hasAvatar: true, legacy: pixel);
    return ImageReceipt(operation, 'committed', null, changed);
  }

  @override
  Future<ImageReceipt> removeAvatar({
    required String operation,
    required String version,
  }) async {
    if (error != null) {
      throw error!;
    }
    avatarRemoves++;
    data = const AvatarData(version: changed, hasAvatar: false);
    return ImageReceipt(operation, 'committed', null, changed);
  }

  @override
  Future<Map<String, dynamic>> review(int id) async => {
    'id': id,
    'can_edit': true,
    'content_revision': rev,
  };
  @override
  Future<PhotoPage> photos({int? localId, int? reviewId, Uri? next}) async =>
      onPhotos == null ? PhotoPage(List.of(rows), null) : onPhotos!();
  @override
  Future<Uint8List> bytes(String path) async => base64Decode(pixel);
  @override
  Future<ImageReceipt> uploadPhoto(
    SelectedImage file, {
    required String operation,
    required int reviewId,
    required String reviewRevision,
    required String description,
    String? photoId,
    String? expectedRevision,
  }) async {
    uploads.add(operation);
    fileNames.add(file.name);
    if (error != null) {
      throw error!;
    }
    if (failSecond && file.name == 'second.png') {
      throw const MediaFailure(422);
    }
    rows = [
      ...rows,
      ReviewImage(
        id: imageOperationId(),
        revision: imageOperationId(),
        reviewId: reviewId,
        description: description,
        state: 'pending',
        imageUrl: photo.imageUrl,
        thumbUrl: photo.thumbUrl,
        canDelete: true,
      ),
    ];
    return ImageReceipt(
      operation,
      'committed',
      rows.last.id,
      rows.last.revision,
    );
  }

  @override
  Future<ImageReceipt> operation(String id) async =>
      ImageReceipt(id, operationState, null, changed);
}

Widget app(
  Widget child, {
  double scale = 1,
  Locale locale = const Locale('pt'),
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('pt'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);
Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(target, 160, scrollable: scroll);
  }
  await tester.ensureVisible(target);
}

Future<void> choose(WidgetTester tester, String button) async {
  if (find.text(button).evaluate().isEmpty) {
    await tester.drag(find.byType(ListView).first, const Offset(0, 1800));
    await tester.pumpAndSettle();
  }
  await reveal(tester, find.text(button));
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Galeria ou arquivo'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppHttp.clearSession();
    AppHttp.token = 'synthetic';
    AppHttp.userId = 42;
  });
  tearDown(() {
    AppHttp.clearSession();
    MediaSessionCache.clear();
  });
  test('receipt never invents an upload success', () {
    expect(
      () => ImageReceipt.fromJson({'state': 'committed'}),
      throwsA(isA<MediaFailure>()),
    );
  });
  test(
    'picker cancellation and invalid format are distinct from network failure',
    () async {
      final plugin = MockPicker();
      when(
        () => plugin.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        ),
      ).thenAnswer((_) async => null);
      final picker = ImageSelectionService(picker: plugin);
      expect(await picker.pick(scope: 'avatar'), isNull);
      when(
        () => plugin.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        ),
      ).thenAnswer(
        (_) async =>
            XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'phone.heic'),
      );
      await expectLater(
        picker.pick(scope: 'avatar'),
        throwsA(isA<MediaFailure>().having((e) => e.status, 'status', 422)),
      );
    },
  );
  test('picker result from another account is discarded', () async {
    final plugin = MockPicker(), pending = Completer<XFile?>();
    when(
      () => plugin.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      ),
    ).thenAnswer((_) => pending.future);
    final future = ImageSelectionService(
      picker: plugin,
    ).pick(scope: 'review:1');
    await Future<void>.delayed(Duration.zero);
    AppHttp.userId = 99;
    pending.complete(XFile.fromData(base64Decode(pixel), name: 'test.png'));
    await expectLater(
      future,
      throwsA(isA<MediaFailure>().having((e) => e.status, 'status', 401)),
    );
  });
  test(
    'multipart has a generated boundary and session authorization, never token in URL',
    () async {
      final old = AppHttp.client;
      addTearDown(() => AppHttp.client = old);
      AppHttp.client = MockClient((request) async {
        expect(request.url.toString(), isNot(contains('synthetic')));
        expect(request.headers['Authorization'], 'Token synthetic');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data; boundary='),
        );
        expect(
          latin1.decode(request.bodyBytes),
          contains('name="operation_id"'),
        );
        expect(latin1.decode(request.bodyBytes), contains('name="file"'));
        return http.Response(
          jsonEncode({
            'operation_id': id,
            'state': 'committed',
            'photo_id': id,
            'revision': rev,
          }),
          201,
        );
      });
      final result = await const MediaService().uploadPhoto(
        selected(),
        operation: id,
        reviewId: 1,
        reviewRevision: rev,
        description: 'Synthetic ramp context',
      );
      expect(result.state, 'committed');
    },
  );
  test('foreign file URL and late session bytes are refused', () async {
    await expectLater(
      const MediaService().bytes('https://foreign.test/image'),
      throwsA(isA<MediaFailure>()),
    );
    final old = AppHttp.client;
    addTearDown(() => AppHttp.client = old);
    final pending = Completer<http.Response>();
    AppHttp.client = MockClient((request) => pending.future);
    final future = const MediaService().bytes(photo.imageUrl);
    AppHttp.clearSession();
    pending.complete(
      http.Response.bytes(
        [255, 216, 255],
        200,
        headers: {'content-type': 'image/jpeg'},
      ),
    );
    await expectLater(
      future,
      throwsA(isA<MediaFailure>().having((e) => e.status, 'status', 401)),
    );
  });
  testWidgets('avatar cancellation preserves old image and never calls save', (
    tester,
  ) async {
    final service = FakeMedia()
      ..data = const AvatarData(version: rev, hasAvatar: true, legacy: pixel);
    final picker = FakePicker()..next = null;
    await tester.pumpWidget(
      app(AvatarEditorScreen(service: service, picker: picker)),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'Selecionar imagem');
    expect(service.avatarSaves, 0);
    expect(find.textContaining('Seleção cancelada'), findsOneWidget);
  });
  testWidgets(
    'avatar confirmation saves, old invalid input fails without replacement',
    (tester) async {
      final service = FakeMedia()
        ..data = const AvatarData(version: rev, hasAvatar: true, legacy: pixel)
        ..error = const MediaFailure(422);
      await tester.pumpWidget(
        app(AvatarEditorScreen(service: service, picker: FakePicker())),
      );
      await tester.pumpAndSettle();
      await choose(tester, 'Selecionar imagem');
      expect(service.avatarSaves, 0);
      await tester.tap(find.byKey(const ValueKey('avatar-save')));
      await tester.pumpAndSettle();
      expect(service.data.version, rev);
      expect(find.textContaining('HEIC/HEIF'), findsOneWidget);
    },
  );
  testWidgets('avatar removal persists and returns default presentation', (
    tester,
  ) async {
    final service = FakeMedia()
      ..data = const AvatarData(version: rev, hasAvatar: true, legacy: pixel);
    await tester.pumpWidget(
      app(AvatarEditorScreen(service: service, picker: FakePicker())),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('avatar-remove')));
    await tester.tap(find.byKey(const ValueKey('avatar-remove')));
    await tester.pumpAndSettle();
    expect(service.avatarRemoves, 0);
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(service.avatarRemoves, 1);
    expect(service.data.hasAvatar, isFalse);
  });
  testWidgets(
    'uncertain avatar removal is reconciled without repeating delete',
    (tester) async {
      final service = FakeMedia()
        ..data = const AvatarData(version: rev, hasAvatar: true, legacy: pixel)
        ..error = const MediaFailure(503);
      await tester.pumpWidget(
        app(AvatarEditorScreen(service: service, picker: FakePicker())),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('avatar-remove')));
      await tester.tap(find.byKey(const ValueKey('avatar-remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();
      expect(await MediaService.remembered('avatar'), hasLength(1));
      service.data = const AvatarData(version: changed, hasAvatar: false);
      service.operationState = 'committed';
      await reveal(tester, find.text('Consultar resultado do envio'));
      await tester.tap(find.text('Consultar resultado do envio'));
      await tester.pumpAndSettle();
      expect(service.avatarRemoves, 0);
      expect(await MediaService.remembered('avatar'), isEmpty);
      expect(find.textContaining('Envio confirmado'), findsOneWidget);
    },
  );
  testWidgets(
    'late avatar reconciliation does not announce success in another account',
    (tester) async {
      final service = FakeMedia()..operationState = 'committed';
      await MediaService.remember('avatar', id);
      await tester.pumpWidget(
        app(AvatarEditorScreen(service: service, picker: FakePicker())),
      );
      await tester.pumpAndSettle();
      final late = Completer<AvatarData>();
      service.onAvatar = () => late.future;
      await reveal(tester, find.text('Consultar resultado do envio'));
      await tester.tap(find.text('Consultar resultado do envio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      AppHttp.userId = 99;
      late.complete(
        const AvatarData(version: changed, hasAvatar: true, legacy: pixel),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Envio confirmado'), findsNothing);
      expect(find.bySemanticsLabel('Foto atual do perfil'), findsNothing);
    },
  );
  testWidgets('selected photo has context and can be removed before sending', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final service = FakeMedia();
      await tester.pumpWidget(
        app(
          PhotoGalleryScreen(
            reviewId: 1,
            manage: true,
            service: service,
            picker: FakePicker(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await choose(tester, 'Selecionar foto opcional');
      expect(find.text('Selecionada; ainda não enviada'), findsOneWidget);
      expect(service.uploads, isEmpty);
      final fieldNode = tester.getSemantics(find.byType(EditableText));
      expect(
        fieldNode.rect.height,
        lessThan(tester.getSize(find.byType(Card)).height),
      );
      expect(
        fieldNode.getSemanticsData().label,
        isNot(contains('Selecionada')),
      );
      await tester.ensureVisible(find.text('Retirar seleção'));
      await tester.tap(find.text('Retirar seleção'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('partial upload retries only failed file using same identity', (
    tester,
  ) async {
    final service = FakeMedia()..failSecond = true, picker = FakePicker();
    await tester.pumpWidget(
      app(
        PhotoGalleryScreen(
          reviewId: 1,
          manage: true,
          service: service,
          picker: picker,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'Selecionar foto opcional');
    await tester.enterText(
      find.byType(TextFormField).first,
      'Rampa na entrada principal sintética',
    );
    picker.next = selected('second.png');
    await choose(tester, 'Selecionar foto opcional');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Banheiro com espaço de circulação',
    );
    await reveal(tester, find.byKey(const ValueKey('photos-submit')));
    await tester.tap(find.byKey(const ValueKey('photos-submit')));
    await tester.pumpAndSettle();
    expect(service.fileNames, ['test.png', 'second.png']);
    final failed = service.uploads.last;
    expect(find.textContaining('A avaliação continua salva.'), findsOneWidget);
    service.failSecond = false;
    await reveal(tester, find.byKey(const ValueKey('photos-submit')));
    await tester.tap(find.byKey(const ValueKey('photos-submit')));
    await tester.pumpAndSettle();
    expect(service.fileNames, ['test.png', 'second.png', 'second.png']);
    expect(service.uploads.last, failed);
  });
  testWidgets('account change clears private selected photo and context', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        PhotoGalleryScreen(
          reviewId: 1,
          manage: true,
          service: FakeMedia(),
          picker: FakePicker(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'Selecionar foto opcional');
    await tester.enterText(
      find.byType(TextFormField),
      'Contexto privado da conta anterior',
    );
    AppHttp.userId = 99;
    await tester.pumpAndSettle();
    expect(find.text('Contexto privado da conta anterior'), findsNothing);
  });
  testWidgets('late response from previous gallery is ignored', (tester) async {
    final late = Completer<PhotoPage>();
    final service = FakeMedia()..onPhotos = () => late.future;
    await tester.pumpWidget(
      app(PhotoGalleryScreen(localId: 1, service: service)),
    );
    await tester.pump();
    service.onPhotos = () async => const PhotoPage([], null);
    await tester.pumpWidget(
      app(PhotoGalleryScreen(localId: 2, service: service)),
    );
    await tester.pumpAndSettle();
    late.complete(const PhotoPage([photo], null));
    await tester.pumpAndSettle();
    expect(find.text(photo.description), findsNothing);
  });
  testWidgets('gallery viewer handles keyboard, Escape and focus return', (
    tester,
  ) async {
    final service = FakeMedia()..rows = [photo];
    await tester.pumpWidget(
      app(PhotoGalleryScreen(localId: 1, service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ampliar foto'));
    await tester.pumpAndSettle();
    expect(find.text('Fechar imagem'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Fechar imagem'), findsNothing);
  });
  testWidgets('200 percent narrow viewer and photo form fit keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        PhotoGalleryScreen(
          reviewId: 1,
          manage: true,
          service: FakeMedia(),
          picker: FakePicker(),
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await choose(tester, 'Selecionar foto opcional');
    await tester.showKeyboard(find.byType(TextFormField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
