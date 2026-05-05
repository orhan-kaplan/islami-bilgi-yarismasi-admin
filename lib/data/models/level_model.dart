import 'package:flutter/foundation.dart';

import 'question_model.dart';

/// Immutable data model representing a quiz level within a book.
///
/// Maps to level entries inside `content/book_X.json` with snake_case JSON keys.
/// Each level contains a list of [QuestionModel] instances.
class LevelModel {
  final int id;
  final int bookId;
  final String categoryName;
  final int levelOrder;
  final String title;
  final int unlockScore;
  final String? assetImage;
  final List<QuestionModel> questions;

  const LevelModel({
    required this.id,
    required this.bookId,
    required this.categoryName,
    required this.levelOrder,
    required this.title,
    required this.unlockScore,
    this.assetImage,
    required this.questions,
  });

  factory LevelModel.fromJson(Map<String, dynamic> json) {
    return LevelModel(
      id: json['id'] as int,
      bookId: json['book_id'] as int,
      categoryName: json['category_name'] as String,
      levelOrder: json['level_order'] as int,
      title: json['title'] as String,
      unlockScore: json['unlock_score'] as int,
      assetImage: json['asset_image'] as String?,
      questions: (json['questions'] as List<dynamic>)
          .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'category_name': categoryName,
      'level_order': levelOrder,
      'title': title,
      'unlock_score': unlockScore,
      'asset_image': assetImage,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  LevelModel copyWith({
    int? id,
    int? bookId,
    String? categoryName,
    int? levelOrder,
    String? title,
    int? unlockScore,
    String? Function()? assetImage,
    List<QuestionModel>? questions,
  }) {
    return LevelModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      categoryName: categoryName ?? this.categoryName,
      levelOrder: levelOrder ?? this.levelOrder,
      title: title ?? this.title,
      unlockScore: unlockScore ?? this.unlockScore,
      assetImage: assetImage != null ? assetImage() : this.assetImage,
      questions: questions ?? this.questions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LevelModel &&
        other.id == id &&
        other.bookId == bookId &&
        other.categoryName == categoryName &&
        other.levelOrder == levelOrder &&
        other.title == title &&
        other.unlockScore == unlockScore &&
        other.assetImage == assetImage &&
        listEquals(other.questions, questions);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      bookId,
      categoryName,
      levelOrder,
      title,
      unlockScore,
      assetImage,
      Object.hashAll(questions),
    );
  }

  @override
  String toString() {
    return 'LevelModel(id: $id, bookId: $bookId, categoryName: $categoryName, '
        'levelOrder: $levelOrder, title: $title, unlockScore: $unlockScore, '
        'assetImage: $assetImage, questions: ${questions.length} questions)';
  }
}
