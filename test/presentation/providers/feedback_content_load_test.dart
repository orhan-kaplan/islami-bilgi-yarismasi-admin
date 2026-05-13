import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';

/// Sample valid feedback JSON for testing.
final _validFeedbackJson = jsonEncode({
  'quiz': {
    'speed_demon': [
      {
        'title': 'Simsek Gibi!',
        'message': 'Masallah, hizina yetisilmiyor!',
        'emoji': 'E',
        'lottie_asset': 'feedback/lightning.json',
        'should_repeat': false,
      }
    ],
    'perfect': [
      {
        'title': 'Mukemmel!',
        'message': 'Tebrikler!',
        'emoji': 'S',
        'lottie_asset': null,
        'should_repeat': true,
      }
    ],
  },
  'speed_quiz': {
    'combo_master': [
      {
        'title': 'Kombo Ustasi!',
        'message': 'Harika kombo!',
        'emoji': 'F',
        'lottie_asset': null,
        'should_repeat': true,
      }
    ],
  },
  'time': {
    'seher': [
      {
        'title': 'Seher Vakti',
        'message': 'Seher vaktinde calisiyorsun!',
        'emoji': 'M',
        'lottie_asset': null,
        'should_repeat': true,
      }
    ],
  },
  'comeback': [
    {
      'title': 'Hos Geldin!',
      'message': 'Seni ozledik!',
      'emoji': 'W',
      'lottie_asset': null,
      'should_repeat': true,
    }
  ],
  'streak': {
    '3': [
      {
        'title': '3 Gun!',
        'message': 'Uc gun ust uste!',
        'emoji': 'F',
        'lottie_asset': null,
        'should_repeat': true,
      }
    ],
  },
  'titles': [
    {
      'title': 'Ilim Yolcusu',
      'icon': 'S',
      'required_books': 0,
      'profile_image': 'images/seed/profile_icon_seed.webp',
    },
    {
      'title': 'Ilim Talebesi',
      'icon': 'B',
      'required_books': 1,
      'profile_image': 'images/seed/profile_icon_student.webp',
    },
  ],
  'learned': {
    '100': [
      {
        'title': 'Tam Puan!',
        'message': 'Hepsini ogrendin!',
        'emoji': 'T',
        'lottie_asset': null,
        'should_repeat': true,
      }
    ],
  },
});

const _healthJson = '{"status": "ok", "assetsRoot": "/tmp/assets", "readWrite": true}';

