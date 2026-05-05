import 'dart:convert';

import '../models/question_model.dart';

/// Result of bulk import parsing containing valid questions and errors.
class BulkImportResult {
  final List<QuestionModel> validQuestions;
  final List<BulkImportError> errors;

  const BulkImportResult({
    this.validQuestions = const [],
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get hasValidQuestions => validQuestions.isNotEmpty;
}

/// Describes a parsing/validation error for a specific question.
class BulkImportError {
  final int questionIndex; // 0-based
  final String reason;

  const BulkImportError({
    required this.questionIndex,
    required this.reason,
  });
}

/// Stateless service that parses multi-question input in JSON array or
/// line-based format.
///
/// Attempts JSON array parse first, falls back to line-based format.
class BulkImporter {
  static const _validTypes = {
    'multiple_choice',
    'true_false',
    'matching',
    'sorting',
  };

  /// Parses the [input] string as either a JSON array of question objects
  /// or a line-based format. Returns a [BulkImportResult] with valid
  /// questions and any errors encountered.
  BulkImportResult parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const BulkImportResult(
        errors: [BulkImportError(questionIndex: 0, reason: 'No questions found in input')],
      );
    }

    // Try JSON array parse first
    if (trimmed.startsWith('[')) {
      try {
        return _parseJson(trimmed);
      } on FormatException {
        // Fall through to line-based parsing
      }
    }

    return _parseLineBased(trimmed);
  }

  /// Parses a JSON array of question objects.
  BulkImportResult _parseJson(String input) {
    final decoded = json.decode(input);

    if (decoded is! List) {
      throw const FormatException('Expected a JSON array');
    }

    if (decoded.isEmpty) {
      return const BulkImportResult(
        errors: [BulkImportError(questionIndex: 0, reason: 'No questions found in input')],
      );
    }

    final validQuestions = <QuestionModel>[];
    final errors = <BulkImportError>[];

    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map<String, dynamic>) {
        errors.add(BulkImportError(
          questionIndex: i,
          reason: 'Expected a JSON object',
        ));
        continue;
      }

      try {
        final question = QuestionModel.fromJson(item);
        final validationError = _validateQuestion(question, i);
        if (validationError != null) {
          errors.add(validationError);
        } else {
          validQuestions.add(_normalizeQuestion(question));
        }
      } catch (e) {
        errors.add(BulkImportError(
          questionIndex: i,
          reason: 'Invalid question format: $e',
        ));
      }
    }

    return BulkImportResult(
      validQuestions: validQuestions,
      errors: errors,
    );
  }

  /// Parses line-based format where questions are separated by blank lines.
  ///
  /// Format per question block:
  /// - Line 1: question_text
  /// - Line 2: option_a
  /// - Line 3: option_b
  /// - Line 4: option_c
  /// - Line 5: option_d
  /// - Line 6: correct_option (A/B/C/D)
  /// - Line 7: explanation (optional)
  /// - Line 8: type (optional, defaults to multiple_choice)
  BulkImportResult _parseLineBased(String input) {
    final blocks = _splitIntoBlocks(input);

    if (blocks.isEmpty) {
      return const BulkImportResult(
        errors: [BulkImportError(questionIndex: 0, reason: 'No questions found in input')],
      );
    }

    final validQuestions = <QuestionModel>[];
    final errors = <BulkImportError>[];

    for (var i = 0; i < blocks.length; i++) {
      final lines = blocks[i];

      if (lines.length < 6) {
        errors.add(BulkImportError(
          questionIndex: i,
          reason: 'Insufficient lines: expected at least 6 (question, 4 options, correct_option), got ${lines.length}',
        ));
        continue;
      }

      final questionText = lines[0];
      final optionA = lines[1];
      final optionB = lines[2];
      final optionC = lines[3];
      final optionD = lines[4];
      final correctOption = lines[5].toUpperCase();
      final explanation = lines.length > 6 ? lines[6] : null;
      final type = lines.length > 7 ? lines[7] : 'multiple_choice';

      // Validate correct_option value
      if (!{'A', 'B', 'C', 'D'}.contains(correctOption)) {
        errors.add(BulkImportError(
          questionIndex: i,
          reason: 'Invalid correct_option: "${lines[5]}". Must be A, B, C, or D',
        ));
        continue;
      }

      // Validate type
      if (!_validTypes.contains(type)) {
        errors.add(BulkImportError(
          questionIndex: i,
          reason: 'Invalid type: $type',
        ));
        continue;
      }

      final question = QuestionModel(
        questionText: questionText,
        optionA: optionA,
        optionB: optionB,
        optionC: optionC,
        optionD: optionD,
        correctOption: correctOption,
        explanation: explanation,
        type: type,
      );

      final validationError = _validateQuestion(question, i);
      if (validationError != null) {
        errors.add(validationError);
      } else {
        validQuestions.add(_normalizeQuestion(question));
      }
    }

    return BulkImportResult(
      validQuestions: validQuestions,
      errors: errors,
    );
  }

  /// Splits input into blocks of non-empty lines, separated by blank lines.
  /// Trims whitespace from each line and ignores extra blank lines.
  List<List<String>> _splitIntoBlocks(String input) {
    final lines = input.split('\n').map((l) => l.trim()).toList();
    final blocks = <List<String>>[];
    var currentBlock = <String>[];

    for (final line in lines) {
      if (line.isEmpty) {
        if (currentBlock.isNotEmpty) {
          blocks.add(currentBlock);
          currentBlock = <String>[];
        }
      } else {
        currentBlock.add(line);
      }
    }

    if (currentBlock.isNotEmpty) {
      blocks.add(currentBlock);
    }

    return blocks;
  }

  /// Validates a question based on its type. Returns an error if invalid,
  /// or null if valid.
  BulkImportError? _validateQuestion(QuestionModel question, int index) {
    // Validate type value
    if (!_validTypes.contains(question.type)) {
      return BulkImportError(
        questionIndex: index,
        reason: 'Invalid type: ${question.type}',
      );
    }

    // Type-specific validation
    switch (question.type) {
      case 'true_false':
        if (!{'A', 'B'}.contains(question.correctOption)) {
          return BulkImportError(
            questionIndex: index,
            reason: 'true_false type requires correct_option to be A or B',
          );
        }
      case 'matching':
        if (!question.optionA.contains('|')) {
          return BulkImportError(
            questionIndex: index,
            reason: 'matching type requires "|" separator in option_a',
          );
        }
        if (!question.optionB.contains('|')) {
          return BulkImportError(
            questionIndex: index,
            reason: 'matching type requires "|" separator in option_b',
          );
        }
        if (!question.optionC.contains('|')) {
          return BulkImportError(
            questionIndex: index,
            reason: 'matching type requires "|" separator in option_c',
          );
        }
        if (!question.optionD.contains('|')) {
          return BulkImportError(
            questionIndex: index,
            reason: 'matching type requires "|" separator in option_d',
          );
        }
    }

    return null;
  }

  /// Applies type-specific normalization to a validated question.
  QuestionModel _normalizeQuestion(QuestionModel question) {
    switch (question.type) {
      case 'true_false':
        return question.copyWith(
          optionA: 'Doğru',
          optionB: 'Yanlış',
          optionC: '',
          optionD: '',
        );
      case 'sorting':
        return question.copyWith(correctOption: 'A');
      default:
        return question;
    }
  }
}
