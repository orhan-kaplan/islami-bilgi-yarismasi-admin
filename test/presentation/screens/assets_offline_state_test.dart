@TestOn('chrome')
library;

// Asset sekmelerinin sunucu kapalıyken sessizce ölmemesini kilitler:
// ağ hatası kullanıcıya söylenir, yazma butonları kapalıdır ve başarısız
// listeleme yeniden denenebilir.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/assets/assets_screen.dart';

void main() {
  const iconEntry = {
    'name': 'star.png',
    'path': 'icons/star.png',
    'size': 512,
    'type': 'file',
    'modified': null,
  };

  Widget createTestWidget(MockClient mockClient, {bool isConnected = true}) {
    return ProviderScope(
      overrides: [
        assetServerClientProvider.overrideWithValue(
          AssetServerClient(
            baseUrl: 'http://localhost:8080',
            client: mockClient,
          ),
        ),
        isServerConnectedProvider.overrideWithValue(isConnected),
      ],
      child: const MaterialApp(home: AssetsScreen()),
    );
  }

  /// Listelemeyi başarıyla döner, yazma isteklerinde bağlantı hatası atar.
  MockClient writesFailClient({List<Map<String, dynamic>> icons = const []}) {
    return MockClient((request) async {
      if (request.method == 'GET' && request.url.path.startsWith('/api/list/')) {
        final body = request.url.path == '/api/list/icons' ? icons : const [];
        return http.Response(jsonEncode(body), 200);
      }
      throw http.ClientException(
        'Failed to fetch',
        Uri.parse('http://localhost:8080'),
      );
    });
  }

  group('Asset writes that never reach the server', () {
    testWidgets('a failed delete tells the user instead of doing nothing',
        (tester) async {
      // deleteFile bağlantı hatasında AssetServerException atmıyor; yalnız
      // onu yakalayan kod hiçbir geri bildirim vermiyordu.
      await tester.pumpWidget(
        createTestWidget(writesFailClient(icons: const [iconEntry])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Icons'));
      await tester.pumpAndSettle();
      expect(find.text('star.png'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not reach the asset server'),
        findsOneWidget,
        reason: 'a dead button with no message looks like a broken app',
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a failed folder creation tells the user', (tester) async {
      await tester.pumpWidget(createTestWidget(writesFailClient()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'siyer');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not reach the asset server'),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  group('Offline affordances', () {
    testWidgets('every add button is disabled while the server is offline',
        (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });
      await tester.pumpWidget(
        createTestWidget(mockClient, isConnected: false),
      );
      await tester.pumpAndSettle();

      FilledButton buttonWithLabel(String label) {
        return tester.widget<FilledButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(FilledButton),
          ),
        );
      }

      expect(buttonWithLabel('New Folder').onPressed, isNull);
      expect(
        find.byTooltip('Asset server is not connected'),
        findsWidgets,
        reason: 'a disabled button must say why it is disabled',
      );

      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      expect(buttonWithLabel('Add New Audio').onPressed, isNull);

      await tester.tap(find.text('Lottie'));
      await tester.pumpAndSettle();
      expect(buttonWithLabel('Add New Lottie').onPressed, isNull);

      await tester.tap(find.text('Icons'));
      await tester.pumpAndSettle();
      expect(buttonWithLabel('Add New Icon').onPressed, isNull);
    });

    testWidgets('add buttons stay enabled while the server is connected',
        (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });
      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      final newFolder = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('New Folder'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(newFolder.onPressed, isNotNull);
    });

    testWidgets('a failed listing explains itself and can be retried',
        (tester) async {
      var listCalls = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/list/icons') {
          listCalls++;
          if (listCalls == 1) {
            throw http.ClientException(
              'Failed to fetch',
              Uri.parse('http://localhost:8080/api/list/icons'),
            );
          }
          return http.Response(jsonEncode([iconEntry]), 200);
        }
        return http.Response(jsonEncode([]), 200);
      });

      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Icons'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not reach the asset server'),
        findsOneWidget,
        reason: 'a raw ClientException dump is not an error state',
      );
      expect(find.textContaining('ClientException'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(listCalls, greaterThan(1));
      expect(find.text('star.png'), findsOneWidget);
    });
  });
}
