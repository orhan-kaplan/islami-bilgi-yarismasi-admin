import 'package:flutter/foundation.dart';

/// Immutable data model representing a single feedback message.
///
/// Maps to entries in `feedback.json` with snake_case JSON keys.
/// Used across quiz, speed_quiz, time, comeback, streak, and learned categories.
class FeedbackMessageModel {
  final String title;
  final String message;
  final String emoji;
  final String? lottieAsset; // Short format: "feedback/masallah.json"
  final bool shouldRepeat;

  const FeedbackMessageModel({
    required this.title,
    required this.message,
    required this.emoji,
    this.lottieAsset,
    this.shouldRepeat = true,
  });

  factory FeedbackMessageModel.fromJson(Map<String, dynamic> json) {
    return FeedbackMessageModel(
      title: json['title'] as String,
      message: json['message'] as String,
      emoji: json['emoji'] as String,
      lottieAsset: json['lottie_asset'] as String?,
      shouldRepeat: json['should_repeat'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'emoji': emoji,
      'lottie_asset': lottieAsset,
      'should_repeat': shouldRepeat,
    };
  }

  FeedbackMessageModel copyWith({
    String? title,
    String? message,
    String? emoji,
    String? lottieAsset,
    bool? shouldRepeat,
    bool clearLottieAsset = false,
  }) {
    return FeedbackMessageModel(
      title: title ?? this.title,
      message: message ?? this.message,
      emoji: emoji ?? this.emoji,
      lottieAsset: clearLottieAsset ? null : (lottieAsset ?? this.lottieAsset),
      shouldRepeat: shouldRepeat ?? this.shouldRepeat,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedbackMessageModel &&
        other.title == title &&
        other.message == message &&
        other.emoji == emoji &&
        other.lottieAsset == lottieAsset &&
        other.shouldRepeat == shouldRepeat;
  }

  @override
  int get hashCode {
    return Object.hash(title, message, emoji, lottieAsset, shouldRepeat);
  }

  @override
  String toString() {
    return 'FeedbackMessageModel(title: $title, message: $message, '
        'emoji: $emoji, lottieAsset: $lottieAsset, shouldRepeat: $shouldRepeat)';
  }
}

/// Immutable data model representing a player title.
///
/// Maps to entries in the `titles` section of `feedback.json` with snake_case JSON keys.
/// Titles are earned based on the number of completed books (`required_books`).
class PlayerTitleModel {
  final String title;
  final String icon;
  final int requiredBooks;
  final String profileImage;

  const PlayerTitleModel({
    required this.title,
    required this.icon,
    required this.requiredBooks,
    required this.profileImage,
  });

  factory PlayerTitleModel.fromJson(Map<String, dynamic> json) {
    return PlayerTitleModel(
      title: json['title'] as String,
      icon: json['icon'] as String,
      requiredBooks: json['required_books'] as int,
      profileImage: json['profile_image'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'icon': icon,
      'required_books': requiredBooks,
      'profile_image': profileImage,
    };
  }

  PlayerTitleModel copyWith({
    String? title,
    String? icon,
    int? requiredBooks,
    String? profileImage,
  }) {
    return PlayerTitleModel(
      title: title ?? this.title,
      icon: icon ?? this.icon,
      requiredBooks: requiredBooks ?? this.requiredBooks,
      profileImage: profileImage ?? this.profileImage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerTitleModel &&
        other.title == title &&
        other.icon == icon &&
        other.requiredBooks == requiredBooks &&
        other.profileImage == profileImage;
  }

  @override
  int get hashCode {
    return Object.hash(title, icon, requiredBooks, profileImage);
  }

  @override
  String toString() {
    return 'PlayerTitleModel(title: $title, icon: $icon, '
        'requiredBooks: $requiredBooks, profileImage: $profileImage)';
  }
}

/// Immutable aggregate state holding all feedback content categories.
///
/// This is the single source of truth for feedback data in the admin tool.
/// Content is loaded from `data/feedback.json` via the asset server and
/// saved back after edits.
class FeedbackContentState {
  final Map<String, List<FeedbackMessageModel>> quiz;
  final Map<String, List<FeedbackMessageModel>> speedQuiz;
  final Map<String, List<FeedbackMessageModel>> time;
  final List<FeedbackMessageModel> comeback;
  final Map<String, List<FeedbackMessageModel>> streak;
  final List<PlayerTitleModel> titles;
  final Map<String, List<FeedbackMessageModel>> learned;

  const FeedbackContentState({
    required this.quiz,
    required this.speedQuiz,
    required this.time,
    required this.comeback,
    required this.streak,
    required this.titles,
    required this.learned,
  });

  /// Creates an empty state with no feedback content loaded.
  factory FeedbackContentState.empty() => const FeedbackContentState(
        quiz: {},
        speedQuiz: {},
        time: {},
        comeback: [],
        streak: {},
        titles: [],
        learned: {},
      );

  /// Deserializes a [FeedbackContentState] from a JSON map.
  ///
  /// JSON keys use snake_case (e.g. `speed_quiz` maps to [speedQuiz]).
  factory FeedbackContentState.fromJson(Map<String, dynamic> json) {
    return FeedbackContentState(
      quiz: _parseMessageMap(json['quiz'] as Map<String, dynamic>?),
      speedQuiz: _parseMessageMap(json['speed_quiz'] as Map<String, dynamic>?),
      time: _parseMessageMap(json['time'] as Map<String, dynamic>?),
      comeback: _parseMessageList(json['comeback'] as List<dynamic>?),
      streak: _parseMessageMap(json['streak'] as Map<String, dynamic>?),
      titles: (json['titles'] as List<dynamic>?)
              ?.map((e) =>
                  PlayerTitleModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      learned: _parseMessageMap(json['learned'] as Map<String, dynamic>?),
    );
  }

  /// Serializes this state to a JSON map with snake_case keys.
  Map<String, dynamic> toJson() {
    return {
      'quiz': _serializeMessageMap(quiz),
      'speed_quiz': _serializeMessageMap(speedQuiz),
      'time': _serializeMessageMap(time),
      'comeback': comeback.map((m) => m.toJson()).toList(),
      'streak': _serializeMessageMap(streak),
      'titles': titles.map((t) => t.toJson()).toList(),
      'learned': _serializeMessageMap(learned),
    };
  }

  /// Returns a copy of this state with the given fields replaced.
  FeedbackContentState copyWith({
    Map<String, List<FeedbackMessageModel>>? quiz,
    Map<String, List<FeedbackMessageModel>>? speedQuiz,
    Map<String, List<FeedbackMessageModel>>? time,
    List<FeedbackMessageModel>? comeback,
    Map<String, List<FeedbackMessageModel>>? streak,
    List<PlayerTitleModel>? titles,
    Map<String, List<FeedbackMessageModel>>? learned,
  }) {
    return FeedbackContentState(
      quiz: quiz ?? this.quiz,
      speedQuiz: speedQuiz ?? this.speedQuiz,
      time: time ?? this.time,
      comeback: comeback ?? this.comeback,
      streak: streak ?? this.streak,
      titles: titles ?? this.titles,
      learned: learned ?? this.learned,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FeedbackContentState) return false;
    return _messageMapEquals(other.quiz, quiz) &&
        _messageMapEquals(other.speedQuiz, speedQuiz) &&
        _messageMapEquals(other.time, time) &&
        listEquals(other.comeback, comeback) &&
        _messageMapEquals(other.streak, streak) &&
        listEquals(other.titles, titles) &&
        _messageMapEquals(other.learned, learned);
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(quiz.entries.map((e) => Object.hash(e.key, Object.hashAll(e.value)))),
      Object.hashAll(speedQuiz.entries.map((e) => Object.hash(e.key, Object.hashAll(e.value)))),
      Object.hashAll(time.entries.map((e) => Object.hash(e.key, Object.hashAll(e.value)))),
      Object.hashAll(comeback),
      Object.hashAll(streak.entries.map((e) => Object.hash(e.key, Object.hashAll(e.value)))),
      Object.hashAll(titles),
      Object.hashAll(learned.entries.map((e) => Object.hash(e.key, Object.hashAll(e.value)))),
    );
  }

  @override
  String toString() {
    return 'FeedbackContentState(quiz: ${quiz.length} categories, '
        'speedQuiz: ${speedQuiz.length} categories, '
        'time: ${time.length} slots, '
        'comeback: ${comeback.length} messages, '
        'streak: ${streak.length} thresholds, '
        'titles: ${titles.length} titles, '
        'learned: ${learned.length} thresholds)';
  }

  // -- Private helpers --

  static Map<String, List<FeedbackMessageModel>> _parseMessageMap(
      Map<String, dynamic>? json) {
    if (json == null) return {};
    return json.map((key, value) => MapEntry(
          key,
          (value as List<dynamic>)
              .map((e) =>
                  FeedbackMessageModel.fromJson(e as Map<String, dynamic>))
              .toList(),
        ));
  }

  static List<FeedbackMessageModel> _parseMessageList(List<dynamic>? json) {
    if (json == null) return [];
    return json
        .map((e) => FeedbackMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Map<String, List<Map<String, dynamic>>> _serializeMessageMap(
      Map<String, List<FeedbackMessageModel>> map) {
    return map.map(
        (key, value) => MapEntry(key, value.map((m) => m.toJson()).toList()));
  }

  static bool _messageMapEquals(
    Map<String, List<FeedbackMessageModel>> a,
    Map<String, List<FeedbackMessageModel>> b,
  ) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!listEquals(a[key], b[key])) return false;
    }
    return true;
  }
}
