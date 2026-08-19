import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/question_model.dart';
import '../../providers/duplicate_check_provider.dart';
import '../preview/question_preview_dialog.dart';
import '../shared/confirm_dialog.dart';
import 'matching_form.dart';
import 'multiple_choice_form.dart';
import 'sorting_form.dart';
import 'true_false_form.dart';

/// Delegates to type-specific question form based on selected type.
///
/// Has a type selector dropdown (multiple_choice, true_false, matching, sorting).
/// When type changes, resets the form appropriately.
class QuestionForm extends ConsumerStatefulWidget {
  const QuestionForm({
    super.key,
    this.question,
    required this.onSave,
    this.contentFile,
    this.levelId,
    this.questionIndex,
    this.onDelete,
  });

  /// The question to edit, or null to create a new one.
  final QuestionModel? question;

  /// Callback when the form is saved with a valid question.
  final ValueChanged<QuestionModel> onSave;

  /// Callback when the question is deleted, or null when deletion is not
  /// available (create mode).
  final VoidCallback? onDelete;

  /// Content file of the current question (for duplicate exclusion).
  final String? contentFile;

  /// Level ID of the current question (for duplicate exclusion).
  final int? levelId;

  /// Index of the current question (for duplicate exclusion).
  final int? questionIndex;

  @override
  ConsumerState<QuestionForm> createState() => _QuestionFormState();
}

class _QuestionFormState extends ConsumerState<QuestionForm> {
  late String _selectedType;
  String _currentQuestionText = '';

  static const _typeLabels = {
    'multiple_choice': 'Multiple Choice',
    'true_false': 'True / False',
    'matching': 'Matching',
    'sorting': 'Sorting',
  };

  @override
  void initState() {
    super.initState();
    _selectedType = widget.question?.type ?? 'multiple_choice';
    _currentQuestionText = widget.question?.questionText ?? '';
  }

  void _onQuestionTextChanged(String text) {
    if (text != _currentQuestionText) {
      setState(() => _currentQuestionText = text);
    }
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete Question',
      message: 'Are you sure you want to delete this question?',
      confirmLabel: 'Delete',
    );

    if (!confirmed || !mounted) return;

    widget.onDelete!();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Question deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.question != null ? 'Edit Question' : 'New Question',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              if (widget.question != null)
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: 'Preview',
                  onPressed: () => showQuestionPreviewDialog(
                    context,
                    question: widget.question!,
                  ),
                ),
              if (widget.question != null && widget.onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'Delete question',
                  onPressed: _delete,
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Question Type',
            ),
            items: _typeLabels.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null && value != _selectedType) {
                setState(() => _selectedType = value);
              }
            },
          ),
          const SizedBox(height: 16),
          _DuplicateWarningBanner(
            questionText: _currentQuestionText,
            excludeContentFile: widget.contentFile,
            excludeLevelId: widget.levelId,
            excludeQuestionIndex: widget.questionIndex,
          ),
          const SizedBox(height: 8),
          _buildTypeForm(),
        ],
      ),
    );
  }

  Widget _buildTypeForm() {
    // When type changes, we pass null for question to reset the form,
    // unless the existing question matches the selected type.
    final questionForForm =
        (widget.question?.type == _selectedType) ? widget.question : null;

    return switch (_selectedType) {
      'multiple_choice' => MultipleChoiceForm(
          key: ValueKey('mc_$_selectedType'),
          question: questionForForm,
          onSave: widget.onSave,
          onQuestionTextChanged: _onQuestionTextChanged,
        ),
      'true_false' => TrueFalseForm(
          key: ValueKey('tf_$_selectedType'),
          question: questionForForm,
          onSave: widget.onSave,
          onQuestionTextChanged: _onQuestionTextChanged,
        ),
      'matching' => MatchingForm(
          key: ValueKey('match_$_selectedType'),
          question: questionForForm,
          onSave: widget.onSave,
          onQuestionTextChanged: _onQuestionTextChanged,
        ),
      'sorting' => SortingForm(
          key: ValueKey('sort_$_selectedType'),
          question: questionForForm,
          onSave: widget.onSave,
          onQuestionTextChanged: _onQuestionTextChanged,
        ),
      _ => MultipleChoiceForm(
          key: ValueKey('default_$_selectedType'),
          question: questionForForm,
          onSave: widget.onSave,
          onQuestionTextChanged: _onQuestionTextChanged,
        ),
    };
  }
}

/// Shows an amber warning banner when duplicate questions are detected.
class _DuplicateWarningBanner extends ConsumerWidget {
  const _DuplicateWarningBanner({
    required this.questionText,
    this.excludeContentFile,
    this.excludeLevelId,
    this.excludeQuestionIndex,
  });

  final String questionText;
  final String? excludeContentFile;
  final int? excludeLevelId;
  final int? excludeQuestionIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (questionText.trim().isEmpty) return const SizedBox.shrink();

    final params = DuplicateCheckParams(
      questionText: questionText,
      excludeContentFile: excludeContentFile,
      excludeLevelId: excludeLevelId,
      excludeQuestionIndex: excludeQuestionIndex,
    );

    final locations = ref.watch(duplicateCheckProvider(params));

    if (locations.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bu soru başka bir yerde de mevcut:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade300,
                  ),
                ),
                const SizedBox(height: 4),
                ...locations.map((loc) => Text(
                      '• $loc',
                      style: TextStyle(color: Colors.amber.shade200),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
