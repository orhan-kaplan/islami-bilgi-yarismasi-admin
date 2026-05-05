import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/bulk_importer.dart';

/// Characters used for generating non-empty text without newlines.
const _textChars =
    'abcçdefgğhıijklmnoöprsştuüvyzABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ 0123456789';

/// Valid correct option values for multiple_choice type.
const _correctOptions = ['A', 'B', 'C', 'D'];

/// Extension providing a generator for valid multiple_choice QuestionModel
/// instances suitable for JSON round-trip testing.
extension BulkImporterGenerators on Any {
  /// Generates a non-empty string without newlines (safe for JSON round-trip).
  Generator<String> get _safeNonEmptyString => simple(
        generate: (random, size) {
          final length = random.nextInt(size.clamp(1, 30)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            buffer.write(_textChars[random.nextInt(_textChars.length)]);
          }
          final result = buffer.toString();
          if (result.trim().isEmpty) {
            return _textChars[random.nextInt(_textChars.length)] + result;
          }
          return result;
        },
        shrink: (input) sync* {
          if (input.length > 1) {
            yield input.substring(0, input.length ~/ 2);
          }
        },
      );

  /// Generates a nullable non-empty string (null or safe string).
  Generator<String?> get _nullableSafeString => simple(
        generate: (random, size) {
          if (random.nextBool()) return null;
          final length = random.nextInt(size.clamp(1, 20)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            buffer.write(_textChars[random.nextInt(_textChars.length)]);
          }
          return buffer.toString();
        },
        shrink: (input) sync* {
          if (input != null) yield null;
        },
      );

  /// Generates a valid multiple_choice QuestionModel with non-empty fields
  /// and no newlines in text — suitable for BulkImporter JSON round-trip.
  Generator<QuestionModel> get validMultipleChoiceQuestion => combine2(
        combine5(
          _safeNonEmptyString,
          _safeNonEmptyString,
          _safeNonEmptyString,
          _safeNonEmptyString,
          _safeNonEmptyString,
          (String questionText, String optA, String optB, String optC,
                  String optD) =>
              (
            questionText: questionText,
            optionA: optA,
            optionB: optB,
            optionC: optC,
            optionD: optD,
          ),
        ),
        combine2(
          choose(_correctOptions),
          _nullableSafeString,
          (String correct, String? explanation) => (
            correctOption: correct,
            explanation: explanation,
          ),
        ),
        (opts, meta) => QuestionModel(
          questionText: opts.questionText,
          optionA: opts.optionA,
          optionB: opts.optionB,
          optionC: opts.optionC,
          optionD: opts.optionD,
          correctOption: meta.correctOption,
          explanation: meta.explanation,
          type: 'multiple_choice',
        ),
      );
}

