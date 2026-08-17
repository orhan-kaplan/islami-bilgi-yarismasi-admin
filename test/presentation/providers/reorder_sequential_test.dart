import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';

/// Generators for reorder property tests.
extension ReorderGenerators on Any {
  /// Generates a list of 2–10 series with random (non-sequential) sortOrder values.
  Generator<List<SeriesModel>> get seriesListForReorder => simple(
        generate: (random, size) {
          final count = random.nextInt(9) + 2; // 2–10 series
          return List.generate(
            count,
            (i) => SeriesModel(
              id: i + 1,
              name: 'Series_${i + 1}',
              sortOrder: random.nextInt(100) + 1, // random order values
              isLocked: random.nextBool(),
              iconEmoji: '📖',
            ),
          );
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a list of 2–8 books within the same series with random bookOrder values.
  Generator<({int seriesId, List<BookModel> books})> get booksForReorder =>
      simple(
        generate: (random, size) {
          final seriesId = random.nextInt(50) + 1;
          final count = random.nextInt(7) + 2; // 2–8 books
          final books = List.generate(
            count,
            (i) => BookModel(
              id: i + 1,
              title: 'Book_${i + 1}',
              description: 'Description',
              assetImage: 'assets/images/book_${i + 1}/book_${i + 1}.png',
              bookOrder: random.nextInt(100) + 1, // random order values
              seriesId: seriesId,
              contentFile: 'book_${i + 1}.json',
            ),
          );
          return (seriesId: seriesId, books: books);
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a list of 2–8 levels within the same content file with random levelOrder values.
  Generator<({String contentFile, List<LevelModel> levels})>
      get levelsForReorder => simple(
            generate: (random, size) {
              final bookId = random.nextInt(50) + 1;
              final contentFile = 'book_$bookId.json';
              final count = random.nextInt(7) + 2; // 2–8 levels
              final levels = List.generate(
                count,
                (i) => LevelModel(
                  id: i + 1,
                  bookId: bookId,
                  categoryName: 'Category_${i + 1}',
                  levelOrder: random.nextInt(100) + 1, // random order values
                  title: 'Level_${i + 1}',
                  unlockScore: 0,
                  questions: const [],
                ),
              );
              return (contentFile: contentFile, levels: levels);
            },
            shrink: (input) => const Iterable.empty(),
          );

  /// Generates a random permutation of indices [0..n-1].
  Generator<List<int>> permutationOf(int n) => simple(
        generate: (random, size) {
          final indices = List.generate(n, (i) => i);
          indices.shuffle(random);
          return indices;
        },
        shrink: (input) => const Iterable.empty(),
      );
}

void main() {
  group('Property 6: Reorder Produces Sequential Values', () {
    // -------------------------------------------------------------------------
    // Series reorder: resulting sortOrder values are sequential starting from 1
    // -------------------------------------------------------------------------

    Glados(any.seriesListForReorder, ExploreConfig(numRuns: 100)).test(
      'reorderSeries produces sequential sortOrder values starting from 1',
      (seriesList) {
        final notifier = ContentNotifier(ContentState(
          series: seriesList,
          books: const [],
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        // Create a random permutation of the series IDs
        final ids = seriesList.map((s) => s.id).toList()..shuffle();

        notifier.reorderSeries(ids);

        final result = notifier.state.series;

        // Verify count is preserved
        expect(result.length, equals(ids.length),
            reason: 'Reorder must preserve all series');

        // Verify sequential sortOrder values starting from 1
        for (var i = 0; i < result.length; i++) {
          expect(result[i].sortOrder, equals(i + 1),
              reason:
                  'Series at index $i should have sortOrder ${i + 1}, '
                  'got ${result[i].sortOrder}');
        }

        // Verify the order matches the requested ID order
        for (var i = 0; i < ids.length; i++) {
          expect(result[i].id, equals(ids[i]),
              reason:
                  'Series at index $i should have id ${ids[i]}, '
                  'got ${result[i].id}');
        }
      },
    );

    Glados(any.seriesListForReorder, ExploreConfig(numRuns: 100)).test(
      'reorderSeries preserves all series data except sortOrder',
      (seriesList) {
        final notifier = ContentNotifier(ContentState(
          series: seriesList,
          books: const [],
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        final originalById = {for (final s in seriesList) s.id: s};
        final ids = seriesList.map((s) => s.id).toList()..shuffle();

        notifier.reorderSeries(ids);

        final result = notifier.state.series;
        for (final s in result) {
          final original = originalById[s.id]!;
          expect(s.name, equals(original.name));
          expect(s.isLocked, equals(original.isLocked));
          expect(s.iconEmoji, equals(original.iconEmoji));
          expect(s.description, equals(original.description));
        }
      },
    );

    // -------------------------------------------------------------------------
    // Book reorder: resulting bookOrder values are sequential starting from 1
    // -------------------------------------------------------------------------

    Glados(any.booksForReorder, ExploreConfig(numRuns: 100)).test(
      'reorderBooks produces sequential bookOrder values starting from 1',
      (data) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: data.books,
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        // Create a random permutation of the book IDs
        final ids = data.books.map((b) => b.id).toList()..shuffle();

        notifier.reorderBooks(data.seriesId, ids);

        final result = notifier.state.books
            .where((b) => b.seriesId == data.seriesId)
            .toList();

        // Verify count is preserved
        expect(result.length, equals(ids.length),
            reason: 'Reorder must preserve all books');

        // Verify sequential bookOrder values starting from 1
        // Sort by bookOrder to check sequential values
        final sortedByOrder = List<BookModel>.from(result)
          ..sort((a, b) => a.bookOrder.compareTo(b.bookOrder));
        for (var i = 0; i < sortedByOrder.length; i++) {
          expect(sortedByOrder[i].bookOrder, equals(i + 1),
              reason:
                  'Book at order position $i should have bookOrder ${i + 1}, '
                  'got ${sortedByOrder[i].bookOrder}');
        }

        // Verify the bookOrder matches the requested ID order
        for (var i = 0; i < ids.length; i++) {
          final book = result.firstWhere((b) => b.id == ids[i]);
          expect(book.bookOrder, equals(i + 1),
              reason:
                  'Book with id ${ids[i]} should have bookOrder ${i + 1}, '
                  'got ${book.bookOrder}');
        }
      },
    );

    Glados(any.booksForReorder, ExploreConfig(numRuns: 100)).test(
      'reorderBooks preserves all book data except bookOrder',
      (data) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: data.books,
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        final originalById = {for (final b in data.books) b.id: b};
        final ids = data.books.map((b) => b.id).toList()..shuffle();

        notifier.reorderBooks(data.seriesId, ids);

        final result = notifier.state.books;
        for (final b in result) {
          final original = originalById[b.id]!;
          expect(b.title, equals(original.title));
          expect(b.description, equals(original.description));
          expect(b.assetImage, equals(original.assetImage));
          expect(b.seriesId, equals(original.seriesId));
          expect(b.contentFile, equals(original.contentFile));
        }
      },
    );

    // -------------------------------------------------------------------------
    // Book reorder: books in other series are not affected
    // -------------------------------------------------------------------------

    Glados(any.booksForReorder, ExploreConfig(numRuns: 100)).test(
      'reorderBooks does not affect books in other series',
      (data) {
        // Add books from a different series
        final otherSeriesId = data.seriesId + 100;
        final otherBooks = [
          BookModel(
            id: 100,
            title: 'OtherBook_1',
            description: 'Other',
            assetImage: 'assets/images/other/other.png',
            bookOrder: 5,
            seriesId: otherSeriesId,
            contentFile: 'other_1.json',
          ),
          BookModel(
            id: 101,
            title: 'OtherBook_2',
            description: 'Other',
            assetImage: 'assets/images/other/other2.png',
            bookOrder: 3,
            seriesId: otherSeriesId,
            contentFile: 'other_2.json',
          ),
        ];

        final allBooks = [...data.books, ...otherBooks];
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: allBooks,
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        final ids = data.books.map((b) => b.id).toList()..shuffle();
        notifier.reorderBooks(data.seriesId, ids);

        // Verify other series books are unchanged
        final otherResult =
            notifier.state.books.where((b) => b.seriesId == otherSeriesId).toList();
        expect(otherResult.length, equals(2));
        expect(otherResult[0].bookOrder, equals(5));
        expect(otherResult[1].bookOrder, equals(3));
      },
    );

    // -------------------------------------------------------------------------
    // Level reorder: resulting levelOrder values are sequential starting from 1
    // -------------------------------------------------------------------------

    Glados(any.levelsForReorder, ExploreConfig(numRuns: 100)).test(
      'reorderLevels produces sequential levelOrder values starting from 1',
      (data) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: const [],
          contentFiles: {data.contentFile: data.levels},
          rewards: const [],
          hadiths: const [],
        ));

        // Create a random permutation of the level IDs
        final ids = data.levels.map((l) => l.id).toList()..shuffle();

        notifier.reorderLevels(data.contentFile, ids);

        final result = notifier.state.contentFiles[data.contentFile]!;

        // Verify count is preserved
        expect(result.length, equals(ids.length),
            reason: 'Reorder must preserve all levels');

        // Verify sequential levelOrder values starting from 1
        for (var i = 0; i < result.length; i++) {
          expect(result[i].levelOrder, equals(i + 1),
              reason:
                  'Level at index $i should have levelOrder ${i + 1}, '
                  'got ${result[i].levelOrder}');
        }

        // Verify the order matches the requested ID order
        for (var i = 0; i < ids.length; i++) {
          expect(result[i].id, equals(ids[i]),
              reason:
                  'Level at index $i should have id ${ids[i]}, '
                  'got ${result[i].id}');
        }
      },
    );

    Glados(any.levelsForReorder, ExploreConfig(numRuns: 100)).test(
      'reorderLevels preserves all level data except levelOrder',
      (data) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: const [],
          contentFiles: {data.contentFile: data.levels},
          rewards: const [],
          hadiths: const [],
        ));

        final originalById = {for (final l in data.levels) l.id: l};
        final ids = data.levels.map((l) => l.id).toList()..shuffle();

        notifier.reorderLevels(data.contentFile, ids);

        final result = notifier.state.contentFiles[data.contentFile]!;
        for (final l in result) {
          final original = originalById[l.id]!;
          expect(l.bookId, equals(original.bookId));
          expect(l.categoryName, equals(original.categoryName));
          expect(l.title, equals(original.title));
          expect(l.unlockScore, equals(original.unlockScore));
          expect(l.assetImage, equals(original.assetImage));
          expect(l.questions, equals(original.questions));
        }
      },
    );

    // -------------------------------------------------------------------------
    // Level reorder: levels in other content files are not affected
    // -------------------------------------------------------------------------

    Glados(any.levelsForReorder, ExploreConfig(numRuns: 100)).test(
      'reorderLevels does not affect levels in other content files',
      (data) {
        final otherContentFile = 'other_${data.contentFile}';
        final otherLevels = [
          const LevelModel(
            id: 200,
            bookId: 99,
            categoryName: 'Other',
            levelOrder: 7,
            title: 'OtherLevel',
            unlockScore: 0,
            questions: [],
          ),
        ];

        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: const [],
          contentFiles: {
            data.contentFile: data.levels,
            otherContentFile: otherLevels,
          },
          rewards: const [],
          hadiths: const [],
        ));

        final ids = data.levels.map((l) => l.id).toList()..shuffle();
        notifier.reorderLevels(data.contentFile, ids);

        // Verify other content file levels are unchanged
        final otherResult = notifier.state.contentFiles[otherContentFile]!;
        expect(otherResult.length, equals(1));
        expect(otherResult[0].levelOrder, equals(7));
        expect(otherResult[0].id, equals(200));
      },
    );
  });
}
