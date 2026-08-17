import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';

// ─── Generators ─────────────────────────────────────────────────────

extension QuestionTypeGenerators on Any {
  /// Generates a random question type from the four valid types.
  Generator<String> get questionType => simple(
        generate: (random, size) {
          const types = [
            'multiple_choice',
            'true_false',
            'matching',
            'sorting',
          ];
          return types[random.nextInt(types.length)];
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a valid correct_option (A, B, C, or D).
  Generator<String> get validCorrectOption => simple(
        generate: (random, size) {
          const options = ['A', 'B', 'C', 'D'];
          return options[random.nextInt(options.length)];
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates an invalid correct_option (not A, B, C, or D).
  Generator<String> get invalidCorrectOption => simple(
        generate: (random, size) {
          const invalid = ['E', 'F', 'a', 'b', '1', 'AB', 'X', 'Z', ''];
          return invalid[random.nextInt(invalid.length)];
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a non-empty string (for option text).
  Generator<String> get nonEmptyString => simple(
        generate: (random, size) {
          final length = random.nextInt(size.clamp(1, 20)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            buffer.writeCharCode(65 + random.nextInt(26)); // A-Z
          }
          return buffer.toString();
        },
        shrink: (input) sync* {
          if (input.length > 1) yield input.substring(0, input.length ~/ 2);
        },
      );

  /// Generates a non-empty string that does NOT contain the '|' separator.
  Generator<String> get stringWithoutPipe => simple(
        generate: (random, size) {
          final length = random.nextInt(size.clamp(1, 15)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            // Use letters and digits only (no pipe)
            buffer.writeCharCode(65 + random.nextInt(26));
          }
          return buffer.toString();
        },
        shrink: (input) sync* {
          if (input.length > 1) yield input.substring(0, input.length ~/ 2);
        },
      );

  /// Generates a string containing the '|' separator (valid matching option).
  Generator<String> get matchingOption => simple(
        generate: (random, size) {
          final leftLen = random.nextInt(size.clamp(1, 10)) + 1;
          final rightLen = random.nextInt(size.clamp(1, 10)) + 1;
          final left = String.fromCharCodes(
            List.generate(leftLen, (_) => 65 + random.nextInt(26)),
          );
          final right = String.fromCharCodes(
            List.generate(rightLen, (_) => 65 + random.nextInt(26)),
          );
          return '$left|$right';
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a correct_option that is NOT 'A' (for sorting violations).
  Generator<String> get nonACorrectOption => simple(
        generate: (random, size) {
          const options = ['B', 'C', 'D'];
          return options[random.nextInt(options.length)];
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a correct_option for true_false that is NOT A or B.
  Generator<String> get invalidTrueFalseCorrectOption => simple(
        generate: (random, size) {
          const options = ['C', 'D'];
          return options[random.nextInt(options.length)];
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a count between min and max.
  Generator<int> get smallCount => simple(
        generate: (random, size) => random.nextInt(4) + 1,
        shrink: (input) sync* {
          if (input > 1) yield input - 1;
        },
      );
}

// ─── Helpers ────────────────────────────────────────────────────────

final _validator = ContentValidator();

List<ValidationIssue> _errors(ContentState state) => _validator
    .validateAll(state)
    .where((i) => i.severity == ValidationSeverity.error)
    .toList();

/// Wraps a single question in a valid ContentState for validation.
ContentState _stateWithQuestion(QuestionModel question) => ContentState(
      series: [
        const SeriesModel(
          id: 1,
          name: 'Series 1',
          sortOrder: 1,
          isLocked: false,
          iconEmoji: '📖',
        ),
      ],
      books: [
        const BookModel(
          id: 1,
          title: 'Book 1',
          description: 'Description',
          assetImage: 'assets/images/book.png',
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
            assetImage: 'assets/images/level.webp',
            questions: [question],
          ),
        ],
      },
      rewards: [],
      hadiths: [],
    );

/// Wraps multiple questions in a valid ContentState for validation.
ContentState _stateWithQuestions(List<QuestionModel> questions) => ContentState(
      series: [
        const SeriesModel(
          id: 1,
          name: 'Series 1',
          sortOrder: 1,
          isLocked: false,
          iconEmoji: '📖',
        ),
      ],
      books: [
        const BookModel(
          id: 1,
          title: 'Book 1',
          description: 'Description',
          assetImage: 'assets/images/book.png',
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
            assetImage: 'assets/images/level.webp',
            questions: questions,
          ),
        ],
      },
      rewards: [],
      hadiths: [],
    );

/// Checks if any error relates to correct_option constraint.
bool _hasCorrectOptionError(List<ValidationIssue> issues) => issues.any((i) =>
    i.jsonPath.contains('correct_option') &&
    i.message.contains('A, B, C, D'));

/// Checks if any error relates to true_false option_c/option_d constraint.
bool _hasTrueFalseOptionError(List<ValidationIssue> issues) => issues.any(
    (i) =>
        i.message.contains('true_false') &&
        (i.jsonPath.contains('option_c') || i.jsonPath.contains('option_d')));

/// Checks if any error relates to matching separator constraint.
bool _hasMatchingSeparatorError(List<ValidationIssue> issues) =>
    issues.any((i) => i.message.contains('separator'));

/// Checks if any error relates to sorting correct_option constraint.
bool _hasSortingCorrectOptionError(List<ValidationIssue> issues) =>
    issues.any((i) =>
        i.message.contains('sorting') && i.message.contains('"A"'));

// ─── Property Tests ─────────────────────────────────────────────────

void main() {
  group('Property 11: Validator Enforces Question Type Constraints', () {
    // ── Sub-property 11a: Invalid correct_option always produces error ──

    Glados(
      any.invalidCorrectOption,
      ExploreConfig(numRuns: 100),
    ).test(
      'invalid correct_option always produces an error',
      (invalidOption) {
        final question = QuestionModel(
          questionText: 'Test question?',
          optionA: 'Answer A',
          optionB: 'Answer B',
          optionC: 'Answer C',
          optionD: 'Answer D',
          correctOption: invalidOption,
          type: 'multiple_choice',
          explanation: 'Explanation',
        );

        final issues = _errors(_stateWithQuestion(question));
        expect(
          _hasCorrectOptionError(issues),
          isTrue,
          reason:
              'correct_option "$invalidOption" is not in {A, B, C, D} '
              'and should produce an error',
        );
      },
    );

    // ── Sub-property 11b: Valid correct_option produces no correct_option error ──

    Glados(
      any.validCorrectOption,
      ExploreConfig(numRuns: 100),
    ).test(
      'valid correct_option produces no correct_option error',
      (validOption) {
        final question = QuestionModel(
          questionText: 'Test question?',
          optionA: 'Answer A',
          optionB: 'Answer B',
          optionC: 'Answer C',
          optionD: 'Answer D',
          correctOption: validOption,
          type: 'multiple_choice',
          explanation: 'Explanation',
        );

        final issues = _errors(_stateWithQuestion(question));
        expect(
          _hasCorrectOptionError(issues),
          isFalse,
          reason:
              'correct_option "$validOption" is valid and should not '
              'produce a correct_option error',
        );
      },
    );

    // ── Sub-property 11c: true_false with non-empty option_c produces error ──

    Glados(
      any.nonEmptyString,
      ExploreConfig(numRuns: 100),
    ).test(
      'true_false with non-empty option_c always produces an error',
      (nonEmptyC) {
        final question = QuestionModel(
          questionText: 'Is this true?',
          optionA: 'Doğru',
          optionB: 'Yanlış',
          optionC: nonEmptyC,
          optionD: '',
          correctOption: 'A',
          type: 'true_false',
          explanation: 'Explanation',
        );

        final issues = _errors(_stateWithQuestion(question));
        expect(
          _hasTrueFalseOptionError(issues),
          isTrue,
          reason:
              'true_false question with non-empty option_c "$nonEmptyC" '
              'should produce an error',
        );
      },
    );

    // ── Sub-property 11d: true_false with non-empty option_d produces error ──

    Glados(
      any.nonEmptyString,
      ExploreConfig(numRuns: 100),
    ).test(
      'true_false with non-empty option_d always produces an error',
      (nonEmptyD) {
        final question = QuestionModel(
          questionText: 'Is this true?',
          optionA: 'Doğru',
          optionB: 'Yanlış',
          optionC: '',
          optionD: nonEmptyD,
          correctOption: 'A',
          type: 'true_false',
          explanation: 'Explanation',
        );

        final issues = _errors(_stateWithQuestion(question));
        expect(
          _hasTrueFalseOptionError(issues),
          isTrue,
          reason:
              'true_false question with non-empty option_d "$nonEmptyD" '
              'should produce an error',
        );
      },
    );

    // ── Sub-property 11e: true_false with empty option_c and option_d produces no type error ──

    Glados(
      any.combine2(
        any.nonEmptyString,
        any.nonEmptyString,
        (String optA, String optB) => (optionA: optA, optionB: optB),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'true_false with empty option_c and option_d produces no true_false error',
      (input) {
        final question = QuestionModel(
          questionText: 'Is this true?',
          optionA: input.optionA,
          optionB: input.optionB,
          optionC: '',
          optionD: '',
          correctOption: 'A',
          type: 'true_false',
          explanation: 'Explanation',
        );

        final issues = _errors(_stateWithQuestion(question));
        expect(
          _hasTrueFalseOptionError(issues),
          isFalse,
          reason:
              'true_false question with empty option_c and option_d '
              'should not produce a true_false type error',
        );
      },
    );

    // ── Sub-property 11f: matching option without pipe separator produces error ──

    Glados(
      any.combine2(
        any.stringWithoutPipe,
        any.smallCount,
        (String badOption, int whichOption) =>
            (badOption: badOption, whichOption: whichOption),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'matching question with option missing pipe separator produces an error',
      (input) {
        // Place the bad option at a random position (1-4 maps to A-D)
        final position = (input.whichOption % 4) + 1;
        const good = 'left|right';

        final question = QuestionModel(
          questionText: 'Match the pairs?',
          optionA: position == 1 ? input.badOption : good,
          optionB: position == 2 ? input.badOption : good,
          optionC: position == 3 ? input.badOption : good,
          optionD: position == 4 ? input.badOption : good,
          correctOption: 'A',
          type: 'matching',
          explanation: 'Explanation',
        );

        final issues = _errors(_stateWithQuestion(question));
        expect(
          _hasMatchingSeparatorError(issues),
          isTrue,
          reason:
              'matching question with option "${input.badOption}" (no pipe) '
              'at position $position should produce a separator error',
        );
      },
    );

    // ── Sub-property 11g: matching with all options containing pipe produces no separator error ──

    Glados(
      any.combine4(
        any.matchingOption,
        any.matchingOption,
        any.matchingOption,
        any.matchingOption,
        (String a, String b, String c, String d) =>
            (optA: a, optB: b, optC: c, optD: d),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'matching question with all options containing pipe produces no separator error',
      (input) {
        final question = QuestionModel(
          questionText: 'Match the pairs?',
          optionA: input.optA,
          optionB: input.optB,
          optionC: input.optC,
          optionD: input.optD,
          correctOption: 'A',
          type: 'matching',
          explanation: 'Explanation',
        );

        final issues = _errors(_stateWithQuestion(question));
        expect(
          _hasMatchingSeparatorError(issues),
          isFalse,
          reason:
              'matching question with all options containing "|" '
              'should not produce a separator error',
        );
      },
    );

    // ── Sub-property 11h: sorting with correct_option != A produces error ──

    Glados(
      any.nonACorrectOption,
      ExploreConfig(numRuns: 100),
    ).test(
      'sorting question with correct_option != A always produces an error',
      (nonAOption) {
        final question = QuestionModel(
          questionText: 'Sort these items?',
          optionA: 'First',
          optionB: 'Second',
          optionC: 'Third',
          optionD: 'Fourth',
          correctOption: nonAOption,
          type: 'sorting',
          explanation: 'Explanation',
        );

        final issues = _errors(_stateWithQuestion(question));
        expect(
          _hasSortingCorrectOptionError(issues),
          isTrue,
          reason:
              'sorting question with correct_option "$nonAOption" '
              'should produce an error (must be "A")',
        );
      },
    );

    // ── Sub-property 11i: sorting with correct_option A produces no sorting error ──

    Glados(
      any.combine4(
        any.nonEmptyString,
        any.nonEmptyString,
        any.nonEmptyString,
        any.nonEmptyString,
        (String a, String b, String c, String d) =>
            (optA: a, optB: b, optC: c, optD: d),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'sorting question with correct_option A produces no sorting error',
      (input) {
        final question = QuestionModel(
          questionText: 'Sort these items?',
          optionA: input.optA,
          optionB: input.optB,
          optionC: input.optC,
          optionD: input.optD,
          correctOption: 'A',
          type: 'sorting',
          explanation: 'Explanation',
        );

        final issues = _errors(_stateWithQuestion(question));
        expect(
          _hasSortingCorrectOptionError(issues),
          isFalse,
          reason:
              'sorting question with correct_option "A" '
              'should not produce a sorting error',
        );
      },
    );

    // ── Sub-property 11j: valid multiple_choice question produces no type-related errors ──

    Glados(
      any.combine4(
        any.nonEmptyString,
        any.nonEmptyString,
        any.nonEmptyString,
        any.validCorrectOption,
        (String qText, String optA, String optB, String correctOpt) =>
            (qText: qText, optA: optA, optB: optB, correctOpt: correctOpt),
      ),
      ExploreConfig(numRuns: 100),
    ).test(
      'valid multiple_choice question produces no type-related errors',
      (input) {
        final question = QuestionModel(
          questionText: '${input.qText}?',
          optionA: input.optA,
          optionB: input.optB,
          optionC: 'Option C',
          optionD: 'Option D',
          correctOption: input.correctOpt,
          type: 'multiple_choice',
          explanation: 'Explanation',
        );

        final issues = _errors(_stateWithQuestion(question));
        // Should have no correct_option, true_false, matching, or sorting errors
        expect(
          _hasCorrectOptionError(issues),
          isFalse,
          reason: 'Valid multiple_choice should not have correct_option error',
        );
        expect(
          _hasTrueFalseOptionError(issues),
          isFalse,
          reason: 'multiple_choice should not trigger true_false checks',
        );
        expect(
          _hasMatchingSeparatorError(issues),
          isFalse,
          reason: 'multiple_choice should not trigger matching checks',
        );
        expect(
          _hasSortingCorrectOptionError(issues),
          isFalse,
          reason: 'multiple_choice should not trigger sorting checks',
        );
      },
    );

    // ── Sub-property 11k: mixed valid questions produce no type errors ──

    Glados(
      any.smallCount,
      ExploreConfig(numRuns: 100),
    ).test(
      'a set of correctly-formed questions of all types produces no type errors',
      (count) {
        final questions = <QuestionModel>[];

        // Add one valid question of each type
        questions.add(const QuestionModel(
          questionText: 'Multiple choice question?',
          optionA: 'A answer',
          optionB: 'B answer',
          optionC: 'C answer',
          optionD: 'D answer',
          correctOption: 'B',
          type: 'multiple_choice',
          explanation: 'Explanation',
        ));

        questions.add(const QuestionModel(
          questionText: 'True or false question?',
          optionA: 'Doğru',
          optionB: 'Yanlış',
          optionC: '',
          optionD: '',
          correctOption: 'A',
          type: 'true_false',
          explanation: 'Explanation',
        ));

        questions.add(const QuestionModel(
          questionText: 'Match the pairs?',
          optionA: 'left1|right1',
          optionB: 'left2|right2',
          optionC: 'left3|right3',
          optionD: 'left4|right4',
          correctOption: 'A',
          type: 'matching',
          explanation: 'Explanation',
        ));

        questions.add(const QuestionModel(
          questionText: 'Sort these items?',
          optionA: 'First',
          optionB: 'Second',
          optionC: 'Third',
          optionD: 'Fourth',
          correctOption: 'A',
          type: 'sorting',
          explanation: 'Explanation',
        ));

        // Add extra valid multiple_choice questions based on count
        for (var i = 0; i < count; i++) {
          questions.add(QuestionModel(
            questionText: 'Extra question ${i + 1}?',
            optionA: 'A${i + 1}',
            optionB: 'B${i + 1}',
            optionC: 'C${i + 1}',
            optionD: 'D${i + 1}',
            correctOption: ['A', 'B', 'C', 'D'][i % 4],
            type: 'multiple_choice',
            explanation: 'Explanation',
          ));
        }

        final issues = _errors(_stateWithQuestions(questions));

        // Filter to only type-constraint errors
        final typeErrors = issues.where((i) =>
            _hasCorrectOptionError([i]) ||
            _hasTrueFalseOptionError([i]) ||
            _hasMatchingSeparatorError([i]) ||
            _hasSortingCorrectOptionError([i]));

        expect(
          typeErrors,
          isEmpty,
          reason:
              'A set of correctly-formed questions should produce no '
              'type-constraint errors, but got: $typeErrors',
        );
      },
    );
  });
}
