import 'package:flutter/material.dart';

import '../../../data/models/question_model.dart';

/// Form for creating/editing a sorting question.
///
/// Provides four ordered items (option_a through option_d).
/// Auto-sets correct_option to "A".
class SortingForm extends StatefulWidget {
  const SortingForm({
    super.key,
    this.question,
    required this.onSave,
  });

  /// The question to edit, or null to create a new one.
  final QuestionModel? question;

  /// Callback when the form is saved with a valid question.
  final ValueChanged<QuestionModel> onSave;

  @override
  State<SortingForm> createState() => _SortingFormState();
}

class _SortingFormState extends State<SortingForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _questionTextController;
  late final TextEditingController _optionAController;
  late final TextEditingController _optionBController;
  late final TextEditingController _optionCController;
  late final TextEditingController _optionDController;
  late final TextEditingController _explanationController;

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
  }

  @override
  void dispose() {
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
      correctOption: 'A',
      explanation: _explanationController.text.trim().isEmpty
          ? null
          : _explanationController.text.trim(),
      type: 'sorting',
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
          Text(
            'Items in Correct Order',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _optionAController,
            decoration: const InputDecoration(
              labelText: '1st Item (Option A) *',
              isDense: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Item must not be empty';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _optionBController,
            decoration: const InputDecoration(
              labelText: '2nd Item (Option B) *',
              isDense: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Item must not be empty';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _optionCController,
            decoration: const InputDecoration(
              labelText: '3rd Item (Option C) *',
              isDense: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Item must not be empty';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _optionDController,
            decoration: const InputDecoration(
              labelText: '4th Item (Option D) *',
              isDense: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Item must not be empty';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Correct option is always "A" for sorting questions.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
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
