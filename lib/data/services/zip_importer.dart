import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/content_state.dart';
import '../models/book_model.dart';
import '../models/hadith_model.dart';
import '../models/level_model.dart';
import '../models/reward_model.dart';
import '../models/series_model.dart';
import 'json_parser.dart';

/// Severity levels for import issues.
enum ImportIssueSeverity { error, warning }

/// Represents an issue encountered during import.
class ImportIssue {
  final String fileName;
  final String message;
  final ImportIssueSeverity severity;

  const ImportIssue({
    required this.fileName,
    required this.message,
    required this.severity,
  });

  @override
  String toString() =>
      'ImportIssue(${severity.name}: $fileName - $message)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImportIssue &&
        other.fileName == fileName &&
        other.message == message &&
        other.severity == severity;
  }

  @override
  int get hashCode => Object.hash(fileName, message, severity);
}

/// Orchestrates extraction and parsing of ZIP archives and individual files.
///
/// Delegates JSON parsing to [JsonParser] and reports issues for missing
/// or malformed files without aborting the entire import.
class ZipImporter {
  final JsonParser _parser;

  ZipImporter({JsonParser? parser}) : _parser = parser ?? JsonParser();

  /// Imports content from a ZIP archive.
  ///
  /// Extracts the ZIP, identifies recognized JSON files, and delegates
  /// parsing to [JsonParser]. Missing files are reported as warnings,
  /// parse errors are reported as errors.
  ///
  /// Returns a tuple of (ContentState with loaded data, List<ImportIssue>).
  (ContentState, List<ImportIssue>) importZip(Uint8List zipBytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (e) {
      return (
        ContentState.empty(),
        [
          ImportIssue(
            fileName: 'archive',
            message: 'The uploaded file is not a valid ZIP archive: $e',
            severity: ImportIssueSeverity.error,
          ),
        ],
      );
    }

    // Build a map of filename → file content bytes
    // Normalize paths: strip common prefixes like "data/", "assets/data/" so
    // that files are found regardless of how the ZIP was created.
    final Map<String, Uint8List> fileMap = {};
    for (final file in archive.files) {
      if (file.isFile) {
        String name = file.name;
        // Skip macOS resource fork files
        if (name.startsWith('__MACOSX')) continue;
        // Strip known prefixes to normalize paths
        if (name.startsWith('assets/data/')) {
          name = name.substring('assets/data/'.length);
        } else if (name.startsWith('data/')) {
          name = name.substring('data/'.length);
        }
        if (name.isNotEmpty) {
          fileMap[name] = file.content as Uint8List;
        }
      }
    }

    final issues = <ImportIssue>[];

    // Parse top-level files
    List<SeriesModel> series = [];
    List<BookModel> books = [];
    List<RewardModel> rewards = [];
    List<HadithModel> hadiths = [];
    final Map<String, List<LevelModel>> contentFiles = {};

    // Expected top-level files
    const expectedFiles = ['series.json', 'books.json', 'rewards.json', 'hadiths.json'];

    for (final expected in expectedFiles) {
      if (!fileMap.containsKey(expected)) {
        issues.add(ImportIssue(
          fileName: expected,
          message: 'File not found in ZIP archive',
          severity: ImportIssueSeverity.warning,
        ));
      }
    }

    // Parse series.json
    if (fileMap.containsKey('series.json')) {
      try {
        final jsonString = utf8.decode(fileMap['series.json']!);
        series = _parser.parseSeries(jsonString);
      } on FormatException catch (e) {
        issues.add(ImportIssue(
          fileName: 'series.json',
          message: 'Parse error: ${e.message}',
          severity: ImportIssueSeverity.error,
        ));
      }
    }

    // Parse books.json
    if (fileMap.containsKey('books.json')) {
      try {
        final jsonString = utf8.decode(fileMap['books.json']!);
        books = _parser.parseBooks(jsonString);
      } on FormatException catch (e) {
        issues.add(ImportIssue(
          fileName: 'books.json',
          message: 'Parse error: ${e.message}',
          severity: ImportIssueSeverity.error,
        ));
      }
    }

    // Parse rewards.json
    if (fileMap.containsKey('rewards.json')) {
      try {
        final jsonString = utf8.decode(fileMap['rewards.json']!);
        rewards = _parser.parseRewards(jsonString);
      } on FormatException catch (e) {
        issues.add(ImportIssue(
          fileName: 'rewards.json',
          message: 'Parse error: ${e.message}',
          severity: ImportIssueSeverity.error,
        ));
      }
    }

    // Parse hadiths.json
    if (fileMap.containsKey('hadiths.json')) {
      try {
        final jsonString = utf8.decode(fileMap['hadiths.json']!);
        hadiths = _parser.parseHadiths(jsonString);
      } on FormatException catch (e) {
        issues.add(ImportIssue(
          fileName: 'hadiths.json',
          message: 'Parse error: ${e.message}',
          severity: ImportIssueSeverity.error,
        ));
      }
    }

    // Parse content files (under content/ directory)
    for (final entry in fileMap.entries) {
      if (entry.key.startsWith('content/') && entry.key.endsWith('.json')) {
        // Extract just the filename without the content/ prefix
        final fileName = entry.key.substring('content/'.length);
        try {
          final jsonString = utf8.decode(entry.value);
          final levels = _parser.parseContentFile(jsonString);
          contentFiles[fileName] = levels;
        } on FormatException catch (e) {
          issues.add(ImportIssue(
            fileName: entry.key,
            message: 'Parse error: ${e.message}',
            severity: ImportIssueSeverity.error,
          ));
        }
      }
    }

    final state = ContentState(
      series: series,
      books: books,
      contentFiles: contentFiles,
      rewards: rewards,
      hadiths: hadiths,
    );

    return (state, issues);
  }

