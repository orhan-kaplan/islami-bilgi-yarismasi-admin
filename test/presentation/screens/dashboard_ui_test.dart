// DashboardScreen, ZIP indirmesi için `file_download_web.dart` üzerinden
// `dart:js_interop`'a bağlı — VM'de pump edilemez.
@TestOn('chrome')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/core/theme/admin_theme.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/auto_load_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/validation_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/dashboard/dashboard_screen.dart';

/// Auto-load durumunu sabitleyen stub — gerçek notifier bağlantı bekliyor.
class _StubAutoLoad extends AutoLoadNotifier {
  _StubAutoLoad(super._ref, AutoLoadStatus initial) {
    state = initial;
  }
}

void main() {
  const hadith = HadithModel(text: 'Mevcut hadis', source: 'Buhârî');

  const book = BookModel(
    id: 1,
    title: 'Book 1',
    description: 'Desc',
    assetImage: 'assets/images/book_1/cover.webp',
    bookOrder: 1,
    seriesId: 1,
    contentFile: 'book_1.json',
  );

  ContentState quizState() => const ContentState(
        series: [],
        books: [book],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

  ContentState hadithsOnlyState() => const ContentState(
        series: [],
        books: [],
        contentFiles: {},
        rewards: [],
        hadiths: [hadith],
      );

  ValidationIssue issue(
    ValidationSeverity severity, {
    String sourceFile = 'books.json',
    String message = 'test issue',
  }) =>
      ValidationIssue(
        severity: severity,
        sourceFile: sourceFile,
        jsonPath: r'$',
        message: message,
      );

  Future<void> pumpDashboard(
    WidgetTester tester, {
    ContentState? state,
    List<ValidationIssue> issues = const [],
    AutoLoadStatus status = AutoLoadStatus.loaded,
    AutoLoadFailure? failure,
    ThemeData? theme,
    GoRouter? router,
    // Loading banner'daki sonsuz spinner pumpAndSettle'ı bitirmiyor.
    bool settle = true,
  }) async {
    final overrides = <Override>[
      isServerConnectedProvider.overrideWithValue(false),
      // Connectivity notifier gerçek health polling'i başlatıyor; mock
      // client anında dönünce timeout timer'ı da kurulmuyor.
      assetServerClientProvider.overrideWithValue(
        AssetServerClient(
          baseUrl: 'http://localhost:8080',
          client: MockClient((_) async => http.Response('down', 500)),
        ),
      ),
      contentStateProvider
          .overrideWith((ref) => ContentNotifier(state ?? ContentState.empty())),
      allValidationResultsProvider.overrideWithValue(issues),
      autoLoadProvider.overrideWith((ref) => _StubAutoLoad(ref, status)),
      autoLoadErrorProvider.overrideWith((ref) => failure),
    ];

    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: router == null
          ? MaterialApp(theme: theme, home: const DashboardScreen())
          : MaterialApp.router(theme: theme, routerConfig: router),
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// ProviderScope'u söküp connectivity'nin periodic timer'ını iptal eder.
  Future<void> teardownScope(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  GoRouter routerWithValidationStub() => GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          GoRoute(
            path: '/validation',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('VALIDATION STUB'))),
          ),
        ],
      );

  group('health score summary', () {
    testWidgets('warning-only issues do not render an empty Critical Issues card',
        (tester) async {
      await pumpDashboard(
        tester,
        state: quizState(),
        issues: List.generate(3, (_) => issue(ValidationSeverity.warning)),
      );

      expect(find.textContaining('Critical Issues'), findsNothing,
          reason: 'error yokken kırmızı "(0 total)" kartı gösterilmemeli');
      expect(find.textContaining('3 warnings'), findsOneWidget,
          reason: 'skoru düşüren warning sayısı ekranda görünmeli');

      await teardownScope(tester);
    });

    testWidgets('errors and warnings are both counted in the summary line',
        (tester) async {
      await pumpDashboard(
        tester,
        state: quizState(),
        issues: [
          issue(ValidationSeverity.error),
          issue(ValidationSeverity.warning),
          issue(ValidationSeverity.warning),
        ],
      );

      expect(find.textContaining('1 error'), findsOneWidget);
      expect(find.textContaining('2 warnings'), findsOneWidget);
      expect(find.textContaining('Critical Issues (1 total)'), findsOneWidget);

      await teardownScope(tester);
    });
  });

  group('empty vs non-empty content', () {
    testWidgets('a hadiths-only session is not reported as empty',
        (tester) async {
      await pumpDashboard(tester, state: hadithsOnlyState());

      expect(find.text('No content loaded'), findsNothing,
          reason: 'hadis dolu oturum boş sayılmamalı');
      expect(find.text('Health Score'), findsOneWidget,
          reason: 'health score gizlenmemeli');

      final exportButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Export ZIP'),
      );
      expect(exportButton.onPressed, isNotNull,
          reason: 'hadis içeriği export edilebilmeli');

      await teardownScope(tester);
    });

    testWidgets('a truly empty session still shows the prompt', (tester) async {
      await pumpDashboard(tester);

      expect(find.text('No content loaded'), findsOneWidget);
      final exportButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Export ZIP'),
      );
      expect(exportButton.onPressed, isNull);

      await teardownScope(tester);
    });

    testWidgets('disabled Export ZIP explains why it is disabled',
        (tester) async {
      await pumpDashboard(tester);

      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.widgetWithText(FilledButton, 'Export ZIP'),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, isNotNull);
      expect(tooltip.message!.toLowerCase(), contains('import'),
          reason: 'gri butonun sebebi ve çıkış yolu yazmalı');

      await teardownScope(tester);
    });
  });

  group('auto-load states', () {
    testWidgets('loading hides the empty prompt and disables import',
        (tester) async {
      await pumpDashboard(
        tester,
        status: AutoLoadStatus.loading,
        settle: false,
      );

      expect(find.text('Loading content from asset server...'), findsOneWidget);
      expect(find.text('No content loaded'), findsNothing,
          reason: 'yükleme sürerken "içerik yok" denmemeli');

      final importButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import'),
      );
      expect(importButton.onPressed, isNull,
          reason: 'auto-load sürerken import yarışa girmemeli');

      await teardownScope(tester);
    });

    testWidgets('an unreachable server keeps the start-the-server hint',
        (tester) async {
      await pumpDashboard(
        tester,
        status: AutoLoadStatus.failed,
        failure: const AutoLoadFailure(
          serverReachable: false,
          message: 'ClientException: Connection refused',
        ),
      );

      expect(find.text('Asset server unavailable'), findsOneWidget);
      expect(find.textContaining('dart run bin/server.dart'), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsOneWidget,
          reason: 'gerçek hata metni yutulmamalı');

      await teardownScope(tester);
    });

    testWidgets('a reachable server reports the real failure instead of "start the server"',
        (tester) async {
      await pumpDashboard(
        tester,
        status: AutoLoadStatus.failed,
        failure: const AutoLoadFailure(
          serverReachable: true,
          message: 'AssetServerException(404): data/series.json',
        ),
      );

      expect(find.text('Asset server unavailable'), findsNothing,
          reason: 'sunucu ayaktayken "sunucu yok" demek yanlış yönlendiriyor');
      expect(find.textContaining('data/series.json'), findsOneWidget);
      expect(find.textContaining('dart run bin/server.dart'), findsNothing,
          reason: 'çalışan sunucu için başlatma komutu gösterilmemeli');
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);

      await teardownScope(tester);
    });
  });

  group('narrow window layout', () {
    testWidgets('dashboard does not overflow at 360px width', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpDashboard(
        tester,
        state: quizState(),
        issues: [
          issue(ValidationSeverity.error, message: 'Book 1 has no levels'),
          issue(ValidationSeverity.warning),
        ],
      );

      expect(tester.takeException(), isNull,
          reason: 'dar pencerede RenderFlex overflow olmamalı');

      await teardownScope(tester);
    });

    testWidgets('the failed banner does not overflow at 360px width',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpDashboard(
        tester,
        state: quizState(),
        status: AutoLoadStatus.failed,
        failure: const AutoLoadFailure(
          serverReachable: false,
          message: 'ClientException: Connection refused',
        ),
      );

      expect(tester.takeException(), isNull);

      await teardownScope(tester);
    });
  });

  group('critical issues navigation', () {
    testWidgets('tapping an error opens the validation report', (tester) async {
      await pumpDashboard(
        tester,
        state: quizState(),
        issues: List.generate(
          7,
          (i) => issue(ValidationSeverity.error, message: 'Broken item $i'),
        ),
        router: routerWithValidationStub(),
      );

      expect(find.text('VALIDATION STUB'), findsNothing);

      final firstError = find.textContaining('Broken item 0');
      await tester.ensureVisible(firstError);
      await tester.pumpAndSettle();
      await tester.tap(firstError);
      await tester.pumpAndSettle();

      expect(find.text('VALIDATION STUB'), findsOneWidget,
          reason: 'hata satırı tıklanabilir olmalı');

      await teardownScope(tester);
    });

    testWidgets('tapping the overflow line opens the validation report',
        (tester) async {
      await pumpDashboard(
        tester,
        state: quizState(),
        issues: List.generate(
          7,
          (i) => issue(ValidationSeverity.error, message: 'Broken item $i'),
        ),
        router: routerWithValidationStub(),
      );

      final moreLine = find.textContaining('and 2 more');
      await tester.ensureVisible(moreLine);
      await tester.pumpAndSettle();
      await tester.tap(moreLine);
      await tester.pumpAndSettle();

      expect(find.text('VALIDATION STUB'), findsOneWidget);

      await teardownScope(tester);
    });
  });

  group('theme colors', () {
    testWidgets('count card labels follow the theme, not a fixed grey',
        (tester) async {
      await pumpDashboard(
        tester,
        state: quizState(),
        theme: adminDarkTheme,
      );

      final label = tester.widget<Text>(find.text('Series'));
      expect(label.style?.color, adminDarkTheme.colorScheme.onSurfaceVariant,
          reason: 'koyu temada sabit grey.shade600 okunmuyor');

      await teardownScope(tester);
    });

    testWidgets('the critical issues card uses the theme error container',
        (tester) async {
      await pumpDashboard(
        tester,
        state: quizState(),
        issues: [issue(ValidationSeverity.error)],
        theme: adminDarkTheme,
      );

      final card = tester.widget<Card>(
        find.ancestor(
          of: find.textContaining('Critical Issues'),
          matching: find.byType(Card),
        ),
      );
      expect(card.color, adminDarkTheme.colorScheme.errorContainer,
          reason: 'koyu temada açık kırmızı zemin kullanılmamalı');

      await teardownScope(tester);
    });
  });
}
