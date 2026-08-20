import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';

/// A valid FeedbackContentState with all required subcategories populated.
FeedbackContentState _createValidState() {
  FeedbackMessageModel msg(String title) => FeedbackMessageModel(
        title: title,
        message: 'Test message',
        emoji: '🎉',
        shouldRepeat: true,
      );

  return FeedbackContentState(
    quiz: {
      'speed_demon': [msg('Speed')],
      'perfect': [msg('Perfect')],
      'one_wrong': [msg('One Wrong')],
      'two_wrong': [msg('Two Wrong')],
      'good': [msg('Good')],
      'moderate': [msg('Moderate')],
      'failure': [msg('Failure')],
    },
    speedQuiz: {
      'combo_master': [msg('Combo')],
      'high_score': [msg('High')],
      'time_expired': [msg('Expired')],
      'moderate': [msg('Moderate')],
      'low': [msg('Low')],
    },
    time: {
      'seher': [msg('Seher')],
      'morning': [msg('Morning')],
      'noon': [msg('Noon')],
      'afternoon': [msg('Afternoon')],
      'evening': [msg('Evening')],
      'night': [msg('Night')],
      'teheccud': [msg('Teheccud')],
    },
    comeback: [msg('Comeback')],
    streak: {
      '3': [msg('3 days')],
      '7': [msg('7 days')],
      '30': [msg('30 days')],
    },
    titles: [
      const PlayerTitleModel(
        title: 'İlim Yolcusu',
        icon: '🌱',
        requiredBooks: 0,
        profileImage: 'images/seed/profile_icon_seed.webp',
      ),
    ],
    learned: {
      '100': [msg('100%')],
      '75': [msg('75%')],
      '50': [msg('50%')],
      '25': [msg('25%')],
      '0': [msg('0%')],
    },
  );
}

