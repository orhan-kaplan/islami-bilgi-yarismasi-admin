// DashboardScreen, ZIP indirmesi için `file_download_web.dart` üzerinden
// `dart:js_interop`'a bağlı — VM'de pump edilemez.
@TestOn('chrome')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/game_config_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/zip_exporter.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/dashboard_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/history_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/dashboard/dashboard_screen.dart';

/// Sidecar validation'ı devreden çıkarıp testi export sonrası davranışa
/// odaklar; ERROR gating'in kendisi zaten zip_exporter testlerinde.
class _SucceedingExporter extends ZipExporter {
  @override
  Uint8List exportZip(
    ContentState state, {
    FeedbackContentState? feedback,
    GameConfigState? gameConfig,
  }) {
    return Uint8List.fromList(const [1, 2, 3]);
  }
}

/// Export sırasında validation dışı bir hata — eski kod yalnızca
/// [ValidationBlockedExportException] yakalıyordu, gerisi sessizce yutuluyordu.
class _ThrowingExporter extends ZipExporter {
  @override
  Uint8List exportZip(
    ContentState state, {
    FeedbackContentState? feedback,
    GameConfigState? gameConfig,
  }) {
    throw StateError('serializer blew up');
  }
}

/// Import, kaydedilmemiş değişiklik varken bile onay sormadan ContentState'i
/// eziyor ve `historyProvider.clear()` ile undo yığınını da siliyordu: yanlış
/// seçilen eski bir dosya, geri alınamaz biçimde diske gidiyordu.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      result;
}

