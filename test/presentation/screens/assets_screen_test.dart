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
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/assets/assets_screen.dart';

void main() {
  /// Creates a mock HTTP client that returns directory listings based on path.
  MockClient createMockClient({
    List<Map<String, dynamic>> imagesEntries = const [],
    List<Map<String, dynamic>> audioEntries = const [],
    List<Map<String, dynamic>> lottieEntries = const [],
    List<Map<String, dynamic>> lottieFeedbackEntries = const [],
    List<Map<String, dynamic>> iconsEntries = const [],
  }) {
    return MockClient((request) async {
      final path = request.url.path;

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
  Widget createTestWidget(MockClient mockClient) {
    return ProviderScope(
      overrides: [
        assetServerClientProvider.overrideWithValue(
          AssetServerClient(
            baseUrl: 'http://localhost:8080',
            client: mockClient,
          ),
        ),
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
  });
}
