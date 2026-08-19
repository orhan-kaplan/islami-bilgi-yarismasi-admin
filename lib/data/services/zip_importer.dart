import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/content_state.dart';
import '../models/book_model.dart';
import '../models/feedback_models.dart';
import '../models/game_config_models.dart';
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

/// Result of [ZipImporter.importAll]: quiz content plus optional sidecars.
class ZipImportBundle {
  final ContentState content;
  final List<ImportIssue> issues;
  final FeedbackContentState? feedback;
  final GameConfigState? gameConfig;

  /// Arşivde gerçekten bulunan üst seviye dosya adları (`series.json` gibi).
  ///
  /// Arşivde olmayan bir dosyanın dilimi mevcut state'ten korunur; bkz.
  /// [mergeImportedSlices].
  final Set<String> providedFiles;

  const ZipImportBundle({
    required this.content,
    required this.issues,
    this.feedback,
    this.gameConfig,
    this.providedFiles = const {},
  });
}

/// Import'u bloklayan bir sorun var mı.
///
/// ERROR bloklar, WARNING bloklamaz — ZIP export ve per-file auto-save ile
/// aynı kural.
bool hasBlockingErrors(List<ImportIssue> issues) {
  return issues.any((i) => i.severity == ImportIssueSeverity.error);
}

