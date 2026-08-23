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
  const EditPanel({
    super.key,
    required this.selectedItem,
    required this.onDeleted,
    required this.onCreated,
  });

  /// The currently selected item, or null if nothing is selected.
  final SelectedItem? selectedItem;

  /// Called after the selected item is deleted so the selection can be cleared.
  final VoidCallback onDeleted;

  /// Called after a create form saves, so the panel can switch to the new
  /// record's edit form. Create modunda kalmak, aynı ID ile ikinci bir
  /// "Create" tıklamasının kaydı bir kez daha eklemesine izin veriyordu.
  final void Function(SelectedItem item) onCreated;

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
        _buildQuestionForm(context, ref, contentFile, levelId, questionIndex),
      CreateSeries() => SeriesForm(
          key: const ValueKey('create_series'),
          onCreated: (id) => onCreated(SelectedSeries(seriesId: id)),
        ),
      CreateBook(:final seriesId) => BookForm(
          key: ValueKey('create_book_$seriesId'),
          seriesId: seriesId,
          onCreated: (id) => onCreated(SelectedBook(bookId: id)),
        ),
      CreateLevel(:final contentFile, :final bookId) => LevelForm(
          key: ValueKey('create_level_${contentFile}_$bookId'),
          contentFile: contentFile,
          bookId: bookId,
          onCreated: (id) => onCreated(
            SelectedLevel(contentFile: contentFile, levelId: id),
          ),
        ),
      CreateQuestion(:final contentFile, :final levelId) =>
        _buildCreateQuestionForm(context, ref, contentFile, levelId),
    };
  }

  /// Shown when the selected record disappears from the content state while
  /// its form is open (undo, reload from server). Aynı ValueKey'i koruyan form
  /// aksi halde silinen kaydın değerleriyle dolu bir "create" formuna dönüşüp
  /// kaydı geri ekleyebiliyordu.
  Widget _buildMissingNotice(String label) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'This $label is no longer available — it was deleted or the change '
          'was undone. Select another item to edit.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSeriesForm(WidgetRef ref, int seriesId) {
    final state = ref.watch(contentStateProvider);
    final series = state.series.where((s) => s.id == seriesId).firstOrNull;
    if (series == null) return _buildMissingNotice('series');
    return SeriesForm(
      key: ValueKey('series_$seriesId'),
      series: series,
      onDeleted: onDeleted,
    );
  }

  Widget _buildBookForm(WidgetRef ref, int bookId) {
    final state = ref.watch(contentStateProvider);
    final book = state.books.where((b) => b.id == bookId).firstOrNull;
    if (book == null) return _buildMissingNotice('book');
    return BookForm(
      key: ValueKey('book_$bookId'),
      book: book,
      onDeleted: onDeleted,
    );
  }

  Widget _buildLevelForm(WidgetRef ref, String contentFile, int levelId) {
    final state = ref.watch(contentStateProvider);
    final levels = state.contentFiles[contentFile] ?? [];
    final level = levels.where((l) => l.id == levelId).firstOrNull;
    if (level == null) return _buildMissingNotice('level');
    return LevelForm(
      key: ValueKey('level_${contentFile}_$levelId'),
      contentFile: contentFile,
      level: level,
      onDeleted: onDeleted,
    );
  }

  Widget _buildQuestionForm(
    BuildContext context,
    WidgetRef ref,
    String contentFile,
    int levelId,
    int questionIndex,
  ) {
    final state = ref.watch(contentStateProvider);
    final levels = state.contentFiles[contentFile] ?? [];
    final level = levels.where((l) => l.id == levelId).firstOrNull;
    if (level == null ||
        questionIndex < 0 ||
        questionIndex >= level.questions.length) {
      return _buildMissingNotice('question');
    }
    final QuestionModel question = level.questions[questionIndex];

    return QuestionForm(
      key: ValueKey('question_${contentFile}_${levelId}_$questionIndex'),
      question: question,
      contentFile: contentFile,
      levelId: levelId,
      questionIndex: questionIndex,
      onDelete: () {
        // Push current state to history before applying the delete.
        ref
            .read(historyProvider.notifier)
            .pushState(ref.read(contentStateProvider));
        ref
            .read(contentStateProvider.notifier)
            .deleteQuestion(contentFile, levelId, questionIndex);
        onDeleted();
      },
      onSave: (updatedQuestion) {
        // Push current state to history before applying the change.
        ref.read(historyProvider.notifier).pushState(ref.read(contentStateProvider));

        ref
            .read(contentStateProvider.notifier)
            .updateQuestion(contentFile, levelId, questionIndex, updatedQuestion);
        _notify(context, 'Question updated');
      },
    );
  }

  Widget _buildCreateQuestionForm(
    BuildContext context,
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
        _notify(context, 'Question created');

        final levels = ref.read(contentStateProvider).contentFiles[contentFile];
        final level = levels?.where((l) => l.id == levelId).firstOrNull;
        if (level != null && level.questions.isNotEmpty) {
          onCreated(SelectedQuestion(
            contentFile: contentFile,
            levelId: levelId,
            questionIndex: level.questions.length - 1,
          ));
        }
      },
    );
  }

  /// Soru formları kayıttan sonra hiçbir geri bildirim vermiyordu; diğer
  /// formların snackbar'ıyla aynı hale getirir.
  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
