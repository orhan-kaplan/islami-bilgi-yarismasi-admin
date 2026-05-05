import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';

// ─── Generators ─────────────────────────────────────────────────────

extension SequentialOrderingGenerators on Any {
  /// Generates a positive integer ID (1+).
  Generator<int> get positiveId => simple(
        generate: (random, size) => random.nextInt(size.clamp(1, 1000)) + 1,
        shrink: (input) sync* {
          if (input > 1) yield input ~/ 2;
        },
      );

  /// Generates a list of N unique positive IDs.
  Generator<List<int>> uniquePositiveIds(int count) => simple(
        generate: (random, size) {
          final ids = <int>{};
          while (ids.length < count) {
            ids.add(random.nextInt(size.clamp(count, 10000)) + 1);
          }
          return ids.toList();
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a non-sequential list of positive integers of given length.
  /// Guarantees the values are NOT sequential starting from 1.
  Generator<List<int>> nonSequentialOrders(int count) => simple(
        generate: (random, size) {
          if (count <= 0) return <int>[];
          // Generate random positive integers that are NOT 1..count sequential
          List<int> orders;
          do {
            orders = List.generate(
              count,
              (_) => random.nextInt(size.clamp(count, 100)) + 1,
            );
            // Sort to check if they happen to be sequential
            final sorted = [...orders]..sort();
            final isSequential = List.generate(count, (i) => i + 1)
                .every((v) => sorted.contains(v) && sorted.indexOf(v) == v - 1);
            if (!isSequential) break;
          } while (true);
          return orders;
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a count between 2 and maxCount (need at least 2 to be non-sequential).
  Generator<int> entityCount({int min = 2, int max = 6}) => simple(
        generate: (random, size) => random.nextInt(max - min + 1) + min,
        shrink: (input) sync* {
          if (input > min) yield input - 1;
        },
      );
}

// ─── Helpers ────────────────────────────────────────────────────────

final _validator = ContentValidator();

List<ValidationIssue> _errors(ContentState state) => _validator
    .validateAll(state)
    .where((i) => i.severity == ValidationSeverity.error)
    .toList();

/// Checks if any error is related to sequential ordering.
bool _hasOrderingError(List<ValidationIssue> issues) => issues.any((i) =>
    i.message.contains('not sequential starting from 1'));

/// Checks if any error is specifically about series sort_order.
bool _hasSeriesSortOrderError(List<ValidationIssue> issues) => issues.any((i) =>
    i.message.contains('sort_order') &&
    i.message.contains('not sequential'));

/// Checks if any error is specifically about book_order.
bool _hasBookOrderError(List<ValidationIssue> issues) => issues.any((i) =>
    i.message.contains('book_order') &&
    i.message.contains('not sequential'));

/// Checks if any error is specifically about level_order.
bool _hasLevelOrderError(List<ValidationIssue> issues) => issues.any((i) =>
    i.message.contains('level_order') &&
    i.message.contains('not sequential'));

/// Builds a valid ContentState with sequential ordering.
ContentState _buildSequentialState({
  required int seriesCount,
  required int booksPerSeries,
  required int levelsPerBook,
}) {
  final series = <SeriesModel>[];
  for (var i = 0; i < seriesCount; i++) {
    series.add(SeriesModel(
      id: i + 1,
      name: 'Series ${i + 1}',
      sortOrder: i + 1,
      isLocked: false,
      iconEmoji: '📖',
    ));
  }

  final books = <BookModel>[];
  var bookId = 1;
  for (var si = 0; si < seriesCount; si++) {
    for (var bi = 0; bi < booksPerSeries; bi++) {
      books.add(BookModel(
        id: bookId,
        title: 'Book $bookId',
        description: 'Description $bookId',
        assetImage: 'assets/images/book_$bookId.png',
        bookOrder: bi + 1,
        seriesId: si + 1,
        contentFile: 'book_$bookId.json',
      ));
      bookId++;
    }
  }

  final contentFiles = <String, List<LevelModel>>{};
  var levelId = 1;
  for (final book in books) {
    final levels = <LevelModel>[];
    for (var li = 0; li < levelsPerBook; li++) {
      levels.add(LevelModel(
        id: levelId,
        bookId: book.id,
        categoryName: 'Category',
        levelOrder: li + 1,
        title: 'Level $levelId',
        unlockScore: 0,
        assetImage: 'assets/images/level.webp',
        questions: List.generate(
          10,
          (qi) => QuestionModel(
            questionText: 'Question ${qi + 1}?',
            optionA: 'A',
            optionB: 'B',
            optionC: 'C',
            optionD: 'D',
            correctOption: ['A', 'B', 'C', 'D'][qi % 4],
            type: 'multiple_choice',
            explanation: 'Explanation',
          ),
        ),
      ));
      levelId++;
    }
    contentFiles[book.contentFile] = levels;
  }

  return ContentState(
    series: series,
    books: books,
    contentFiles: contentFiles,
    rewards: [],
    hadiths: [],
  );
}

// ─── Property Tests ─────────────────────────────────────────────────

void main() {
  group(
      'Property 10: Validator Detects Sequential Ordering Violations', () {
    // ── Sub-property 10a: Non-sequential series sort_order produces error ──

    Glados(
      any.entityCount(min: 2, max: 6),
      ExploreConfig(numRuns: 100),
    ).test(
      'non-sequential series sort_order always produces an error',
      (seriesCount) {
        // Create series with non-sequential sort_order values
        final series = <SeriesModel>[];
        // Use values that skip (e.g., 1, 3, 5...) to guarantee non-sequential
        for (var i = 0; i < seriesCount; i++) {
          series.add(SeriesModel(
            id: i + 1,
            name: 'Series ${i + 1}',
            sortOrder: (i + 1) * 2, // 2, 4, 6... instead of 1, 2, 3...
            isLocked: false,
            iconEmoji: '📖',
          ));
        }

        // Build a valid state around the bad series ordering
        final books = [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: 'assets/images/b.png',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ];

        final state = ContentState(
          series: series,
          books: books,
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: 1,
                bookId: 1,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level',
                unlockScore: 0,
                questions: List.generate(
                  10,
                  (qi) => QuestionModel(
                    questionText: 'Q${qi + 1}?',
                    optionA: 'A',
                    optionB: 'B',
                    optionC: 'C',
                    optionD: 'D',
                    correctOption: ['A', 'B', 'C', 'D'][qi % 4],
                    type: 'multiple_choice',
                    explanation: 'Exp',
                  ),
                ),
              ),
            ],
          },
          rewards: [],
          hadiths: [],
        );

        final issues = _errors(state);
        expect(
          _hasSeriesSortOrderError(issues),
          isTrue,
          reason:
              'Series with sort_order values ${series.map((s) => s.sortOrder).toList()} '
              'are not sequential starting from 1 and should produce an error',
        );
      },
    );

    // ── Sub-property 10b: Non-sequential book_order within a series produces error ──

    Glados(
      any.entityCount(min: 2, max: 5),
      ExploreConfig(numRuns: 100),
    ).test(
      'non-sequential book_order within a series always produces an error',
      (bookCount) {
        final series = [
          SeriesModel(
            id: 1,
            name: 'Series 1',
            sortOrder: 1,
            isLocked: false,
            iconEmoji: '📖',
          ),
        ];

        // Create books with non-sequential book_order (skip values)
        final books = <BookModel>[];
        final contentFiles = <String, List<LevelModel>>{};
        for (var i = 0; i < bookCount; i++) {
          final bookId = i + 1;
          books.add(BookModel(
            id: bookId,
            title: 'Book $bookId',
            description: 'Desc $bookId',
            assetImage: 'assets/images/b$bookId.png',
            bookOrder: (i + 1) * 3, // 3, 6, 9... instead of 1, 2, 3...
            seriesId: 1,
            contentFile: 'book_$bookId.json',
          ));
          contentFiles['book_$bookId.json'] = [
            LevelModel(
              id: bookId * 100,
              bookId: bookId,
              categoryName: 'Cat',
              levelOrder: 1,
              title: 'Level in Book $bookId',
              unlockScore: 0,
              questions: List.generate(
                10,
                (qi) => QuestionModel(
                  questionText: 'Q${qi + 1}?',
                  optionA: 'A',
                  optionB: 'B',
                  optionC: 'C',
                  optionD: 'D',
                  correctOption: ['A', 'B', 'C', 'D'][qi % 4],
                  type: 'multiple_choice',
                  explanation: 'Exp',
                ),
              ),
            ),
          ];
        }

        final state = ContentState(
          series: series,
          books: books,
          contentFiles: contentFiles,
          rewards: [],
          hadiths: [],
        );

        final issues = _errors(state);
        expect(
          _hasBookOrderError(issues),
          isTrue,
          reason:
              'Books with book_order values ${books.map((b) => b.bookOrder).toList()} '
              'in series 1 are not sequential starting from 1 and should produce an error',
        );
      },
    );

    // ── Sub-property 10c: Non-sequential level_order within a book produces error ──

    Glados(
      any.entityCount(min: 2, max: 5),
      ExploreConfig(numRuns: 100),
    ).test(
      'non-sequential level_order within a book always produces an error',
      (levelCount) {
        final series = [
          SeriesModel(
            id: 1,
            name: 'Series 1',
            sortOrder: 1,
            isLocked: false,
            iconEmoji: '📖',
          ),
        ];

        final books = [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: 'assets/images/b.png',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ];

        // Create levels with non-sequential level_order (skip values)
        final levels = <LevelModel>[];
        for (var i = 0; i < levelCount; i++) {
          levels.add(LevelModel(
            id: i + 1,
            bookId: 1,
            categoryName: 'Cat',
            levelOrder: (i + 1) * 2, // 2, 4, 6... instead of 1, 2, 3...
            title: 'Level ${i + 1}',
            unlockScore: 0,
            questions: List.generate(
              10,
              (qi) => QuestionModel(
                questionText: 'Q${qi + 1}?',
                optionA: 'A',
                optionB: 'B',
                optionC: 'C',
                optionD: 'D',
                correctOption: ['A', 'B', 'C', 'D'][qi % 4],
                type: 'multiple_choice',
                explanation: 'Exp',
              ),
            ),
          ));
        }

        final state = ContentState(
          series: series,
          books: books,
          contentFiles: {'book_1.json': levels},
          rewards: [],
          hadiths: [],
        );

        final issues = _errors(state);
        expect(
          _hasLevelOrderError(issues),
          isTrue,
          reason:
              'Levels with level_order values ${levels.map((l) => l.levelOrder).toList()} '
              'are not sequential starting from 1 and should produce an error',
        );
      },
    );

    // ── Sub-property 10d: Gaps in series sort_order produce error ──

    Glados(
      any.entityCount(min: 3, max: 6),
      ExploreConfig(numRuns: 100),
    ).test(
      'series sort_order with gaps (e.g., 1, 2, 4) produces an error',
      (seriesCount) {
        // Create sequential then introduce a gap by skipping one value
        final series = <SeriesModel>[];
        for (var i = 0; i < seriesCount; i++) {
          // Skip value at position seriesCount-1 (last item gets +1 extra)
          final order = i < seriesCount - 1 ? i + 1 : i + 2;
          series.add(SeriesModel(
            id: i + 1,
            name: 'Series ${i + 1}',
            sortOrder: order,
            isLocked: false,
            iconEmoji: '📖',
          ));
        }

        final books = [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: 'assets/images/b.png',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ];

        final state = ContentState(
          series: series,
          books: books,
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: 1,
                bookId: 1,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level',
                unlockScore: 0,
                questions: List.generate(
                  10,
                  (qi) => QuestionModel(
                    questionText: 'Q${qi + 1}?',
                    optionA: 'A',
                    optionB: 'B',
                    optionC: 'C',
                    optionD: 'D',
                    correctOption: ['A', 'B', 'C', 'D'][qi % 4],
                    type: 'multiple_choice',
                    explanation: 'Exp',
                  ),
                ),
              ),
            ],
          },
          rewards: [],
          hadiths: [],
        );

        final issues = _errors(state);
        expect(
          _hasSeriesSortOrderError(issues),
          isTrue,
          reason:
              'Series with sort_order values ${series.map((s) => s.sortOrder).toList()} '
              'have a gap and should produce an error',
        );
      },
    );

