import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';

/// Generators for states with parent-child relationships.
extension DeletionGuardGenerators on Any {
  /// Generates a series with 1–5 books referencing it.
  Generator<({SeriesModel series, List<BookModel> books})>
      get seriesWithBooks => simple(
            generate: (random, size) {
              final seriesId = random.nextInt(100) + 1;
              final bookCount = random.nextInt(5) + 1;
              final series = SeriesModel(
                id: seriesId,
                name: 'Series_$seriesId',
                sortOrder: 1,
                isLocked: false,
                iconEmoji: '📖',
              );
              final books = List.generate(
                bookCount,
                (i) => BookModel(
                  id: i + 1,
                  title: 'Book_${i + 1}',
                  description: 'Description',
                  assetImage: 'assets/images/book_${i + 1}/book_${i + 1}.png',
                  bookOrder: i + 1,
                  seriesId: seriesId,
                  contentFile: 'book_${i + 1}.json',
                ),
              );
              return (series: series, books: books);
            },
            shrink: (input) => const Iterable.empty(),
          );

  /// Generates a book with 1–5 levels in its content file.
  Generator<({BookModel book, List<LevelModel> levels})>
      get bookWithLevels => simple(
            generate: (random, size) {
              final bookId = random.nextInt(100) + 1;
              final levelCount = random.nextInt(5) + 1;
              final contentFile = 'book_$bookId.json';
              final book = BookModel(
                id: bookId,
                title: 'Book_$bookId',
                description: 'Description',
                assetImage: 'assets/images/book_$bookId/book_$bookId.png',
                bookOrder: 1,
                seriesId: 1,
                contentFile: contentFile,
              );
              final levels = List.generate(
                levelCount,
                (i) => LevelModel(
                  id: i + 1,
                  bookId: bookId,
                  categoryName: 'Category',
                  levelOrder: i + 1,
                  title: 'Level_${i + 1}',
                  unlockScore: 0,
                  questions: const [],
                ),
              );
              return (book: book, levels: levels);
            },
            shrink: (input) => const Iterable.empty(),
          );

