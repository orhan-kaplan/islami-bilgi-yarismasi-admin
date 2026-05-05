import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';

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

  // ── 10.5 Series IDs ──────────────────────────────────────────────

  group('10.5 — Series IDs unique positive integers', () {
    test('duplicate series ID produces error', () {
      final state = _validState().copyWith(
        series: [_series(id: 1, sortOrder: 1), _series(id: 1, sortOrder: 2)],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('Duplicate series ID')), isTrue);
    });

    test('non-positive series ID produces error', () {
      final state = _validState().copyWith(
        series: [_series(id: 0)],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('positive integer')), isTrue);
    });
  });

  // ── 10.4 Book IDs ───────────────────────────────────────────────

  group('10.4 — Book IDs unique positive integers', () {
    test('duplicate book ID produces error', () {
      final state = _validState().copyWith(
        books: [
          _book(id: 1, bookOrder: 1),
          _book(id: 1, bookOrder: 2, contentFile: 'book_2.json'),
        ],
        contentFiles: {
          'book_1.json': [_level()],
          'book_2.json': [_level(id: 2, bookId: 1)],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('Duplicate book ID')), isTrue);
    });

    test('non-positive book ID produces error', () {
      final state = _validState().copyWith(
        books: [_book(id: -1)],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('positive integer') && i.sourceFile == 'books.json'), isTrue);
    });
  });

  // ── 10.1 Level IDs ──────────────────────────────────────────────

  group('10.1 — Level IDs unique positive integers across all books', () {
    test('duplicate level ID across books produces error', () {
      final state = ContentState(
        series: [_series()],
        books: [
          _book(id: 1, bookOrder: 1, contentFile: 'book_1.json'),
          _book(id: 2, bookOrder: 2, contentFile: 'book_2.json'),
        ],
        contentFiles: {
          'book_1.json': [_level(id: 1, bookId: 1)],
          'book_2.json': [_level(id: 1, bookId: 2)],
        },
        rewards: [],
        hadiths: [],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('Duplicate level ID')), isTrue);
    });

    test('non-positive level ID produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [_level(id: 0)],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('positive integer') && i.sourceFile.contains('content/')), isTrue);
    });
  });

  // ── 10.3 Book → Series FK ──────────────────────────────────────

  group('10.3 — Book series_id references existing series', () {
    test('broken series_id produces error', () {
      final state = _validState().copyWith(
        books: [_book(seriesId: 999)],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('series_id')), isTrue);
    });
  });

  // ── 10.2 Level → Book FK ──────────────────────────────────────

  group('10.2 — Level book_id references existing book', () {
    test('broken book_id produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [_level(bookId: 999)],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('book_id') && i.message.contains('non-existent book')), isTrue);
    });
  });

  // ── 10.15 Reward → Book FK ────────────────────────────────────

  group('10.15 — Reward unlock_book_id references existing book', () {
    test('broken unlock_book_id produces error', () {
      final state = _validState().copyWith(
        rewards: [_reward(unlockBookId: 999)],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('unlock_book_id')), isTrue);
    });
  });

  // ── 10.17 Content file book_id consistency ────────────────────

  group('10.17 — Level book_id consistent with referencing book', () {
    test('inconsistent book_id produces error', () {
      final state = ContentState(
        series: [_series()],
        books: [
          _book(id: 1, contentFile: 'book_1.json'),
          _book(id: 2, bookOrder: 2, contentFile: 'book_2.json'),
        ],
        contentFiles: {
          'book_1.json': [_level(id: 1, bookId: 2)], // bookId should be 1
          'book_2.json': [_level(id: 2, bookId: 2)],
        },
        rewards: [],
        hadiths: [],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('inconsistent')), isTrue);
    });
  });

  // ── 10.8 Series sort_order sequential ─────────────────────────

  group('10.8 — Series sort_order sequential from 1', () {
    test('non-sequential sort_order produces error', () {
      final state = _validState().copyWith(
        series: [_series(id: 1, sortOrder: 1), _series(id: 2, sortOrder: 3)],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('sort_order')), isTrue);
    });

    test('sort_order starting from 0 produces error', () {
      final state = _validState().copyWith(
        series: [_series(id: 1, sortOrder: 0)],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('sort_order')), isTrue);
    });
  });

  // ── 10.7 Book order sequential within series ──────────────────

  group('10.7 — book_order sequential from 1 within series', () {
    test('non-sequential book_order produces error', () {
      final state = ContentState(
        series: [_series()],
        books: [
          _book(id: 1, bookOrder: 1, contentFile: 'book_1.json'),
          _book(id: 2, bookOrder: 3, contentFile: 'book_2.json'),
        ],
        contentFiles: {
          'book_1.json': [_level(id: 1, bookId: 1)],
          'book_2.json': [_level(id: 2, bookId: 2)],
        },
        rewards: [],
        hadiths: [],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('book_order')), isTrue);
    });
  });

  // ── 10.6 Level order sequential within book ───────────────────

  group('10.6 — level_order sequential from 1 within book', () {
    test('non-sequential level_order produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(id: 1, levelOrder: 1),
            _level(id: 2, levelOrder: 3),
          ],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('level_order')), isTrue);
    });
  });

  // ── 10.9 correct_option values ────────────────────────────────

  group('10.9 — correct_option must be A, B, C, or D', () {
    test('invalid correct_option produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(questions: [_question(correctOption: 'E')]),
          ],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('correct_option') && i.message.contains('A, B, C, D')), isTrue);
    });
  });

  // ── 10.10 true_false constraints ──────────────────────────────

  group('10.10 — true_false option_c and option_d must be empty', () {
    test('non-empty option_c on true_false produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(questions: [
              _question(type: 'true_false', optionC: 'X', optionD: ''),
            ]),
          ],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('option_c')), isTrue);
    });

    test('non-empty option_d on true_false produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(questions: [
              _question(type: 'true_false', optionC: '', optionD: 'Y'),
            ]),
          ],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('option_d')), isTrue);
    });
  });

  // ── 10.11 matching separator ──────────────────────────────────

  group('10.11 — matching options must contain | separator', () {
    test('missing separator produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(questions: [
              _question(
                type: 'matching',
                optionA: 'left|right',
                optionB: 'left|right',
                optionC: 'no separator',
                optionD: 'left|right',
              ),
            ]),
          ],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('separator')), isTrue);
    });
  });

  // ── 10.12 sorting correct_option ──────────────────────────────

  group('10.12 — sorting correct_option must be A', () {
    test('sorting with correct_option B produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(questions: [
              _question(type: 'sorting', correctOption: 'B'),
            ]),
          ],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('sorting') && i.message.contains('"A"')), isTrue);
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

  // ── 10.16 Required fields ─────────────────────────────────────

  group('10.16 — Required fields non-empty', () {
    test('empty series name produces error', () {
      final state = _validState().copyWith(
        series: [_series(name: '')],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('name') && i.message.contains('required')), isTrue);
    });

    test('empty book title produces error', () {
      final state = _validState().copyWith(
        books: [_book(title: '')],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('title') && i.sourceFile == 'books.json'), isTrue);
    });

    test('empty book description produces error', () {
      final state = _validState().copyWith(
        books: [_book(description: '')],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('description') && i.sourceFile == 'books.json'), isTrue);
    });

    test('empty book content_file produces error', () {
      final state = _validState().copyWith(
        books: [_book(contentFile: '')],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.message.contains('content_file') && i.message.contains('required')), isTrue);
    });

    test('empty level title produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [_level(title: '')],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('title') && i.sourceFile.contains('content/')), isTrue);
    });

    test('empty level category_name produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [_level(categoryName: '')],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('category_name')), isTrue);
    });

    test('empty question_text produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(questions: [_question(questionText: '')]),
          ],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('question_text')), isTrue);
    });

    test('empty option_a produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(questions: [_question(optionA: '')]),
          ],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('option_a')), isTrue);
    });

    test('empty option_b produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(questions: [_question(optionB: '')]),
          ],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('option_b')), isTrue);
    });

    test('empty correct_option produces error', () {
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [
            _level(questions: [_question(correctOption: '')]),
          ],
        },
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('correct_option')), isTrue);
    });

    test('empty reward title produces error', () {
      final state = _validState().copyWith(
        rewards: [_reward(title: '')],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('title') && i.sourceFile == 'rewards.json'), isTrue);
    });

    test('empty reward description produces error', () {
      final state = _validState().copyWith(
        rewards: [_reward(description: '')],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('description') && i.sourceFile == 'rewards.json'), isTrue);
    });

    test('empty reward asset_image produces error', () {
      final state = _validState().copyWith(
        rewards: [_reward(assetImage: '')],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('asset_image') && i.sourceFile == 'rewards.json'), isTrue);
    });

    test('empty hadith text produces error', () {
      final state = _validState().copyWith(
        hadiths: [_hadith(text: '')],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('text') && i.sourceFile == 'hadiths.json'), isTrue);
    });

    test('empty hadith source produces error', () {
      final state = _validState().copyWith(
        hadiths: [_hadith(source: '')],
      );
      final issues = _errors(state);
      expect(issues.any((i) => i.jsonPath.contains('source') && i.sourceFile == 'hadiths.json'), isTrue);
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
      // Should have many errors — at least one per violation category
      expect(issues.length, greaterThanOrEqualTo(8));
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

  // ── 11.4 Duplicate question_text ──────────────────────────────

  group('11.4 — Duplicate question_text after normalization', () {
    test('duplicate question text produces warning', () {
      final questions = List.generate(
        10,
        (i) => _question(
          questionText: i < 2 ? 'Same question?' : 'Unique Q${i + 1}?',
          correctOption: ['A', 'B', 'C', 'D'][i % 4],
        ),
      );
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [_level(questions: questions)],
        },
      );
      final warnings = _warnings(state);
      expect(
        warnings.any((i) => i.message.contains('Duplicate question text')),
        isTrue,
      );
    });

    test('duplicate with different whitespace produces warning', () {
      final questions = List.generate(
        10,
        (i) {
          if (i == 0) return _question(questionText: 'What is this?', correctOption: 'A');
          if (i == 1) return _question(questionText: '  What   is  this?  ', correctOption: 'B');
          return _question(
            questionText: 'Unique Q${i + 1}?',
            correctOption: ['A', 'B', 'C', 'D'][i % 4],
          );
        },
      );
      final state = _validState().copyWith(
        contentFiles: {
          'book_1.json': [_level(questions: questions)],
        },
      );
      final warnings = _warnings(state);
      expect(
        warnings.any((i) => i.message.contains('Duplicate question text')),
        isTrue,
      );
    });

    test('duplicates across different content files produce warning', () {
      final questionsBook1 = List.generate(
        10,
        (i) => _question(
          questionText: i == 0 ? 'Shared question?' : 'Book1 Q${i + 1}?',
          correctOption: ['A', 'B', 'C', 'D'][i % 4],
        ),
      );
      final questionsBook2 = List.generate(
        10,
        (i) => _question(
          questionText: i == 0 ? 'Shared question?' : 'Book2 Q${i + 1}?',
          correctOption: ['A', 'B', 'C', 'D'][i % 4],
        ),
      );
      final state = ContentState(
        series: [_series()],
        books: [
          _book(id: 1, bookOrder: 1, contentFile: 'book_1.json'),
          _book(id: 2, bookOrder: 2, contentFile: 'book_2.json'),
        ],
        contentFiles: {
          'book_1.json': [_level(id: 1, bookId: 1, questions: questionsBook1)],
          'book_2.json': [_level(id: 2, bookId: 2, questions: questionsBook2)],
        },
        rewards: [],
        hadiths: [],
      );
      final warnings = _warnings(state);
      expect(
        warnings.any((i) => i.message.contains('Duplicate question text')),
        isTrue,
      );
    });

    test('unique question texts produce no duplicate warning', () {
      final state = _validState();
      final warnings = _warnings(state);
      expect(
        warnings.any((i) => i.message.contains('Duplicate question text')),
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
