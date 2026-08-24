@TestOn('chrome')
library;

// Lottie silme, Images'teki referans korumasının aynısını uygulamalı:
// feedback mesajları ve game_config slotları hâlâ kullanıyorsa dosya
// silinemez. Aksi hâlde uygulama çalışırken eksik animasyonla patlıyor.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/game_config_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/game_config_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/assets/assets_screen.dart';

void main() {
  const rootEntries = [
    {
      'name': 'Confetti.json',
      'path': 'lottie/Confetti.json',
      'size': 1024,
      'type': 'file',
      'modified': null,
    },
    {
      'name': 'unused.json',
      'path': 'lottie/unused.json',
      'size': 1024,
      'type': 'file',
      'modified': null,
    },
  ];

  const feedbackEntries = [
    {
      'name': 'masallah.json',
      'path': 'lottie/feedback/masallah.json',
      'size': 1024,
      'type': 'file',
      'modified': null,
    },
  ];

  /// `feedback/masallah.json`'a bağlı tek mesaj içeren feedback state'i.
  const feedbackState = FeedbackContentState(
    quiz: {},
    speedQuiz: {},
    time: {},
    comeback: [
      FeedbackMessageModel(
        title: 'Tekrar hoş geldin',
        message: 'Seni özledik',
        emoji: '🎉',
        lottieAsset: 'feedback/masallah.json',
      ),
    ],
    streak: {},
    titles: [],
    learned: {},
  );

  Widget createTestWidget(
    MockClient mockClient, {
    FeedbackContentState? feedback,
    GameConfigState? gameConfig,
  }) {
    return ProviderScope(
      overrides: [
        assetServerClientProvider.overrideWithValue(
          AssetServerClient(
            baseUrl: 'http://localhost:8080',
            client: mockClient,
          ),
        ),
        isServerConnectedProvider.overrideWithValue(true),
        feedbackContentProvider.overrideWith(
          (ref) => FeedbackContentNotifier(
            feedback ?? FeedbackContentState.empty(),
          ),
        ),
        gameConfigProvider.overrideWith(
          (ref) => GameConfigNotifier(gameConfig ?? GameConfigState.defaults),
        ),
      ],
      child: const MaterialApp(home: AssetsScreen()),
    );
  }

  MockClient createMockClient({
    required List<String> deleteLog,
    bool failWrites = false,
  }) {
    return MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'DELETE') {
        if (failWrites) {
          throw http.ClientException('Failed to fetch', request.url);
        }
        deleteLog.add(path);
        return http.Response(jsonEncode({'success': true}), 200);
      }
      if (path == '/api/list/lottie') {
        return http.Response(jsonEncode(rootEntries), 200);
      }
      if (path == '/api/list/lottie/feedback') {
        return http.Response(jsonEncode(feedbackEntries), 200);
      }
      if (path.startsWith('/api/list/')) {
        return http.Response(jsonEncode([]), 200);
      }
      return http.Response(jsonEncode({'error': 'Not found'}), 404);
    });
  }

  Future<void> openLottieTab(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lottie'));
    await tester.pumpAndSettle();
  }

  /// Kart → önizleme dialogu → Delete.
  Future<void> tapDeleteInPreview(WidgetTester tester, String fileName) async {
    // Feedback bölümü kaydırma alanının altında kalabiliyor.
    await tester.ensureVisible(find.text(fileName));
    await tester.pumpAndSettle();
    await tester.tap(find.text(fileName));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
  }

  group('Lottie delete guard', () {
    testWidgets('a lottie used by a feedback message cannot be deleted',
        (tester) async {
      final deleteLog = <String>[];
      await tester.pumpWidget(
        createTestWidget(
          createMockClient(deleteLog: deleteLog),
          feedback: feedbackState,
        ),
      );
      await openLottieTab(tester);

      await tapDeleteInPreview(tester, 'masallah.json');

      expect(find.text('Cannot Delete'), findsOneWidget);
      expect(
        find.textContaining('Tekrar hoş geldin'),
        findsOneWidget,
        reason: 'the block must name what still uses the file',
      );
      expect(
        deleteLog,
        isEmpty,
        reason: 'a referenced animation must never reach the server',
      );
    });

    testWidgets('a lottie used by game_config cannot be deleted',
        (tester) async {
      final deleteLog = <String>[];
      await tester.pumpWidget(
        createTestWidget(createMockClient(deleteLog: deleteLog)),
      );
      await openLottieTab(tester);

      await tapDeleteInPreview(tester, 'Confetti.json');

      expect(find.text('Cannot Delete'), findsOneWidget);
      expect(find.textContaining('confetti'), findsOneWidget);
      expect(deleteLog, isEmpty);
    });

    testWidgets('an unreferenced lottie is still deletable after confirming',
        (tester) async {
      final deleteLog = <String>[];
      await tester.pumpWidget(
        createTestWidget(
          createMockClient(deleteLog: deleteLog),
          feedback: feedbackState,
        ),
      );
      await openLottieTab(tester);

      await tapDeleteInPreview(tester, 'unused.json');

      expect(
        find.text('Cannot Delete'),
        findsNothing,
        reason: 'the guard must not block files nothing references',
      );
      expect(find.text('Delete Lottie Animation'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleteLog, contains('/api/files/lottie/unused.json'));
    });

    testWidgets('a lottie delete that never reaches the server says so',
        (tester) async {
      final deleteLog = <String>[];
      await tester.pumpWidget(
        createTestWidget(
          createMockClient(deleteLog: deleteLog, failWrites: true),
        ),
      );
      await openLottieTab(tester);

      await tapDeleteInPreview(tester, 'unused.json');
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not reach the asset server'),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });
}
