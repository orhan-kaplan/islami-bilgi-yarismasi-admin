/// Immutable data model representing a book completion reward.
///
/// Maps to entries in `rewards.json` with snake_case JSON keys.
class RewardModel {
  final String title;
  final String description;
  final String assetImage;
  final int unlockBookId;

  const RewardModel({
    required this.title,
    required this.description,
    required this.assetImage,
    required this.unlockBookId,
  });

  factory RewardModel.fromJson(Map<String, dynamic> json) {
    return RewardModel(
      title: json['title'] as String,
      description: json['description'] as String,
      assetImage: json['asset_image'] as String,
      unlockBookId: json['unlock_book_id'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'asset_image': assetImage,
      'unlock_book_id': unlockBookId,
    };
  }

  RewardModel copyWith({
    String? title,
    String? description,
    String? assetImage,
    int? unlockBookId,
  }) {
    return RewardModel(
      title: title ?? this.title,
      description: description ?? this.description,
      assetImage: assetImage ?? this.assetImage,
      unlockBookId: unlockBookId ?? this.unlockBookId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RewardModel &&
        other.title == title &&
        other.description == description &&
        other.assetImage == assetImage &&
        other.unlockBookId == unlockBookId;
  }

  @override
  int get hashCode {
    return Object.hash(title, description, assetImage, unlockBookId);
  }

  @override
  String toString() {
    return 'RewardModel(title: $title, description: $description, '
        'assetImage: $assetImage, unlockBookId: $unlockBookId)';
  }
}
