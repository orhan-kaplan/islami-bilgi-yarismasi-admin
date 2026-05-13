import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/content_state.dart';
import 'content_providers.dart';

/// Parameter for duplicate check that includes the question text and
/// optional exclusion coordinates to avoid matching the current question.
class DuplicateCheckParams {
  final String questionText;
  final String? excludeContentFile;
  final int? excludeLevelId;
  final int? excludeQuestionIndex;

  const DuplicateCheckParams({
    required this.questionText,
    this.excludeContentFile,
    this.excludeLevelId,
    this.excludeQuestionIndex,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DuplicateCheckParams &&
        other.questionText == questionText &&
        other.excludeContentFile == excludeContentFile &&
        other.excludeLevelId == excludeLevelId &&
        other.excludeQuestionIndex == excludeQuestionIndex;
  }

  @override
  int get hashCode => Object.hash(
        questionText,
        excludeContentFile,
        excludeLevelId,
        excludeQuestionIndex,
      );
}

/// Normalizes text for comparison: trims, lowercases, collapses whitespace.
String _normalize(String text) {
  return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// Provider that checks for duplicate question text across all content.
/// Returns a list of location strings where duplicates exist.
final duplicateCheckProvider =
    Provider.family<List<String>, DuplicateCheckParams>((ref, params) {
  if (params.questionText.trim().isEmpty) return [];

  final state = ref.watch(contentStateProvider);
  final normalized = _normalize(params.questionText);
  if (normalized.isEmpty) return [];

  return _findDuplicates(
    normalized: normalized,
    state: state,
    excludeContentFile: params.excludeContentFile,
    excludeLevelId: params.excludeLevelId,
    excludeQuestionIndex: params.excludeQuestionIndex,
  );
});

/// Finds duplicate question locations in the content state.
List<String> _findDuplicates({
  required String normalized,
  required ContentState state,
  String? excludeContentFile,
  int? excludeLevelId,
  int? excludeQuestionIndex,
}) {
  final locations = <String>[];

  for (final entry in state.contentFiles.entries) {
    final contentFile = entry.key;
    final levels = entry.value;

    // Find the book for this content file
    final book =
        state.books.where((b) => b.contentFile == contentFile).firstOrNull;
    final bookTitle = book?.title ?? contentFile;

    for (final level in levels) {
      for (var i = 0; i < level.questions.length; i++) {
        // Skip the current question being edited
        if (contentFile == excludeContentFile &&
            level.id == excludeLevelId &&
            i == excludeQuestionIndex) {
          continue;
        }

        final q = level.questions[i];
        final qNormalized = _normalize(q.questionText);
        if (qNormalized == normalized) {
          locations.add('$bookTitle > ${level.title} > Soru ${i + 1}');
        }
      }
    }
  }

  return locations;
}
