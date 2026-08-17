// Feature: asset-management, Property 5: Asset Reference Detection
// **Validates: Requirements 4.6, 12.1, 12.2**

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_reference_detector.dart';

import '../../helpers/content_generators.dart';

/// Pool of asset image paths for generating content with known paths.
const _assetPathPool = [
  'assets/images/book_1/level_1.webp',
  'assets/images/book_1/level_2.webp',
  'assets/images/book_2/level_1.webp',
  'assets/images/book_2/book_2.png',
  'assets/images/book_3/level_5.webp',
  'assets/images/rewards/book_1_reward.webp',
  'assets/images/rewards/book_2_reward.webp',
  'assets/images/rewards/book_3_reward.webp',
];

/// Paths guaranteed to NOT be in the pool above.
const _nonExistentPaths = [
  'assets/images/book_99/level_99.webp',
  'assets/images/nonexistent/image.png',
  'assets/images/book_0/cover.webp',
  'assets/icons/missing_icon.png',
];

/// Extension on [Any] to provide generators for asset reference tests.
extension AssetReferenceGenerators on Any {
  /// Generates a random asset path from the pool.
  Generator<String> get poolAssetPath => simple(
        generate: (random, size) {
          return _assetPathPool[random.nextInt(_assetPathPool.length)];
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a path guaranteed to not be in the pool.
  Generator<String> get nonExistentAssetPath => simple(
        generate: (random, size) {
          return _nonExistentPaths[random.nextInt(_nonExistentPaths.length)];
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a ContentState with asset paths drawn from the pool.
  Generator<ContentState> get contentStateWithPoolPaths => simple(
        generate: (random, size) {
          // Generate 1-3 books with paths from pool
          final bookCount = random.nextInt(3) + 1;
          final books = <BookModel>[];
          for (var i = 0; i < bookCount; i++) {
            books.add(BookModel(
              id: i + 1,
              title: 'Book ${i + 1}',
              description: 'Description ${i + 1}',
              assetImage:
                  _assetPathPool[random.nextInt(_assetPathPool.length)],
              bookOrder: i + 1,
              seriesId: 1,
              contentFile: 'book_${i + 1}.json',
            ));
          }

          // Generate 1-4 levels with nullable paths from pool
          final levelCount = random.nextInt(4) + 1;
          final levels = <LevelModel>[];
          for (var i = 0; i < levelCount; i++) {
            final hasImage = random.nextBool();
            levels.add(LevelModel(
              id: i + 1,
              bookId: (i % bookCount) + 1,
              categoryName: 'Category ${i + 1}',
              levelOrder: i + 1,
              title: 'Level ${i + 1}',
              unlockScore: 10 * (i + 1),
              assetImage: hasImage
                  ? _assetPathPool[random.nextInt(_assetPathPool.length)]
                  : null,
              questions: const [],
            ));
          }

          // Generate 0-3 rewards with paths from pool
          final rewardCount = random.nextInt(4);
          final rewards = <RewardModel>[];
          for (var i = 0; i < rewardCount; i++) {
            rewards.add(RewardModel(
              title: 'Reward ${i + 1}',
              description: 'Reward desc ${i + 1}',
              assetImage:
                  _assetPathPool[random.nextInt(_assetPathPool.length)],
              unlockBookId: i + 1,
            ));
          }

          // Group levels into content files
          final contentFiles = <String, List<LevelModel>>{};
          for (var i = 0; i < levels.length; i++) {
            final key = books[i % books.length].contentFile;
            contentFiles.putIfAbsent(key, () => []).add(levels[i]);
          }

          return ContentState(
            series: const [],
            books: books,
            contentFiles: contentFiles,
            rewards: rewards,
            hadiths: const [],
          );
        },
        shrink: (input) => const Iterable.empty(),
      );
}

void main() {
  group('Property 5: Asset Reference Detection', () {
    Glados2(any.contentStateWithPoolPaths, any.poolAssetPath,
            ExploreConfig(numRuns: 100))
        .test(
      'isReferenced returns true iff path appears in at least one book, level, or reward',
      (state, queryPath) {
        // Manually compute expected result
        final inBooks =
            state.books.any((b) => b.assetImage == queryPath);
        final inLevels = state.contentFiles.values
            .any((levels) => levels.any((l) => l.assetImage == queryPath));
        final inRewards =
            state.rewards.any((r) => r.assetImage == queryPath);
        final expectedReferenced = inBooks || inLevels || inRewards;

        // Call the function under test
        final result =
            AssetReferenceDetector.isReferenced(state, queryPath);

        expect(result, equals(expectedReferenced),
            reason:
                'isReferenced("$queryPath") should be $expectedReferenced. '
                'inBooks: $inBooks, inLevels: $inLevels, inRewards: $inRewards');
      },
    );

    Glados(any.contentStateWithPoolPaths, ExploreConfig(numRuns: 100)).test(
      'non-existent path is never reported as referenced',
      (state) {
        // Use a path that is guaranteed to not be in the pool
        const nonExistentPath = 'assets/images/book_999/nonexistent.webp';

        final result =
            AssetReferenceDetector.isReferenced(state, nonExistentPath);

        expect(result, isFalse,
            reason:
                'A path not present in any content should not be referenced');
      },
    );

    Glados2(any.contentStateWithPoolPaths, any.poolAssetPath,
            ExploreConfig(numRuns: 100))
        .test(
      'findReferences returns correct number of references',
      (state, queryPath) {
        // Manually count expected references
        var expectedCount = 0;
        for (final book in state.books) {
          if (book.assetImage == queryPath) expectedCount++;
        }
        for (final levels in state.contentFiles.values) {
          for (final level in levels) {
            if (level.assetImage == queryPath) expectedCount++;
          }
        }
        for (final reward in state.rewards) {
          if (reward.assetImage == queryPath) expectedCount++;
        }

        // Call the function under test
        final references =
            AssetReferenceDetector.findReferences(state, queryPath);

        expect(references.length, equals(expectedCount),
            reason:
                'findReferences("$queryPath") should return $expectedCount references, '
                'got ${references.length}');
      },
    );

    Glados(any.contentStateWithPoolPaths, ExploreConfig(numRuns: 100)).test(
      'findReferences returns empty list for non-existent path',
      (state) {
        const nonExistentPath = 'assets/images/book_999/nonexistent.webp';

        final references =
            AssetReferenceDetector.findReferences(state, nonExistentPath);

        expect(references, isEmpty,
            reason:
                'findReferences for a non-existent path should return empty list');
      },
    );

    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'isReferenced consistent with findReferences for generated ContentState',
      (state) {
        // Pick a path from the state if available, otherwise use non-existent
        final allPaths =
            AssetReferenceDetector.getAllReferencedPaths(state);
        final testPath = allPaths.isNotEmpty
            ? allPaths.first
            : 'assets/images/nonexistent.webp';

        final isRef =
            AssetReferenceDetector.isReferenced(state, testPath);
        final refs =
            AssetReferenceDetector.findReferences(state, testPath);

        // isReferenced should be true iff findReferences is non-empty
        expect(isRef, equals(refs.isNotEmpty),
            reason:
                'isReferenced and findReferences should be consistent: '
                'isReferenced=$isRef, findReferences.length=${refs.length}');
      },
    );

    // Unit tests for specific edge cases
    test('isReferenced returns true for path in book assetImage', () {
      const path = 'assets/images/book_1/book_1.png';
      const state = ContentState(
        series: [],
        books: [
          BookModel(
            id: 1,
            title: 'Test Book',
            description: 'Desc',
            assetImage: path,
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

      expect(AssetReferenceDetector.isReferenced(state, path), isTrue);
    });

    test('isReferenced returns true for path in level assetImage', () {
      const path = 'assets/images/book_1/level_1.webp';
      const state = ContentState(
        series: [],
        books: [],
        contentFiles: {
          'book_1.json': [
            LevelModel(
              id: 1,
              bookId: 1,
              categoryName: 'Cat',
              levelOrder: 1,
              title: 'Level 1',
              unlockScore: 10,
              assetImage: path,
              questions: [],
            ),
          ],
        },
        rewards: [],
        hadiths: [],
      );

      expect(AssetReferenceDetector.isReferenced(state, path), isTrue);
    });

    test('isReferenced returns true for path in reward assetImage', () {
      const path = 'assets/images/rewards/book_1_reward.webp';
      const state = ContentState(
        series: [],
        books: [],
        contentFiles: {},
        rewards: [
          RewardModel(
            title: 'Reward',
            description: 'Desc',
            assetImage: path,
            unlockBookId: 1,
          ),
        ],
        hadiths: [],
      );

      expect(AssetReferenceDetector.isReferenced(state, path), isTrue);
    });

    test('isReferenced returns false for unreferenced path', () {
      const path = 'assets/images/book_99/nonexistent.webp';
      const state = ContentState(
        series: [],
        books: [
          BookModel(
            id: 1,
            title: 'Test Book',
            description: 'Desc',
            assetImage: 'assets/images/book_1/book_1.png',
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

      expect(AssetReferenceDetector.isReferenced(state, path), isFalse);
    });

    test('isReferenced works with API_Path format (without assets/ prefix)',
        () {
      const appPath = 'assets/images/book_1/book_1.png';
      const apiPath = 'images/book_1/book_1.png';
      const state = ContentState(
        series: [],
        books: [
          BookModel(
            id: 1,
            title: 'Test Book',
            description: 'Desc',
            assetImage: appPath,
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

      // Query with API_Path format should still find the reference
      expect(AssetReferenceDetector.isReferenced(state, apiPath), isTrue);
    });

    test('findReferences returns correct reference types', () {
      const path = 'assets/images/book_1/level_1.webp';
      const state = ContentState(
        series: [],
        books: [
          BookModel(
            id: 1,
            title: 'Book 1',
            description: 'Desc',
            assetImage: path,
            bookOrder: 1,
            seriesId: 1,
            contentFile: 'book_1.json',
          ),
        ],
        contentFiles: {
          'book_1.json': [
            LevelModel(
              id: 1,
              bookId: 1,
              categoryName: 'Cat',
              levelOrder: 1,
              title: 'Level 1',
              unlockScore: 10,
              assetImage: path,
              questions: [],
            ),
          ],
        },
        rewards: [
          RewardModel(
            title: 'Reward',
            description: 'Desc',
            assetImage: path,
            unlockBookId: 1,
          ),
        ],
        hadiths: [],
      );

      final refs = AssetReferenceDetector.findReferences(state, path);
      expect(refs.length, equals(3));
      expect(
          refs.any((r) => r.type == AssetReferenceType.book), isTrue);
      expect(
          refs.any((r) => r.type == AssetReferenceType.level), isTrue);
      expect(
          refs.any((r) => r.type == AssetReferenceType.reward), isTrue);
    });

    test('empty ContentState has no references', () {
      final state = ContentState.empty();
      const path = 'assets/images/book_1/level_1.webp';

      expect(AssetReferenceDetector.isReferenced(state, path), isFalse);
      expect(AssetReferenceDetector.findReferences(state, path), isEmpty);
    });
  });
}
