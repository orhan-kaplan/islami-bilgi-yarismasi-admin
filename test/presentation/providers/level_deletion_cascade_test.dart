import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';

/// Generators for levels with random question counts.
extension LevelDeletionCascadeGenerators on Any {
  /// Generates a content file name and a list of 2–6 levels, each with
  /// 0–15 random questions.
  Generator<({String contentFile, List<LevelModel> levels, int targetIndex})>
      get contentFileWithLevels => simple(
            generate: (random, size) {
              final bookId = random.nextInt(100) + 1;
              final contentFile = 'book_$bookId.json';
              final levelCount = random.nextInt(5) + 2; // 2–6 levels

              final levels = List.generate(levelCount, (i) {
                final questionCount = random.nextInt(16); // 0–15 questions
                final questions = List.generate(
                  questionCount,
                  (q) => QuestionModel(
                    questionText: 'Q${i}_${q}_${random.nextInt(10000)}',
                    optionA: 'A',
                    optionB: 'B',
                    optionC: 'C',
                    optionD: 'D',
                    correctOption: 'A',
                    type: 'multiple_choice',
                  ),
                );
                return LevelModel(
                  id: i + 1,
                  bookId: bookId,
                  categoryName: 'Category_$i',
                  levelOrder: i + 1,
                  title: 'Level_${i + 1}',
                  unlockScore: i * 10,
                  questions: questions,
                );
              });

              // Pick a random level to delete
              final targetIndex = random.nextInt(levelCount);

              return (
                contentFile: contentFile,
                levels: levels,
                targetIndex: targetIndex,
              );
            },
            shrink: (input) => const Iterable.empty(),
          );

  /// Generates a single level with 1–20 questions for focused single-level tests.
  Generator<({String contentFile, LevelModel level})>
      get singleLevelWithQuestions => simple(
            generate: (random, size) {
              final bookId = random.nextInt(100) + 1;
              final contentFile = 'book_$bookId.json';
              final questionCount = random.nextInt(20) + 1; // 1–20 questions

              final questions = List.generate(
                questionCount,
                (q) => QuestionModel(
                  questionText: 'Question_${q}_${random.nextInt(10000)}',
                  optionA: 'Option A',
                  optionB: 'Option B',
                  optionC: 'Option C',
                  optionD: 'Option D',
                  correctOption: ['A', 'B', 'C', 'D'][random.nextInt(4)],
                  type: 'multiple_choice',
                ),
              );

              final level = LevelModel(
                id: 1,
                bookId: bookId,
                categoryName: 'Category',
                levelOrder: 1,
                title: 'Level_1',
                unlockScore: 0,
                questions: questions,
              );

              return (contentFile: contentFile, level: level);
            },
            shrink: (input) => const Iterable.empty(),
          );
}

