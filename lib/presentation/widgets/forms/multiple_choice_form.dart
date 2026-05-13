import 'package:flutter/material.dart';

import '../../../data/models/question_model.dart';

/// Form for creating/editing a multiple choice question.
///
/// Fields: question_text, option_a, option_b, option_c, option_d,
/// correct_option (A/B/C/D), explanation (optional).
class MultipleChoiceForm extends StatefulWidget {
  const MultipleChoiceForm({
    super.key,
    this.question,
    required this.onSave,
    this.onQuestionTextChanged,
  });

  /// The question to edit, or null to create a new one.
  final QuestionModel? question;

  /// Callback when the form is saved with a valid question.
  final ValueChanged<QuestionModel> onSave;

  /// Callback when the question text field changes (for duplicate detection).
  final ValueChanged<String>? onQuestionTextChanged;

  @override
  State<MultipleChoiceForm> createState() => _MultipleChoiceFormState();
}

class _MultipleChoiceFormState extends State<MultipleChoiceForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _questionTextController;
  late final TextEditingController _optionAController;
  late final TextEditingController _optionBController;
  late final TextEditingController _optionCController;
  late final TextEditingController _optionDController;
  late final TextEditingController _explanationController;
  late String _correctOption;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _questionTextController = TextEditingController(text: q?.questionText ?? '');
    _optionAController = TextEditingController(text: q?.optionA ?? '');
    _optionBController = TextEditingController(text: q?.optionB ?? '');
    _optionCController = TextEditingController(text: q?.optionC ?? '');
    _optionDController = TextEditingController(text: q?.optionD ?? '');
    _explanationController = TextEditingController(text: q?.explanation ?? '');
    _correctOption = q?.correctOption ?? 'A';

    _questionTextController.addListener(_notifyQuestionTextChanged);
  }

  void _notifyQuestionTextChanged() {
    widget.onQuestionTextChanged?.call(_questionTextController.text);
  }

  @override
  void dispose() {
    _questionTextController.removeListener(_notifyQuestionTextChanged);
    _questionTextController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final question = QuestionModel(
      questionText: _questionTextController.text.trim(),
      optionA: _optionAController.text.trim(),
      optionB: _optionBController.text.trim(),
      optionC: _optionCController.text.trim(),
      optionD: _optionDController.text.trim(),
      correctOption: _correctOption,
      explanation: _explanationController.text.trim().isEmpty
          ? null
          : _explanationController.text.trim(),
      type: 'multiple_choice',
    );

    widget.onSave(question);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _questionTextController,
            decoration: const InputDecoration(
              labelText: 'Question Text *',
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Question text must not be empty';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _optionAController,
            decoration: const InputDecoration(
              labelText: 'Option A *',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Option A must not be empty';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _optionBController,
            decoration: const InputDecoration(
              labelText: 'Option B *',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Option B must not be empty';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _optionCController,
            decoration: const InputDecoration(
              labelText: 'Option C',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _optionDController,
            decoration: const InputDecoration(
              labelText: 'Option D',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _correctOption,
            decoration: const InputDecoration(
              labelText: 'Correct Option *',
            ),
            items: const [
              DropdownMenuItem(value: 'A', child: Text('A')),
              DropdownMenuItem(value: 'B', child: Text('B')),
              DropdownMenuItem(value: 'C', child: Text('C')),
              DropdownMenuItem(value: 'D', child: Text('D')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _correctOption = value);
            },
            validator: (value) {
              if (value == null || !['A', 'B', 'C', 'D'].contains(value)) {
                return 'Correct option must be A, B, C, or D';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _explanationController,
            decoration: const InputDecoration(
              labelText: 'Explanation (optional)',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Question'),
          ),
        ],
      ),
    );
  }
}
