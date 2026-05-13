import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/question_model.dart';
import '../../providers/content_providers.dart';
import '../../providers/history_providers.dart';
import '../../widgets/forms/book_form.dart';
import '../../widgets/forms/level_form.dart';
import '../../widgets/forms/question_form.dart';
import '../../widgets/forms/series_form.dart';
import 'content_explorer_screen.dart';

/// Right panel of the Content Explorer that shows a context-sensitive edit form
/// based on the currently selected item.
class EditPanel extends ConsumerWidget {
  const EditPanel({super.key, required this.selectedItem});

  /// The currently selected item, or null if nothing is selected.
  final SelectedItem? selectedItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = selectedItem;

    if (item == null) {
      return const Center(
        child: Text('Select an item to edit'),
      );
    }

    return switch (item) {
      SelectedSeries(:final seriesId) => _buildSeriesForm(ref, seriesId),
      SelectedBook(:final bookId) => _buildBookForm(ref, bookId),
      SelectedLevel(:final contentFile, :final levelId) =>
        _buildLevelForm(ref, contentFile, levelId),
      SelectedQuestion(:final contentFile, :final levelId, :final questionIndex) =>
        _buildQuestionForm(ref, contentFile, levelId, questionIndex),
      CreateSeries() => const SeriesForm(key: ValueKey('create_series')),
      CreateBook(:final seriesId) => BookForm(
          key: ValueKey('create_book_$seriesId'),
          seriesId: seriesId,
        ),
      CreateLevel(:final contentFile, :final bookId) => LevelForm(
          key: ValueKey('create_level_${contentFile}_$bookId'),
          contentFile: contentFile,
          bookId: bookId,
        ),
      CreateQuestion(:final contentFile, :final levelId) =>
        _buildCreateQuestionForm(ref, contentFile, levelId),
    };
  }

  Widget _buildSeriesForm(WidgetRef ref, int seriesId) {
    final state = ref.watch(contentStateProvider);
    final series = state.series.where((s) => s.id == seriesId).firstOrNull;
    return SeriesForm(
      key: ValueKey('series_$seriesId'),
      series: series,
    );
  }

  Widget _buildBookForm(WidgetRef ref, int bookId) {
    final state = ref.watch(contentStateProvider);
    final book = state.books.where((b) => b.id == bookId).firstOrNull;
    return BookForm(
      key: ValueKey('book_$bookId'),
      book: book,
    );
  }

  Widget _buildLevelForm(WidgetRef ref, String contentFile, int levelId) {
    final state = ref.watch(contentStateProvider);
    final levels = state.contentFiles[contentFile] ?? [];
    final level = levels.where((l) => l.id == levelId).firstOrNull;
    return LevelForm(
      key: ValueKey('level_${contentFile}_$levelId'),
      contentFile: contentFile,
      level: level,
    );
  }

  Widget _buildQuestionForm(
    WidgetRef ref,
    String contentFile,
    int levelId,
    int questionIndex,
  ) {
    final state = ref.watch(contentStateProvider);
    final levels = state.contentFiles[contentFile] ?? [];
    final level = levels.where((l) => l.id == levelId).firstOrNull;
    QuestionModel? question;
    if (level != null &&
        questionIndex >= 0 &&
        questionIndex < level.questions.length) {
      question = level.questions[questionIndex];
    }

    return QuestionForm(
      key: ValueKey('question_${contentFile}_${levelId}_$questionIndex'),
      question: question,
      contentFile: contentFile,
      levelId: levelId,
      questionIndex: questionIndex,
      onSave: (updatedQuestion) {
        // Push current state to history before applying the change.
        ref.read(historyProvider.notifier).pushState(ref.read(contentStateProvider));

        final notifier = ref.read(contentStateProvider.notifier);
        if (question != null) {
          notifier.updateQuestion(
              contentFile, levelId, questionIndex, updatedQuestion);
        } else {
          notifier.addQuestion(contentFile, levelId, updatedQuestion);
        }
      },
    );
  }

  Widget _buildCreateQuestionForm(
    WidgetRef ref,
    String contentFile,
    int levelId,
  ) {
    return QuestionForm(
      key: ValueKey('create_question_${contentFile}_$levelId'),
      question: null,
      onSave: (newQuestion) {
        // Push current state to history before applying the change.
        ref.read(historyProvider.notifier).pushState(ref.read(contentStateProvider));

        final notifier = ref.read(contentStateProvider.notifier);
        notifier.addQuestion(contentFile, levelId, newQuestion);
      },
    );
  }
}
