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

extension RequiredFieldGenerators on Any {
  /// Generates a non-empty Turkish-flavored string.
  Generator<String> get nonEmptyString => simple(
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

  /// Generates a boolean.
  Generator<bool> get boolean => simple(
        generate: (random, size) => random.nextBool(),
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a random index from 0 to max-1.
  Generator<int> indexUpTo(int max) => simple(
        generate: (random, size) => random.nextInt(max),
        shrink: (input) sync* {
          if (input > 0) yield input - 1;
        },
      );

  /// Generates a random subset of indices from a list of field names.
  /// At least one field will be emptied.
  Generator<List<int>> nonEmptySubset(int fieldCount) => simple(
        generate: (random, size) {
          final count = random.nextInt(fieldCount) + 1;
          final indices = <int>{};
          while (indices.length < count) {
            indices.add(random.nextInt(fieldCount));
          }
          return indices.toList()..sort();
        },
        shrink: (input) sync* {
          if (input.length > 1) yield [input.first];
        },
      );
}

// ─── Helpers ────────────────────────────────────────────────────────

final _validator = ContentValidator();

List<ValidationIssue> _errors(ContentState state) => _validator
    .validateAll(state)
    .where((i) => i.severity == ValidationSeverity.error)
    .toList();

/// Filters issues to only those related to required field violations.
List<ValidationIssue> _requiredFieldErrors(ContentState state) => _errors(state)
    .where((i) => i.message.contains('required and must not be empty'))
    .toList();

/// Builds a minimal valid ContentState with no required field violations.
ContentState _buildValidState() {
  return ContentState(
    series: [
      const SeriesModel(
        id: 1,
        name: 'Test Series',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      ),
    ],
    books: [
      const BookModel(
        id: 1,
        title: 'Test Book',
        description: 'A test book description',
        assetImage: 'assets/images/book_1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
    ],
    contentFiles: {
      'book_1.json': [
        const LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'Test Category',
          levelOrder: 1,
          title: 'Test Level',
          unlockScore: 0,
          assetImage: 'assets/images/level.webp',
          questions: [
            QuestionModel(
              questionText: 'What is this?',
              optionA: 'Answer A',
              optionB: 'Answer B',
              optionC: 'Answer C',
              optionD: 'Answer D',
              correctOption: 'A',
              type: 'multiple_choice',
              explanation: 'Because A',
            ),
          ],
        ),
      ],
    },
    rewards: [
      const RewardModel(
        title: 'Test Reward',
        description: 'A reward description',
        assetImage: 'assets/images/reward.png',
        unlockBookId: 1,
      ),
    ],
    hadiths: [
      const HadithModel(
        text: 'A hadith text',
        source: 'Bukhari',
      ),
    ],
  );
}

// ─── Required field names per entity ────────────────────────────────

// Series required field: name (index 0)
const _seriesRequiredFields = ['name'];

// Book required fields: title (0), description (1), content_file (2)
const _bookRequiredFields = ['title', 'description', 'content_file'];

// Level required fields: title (0), category_name (1)
const _levelRequiredFields = ['title', 'category_name'];

// Question required fields: question_text (0), option_a (1), option_b (2), correct_option (3)
const _questionRequiredFields = [
  'question_text',
  'option_a',
  'option_b',
  'correct_option',
];

// Reward required fields: title (0), description (1), asset_image (2)
const _rewardRequiredFields = ['title', 'description', 'asset_image'];

// Hadith required fields: text (0), source (1)
const _hadithRequiredFields = ['text', 'source'];

// ─── Property Tests ─────────────────────────────────────────────────

void main() {
  group('Property 12: Validator Detects Required Field Violations', () {
    // ── Sub-property 12a: Empty series name produces error ──

    Glados(
      any.nonEmptySubset(_seriesRequiredFields.length),
      ExploreConfig(numRuns: 100),
    ).test(
      'empty series required fields always produce errors',
      (emptyFieldIndices) {
        // Build a series with selected fields emptied
        String name = 'Valid Series';
        if (emptyFieldIndices.contains(0)) name = '';

        final state = ContentState(
          series: [
            SeriesModel(
              id: 1,
              name: name,
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            const BookModel(
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
              const LevelModel(
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

        final issues = _requiredFieldErrors(state);

        // Each emptied field should produce an error
        for (final idx in emptyFieldIndices) {
          final fieldName = _seriesRequiredFields[idx];
          expect(
            issues.any((i) =>
                i.sourceFile == 'series.json' &&
                i.message.contains('Series $fieldName')),
            isTrue,
            reason:
                'Empty series field "$fieldName" should produce a required field error',
          );
        }
      },
    );

    // ── Sub-property 12b: Empty book required fields produce errors ──

    Glados(
      any.nonEmptySubset(_bookRequiredFields.length),
      ExploreConfig(numRuns: 100),
    ).test(
      'empty book required fields always produce errors',
      (emptyFieldIndices) {
        String title = 'Valid Book';
        String description = 'Valid Description';
        String contentFile = 'book_1.json';

        if (emptyFieldIndices.contains(0)) title = '';
        if (emptyFieldIndices.contains(1)) description = '';
        if (emptyFieldIndices.contains(2)) contentFile = '';

        final state = ContentState(
          series: [
            const SeriesModel(
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
              title: title,
              description: description,
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: 1,
              contentFile: contentFile,
            ),
          ],
          contentFiles: {
            // Use the contentFile value as key so content file existence check passes
            // (unless contentFile is empty, in which case we still need a valid entry)
            if (contentFile.isNotEmpty) contentFile: [
              const LevelModel(
                id: 1,
                bookId: 1,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level',
                unlockScore: 0,
                questions: [],
              ),
            ],
            if (contentFile.isEmpty) 'book_1.json': [
              const LevelModel(
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

        final issues = _requiredFieldErrors(state);

        for (final idx in emptyFieldIndices) {
          final fieldName = _bookRequiredFields[idx];
          expect(
            issues.any((i) =>
                i.sourceFile == 'books.json' &&
                i.message.contains('Book $fieldName')),
            isTrue,
            reason:
                'Empty book field "$fieldName" should produce a required field error',
          );
        }
      },
    );

    // ── Sub-property 12c: Empty level required fields produce errors ──

    Glados(
      any.nonEmptySubset(_levelRequiredFields.length),
      ExploreConfig(numRuns: 100),
    ).test(
      'empty level required fields always produce errors',
      (emptyFieldIndices) {
        String title = 'Valid Level';
        String categoryName = 'Valid Category';

        if (emptyFieldIndices.contains(0)) title = '';
        if (emptyFieldIndices.contains(1)) categoryName = '';

        final state = ContentState(
          series: [
            const SeriesModel(
              id: 1,
              name: 'Series',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            const BookModel(
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
                id: 1,
                bookId: 1,
                categoryName: categoryName,
                levelOrder: 1,
                title: title,
                unlockScore: 0,
                questions: const [],
              ),
            ],
          },
          rewards: [],
          hadiths: [],
        );

        final issues = _requiredFieldErrors(state);

        for (final idx in emptyFieldIndices) {
          final fieldName = _levelRequiredFields[idx];
          expect(
            issues.any((i) =>
                i.sourceFile.contains('content/') &&
                i.message.contains('Level $fieldName')),
            isTrue,
            reason:
                'Empty level field "$fieldName" should produce a required field error',
          );
        }
      },
    );

    // ── Sub-property 12d: Empty question required fields produce errors ──

    Glados(
      any.nonEmptySubset(_questionRequiredFields.length),
      ExploreConfig(numRuns: 100),
    ).test(
      'empty question required fields always produce errors',
      (emptyFieldIndices) {
        String questionText = 'Valid question?';
        String optionA = 'Answer A';
        String optionB = 'Answer B';
        String correctOption = 'A';

        if (emptyFieldIndices.contains(0)) questionText = '';
        if (emptyFieldIndices.contains(1)) optionA = '';
        if (emptyFieldIndices.contains(2)) optionB = '';
        if (emptyFieldIndices.contains(3)) correctOption = '';

        final state = ContentState(
          series: [
            const SeriesModel(
              id: 1,
              name: 'Series',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            const BookModel(
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
                id: 1,
                bookId: 1,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level',
                unlockScore: 0,
                questions: [
                  QuestionModel(
                    questionText: questionText,
                    optionA: optionA,
                    optionB: optionB,
                    optionC: 'C answer',
                    optionD: 'D answer',
                    correctOption: correctOption,
                    type: 'multiple_choice',
                    explanation: 'Explanation',
                  ),
                ],
              ),
            ],
          },
          rewards: [],
          hadiths: [],
        );

        final issues = _requiredFieldErrors(state);

        for (final idx in emptyFieldIndices) {
          final fieldName = _questionRequiredFields[idx];
          expect(
            issues.any((i) =>
                i.sourceFile.contains('content/') &&
                i.message.contains('Question $fieldName')),
            isTrue,
            reason:
                'Empty question field "$fieldName" should produce a required field error',
          );
        }
      },
    );

    // ── Sub-property 12e: Empty reward required fields produce errors ──

    Glados(
      any.nonEmptySubset(_rewardRequiredFields.length),
      ExploreConfig(numRuns: 100),
    ).test(
      'empty reward required fields always produce errors',
      (emptyFieldIndices) {
        String title = 'Valid Reward';
        String description = 'Valid Description';
        String assetImage = 'assets/images/reward.png';

        if (emptyFieldIndices.contains(0)) title = '';
        if (emptyFieldIndices.contains(1)) description = '';
        if (emptyFieldIndices.contains(2)) assetImage = '';

        final state = ContentState(
          series: [
            const SeriesModel(
              id: 1,
              name: 'Series',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            const BookModel(
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
              const LevelModel(
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
          rewards: [
            RewardModel(
              title: title,
              description: description,
              assetImage: assetImage,
              unlockBookId: 1,
            ),
          ],
          hadiths: [],
        );

        final issues = _requiredFieldErrors(state);

        for (final idx in emptyFieldIndices) {
          final fieldName = _rewardRequiredFields[idx];
          expect(
            issues.any((i) =>
                i.sourceFile == 'rewards.json' &&
                i.message.contains('Reward $fieldName')),
            isTrue,
            reason:
                'Empty reward field "$fieldName" should produce a required field error',
          );
        }
      },
    );

    // ── Sub-property 12f: Empty hadith required fields produce errors ──

    Glados(
      any.nonEmptySubset(_hadithRequiredFields.length),
      ExploreConfig(numRuns: 100),
    ).test(
      'empty hadith required fields always produce errors',
      (emptyFieldIndices) {
        String text = 'Valid hadith text';
        String source = 'Bukhari';

        if (emptyFieldIndices.contains(0)) text = '';
        if (emptyFieldIndices.contains(1)) source = '';

        final state = ContentState(
          series: [
            const SeriesModel(
              id: 1,
              name: 'Series',
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            const BookModel(
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
              const LevelModel(
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
          hadiths: [
            HadithModel(
              text: text,
              source: source,
            ),
          ],
        );

        final issues = _requiredFieldErrors(state);

        for (final idx in emptyFieldIndices) {
          final fieldName = _hadithRequiredFields[idx];
          expect(
            issues.any((i) =>
                i.sourceFile == 'hadiths.json' &&
                i.message.contains('Hadith $fieldName')),
            isTrue,
            reason:
                'Empty hadith field "$fieldName" should produce a required field error',
          );
        }
      },
    );

    // ── Sub-property 12g: Valid state with all fields populated has no required field errors ──

    Glados(
      any.combine3(
        any.nonEmptyString,
        any.nonEmptyString,
        any.nonEmptyString,
        (String s1, String s2, String s3) => (s1: s1, s2: s2, s3: s3),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'state with all required fields populated has no required field errors',
      (input) {
        final state = ContentState(
          series: [
            SeriesModel(
              id: 1,
              name: input.s1,
              sortOrder: 1,
              isLocked: false,
              iconEmoji: '📖',
            ),
          ],
          books: [
            BookModel(
              id: 1,
              title: input.s2,
              description: input.s3,
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
                bookId: 1,
                categoryName: input.s1,
                levelOrder: 1,
                title: input.s2,
                unlockScore: 0,
                questions: [
                  QuestionModel(
                    questionText: input.s3,
                    optionA: input.s1,
                    optionB: input.s2,
                    optionC: input.s3,
                    optionD: input.s1,
                    correctOption: 'A',
                    type: 'multiple_choice',
                    explanation: 'Explanation',
                  ),
                ],
              ),
            ],
          },
          rewards: [
            RewardModel(
              title: input.s1,
              description: input.s2,
              assetImage: 'assets/images/reward.png',
              unlockBookId: 1,
            ),
          ],
          hadiths: [
            HadithModel(
              text: input.s3,
              source: input.s1,
            ),
          ],
        );

        final issues = _requiredFieldErrors(state);
        expect(
          issues,
          isEmpty,
          reason:
              'State with all required fields populated should have no '
              'required field errors, but got: $issues',
        );
      },
    );

    // ── Sub-property 12h: Error count matches number of empty required fields ──

    Glados(
      any.combine2(
        any.nonEmptySubset(_bookRequiredFields.length),
        any.nonEmptySubset(_questionRequiredFields.length),
        (List<int> bookFields, List<int> questionFields) =>
            (bookFields: bookFields, questionFields: questionFields),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'number of required field errors matches number of empty fields',
      (input) {
        String bookTitle = 'Valid Book';
        String bookDescription = 'Valid Description';
        String bookContentFile = 'book_1.json';
        String questionText = 'Valid question?';
        String optionA = 'Answer A';
        String optionB = 'Answer B';
        String correctOption = 'A';

        if (input.bookFields.contains(0)) bookTitle = '';
        if (input.bookFields.contains(1)) bookDescription = '';
        if (input.bookFields.contains(2)) bookContentFile = '';

        if (input.questionFields.contains(0)) questionText = '';
        if (input.questionFields.contains(1)) optionA = '';
        if (input.questionFields.contains(2)) optionB = '';
        if (input.questionFields.contains(3)) correctOption = '';

        final contentFileKey =
            bookContentFile.isNotEmpty ? bookContentFile : 'book_1.json';

        final state = ContentState(
          series: [
            const SeriesModel(
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
              title: bookTitle,
              description: bookDescription,
              assetImage: 'assets/images/b.png',
              bookOrder: 1,
              seriesId: 1,
              contentFile: bookContentFile,
            ),
          ],
          contentFiles: {
            contentFileKey: [
              LevelModel(
                id: 1,
                bookId: 1,
                categoryName: 'Cat',
                levelOrder: 1,
                title: 'Level',
                unlockScore: 0,
                questions: [
                  QuestionModel(
                    questionText: questionText,
                    optionA: optionA,
                    optionB: optionB,
                    optionC: 'C',
                    optionD: 'D',
                    correctOption: correctOption,
                    type: 'multiple_choice',
                    explanation: 'Explanation',
                  ),
                ],
              ),
            ],
          },
          rewards: [],
          hadiths: [],
        );

        final issues = _requiredFieldErrors(state);
        final expectedCount =
            input.bookFields.length + input.questionFields.length;

        expect(
          issues.length,
          equals(expectedCount),
          reason:
              'Expected $expectedCount required field errors '
              '(book fields: ${input.bookFields.map((i) => _bookRequiredFields[i]).toList()}, '
              'question fields: ${input.questionFields.map((i) => _questionRequiredFields[i]).toList()}) '
              'but got ${issues.length}: $issues',
        );
      },
    );
  });
}