  /// Generates a series with NO books referencing it (orphan series).
  Generator<SeriesModel> get orphanSeries => simple(
        generate: (random, size) {
          final seriesId = random.nextInt(100) + 1;
          return SeriesModel(
            id: seriesId,
            name: 'OrphanSeries_$seriesId',
            sortOrder: 1,
            isLocked: false,
            iconEmoji: '📚',
          );
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a book with an empty content file (no levels).
  Generator<BookModel> get bookWithNoLevels => simple(
        generate: (random, size) {
          final bookId = random.nextInt(100) + 1;
          return BookModel(
            id: bookId,
            title: 'EmptyBook_$bookId',
            description: 'Description',
            assetImage: 'assets/images/book_$bookId/book_$bookId.png',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_$bookId.json',
          );
        },
        shrink: (input) => const Iterable.empty(),
      );
}

void main() {
  group('Property 5: Non-Empty Parent Deletion Guard', () {
    // -------------------------------------------------------------------------
    // Series deletion guard: series with books is rejected
    // -------------------------------------------------------------------------

    Glados(any.seriesWithBooks, ExploreConfig(numRuns: 100)).test(
      'deleteSeries returns false when series has books',
      (data) {
        final notifier = ContentNotifier(ContentState(
          series: [data.series],
          books: data.books,
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        final result = notifier.deleteSeries(data.series.id);

        expect(result, isFalse,
            reason:
                'Deleting series ${data.series.id} with ${data.books.length} '
                'books should be rejected');
      },
    );

    Glados(any.seriesWithBooks, ExploreConfig(numRuns: 100)).test(
      'state remains unchanged after rejected series deletion',
      (data) {
        final initialState = ContentState(
          series: [data.series],
          books: data.books,
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        );
        final notifier = ContentNotifier(initialState);

        notifier.deleteSeries(data.series.id);

        expect(notifier.state, equals(initialState),
            reason: 'State must not change when deletion is rejected');
      },
    );

    // -------------------------------------------------------------------------
    // Book deletion guard: book with levels is rejected
    // -------------------------------------------------------------------------

    Glados(any.bookWithLevels, ExploreConfig(numRuns: 100)).test(
      'deleteBook returns false when book has levels',
      (data) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: [data.book],
          contentFiles: {data.book.contentFile: data.levels},
          rewards: const [],
          hadiths: const [],
        ));

        final result = notifier.deleteBook(data.book.id);

        expect(result, isFalse,
            reason: 'Deleting book ${data.book.id} with ${data.levels.length} '
                'levels should be rejected');
      },
    );

    Glados(any.bookWithLevels, ExploreConfig(numRuns: 100)).test(
      'state remains unchanged after rejected book deletion',
      (data) {
        final initialState = ContentState(
          series: const [],
          books: [data.book],
          contentFiles: {data.book.contentFile: data.levels},
          rewards: const [],
          hadiths: const [],
        );
        final notifier = ContentNotifier(initialState);

        notifier.deleteBook(data.book.id);

        expect(notifier.state, equals(initialState),
            reason: 'State must not change when deletion is rejected');
      },
    );

    // -------------------------------------------------------------------------
    // Series deletion succeeds when no books reference it
    // -------------------------------------------------------------------------

    Glados(any.orphanSeries, ExploreConfig(numRuns: 100)).test(
      'deleteSeries returns true when series has no books',
      (series) {
        final notifier = ContentNotifier(ContentState(
          series: [series],
          books: const [],
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        final result = notifier.deleteSeries(series.id);

        expect(result, isTrue,
            reason:
                'Deleting series ${series.id} with no books should succeed');
      },
    );

    Glados(any.orphanSeries, ExploreConfig(numRuns: 100)).test(
      'series is removed from state after successful deletion',
      (series) {
        final notifier = ContentNotifier(ContentState(
          series: [series],
          books: const [],
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        notifier.deleteSeries(series.id);

        expect(notifier.state.series, isEmpty,
            reason: 'Series list should be empty after successful deletion');
      },
    );

    // -------------------------------------------------------------------------
    // Book deletion succeeds when no levels exist
    // -------------------------------------------------------------------------

    Glados(any.bookWithNoLevels, ExploreConfig(numRuns: 100)).test(
      'deleteBook returns true when book has no levels',
      (book) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: [book],
          contentFiles: {book.contentFile: const []},
          rewards: const [],
          hadiths: const [],
        ));

        final result = notifier.deleteBook(book.id);

        expect(result, isTrue,
            reason: 'Deleting book ${book.id} with no levels should succeed');
      },
    );

    Glados(any.bookWithNoLevels, ExploreConfig(numRuns: 100)).test(
      'book is removed from state after successful deletion',
      (book) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: [book],
          contentFiles: {book.contentFile: const []},
          rewards: const [],
          hadiths: const [],
        ));

        notifier.deleteBook(book.id);

        expect(notifier.state.books, isEmpty,
            reason: 'Books list should be empty after successful deletion');
      },
    );

    // -------------------------------------------------------------------------
    // Book deletion succeeds when content file is not in map at all
    // -------------------------------------------------------------------------

    Glados(any.bookWithNoLevels, ExploreConfig(numRuns: 100)).test(
      'deleteBook returns true when content file is absent from map',
      (book) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: [book],
          contentFiles: const {},
          rewards: const [],
          hadiths: const [],
        ));

        final result = notifier.deleteBook(book.id);

        expect(result, isTrue,
            reason: 'Deleting book with no content file entry should succeed');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Book deletion is blocked while a reward still unlocks the book
  //
  // The reward → book FK is reported against rewards.json, but deleting a book
  // only makes books.json dirty. Per-file save gating therefore never sees the
  // dangling reference: books.json is written and rewards.json keeps pointing
  // at a book that no longer exists.
  // ---------------------------------------------------------------------------

  group('deleteBook guards the reward foreign key', () {
    ContentNotifier notifierWithReward({required int unlockBookId}) =>
        ContentNotifier(ContentState(
          series: const [],
          books: const [
            BookModel(
              id: 1,
              title: 'Book 1',
              description: 'Description',
              assetImage: 'assets/images/book_1/book_1.png',
              bookOrder: 1,
              seriesId: 1,
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: const {'book_1.json': []},
          rewards: [
            RewardModel(
              title: 'Reward',
              description: 'Description',
              assetImage: 'assets/images/rewards/r.webp',
              unlockBookId: unlockBookId,
            ),
          ],
          hadiths: const [],
        ));

    test('deleteBook returns false when a reward unlocks the book', () {
      final notifier = notifierWithReward(unlockBookId: 1);

      expect(
        notifier.deleteBook(1),
        isFalse,
        reason: 'deleting a book a reward still unlocks would leave a dangling '
            'unlock_book_id in rewards.json',
      );
    });

    test('state is unchanged when the deletion is blocked', () {
      final notifier = notifierWithReward(unlockBookId: 1);
      final before = notifier.state;

      notifier.deleteBook(1);

      expect(notifier.state, before);
    });

    test('deleteBook still succeeds when no reward unlocks the book', () {
      final notifier = notifierWithReward(unlockBookId: 99);

      expect(notifier.deleteBook(1), isTrue);
      expect(notifier.state.books, isEmpty);
    });
  });
}
