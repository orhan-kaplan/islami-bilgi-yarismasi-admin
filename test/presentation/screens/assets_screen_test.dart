@TestOn('chrome')
library;

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
  /// Creates a mock HTTP client that returns directory listings based on path.
  MockClient createMockClient({
    List<Map<String, dynamic>> imagesEntries = const [],
    List<Map<String, dynamic>> audioEntries = const [],
    List<Map<String, dynamic>> lottieEntries = const [],
    List<Map<String, dynamic>> lottieFeedbackEntries = const [],
    List<Map<String, dynamic>> iconsEntries = const [],
    Map<String, List<Map<String, dynamic>>> subfolderEntries = const {},
  }) {
    return MockClient((request) async {
      final path = request.url.path;

      for (final entry in subfolderEntries.entries) {
        if (path == '/api/list/${entry.key}') {
          return http.Response(jsonEncode(entry.value), 200);
        }
      }

      if (path == '/api/list/images') {
        return http.Response(jsonEncode(imagesEntries), 200);
      } else if (path == '/api/list/audio') {
        return http.Response(jsonEncode(audioEntries), 200);
      } else if (path == '/api/list/lottie') {
        return http.Response(jsonEncode(lottieEntries), 200);
      } else if (path == '/api/list/lottie/feedback') {
        return http.Response(jsonEncode(lottieFeedbackEntries), 200);
      } else if (path == '/api/list/icons') {
        return http.Response(jsonEncode(iconsEntries), 200);
      }

      return http.Response(jsonEncode({'error': 'Not found'}), 404);
    });
  }

  /// Wraps [AssetsScreen] in a [MaterialApp] with [ProviderScope] overrides.
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
      child: const MaterialApp(
        home: AssetsScreen(),
      ),
    );
  }

  group('AssetsScreen', () {
    testWidgets('renders with 4 tabs (Images, Audio, Lottie, Icons)',
        (tester) async {
      final mockClient = createMockClient();
      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      expect(find.text('Images'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Lottie'), findsOneWidget);
      expect(find.text('Icons'), findsOneWidget);
    });

    testWidgets('tab switching works — tap Audio tab shows Audio content',
        (tester) async {
      final mockClient = createMockClient(
        audioEntries: [
          {
            'name': 'welcome.mp3',
            'path': 'audio/welcome.mp3',
            'size': 12345,
            'type': 'file',
            'modified': '2024-01-01T00:00:00.000Z',
          },
        ],
      );
      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      // Tap on Audio tab
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();

      // Audio tab content should be visible
      expect(find.text('Audio Files'), findsOneWidget);
      expect(find.text('welcome.mp3'), findsOneWidget);
    });

    testWidgets(
        'Images tab shows "Select a folder" when no folder is selected',
        (tester) async {
      final mockClient = createMockClient(
        imagesEntries: [
          {
            'name': 'book_1',
            'path': 'images/book_1',
            'size': 0,
            'type': 'directory',
            'modified': null,
          },
        ],
      );
      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      // Images tab is the default tab — should show folder sidebar and
      // "Select a folder" message in the main area
      expect(find.text('Select a folder from the sidebar'), findsOneWidget);
    });

    testWidgets('Images tab shows folder list from server response',
        (tester) async {
      final mockClient = createMockClient(
        imagesEntries: [
          {
            'name': 'book_1',
            'path': 'images/book_1',
            'size': 0,
            'type': 'directory',
            'modified': null,
          },
          {
            'name': 'book_2',
            'path': 'images/book_2',
            'size': 0,
            'type': 'directory',
            'modified': null,
          },
          {
            'name': 'rewards',
            'path': 'images/rewards',
            'size': 0,
            'type': 'directory',
            'modified': null,
          },
        ],
      );
      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      // Folder names should appear in the sidebar
      expect(find.text('book_1'), findsOneWidget);
      expect(find.text('book_2'), findsOneWidget);
      expect(find.text('rewards'), findsOneWidget);
    });

    testWidgets('creating an image folder syncs pubspec.yaml', (tester) async {
      // A folder that never reaches pubspec.yaml is a folder whose images are
      // missing from the app bundle at runtime, with no warning anywhere.
      final requestedPaths = <String>[];
      final mockClient = MockClient((request) async {
        requestedPaths.add('${request.method} ${request.url.path}');
        if (request.url.path.startsWith('/api/list/')) {
          return http.Response(jsonEncode([]), 200);
        }
        return http.Response(jsonEncode({'success': true}), 200);
      });

      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Folder'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'siyer');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(requestedPaths, contains('POST /api/folders/images/siyer'));
      expect(requestedPaths, contains('POST /api/sync-pubspec'));
    });

    testWidgets(
        'Icons tab shows "No icons found" when server returns empty list',
        (tester) async {
      final mockClient = createMockClient(iconsEntries: []);
      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      // Switch to Icons tab
      await tester.tap(find.text('Icons'));
      await tester.pumpAndSettle();

      expect(find.text('No icons found'), findsOneWidget);
    });

    testWidgets('folder selection survives a round trip to another tab',
        (tester) async {
      // Sekme değişiminde ImagesTab dispose olursa editör her dönüşte
      // klasörü yeniden seçmek zorunda kalıyor.
      final mockClient = createMockClient(
        imagesEntries: [
          {
            'name': 'book_1',
            'path': 'images/book_1',
            'size': 0,
            'type': 'directory',
            'modified': null,
          },
        ],
        subfolderEntries: {
          'images/book_1': [
            {
              'name': 'level_1.webp',
              'path': 'images/book_1/level_1.webp',
              'size': 2048,
              'type': 'file',
              'modified': null,
            },
          ],
        },
      );
      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      await tester.tap(find.text('book_1'));
      await tester.pumpAndSettle();
      expect(find.text('level_1.webp'), findsOneWidget);

      await tester.tap(find.text('Icons'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Images'));
      await tester.pumpAndSettle();

      expect(
        find.text('Select a folder from the sidebar'),
        findsNothing,
        reason: 'the selected folder must survive leaving and re-entering',
      );
      expect(find.text('level_1.webp'), findsOneWidget);
    });

    testWidgets('New Folder dialog previews the sanitized folder name',
        (tester) async {
      // sanitizeFilename girdiyi sessizce değiştiriyor; kullanıcı sonucu
      // ancak klasör oluştuktan sonra görüyordu.
      final mockClient = createMockClient();
      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Folder'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Book 4');
      await tester.pumpAndSettle();

      expect(
        find.text('Will be created as: book_4'),
        findsOneWidget,
        reason: 'the dialog must show the name that will actually be created',
      );
    });

    testWidgets(
        'pubspec sync failure explains that the images will not be bundled',
        (tester) async {
      final mockClient = MockClient((request) async {
        if (request.url.path.startsWith('/api/list/')) {
          return http.Response(jsonEncode([]), 200);
        }
        if (request.url.path == '/api/sync-pubspec') {
          return http.Response(
            jsonEncode({'error': 'No "- assets/images/" anchor line found'}),
            409,
          );
        }
        return http.Response(jsonEncode({'success': true}), 200);
      });

      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'siyer');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('will not be bundled'),
        findsOneWidget,
        reason: 'a silent pubspec failure ships a folder the app cannot see',
      );

      // SnackBar'ın 4 sn'lik zamanlayıcısı test sonunda beklemede kalmasın.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('an image thumbnail that fails to load says so',
        (tester) async {
      final mockClient = createMockClient(
        imagesEntries: [
          {
            'name': 'book_1',
            'path': 'images/book_1',
            'size': 0,
            'type': 'directory',
            'modified': null,
          },
        ],
        subfolderEntries: {
          'images/book_1': [
            {
              'name': 'level_1.webp',
              'path': 'images/book_1/level_1.webp',
              'size': 2048,
              'type': 'file',
              'modified': null,
            },
          ],
        },
      );
      await tester.pumpWidget(createTestWidget(mockClient));
      await tester.pumpAndSettle();

      await tester.tap(find.text('book_1'));
      await tester.pumpAndSettle();

      // Thumbnail isteği gerçek ağa çıkıyor ve başarısız oluyor; hata
      // fake-async dışında geldiği için gerçek zamana izin vermek gerekiyor.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to load'),
        findsOneWidget,
        reason: 'a bare broken-image icon does not tell the user what failed',
      );
    });
  });
}
