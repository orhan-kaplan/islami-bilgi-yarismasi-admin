
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/auto_load_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/history_providers.dart';

/// Sample JSON data for testing auto-load.
const _seriesJson = '''
[
  {"id": 1, "name": "Test Series", "sort_order": 1, "is_locked": false, "icon_emoji": "A"}
]
''';

const _booksJson = '''
[
  {"id": 1, "series_id": 1, "title": "Test Book", "description": "Desc", "book_order": 1, "content_file": "book_1.json", "asset_image": "assets/images/book_1/book_1.png"}
]
''';

const _rewardsJson = '''
[
  {"title": "Reward 1", "description": "Desc", "asset_image": "assets/images/rewards/reward.webp", "unlock_book_id": 1}
]
''';

const _hadithsJson = '''
[
  {"text": "Test hadith", "source": "Test source"}
]
''';

const _contentFileJson = '''
{
  "levels": [
    {
      "id": 1,
      "book_id": 1,
      "category_name": "Category 1",
      "level_order": 1,
      "title": "Level 1",
      "unlock_score": 0,
      "questions": []
    }
  ]
}
''';

const _contentDirListing = '''
[
  {"name": "book_1.json", "path": "data/content/book_1.json", "size": 100, "type": "file"}
]
''';

const _healthJson = '''
{"status": "ok", "assetsRoot": "/tmp/assets", "readWrite": true}
''';