void main() {
  const existing = HadithModel(text: 'Mevcut hadis', source: 'Buhârî');

  ContentState stateWith(List<HadithModel> hadiths) => ContentState(
        series: const [],
        books: const [],
        contentFiles: const {},
        rewards: const [],
        hadiths: hadiths,
      );

  /// Export testleri için geçerli (validation'ı geçen) quiz içeriği — Export
  /// butonunun etkin olması gerekiyor.
  ContentState exportableState(List<HadithModel> hadiths) => ContentState(
        series: const [
          SeriesModel(
            id: 1,
            name: 'Seri',
            sortOrder: 1,
            isLocked: false,
            iconEmoji: 'A',
          ),
        ],
        books: const [
          BookModel(
            id: 1,
            title: 'Kitap',
            description: 'Açıklama',
            assetImage: 'assets/images/book_1/cover.webp',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ],
        contentFiles: const {'book_1.json': []},
        rewards: const [],
        hadiths: hadiths,
      );

  Uint8List hadithsJson(String text) => Uint8List.fromList(utf8.encode(
        jsonEncode([
          {'text': text, 'source': 'Müslim'}
        ]),
      ));

  setUp(() {
    FilePicker.platform = _FakeFilePicker(
      FilePickerResult([
        PlatformFile(
          name: 'hadiths.json',
          size: 1,
          bytes: hadithsJson('İçe aktarılan hadis'),
        ),
      ]),
    );
  });

  Future<ProviderContainer> pumpDashboard(
    WidgetTester tester, {
    required ContentState current,
    required ContentState? baseline,
    bool connected = false,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...extraOverrides,
        isServerConnectedProvider.overrideWithValue(connected),
        // Connectivity notifier gerçek health polling'i başlatıyor; mock
        // client anında dönünce timeout timer'ı da kurulmuyor.
        assetServerClientProvider.overrideWithValue(
          AssetServerClient(
            baseUrl: 'http://localhost:8080',
            client: MockClient((_) async => http.Response('down', 500)),
          ),
        ),
        contentStateProvider.overrideWith((ref) => ContentNotifier(current)),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(savedBaselineProvider.notifier).state = baseline;
    // Import'un sildiği yığının gerçekten dolu olduğunu garanti et.
    container.read(historyProvider.notifier).pushState(current);
    await tester.pumpAndSettle();
    return container;
  }

  /// ProviderScope'u söküp connectivity'nin 30 sn'lik periodic timer'ını
  /// iptal eder — aksi halde test "pending timer" ile düşer.
  Future<void> teardownScope(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  Future<void> tapImport(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Import').first);
    await tester.pumpAndSettle();
  }

  testWidgets('kaydedilmemiş değişiklik varken import onay ister',
      (tester) async {
    final c = await pumpDashboard(
      tester,
      current: stateWith(const [existing]),
      baseline: stateWith(const []),
    );
    expect(c.read(isDirtyProvider), isTrue);

    await tapImport(tester);

    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget,
        reason: 'üzerine yazmadan önce onay sorulmalı');

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(c.read(contentStateProvider).hadiths, [existing],
        reason: 'iptal edilen import içeriği değiştirmemeli');
    expect(c.read(canUndoProvider), isTrue,
        reason: 'iptal edilen import undo yığınını silmemeli');

    await teardownScope(tester);
  });

  testWidgets('onaylanan import uygulanır', (tester) async {
    final c = await pumpDashboard(
      tester,
      current: stateWith(const [existing]),
      baseline: stateWith(const []),
    );

    await tapImport(tester);
    await tester.tap(find.widgetWithText(FilledButton, "Import").last);
    await tester.pumpAndSettle();

    expect(c.read(contentStateProvider).hadiths.single.text,
        'İçe aktarılan hadis');

    await teardownScope(tester);
  });

  testWidgets('temiz state\'te import onay sormaz', (tester) async {
    final current = stateWith(const [existing]);
    final c = await pumpDashboard(
      tester,
      current: current,
      baseline: current,
    );
    expect(c.read(isDirtyProvider), isFalse);

    await tapImport(tester);

    expect(c.read(contentStateProvider).hadiths.single.text,
        'İçe aktarılan hadis',
        reason: 'kaybedilecek bir şey yokken akış kesilmemeli');

    // Onay sorulmadan uygulanan import, undo yığınını da siliyor ve dosyaları
    // diske kuyruğa alıyor — kullanıcı en azından ne olduğunu görmeli.
    final snack = tester.widget<Text>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)),
    );
    expect(snack.data, contains('hadiths.json'),
        reason: 'hangi dosyanın değiştiği söylenmeli');
    expect(snack.data!.toLowerCase(), contains('undo'),
        reason: 'undo geçmişinin silindiği söylenmeli');

    await teardownScope(tester);
  });

  testWidgets('connected import does not treat the merged tree as already saved',
      (tester) async {
    final current = stateWith(const [existing]);
    final c = await pumpDashboard(
      tester,
      current: current,
      baseline: current,
      connected: true,
    );
    expect(c.read(isDirtyProvider), isFalse);

    await tapImport(tester);

    expect(c.read(contentStateProvider).hadiths.single.text,
        'İçe aktarılan hadis');
    expect(c.read(savedBaselineProvider), current);
    expect(c.read(isDirtyProvider), isTrue,
        reason: 'baseline must stay on the pre-import tree until a PUT succeeds');

    await teardownScope(tester);
  });

  // ───────────────────────────────────────────────────────────────────
  // Seçim geri bildirimi — sessiz `return` yerine ne olduğunu söyle.
  // ───────────────────────────────────────────────────────────────────

  Future<String?> snackBarText(WidgetTester tester) async {
    final finder = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Text),
    );
    if (finder.evaluate().isEmpty) return null;
    return tester.widget<Text>(finder.first).data;
  }

  testWidgets('okunamayan dosya seçimi sessiz kalmaz', (tester) async {
    FilePicker.platform = _FakeFilePicker(
      FilePickerResult([
        PlatformFile(name: 'hadiths.json', size: 1, bytes: null),
      ]),
    );
    final current = stateWith(const [existing]);
    final c = await pumpDashboard(tester, current: current, baseline: current);

    await tapImport(tester);

    final text = await snackBarText(tester);
    expect(text, isNotNull, reason: 'hiçbir şey olmaması açıklanmalı');
    expect(text, contains('hadiths.json'));
    expect(c.read(contentStateProvider), current,
        reason: 'okunamayan dosya içeriği değiştirmemeli');

    await teardownScope(tester);
  });

  testWidgets('desteklenmeyen dosya türü bildirilir', (tester) async {
    FilePicker.platform = _FakeFilePicker(
      FilePickerResult([
        PlatformFile(
          name: 'notes.txt',
          size: 1,
          bytes: Uint8List.fromList(utf8.encode('hello')),
        ),
      ]),
    );
    final current = stateWith(const [existing]);
    await pumpDashboard(tester, current: current, baseline: current);

    await tapImport(tester);

    final text = await snackBarText(tester);
    expect(text, isNotNull);
    expect(text!.toLowerCase(), contains('notes.txt'));

    await teardownScope(tester);
  });

  testWidgets('ZIP yanında seçilen JSON sessizce yok sayılmaz', (tester) async {
    final zipBytes = ZipExporter().exportZip(stateWith(const [existing]));
    FilePicker.platform = _FakeFilePicker(
      FilePickerResult([
        PlatformFile(name: 'content.zip', size: zipBytes.length, bytes: zipBytes),
        PlatformFile(name: 'books.json', size: 2, bytes: hadithsJson('x')),
      ]),
    );
    final current = stateWith(const [existing]);
    await pumpDashboard(tester, current: current, baseline: current);

    await tapImport(tester);

    expect(find.text('Import Issues'), findsOneWidget,
        reason: 'yok sayılan dosya kullanıcıya bildirilmeli');
    expect(find.text('books.json'), findsOneWidget);
    expect(find.textContaining('gnored'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();
    await teardownScope(tester);
  });

  // ───────────────────────────────────────────────────────────────────
  // Export
  // ───────────────────────────────────────────────────────────────────

  Future<void> tapExport(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Export ZIP'));
    await tester.pumpAndSettle();
  }

  testWidgets('bağlıyken export ZIP indirmesi state\'i kaydedilmiş saymaz',
      (tester) async {
    final saved = exportableState(const []);
    final current = exportableState(const [existing]);
    final c = await pumpDashboard(
      tester,
      current: current,
      baseline: saved,
      connected: true,
      extraOverrides: [
        zipExporterProvider.overrideWithValue(_SucceedingExporter()),
      ],
    );
    expect(c.read(isDirtyProvider), isTrue);

    await tapExport(tester);

    expect(c.read(savedBaselineProvider), saved,
        reason: 'ZIP indirmesi sunucuya yazmaz; baseline kaymamalı');
    expect(c.read(isDirtyProvider), isTrue,
        reason: 'diskteki dosyalar hâlâ eski — dirty göstergesi susmamalı');

    await teardownScope(tester);
  });

  testWidgets('offline export edilen ağaç kaydedilmiş sayılır', (tester) async {
    final current = exportableState(const [existing]);
    final c = await pumpDashboard(
      tester,
      current: current,
      baseline: exportableState(const []),
      extraOverrides: [
        zipExporterProvider.overrideWithValue(_SucceedingExporter()),
      ],
    );

    await tapExport(tester);

    expect(c.read(savedBaselineProvider), current,
        reason: 'ZIP modunda export tek kayıt yolu',);

    await teardownScope(tester);
  });

  testWidgets('validation dışı export hatası kullanıcıya gösterilir',
      (tester) async {
    final current = exportableState(const [existing]);
    await pumpDashboard(
      tester,
      current: current,
      baseline: current,
      extraOverrides: [
        zipExporterProvider.overrideWithValue(_ThrowingExporter()),
      ],
    );

    await tapExport(tester);

    expect(find.text('Export Failed'), findsOneWidget,
        reason: 'yakalanmayan hata sessizce yutulmamalı');
    expect(find.textContaining('serializer blew up'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();
    await teardownScope(tester);
  });
}
