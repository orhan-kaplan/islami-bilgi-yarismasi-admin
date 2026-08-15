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
        capturedRequests.add(request as http.Request);
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
}

class _AlreadyLoadedAutoLoad extends StateNotifier<AutoLoadStatus>
    implements AutoLoadNotifier {
  _AlreadyLoadedAutoLoad() : super(AutoLoadStatus.loaded);

  @override
  bool get hasLoadedOnce => true;

  @override
  Future<void> performAutoLoad() async {}
}
