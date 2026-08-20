import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';

/// Generators for lists of entities with random positive IDs.
extension AutoIdGenerators on Any {
  /// Generates a list of SeriesModel with random positive IDs (1–999).
  Generator<List<SeriesModel>> get seriesListWithRandomIds =>
      listWithLengthInRange(
        1,
        20,
        simple(
          generate: (random, size) {
            final id = random.nextInt(999) + 1;
            return SeriesModel(
              id: id,
              name: 'Series_$id',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            );
          },
          shrink: (input) => const Iterable.empty(),
        ),
      );

  /// Generates a list of BookModel with random positive IDs (1–999).
  Generator<List<BookModel>> get bookListWithRandomIds =>
      listWithLengthInRange(
        1,
        20,
        simple(
          generate: (random, size) {
            final id = random.nextInt(999) + 1;
            return BookModel(
              id: id,
              title: 'Book_$id',
              description: 'Description',
              assetImage: 'assets/images/book_$id/book_$id.png',
              bookOrder: 1,
              seriesId: 1,
              contentFile: 'book_$id.json',
            );
          },
          shrink: (input) => const Iterable.empty(),
        ),
      );

  /// Generates a list of LevelModel with random positive IDs (1–999).
  Generator<List<LevelModel>> get levelListWithRandomIds =>
      listWithLengthInRange(
        1,
        20,
        simple(
          generate: (random, size) {
            final id = random.nextInt(999) + 1;
            return LevelModel(
              id: id,
              bookId: 1,
              categoryName: 'Category',
              levelOrder: 1,
              title: 'Level_$id',
              unlockScore: 0,
              questions: const [],
            );
          },
          shrink: (input) => const Iterable.empty(),
        ),
      );

  /// Generates a list of LevelModel lists to simulate multiple content files.
  Generator<List<List<LevelModel>>> get multiContentFileLevels =>
      listWithLengthInRange(
        1,
        5,
        listWithLengthInRange(
          1,
          10,
          simple(
            generate: (random, size) {
              final id = random.nextInt(999) + 1;
              return LevelModel(
                id: id,
                bookId: 1,
                categoryName: 'Category',
                levelOrder: 1,
                title: 'Level_$id',
                unlockScore: 0,
                questions: const [],
              );
            },
            shrink: (input) => const Iterable.empty(),
          ),
        ),
      );
}

void main() {
  group('Property 4: Auto-ID Generation Produces Unique IDs', () {
    // -------------------------------------------------------------------------
    // Series auto-ID
    // -------------------------------------------------------------------------

    Glados(any.seriesListWithRandomIds, ExploreConfig(numRuns: 100)).test(
      'nextSeriesId equals max existing ID + 1 for non-empty lists',
      (seriesList) {
        final notifier = ContentNotifier(ContentState(
          series: seriesList,
          books: const [],
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        final maxId =
            seriesList.map((s) => s.id).reduce((a, b) => a > b ? a : b);
        final nextId = notifier.nextSeriesId;

        expect(nextId, equals(maxId + 1),
            reason: 'nextSeriesId should be max($maxId) + 1 = ${maxId + 1}');
      },
    );

    Glados(any.seriesListWithRandomIds, ExploreConfig(numRuns: 100)).test(
      'nextSeriesId never collides with existing series IDs',
      (seriesList) {
        final notifier = ContentNotifier(ContentState(
          series: seriesList,
          books: const [],
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        final existingIds = seriesList.map((s) => s.id).toSet();
        final nextId = notifier.nextSeriesId;

        expect(existingIds.contains(nextId), isFalse,
            reason: 'nextSeriesId ($nextId) must not collide with existing IDs');
      },
    );

    // -------------------------------------------------------------------------
    // Book auto-ID
    // -------------------------------------------------------------------------

    Glados(any.bookListWithRandomIds, ExploreConfig(numRuns: 100)).test(
      'nextBookId equals max existing ID + 1 for non-empty lists',
      (bookList) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: bookList,
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        final maxId =
            bookList.map((b) => b.id).reduce((a, b) => a > b ? a : b);
        final nextId = notifier.nextBookId;

        expect(nextId, equals(maxId + 1),
            reason: 'nextBookId should be max($maxId) + 1 = ${maxId + 1}');
      },
    );

    Glados(any.bookListWithRandomIds, ExploreConfig(numRuns: 100)).test(
      'nextBookId never collides with existing book IDs',
      (bookList) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: bookList,
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        final existingIds = bookList.map((b) => b.id).toSet();
        final nextId = notifier.nextBookId;

        expect(existingIds.contains(nextId), isFalse,
            reason: 'nextBookId ($nextId) must not collide with existing IDs');
      },
    );

    // -------------------------------------------------------------------------
    // Level auto-ID (across ALL content files)
    // -------------------------------------------------------------------------

    Glados(any.multiContentFileLevels, ExploreConfig(numRuns: 100)).test(
      'nextLevelId equals max ID across all content files + 1',
      (levelLists) {
        // Build content files map with distinct keys
        final contentFiles = <String, List<LevelModel>>{};
        for (var i = 0; i < levelLists.length; i++) {
          contentFiles['book_${i + 1}.json'] = levelLists[i];
        }

        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: const [],
          contentFiles: contentFiles,
          rewards: const [],
          hadiths: const [],
        ));

        final allLevels = levelLists.expand((l) => l).toList();
        final maxId =
            allLevels.map((l) => l.id).reduce((a, b) => a > b ? a : b);
        final nextId = notifier.nextLevelId;

        expect(nextId, equals(maxId + 1),
            reason: 'nextLevelId should be max($maxId) + 1 = ${maxId + 1}');
      },
    );

    Glados(any.multiContentFileLevels, ExploreConfig(numRuns: 100)).test(
      'nextLevelId never collides with any existing level ID across files',
      (levelLists) {
        final contentFiles = <String, List<LevelModel>>{};
        for (var i = 0; i < levelLists.length; i++) {
          contentFiles['book_${i + 1}.json'] = levelLists[i];
        }

        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: const [],
          contentFiles: contentFiles,
          rewards: const [],
          hadiths: const [],
        ));

        final allIds =
            levelLists.expand((l) => l).map((l) => l.id).toSet();
        final nextId = notifier.nextLevelId;

        expect(allIds.contains(nextId), isFalse,
            reason:
                'nextLevelId ($nextId) must not collide with any existing level ID');
      },
    );

    // -------------------------------------------------------------------------
    // Empty state edge case
    // -------------------------------------------------------------------------

    test('all next*Id methods return 1 for empty state', () {
      final notifier = ContentNotifier();

      expect(notifier.nextSeriesId, equals(1));
      expect(notifier.nextBookId, equals(1));
      expect(notifier.nextLevelId, equals(1));
    });
  });
}
