import '../models/content_state.dart';

/// Types of content changes that map to specific JSON files.
enum ContentChangeType {
  series,
  books,
  rewards,
  hadiths,
  contentFile,
}

/// Returns the API_Path for a given content change type.
///
/// For [ContentChangeType.contentFile], the [contentFileKey] parameter
/// is required and represents the filename (e.g., `book_1.json`).
///
/// Examples:
/// - `series` → `data/series.json`
/// - `books` → `data/books.json`
/// - `rewards` → `data/rewards.json`
/// - `hadiths` → `data/hadiths.json`
/// - `contentFile` with key `book_1.json` → `data/content/book_1.json`
String getApiPathForChange(ContentChangeType type, {String? contentFileKey}) {
  switch (type) {
    case ContentChangeType.series:
      return 'data/series.json';
    case ContentChangeType.books:
      return 'data/books.json';
    case ContentChangeType.rewards:
      return 'data/rewards.json';
    case ContentChangeType.hadiths:
      return 'data/hadiths.json';
    case ContentChangeType.contentFile:
      if (contentFileKey == null || contentFileKey.isEmpty) {
        throw ArgumentError(
          'contentFileKey is required for ContentChangeType.contentFile',
        );
      }
      return 'data/content/$contentFileKey';
  }
}

/// Compares two [ContentState] instances and returns a list of API_Paths
/// for files that have changed between them.
///
/// Uses identity comparison (`!=`) on each top-level field.
/// For `contentFiles`, compares each key's value individually.
List<String> getChangedFiles(ContentState previous, ContentState current) {
  final changedPaths = <String>[];

  if (current.series != previous.series) {
    changedPaths.add(getApiPathForChange(ContentChangeType.series));
  }

  if (current.books != previous.books) {
    changedPaths.add(getApiPathForChange(ContentChangeType.books));
  }

  if (current.rewards != previous.rewards) {
    changedPaths.add(getApiPathForChange(ContentChangeType.rewards));
  }

  if (current.hadiths != previous.hadiths) {
    changedPaths.add(getApiPathForChange(ContentChangeType.hadiths));
  }

  // Compare contentFiles: check all keys in both maps
  final allKeys = <String>{
    ...previous.contentFiles.keys,
    ...current.contentFiles.keys,
  };

  for (final key in allKeys) {
    final previousValue = previous.contentFiles[key];
    final currentValue = current.contentFiles[key];
    if (previousValue != currentValue) {
      changedPaths.add(
        getApiPathForChange(ContentChangeType.contentFile, contentFileKey: key),
      );
    }
  }

  return changedPaths;
}