/// [imported] içinden yalnızca [providedFiles] ile gelen dilimleri [current]
/// üzerine yazar.
///
/// Import edilen dosya kümesi eksik olabilir (tek bir `books.json` seçmek ya da
/// yalnız birkaç dosya içeren bir ZIP). Tüm state'i [imported] ile değiştirmek,
/// verilmeyen dosyaları boşaltıyor ve auto-save bu boşluğu diske yazıyordu.
/// Verilmeyen dosyalar burada olduğu gibi korunur; boş ama *verilmiş* bir dosya
/// (`[]`) kendi dilimini temizler.
///
/// `contentFiles` anahtar bazında birleştirilir: import edilen anahtarlar
/// üzerine yazar, arşivde olmayan anahtarlar korunur.
ContentState mergeImportedSlices(
  ContentState current,
  ContentState imported,
  Set<String> providedFiles,
) {
  return ContentState(
    series: providedFiles.contains('series.json')
        ? imported.series
        : current.series,
    books:
        providedFiles.contains('books.json') ? imported.books : current.books,
    rewards: providedFiles.contains('rewards.json')
        ? imported.rewards
        : current.rewards,
    hadiths: providedFiles.contains('hadiths.json')
        ? imported.hadiths
        : current.hadiths,
    contentFiles: imported.contentFiles.isEmpty
        ? current.contentFiles
        : {...current.contentFiles, ...imported.contentFiles},
  );
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
  /// Returns a tuple of `(ContentState, List<ImportIssue>)`.
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
          fileMap[name] = file.content;
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

    // Arşivde dosya var ama hiçbiri tanınmıyorsa (örn. export ZIP'i fazladan bir
    // klasöre sarılmış), prefix normalizasyonu tutmamıştır. Bunu yalnızca
    // "dosya bulunamadı" uyarılarıyla geçmek, boş bir state'in diske yazılması
    // demek; import'u bloklamak gerekir.
    final recognizedAny = expectedFiles.any(fileMap.containsKey) ||
        fileMap.keys
            .any((k) => k.startsWith('content/') && k.endsWith('.json'));
    if (fileMap.isNotEmpty && !recognizedAny) {
      issues.add(ImportIssue(
        fileName: 'archive',
        message: 'No recognized content files found in the archive. Expected '
            '${expectedFiles.join(', ')} or content/*.json at the archive root '
            '(optionally under data/ or assets/data/). Found: '
            '${fileMap.keys.take(5).join(', ')}',
        severity: ImportIssueSeverity.error,
      ));
    }

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

  /// Imports quiz content plus optional sidecar `feedback.json` / `game_config.json`.
  ///
  /// Missing sidecars are warnings; existing in-memory extras must be left
  /// unchanged by the caller when the corresponding field is null.
  ZipImportBundle importAll(Uint8List zipBytes) {
    final (content, issues) = importZip(zipBytes);
    final extraIssues = List<ImportIssue>.from(issues);

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      return ZipImportBundle(content: content, issues: extraIssues);
    }

    final fileMap = <String, Uint8List>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      String name = file.name;
      if (name.startsWith('__MACOSX')) continue;
      if (name.startsWith('assets/data/')) {
        name = name.substring('assets/data/'.length);
      } else if (name.startsWith('data/')) {
        name = name.substring('data/'.length);
      }
      if (name.isNotEmpty) {
        fileMap[name] = file.content;
      }
    }

    FeedbackContentState? feedback;
    GameConfigState? gameConfig;

    if (fileMap.containsKey('feedback.json')) {
      try {
        final decoded = json.decode(utf8.decode(fileMap['feedback.json']!));
        feedback =
            FeedbackContentState.fromJson(decoded as Map<String, dynamic>);
      } catch (e) {
        extraIssues.add(ImportIssue(
          fileName: 'feedback.json',
          message: 'Parse error: $e',
          severity: ImportIssueSeverity.error,
        ));
      }
    } else {
      extraIssues.add(const ImportIssue(
        fileName: 'feedback.json',
        message: 'File not found in ZIP — existing feedback left unchanged',
        severity: ImportIssueSeverity.warning,
      ));
    }

    if (fileMap.containsKey('game_config.json')) {
      try {
        final decoded = json.decode(utf8.decode(fileMap['game_config.json']!));
        gameConfig = GameConfigState.fromJson(decoded as Map<String, dynamic>);
      } catch (e) {
        extraIssues.add(ImportIssue(
          fileName: 'game_config.json',
          message: 'Parse error: $e',
          severity: ImportIssueSeverity.error,
        ));
      }
    } else {
      extraIssues.add(const ImportIssue(
        fileName: 'game_config.json',
        message:
            'File not found in ZIP — existing game config left unchanged',
        severity: ImportIssueSeverity.warning,
      ));
    }

    return ZipImportBundle(
      content: content,
      issues: extraIssues,
      feedback: feedback,
      gameConfig: gameConfig,
      providedFiles: fileMap.keys.toSet(),
    );
  }

  /// Parses sidecar JSON files picked individually. Unknown names are ignored.
  ({
    FeedbackContentState? feedback,
    GameConfigState? gameConfig,
    List<ImportIssue> issues,
  }) parseExtras(Map<String, Uint8List> files) {
    final issues = <ImportIssue>[];
    FeedbackContentState? feedback;
    GameConfigState? gameConfig;

    final feedbackBytes = files['feedback.json'];
    if (feedbackBytes != null) {
      try {
        final decoded = json.decode(utf8.decode(feedbackBytes));
        feedback =
            FeedbackContentState.fromJson(decoded as Map<String, dynamic>);
      } catch (e) {
        issues.add(ImportIssue(
          fileName: 'feedback.json',
          message: 'Parse error: $e',
          severity: ImportIssueSeverity.error,
        ));
      }
    }

    final configBytes = files['game_config.json'];
    if (configBytes != null) {
      try {
        final decoded = json.decode(utf8.decode(configBytes));
        gameConfig = GameConfigState.fromJson(decoded as Map<String, dynamic>);
      } catch (e) {
        issues.add(ImportIssue(
          fileName: 'game_config.json',
          message: 'Parse error: $e',
          severity: ImportIssueSeverity.error,
        ));
      }
    }

    return (feedback: feedback, gameConfig: gameConfig, issues: issues);
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
  /// Returns a tuple of `(ContentState, List<ImportIssue>)`.
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
      } else if (fileName == 'feedback.json' || fileName == 'game_config.json') {
        // Sidecars are handled by parseExtras / importAll, not ContentState.
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
