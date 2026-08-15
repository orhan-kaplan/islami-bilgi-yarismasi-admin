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

/// Copies the slice of [saved] that corresponds to [apiPath] onto [baseline].
///
/// Auto-save writes one JSON file at a time. Replacing the entire baseline
/// with [saved] would mark unrelated unsaved files as clean.
///
/// Unknown [apiPath] values leave [baseline] unchanged. If a content file
/// key is absent from [saved], it is removed from the baseline map.
ContentState mergeSavedFileIntoBaseline(
  ContentState baseline,
  ContentState saved,
  String apiPath,
) {
  if (apiPath == getApiPathForChange(ContentChangeType.series)) {
    return baseline.copyWith(series: saved.series);
  }
  if (apiPath == getApiPathForChange(ContentChangeType.books)) {
    return baseline.copyWith(books: saved.books);
  }
  if (apiPath == getApiPathForChange(ContentChangeType.rewards)) {
    return baseline.copyWith(rewards: saved.rewards);
  }
  if (apiPath == getApiPathForChange(ContentChangeType.hadiths)) {
    return baseline.copyWith(hadiths: saved.hadiths);
  }

  const contentPrefix = 'data/content/';
  if (apiPath.startsWith(contentPrefix)) {
    final key = apiPath.substring(contentPrefix.length);
    if (key.isEmpty) return baseline;

    final updated = Map.of(baseline.contentFiles);
    if (saved.contentFiles.containsKey(key)) {
      updated[key] = saved.contentFiles[key]!;
    } else {
      updated.remove(key);
    }
    return baseline.copyWith(contentFiles: updated);
  }

  return baseline;
}
