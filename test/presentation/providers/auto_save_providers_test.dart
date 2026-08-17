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

ContentState _validState({
  String seriesName = 'Series',
  String bookTitle = 'Book',
}) {
  return ContentState(
    series: [
      SeriesModel(
        id: 1,
        name: seriesName,
        sortOrder: 1,
        isLocked: false,
        iconEmoji: 'A',
      ),
    ],
    books: [
      BookModel(
        id: 1,
        title: bookTitle,
        description: 'Desc',
        assetImage: 'assets/images/book.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: const {
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
    rewards: const [],
    hadiths: const [],
  );
}

/// Two books, the second one holding an empty content file — the only shape
/// [ContentNotifier.deleteBook] allows to be deleted.
ContentState _twoBookState() {
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
        title: 'Book 1',
        description: 'Desc',
        assetImage: 'assets/images/book_1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
      BookModel(
        id: 2,
        title: 'Book 2',
        description: 'Desc',
        assetImage: 'assets/images/book_2.png',
        bookOrder: 2,
        seriesId: 1,
        contentFile: 'book_2.json',
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
      'book_2.json': [],
    },
    rewards: [],
    hadiths: [],
  );
}

void main() {
  group('AutoSaveController baseline merge', () {
    late List<http.Request> capturedRequests;

    ProviderContainer createLoadedContainer({
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
          autoLoadProvider.overrideWith(
            (ref) => _AlreadyLoadedAutoLoad(),
          ),
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

    test('starts in idle state', () {
      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });
      final container = createLoadedContainer(mockClient: mockClient);

      expect(
        container.read(autoSaveControllerProvider),
        SaveStatus.idle,
      );
    });

    test('saving series.json does not mark unsaved books as clean', () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('', 200);
      });
      final container = createLoadedContainer(mockClient: mockClient);
      container.read(autoSaveControllerProvider);

      final notifier = container.read(contentStateProvider.notifier);
      notifier.updateSeries(
        container.read(contentStateProvider).series.first.copyWith(name: 'Edited'),
      );

      await Future<void>.delayed(const Duration(seconds: 1));

      notifier.updateBook(
        container.read(contentStateProvider).books.first.copyWith(title: 'Edited Book'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final seriesPuts = capturedRequests
          .where((r) => r.method == 'PUT' && r.url.path.endsWith('data/series.json'))
          .toList();
      final bookPuts = capturedRequests
          .where((r) => r.method == 'PUT' && r.url.path.endsWith('data/books.json'))
          .toList();

      expect(seriesPuts, isNotEmpty);
      expect(bookPuts, isEmpty);
      expect(container.read(isDirtyProvider), isTrue);
      expect(
        container.read(savedBaselineProvider)!.series.first.name,
        'Edited',
      );
      expect(
        container.read(savedBaselineProvider)!.books.first.title,
        'Book',
      );

      await Future<void>.delayed(const Duration(seconds: 1));

      expect(container.read(isDirtyProvider), isFalse);
      expect(
        container.read(savedBaselineProvider)!.books.first.title,
        'Edited Book',
      );
    });
  });

  group('AutoSaveController failed writes', () {
    late List<http.Request> capturedRequests;

    ProviderContainer createLoadedContainer({
      required http.Client mockClient,
      ContentState? initial,
    }) {
      final state = initial ?? _validState();
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

      container.read(contentStateProvider.notifier).importContent(state);
      container.read(savedBaselineProvider.notifier).state = state;
      return container;
    }

    setUp(() {
      capturedRequests = [];
    });

    test('a rejected PUT is retried by the next flush', () async {
      var failNextPut = true;
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        if (request.method == 'PUT' && failNextPut) {
          failNextPut = false;
          return http.Response('{"error":"boom"}', 500);
        }
        return http.Response('', 200);
      });
      final container = createLoadedContainer(mockClient: mockClient);
      container.read(autoSaveControllerProvider);

      container.read(contentStateProvider.notifier).updateSeries(
            container
                .read(contentStateProvider)
                .series
                .first
                .copyWith(name: 'Edited'),
          );

      await Future<void>.delayed(const Duration(milliseconds: 2400));

      expect(container.read(autoSaveControllerProvider), SaveStatus.error);
      expect(container.read(isDirtyProvider), isTrue);

      await container
          .read(autoSaveControllerProvider.notifier)
          .flushPendingSaves();

      final seriesPuts = capturedRequests
          .where((r) =>
              r.method == 'PUT' && r.url.path.endsWith('data/series.json'))
          .toList();

      expect(
        seriesPuts.length,
        2,
        reason: 'the failed write must stay pending so a flush can retry it',
      );
      expect(container.read(isDirtyProvider), isFalse);
    });

    test('one rejected PUT does not cancel the other pending files', () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        if (request.method == 'PUT' &&
            request.url.path.endsWith('data/series.json')) {
          return http.Response('{"error":"boom"}', 500);
        }
        return http.Response('', 200);
      });
      final container = createLoadedContainer(mockClient: mockClient);
      container.read(autoSaveControllerProvider);

      final notifier = container.read(contentStateProvider.notifier);
      notifier.updateSeries(
        container.read(contentStateProvider).series.first.copyWith(
              name: 'Edited',
            ),
      );
      notifier.updateBook(
        container.read(contentStateProvider).books.first.copyWith(
              title: 'Edited Book',
            ),
      );

      await container
          .read(autoSaveControllerProvider.notifier)
          .flushPendingSaves();

      expect(
        capturedRequests.any((r) =>
            r.method == 'PUT' && r.url.path.endsWith('data/books.json')),
        isTrue,
        reason: 'a failure on series.json must not skip books.json',
      );
      expect(
        container.read(savedBaselineProvider)!.books.first.title,
        'Edited Book',
      );
    });
  });

  group('AutoSaveController content file removal', () {
    late List<http.Request> capturedRequests;

    ProviderContainer createLoadedContainer({
      required http.Client mockClient,
    }) {
      final initial = _twoBookState();
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

    test('deleting a book deletes its content file on the server', () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response('{"success":true}', 200);
      });
      final container = createLoadedContainer(mockClient: mockClient);
      container.read(autoSaveControllerProvider);

      final deleted = container.read(contentStateProvider.notifier).deleteBook(2);
      expect(deleted, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 2400));

      expect(
        capturedRequests.any((r) =>
            r.method == 'DELETE' &&
            r.url.path.endsWith('data/content/book_2.json')),
        isTrue,
        reason: 'an orphaned content file would otherwise stay on disk and in '
            'the app bundle',
      );
      expect(
        container.read(isDirtyProvider),
        isFalse,
        reason: 'the baseline must drop the removed content file, otherwise '
            'the unsaved-changes guard warns forever',
      );
    });

    test('a content file already gone from the server counts as saved',
        () async {
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        if (request.method == 'DELETE') {
          return http.Response('{"error":"File not found"}', 404);
        }
        return http.Response('', 200);
      });
      final container = createLoadedContainer(mockClient: mockClient);
      container.read(autoSaveControllerProvider);

      container.read(contentStateProvider.notifier).deleteBook(2);

      await Future<void>.delayed(const Duration(milliseconds: 2400));

      expect(container.read(isDirtyProvider), isFalse);
      expect(container.read(autoSaveControllerProvider),
          isNot(SaveStatus.error));
    });
  });
}

class _AlreadyLoadedAutoLoad extends StateNotifier<AutoLoadStatus>
    implements AutoLoadNotifier {
  _AlreadyLoadedAutoLoad() : super(AutoLoadStatus.loaded);

  @override
  bool get hasLoadedOnce => true;

  @override
  Future<void> performAutoLoad() async {}
}
