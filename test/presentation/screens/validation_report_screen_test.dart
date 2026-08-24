// Validation raporunun dürüstlüğünü kilitler: atlanan asset kontrollerini
// "temiz" diye göstermemesi, düzeltme sonrası yenilenebilmesi, warning
// renginin tema token'ından gelmesi ve satırdaki yolun kopyalanabilmesi.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/core/theme/admin_theme.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/validation/validation_report_screen.dart';

void main() {
  const emptyState = ContentState(
    series: [],
    books: [],
    contentFiles: {},
    rewards: [],
    hadiths: [],
  );

  /// Tek bir kitabı `assets/images/book_1/cover.webp`'e referans veren state.
  const stateWithAssetReference = ContentState(
    series: [],
    books: [
      BookModel(
        id: 1,
        title: 'Book 1',
        description: 'Desc',
        assetImage: 'assets/images/book_1/cover.webp',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: {},
    rewards: [],
    hadiths: [],
  );

  Widget createTestWidget({
    required http.Client mockClient,
    required ContentState contentState,
    required bool isConnected,
  }) {
    return ProviderScope(
      overrides: [
        assetServerClientProvider.overrideWithValue(
          AssetServerClient(
            baseUrl: 'http://localhost:8080',
            client: mockClient,
          ),
        ),
        contentStateProvider.overrideWith((ref) => ContentNotifier(contentState)),
        isServerConnectedProvider.overrideWithValue(isConnected),
      ],
      child: MaterialApp(
        theme: adminTheme,
        home: const ValidationReportScreen(),
      ),
    );
  }

  MockClient listingClient(List<Map<String, dynamic>> entries) {
    return MockClient((request) async {
      if (request.url.path.startsWith('/api/list/')) {
        return http.Response(jsonEncode(entries), 200);
      }
      return http.Response(jsonEncode({'error': 'Not found'}), 404);
    });
  }

  group('ValidationReportScreen — skipped asset checks', () {
    testWidgets(
        'disconnected report does not claim everything is clean',
        (tester) async {
      // Bağlantı yokken missingAssetValidationProvider sessizce boş dönüyor;
      // ekran bunu "sorun yok" diye gösterirse kullanıcı hiç yapılmamış bir
      // kontrole güvenmiş olur.
      await tester.pumpWidget(
        createTestWidget(
          mockClient: MockClient((request) async {
            fail('No request should be made while disconnected');
          }),
          contentState: emptyState,
          isConnected: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No validation issues found!'), findsNothing);
      expect(
        find.textContaining('Asset checks skipped'),
        findsOneWidget,
        reason: 'the report must say the asset check did not run',
      );
    });

    testWidgets('connected report with no issues still shows the all-clear',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          mockClient: listingClient(const []),
          contentState: emptyState,
          isConnected: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No validation issues found!'), findsOneWidget);
      expect(find.textContaining('Asset checks skipped'), findsNothing);
    });
  });

  group('ValidationReportScreen — refresh', () {
    testWidgets('re-runs the asset check so a fixed asset clears its warning',
        (tester) async {
      var listCalls = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path.startsWith('/api/list/')) {
          listCalls++;
          // İlk listeleme klasörü boş gösterir (asset eksik), ikincisi
          // kullanıcı dosyayı yüklemiş gibi dosyayı döner.
          final entries = listCalls == 1
              ? const <Map<String, dynamic>>[]
              : const [
                  {
                    'name': 'cover.webp',
                    'path': 'images/book_1/cover.webp',
                    'size': 100,
                    'type': 'file',
                    'modified': null,
                  },
                ];
          return http.Response(jsonEncode(entries), 200);
        }
        return http.Response(jsonEncode({'error': 'Not found'}), 404);
      });

      await tester.pumpWidget(
        createTestWidget(
          mockClient: mockClient,
          contentState: stateWithAssetReference,
          isConnected: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Asset not found: assets/images/book_1/cover.webp'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Re-run asset checks'));
      await tester.pumpAndSettle();

      expect(listCalls, greaterThan(1));
      expect(
        find.text('Asset not found: assets/images/book_1/cover.webp'),
        findsNothing,
        reason: 'refresh must drop the warning for an asset that now exists',
      );
    });
  });

  group('ValidationReportScreen — warning color', () {
    testWidgets('warning section uses the theme token, not Colors.orange',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          mockClient: listingClient(const []),
          contentState: stateWithAssetReference,
          isConnected: true,
        ),
      );
      await tester.pumpAndSettle();

      final header = tester.widget<Text>(find.text('Warnings (1)'));
      expect(header.style?.color, AdminSemanticColors.light.warning);
      expect(header.style?.color, isNot(Colors.orange));
    });
  });

  group('ValidationReportScreen — issue rows', () {
    testWidgets('copies the json path of an issue to the clipboard',
        (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        createTestWidget(
          mockClient: listingClient(const []),
          contentState: stateWithAssetReference,
          isConnected: true,
        ),
      );
      await tester.pumpAndSettle();

      final warningTile = find.ancestor(
        of: find.text('Asset not found: assets/images/book_1/cover.webp'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find.descendant(of: warningTile, matching: find.byTooltip('Copy path')),
      );
      await tester.pumpAndSettle();

      expect(copied, 'asset_image');
      expect(find.text('Path copied'), findsOneWidget);
    });
  });
}
