// Feature: asset-management, Property 9: App_Path ↔ API_Path Round-Trip
// **Validates: Requirements 1.3, 3.1**

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group;
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_path_utils.dart';

/// Valid path segment characters (alphanumeric, underscore, hyphen, dot).
const _segmentChars = 'abcdefghijklmnopqrstuvwxyz0123456789_-.';

/// Valid file extensions for assets.
const _extensions = ['.webp', '.png', '.jpg', '.json', '.mp3', '.wav', '.gif'];

/// Extension on [Any] to provide generators for valid path segments.
extension AssetPathGenerators on Any {
  /// Generates a single valid path segment (folder or filename without extension).
  Generator<String> get pathSegment => simple(
        generate: (random, size) {
          final length = random.nextInt(size.clamp(1, 20)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            buffer.write(_segmentChars[random.nextInt(_segmentChars.length)]);
          }
          return buffer.toString();
        },
        shrink: (input) => [],
      );

  /// Generates a valid API_Path: one or more path segments joined by '/',
  /// ending with a filename that has a valid extension.
  /// Example: `images/book_1/cover.webp`
  Generator<String> get validApiPath => simple(
        generate: (random, size) {
          // Generate 1-3 directory segments
          final numDirs = random.nextInt(3) + 1;
          final segments = <String>[];
          for (var i = 0; i < numDirs; i++) {
            final segLen = random.nextInt(10) + 1;
            final buffer = StringBuffer();
            for (var j = 0; j < segLen; j++) {
              buffer
                  .write(_segmentChars[random.nextInt(_segmentChars.length)]);
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
          return segments.join('/');
        },
        shrink: (input) => [],
      );

  /// Generates a valid App_Path: `assets/` prefix + valid API_Path.
  /// Example: `assets/images/book_1/cover.webp`
  Generator<String> get validAppPath => simple(
        generate: (random, size) {
          // Reuse the API path generator logic
          final numDirs = random.nextInt(3) + 1;
          final segments = <String>[];
          for (var i = 0; i < numDirs; i++) {
            final segLen = random.nextInt(10) + 1;
            final buffer = StringBuffer();
            for (var j = 0; j < segLen; j++) {
              buffer
                  .write(_segmentChars[random.nextInt(_segmentChars.length)]);
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
}

void main() {
  group('Property 9: App_Path ↔ API_Path Round-Trip', () {
    Glados(any.validApiPath, ExploreConfig(numRuns: 100)).test(
      'apiPathToAppPath(appPathToApiPath(apiPath)) == apiPath for valid API_Paths',
      (apiPath) {
        // API_Path should not start with 'assets/'
        expect(apiPath.startsWith('assets/'), isFalse,
            reason: 'Generated API_Path should not start with assets/');

        // Round-trip: API_Path → App_Path → API_Path
        final appPath = AssetPathUtils.apiPathToAppPath(apiPath);
        final roundTripped = AssetPathUtils.appPathToApiPath(appPath);

        expect(roundTripped, equals(apiPath),
            reason:
                'appPathToApiPath(apiPathToAppPath("$apiPath")) should equal "$apiPath"');
      },
    );

    Glados(any.validAppPath, ExploreConfig(numRuns: 100)).test(
      'appPathToApiPath(apiPathToAppPath(appPath)) == appPath for valid App_Paths',
      (appPath) {
        // App_Path should start with 'assets/'
        expect(appPath.startsWith('assets/'), isTrue,
            reason: 'Generated App_Path should start with assets/');

        // Round-trip: App_Path → API_Path → App_Path
        final apiPath = AssetPathUtils.appPathToApiPath(appPath);
        final roundTripped = AssetPathUtils.apiPathToAppPath(apiPath);

        expect(roundTripped, equals(appPath),
            reason:
                'apiPathToAppPath(appPathToApiPath("$appPath")) should equal "$appPath"');
      },
    );
  });
}
