import 'dart:convert';

/// Client-side asset category for file type validation.
enum AssetCategory {
  images,
  audio,
  lottie,
  icons,
}

/// Shared upload validation utility that centralizes file type validation logic.
///
/// Provides static methods for checking file extensions against allowed types
/// per asset category, and for validating Lottie JSON structure.
class UploadValidator {
  UploadValidator._();

  /// Allowed extensions per asset category (without leading dot).
  static const Map<AssetCategory, List<String>> _allowedExtensions = {
    AssetCategory.images: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
    AssetCategory.audio: ['mp3', 'wav', 'm4a', 'ogg'],
    AssetCategory.lottie: ['json'],
    AssetCategory.icons: ['png', 'jpg', 'jpeg', 'webp', 'ico'],
  };

  /// Returns whether [filename] has a valid extension for the given [category].
  ///
  /// The check is case-insensitive.
  static bool isValidExtension(String filename, AssetCategory category) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == filename.length - 1) {
      return false;
    }
    final ext = filename.substring(dotIndex + 1).toLowerCase();
    final allowed = _allowedExtensions[category];
    if (allowed == null) return false;
    return allowed.contains(ext);
  }

  /// Validates that [bytes] represent a valid Lottie JSON structure.
  ///
  /// A valid Lottie file must be a JSON object containing the fields:
  /// `v` (version), `layers` (array), `w` (width), and `h` (height).
  ///
  /// Returns `null` if valid, or an error message describing the issue.
  static String? validateLottieStructure(List<int> bytes) {
    try {
      final content = utf8.decode(bytes);
      final json = jsonDecode(content);
      if (json is! Map<String, dynamic>) {
        return 'File is not a valid JSON object.';
      }

      final missingFields = <String>[];
      if (!json.containsKey('v')) missingFields.add('v (version)');
      if (!json.containsKey('layers')) missingFields.add('layers');
      if (!json.containsKey('w')) missingFields.add('w (width)');
      if (!json.containsKey('h')) missingFields.add('h (height)');

      if (missingFields.isNotEmpty) {
        return 'Invalid Lottie file. Missing required fields:\n'
            '${missingFields.map((f) => '• $f').join('\n')}';
      }

      return null;
    } on FormatException {
      return 'File is not valid JSON.';
    } catch (e) {
      return 'Failed to parse file: $e';
    }
  }

  /// Returns the list of allowed extensions (without leading dot) for [category].
  static List<String> getAllowedExtensions(AssetCategory category) {
    return List.unmodifiable(_allowedExtensions[category] ?? []);
  }
}
