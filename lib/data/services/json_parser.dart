import 'dart:convert';

import '../models/book_model.dart';
import '../models/hadith_model.dart';
import '../models/level_model.dart';
import '../models/reward_model.dart';
import '../models/series_model.dart';

/// Stateless service that converts raw JSON strings into data models.
///
/// Each method throws [FormatException] with a descriptive message
/// when the input is not valid JSON or does not match the expected structure.
class JsonParser {
  /// Parses a JSON array string into a list of [SeriesModel].
  ///
  /// Expects a JSON array of series objects.
  /// Throws [FormatException] on invalid JSON.
  List<SeriesModel> parseSeries(String jsonString) {
    final dynamic decoded;
    try {
      decoded = json.decode(jsonString);
    } on FormatException catch (e) {
      throw FormatException(
        'Invalid JSON in series data: ${e.message}',
      );
    }

    if (decoded is! List) {
      throw const FormatException(
        'Invalid series data: expected a JSON array',
      );
    }

    return decoded
        .map((item) => SeriesModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Parses a JSON array string into a list of [BookModel].
  ///
  /// Expects a JSON array of book objects.
  /// Throws [FormatException] on invalid JSON.
  List<BookModel> parseBooks(String jsonString) {
    final dynamic decoded;
    try {
      decoded = json.decode(jsonString);
    } on FormatException catch (e) {
      throw FormatException(
        'Invalid JSON in books data: ${e.message}',
      );
    }

    if (decoded is! List) {
      throw const FormatException(
        'Invalid books data: expected a JSON array',
      );
    }

    return decoded
        .map((item) => BookModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Parses a JSON object string with a `levels` key into a list of [LevelModel].
  ///
  /// Expects `{"levels": [...]}` format (not a plain array).
  /// Throws [FormatException] on invalid JSON or missing `levels` key.
  List<LevelModel> parseContentFile(String jsonString) {
    final dynamic decoded;
    try {
      decoded = json.decode(jsonString);
    } on FormatException catch (e) {
      throw FormatException(
        'Invalid JSON in content file: ${e.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid content file: expected a JSON object with a "levels" key',
      );
    }

    final levels = decoded['levels'];
    if (levels is! List) {
      throw const FormatException(
        'Invalid content file: missing or invalid "levels" key',
      );
    }

    return levels
        .map((item) => LevelModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Parses a JSON array string into a list of [RewardModel].
  ///
  /// Expects a JSON array of reward objects.
  /// Throws [FormatException] on invalid JSON.
  List<RewardModel> parseRewards(String jsonString) {
    final dynamic decoded;
    try {
      decoded = json.decode(jsonString);
    } on FormatException catch (e) {
      throw FormatException(
        'Invalid JSON in rewards data: ${e.message}',
      );
    }

    if (decoded is! List) {
      throw const FormatException(
        'Invalid rewards data: expected a JSON array',
      );
    }

    return decoded
        .map((item) => RewardModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Parses a JSON array string into a list of [HadithModel].
  ///
  /// Expects a JSON array of hadith objects.
  /// Throws [FormatException] on invalid JSON.
  List<HadithModel> parseHadiths(String jsonString) {
    final dynamic decoded;
    try {
      decoded = json.decode(jsonString);
    } on FormatException catch (e) {
      throw FormatException(
        'Invalid JSON in hadiths data: ${e.message}',
      );
    }

    if (decoded is! List) {
      throw const FormatException(
        'Invalid hadiths data: expected a JSON array',
      );
    }

    return decoded
        .map((item) => HadithModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
