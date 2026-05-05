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

const _turkishChars =
    'abcçdefgğhıijklmnoöprsştuüvyzABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ';

extension IdValidationGenerators on Any {
  /// Generates a non-empty Turkish-flavored string.
  Generator<String> get turkishString => simple(
        generate: (random, size) {
          final length = random.nextInt(size.clamp(1, 20)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            buffer.write(_turkishChars[random.nextInt(_turkishChars.length)]);
          }
          return buffer.toString();
        },
        shrink: (input) sync* {
          if (input.length > 1) yield input.substring(0, input.length ~/ 2);
        },
      );

  /// Generates a positive integer ID (1+).
  Generator<int> get positiveId => simple(
        generate: (random, size) => random.nextInt(size.clamp(1, 1000)) + 1,
        shrink: (input) sync* {
          if (input > 1) yield input ~/ 2;
        },
      );

  /// Generates a non-positive integer (0 or negative).
  Generator<int> get nonPositiveId => simple(
        generate: (random, size) => -(random.nextInt(size.clamp(1, 100))),
        shrink: (input) sync* {
          if (input < 0) yield input ~/ 2;
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

  /// Generates a valid question for use in levels.
  Generator<QuestionModel> get validQuestion => combine2(
        turkishString,
        turkishString,
        (String text, String explanation) => QuestionModel(
          questionText: text,
          optionA: 'A answer',
          optionB: 'B answer',
          optionC: 'C answer',
          optionD: 'D answer',
          correctOption: 'A',
          type: 'multiple_choice',
          explanation: explanation,
        ),
      );
}

// ─── Helpers ────────────────────────────────────────────────────────

final _validator = ContentValidator();

List<ValidationIssue> _errors(ContentState state) => _validator
    .validateAll(state)
    .where((i) => i.severity == ValidationSeverity.error)
    .toList();

/// Checks if any error is related to ID positivity or uniqueness.
bool _hasIdError(List<ValidationIssue> issues) => issues.any((i) =>
    i.message.contains('positive integer') ||
    i.message.contains('Duplicate'));

/// Checks if any error is specifically about ID positivity.
bool _hasPositivityError(List<ValidationIssue> issues) =>
    issues.any((i) => i.message.contains('positive integer'));

/// Checks if any error is specifically about duplicate IDs.
bool _hasDuplicateError(List<ValidationIssue> issues) =>
    issues.any((i) => i.message.contains('Duplicate'));

/// Builds a fully valid ContentState with unique positive IDs and
/// sequential ordering so that only ID-related checks are relevant.
ContentState _buildValidState({
  required List<int> seriesIds,
  required List<int> bookIds,
  required List<int> levelIds,
}) {
  assert(seriesIds.isNotEmpty);
  assert(bookIds.isNotEmpty);
  assert(levelIds.isNotEmpty);

  final series = <SeriesModel>[];
  for (var i = 0; i < seriesIds.length; i++) {
    series.add(SeriesModel(
      id: seriesIds[i],
      name: 'Series ${seriesIds[i]}',
      sortOrder: i + 1,
      isLocked: false,
      iconEmoji: '📖',
    ));
  }

  final books = <BookModel>[];
  for (var i = 0; i < bookIds.length; i++) {
    books.add(BookModel(
      id: bookIds[i],
      title: 'Book ${bookIds[i]}',
      description: 'Description ${bookIds[i]}',
      assetImage: 'assets/images/book_${i + 1}.png',
      bookOrder: i + 1,
      seriesId: seriesIds[0],
      contentFile: 'book_${i + 1}.json',
    ));
  }

  final contentFiles = <String, List<LevelModel>>{};
  final questionsPerLevel = List.generate(
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
  );

  // Distribute levels across books
  for (var i = 0; i < levelIds.length; i++) {
    final bookIndex = i % bookIds.length;
    final contentFileName = 'book_${bookIndex + 1}.json';
    contentFiles.putIfAbsent(contentFileName, () => []);
    contentFiles[contentFileName]!.add(LevelModel(
      id: levelIds[i],
      bookId: bookIds[bookIndex],
      categoryName: 'Category',
      levelOrder: contentFiles[contentFileName]!.length + 1,
      title: 'Level ${levelIds[i]}',
      unlockScore: 0,
      assetImage: 'assets/images/level.webp',
      questions: questionsPerLevel,
    ));
  }

  // Ensure all book content files exist
  for (var i = 0; i < bookIds.length; i++) {
    final contentFileName = 'book_${i + 1}.json';
    contentFiles.putIfAbsent(
      contentFileName,
      () => [
        LevelModel(
          id: levelIds.last + i + 1000,
          bookId: bookIds[i],
          categoryName: 'Category',
          levelOrder: 1,
          title: 'Default Level',
          unlockScore: 0,
          assetImage: 'assets/images/level.webp',
          questions: questionsPerLevel,
        ),
      ],
    );
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
  group('Property 8: Validator Detects ID Uniqueness and Positivity Violations',
      () {
    // ── Sub-property 8a: Non-positive series IDs produce errors ──

    Glados(
      any.combine2(
        any.nonPositiveId,
        any.positiveId,
        (int badId, int goodBookId) => (badId: badId, bookId: goodBookId),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'non-positive series ID always produces an error',
      (input) {
        final state = ContentState(
          series: [
            SeriesModel(
              id: input.badId,
              name: 'Test Series',
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
              seriesId: input.badId,
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: 1,
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
          _hasPositivityError(issues),
          isTrue,
          reason:
              'Series ID ${input.badId} is non-positive and should produce an error',
        );
      },
    );

    // ── Sub-property 8b: Non-positive book IDs produce errors ──

    Glados(
      any.nonPositiveId,
      ExploreConfig(numRuns: 100),
    ).test(
      'non-positive book ID always produces an error',
      (badBookId) {
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
              id: badBookId,
              title: 'Book',
              description: 'Desc',
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: 1,
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: 1,
                bookId: badBookId,
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
          issues.any((i) =>
              i.message.contains('positive integer') &&
              i.sourceFile == 'books.json'),
          isTrue,
          reason:
              'Book ID $badBookId is non-positive and should produce an error',
        );
      },
    );

    // ── Sub-property 8c: Non-positive level IDs produce errors ──

    Glados(
      any.nonPositiveId,
      ExploreConfig(numRuns: 100),
    ).test(
      'non-positive level ID always produces an error',
      (badLevelId) {
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
              id: 1,
              title: 'Book',
              description: 'Desc',
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: 1,
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: badLevelId,
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

        final issues = _errors(state);
        expect(
          issues.any((i) =>
              i.message.contains('positive integer') &&
              i.sourceFile.contains('content/')),
          isTrue,
          reason:
              'Level ID $badLevelId is non-positive and should produce an error',
        );
      },
    );

    // ── Sub-property 8d: Duplicate series IDs produce errors ──

    Glados(
      any.positiveId,
      ExploreConfig(numRuns: 100),
    ).test(
      'duplicate series IDs always produce an error',
      (duplicateId) {
        final state = ContentState(
          series: [
            SeriesModel(
              id: duplicateId,
              name: 'Series A',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
            SeriesModel(
              id: duplicateId,
              name: 'Series B',
              sortOrder: 2,
              isLocked: false,
              iconEmoji: '🕌',
            ),
          ],
          books: [
            BookModel(
              id: 1,
              title: 'Book',
              description: 'Desc',
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: duplicateId,
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

        final issues = _errors(state);
        expect(
          issues.any((i) =>
              i.message.contains('Duplicate series ID') &&
              i.message.contains('$duplicateId')),
          isTrue,
          reason:
              'Duplicate series ID $duplicateId should produce an error',
        );
      },
    );

    // ── Sub-property 8e: Duplicate book IDs produce errors ──

    Glados(
      any.positiveId,
      ExploreConfig(numRuns: 100),
    ).test(
      'duplicate book IDs always produce an error',
      (duplicateId) {
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
              id: duplicateId,
              title: 'Book A',
              description: 'Desc A',
              assetImage: 'assets/images/a.png',
              bookOrder: 1,
              seriesId: 1,
              contentFile: 'book_1.json',
            ),
            BookModel(
              id: duplicateId,
              title: 'Book B',
              description: 'Desc B',
              assetImage: 'assets/images/b.png',
              bookOrder: 2,
              seriesId: 1,
              contentFile: 'book_2.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: 1,
                bookId: duplicateId,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level 1',
                unlockScore: 0,
                questions: [],
              ),
            ],
            'book_2.json': [
              LevelModel(
                id: 2,
                bookId: duplicateId,
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
          issues.any((i) =>
              i.message.contains('Duplicate book ID') &&
              i.message.contains('$duplicateId')),
          isTrue,
          reason:
              'Duplicate book ID $duplicateId should produce an error',
        );
      },
    );

    // ── Sub-property 8f: Duplicate level IDs across books produce errors ──

    Glados(
      any.positiveId,
      ExploreConfig(numRuns: 100),
    ).test(
      'duplicate level IDs across books always produce an error',
      (duplicateId) {
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
              id: 1,
              title: 'Book A',
              description: 'Desc A',
              assetImage: 'assets/images/a.png',
              bookOrder: 1,
              seriesId: 1,
              contentFile: 'book_1.json',
            ),
            BookModel(
              id: 2,
              title: 'Book B',
              description: 'Desc B',
              assetImage: 'assets/images/b.png',
              bookOrder: 2,
              seriesId: 1,
              contentFile: 'book_2.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: duplicateId,
                bookId: 1,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level in Book 1',
                unlockScore: 0,
                questions: [],
              ),
            ],
            'book_2.json': [
              LevelModel(
                id: duplicateId,
                bookId: 2,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level in Book 2',
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
          issues.any((i) =>
              i.message.contains('Duplicate level ID') &&
              i.message.contains('$duplicateId')),
          isTrue,
          reason:
              'Duplicate level ID $duplicateId across books should produce an error',
        );
      },
    );

    // ── Sub-property 8g: All unique positive IDs produce no ID-related errors ──

    Glados(
      any.combine3(
        any.uniquePositiveIds(3),
        any.uniquePositiveIds(3),
        any.uniquePositiveIds(5),
        (List<int> seriesIds, List<int> bookIds, List<int> levelIds) =>
            (seriesIds: seriesIds, bookIds: bookIds, levelIds: levelIds),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'all unique positive IDs produce no ID-related errors',
      (input) {
        final state = _buildValidState(
          seriesIds: input.seriesIds,
          bookIds: input.bookIds,
          levelIds: input.levelIds,
        );

        final issues = _errors(state);

        // Filter to only ID-related errors
        final idErrors = issues.where((i) =>
            i.message.contains('positive integer') ||
            i.message.contains('Duplicate'));

        expect(
          idErrors,
          isEmpty,
          reason:
              'State with unique positive IDs (series: ${input.seriesIds}, '
              'books: ${input.bookIds}, levels: ${input.levelIds}) '
              'should have no ID-related errors, but got: $idErrors',
        );
      },
    );

    // ── Sub-property 8h: Mixed violations — both duplicate and non-positive ──

    Glados(
      any.combine2(
        any.nonPositiveId,
        any.positiveId,
        (int nonPositive, int positive) =>
            (nonPositive: nonPositive, positive: positive),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'state with both duplicate and non-positive IDs reports both error types',
      (input) {
        final state = ContentState(
          series: [
            SeriesModel(
              id: input.nonPositive,
              name: 'Series A',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
            SeriesModel(
              id: input.nonPositive,
              name: 'Series B',
              sortOrder: 2,
              isLocked: false,
              iconEmoji: '🕌',
            ),
          ],
          books: [
            BookModel(
              id: input.positive,
              title: 'Book',
              description: 'Desc',
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: input.nonPositive,
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              LevelModel(
                id: 1,
                bookId: input.positive,
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

        // Should detect non-positive ID
        expect(
          _hasPositivityError(issues),
          isTrue,
          reason:
              'Non-positive series ID ${input.nonPositive} should be detected',
        );

        // Should detect duplicate ID
        expect(
          _hasDuplicateError(issues),
          isTrue,
          reason:
              'Duplicate series ID ${input.nonPositive} should be detected',
        );
      },
    );
  });
}
