import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';

// ─── Generators ─────────────────────────────────────────────────────

const _turkishChars =
    'abcçdefgğhıijklmnoöprsştuüvyzABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ0123456789?';

/// Various whitespace characters to inject for normalization testing.
const _whitespaceVariants = [' ', '  ', '\t', '\n', '  \t  ', ' \n '];

extension DuplicateQuestionGenerators on Any {
  /// Generates a non-empty Turkish-flavored string (used as base question text).
  Generator<String> get nonEmptyTurkishString => simple(
        generate: (random, size) {
          final length = random.nextInt(size.clamp(3, 30)) + 3;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            buffer.write(_turkishChars[random.nextInt(_turkishChars.length)]);
          }
          return buffer.toString();
        },
        shrink: (input) sync* {
          if (input.length > 3) yield input.substring(0, input.length ~/ 2);
        },
      );

  /// Generates a whitespace-varied version of a base string.
  /// Inserts random whitespace between words and at boundaries.
  Generator<String> whitespaceVariant(String base) => simple(
        generate: (random, size) {
          final words = base.split(RegExp(r'\s+'));
          final buffer = StringBuffer();

          // Optionally add leading whitespace
          if (random.nextBool()) {
            buffer.write(
                _whitespaceVariants[random.nextInt(_whitespaceVariants.length)]);
          }

          for (var i = 0; i < words.length; i++) {
            buffer.write(words[i]);
            if (i < words.length - 1) {
              // Insert random whitespace between words
              buffer.write(_whitespaceVariants[
                  random.nextInt(_whitespaceVariants.length)]);
            }
          }

          // Optionally add trailing whitespace
          if (random.nextBool()) {
            buffer.write(
                _whitespaceVariants[random.nextInt(_whitespaceVariants.length)]);
          }

          return buffer.toString();
        },
        shrink: (input) sync* {
          final trimmed = input.trim();
          if (trimmed != input) yield trimmed;
        },
      );

  /// Generates a count of unique questions (2–8).
  Generator<int> get uniqueQuestionCount => simple(
        generate: (random, size) => random.nextInt(7) + 2,
        shrink: (input) sync* {
          if (input > 2) yield input - 1;
        },
      );

  /// Generates a random whitespace insertion pattern for a string.
  /// Returns a string with extra whitespace injected at random positions.
  Generator<String> whitespaceMangled(String base) => simple(
        generate: (random, size) {
          if (base.isEmpty) return base;
          final buffer = StringBuffer();

          // Add leading whitespace
          final leadCount = random.nextInt(3);
          for (var i = 0; i < leadCount; i++) {
            buffer.write(' ');
          }

          for (var i = 0; i < base.length; i++) {
            buffer.write(base[i]);
            // Randomly insert extra whitespace after characters
            if (base[i] == ' ' && random.nextBool()) {
              final extraSpaces = random.nextInt(3) + 1;
              for (var j = 0; j < extraSpaces; j++) {
                buffer.write(' ');
              }
            }
          }

          // Add trailing whitespace
          final trailCount = random.nextInt(3);
          for (var i = 0; i < trailCount; i++) {
            buffer.write(' ');
          }

          return buffer.toString();
        },
        shrink: (input) sync* {
          final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
          if (trimmed != input) yield trimmed;
        },
      );

  /// Generates a random number of duplicate occurrences (2–5).
  Generator<int> get duplicateCount => simple(
        generate: (random, size) => random.nextInt(4) + 2,
        shrink: (input) sync* {
          if (input > 2) yield input - 1;
        },
      );
}

// ─── Helpers ────────────────────────────────────────────────────────

final _validator = ContentValidator();

List<ValidationIssue> _warnings(ContentState state) => _validator
    .validateAll(state)
    .where((i) => i.severity == ValidationSeverity.warning)
    .toList();

List<ValidationIssue> _duplicateWarnings(ContentState state) =>
    _warnings(state)
        .where((i) => i.message.contains('Duplicate question text'))
        .toList();

/// Builds a minimal valid ContentState with the given questions in a single level.
ContentState _stateWithQuestions(List<QuestionModel> questions) {
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
        description: 'A test book',
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
          categoryName: 'Category',
          levelOrder: 1,
          title: 'Level 1',
          unlockScore: 0,
          questions: questions,
        ),
      ],
    },
    rewards: const [],
    hadiths: const [],
  );
}