  /// Imports content from individual files by inferring roles from filenames.
  ///
  /// Recognized filenames:
  /// - `series.json` → parseSeries
  /// - `books.json` → parseBooks
  /// - `rewards.json` → parseRewards
  /// - `hadiths.json` → parseHadiths
  /// - Files matching `book_*.json` pattern → parseContentFile
  ///
  /// Unrecognized filenames are reported as warnings.
  ///
  /// Returns a tuple of (ContentState with loaded data, List<ImportIssue>).
  (ContentState, List<ImportIssue>) importFiles(Map<String, Uint8List> files) {
    final issues = <ImportIssue>[];

    List<SeriesModel> series = [];
    List<BookModel> books = [];
    List<RewardModel> rewards = [];
    List<HadithModel> hadiths = [];
    final Map<String, List<LevelModel>> contentFiles = {};

    for (final entry in files.entries) {
      final fileName = entry.key;
      final bytes = entry.value;

      if (fileName == 'series.json') {
        try {
          final jsonString = utf8.decode(bytes);
          series = _parser.parseSeries(jsonString);
        } on FormatException catch (e) {
          issues.add(ImportIssue(
            fileName: fileName,
            message: 'Parse error: ${e.message}',
            severity: ImportIssueSeverity.error,
          ));
        }
      } else if (fileName == 'books.json') {
        try {
          final jsonString = utf8.decode(bytes);
          books = _parser.parseBooks(jsonString);
        } on FormatException catch (e) {
          issues.add(ImportIssue(
            fileName: fileName,
            message: 'Parse error: ${e.message}',
            severity: ImportIssueSeverity.error,
          ));
        }
      } else if (fileName == 'rewards.json') {
        try {
          final jsonString = utf8.decode(bytes);
          rewards = _parser.parseRewards(jsonString);
        } on FormatException catch (e) {
          issues.add(ImportIssue(
            fileName: fileName,
            message: 'Parse error: ${e.message}',
            severity: ImportIssueSeverity.error,
          ));
        }
      } else if (fileName == 'hadiths.json') {
        try {
          final jsonString = utf8.decode(bytes);
          hadiths = _parser.parseHadiths(jsonString);
        } on FormatException catch (e) {
          issues.add(ImportIssue(
            fileName: fileName,
            message: 'Parse error: ${e.message}',
            severity: ImportIssueSeverity.error,
          ));
        }
      } else if (RegExp(r'^book_.*\.json$').hasMatch(fileName)) {
        try {
          final jsonString = utf8.decode(bytes);
          final levels = _parser.parseContentFile(jsonString);
          contentFiles[fileName] = levels;
        } on FormatException catch (e) {
          issues.add(ImportIssue(
            fileName: fileName,
            message: 'Parse error: ${e.message}',
            severity: ImportIssueSeverity.error,
          ));
        }
      } else {
        issues.add(ImportIssue(
          fileName: fileName,
          message: 'Unrecognized filename, skipping',
          severity: ImportIssueSeverity.warning,
        ));
      }
    }

    final state = ContentState(
      series: series,
      books: books,
      contentFiles: contentFiles,
      rewards: rewards,
      hadiths: hadiths,
    );

    return (state, issues);
  }
}