void main() {
  group('FeedbackAutoSaveController', () {
    late List<http.Request> capturedRequests;

    /// Creates a container with connectivity already connected and feedback
    /// already loaded, so the auto-save controller starts listening immediately.
    ProviderContainer createLoadedContainer({
      required http.Client mockClient,
      bool connected = true,
    }) {
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: mockClient,
            ),
          ),
          // Override connectivity check directly
          isServerConnectedProvider.overrideWithValue(connected),
          // Override feedback load status to loaded
          feedbackLoadProvider.overrideWith(
            (ref) => _AlreadyLoadedNotifier(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Pre-populate the feedback content state
      container
          .read(feedbackContentProvider.notifier)
          .importContent(_createValidState());

      return container;
    }

    setUp(() {
      capturedRequests = [];
    });

    test('starts in idle state', () {
      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });

      final container = createLoadedContainer(mockClient: mockClient);
      final status = container.read(feedbackAutoSaveProvider);
      expect(status, FeedbackSaveStatus.idle);
    });

    test('saves feedback.json after debounce when content changes', () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        if (request.url.path == '/api/files/data/feedback.json') {
          return http.Response('', 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createLoadedContainer(mockClient: mockClient);

      // Initialize the auto-save controller (starts listening)
      container.read(feedbackAutoSaveProvider);

      // Modify feedback content
      container.read(feedbackContentProvider.notifier).addMessage(
            'comeback',
            null,
            const FeedbackMessageModel(
              title: 'New Message',
              message: 'Hello!',
              emoji: '👋',
              shouldRepeat: true,
            ),
          );

      // Wait for debounce (2s) + buffer
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // Verify a PUT request was made to data/feedback.json
      final putRequests = capturedRequests
          .where((r) =>
              r.method == 'PUT' &&
              r.url.path == '/api/files/data/feedback.json')
          .toList();

      expect(putRequests, isNotEmpty);

      // Verify the saved JSON contains the new message
      final savedBody = putRequests.last.body;
      final savedJson = jsonDecode(savedBody) as Map<String, dynamic>;
      final comebackList = savedJson['comeback'] as List<dynamic>;
      expect(comebackList.length, 2); // original + new
    });

    test('blocks save when validation fails', () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('', 200);
      });

      final container = createLoadedContainer(mockClient: mockClient);

      // Initialize auto-save
      container.read(feedbackAutoSaveProvider);

      // Set state to invalid (empty state fails validation)
      container
          .read(feedbackContentProvider.notifier)
          .importContent(FeedbackContentState.empty());

      // Wait for debounce
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // Verify no PUT request was made (save was blocked)
      final putRequests = capturedRequests
          .where((r) =>
              r.method == 'PUT' &&
              r.url.path == '/api/files/data/feedback.json')
          .toList();

      expect(putRequests, isEmpty);

      // Status should be error
      expect(
          container.read(feedbackAutoSaveProvider), FeedbackSaveStatus.error);
    });

    test('flushPendingSave saves immediately without waiting for debounce',
        () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        if (request.url.path == '/api/files/data/feedback.json') {
          return http.Response('', 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createLoadedContainer(mockClient: mockClient);

      // Initialize auto-save
      final autoSaveNotifier =
          container.read(feedbackAutoSaveProvider.notifier);

      // Modify content
      container.read(feedbackContentProvider.notifier).addMessage(
            'comeback',
            null,
            const FeedbackMessageModel(
              title: 'Flush Test',
              message: 'Immediate save',
              emoji: '⚡',
              shouldRepeat: true,
            ),
          );

      // Flush immediately (don't wait for debounce)
      await autoSaveNotifier.flushPendingSave();

      // Verify PUT was made
      final putRequests = capturedRequests
          .where((r) =>
              r.method == 'PUT' &&
              r.url.path == '/api/files/data/feedback.json')
          .toList();

      expect(putRequests, isNotEmpty);
    });

    test('does not save when server is disconnected', () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('', 200);
      });

      // Create container with disconnected server
      final container =
          createLoadedContainer(mockClient: mockClient, connected: false);

      // Initialize auto-save
      container.read(feedbackAutoSaveProvider);

      // Modify content
      container.read(feedbackContentProvider.notifier).addMessage(
            'comeback',
            null,
            const FeedbackMessageModel(
              title: 'Offline',
              message: 'Should not save',
              emoji: '🚫',
              shouldRepeat: true,
            ),
          );

      // Wait for debounce
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // No PUT should have been made
      final putRequests = capturedRequests
          .where((r) =>
              r.method == 'PUT' &&
              r.url.path == '/api/files/data/feedback.json')
          .toList();

      expect(putRequests, isEmpty);
      expect(
          container.read(feedbackAutoSaveProvider), FeedbackSaveStatus.idle);
    });

    test('transitions to saved then back to idle after successful save',
        () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        if (request.url.path == '/api/files/data/feedback.json') {
          return http.Response('', 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createLoadedContainer(mockClient: mockClient);

      // Initialize auto-save
      container.read(feedbackAutoSaveProvider);

      // Modify content
      container.read(feedbackContentProvider.notifier).addMessage(
            'comeback',
            null,
            const FeedbackMessageModel(
              title: 'Status Test',
              message: 'Check transitions',
              emoji: '✅',
              shouldRepeat: true,
            ),
          );

      // Wait for debounce + save
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // Should be saved
      expect(container.read(feedbackAutoSaveProvider),
          FeedbackSaveStatus.saved);

      // Wait for reset to idle (2s delay)
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      expect(
          container.read(feedbackAutoSaveProvider), FeedbackSaveStatus.idle);
    });

    test('a failed PUT is retried by the next flush', () async {
      var failNext = true;
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        if (request.url.path == '/api/files/data/feedback.json') {
          if (failNext) {
            failNext = false;
            return http.Response('{"error":"disk full"}', 500);
          }
          return http.Response('', 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createLoadedContainer(mockClient: mockClient);
      container.read(feedbackAutoSaveProvider);

      container.read(feedbackContentProvider.notifier).addMessage(
            'comeback',
            null,
            const FeedbackMessageModel(
              title: 'Retry me',
              message: 'Must survive a failed write',
              emoji: '🔁',
              shouldRepeat: true,
            ),
          );

      await container.read(feedbackAutoSaveProvider.notifier).flushPendingSave();
      expect(container.read(feedbackAutoSaveProvider), FeedbackSaveStatus.error);

      // Başarısız yazım değişikliği düşürmemeli; ikinci flush yeniden denemeli.
      await container.read(feedbackAutoSaveProvider.notifier).flushPendingSave();

      final okPuts = capturedRequests
          .where((r) =>
              r.method == 'PUT' &&
              r.url.path == '/api/files/data/feedback.json')
          .toList();
      expect(okPuts.length, 2);
      expect(okPuts.last.body, contains('Retry me'));
      expect(container.read(feedbackAutoSaveProvider), FeedbackSaveStatus.saved);
    });

    test('transitions to error on server failure', () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        if (request.url.path == '/api/files/data/feedback.json' &&
            request.method == 'PUT') {
          return http.Response('{"error": "Internal error"}', 500);
        }
        return http.Response('', 200);
      });

      final container = createLoadedContainer(mockClient: mockClient);

      // Initialize auto-save
      container.read(feedbackAutoSaveProvider);

      // Modify content
      container.read(feedbackContentProvider.notifier).addMessage(
            'comeback',
            null,
            const FeedbackMessageModel(
              title: 'Error Test',
              message: 'Server will fail',
              emoji: '❌',
              shouldRepeat: true,
            ),
          );

      // Wait for debounce + save attempt
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // Should be error
      expect(container.read(feedbackAutoSaveProvider),
          FeedbackSaveStatus.error);
    });

    test('debounces multiple rapid changes into single save', () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        if (request.url.path == '/api/files/data/feedback.json') {
          return http.Response('', 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createLoadedContainer(mockClient: mockClient);

      // Initialize auto-save
      container.read(feedbackAutoSaveProvider);

      final notifier = container.read(feedbackContentProvider.notifier);

      // Make multiple rapid changes
      notifier.addMessage(
        'comeback',
        null,
        const FeedbackMessageModel(
          title: 'Change 1',
          message: 'First',
          emoji: '1️⃣',
          shouldRepeat: true,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      notifier.addMessage(
        'comeback',
        null,
        const FeedbackMessageModel(
          title: 'Change 2',
          message: 'Second',
          emoji: '2️⃣',
          shouldRepeat: true,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      notifier.addMessage(
        'comeback',
        null,
        const FeedbackMessageModel(
          title: 'Change 3',
          message: 'Third',
          emoji: '3️⃣',
          shouldRepeat: true,
        ),
      );

      // Wait for debounce (2s from last change) + buffer
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // Should only have one PUT request (debounced)
      final putRequests = capturedRequests
          .where((r) =>
              r.method == 'PUT' &&
              r.url.path == '/api/files/data/feedback.json')
          .toList();

      expect(putRequests.length, 1);

      // The saved state should contain all 3 new messages + original
      final savedBody = putRequests.first.body;
      final savedJson = jsonDecode(savedBody) as Map<String, dynamic>;
      final comebackList = savedJson['comeback'] as List<dynamic>;
      expect(comebackList.length, 4); // original + 3 new
    });
  });

  group('Feedback auto-save with no feedback.json on the server', () {
    late List<http.Request> capturedRequests;

    ProviderContainer createEmptyContainer({required http.Client mockClient}) {
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: mockClient,
            ),
          ),
          isServerConnectedProvider.overrideWithValue(true),
          feedbackLoadProvider.overrideWith((ref) => _EmptyStatusNotifier()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      capturedRequests = [];
    });

    test('initial data created from the empty state is written to the server',
        () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('', 200);
      });
      final container = createEmptyContainer(mockClient: mockClient);
      container.read(feedbackAutoSaveProvider);

      container
          .read(feedbackContentProvider.notifier)
          .importContent(_createValidState());

      await container.read(feedbackAutoSaveProvider.notifier).flushPendingSave();

      final puts = capturedRequests
          .where((r) =>
              r.method == 'PUT' &&
              r.url.path == '/api/files/data/feedback.json')
          .toList();
      expect(puts, isNotEmpty);
      expect(puts.last.body, contains('İlim Yolcusu'));
    });
  });
}

// =============================================================================
// Test Helpers
// =============================================================================

/// A feedback load notifier that starts in loaded state immediately.
class _AlreadyLoadedNotifier extends StateNotifier<FeedbackLoadStatus>
    implements FeedbackLoadNotifier {
  _AlreadyLoadedNotifier() : super(FeedbackLoadStatus.loaded);

  @override
  bool get hasLoadedOnce => true;

  @override
  Future<void> performLoad({bool force = false}) async {}

  @override
  void markLoaded() => state = FeedbackLoadStatus.loaded;
}

/// feedback.json sunucuda yokken oluşan durum.
class _EmptyStatusNotifier extends StateNotifier<FeedbackLoadStatus>
    implements FeedbackLoadNotifier {
  _EmptyStatusNotifier() : super(FeedbackLoadStatus.empty);

  @override
  bool get hasLoadedOnce => true;

  @override
  Future<void> performLoad({bool force = false}) async {}

  @override
  void markLoaded() => state = FeedbackLoadStatus.loaded;
}