/// Builds a ContentState with questions spread across two content files.
ContentState _stateWithTwoBooks(
    List<QuestionModel> questionsBook1, List<QuestionModel> questionsBook2) {
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
        title: 'Book 1',
        description: 'First book',
        assetImage: 'assets/images/b1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      ),
      const BookModel(
        id: 2,
        title: 'Book 2',
        description: 'Second book',
        assetImage: 'assets/images/b2.png',
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
          categoryName: 'Category',
          levelOrder: 1,
          title: 'Level 1',
          unlockScore: 0,
          questions: questionsBook1,
        ),
      ],
      'book_2.json': [
        LevelModel(
          id: 2,
          bookId: 2,
          categoryName: 'Category',
          levelOrder: 1,
          title: 'Level 1',
          unlockScore: 0,
          questions: questionsBook2,
        ),
      ],
    },
    rewards: const [],
    hadiths: const [],
  );
}

/// Creates a question with the given text.
QuestionModel _q(String text) => QuestionModel(
      questionText: text,
      optionA: 'A answer',
      optionB: 'B answer',
      optionC: 'C answer',
      optionD: 'D answer',
      correctOption: 'A',
      type: 'multiple_choice',
      explanation: 'Explanation',
    );

// ─── Property Tests ─────────────────────────────────────────────────