void main() {
  group('FeedbackContentNotifier.loadFromServer', () {
    test('loads and parses valid feedback JSON from server', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/files/data/feedback.json') {
          return http.Response(_validFeedbackJson, 200);
        }
        return http.Response('Not found', 404);
      });

      final client = AssetServerClient(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final notifier = FeedbackContentNotifier();
      await notifier.loadFromServer(client);

      expect(notifier.state.quiz.containsKey('speed_demon'), isTrue);
      expect(notifier.state.quiz['speed_demon']!.length, 1);
      expect(notifier.state.quiz['speed_demon']!.first.title, 'Simsek Gibi!');
      expect(notifier.state.comeback.length, 1);
      expect(notifier.state.titles.length, 2);
      expect(notifier.state.titles.first.title, 'Ilim Yolcusu');
    });

    test('sets empty state on 404 (file not found)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "File not found"}', 404);
      });

      final client = AssetServerClient(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final notifier = FeedbackContentNotifier();
      await notifier.loadFromServer(client);

      expect(notifier.state, equals(FeedbackContentState.empty()));
    });

    test('rethrows non-404 AssetServerException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "Internal error"}', 500);
      });

      final client = AssetServerClient(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final notifier = FeedbackContentNotifier();
      expect(
        () => notifier.loadFromServer(client),
        throwsA(isA<AssetServerException>()),
      );
    });

    test('parses all categories correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/files/data/feedback.json') {
          return http.Response(_validFeedbackJson, 200);
        }
        return http.Response('Not found', 404);
      });

      final client = AssetServerClient(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final notifier = FeedbackContentNotifier();
      await notifier.loadFromServer(client);

      expect(notifier.state.quiz.containsKey('speed_demon'), isTrue);
      expect(notifier.state.quiz.containsKey('perfect'), isTrue);
      expect(notifier.state.speedQuiz.containsKey('combo_master'), isTrue);
      expect(notifier.state.time.containsKey('seher'), isTrue);
      expect(notifier.state.comeback.length, 1);
      expect(notifier.state.streak.containsKey('3'), isTrue);
      expect(notifier.state.titles.length, 2);
      expect(notifier.state.learned.containsKey('100'), isTrue);
    });

    test('parses lottie_asset and should_repeat correctly', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/files/data/feedback.json') {
          return http.Response(_validFeedbackJson, 200);
        }
        return http.Response('Not found', 404);
      });

      final client = AssetServerClient(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final notifier = FeedbackContentNotifier();
      await notifier.loadFromServer(client);

      final speedDemon = notifier.state.quiz['speed_demon']!.first;
      expect(speedDemon.lottieAsset, 'feedback/lightning.json');
      expect(speedDemon.shouldRepeat, false);

      final perfect = notifier.state.quiz['perfect']!.first;
      expect(perfect.lottieAsset, isNull);
      expect(perfect.shouldRepeat, true);
    });
  });

  group('FeedbackLoadNotifier', () {
    ProviderContainer createContainer({required http.Client mockClient}) {
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: mockClient,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('performLoad transitions to loaded on success', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') {
          return http.Response(_healthJson, 200);
        }
        if (path == '/api/files/data/feedback.json') {
          return http.Response(_validFeedbackJson, 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      final notifier = container.read(feedbackLoadProvider.notifier);
      await notifier.performLoad();

      expect(container.read(feedbackLoadProvider), FeedbackLoadStatus.loaded);
    });

    test('performLoad transitions to empty on 404', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') {
          return http.Response(_healthJson, 200);
        }
        if (path == '/api/files/data/feedback.json') {
          return http.Response('{"error": "File not found"}', 404);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      final notifier = container.read(feedbackLoadProvider.notifier);
      await notifier.performLoad();

      expect(container.read(feedbackLoadProvider), FeedbackLoadStatus.empty);
      expect(container.read(feedbackNeedsInitialDataProvider), isTrue);
    });

    test('performLoad transitions to failed on server error', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') {
          return http.Response(_healthJson, 200);
        }
        if (path == '/api/files/data/feedback.json') {
          return http.Response('{"error": "Internal error"}', 500);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      final notifier = container.read(feedbackLoadProvider.notifier);
      await notifier.performLoad();

      expect(container.read(feedbackLoadProvider), FeedbackLoadStatus.failed);
    });

    test('performLoad transitions to failed on network error', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final container = createContainer(mockClient: mockClient);

      final notifier = container.read(feedbackLoadProvider.notifier);
      await notifier.performLoad();

      expect(container.read(feedbackLoadProvider), FeedbackLoadStatus.failed);
    });

    test('populates feedbackContentProvider after successful load', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') {
          return http.Response(_healthJson, 200);
        }
        if (path == '/api/files/data/feedback.json') {
          return http.Response(_validFeedbackJson, 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      await container.read(feedbackLoadProvider.notifier).performLoad();

      final state = container.read(feedbackContentProvider);
      expect(state.quiz.isNotEmpty, isTrue);
      expect(state.titles.length, 2);
      expect(state.comeback.length, 1);
    });

    test('feedbackNeedsInitialDataProvider is false when loaded', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') {
          return http.Response(_healthJson, 200);
        }
        if (path == '/api/files/data/feedback.json') {
          return http.Response(_validFeedbackJson, 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      await container.read(feedbackLoadProvider.notifier).performLoad();

      expect(container.read(feedbackNeedsInitialDataProvider), isFalse);
    });

    test('auto-triggers when connectivity becomes connected', () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') {
          return http.Response(_healthJson, 200);
        }
        if (path == '/api/files/data/feedback.json') {
          return http.Response(_validFeedbackJson, 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      // Read the feedback load provider — this creates the notifier which
      // listens to connectivity. The connectivity notifier will do a health
      // check and transition to connected, triggering the load.
      container.read(feedbackLoadProvider);

      // Wait for connectivity health check + load sequence
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final status = container.read(feedbackLoadProvider);
      expect(status, FeedbackLoadStatus.loaded);
    });
  });
}
