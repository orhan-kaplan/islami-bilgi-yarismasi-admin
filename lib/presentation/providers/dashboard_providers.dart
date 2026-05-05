import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_providers.dart';

/// Derived provider that computes aggregate counts for the dashboard.
///
/// Returns a map with keys: 'series', 'books', 'levels', 'questions'.
/// - 'series' = state.series.length
/// - 'books' = state.books.length
/// - 'levels' = sum of all levels across all content files
/// - 'questions' = sum of all questions across all levels across all content files
final totalCountsProvider = Provider<Map<String, int>>((ref) {
  final state = ref.watch(contentStateProvider);

  final levelCount =
      state.contentFiles.values.fold<int>(0, (sum, levels) => sum + levels.length);

  final questionCount = state.contentFiles.values.fold<int>(
    0,
    (sum, levels) =>
        sum + levels.fold<int>(0, (lSum, level) => lSum + level.questions.length),
  );

  return {
    'series': state.series.length,
    'books': state.books.length,
    'levels': levelCount,
    'questions': questionCount,
  };
});