void main() {
  final bulkImporter = BulkImporter();

  group('Property 10: Bulk import JSON array round-trip', () {
    /// **Validates: Requirements 5.3**
    Glados(
      any.listWithLengthInRange(1, 5, any.validMultipleChoiceQuestion),
      ExploreConfig(numRuns: 100),
    ).test(
      'serializing valid QuestionModels as JSON array and parsing with BulkImporter produces equivalent result',
      (questions) {
        // Serialize as JSON array
        final jsonString =
            jsonEncode(questions.map((q) => q.toJson()).toList());

        // Parse with BulkImporter
        final result = bulkImporter.parse(jsonString);

        // Verify no errors
        expect(result.errors, isEmpty,
            reason: 'Valid multiple_choice questions should produce no errors');

        // Verify valid questions match original list
        expect(result.validQuestions.length, equals(questions.length),
            reason: 'All questions should be parsed successfully');

        for (var i = 0; i < questions.length; i++) {
          expect(result.validQuestions[i], equals(questions[i]),
              reason: 'Question at index $i should be equivalent after round-trip');
        }
      },
    );
  });

  group('Property 11: Bulk import line-based format round-trip', () {
    /// **Validates: Requirements 5.4**
    Glados(
      any.listWithLengthInRange(1, 5, any.validMultipleChoiceQuestion),
      ExploreConfig(numRuns: 100),
    ).test(
      'formatting valid multiple_choice questions in line-based format and parsing with BulkImporter produces equivalent result',
      (questions) {
        // Trim fields to match parser behavior (requirement 5.16: parser trims whitespace)
        final trimmedQuestions = questions
            .map((q) => QuestionModel(
                  questionText: q.questionText.trim(),
                  optionA: q.optionA.trim(),
                  optionB: q.optionB.trim(),
                  optionC: q.optionC.trim(),
                  optionD: q.optionD.trim(),
                  correctOption: q.correctOption.trim(),
                  explanation: q.explanation?.trim(),
                  type: q.type,
                ))
            .where((q) =>
                q.questionText.isNotEmpty &&
                q.optionA.isNotEmpty &&
                q.optionB.isNotEmpty &&
                q.optionC.isNotEmpty &&
                q.optionD.isNotEmpty)
            .toList();

        // Skip if trimming eliminated all questions
        if (trimmedQuestions.isEmpty) return;
        // Format each question in line-based format
        final buffer = StringBuffer();
        for (var i = 0; i < trimmedQuestions.length; i++) {
          final q = trimmedQuestions[i];
          // Line 1: question_text
          buffer.writeln(q.questionText);
          // Line 2: option_a
          buffer.writeln(q.optionA);
          // Line 3: option_b
          buffer.writeln(q.optionB);
          // Line 4: option_c
          buffer.writeln(q.optionC);
          // Line 5: option_d
          buffer.writeln(q.optionD);
          // Line 6: correct_option
          buffer.writeln(q.correctOption);
          if (q.explanation != null) {
            // Line 7: explanation
            buffer.writeln(q.explanation);
            // Line 8: type (required when explanation is present to disambiguate)
            buffer.writeln(q.type);
          }
          // Separate questions with a blank line (except last)
          if (i < trimmedQuestions.length - 1) {
            buffer.writeln();
          }
        }

        final lineBasedString = buffer.toString();

        // Parse with BulkImporter
        final result = bulkImporter.parse(lineBasedString);

        // Verify no errors
        expect(result.errors, isEmpty,
            reason:
                'Valid multiple_choice questions in line format should produce no errors');

        // Verify valid questions match original list
        expect(result.validQuestions.length, equals(trimmedQuestions.length),
            reason: 'All questions should be parsed successfully');

        for (var i = 0; i < trimmedQuestions.length; i++) {
          final original = trimmedQuestions[i];
          final parsed = result.validQuestions[i];
          expect(parsed.questionText, equals(original.questionText),
              reason: 'Question text at index $i should match');
          expect(parsed.optionA, equals(original.optionA),
              reason: 'Option A at index $i should match');
          expect(parsed.optionB, equals(original.optionB),
              reason: 'Option B at index $i should match');
          expect(parsed.optionC, equals(original.optionC),
              reason: 'Option C at index $i should match');
          expect(parsed.optionD, equals(original.optionD),
              reason: 'Option D at index $i should match');
          expect(parsed.correctOption, equals(original.correctOption),
              reason: 'Correct option at index $i should match');
          expect(parsed.explanation, equals(original.explanation),
              reason: 'Explanation at index $i should match');
          expect(parsed.type, equals(original.type),
              reason: 'Type at index $i should match');
        }
      },
    );
  });

  group('Property 12: Bulk import type-specific normalization and validation', () {
    /// **Validates: Requirements 5.12, 5.13, 5.14, 5.15**

    test('true_false type normalizes options to Doğru/Yanlış and empties C/D', () {
      final jsonInput = jsonEncode([
        {
          'question_text': 'Hz. Muhammed son peygamberdir',
          'option_a': 'True',
          'option_b': 'False',
          'option_c': 'Maybe',
          'option_d': 'None',
          'correct_option': 'A',
          'type': 'true_false',
        }
      ]);

      final result = bulkImporter.parse(jsonInput);

      expect(result.errors, isEmpty);
      expect(result.validQuestions.length, equals(1));
      final q = result.validQuestions.first;
      expect(q.optionA, equals('Doğru'));
      expect(q.optionB, equals('Yanlış'));
      expect(q.optionC, equals(''));
      expect(q.optionD, equals(''));
      expect(q.correctOption, equals('A'));
    });

    test('true_false type with correctOption=C is marked invalid', () {
      final jsonInput = jsonEncode([
        {
          'question_text': 'Hz. Muhammed son peygamberdir',
          'option_a': 'True',
          'option_b': 'False',
          'option_c': 'Maybe',
          'option_d': 'None',
          'correct_option': 'C',
          'type': 'true_false',
        }
      ]);

      final result = bulkImporter.parse(jsonInput);

      expect(result.validQuestions, isEmpty);
      expect(result.errors.length, equals(1));
      expect(result.errors.first.reason,
          contains('true_false type requires correct_option to be A or B'));
    });

    test('sorting type normalizes correctOption to A regardless of input', () {
      final jsonInput = jsonEncode([
        {
          'question_text': 'Sırala: Namaz vakitleri',
          'option_a': 'Sabah',
          'option_b': 'Öğle',
          'option_c': 'İkindi',
          'option_d': 'Akşam',
          'correct_option': 'D',
          'type': 'sorting',
        }
      ]);

      final result = bulkImporter.parse(jsonInput);

      expect(result.errors, isEmpty);
      expect(result.validQuestions.length, equals(1));
      final q = result.validQuestions.first;
      expect(q.correctOption, equals('A'));
    });

    test('matching type with | in all options is valid', () {
      final jsonInput = jsonEncode([
        {
          'question_text': 'Eşleştir: Peygamberler ve mucizeleri',
          'option_a': 'Hz. Musa | Asa',
          'option_b': 'Hz. İsa | Ölüleri diriltme',
          'option_c': 'Hz. Süleyman | Hayvanlarla konuşma',
          'option_d': 'Hz. İbrahim | Ateşte yanmama',
          'correct_option': 'A',
          'type': 'matching',
        }
      ]);

      final result = bulkImporter.parse(jsonInput);

      expect(result.errors, isEmpty);
      expect(result.validQuestions.length, equals(1));
    });

    test('matching type without | in one option is marked invalid', () {
      final jsonInput = jsonEncode([
        {
          'question_text': 'Eşleştir: Peygamberler ve mucizeleri',
          'option_a': 'Hz. Musa | Asa',
          'option_b': 'Hz. İsa - Ölüleri diriltme',
          'option_c': 'Hz. Süleyman | Hayvanlarla konuşma',
          'option_d': 'Hz. İbrahim | Ateşte yanmama',
          'correct_option': 'A',
          'type': 'matching',
        }
      ]);

      final result = bulkImporter.parse(jsonInput);

      expect(result.validQuestions, isEmpty);
      expect(result.errors.length, equals(1));
      expect(result.errors.first.reason, contains('|'));
    });

    test('invalid type (e.g., "quiz") is marked invalid with descriptive error', () {
      final jsonInput = jsonEncode([
        {
          'question_text': 'Bir soru',
          'option_a': 'A',
          'option_b': 'B',
          'option_c': 'C',
          'option_d': 'D',
          'correct_option': 'A',
          'type': 'quiz',
        }
      ]);

      final result = bulkImporter.parse(jsonInput);

      expect(result.validQuestions, isEmpty);
      expect(result.errors.length, equals(1));
      expect(result.errors.first.reason, equals('Invalid type: quiz'));
    });
  });

  group('Property 13: Bulk import whitespace tolerance', () {
    /// **Validates: Requirements 5.16**
    Glados(
      any.validMultipleChoiceQuestion,
      ExploreConfig(numRuns: 100),
    ).test(
      'adding leading/trailing whitespace to lines and extra blank lines between blocks produces the same parse result as trimmed input',
      (question) {
        // Trim fields to match parser behavior
        final trimmedQuestion = QuestionModel(
          questionText: question.questionText.trim(),
          optionA: question.optionA.trim(),
          optionB: question.optionB.trim(),
          optionC: question.optionC.trim(),
          optionD: question.optionD.trim(),
          correctOption: question.correctOption.trim(),
          explanation: question.explanation?.trim(),
          type: question.type,
        );

        // Skip if trimming produces empty required fields
        if (trimmedQuestion.questionText.isEmpty ||
            trimmedQuestion.optionA.isEmpty ||
            trimmedQuestion.optionB.isEmpty ||
            trimmedQuestion.optionC.isEmpty ||
            trimmedQuestion.optionD.isEmpty) {
          return;
        }

        // Format clean version (no extra whitespace)
        final cleanBuffer = StringBuffer();
        cleanBuffer.writeln(trimmedQuestion.questionText);
        cleanBuffer.writeln(trimmedQuestion.optionA);
        cleanBuffer.writeln(trimmedQuestion.optionB);
        cleanBuffer.writeln(trimmedQuestion.optionC);
        cleanBuffer.writeln(trimmedQuestion.optionD);
        cleanBuffer.writeln(trimmedQuestion.correctOption);
        if (trimmedQuestion.explanation != null) {
          cleanBuffer.writeln(trimmedQuestion.explanation);
          cleanBuffer.writeln(trimmedQuestion.type);
        }
        final cleanInput = cleanBuffer.toString();

        // Format whitespace version (add leading/trailing spaces to each line,
        // add extra blank lines between blocks)
        final wsBuffer = StringBuffer();
        wsBuffer.writeln(''); // extra blank line before
        wsBuffer.writeln(''); // another extra blank line
        wsBuffer.writeln('  ${trimmedQuestion.questionText}  ');
        wsBuffer.writeln('\t${trimmedQuestion.optionA} ');
        wsBuffer.writeln(' ${trimmedQuestion.optionB}\t');
        wsBuffer.writeln('  ${trimmedQuestion.optionC}  ');
        wsBuffer.writeln(' ${trimmedQuestion.optionD}  ');
        wsBuffer.writeln('  ${trimmedQuestion.correctOption} ');
        if (trimmedQuestion.explanation != null) {
          wsBuffer.writeln(' ${trimmedQuestion.explanation}  ');
          wsBuffer.writeln('  ${trimmedQuestion.type}  ');
        }
        wsBuffer.writeln(''); // extra blank line after
        wsBuffer.writeln(''); // another extra blank line
        final wsInput = wsBuffer.toString();

        // Parse both versions
        final cleanResult = bulkImporter.parse(cleanInput);
        final wsResult = bulkImporter.parse(wsInput);

        // Verify both produce the same number of valid questions
        expect(wsResult.validQuestions.length,
            equals(cleanResult.validQuestions.length),
            reason: 'Whitespace version should produce same number of valid questions');

        // Verify both produce the same number of errors
        expect(wsResult.errors.length, equals(cleanResult.errors.length),
            reason: 'Whitespace version should produce same number of errors');

        // Verify parsed questions are equivalent
        for (var i = 0; i < cleanResult.validQuestions.length; i++) {
          final cleanQ = cleanResult.validQuestions[i];
          final wsQ = wsResult.validQuestions[i];
          expect(wsQ.questionText, equals(cleanQ.questionText),
              reason: 'Question text should match after whitespace trimming');
          expect(wsQ.optionA, equals(cleanQ.optionA),
              reason: 'Option A should match after whitespace trimming');
          expect(wsQ.optionB, equals(cleanQ.optionB),
              reason: 'Option B should match after whitespace trimming');
          expect(wsQ.optionC, equals(cleanQ.optionC),
              reason: 'Option C should match after whitespace trimming');
          expect(wsQ.optionD, equals(cleanQ.optionD),
              reason: 'Option D should match after whitespace trimming');
          expect(wsQ.correctOption, equals(cleanQ.correctOption),
              reason: 'Correct option should match after whitespace trimming');
          expect(wsQ.explanation, equals(cleanQ.explanation),
              reason: 'Explanation should match after whitespace trimming');
          expect(wsQ.type, equals(cleanQ.type),
              reason: 'Type should match after whitespace trimming');
        }
      },
    );
  });
}
