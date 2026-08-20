import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/save_gating.dart';

// ─── Helpers ────────────────────────────────────────────────────────

SeriesModel _series({int id = 1, String name = 'Test', int sortOrder = 1}) =>
    SeriesModel(
      id: id,
      name: name,
      sortOrder: sortOrder,
      isLocked: false,
      iconEmoji: '📖',
    );

BookModel _book({
  int id = 1,
  String title = 'Book',
  String description = 'Desc',
  String assetImage = 'assets/images/b.png',
  int bookOrder = 1,
  int seriesId = 1,
  String contentFile = 'book_1.json',
}) =>
    BookModel(
      id: id,
      title: title,
      description: description,
      assetImage: assetImage,
      bookOrder: bookOrder,
      seriesId: seriesId,
      contentFile: contentFile,
    );

QuestionModel _question({
  String questionText = 'What is 1+1?',
  String optionA = 'A answer',
  String optionB = 'B answer',
  String optionC = 'C answer',
  String optionD = 'D answer',
  String correctOption = 'A',
  String type = 'multiple_choice',
  String? explanation = 'Some explanation',
}) =>
    QuestionModel(
      questionText: questionText,
      optionA: optionA,
      optionB: optionB,
      optionC: optionC,
      optionD: optionD,
      correctOption: correctOption,
      type: type,
      explanation: explanation,
    );

LevelModel _level({
  int id = 1,
  int bookId = 1,
  String categoryName = 'Cat',
  int levelOrder = 1,
  String title = 'Level',
  int unlockScore = 0,
  String? assetImage = 'assets/images/l.webp',
  List<QuestionModel>? questions,
}) =>
    LevelModel(
      id: id,
      bookId: bookId,
      categoryName: categoryName,
      levelOrder: levelOrder,
      title: title,
      unlockScore: unlockScore,
      assetImage: assetImage,
      questions: questions ?? [_question()],
    );

RewardModel _reward({
  String title = 'Reward',
  String description = 'Desc',
  String assetImage = 'assets/images/r.webp',
  int unlockBookId = 1,
}) =>
    RewardModel(
      title: title,
      description: description,
      assetImage: assetImage,
      unlockBookId: unlockBookId,
    );

HadithModel _hadith({String text = 'Hadith text', String source = 'Source'}) =>
    HadithModel(text: text, source: source);

/// Builds a fully valid [ContentState] that produces zero errors.
ContentState _validState() => ContentState(
      series: [_series()],
      books: [_book()],
      contentFiles: {
        'book_1.json': [_level(questions: _tenQuestions())],
      },
      rewards: [_reward()],
      hadiths: [_hadith()],
    );

/// Generates a list of 10 questions with balanced correct_option distribution.
List<QuestionModel> _tenQuestions() {
  final options = ['A', 'B', 'C', 'D'];
  return List.generate(
    10,
    (i) => _question(
      questionText: 'Question ${i + 1}?',
      correctOption: options[i % 4],
    ),
  );
}

final _validator = ContentValidator();

List<ValidationIssue> _errors(ContentState state) =>
    _validator.validateAll(state).where((i) => i.severity == ValidationSeverity.error).toList();

List<ValidationIssue> _warnings(ContentState state) =>
    _validator.validateAll(state).where((i) => i.severity == ValidationSeverity.warning).toList();

// ─── Tests ──────────────────────────────────────────────────────────

