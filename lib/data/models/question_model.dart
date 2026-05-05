/// Immutable data model representing a quiz question.
///
/// Maps to question entries inside `content/book_X.json` with snake_case JSON keys.
/// Supports four question types: `multiple_choice`, `true_false`, `matching`, `sorting`.
class QuestionModel {
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption;
  final String? explanation;
  final String type;

  const QuestionModel({
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    this.explanation,
    this.type = 'multiple_choice',
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      questionText: json['question_text'] as String,
      optionA: json['option_a'] as String,
      optionB: json['option_b'] as String,
      optionC: json['option_c'] as String,
      optionD: json['option_d'] as String,
      correctOption: json['correct_option'] as String,
      explanation: json['explanation'] as String?,
      type: json['type'] as String? ?? 'multiple_choice',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_text': questionText,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'correct_option': correctOption,
      'explanation': explanation,
      'type': type,
    };
  }

  QuestionModel copyWith({
    String? questionText,
    String? optionA,
    String? optionB,
    String? optionC,
    String? optionD,
    String? correctOption,
    String? Function()? explanation,
    String? type,
  }) {
    return QuestionModel(
      questionText: questionText ?? this.questionText,
      optionA: optionA ?? this.optionA,
      optionB: optionB ?? this.optionB,
      optionC: optionC ?? this.optionC,
      optionD: optionD ?? this.optionD,
      correctOption: correctOption ?? this.correctOption,
      explanation: explanation != null ? explanation() : this.explanation,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuestionModel &&
        other.questionText == questionText &&
        other.optionA == optionA &&
        other.optionB == optionB &&
        other.optionC == optionC &&
        other.optionD == optionD &&
        other.correctOption == correctOption &&
        other.explanation == explanation &&
        other.type == type;
  }

  @override
  int get hashCode {
    return Object.hash(
      questionText,
      optionA,
      optionB,
      optionC,
      optionD,
      correctOption,
      explanation,
      type,
    );
  }

  @override
  String toString() {
    return 'QuestionModel(questionText: $questionText, optionA: $optionA, '
        'optionB: $optionB, optionC: $optionC, optionD: $optionD, '
        'correctOption: $correctOption, explanation: $explanation, type: $type)';
  }
}
