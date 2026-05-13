import '../services/content_validator.dart';

/// Determines whether a file is allowed to be saved based on validation issues.
///
/// Returns `true` if there are zero ERROR-level [ValidationIssue]s whose
/// [sourceFile] matches the given [apiPath] (after stripping the `data/` prefix
/// from [apiPath] to match the sourceFile format used by [ContentValidator]).
///
/// WARNING-level issues do NOT block save.
///
/// The [apiPath] is the server API path (e.g., `data/series.json`,
/// `data/content/book_1.json`). The [ValidationIssue.sourceFile] uses a
/// shorter format (e.g., `series.json`, `content/book_1.json`).
///
/// This function is pure and can be tested independently.
bool isSaveAllowedForFile(String apiPath, List<ValidationIssue> issues) {
  // Convert apiPath to the sourceFile format used by ValidationIssue.
  // apiPath format: "data/series.json" or "data/content/book_1.json"
  // sourceFile format: "series.json" or "content/book_1.json"
  final sourceFile = _apiPathToSourceFile(apiPath);

  // Check if there are any ERROR-level issues for this file
  final hasErrors = issues.any(
    (issue) =>
        issue.severity == ValidationSeverity.error &&
        issue.sourceFile == sourceFile,
  );

  return !hasErrors;
}

/// Converts an API path (e.g., `data/series.json`) to the sourceFile format
/// used by [ValidationIssue] (e.g., `series.json`).
String _apiPathToSourceFile(String apiPath) {
  const dataPrefix = 'data/';
  if (apiPath.startsWith(dataPrefix)) {
    return apiPath.substring(dataPrefix.length);
  }
  return apiPath;
}
