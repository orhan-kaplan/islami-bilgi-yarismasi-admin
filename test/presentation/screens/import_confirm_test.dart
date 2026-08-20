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
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/history_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/dashboard/dashboard_screen.dart';

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
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
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
}
