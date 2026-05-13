// Feature: asset-management, Property 3: Content Change to File Path Mapping
// **Validates: Requirements 3.1**

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/services/content_file_mapping.dart';

/// Characters allowed in content file keys (alphanumeric, underscore, hyphen, dot).
const _keyChars = 'abcdefghijklmnopqrstuvwxyz0123456789_-';

/// Extension on [Any] to provide generators for content file keys.
extension ContentFileKeyGenerators on Any {
  /// Generates a valid content file key like `book_1.json`, `book_23.json`, etc.
  Generator<String> get contentFileKey => simple(
        generate: (random, size) {
          final nameLen = random.nextInt(size.clamp(1, 15)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < nameLen; i++) {
            buffer.write(_keyChars[random.nextInt(_keyChars.length)]);
          }
          buffer.write('.json');
          return buffer.toString();
        },
        shrink: (input) => [],
      );
}

void main() {
  group('Property 3: Content Change to File Path Mapping', () {
    test('series maps to data/series.json', () {
      final result = getApiPathForChange(ContentChangeType.series);
      expect(result, equals('data/series.json'));
    });

    test('books maps to data/books.json', () {
      final result = getApiPathForChange(ContentChangeType.books);
      expect(result, equals('data/books.json'));
    });

    test('rewards maps to data/rewards.json', () {
      final result = getApiPathForChange(ContentChangeType.rewards);
      expect(result, equals('data/rewards.json'));
    });

    test('hadiths maps to data/hadiths.json', () {
      final result = getApiPathForChange(ContentChangeType.hadiths);
      expect(result, equals('data/hadiths.json'));
    });

    Glados(any.contentFileKey, ExploreConfig(numRuns: 100)).test(
      'contentFile with random key maps to data/content/{key}',
      (key) {
        final result = getApiPathForChange(
          ContentChangeType.contentFile,
          contentFileKey: key,
        );
        expect(result, equals('data/content/$key'),
            reason:
                'getApiPathForChange(contentFile, key: "$key") should return "data/content/$key"');
      },
    );

    test('contentFile without key throws ArgumentError', () {
      expect(
        () => getApiPathForChange(ContentChangeType.contentFile),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('contentFile with empty key throws ArgumentError', () {
      expect(
        () => getApiPathForChange(
          ContentChangeType.contentFile,
          contentFileKey: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('all fixed enum values produce correct paths', () {
      final expectedMappings = {
        ContentChangeType.series: 'data/series.json',
        ContentChangeType.books: 'data/books.json',
        ContentChangeType.rewards: 'data/rewards.json',
        ContentChangeType.hadiths: 'data/hadiths.json',
      };

      for (final entry in expectedMappings.entries) {
        expect(
          getApiPathForChange(entry.key),
          equals(entry.value),
          reason: '${entry.key} should map to ${entry.value}',
        );
      }
    });
  });
}
