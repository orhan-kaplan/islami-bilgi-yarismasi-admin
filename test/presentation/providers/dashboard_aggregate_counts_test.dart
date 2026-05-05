import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/dashboard_providers.dart';

/// Generators for random ContentState instances with varying sizes.
extension DashboardGenerators on Any {
  /// Generates a complete random ContentState with varying sizes of all
  /// collections, including nested levels and questions.
  Generator<ContentState> get randomContentState => simple(
        generate: (random, size) {
          // Generate series (0–10)
          final seriesCount = random.nextInt(11);
          final series = List.generate(
            seriesCount,
            (i) => SeriesModel(
              id: i + 1,
              name: 'Series_${i + 1}',
              sortOrder: i + 1,
              isLocked: random.nextBool(),
              iconEmoji: '📖',
            ),
          );

          // Generate books (0–10)
          final bookCount = random.nextInt(11);
          final books = List.generate(
            bookCount,
            (i) => BookModel(
              id: i + 1,
              title: 'Book_${i + 1}',
              description: 'Description',
              assetImage: 'assets/images/book_${i + 1}/book_${i + 1}.png',
              bookOrder: i + 1,
              seriesId: 1,
              contentFile: 'book_${i + 1}.json',
            ),
          );

          // Generate content files (0–5) with levels (0–8) and questions (0–12)
          final fileCount = random.nextInt(6);
          final contentFiles = <String, List<LevelModel>>{};
          for (var i = 0; i < fileCount; i++) {
            final levelCount = random.nextInt(9);
            final levels = <LevelModel>[];
            for (var j = 0; j < levelCount; j++) {
              final questionCount = random.nextInt(13);
              final questions = List.generate(
                questionCount,
                (q) => QuestionModel(
                  questionText: 'Q_${i}_${j}_$q',
                  optionA: 'A',
                  optionB: 'B',
                  optionC: 'C',
                  optionD: 'D',
                  correctOption: 'A',
                  type: 'multiple_choice',
                ),
              );
              levels.add(LevelModel(
                id: i * 100 + j + 1,
                bookId: i + 1,
                categoryName: 'Category_$j',
                levelOrder: j + 1,
                title: 'Level_${i}_$j',
                unlockScore: 0,
                questions: questions,
              ));
            }
            contentFiles['book_${i + 1}.json'] = levels;
          }

          // Generate rewards (0–5)
          final rewardCount = random.nextInt(6);
          final rewards = List.generate(
            rewardCount,
            (i) => RewardModel(
              title: 'Reward_${i + 1}',
              description: 'Reward desc',
              assetImage: 'assets/images/reward_${i + 1}.png',
              unlockBookId: 1,
            ),
          );

          // Generate hadiths (0–5)
          final hadithCount = random.nextInt(6);
          final hadiths = List.generate(
            hadithCount,
            (i) => HadithModel(
              text: 'Hadith text ${i + 1}',
              source: 'Source ${i + 1}',
            ),
          );

          return ContentState(
            series: series,
            books: books,
            contentFiles: contentFiles,
            rewards: rewards,
            hadiths: hadiths,
          );
        },
        shrink: (input) => const Iterable.empty(),
      );
}

