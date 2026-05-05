/// Validation constants used by [ContentValidator].
///
/// Centralizes magic values so that both the validator and the UI
/// reference the same source of truth.
class ValidationRules {
  ValidationRules._();

  /// Valid values for [QuestionModel.correctOption].
  static const validCorrectOptions = {'A', 'B', 'C', 'D'};

  /// Valid values for [QuestionModel.correctOption] when type is `true_false`.
  static const validTrueFalseCorrectOptions = {'A', 'B'};

  /// Recognised question types.
  static const validQuestionTypes = {
    'multiple_choice',
    'true_false',
    'matching',
    'sorting',
  };

  /// The separator expected inside each option of a `matching` question.
  static const matchingSeparator = '|';

  /// The only valid `correct_option` for `sorting` questions.
  static const sortingCorrectOption = 'A';

  /// Required prefix for asset image paths.
  static const assetImagePrefix = 'assets/';
}
