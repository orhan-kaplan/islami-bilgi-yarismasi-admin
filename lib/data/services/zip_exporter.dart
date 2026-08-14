import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/content_state.dart';
import '../models/feedback_models.dart';
import '../models/game_config_models.dart';
import 'content_validator.dart';
import 'json_serializer.dart';

/// Exception thrown when export is blocked due to validation errors.
///
/// Contains the list of ERROR-level [ValidationIssue]s that prevented export.
/// WARNING-level issues do NOT block export.
class ValidationBlockedExportException implements Exception {
  /// The ERROR-level validation issues that blocked the export.
  final List<ValidationIssue> errors;

  const ValidationBlockedExportException(this.errors);

  @override
  String toString() =>
      'ValidationBlockedExportException: ${errors.length} error(s) blocked export';
}

/// Orchestrates serialization and ZIP packaging of content state.
///
/// Before producing a ZIP archive, the exporter runs validation and
/// refuses to export if any ERROR-level issues exist. WARNING-level
/// issues do not block export.
class ZipExporter {
  final ContentValidator _validator;
  final JsonSerializer _serializer;

  ZipExporter({
    ContentValidator? validator,
    JsonSerializer? serializer,
  })  : _validator = validator ?? ContentValidator(),
        _serializer = serializer ?? JsonSerializer();

  /// Serializes all content and packages it into a ZIP archive.
  ///
  /// First validates the [state]. If any ERROR-level issues exist,
  /// throws [ValidationBlockedExportException] with those errors.
  ///
  /// If validation passes (no errors, warnings are OK), serializes
  /// all content via [JsonSerializer] and packages into a ZIP with
  /// the following structure:
  /// ```
  /// ├── series.json
  /// ├── books.json
  /// ├── rewards.json
  /// ├── hadiths.json
  /// └── content/
  ///     ├── {book.contentFile}
  ///     └── ...
  /// ```
  ///
  /// Returns the ZIP archive as [Uint8List].
  /// Optional [feedback] / [gameConfig] are added as sidecar JSON files.
  /// Omit them to keep the original 4-file (+ content/) ZIP shape.
  Uint8List exportZip(
    ContentState state, {
    FeedbackContentState? feedback,
    GameConfigState? gameConfig,
  }) {
    // Run validation
    final issues = _validator.validateAll(state);
    final errors = issues
        .where((i) => i.severity == ValidationSeverity.error)
        .toList();

    if (errors.isNotEmpty) {
      throw ValidationBlockedExportException(errors);
    }

    // Serialize all content
    final seriesJson = _serializer.serializeSeries(state.series);
    final booksJson = _serializer.serializeBooks(state.books);
    final rewardsJson = _serializer.serializeRewards(state.rewards);
    final hadithsJson = _serializer.serializeHadiths(state.hadiths);

    // Build ZIP archive
    final archive = Archive();

    archive.add(ArchiveFile.string('series.json', seriesJson));
    archive.add(ArchiveFile.string('books.json', booksJson));
    archive.add(ArchiveFile.string('rewards.json', rewardsJson));
    archive.add(ArchiveFile.string('hadiths.json', hadithsJson));

    // Add content files
    for (final entry in state.contentFiles.entries) {
      final contentJson = _serializer.serializeContentFile(entry.value);
      archive.add(ArchiveFile.string('content/${entry.key}', contentJson));
    }

    if (feedback != null) {
      archive.add(ArchiveFile.string(
        'feedback.json',
        const JsonEncoder.withIndent('  ').convert(feedback.toJson()),
      ));
    }
    if (gameConfig != null) {
      archive.add(ArchiveFile.string(
        'game_config.json',
        const JsonEncoder.withIndent('  ').convert(gameConfig.toJson()),
      ));
    }

    // Encode to ZIP bytes
    final zipBytes = ZipEncoder().encodeBytes(archive);
    return Uint8List.fromList(zipBytes);
  }
}
