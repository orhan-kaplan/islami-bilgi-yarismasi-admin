// Feature: asset-management, Property 3: Content Change to File Path Mapping
// **Validates: Requirements 3.1**

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
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

  group('mergeSavedFileIntoBaseline', () {
    const seriesA = SeriesModel(
      id: 1,
      name: 'A',
      sortOrder: 1,
      isLocked: false,
      iconEmoji: 'A',
    );
    const seriesB = SeriesModel(
      id: 1,
      name: 'B',
      sortOrder: 1,
      isLocked: false,
      iconEmoji: 'B',
    );
    const bookA = BookModel(
      id: 1,
      title: 'Book A',
      description: 'Desc',
      assetImage: 'assets/images/a.png',
      bookOrder: 1,
      seriesId: 1,
      contentFile: 'book_1.json',
    );
    const bookB = BookModel(
      id: 1,
      title: 'Book B',
      description: 'Desc',
      assetImage: 'assets/images/b.png',
      bookOrder: 1,
      seriesId: 1,
      contentFile: 'book_1.json',
    );
    const levelA = LevelModel(
      id: 1,
      bookId: 1,
      categoryName: 'Cat',
      levelOrder: 1,
      title: 'Level A',
      unlockScore: 0,
      questions: [],
    );
    const levelB = LevelModel(
      id: 1,
      bookId: 1,
      categoryName: 'Cat',
      levelOrder: 1,
      title: 'Level B',
      unlockScore: 0,
      questions: [],
    );

    ContentState state({
      List<SeriesModel> series = const [seriesA],
      List<BookModel> books = const [bookA],
      Map<String, List<LevelModel>>? contentFiles,
      List<RewardModel> rewards = const [],
      List<HadithModel> hadiths = const [],
    }) {
      return ContentState(
        series: series,
        books: books,
        contentFiles: contentFiles ??
            const {
              'book_1.json': [levelA],
            },
        rewards: rewards,
        hadiths: hadiths,
      );
    }

    test('merging series.json keeps other slices from baseline', () {
      final baseline = state();
      final saved = state(series: const [seriesB], books: const [bookB]);

      final merged = mergeSavedFileIntoBaseline(
        baseline,
        saved,
        'data/series.json',
      );

      expect(merged.series, equals(const [seriesB]));
      expect(merged.books, equals(const [bookA]));
    });

    test('merging books.json keeps series from baseline', () {
      final baseline = state();
      final saved = state(series: const [seriesB], books: const [bookB]);

      final merged = mergeSavedFileIntoBaseline(
        baseline,
        saved,
        'data/books.json',
      );

      expect(merged.series, equals(const [seriesA]));
      expect(merged.books, equals(const [bookB]));
    });

    test('merging a content file updates only that key', () {
      final baseline = state(
        contentFiles: const {
          'book_1.json': [levelA],
          'book_2.json': [levelA],
        },
      );
      final saved = state(
        contentFiles: const {
          'book_1.json': [levelB],
          'book_2.json': [levelB],
        },
      );

      final merged = mergeSavedFileIntoBaseline(
        baseline,
        saved,
        'data/content/book_1.json',
      );

      expect(merged.contentFiles['book_1.json'], equals(const [levelB]));
      expect(merged.contentFiles['book_2.json'], equals(const [levelA]));
    });

    test('unknown api path leaves baseline unchanged', () {
      final baseline = state();
      final saved = state(series: const [seriesB]);

      final merged = mergeSavedFileIntoBaseline(
        baseline,
        saved,
        'data/unknown.json',
      );

      expect(merged, equals(baseline));
    });

    test('missing content file key is removed from baseline', () {
      final baseline = state(
        contentFiles: const {
          'book_1.json': [levelA],
          'book_2.json': [levelA],
        },
      );
      final saved = state(
        contentFiles: const {
          'book_1.json': [levelA],
        },
      );

      final merged = mergeSavedFileIntoBaseline(
        baseline,
        saved,
        'data/content/book_2.json',
      );

      expect(merged.contentFiles.containsKey('book_2.json'), isFalse);
      expect(merged.contentFiles['book_1.json'], equals(const [levelA]));
    });
  });
}