    // ── Sub-property 10e: Duplicate order values produce error ──

    Glados(
      any.entityCount(min: 2, max: 5),
      ExploreConfig(numRuns: 100),
    ).test(
      'duplicate sort_order values in series produce an error',
      (seriesCount) {
        // Create series where two items share the same sort_order
        final series = <SeriesModel>[];
        for (var i = 0; i < seriesCount; i++) {
          series.add(SeriesModel(
            id: i + 1,
            name: 'Series ${i + 1}',
            // First two share sort_order 1, rest are sequential from there
            sortOrder: i == 0 ? 1 : i,
            isLocked: false,
            iconEmoji: '📖',
          ));
        }

        final books = [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: 'assets/images/b.png',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ];

        final state = ContentState(
          series: series,
          books: books,
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: 1,
                bookId: 1,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level',
                unlockScore: 0,
                questions: List.generate(
                  10,
                  (qi) => QuestionModel(
                    questionText: 'Q${qi + 1}?',
                    optionA: 'A',
                    optionB: 'B',
                    optionC: 'C',
                    optionD: 'D',
                    correctOption: ['A', 'B', 'C', 'D'][qi % 4],
                    type: 'multiple_choice',
                    explanation: 'Exp',
                  ),
                ),
              ),
            ],
          },
          rewards: [],
          hadiths: [],
        );

        final issues = _errors(state);
        expect(
          _hasSeriesSortOrderError(issues),
          isTrue,
          reason:
              'Series with duplicate sort_order values '
              '${series.map((s) => s.sortOrder).toList()} should produce an error',
        );
      },
    );

    // ── Sub-property 10f: sort_order not starting from 1 produces error ──

    Glados(
      any.entityCount(min: 1, max: 5),
      ExploreConfig(numRuns: 100),
    ).test(
      'series sort_order starting from value > 1 produces an error',
      (seriesCount) {
        // Start from 2 instead of 1
        final series = <SeriesModel>[];
        for (var i = 0; i < seriesCount; i++) {
          series.add(SeriesModel(
            id: i + 1,
            name: 'Series ${i + 1}',
            sortOrder: i + 2, // Starts from 2 instead of 1
            isLocked: false,
            iconEmoji: '📖',
          ));
        }

        final books = [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: 'assets/images/b.png',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ];

        final state = ContentState(
          series: series,
          books: books,
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: 1,
                bookId: 1,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level',
                unlockScore: 0,
                questions: List.generate(
                  10,
                  (qi) => QuestionModel(
                    questionText: 'Q${qi + 1}?',
                    optionA: 'A',
                    optionB: 'B',
                    optionC: 'C',
                    optionD: 'D',
                    correctOption: ['A', 'B', 'C', 'D'][qi % 4],
                    type: 'multiple_choice',
                    explanation: 'Exp',
                  ),
                ),
              ),
            ],
          },
          rewards: [],
          hadiths: [],
        );

        final issues = _errors(state);
        expect(
          _hasSeriesSortOrderError(issues),
          isTrue,
          reason:
              'Series with sort_order starting from 2 '
              '${series.map((s) => s.sortOrder).toList()} should produce an error',
        );
      },
    );

    // ── Sub-property 10g: Multiple series in different books with non-sequential book_order ──

    Glados(
      any.combine2(
        any.entityCount(min: 2, max: 4),
        any.entityCount(min: 2, max: 4),
        (int seriesCount, int booksPerSeries) =>
            (seriesCount: seriesCount, booksPerSeries: booksPerSeries),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'non-sequential book_order in any series produces an error',
      (input) {
        final series = <SeriesModel>[];
        for (var i = 0; i < input.seriesCount; i++) {
          series.add(SeriesModel(
            id: i + 1,
            name: 'Series ${i + 1}',
            sortOrder: i + 1,
            isLocked: false,
            iconEmoji: '📖',
          ));
        }

        final books = <BookModel>[];
        final contentFiles = <String, List<LevelModel>>{};
        var bookId = 1;
        for (var si = 0; si < input.seriesCount; si++) {
          for (var bi = 0; bi < input.booksPerSeries; bi++) {
            // Make book_order non-sequential for the first series only
            final order = si == 0 ? (bi + 1) * 2 : bi + 1;
            books.add(BookModel(
              id: bookId,
              title: 'Book $bookId',
              description: 'Desc $bookId',
              assetImage: 'assets/images/b$bookId.png',
              bookOrder: order,
              seriesId: si + 1,
              contentFile: 'book_$bookId.json',
            ));
            contentFiles['book_$bookId.json'] = [
              LevelModel(
                id: bookId * 100,
                bookId: bookId,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level in Book $bookId',
                unlockScore: 0,
                questions: List.generate(
                  10,
                  (qi) => QuestionModel(
                    questionText: 'Q${qi + 1}?',
                    optionA: 'A',
                    optionB: 'B',
                    optionC: 'C',
                    optionD: 'D',
                    correctOption: ['A', 'B', 'C', 'D'][qi % 4],
                    type: 'multiple_choice',
                    explanation: 'Exp',
                  ),
                ),
              ),
            ];
            bookId++;
          }
        }

        final state = ContentState(
          series: series,
          books: books,
          contentFiles: contentFiles,
          rewards: [],
          hadiths: [],
        );

        final issues = _errors(state);
        expect(
          _hasBookOrderError(issues),
          isTrue,
          reason:
              'Books in series 1 with book_order values '
              '${books.where((b) => b.seriesId == 1).map((b) => b.bookOrder).toList()} '
              'are not sequential and should produce an error',
        );
      },
    );

    // ── Sub-property 10h: Sequential ordering produces no ordering errors ──

    Glados(
      any.combine3(
        any.entityCount(min: 1, max: 4),
        any.entityCount(min: 1, max: 3),
        any.entityCount(min: 1, max: 4),
        (int seriesCount, int booksPerSeries, int levelsPerBook) => (
          seriesCount: seriesCount,
          booksPerSeries: booksPerSeries,
          levelsPerBook: levelsPerBook,
        ),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'sequential ordering produces no ordering-related errors',
      (input) {
        final state = _buildSequentialState(
          seriesCount: input.seriesCount,
          booksPerSeries: input.booksPerSeries,
          levelsPerBook: input.levelsPerBook,
        );

        final issues = _errors(state);

        // Filter to only ordering-related errors
        final orderingErrors = issues.where(
            (i) => i.message.contains('not sequential starting from 1'));

        expect(
          orderingErrors,
          isEmpty,
          reason:
              'State with sequential ordering (${input.seriesCount} series, '
              '${input.booksPerSeries} books/series, ${input.levelsPerBook} levels/book) '
              'should have no ordering errors, but got: $orderingErrors',
        );
      },
    );
  });
}