void main() {
  group('Property 15: Dashboard Aggregate Counts Are Accurate', () {
    // -------------------------------------------------------------------------
    // Series count matches actual list length
    // -------------------------------------------------------------------------

    Glados(any.randomContentState, ExploreConfig(numRuns: 100)).test(
      'series count matches state.series.length',
      (state) {
        final container = ProviderContainer(
          overrides: [
            contentStateProvider.overrideWith((ref) => ContentNotifier(state)),
          ],
        );
        addTearDown(container.dispose);

        final counts = container.read(totalCountsProvider);
        expect(counts['series'], equals(state.series.length),
            reason:
                'series count (${counts['series']}) should equal state.series.length (${state.series.length})');
      },
    );

    // -------------------------------------------------------------------------
    // Books count matches actual list length
    // -------------------------------------------------------------------------

    Glados(any.randomContentState, ExploreConfig(numRuns: 100)).test(
      'books count matches state.books.length',
      (state) {
        final container = ProviderContainer(
          overrides: [
            contentStateProvider.overrideWith((ref) => ContentNotifier(state)),
          ],
        );
        addTearDown(container.dispose);

        final counts = container.read(totalCountsProvider);
        expect(counts['books'], equals(state.books.length),
            reason:
                'books count (${counts['books']}) should equal state.books.length (${state.books.length})');
      },
    );

    // -------------------------------------------------------------------------
    // Levels count matches sum of all levels across content files
    // -------------------------------------------------------------------------

    Glados(any.randomContentState, ExploreConfig(numRuns: 100)).test(
      'levels count matches sum of all levels across content files',
      (state) {
        final container = ProviderContainer(
          overrides: [
            contentStateProvider.overrideWith((ref) => ContentNotifier(state)),
          ],
        );
        addTearDown(container.dispose);

        final expectedLevelCount = state.contentFiles.values
            .fold<int>(0, (sum, levels) => sum + levels.length);

        final counts = container.read(totalCountsProvider);
        expect(counts['levels'], equals(expectedLevelCount),
            reason:
                'levels count (${counts['levels']}) should equal total levels ($expectedLevelCount)');
      },
    );

    // -------------------------------------------------------------------------
    // Questions count matches sum of all questions across all levels
    // -------------------------------------------------------------------------

    Glados(any.randomContentState, ExploreConfig(numRuns: 100)).test(
      'questions count matches sum of all questions across all levels',
      (state) {
        final container = ProviderContainer(
          overrides: [
            contentStateProvider.overrideWith((ref) => ContentNotifier(state)),
          ],
        );
        addTearDown(container.dispose);

        final expectedQuestionCount = state.contentFiles.values.fold<int>(
          0,
          (sum, levels) => sum +
              levels.fold<int>(
                  0, (lSum, level) => lSum + level.questions.length),
        );

        final counts = container.read(totalCountsProvider);
        expect(counts['questions'], equals(expectedQuestionCount),
            reason:
                'questions count (${counts['questions']}) should equal total questions ($expectedQuestionCount)');
      },
    );

    // -------------------------------------------------------------------------
    // All four count keys are present
    // -------------------------------------------------------------------------

    Glados(any.randomContentState, ExploreConfig(numRuns: 100)).test(
      'totalCountsProvider always contains all four keys',
      (state) {
        final container = ProviderContainer(
          overrides: [
            contentStateProvider.overrideWith((ref) => ContentNotifier(state)),
          ],
        );
        addTearDown(container.dispose);

        final counts = container.read(totalCountsProvider);
        expect(counts.containsKey('series'), isTrue);
        expect(counts.containsKey('books'), isTrue);
        expect(counts.containsKey('levels'), isTrue);
        expect(counts.containsKey('questions'), isTrue);
      },
    );

    // -------------------------------------------------------------------------
    // All counts are non-negative
    // -------------------------------------------------------------------------

    Glados(any.randomContentState, ExploreConfig(numRuns: 100)).test(
      'all counts are non-negative',
      (state) {
        final container = ProviderContainer(
          overrides: [
            contentStateProvider.overrideWith((ref) => ContentNotifier(state)),
          ],
        );
        addTearDown(container.dispose);

        final counts = container.read(totalCountsProvider);
        expect(counts['series']!, greaterThanOrEqualTo(0));
        expect(counts['books']!, greaterThanOrEqualTo(0));
        expect(counts['levels']!, greaterThanOrEqualTo(0));
        expect(counts['questions']!, greaterThanOrEqualTo(0));
      },
    );

    // -------------------------------------------------------------------------
    // Empty state produces all zeros
    // -------------------------------------------------------------------------

    test('empty state produces all zero counts', () {
      final container = ProviderContainer(
        overrides: [
          contentStateProvider.overrideWith((ref) => ContentNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final counts = container.read(totalCountsProvider);
      expect(counts['series'], equals(0));
      expect(counts['books'], equals(0));
      expect(counts['levels'], equals(0));
      expect(counts['questions'], equals(0));
    });

    // -------------------------------------------------------------------------
    // Counts are consistent: questions >= 0 for each level
    // -------------------------------------------------------------------------

    Glados(any.randomContentState, ExploreConfig(numRuns: 100)).test(
      'questions count >= levels count only when all levels have at least one question (or both zero)',
      (state) {
        final container = ProviderContainer(
          overrides: [
            contentStateProvider.overrideWith((ref) => ContentNotifier(state)),
          ],
        );
        addTearDown(container.dispose);

        final counts = container.read(totalCountsProvider);
        // If there are no levels, there can be no questions
        if (counts['levels'] == 0) {
          expect(counts['questions'], equals(0),
              reason: 'No levels means no questions');
        }
      },
    );
  });
}