void main() {
  group('Property 14: Validator Detects Duplicate Questions', () {
    // ── 14a: Exact duplicate question texts produce warnings ──

    Glados(
      any.nonEmptyTurkishString,
      ExploreConfig(numRuns: 100),
    ).test(
      'exact duplicate question texts always produce WARNING-level issues',
      (baseText) {
        // Create two questions with the exact same text plus some unique ones
        final questions = [
          _q(baseText),
          _q(baseText), // duplicate
          _q('Unique question 1?'),
          _q('Unique question 2?'),
        ];

        final state = _stateWithQuestions(questions);
        final issues = _duplicateWarnings(state);

        // Should have exactly 2 warnings (one for each occurrence of the duplicate)
        expect(
          issues.length,
          equals(2),
          reason:
              'Two questions with text "$baseText" should produce 2 duplicate '
              'warnings (one per occurrence), but got ${issues.length}: $issues',
        );

        // All issues should be WARNING severity
        for (final issue in issues) {
          expect(issue.severity, equals(ValidationSeverity.warning));
        }
      },
    );

    // ── 14b: Whitespace-varied duplicates are detected ──

    Glados(
      any.nonEmptyTurkishString,
      ExploreConfig(numRuns: 100),
    ).test(
      'whitespace-varied duplicates are detected after normalization',
      (baseText) {
        // The base text with words separated by single spaces
        final normalizedBase = baseText.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (normalizedBase.isEmpty) return; // skip empty after normalization

        // Create a variant with extra whitespace
        final mangledText = '  $normalizedBase  ';

        final questions = [
          _q(normalizedBase),
          _q(mangledText), // same after normalization
          _q('Completely different question?'),
        ];

        final state = _stateWithQuestions(questions);
        final issues = _duplicateWarnings(state);

        // Should detect the duplicate pair
        expect(
          issues.length,
          equals(2),
          reason:
              'Questions "$normalizedBase" and "$mangledText" should be '
              'detected as duplicates after whitespace normalization, '
              'but got ${issues.length} warnings: $issues',
        );
      },
    );

    // ── 14c: Tabs and newlines in question text are normalized ──

    Glados(
      any.nonEmptyTurkishString,
      ExploreConfig(numRuns: 100),
    ).test(
      'tabs and newlines are collapsed to single space for duplicate detection',
      (baseText) {
        final normalizedBase = baseText.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (normalizedBase.isEmpty) return;

        // Insert tabs and newlines between characters
        final withTabs = normalizedBase.replaceAll(' ', '\t');
        final withNewlines = normalizedBase.replaceAll(' ', '\n');

        // If the base has no spaces, add whitespace variants around it
        final variant = normalizedBase.contains(' ')
            ? withTabs
            : '\t$normalizedBase\t';
        final variant2 = normalizedBase.contains(' ')
            ? withNewlines
            : '\n$normalizedBase\n';

        final questions = [
          _q(normalizedBase),
          _q(variant),
          _q(variant2),
          _q('A totally unique question here?'),
        ];

        final state = _stateWithQuestions(questions);
        final issues = _duplicateWarnings(state);

        // All three should normalize to the same text → 3 warnings
        expect(
          issues.length,
          equals(3),
          reason:
              'Three whitespace variants of "$normalizedBase" should produce '
              '3 duplicate warnings, but got ${issues.length}: $issues',
        );
      },
    );

    // ── 14d: All unique questions produce no duplicate warnings ──

    Glados(
      any.uniqueQuestionCount,
      ExploreConfig(numRuns: 100),
    ).test(
      'all unique question texts produce no duplicate warnings',
      (count) {
        // Generate questions with guaranteed unique texts
        final questions = List.generate(
          count,
          (i) => _q('Unique question number $i with index $i?'),
        );

        final state = _stateWithQuestions(questions);
        final issues = _duplicateWarnings(state);

        expect(
          issues,
          isEmpty,
          reason:
              'State with $count unique questions should have no duplicate '
              'warnings, but got: $issues',
        );
      },
    );

    // ── 14e: Duplicates across different content files are detected ──

    Glados(
      any.nonEmptyTurkishString,
      ExploreConfig(numRuns: 100),
    ).test(
      'duplicates across different content files produce warnings',
      (sharedText) {
        final normalizedShared =
            sharedText.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (normalizedShared.isEmpty) return;

        final questionsBook1 = [
          _q(normalizedShared),
          _q('Book1 unique question?'),
        ];
        final questionsBook2 = [
          _q(normalizedShared), // same text in different book
          _q('Book2 unique question?'),
        ];

        final state = _stateWithTwoBooks(questionsBook1, questionsBook2);
        final issues = _duplicateWarnings(state);

        // Should detect the cross-file duplicate (2 warnings, one per occurrence)
        expect(
          issues.length,
          equals(2),
          reason:
              'Shared question "$normalizedShared" across two books should '
              'produce 2 duplicate warnings, but got ${issues.length}: $issues',
        );

        // Verify warnings reference different source files
        final sourceFiles = issues.map((i) => i.sourceFile).toSet();
        expect(
          sourceFiles.length,
          equals(2),
          reason:
              'Duplicate warnings should reference both content files, '
              'but only referenced: $sourceFiles',
        );
      },
    );

    // ── 14f: Multiple duplicate groups are all detected ──

    Glados(
      any.duplicateCount,
      ExploreConfig(numRuns: 100),
    ).test(
      'multiple distinct duplicate groups each produce warnings',
      (numDuplicateGroups) {
        final questions = <QuestionModel>[];

        // Create numDuplicateGroups groups, each with 2 duplicates
        for (var g = 0; g < numDuplicateGroups; g++) {
          final text = 'Duplicate group $g question text?';
          questions.add(_q(text));
          questions.add(_q(text));
        }

        // Add some unique questions
        questions.add(_q('Unique filler question A?'));
        questions.add(_q('Unique filler question B?'));

        final state = _stateWithQuestions(questions);
        final issues = _duplicateWarnings(state);

        // Each group of 2 duplicates produces 2 warnings
        final expectedWarnings = numDuplicateGroups * 2;
        expect(
          issues.length,
          equals(expectedWarnings),
          reason:
              '$numDuplicateGroups duplicate groups (2 each) should produce '
              '$expectedWarnings warnings, but got ${issues.length}: $issues',
        );
      },
    );

    // ── 14g: Leading/trailing whitespace only duplicates are detected ──

    Glados(
      any.nonEmptyTurkishString,
      ExploreConfig(numRuns: 100),
    ).test(
      'leading and trailing whitespace only differences are detected as duplicates',
      (baseText) {
        final trimmed = baseText.trim();
        if (trimmed.isEmpty) return;

        final questions = [
          _q(trimmed),
          _q('   $trimmed   '), // leading + trailing spaces
          _q('Another unique question?'),
        ];

        final state = _stateWithQuestions(questions);
        final issues = _duplicateWarnings(state);

        expect(
          issues.length,
          equals(2),
          reason:
              'Questions "$trimmed" and "   $trimmed   " should be detected '
              'as duplicates, but got ${issues.length} warnings: $issues',
        );
      },
    );
  });
}
