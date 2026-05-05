/// Immutable data model representing a hadith entry.
///
/// Maps to entries in `hadiths.json` with snake_case JSON keys.
class HadithModel {
  final String text;
  final String source;

  const HadithModel({
    required this.text,
    required this.source,
  });

  factory HadithModel.fromJson(Map<String, dynamic> json) {
    return HadithModel(
      text: json['text'] as String,
      source: json['source'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'source': source,
    };
  }

  HadithModel copyWith({
    String? text,
    String? source,
  }) {
    return HadithModel(
      text: text ?? this.text,
      source: source ?? this.source,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HadithModel &&
        other.text == text &&
        other.source == source;
  }

  @override
  int get hashCode {
    return Object.hash(text, source);
  }

  @override
  String toString() {
    return 'HadithModel(text: $text, source: $source)';
  }
}
