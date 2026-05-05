import '../models/book_model.dart';
import '../models/content_state.dart';

/// Result of a search/filter operation on the content tree.
///
/// Contains both the directly matching item IDs and the IDs of items
/// that should be visible (matching items + their ancestors).
class SearchResult {
  final Set<int> matchingSeriesIds;
  final Set<int> matchingBookIds;
  final Set<int> matchingLevelIds;
  final Set<int> matchingQuestionIndices; // encoded as levelId * 1000 + qi
  final Set<int> visibleSeriesIds;
  final Set<int> visibleBookIds;
  final Set<int> visibleLevelIds;

  const SearchResult({
    required this.matchingSeriesIds,
    required this.matchingBookIds,
    required this.matchingLevelIds,
    required this.matchingQuestionIndices,
    required this.visibleSeriesIds,
    required this.visibleBookIds,
    required this.visibleLevelIds,
  });
}

/// Pure-function service for Turkish-normalized text search across content.
///
/// Provides case-insensitive matching that handles Turkish-specific characters
/// (ı, İ, ö, Ö, ü, Ü, ş, Ş, ç, Ç, ğ, Ğ) by normalizing them to their
/// Latin equivalents before comparison.
class SearchEngine {
  /// Normalizes a string for Turkish-insensitive comparison.
  ///
  /// Performs Turkish-aware case-insensitive lowercasing:
  /// İ→i, I→ı, Ö→ö, Ü→ü, Ş→ş, Ç→ç, Ğ→ğ
  /// All other characters are lowercased using standard rules.
  /// Note: ı and i are kept as distinct characters (they are different
  /// letters in Turkish).
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      switch (char) {
        case 'İ':
          buffer.write('i');
        case 'I':
          buffer.write('ı');
        case 'Ö':
          buffer.write('ö');
        case 'Ü':
          buffer.write('ü');
        case 'Ş':
          buffer.write('ş');
        case 'Ç':
          buffer.write('ç');
        case 'Ğ':
          buffer.write('ğ');
        default:
          buffer.write(char.toLowerCase());
      }
    }
    return buffer.toString();
  }

  /// Returns IDs of matching items and their ancestors.
  ///
  /// Searches series names, book titles, level titles, and question text.
  /// When a child item matches, all its ancestors are included in the
  /// visible sets to maintain tree structure.
  static SearchResult filter(ContentState state, String query) {
    final normalizedQuery = normalize(query);

    final matchingSeriesIds = <int>{};
    final matchingBookIds = <int>{};
    final matchingLevelIds = <int>{};
    final matchingQuestionIndices = <int>{};
    final visibleSeriesIds = <int>{};
    final visibleBookIds = <int>{};
    final visibleLevelIds = <int>{};

    // Check series names
    for (final series in state.series) {
      if (normalize(series.name).contains(normalizedQuery)) {
        matchingSeriesIds.add(series.id);
      }
    }

    // Check book titles
    for (final book in state.books) {
      if (normalize(book.title).contains(normalizedQuery)) {
        matchingBookIds.add(book.id);
        visibleSeriesIds.add(book.seriesId);
      }
    }

    // Check levels and questions
    for (final entry in state.contentFiles.entries) {
      final contentFile = entry.key;
      final levels = entry.value;

      // Find the book that owns this content file
      final parentBook = _findBookByContentFile(state, contentFile);

      for (final level in levels) {
        // Check level title
        if (normalize(level.title).contains(normalizedQuery)) {
          matchingLevelIds.add(level.id);
          if (parentBook != null) {
            visibleBookIds.add(parentBook.id);
            visibleSeriesIds.add(parentBook.seriesId);
          }
        }

        // Check question text
        for (int qi = 0; qi < level.questions.length; qi++) {
          final question = level.questions[qi];
          if (normalize(question.questionText).contains(normalizedQuery)) {
            matchingQuestionIndices.add(level.id * 1000 + qi);
            visibleLevelIds.add(level.id);
            if (parentBook != null) {
              visibleBookIds.add(parentBook.id);
              visibleSeriesIds.add(parentBook.seriesId);
            }
          }
        }
      }
    }

    // All matching items are also visible
    visibleSeriesIds.addAll(matchingSeriesIds);
    visibleBookIds.addAll(matchingBookIds);
    visibleLevelIds.addAll(matchingLevelIds);

    return SearchResult(
      matchingSeriesIds: matchingSeriesIds,
      matchingBookIds: matchingBookIds,
      matchingLevelIds: matchingLevelIds,
      matchingQuestionIndices: matchingQuestionIndices,
      visibleSeriesIds: visibleSeriesIds,
      visibleBookIds: visibleBookIds,
      visibleLevelIds: visibleLevelIds,
    );
  }

  /// Finds the book whose contentFile matches the given filename.
  static BookModel? _findBookByContentFile(
    ContentState state,
    String contentFile,
  ) {
    for (final book in state.books) {
      if (book.contentFile == contentFile) {
        return book;
      }
    }
    return null;
  }
}
