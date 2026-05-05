import 'dart:convert';

import '../models/book_model.dart';
import '../models/hadith_model.dart';
import '../models/level_model.dart';
import '../models/reward_model.dart';
import '../models/series_model.dart';

/// Stateless service that converts data models back to JSON strings
/// matching the main app's expected format.
///
/// All methods produce UTF-8 encoded, pretty-printed JSON with 2-space
/// indentation. Snake_case keys are handled by each model's `toJson` method.
class JsonSerializer {
  static const _encoder = JsonEncoder.withIndent('  ');

  /// Converts a list of [SeriesModel] to a pretty-printed JSON array string.
  String serializeSeries(List<SeriesModel> series) {
    return _encoder.convert(series.map((s) => s.toJson()).toList());
  }

  /// Converts a list of [BookModel] to a pretty-printed JSON array string.
  String serializeBooks(List<BookModel> books) {
    return _encoder.convert(books.map((b) => b.toJson()).toList());
  }

  /// Converts a list of [LevelModel] to a pretty-printed JSON object string
  /// with the structure `{"levels": [...]}`.
  String serializeContentFile(List<LevelModel> levels) {
    return _encoder.convert({
      'levels': levels.map((l) => l.toJson()).toList(),
    });
  }

  /// Converts a list of [RewardModel] to a pretty-printed JSON array string.
  String serializeRewards(List<RewardModel> rewards) {
    return _encoder.convert(rewards.map((r) => r.toJson()).toList());
  }

  /// Converts a list of [HadithModel] to a pretty-printed JSON array string.
  String serializeHadiths(List<HadithModel> hadiths) {
    return _encoder.convert(hadiths.map((h) => h.toJson()).toList());
  }
}