void main() {
  group('ContentValidator — valid state', () {
    test('produces no errors for a fully valid state', () {
      final issues = _errors(_validState());
      expect(issues, isEmpty);
    });
  });

  // ── 10.1 Level IDs ──────────────────────────────────────────────
  //
  // Non-positive level IDs and cross-book duplicates are covered by
  // Property 8 (id_uniqueness_positivity_test.dart, sub-properties 8c/8f).
  // Only the per-file save-gating behavior below is unique to this file.

  group('10.1 — Level IDs unique positive integers across all books', () {
    test('duplicate level ID is reported against both content files', () {
      // Save gating is per file: it only blocks the file the issue names.
      // Reporting a global collision against whichever file happens to be
      // iterated second lets the edited file through and blocks an
      // untouched one.
      final state = ContentState(
        series: [_series()],
        books: [
          _book(id: 1, bookOrder: 1, contentFile: 'book_1.json'),
          _book(id: 2, bookOrder: 2, contentFile: 'book_2.json'),
        ],
        contentFiles: {
          'book_1.json': [_level(id: 7, bookId: 1)],
          'book_2.json': [_level(id: 7, bookId: 2)],
        },
        rewards: [],
        hadiths: [],
      );
      final duplicates = _errors(state)
          .where((i) => i.message.contains('Duplicate level ID'))
          .toList();

      expect(
        duplicates.map((i) => i.sourceFile).toSet(),
        {'content/book_1.json', 'content/book_2.json'},
        reason: 'both files carrying level ID 7 must be blocked — '
            'got: $duplicates',
      );
    });
  });

  // ── 10.18 correct_option must point at a filled option ────────

  group('10.18 — correct_option must reference a non-empty option', () {
    test('multiple_choice pointing at an empty option_d produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(questions: [
              _question(optionC: '', optionD: '', correctOption: 'D'),
            ]),
          ],
        },
      );
      final issues = _errors(state);
      expect(
        issues.any((i) =>
            i.jsonPath.contains('correct_option') &&
            i.message.contains('option_d')),
        isTrue,
        reason: 'the app renders options[3] as the right answer — an empty '
            'string makes the correct answer unpickable',
      );
    });

    test('true_false with correct_option pointing at an empty option produces error', () {
      const expectedField = {'C': 'option_c', 'D': 'option_d'};
      for (final correct in ['C', 'D']) {
        final state = _validState().copyWith(
          contentFiles: {
            'book_1.json': [
              _level(questions: [
                _question(
                  type: 'true_false',
                  optionA: 'Doğru',
                  optionB: 'Yanlış',
                  optionC: '',
                  optionD: '',
                  correctOption: correct,
                ),
              ]),
            ],
          },
        );
        final issues = _errors(state);
        expect(
          issues.any((i) =>
              i.jsonPath.contains('correct_option') &&
              i.message.contains(expectedField[correct]!)),
          isTrue,
          reason: 'correct_option $correct',
        );
      }
    });

    test('multiple_choice pointing at a filled option produces no error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(questions: [
              _question(optionC: '', optionD: '', correctOption: 'B'),
            ]),
          ],
        },
      );
      expect(_errors(state), isEmpty);
    });

    test('true_false answered with A or B produces no error', () {
      for (final correct in ['A', 'B']) {
        final state = _validState().copyWith(
          contentFiles: {
            'book_1.json': [
              _level(questions: [
                _question(
                  type: 'true_false',
                  optionA: 'Doğru',
                  optionB: 'Yanlış',
                  optionC: '',
                  optionD: '',
                  correctOption: correct,
                ),
              ]),
            ],
          },
        );
        expect(_errors(state), isEmpty, reason: 'correct_option $correct');
      }
    });
  });

  // ── 10.13 content_file format and existence ───────────────────

  group('10.13 — content_file filename only and exists', () {
    test('content_file with path prefix produces error', () {
      final state = _validState().copyWith(
        books: [_book(contentFile: 'content/book_1.json')],
        contentFiles: {'content/book_1.json': [_level()]},
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('filename only')), isTrue);
    });

    test('missing content file produces error', () {
      final state = _validState().copyWith(
        books: [_book(contentFile: 'book_99.json')],
        contentFiles: {'book_1.json': [_level()]},
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('No content file found')), isTrue);
    });
  });

  // ── 10.17 content-file book_id consistency ────────────────────

  group('10.17 — content-file book_id consistency', () {
    /// Two books, one file, levels tagged with the *last* book's id.
    /// Last-write-wins on the expected-id map used to miss this entirely.
    ContentState sharedFileMatchingLastBook() => _validState().copyWith(
          books: [
            _book(id: 1, bookOrder: 1, contentFile: 'book_1.json'),
            _book(
              id: 2,
              title: 'Book 2',
              description: 'Desc 2',
              assetImage: 'assets/images/b2.png',
              bookOrder: 2,
              contentFile: 'book_1.json',
            ),
          ],
          contentFiles: {
            'book_1.json': [
              _level(id: 1, bookId: 2, questions: _tenQuestions()),
            ],
          },
        );

    test(
        'two books sharing a content_file produce a books.json error even '
        'when levels match the last referencing book', () {
      final issues = _errors(sharedFileMatchingLastBook());
      expect(
        issues.where((i) =>
            i.sourceFile == 'books.json' &&
            i.jsonPath.contains('content_file') &&
            i.message.contains('book_1.json') &&
            i.message.contains('multiple books')),
        isNotEmpty,
        reason: 'rule 7 cannot hold for two different book IDs on one file — '
            'got: $issues',
      );
    });

    test(
        'shared content_file blocks auto-save of books.json '
        '(seeder would insert the same level PK twice)', () {
      final issues = _errors(sharedFileMatchingLastBook());
      expect(
        isSaveAllowedForFile('data/books.json', issues),
        isFalse,
        reason: 'per-file gating only looks at the issue sourceFile; an error '
            'only on the content file would still write the dual mapping',
      );
    });
  });

  // ── 10.14 asset_image prefix ──────────────────────────────────

  group('10.14 — asset_image must start with assets/', () {
    test('book with bad asset_image produces error', () {
      final state = _validState().copyWith(
        books: [_book(assetImage: 'images/b.png')],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('assets/') && i.sourceFile == 'books.json'), isTrue);
    });

    test('level with bad asset_image produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [_level(assetImage: 'images/l.webp')],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('assets/') && i.sourceFile.contains('content/')), isTrue);
    });

    test('reward with bad asset_image produces error', () {
      final state = _validState().copyWith(
        rewards: [_reward(assetImage: 'images/r.webp')],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('assets/') && i.sourceFile == 'rewards.json'), isTrue);
    });
  });

  // ── Multiple errors reported together ─────────────────────────

  group('Multiple errors reported together', () {
    test('state with many violations reports all of them', () {
      final state = ContentState(
        series: [_series(id: 0, name: '')], // non-positive ID + empty name
        books: [_book(id: -1, title: '', seriesId: 999)], // non-positive ID + empty title + broken FK
        contentFiles: {
          'book_1.json': [
            _level(
              id: 0,
              bookId: 999,
              title: '',
              questions: [_question(correctOption: 'Z')],
            ),
          ],
        },
        rewards: [_reward(unlockBookId: 999, title: '')],
        hadiths: [_hadith(text: '', source: '')],
      );
      final issues = _errors(state);

      // Every planted violation must be independently represented, not just
      // counted — a length check alone would still pass if two categories
      // silently canceled out and a third fired twice.
      expect(
        issues.any((i) => i.message.contains('positive integer') && i.sourceFile == 'series.json'),
        isTrue,
        reason: 'non-positive series ID',
      );
      expect(
        issues.any((i) => i.message.contains('name') && i.message.contains('required')),
        isTrue,
        reason: 'empty series name',
      );
      expect(
        issues.any((i) => i.message.contains('positive integer') && i.sourceFile == 'books.json'),
        isTrue,
        reason: 'non-positive book ID',
      );
      expect(
        issues.any((i) => i.jsonPath.contains('title') && i.sourceFile == 'books.json'),
        isTrue,
        reason: 'empty book title',
      );
      expect(
        issues.any((i) => i.jsonPath.contains('series_id')),
        isTrue,
        reason: 'broken book → series FK',
      );
      expect(
        issues.any((i) => i.message.contains('positive integer') && i.sourceFile.contains('content/')),
        isTrue,
        reason: 'non-positive level ID',
      );
      expect(
        issues.any((i) => i.jsonPath.contains('book_id') && i.message.contains('non-existent book')),
        isTrue,
        reason: 'broken level → book FK',
      );
      expect(
        issues.any((i) => i.jsonPath.contains('title') && i.sourceFile.contains('content/')),
        isTrue,
        reason: 'empty level title',
      );
      expect(
        issues.any((i) => i.message.contains('correct_option') && i.message.contains('A, B, C, D')),
        isTrue,
        reason: 'invalid correct_option',
      );
      expect(
        issues.any((i) => i.jsonPath.contains('unlock_book_id')),
        isTrue,
        reason: 'broken reward → book FK',
      );
      expect(
        issues.any((i) => i.jsonPath.contains('title') && i.sourceFile == 'rewards.json'),
        isTrue,
        reason: 'empty reward title',
      );
      expect(
        issues.any((i) => i.jsonPath.contains('text') && i.sourceFile == 'hadiths.json'),
        isTrue,
        reason: 'empty hadith text',
      );
      expect(
        issues.any((i) => i.jsonPath.contains('source') && i.sourceFile == 'hadiths.json'),
        isTrue,
        reason: 'empty hadith source',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════
  // WARNING-LEVEL VALIDATION RULES (Requirement 11)
  // ══════════════════════════════════════════════════════════════════

  // ── 11.2 Question with empty explanation ──────────────────────

  group('11.2 — Question with empty explanation', () {
    test('question with null explanation produces warning', () {
      final questions = List.generate(
        10,
        (i) => _question(
          questionText: 'Q${i + 1}?',
          correctOption: ['A', 'B', 'C', 'D'][i % 4],
          explanation: i == 0 ? null : 'Explanation $i',
        ),
      );
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [_level(questions: questions)],
        },
      );
      final warnings = _warnings(state);
      expect(
        warnings.any((i) => i.message.contains('empty explanation')),
        isTrue,
      );
    });

    test('question with empty string explanation produces warning', () {
      final questions = List.generate(
        10,
        (i) => _question(
          questionText: 'Q${i + 1}?',
          correctOption: ['A', 'B', 'C', 'D'][i % 4],
          explanation: i == 0 ? '' : 'Explanation $i',
        ),
      );
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [_level(questions: questions)],
        },
      );
      final warnings = _warnings(state);
      expect(
        warnings.any((i) => i.message.contains('empty explanation')),
        isTrue,
      );
    });

    test('question with non-empty explanation produces no warning', () {
      // _validState already has questions with 'Some explanation'
      final state = _validState();
      final warnings = _warnings(state);
      expect(
        warnings.any((i) => i.message.contains('empty explanation')),
        isFalse,
      );
    });
  });

  // ── Warnings don't interfere with error detection ─────────────

  group('Warnings do not interfere with error detection', () {
    test('state with warnings still correctly reports errors', () {
      // State with both a warning trigger (empty explanation) and an error (broken FK)
      final state = ContentState(
        series: [_series()],
        books: [_book(seriesId: 999)], // broken FK → error
        contentFiles: {
          'book_1.json': [_level(questions: [_question(explanation: null)])], // null explanation → warning
        },
        rewards: [],
        hadiths: [],
      );
      final errors = _errors(state);
      final warnings = _warnings(state);
      expect(errors.any((i) => i.jsonPath.contains('series_id')), isTrue);
      expect(warnings.any((i) => i.message.contains('empty explanation')), isTrue);
    });

    test('state with only warnings has zero errors', () {
      // State that triggers warnings but no errors
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [_level(questions: [_question(explanation: null)])], // null explanation → warning
        },
      );
      final errors = _errors(state);
      final warnings = _warnings(state);
      expect(errors, isEmpty);
      expect(warnings, isNotEmpty);
    });
  });
}
