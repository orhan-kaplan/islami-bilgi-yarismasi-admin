import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/question_model.dart';
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
  });

  /// The question to edit, or null to create a new one.
  final QuestionModel? question;

  /// Callback when the form is saved with a valid question.
  final ValueChanged<QuestionModel> onSave;

  @override
  ConsumerState<QuestionForm> createState() => _QuestionFormState();
}

class _QuestionFormState extends ConsumerState<QuestionForm> {
  late String _selectedType;

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
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.question != null ? 'Edit Question' : 'New Question',
            style: Theme.of(context).textTheme.headlineSmall,
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
          const SizedBox(height: 24),
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
        ),
      'true_false' => TrueFalseForm(
          key: ValueKey('tf_$_selectedType'),
          question: questionForForm,
          onSave: widget.onSave,
        ),
      'matching' => MatchingForm(
          key: ValueKey('match_$_selectedType'),
          question: questionForForm,
          onSave: widget.onSave,
        ),
      'sorting' => SortingForm(
          key: ValueKey('sort_$_selectedType'),
          question: questionForForm,
          onSave: widget.onSave,
        ),
      _ => MultipleChoiceForm(
          key: ValueKey('default_$_selectedType'),
          question: questionForForm,
          onSave: widget.onSave,
        ),
    };
  }
}