void main() {
  group('Property 7: Level Deletion Cascades to Questions', () {
    // -------------------------------------------------------------------------
    // Deleting a level removes it and all its questions from state
    // -------------------------------------------------------------------------

    Glados(any.contentFileWithLevels, ExploreConfig(numRuns: 100)).test(
      'deleting a level removes it from the content file',
      (data) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: const [],
          contentFiles: {data.contentFile: data.levels},
          rewards: const [],
          hadiths: const [],
        ));

        final targetLevel = data.levels[data.targetIndex];
        notifier.deleteLevel(data.contentFile, targetLevel.id);

        final remainingLevels =
            notifier.state.contentFiles[data.contentFile] ?? [];

        expect(
          remainingLevels.any((l) => l.id == targetLevel.id),
          isFalse,
          reason: 'Deleted level ${targetLevel.id} should not exist in state',
        );
      },
    );

    Glados(any.contentFileWithLevels, ExploreConfig(numRuns: 100)).test(
      'deleting a level decreases level count by exactly 1',
      (data) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: const [],
          contentFiles: {data.contentFile: data.levels},
          rewards: const [],
          hadiths: const [],
        ));

        final initialLevelCount = data.levels.length;
        final targetLevel = data.levels[data.targetIndex];
        notifier.deleteLevel(data.contentFile, targetLevel.id);

        final remainingLevels =
            notifier.state.contentFiles[data.contentFile] ?? [];

        expect(remainingLevels.length, equals(initialLevelCount - 1),
            reason: 'Level count should decrease by exactly 1');
      },
    );

    Glados(any.contentFileWithLevels, ExploreConfig(numRuns: 100)).test(
      'deleting a level removes all its questions from total count',
      (data) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: const [],
          contentFiles: {data.contentFile: data.levels},
          rewards: const [],
          hadiths: const [],
        ));

        final totalQuestionsBefore = data.levels
            .fold<int>(0, (sum, level) => sum + level.questions.length);
        final targetLevel = data.levels[data.targetIndex];
        final deletedQuestionCount = targetLevel.questions.length;

        notifier.deleteLevel(data.contentFile, targetLevel.id);

        final remainingLevels =
            notifier.state.contentFiles[data.contentFile] ?? [];
        final totalQuestionsAfter = remainingLevels
            .fold<int>(0, (sum, level) => sum + level.questions.length);

        expect(
          totalQuestionsAfter,
          equals(totalQuestionsBefore - deletedQuestionCount),
          reason:
              'Total question count should decrease by $deletedQuestionCount '
              '(the number of questions in the deleted level)',
        );
      },
    );

    // -------------------------------------------------------------------------
    // Other levels and their questions remain untouched
    // -------------------------------------------------------------------------

    Glados(any.contentFileWithLevels, ExploreConfig(numRuns: 100)).test(
      'other levels and their questions remain unchanged after deletion',
      (data) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: const [],
          contentFiles: {data.contentFile: data.levels},
          rewards: const [],
          hadiths: const [],
        ));

        final targetLevel = data.levels[data.targetIndex];
        final expectedRemaining = data.levels
            .where((l) => l.id != targetLevel.id)
            .toList();

        notifier.deleteLevel(data.contentFile, targetLevel.id);

        final remainingLevels =
            notifier.state.contentFiles[data.contentFile] ?? [];

        // Each remaining level keeps its content. level_order is the one
        // exception: it is renumbered 1..N so the deletion does not leave a
        // gap that blocks the content file's save.
        for (final expected in expectedRemaining) {
          final actual = remainingLevels.firstWhere(
            (l) => l.id == expected.id,
            orElse: () => throw StateError(
                'Level ${expected.id} should still exist after deleting '
                'level ${targetLevel.id}'),
          );
          expect(actual, equals(expected.copyWith(levelOrder: actual.levelOrder)),
              reason: 'Level ${expected.id} should be unchanged');
          expect(actual.questions.length, equals(expected.questions.length),
              reason:
                  'Questions in level ${expected.id} should be unchanged');
        }

        // Relative order is preserved and the values stay sequential.
        final byOrder = [...remainingLevels]
          ..sort((a, b) => a.levelOrder.compareTo(b.levelOrder));
        expect(
          byOrder.map((l) => l.id).toList(),
          expectedRemaining.map((l) => l.id).toList(),
          reason: 'renumbering should not reshuffle the remaining levels',
        );
        expect(
          byOrder.map((l) => l.levelOrder).toList(),
          List.generate(byOrder.length, (i) => i + 1),
        );
      },
    );

    // -------------------------------------------------------------------------
    // Single level deletion: all questions are gone
    // -------------------------------------------------------------------------

    Glados(any.singleLevelWithQuestions, ExploreConfig(numRuns: 100)).test(
      'deleting the only level results in empty level list and zero questions',
      (data) {
        final notifier = ContentNotifier(ContentState(
          series: const [],
          books: const [],
          contentFiles: {data.contentFile: [data.level]},
          rewards: const [],
          hadiths: const [],
        ));

        expect(data.level.questions.isNotEmpty, isTrue,
            reason: 'Test precondition: level should have questions');

        notifier.deleteLevel(data.contentFile, data.level.id);

        final remainingLevels =
            notifier.state.contentFiles[data.contentFile] ?? [];

        expect(remainingLevels, isEmpty,
            reason: 'No levels should remain after deleting the only level');

        final totalQuestions = remainingLevels
            .fold<int>(0, (sum, level) => sum + level.questions.length);
        expect(totalQuestions, isZero,
            reason: 'Total question count should be zero');
      },
    );
  });
}
