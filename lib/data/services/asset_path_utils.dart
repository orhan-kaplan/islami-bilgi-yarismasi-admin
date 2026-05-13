/// Utility class for converting between App_Path and API_Path formats,
/// and for sanitizing filenames for safe filesystem use.
///
/// Path conventions:
/// - **App_Path**: Asset references stored in JSON content fields
///   (e.g., `assets/images/book_1/cover.webp`)
/// - **API_Path**: Paths used in Asset Server API calls, relative to assets root
///   (e.g., `images/book_1/cover.webp`)
class AssetPathUtils {
  static const String _assetsPrefix = 'assets/';

  /// Convert App_Path to API_Path by stripping the `assets/` prefix.
  ///
  /// Example: `assets/images/book_1/cover.webp` → `images/book_1/cover.webp`
  ///
  /// If the path doesn't start with `assets/`, it is returned unchanged
  /// (assumed to already be an API_Path).
  static String appPathToApiPath(String appPath) {
    if (appPath.startsWith(_assetsPrefix)) {
      return appPath.substring(_assetsPrefix.length);
    }
    return appPath;
  }

  /// Convert API_Path to App_Path by prepending the `assets/` prefix.
  ///
  /// Example: `images/book_1/cover.webp` → `assets/images/book_1/cover.webp`
  ///
  /// If the path already starts with `assets/`, it is returned unchanged
  /// (assumed to already be an App_Path).
  static String apiPathToAppPath(String apiPath) {
    if (apiPath.startsWith(_assetsPrefix)) {
      return apiPath;
    }
    return '$_assetsPrefix$apiPath';
  }

  /// Validate that a path is a valid App_Path (starts with `assets/`).
  static bool isValidAppPath(String path) {
    return path.startsWith(_assetsPrefix);
  }

  /// Sanitize a filename for safe filesystem use.
  ///
  /// - Removes characters unsafe for filesystems: `/ \ : * ? " < > |`
  /// - Replaces spaces with underscores
  /// - Converts to lowercase
  /// - Removes leading dots (hidden files)
  /// - Returns `'unnamed'` if the result is empty after sanitization
  static String sanitizeFilename(String filename) {
    // Convert to lowercase
    var sanitized = filename.toLowerCase();

    // Remove unsafe characters: / \ : * ? " < > |
    sanitized = sanitized.replaceAll(RegExp(r'[/\\:*?"<>|]'), '');

    // Replace spaces with underscores
    sanitized = sanitized.replaceAll(' ', '_');

    // Remove leading dots (hidden files)
    sanitized = sanitized.replaceFirst(RegExp(r'^\.+'), '');

    // If empty after sanitization, return a default name
    if (sanitized.isEmpty) {
      return 'unnamed';
    }

    return sanitized;
  }
}
