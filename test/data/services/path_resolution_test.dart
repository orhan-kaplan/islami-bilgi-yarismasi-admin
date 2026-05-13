// Feature: asset-management, Property 6: Inline Picker Path Resolution
// **Validates: Requirements 8.3, 9.3, 10.3**

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_path_utils.dart';

/// Resolves the path for an inline image picker upload.
///
/// - If [currentAppPath] is set (non-null, non-empty), the upload overwrites
///   the existing file, so the same path is returned.
/// - If [currentAppPath] is null or empty, a new path is constructed from
///   [defaultDirectory] and the sanitized [filename], prefixed with `assets/`.
String resolvePickerPath({
  String? currentAppPath,
  required String defaultDirectory,
  required String filename,
}) {
  if (currentAppPath != null && currentAppPath.isNotEmpty) {
    return currentAppPath;
  }
  final sanitized = AssetPathUtils.sanitizeFilename(filename);
  final dir =
      defaultDirectory.endsWith('/') ? defaultDirectory : '$defaultDirectory/';
  return AssetPathUtils.apiPathToAppPath('$dir$sanitized');
}

/// Valid path segment characters (alphanumeric, underscore, hyphen, dot).
const _segmentChars = 'abcdefghijklmnopqrstuvwxyz0123456789_-';

/// Valid file extensions for image assets.
const _extensions = ['.webp', '.png', '.jpg', '.jpeg', '.gif'];

/// Characters that may appear in raw filenames (including some that need sanitizing).
const _filenameChars =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-. ';

/// Extension on [Any] to provide generators for path resolution testing.
extension PathResolutionGenerators on Any {
  /// Generates a valid existing App_Path (starts with `assets/`).
  Generator<String> get existingAppPath => simple(
        generate: (random, size) {
          // Generate 1-3 directory segments
          final numDirs = random.nextInt(3) + 1;
          final segments = <String>[];
          for (var i = 0; i < numDirs; i++) {
            final segLen = random.nextInt(10) + 1;
            final buffer = StringBuffer();
            for (var j = 0; j < segLen; j++) {
              buffer.write(_segmentChars[random.nextInt(_segmentChars.length)]);
            }
            segments.add(buffer.toString());
          }
          // Generate filename with extension
          final nameLen = random.nextInt(10) + 1;
          final nameBuffer = StringBuffer();
          for (var i = 0; i < nameLen; i++) {
            nameBuffer
                .write(_segmentChars[random.nextInt(_segmentChars.length)]);
          }
          final ext = _extensions[random.nextInt(_extensions.length)];
          segments.add('${nameBuffer.toString()}$ext');
          return 'assets/${segments.join('/')}';
        },
        shrink: (input) => [],
      );

  /// Generates a valid default directory (API_Path format, e.g. `images/rewards/`).
  Generator<String> get defaultDirectory => simple(
        generate: (random, size) {
          // Generate 1-2 directory segments
          final numDirs = random.nextInt(2) + 1;
          final segments = <String>[];
          for (var i = 0; i < numDirs; i++) {
            final segLen = random.nextInt(10) + 1;
            final buffer = StringBuffer();
            for (var j = 0; j < segLen; j++) {
              buffer.write(_segmentChars[random.nextInt(_segmentChars.length)]);
            }
            segments.add(buffer.toString());
          }
          // Always end with trailing slash
          return '${segments.join('/')}/';
        },
        shrink: (input) => [],
      );

  /// Generates a raw filename (may contain characters that need sanitizing).
  Generator<String> get rawFilename => simple(
        generate: (random, size) {
          final nameLen = random.nextInt(size.clamp(1, 15)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < nameLen; i++) {
            buffer
                .write(_filenameChars[random.nextInt(_filenameChars.length)]);
          }
          // Always add a valid extension
          final ext = _extensions[random.nextInt(_extensions.length)];
          buffer.write(ext);
          return buffer.toString();
        },
        shrink: (input) => [],
      );
}

void main() {
  group('Property 6: Inline Picker Path Resolution', () {
    Glados2(any.existingAppPath, any.rawFilename, ExploreConfig(numRuns: 100))
        .test(
      'existing App_Path → same path returned (overwrite)',
      (existingPath, filename) {
        final result = resolvePickerPath(
          currentAppPath: existingPath,
          defaultDirectory: 'images/rewards/',
          filename: filename,
        );

        expect(result, equals(existingPath),
            reason:
                'When currentAppPath is set ("$existingPath"), resolvePickerPath should return the same path');
      },
    );

    Glados2(any.defaultDirectory, any.rawFilename, ExploreConfig(numRuns: 100))
        .test(
      'no existing path → default directory + sanitized filename',
      (defaultDir, filename) {
        final result = resolvePickerPath(
          currentAppPath: null,
          defaultDirectory: defaultDir,
          filename: filename,
        );

        final sanitized = AssetPathUtils.sanitizeFilename(filename);
        final expectedDir =
            defaultDir.endsWith('/') ? defaultDir : '$defaultDir/';
        final expected = 'assets/$expectedDir$sanitized';

        expect(result, equals(expected),
            reason:
                'When no currentAppPath, result should be "assets/{defaultDir}/{sanitizedFilename}" '
                'but got "$result" for dir="$defaultDir", filename="$filename"');
      },
    );

    Glados2(any.defaultDirectory, any.rawFilename, ExploreConfig(numRuns: 100))
        .test(
      'empty string currentAppPath → treated as no path',
      (defaultDir, filename) {
        final result = resolvePickerPath(
          currentAppPath: '',
          defaultDirectory: defaultDir,
          filename: filename,
        );

        final sanitized = AssetPathUtils.sanitizeFilename(filename);
        final expectedDir =
            defaultDir.endsWith('/') ? defaultDir : '$defaultDir/';
        final expected = 'assets/$expectedDir$sanitized';

        expect(result, equals(expected),
            reason:
                'When currentAppPath is empty, result should be "assets/{defaultDir}/{sanitizedFilename}" '
                'but got "$result" for dir="$defaultDir", filename="$filename"');
      },
    );

    Glados2(any.defaultDirectory, any.rawFilename, ExploreConfig(numRuns: 100))
        .test(
      'result always starts with assets/ when no existing path',
      (defaultDir, filename) {
        final result = resolvePickerPath(
          currentAppPath: null,
          defaultDirectory: defaultDir,
          filename: filename,
        );

        expect(result.startsWith('assets/'), isTrue,
            reason:
                'Resolved path should always start with "assets/" but got "$result"');
      },
    );

    Glados(any.existingAppPath, ExploreConfig(numRuns: 100)).test(
      'result always starts with assets/ when existing path is set',
      (existingPath) {
        final result = resolvePickerPath(
          currentAppPath: existingPath,
          defaultDirectory: 'images/rewards/',
          filename: 'anything.png',
        );

        expect(result.startsWith('assets/'), isTrue,
            reason:
                'Resolved path should always start with "assets/" but got "$result"');
      },
    );
  });
}