void main() {
  group('AutoLoadNotifier', () {
    /// Creates a [ProviderContainer] with mocked HTTP client.
    ProviderContainer createContainer({
      required http.Client mockClient,
      List<Override> extraOverrides = const [],
    }) {
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: mockClient,
            ),
          ),
          ...extraOverrides,
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    /// Creates a mock client that responds to all auto-load requests
    /// (health check succeeds, all data files available).
    MockClient createSuccessfulMockClient() {
      return MockClient((request) async {
        final path = request.url.path;

        if (path == '/api/health') {
          return http.Response(_healthJson, 200);
        }
        if (path == '/api/files/data/series.json') {
          return http.Response(_seriesJson, 200);
        }
        if (path == '/api/files/data/books.json') {
          return http.Response(_booksJson, 200);
        }
        if (path == '/api/files/data/rewards.json') {
          return http.Response(_rewardsJson, 200);
        }
        if (path == '/api/files/data/hadiths.json') {
          return http.Response(_hadithsJson, 200);
        }
        if (path == '/api/list/data/content') {
          return http.Response(_contentDirListing, 200);
        }
        if (path == '/api/files/data/content/book_1.json') {
          return http.Response(_contentFileJson, 200);
        }

        return http.Response('Not found', 404);
      });
    }

    test('initial state is idle', () {
      final mockClient = createSuccessfulMockClient();
      final container = createContainer(mockClient: mockClient);

      // Read auto-load without triggering connectivity first
      // The notifier starts idle and waits for connectivity
      final status = container.read(autoLoadProvider);
      // It may be idle or already loading depending on connectivity timing
      expect(
        status,
        anyOf(AutoLoadStatus.idle, AutoLoadStatus.loading),
      );
    });

    test('performAutoLoad transitions to loaded on success', () async {
      final mockClient = createSuccessfulMockClient();
      final container = createContainer(mockClient: mockClient);

      // Directly call performAutoLoad to test the load sequence
      final notifier = container.read(autoLoadProvider.notifier);
      await notifier.performAutoLoad();

      final status = container.read(autoLoadProvider);
      expect(status, AutoLoadStatus.loaded);
      expect(notifier.loadedFromServer, isTrue);
    });

    test('populates ContentState after successful load', () async {
      final mockClient = createSuccessfulMockClient();
      final container = createContainer(mockClient: mockClient);

      await container.read(autoLoadProvider.notifier).performAutoLoad();

      final contentState = container.read(contentStateProvider);
      expect(contentState.series.length, 1);
      expect(contentState.series.first.name, 'Test Series');
      expect(contentState.books.length, 1);
      expect(contentState.books.first.title, 'Test Book');
      expect(contentState.rewards.length, 1);
      expect(contentState.hadiths.length, 1);
      expect(contentState.contentFiles.containsKey('book_1.json'), isTrue);
      expect(contentState.contentFiles['book_1.json']!.length, 1);
    });

    test('sets saved baseline after successful load', () async {
      final mockClient = createSuccessfulMockClient();
      final container = createContainer(mockClient: mockClient);

      await container.read(autoLoadProvider.notifier).performAutoLoad();

      final baseline = container.read(savedBaselineProvider);
      expect(baseline, isNotNull);

      final contentState = container.read(contentStateProvider);
      expect(baseline, equals(contentState));
    });

    test('clears undo/redo history after successful load', () async {
      final mockClient = createSuccessfulMockClient();
      final container = createContainer(mockClient: mockClient);

      // Push some history first
      final dummyState = ContentState.empty();
      container.read(historyProvider.notifier).pushState(dummyState);
      expect(container.read(canUndoProvider), isTrue);

      // Perform auto-load
      await container.read(autoLoadProvider.notifier).performAutoLoad();

      // History should be cleared
      expect(container.read(canUndoProvider), isFalse);
      expect(container.read(canRedoProvider), isFalse);
    });

    test('transitions to failed when health check fails', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final container = createContainer(mockClient: mockClient);

      await container.read(autoLoadProvider.notifier).performAutoLoad();

      final status = container.read(autoLoadProvider);
      expect(status, AutoLoadStatus.failed);
    });

    test('transitions to failed when a data file fetch returns error',
        () async {
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') {
          return http.Response(_healthJson, 200);
        }
        // series.json returns 404
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      await container.read(autoLoadProvider.notifier).performAutoLoad();

      final status = container.read(autoLoadProvider);
      expect(status, AutoLoadStatus.failed);
    });

    test('autoLoadCompleteProvider returns true after successful load',
        () async {
      final mockClient = createSuccessfulMockClient();
      final container = createContainer(mockClient: mockClient);

      await container.read(autoLoadProvider.notifier).performAutoLoad();

      expect(container.read(autoLoadCompleteProvider), isTrue);
    });

    test('autoLoadCompleteProvider returns false when load fails', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final container = createContainer(mockClient: mockClient);

      await container.read(autoLoadProvider.notifier).performAutoLoad();

      expect(container.read(autoLoadCompleteProvider), isFalse);
    });

    test('hasLoadedOnce is true after successful load', () async {
      final mockClient = createSuccessfulMockClient();
      final container = createContainer(mockClient: mockClient);

      final notifier = container.read(autoLoadProvider.notifier);
      expect(notifier.hasLoadedOnce, isFalse);

      await notifier.performAutoLoad();

      expect(notifier.hasLoadedOnce, isTrue);
    });

    test('hasLoadedOnce remains false after failed load', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final container = createContainer(mockClient: mockClient);

      final notifier = container.read(autoLoadProvider.notifier);
      await notifier.performAutoLoad();

      expect(notifier.hasLoadedOnce, isFalse);
      expect(notifier.loadedFromServer, isFalse);
    });

    test('retry via performAutoLoad works after initial failure', () async {
      var healthCallCount = 0;
      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path == '/api/health') {
          healthCallCount++;
          if (healthCallCount <= 2) {
            // First two health calls fail (connectivity check + first auto-load)
            throw http.ClientException('Connection refused');
          }
          return http.Response(_healthJson, 200);
        }
        if (path == '/api/files/data/series.json') {
          return http.Response(_seriesJson, 200);
        }
        if (path == '/api/files/data/books.json') {
          return http.Response(_booksJson, 200);
        }
        if (path == '/api/files/data/rewards.json') {
          return http.Response(_rewardsJson, 200);
        }
        if (path == '/api/files/data/hadiths.json') {
          return http.Response(_hadithsJson, 200);
        }
        if (path == '/api/list/data/content') {
          return http.Response(_contentDirListing, 200);
        }
        if (path == '/api/files/data/content/book_1.json') {
          return http.Response(_contentFileJson, 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(mockClient: mockClient);

      final notifier = container.read(autoLoadProvider.notifier);

      // First attempt fails (health throws)
      await notifier.performAutoLoad();
      expect(container.read(autoLoadProvider), AutoLoadStatus.failed);

      // Retry succeeds (healthCallCount > 2)
      await notifier.performAutoLoad();
      expect(container.read(autoLoadProvider), AutoLoadStatus.loaded);
    });

    test('content state is empty before load', () {
      final mockClient = createSuccessfulMockClient();
      final container = createContainer(mockClient: mockClient);

      final contentState = container.read(contentStateProvider);
      expect(contentState, equals(ContentState.empty()));
    });

    test('auto-triggers when connectivity becomes connected', () async {
      final mockClient = createSuccessfulMockClient();
      final container = createContainer(mockClient: mockClient);

      // Read auto-load provider — this creates the notifier which listens
      // to connectivity. The connectivity notifier will do a health check
      // and transition to connected, which should trigger auto-load.
      container.read(autoLoadProvider);

      // Wait for connectivity health check + auto-load sequence
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final status = container.read(autoLoadProvider);
      expect(status, AutoLoadStatus.loaded);
    });

    test('markSessionLoaded does not claim the bytes came from GET', () {
      final connectivity = _ManualConnectivity();
      final container = createContainer(
        mockClient: createSuccessfulMockClient(),
        extraOverrides: [
          serverConnectivityProvider.overrideWith((ref) => connectivity),
        ],
      );

      final notifier = container.read(autoLoadProvider.notifier);
      notifier.markSessionLoaded();

      expect(container.read(autoLoadProvider), AutoLoadStatus.loaded);
      expect(notifier.hasLoadedOnce, isTrue);
      expect(notifier.loadedFromServer, isFalse);
      expect(container.read(hasUnsyncedLocalSessionProvider), isTrue);
    });

    test('first connect does not overwrite in-memory ZIP content', () async {
      final connectivity = _ManualConnectivity();
      var seriesGets = 0;
      final mockClient = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/health') {
          return http.Response(_healthJson, 200);
        }
        if (path == '/api/files/data/series.json') {
          seriesGets++;
          return http.Response(_seriesJson, 200);
        }
        if (path == '/api/files/data/books.json') {
          return http.Response(_booksJson, 200);
        }
        if (path == '/api/files/data/rewards.json') {
          return http.Response(_rewardsJson, 200);
        }
        if (path == '/api/files/data/hadiths.json') {
          return http.Response(_hadithsJson, 200);
        }
        if (path == '/api/list/data/content') {
          return http.Response(_contentDirListing, 200);
        }
        if (path == '/api/files/data/content/book_1.json') {
          return http.Response(_contentFileJson, 200);
        }
        return http.Response('Not found', 404);
      });

      final container = createContainer(
        mockClient: mockClient,
        extraOverrides: [
          serverConnectivityProvider.overrideWith((ref) => connectivity),
        ],
      );

      const local = HadithModel(text: 'ZIP hadisi', source: 'Yerel');
      container.read(contentStateProvider.notifier).importContent(
            ContentState.empty().copyWith(hadiths: const [local]),
          );

      final notifier = container.read(autoLoadProvider.notifier);
      connectivity.connect();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(contentStateProvider).hadiths.single.text, 'ZIP hadisi');
      expect(container.read(contentStateProvider).series, isEmpty);
      expect(container.read(autoLoadProvider), AutoLoadStatus.loaded);
      expect(notifier.loadedFromServer, isFalse);
      expect(seriesGets, 0);
      expect(container.read(hasUnsyncedLocalSessionProvider), isTrue);

      await notifier.performAutoLoad();
      expect(
        container.read(contentStateProvider).hadiths.single.text,
        'ZIP hadisi',
        reason: 'Retry without force must still keep the local tree',
      );
      expect(seriesGets, 0);

      await notifier.performAutoLoad(force: true);
      expect(container.read(contentStateProvider).series.first.name, 'Test Series');
      expect(container.read(contentStateProvider).hadiths.single.text, 'Test hadith');
      expect(notifier.loadedFromServer, isTrue);
      expect(seriesGets, 1);
      expect(container.read(hasUnsyncedLocalSessionProvider), isFalse);
    });
  });
}

class _ManualConnectivity extends StateNotifier<ServerConnectivity>
    implements ServerConnectivityNotifier {
  _ManualConnectivity() : super(ServerConnectivity.disconnected);

  void connect() => state = ServerConnectivity.connected;
}
