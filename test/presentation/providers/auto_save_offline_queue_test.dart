import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/auto_load_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/history_providers.dart';

ContentState _validState() {
  return const ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: 'Series',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: 'A',
      ),
    ],
    books: [
      BookModel(
        id: 1,
        title: 'Book',
        description: 'Desc',
        assetImage: 'assets/images/book.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: {
      'book_1.json': [
        LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'Cat',
          levelOrder: 1,
          title: 'Level',
          unlockScore: 0,
          questions: [],
        ),
      ],
    },
    rewards: [],
    hadiths: [],
  );
}

/// Connectivity that the test flips by hand, so a session can start offline
/// and reconnect later.
class _ManualConnectivity extends StateNotifier<ServerConnectivity>
    implements ServerConnectivityNotifier {
  _ManualConnectivity() : super(ServerConnectivity.disconnected);

  void connect() => state = ServerConnectivity.connected;
}

class _AlreadyLoadedAutoLoad extends StateNotifier<AutoLoadStatus>
    implements AutoLoadNotifier {
  _AlreadyLoadedAutoLoad() : super(AutoLoadStatus.loaded);

  @override
  bool get hasLoadedOnce => true;

  @override
  Future<void> performAutoLoad() async {}
}

void main() {
  group('AutoSaveController offline queue', () {
    late List<http.Request> capturedRequests;
    late _ManualConnectivity connectivity;

    ProviderContainer createContainer({required http.Client mockClient}) {
      connectivity = _ManualConnectivity();
      final initial = _validState();
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: mockClient,
            ),
          ),
          serverConnectivityProvider.overrideWith((ref) => connectivity),
          autoLoadProvider.overrideWith((ref) => _AlreadyLoadedAutoLoad()),
        ],
      );
      addTearDown(container.dispose);

      container.read(contentStateProvider.notifier).importContent(initial);
      container.read(savedBaselineProvider.notifier).state = initial;
      return container;
    }

    setUp(() {
      capturedRequests = [];
    });

    List<http.Request> putsFor(String path) => capturedRequests
        .where((r) => r.method == 'PUT' && r.url.path.endsWith(path))
        .toList();

    test('edits made while disconnected are saved after reconnecting',
        () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('', 200);
      });
      final container = createContainer(mockClient: mockClient);
      container.read(autoSaveControllerProvider);

      // Sunucu kapalıyken düzenle.
      container.read(contentStateProvider.notifier).updateSeries(
            container
                .read(contentStateProvider)
                .series
                .first
                .copyWith(name: 'Offline Edit'),
          );

      await Future<void>.delayed(const Duration(milliseconds: 2500));
      expect(putsFor('data/series.json'), isEmpty);

      // Yeniden bağlan ve flush et (reconnection dialog / Ctrl+S yolu).
      connectivity.connect();
      await container.read(autoSaveControllerProvider.notifier).flushPendingSaves();

      expect(putsFor('data/series.json'), isNotEmpty);
      expect(
        putsFor('data/series.json').last.body,
        contains('Offline Edit'),
      );
      expect(container.read(isDirtyProvider), isFalse);
    });

    test('a flush attempted while disconnected does not drop pending files',
        () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('', 200);
      });
      final container = createContainer(mockClient: mockClient);
      container.read(autoSaveControllerProvider);

      container.read(contentStateProvider.notifier).updateSeries(
            container
                .read(contentStateProvider)
                .series
                .first
                .copyWith(name: 'Offline Edit'),
          );
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      // Kullanıcı bağlantı yokken Ctrl+S'e basar.
      await container.read(autoSaveControllerProvider.notifier).flushPendingSaves();
      expect(putsFor('data/series.json'), isEmpty);

      // Sonra bağlantı gelir; değişiklik hâlâ kuyrukta olmalı.
      connectivity.connect();
      await container.read(autoSaveControllerProvider.notifier).flushPendingSaves();

      expect(putsFor('data/series.json'), isNotEmpty);
    });
  });

  group('AutoSaveController status honesty', () {
    late List<http.Request> capturedRequests;

    ProviderContainer createConnectedContainer({
      required http.Client mockClient,
    }) {
      final initial = _validState();
      final container = ProviderContainer(
        overrides: [
          assetServerClientProvider.overrideWithValue(
            AssetServerClient(
              baseUrl: 'http://localhost:8080',
              client: mockClient,
            ),
          ),
          isServerConnectedProvider.overrideWithValue(true),
          autoLoadProvider.overrideWith((ref) => _AlreadyLoadedAutoLoad()),
        ],
      );
      addTearDown(container.dispose);

      container.read(contentStateProvider.notifier).importContent(initial);
      container.read(savedBaselineProvider.notifier).state = initial;
      return container;
    }

    setUp(() {
      capturedRequests = [];
    });

    test('a blocked file keeps the status at error even after another file saves',
        () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('', 200);
      });
      final container = createConnectedContainer(mockClient: mockClient);
      container.read(autoSaveControllerProvider);

      final notifier = container.read(contentStateProvider.notifier);
      // Boş başlık books.json için ERROR üretir → o dosya bloklanır.
      notifier.updateBook(
        container.read(contentStateProvider).books.first.copyWith(title: ''),
      );
      notifier.updateSeries(
        container.read(contentStateProvider).series.first.copyWith(name: 'Edited'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 2500));

      final seriesPuts = capturedRequests
          .where((r) => r.method == 'PUT' && r.url.path.endsWith('data/series.json'));
      final bookPuts = capturedRequests
          .where((r) => r.method == 'PUT' && r.url.path.endsWith('data/books.json'));

      expect(seriesPuts, isNotEmpty, reason: 'series.json has no errors');
      expect(bookPuts, isEmpty, reason: 'books.json has an ERROR issue');
      expect(
        container.read(autoSaveControllerProvider),
        SaveStatus.error,
        reason: 'a file is still unsaved, so the status must not read as saved',
      );
    });
  });
}
