import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';

// ─── Generators ─────────────────────────────────────────────────────

extension ForeignKeyGenerators on Any {
  /// Generates a positive integer ID (1+).
  Generator<int> get positiveId => simple(
        generate: (random, size) => random.nextInt(size.clamp(1, 1000)) + 1,
        shrink: (input) sync* {
          if (input > 1) yield input ~/ 2;
        },
      );

  /// Generates a positive integer guaranteed to NOT be in the given set.
  Generator<int> nonExistentId(Set<int> existingIds) => simple(
        generate: (random, size) {
          var id = random.nextInt(size.clamp(1, 10000)) + 1;
          // Ensure the generated ID is not in the existing set
          while (existingIds.contains(id)) {
            id++;
          }
          return id;
        },
        shrink: (input) sync* {
          if (input > 1) {
            final candidate = input ~/ 2;
            if (!existingIds.contains(candidate)) yield candidate;
          }
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
}

// ─── Helpers ────────────────────────────────────────────────────────

final _validator = ContentValidator();

List<ValidationIssue> _errors(ContentState state) => _validator
    .validateAll(state)
    .where((i) => i.severity == ValidationSeverity.error)
    .toList();

/// Checks if any error mentions a non-existent series reference.
bool _hasSeriesFKError(List<ValidationIssue> issues) => issues.any((i) =>
    i.message.contains('non-existent series ID') &&
    i.sourceFile == 'books.json');

/// Checks if any error mentions a non-existent book reference from levels.
bool _hasLevelBookFKError(List<ValidationIssue> issues) => issues.any((i) =>
    i.message.contains('non-existent book ID') &&
    i.sourceFile.contains('content/'));

/// Checks if any error mentions a non-existent book reference from rewards.
bool _hasRewardBookFKError(List<ValidationIssue> issues) => issues.any((i) =>
    i.message.contains('non-existent book ID') &&
    i.sourceFile == 'rewards.json');

/// Checks if any error mentions content file book_id inconsistency.
bool _hasContentFileBookIdError(List<ValidationIssue> issues) =>
    issues.any((i) => i.message.contains('inconsistent with the'));

/// Builds a fully valid ContentState with proper FK relationships.
ContentState _buildValidState({
  required int seriesId,
  required int bookId,
  required int levelId,
}) {
  return ContentState(
    series: [
      SeriesModel(
        id: seriesId,
        name: 'Series $seriesId',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      ),
    ],
    books: [
      BookModel(
        id: bookId,
        title: 'Book $bookId',
        description: 'Description',
        assetImage: 'assets/images/book.png',
        bookOrder: 1,
        seriesId: seriesId,
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: {
      'book_1.json': [
        LevelModel(
          id: levelId,
          bookId: bookId,
          categoryName: 'Category',
          levelOrder: 1,
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
        ),
      ],
    },
    rewards: [
      RewardModel(
        title: 'Reward',
        description: 'Reward desc',
        assetImage: 'assets/images/reward.png',
        unlockBookId: bookId,
      ),
    ],
    hadiths: [
      HadithModel(text: 'Hadith text', source: 'Source'),
    ],
  );
}

// ─── Property Tests ─────────────────────────────────────────────────

void main() {
  group(
      'Property 9: Validator Detects Foreign Key Reference Violations', () {
    // ── Sub-property 9a: Book with non-existent series_id produces error ──

    Glados(
      any.combine2(
        any.positiveId,
        any.positiveId,
        (int bookId, int levelId) => (bookId: bookId, levelId: levelId),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'book referencing non-existent series_id always produces an error',
      (input) {
        // Create a state where the book's seriesId doesn't match any series
        const existingSeriesId = 1;
        // Use a broken series reference that is guaranteed different
        final brokenSeriesId = existingSeriesId + 1000;

        final state = ContentState(
          series: [
            SeriesModel(
              id: existingSeriesId,
              name: 'Existing Series',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            BookModel(
              id: input.bookId,
              title: 'Book',
              description: 'Desc',
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: brokenSeriesId, // FK violation
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: input.levelId,
                bookId: input.bookId,
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

        final issues = _errors(state);
        expect(
          _hasSeriesFKError(issues),
          isTrue,
          reason:
              'Book with series_id $brokenSeriesId referencing non-existent '
              'series should produce an error',
        );
      },
    );

    // ── Sub-property 9b: Level with non-existent book_id produces error ──

    Glados(
      any.combine2(
        any.positiveId,
        any.positiveId,
        (int seriesId, int bookId) => (seriesId: seriesId, bookId: bookId),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'level referencing non-existent book_id always produces an error',
      (input) {
        final existingBookId = input.bookId;
        final brokenBookId = existingBookId + 1000;

        final state = ContentState(
          series: [
            SeriesModel(
              id: input.seriesId,
              name: 'Series',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            BookModel(
              id: existingBookId,
              title: 'Book',
              description: 'Desc',
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: input.seriesId,
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: 1,
                bookId: brokenBookId, // FK violation
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

        final issues = _errors(state);
        expect(
          _hasLevelBookFKError(issues),
          isTrue,
          reason:
              'Level with book_id $brokenBookId referencing non-existent '
              'book should produce an error',
        );
      },
    );

    // ── Sub-property 9c: Reward with non-existent unlock_book_id produces error ──

    Glados(
      any.combine2(
        any.positiveId,
        any.positiveId,
        (int seriesId, int bookId) => (seriesId: seriesId, bookId: bookId),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'reward referencing non-existent unlock_book_id always produces an error',
      (input) {
        final existingBookId = input.bookId;
        final brokenBookId = existingBookId + 1000;

        final state = ContentState(
          series: [
            SeriesModel(
              id: input.seriesId,
              name: 'Series',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            BookModel(
              id: existingBookId,
              title: 'Book',
              description: 'Desc',
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: input.seriesId,
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: 1,
                bookId: existingBookId,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level',
                unlockScore: 0,
                questions: [],
              ),
            ],
          },
          rewards: [
            RewardModel(
              title: 'Reward',
              description: 'Reward desc',
              assetImage: 'assets/images/reward.png',
              unlockBookId: brokenBookId, // FK violation
            ),
          ],
          hadiths: [],
        );

        final issues = _errors(state);
        expect(
          _hasRewardBookFKError(issues),
          isTrue,
          reason:
              'Reward with unlock_book_id $brokenBookId referencing '
              'non-existent book should produce an error',
        );
      },
    );

    // ── Sub-property 9d: Content file book_id inconsistency produces error ──

    Glados(
      any.combine3(
        any.positiveId,
        any.positiveId,
        any.positiveId,
        (int seriesId, int bookId, int levelId) =>
            (seriesId: seriesId, bookId: bookId, levelId: levelId),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'content file with inconsistent book_id always produces an error',
      (input) {
        final correctBookId = input.bookId;
        final inconsistentBookId = correctBookId + 1000;

        final state = ContentState(
          series: [
            SeriesModel(
              id: input.seriesId,
              name: 'Series',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            BookModel(
              id: correctBookId,
              title: 'Book',
              description: 'Desc',
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: input.seriesId,
              contentFile: 'book_1.json',
            ),
            // Add a second book so the inconsistent ID is a valid book
            // but still wrong for this content file
            BookModel(
              id: inconsistentBookId,
              title: 'Other Book',
              description: 'Desc',
              assetImage: 'assets/images/b2.png',
              bookOrder: 2,
              seriesId: input.seriesId,
              contentFile: 'book_2.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: input.levelId,
                bookId: inconsistentBookId, // Inconsistent: should be correctBookId
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level',
                unlockScore: 0,
                questions: [],
              ),
            ],
            'book_2.json': [
              LevelModel(
                id: input.levelId + 1000,
                bookId: inconsistentBookId,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level 2',
                unlockScore: 0,
                questions: [],
              ),
            ],
          },
          rewards: [],
          hadiths: [],
        );

        final issues = _errors(state);
        expect(
          _hasContentFileBookIdError(issues),
          isTrue,
          reason:
              'Level in book_1.json with book_id $inconsistentBookId '
              '(expected $correctBookId) should produce a consistency error',
        );
      },
    );

    // ── Sub-property 9e: Valid FK references produce no FK-related errors ──

    Glados(
      any.combine3(
        any.positiveId,
        any.positiveId,
        any.positiveId,
        (int seriesId, int bookId, int levelId) =>
            (seriesId: seriesId, bookId: bookId, levelId: levelId),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'valid FK references produce no FK-related errors',
      (input) {
        final state = _buildValidState(
          seriesId: input.seriesId,
          bookId: input.bookId,
          levelId: input.levelId,
        );

        final issues = _errors(state);

        // Filter to only FK-related errors
        final fkErrors = issues.where((i) =>
            i.message.contains('non-existent series ID') ||
            i.message.contains('non-existent book ID') ||
            i.message.contains('inconsistent with the'));

        expect(
          fkErrors,
          isEmpty,
          reason:
              'State with valid FK references (series: ${input.seriesId}, '
              'book: ${input.bookId}, level: ${input.levelId}) '
              'should have no FK-related errors, but got: $fkErrors',
        );
      },
    );

    // ── Sub-property 9f: Multiple FK violations are all detected ──

    Glados(
      any.positiveId,
      ExploreConfig(numRuns: 100),
    ).test(
      'state with multiple FK violations reports all of them',
      (baseId) {
        final existingSeriesId = baseId;
        final existingBookId = baseId + 100;
        final brokenSeriesId = baseId + 2000;
        final brokenBookId = baseId + 3000;

        final state = ContentState(
          series: [
            SeriesModel(
              id: existingSeriesId,
              name: 'Series',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            // Book with broken series FK
            BookModel(
              id: existingBookId,
              title: 'Book',
              description: 'Desc',
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: brokenSeriesId, // FK violation: series doesn't exist
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              // Level with broken book FK
              LevelModel(
                id: 1,
                bookId: brokenBookId, // FK violation: book doesn't exist
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level',
                unlockScore: 0,
                questions: [],
              ),
            ],
          },
          rewards: [
            // Reward with broken book FK
            RewardModel(
              title: 'Reward',
              description: 'Reward desc',
              assetImage: 'assets/images/reward.png',
              unlockBookId: brokenBookId, // FK violation: book doesn't exist
            ),
          ],
          hadiths: [],
        );

        final issues = _errors(state);

        // Should detect broken series FK
        expect(
          _hasSeriesFKError(issues),
          isTrue,
          reason:
              'Book with broken series_id $brokenSeriesId should be detected',
        );

        // Should detect broken level→book FK
        expect(
          _hasLevelBookFKError(issues),
          isTrue,
          reason:
              'Level with broken book_id $brokenBookId should be detected',
        );

        // Should detect broken reward→book FK
        expect(
          _hasRewardBookFKError(issues),
          isTrue,
          reason:
              'Reward with broken unlock_book_id $brokenBookId should be detected',
        );
      },
    );

    // ── Sub-property 9g: Randomly broken series_id always detected ──

    Glados(
      any.uniquePositiveIds(3),
      ExploreConfig(numRuns: 100),
    ).test(
      'randomly generated non-existent series_id is always detected',
      (seriesIds) {
        // Use first ID as the existing series, generate a non-existent one
        final existingSeriesId = seriesIds[0];
        final existingBookId = seriesIds[1];
        final existingLevelId = seriesIds[2];
        // Guaranteed non-existent
        final nonExistentSeriesId = existingSeriesId + existingBookId + existingLevelId + 9999;

        final state = ContentState(
          series: [
            SeriesModel(
              id: existingSeriesId,
              name: 'Series',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            BookModel(
              id: existingBookId,
              title: 'Book',
              description: 'Desc',
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: nonExistentSeriesId, // Broken FK
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: existingLevelId,
                bookId: existingBookId,
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

        final issues = _errors(state);
        expect(
          _hasSeriesFKError(issues),
          isTrue,
          reason:
              'Book referencing non-existent series_id $nonExistentSeriesId '
              '(existing: $existingSeriesId) should produce an error',
        );
      },
    );

    // ── Sub-property 9h: Content file book_id consistency with multiple levels ──

    Glados(
      any.combine2(
        any.positiveId,
        any.simple(
          generate: (random, size) => random.nextInt(3) + 2,
          shrink: (input) sync* {
            if (input > 2) yield input - 1;
          },
        ),
        (int baseId, int levelCount) =>
            (baseId: baseId, levelCount: levelCount),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'content file with multiple levels having inconsistent book_ids detected',
      (input) {
        final correctBookId = input.baseId;
        final wrongBookId = input.baseId + 5000;

        // Create levels where at least one has the wrong book_id
        final levels = <LevelModel>[];
        for (var i = 0; i < input.levelCount; i++) {
          levels.add(LevelModel(
            id: input.baseId + i + 100,
            // Last level has wrong book_id
            bookId: i == input.levelCount - 1 ? wrongBookId : correctBookId,
            categoryName: 'Cat',
            levelOrder: i + 1,
            title: 'Level ${i + 1}',
            unlockScore: 0,
            questions: [],
          ));
        }

        final state = ContentState(
          series: [
            SeriesModel(
              id: 1,
              name: 'Series',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            BookModel(
              id: correctBookId,
              title: 'Book',
              description: 'Desc',
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: 1,
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: {
            'book_1.json': levels,
          },
          rewards: [],
          hadiths: [],
        );

        final issues = _errors(state);
        expect(
          _hasContentFileBookIdError(issues),
          isTrue,
          reason:
              'Content file with level having book_id $wrongBookId '
              '(expected $correctBookId) should produce a consistency error',
        );
      },
    );
  });
}
