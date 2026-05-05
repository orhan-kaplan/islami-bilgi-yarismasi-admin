import 'package:flutter/foundation.dart';

import 'book_model.dart';
import 'hadith_model.dart';
import 'level_model.dart';
import 'reward_model.dart';
import 'series_model.dart';

/// Immutable aggregate state holding all content in memory.
///
/// This is the single source of truth for the admin tool. Content enters
/// via ZIP import and is exported back as a ZIP archive.
class ContentState {
  final List<SeriesModel> series;
  final List<BookModel> books;
  final Map<String, List<LevelModel>> contentFiles;
  final List<RewardModel> rewards;
  final List<HadithModel> hadiths;

  const ContentState({
    required this.series,
    required this.books,
    required this.contentFiles,
    required this.rewards,
    required this.hadiths,
  });

  /// Creates an empty state with no content loaded.
  factory ContentState.empty() {
    return const ContentState(
      series: [],
      books: [],
      contentFiles: {},
      rewards: [],
      hadiths: [],
    );
  }

  ContentState copyWith({
    List<SeriesModel>? series,
    List<BookModel>? books,
    Map<String, List<LevelModel>>? contentFiles,
    List<RewardModel>? rewards,
    List<HadithModel>? hadiths,
  }) {
    return ContentState(
      series: series ?? this.series,
      books: books ?? this.books,
      contentFiles: contentFiles ?? this.contentFiles,
      rewards: rewards ?? this.rewards,
      hadiths: hadiths ?? this.hadiths,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentState &&
        listEquals(other.series, series) &&
        listEquals(other.books, books) &&
        mapEquals(other.contentFiles, contentFiles) &&
        listEquals(other.rewards, rewards) &&
        listEquals(other.hadiths, hadiths);
  }

  @override
  int get hashCode {
    return Object.hash(
      Object.hashAll(series),
      Object.hashAll(books),
      Object.hashAll(contentFiles.entries),
      Object.hashAll(rewards),
      Object.hashAll(hadiths),
    );
  }

  @override
  String toString() {
    return 'ContentState(series: ${series.length}, books: ${books.length}, '
        'contentFiles: ${contentFiles.length}, rewards: ${rewards.length}, '
        'hadiths: ${hadiths.length})';
  }
}
