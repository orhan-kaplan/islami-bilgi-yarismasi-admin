import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';

/// Question-type rules that let broken content through the save/export gate.
///
/// Each case here validates cleanly today but renders wrong in the mobile app:
/// the app splits a `matching` option into exactly two parts, shuffles all
/// four `sorting` options, and falls back to multiple choice for any type it
/// does not recognise.

final _validator = ContentValidator();

List<ValidationIssue> _errors(ContentState state) => _validator
    .validateAll(state)
    .where((i) => i.severity == ValidationSeverity.error)
    .toList();

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
      rewards: const [],
      hadiths: const [],
    );

QuestionModel _matching({
  String optionA = 'left1|right1',
  String optionB = 'left2|right2',
  String optionC = 'left3|right3',
  String optionD = 'left4|right4',
}) =>
    QuestionModel(
      questionText: 'Match the pairs?',
      optionA: optionA,
      optionB: optionB,
      optionC: optionC,
      optionD: optionD,
      correctOption: 'A',
      type: 'matching',
      explanation: 'Explanation',
    );

QuestionModel _sorting({
  String optionA = 'First',
  String optionB = 'Second',
  String optionC = 'Third',
  String optionD = 'Fourth',
}) =>
    QuestionModel(
      questionText: 'Sort these items?',
      optionA: optionA,
      optionB: optionB,
      optionC: optionC,
      optionD: optionD,
      correctOption: 'A',
      type: 'sorting',
      explanation: 'Explanation',
    );

bool _hasSeparatorError(List<ValidationIssue> issues) =>
    issues.any((i) => i.message.contains('separator'));

void main() {
  group('matching option pipe count', () {
    test('an option with two pipes produces a separator error', () {
      final issues = _errors(
        _stateWithQuestion(_matching(optionA: 'left|middle|right')),
      );
      expect(
        _hasSeparatorError(issues),
        isTrue,
        reason: 'an option with two pipes cannot be split into a left/right '
            'pair and renders as "Hata" in the app — got: $issues',
      );
    });

    test('an option made of pipes only produces a separator error', () {
      final issues = _errors(_stateWithQuestion(_matching(optionD: 'a|b|c|d')));
      expect(_hasSeparatorError(issues), isTrue);
    });

    test('exactly one pipe per option produces no separator error', () {
      final issues = _errors(
        _stateWithQuestion(_matching(
          optionA: 'Doğumu | 571',
          optionB: 'Annesinin Vefatı | 6 Yaş',
          optionC: 'Dedesinin Vefatı | 8 Yaş',
          optionD: 'Evliliği | 25 Yaş',
        )),
      );
      expect(_hasSeparatorError(issues), isFalse);
    });
  });

  group('sorting item completeness', () {
    test('an empty option_c produces an error', () {
      final issues = _errors(_stateWithQuestion(_sorting(optionC: '')));
      expect(
        issues.any((i) =>
            i.jsonPath.contains('option_c') && i.message.contains('sorting')),
        isTrue,
        reason: 'the app shuffles all four options, so an empty item makes the '
            'question unsolvable — got: $issues',
      );
    });

    test('an empty option_d produces an error', () {
      final issues = _errors(_stateWithQuestion(_sorting(optionD: '')));
      expect(
        issues.any((i) =>
            i.jsonPath.contains('option_d') && i.message.contains('sorting')),
        isTrue,
      );
    });

    test('four filled items produce no error', () {
      expect(
        _errors(_stateWithQuestion(_sorting(
          optionA: 'Hz. İbrahim',
          optionB: 'Hz. İsmail',
          optionC: 'Adnan',
          optionD: 'Hz. Muhammed (s.a.v)',
        ))),
        isEmpty,
      );
    });
  });

  group('question type whitelist', () {
    test('an unrecognised type produces an error', () {
      final issues = _errors(
        _stateWithQuestion(_matching().copyWith(type: 'matchin')),
      );
      expect(
        issues.any((i) => i.jsonPath.endsWith('.type')),
        isTrue,
        reason: 'an unknown type silently degrades to multiple choice in the '
            'app and skips every type rule — got: $issues',
      );
    });

    test('an empty type produces an error', () {
      final issues = _errors(
        _stateWithQuestion(_sorting().copyWith(type: '')),
      );
      expect(issues.any((i) => i.jsonPath.endsWith('.type')), isTrue);
    });

    test('each of the four known types validates cleanly', () {
      const known = {
        'multiple_choice': ('A', 'B', 'C', 'D'),
        'true_false': ('Doğru', 'Yanlış', '', ''),
        'matching': ('l1|r1', 'l2|r2', 'l3|r3', 'l4|r4'),
        'sorting': ('First', 'Second', 'Third', 'Fourth'),
      };

      for (final entry in known.entries) {
        final (a, b, c, d) = entry.value;
        final question = QuestionModel(
          questionText: 'A question?',
          optionA: a,
          optionB: b,
          optionC: c,
          optionD: d,
          correctOption: 'A',
          type: entry.key,
          explanation: 'Explanation',
        );
        expect(
          _errors(_stateWithQuestion(question)),
          isEmpty,
          reason: 'type "${entry.key}" should validate cleanly',
        );
      }
    });
  });
}
