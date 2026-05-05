import 'package:flutter/material.dart';

import '../../../data/models/question_model.dart';

/// Form for creating/editing a true/false question.
///
/// Pre-fills option_a="Doğru", option_b="Yanlış", auto-sets option_c/d to empty.
/// Restricts correct_option to A or B.
class TrueFalseForm extends StatefulWidget {
  const TrueFalseForm({
    super.key,
    this.question,
    required this.onSave,
  });

  /// The question to edit, or null to create a new one.
  final QuestionModel? question;

  /// Callback when the form is saved with a valid question.
  final ValueChanged<QuestionModel> onSave;

  @override
  State<TrueFalseForm> createState() => _TrueFalseFormState();
}

class _TrueFalseFormState extends State<TrueFalseForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _questionTextController;
  late final TextEditingController _explanationController;
  late String _correctOption;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _questionTextController = TextEditingController(text: q?.questionText ?? '');
    _explanationController = TextEditingController(text: q?.explanation ?? '');
    // For true/false, correct_option is either A (Doğru) or B (Yanlış)
    _correctOption = (q?.correctOption == 'B') ? 'B' : 'A';
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final question = QuestionModel(
      questionText: _questionTextController.text.trim(),
      optionA: 'Doğru',
      optionB: 'Yanlış',
      optionC: '',
      optionD: '',
      correctOption: _correctOption,
      explanation: _explanationController.text.trim().isEmpty
          ? null
          : _explanationController.text.trim(),
      type: 'true_false',
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
          // Show pre-filled options as read-only info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Options (auto-filled)',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('A: Doğru'),
                  const Text('B: Yanlış'),
                  const Text('C: (empty)'),
                  const Text('D: (empty)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _correctOption,
            decoration: const InputDecoration(
              labelText: 'Correct Answer *',
            ),
            items: const [
              DropdownMenuItem(value: 'A', child: Text('A - Doğru')),
              DropdownMenuItem(value: 'B', child: Text('B - Yanlış')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _correctOption = value);
            },
            validator: (value) {
              if (value == null || !['A', 'B'].contains(value)) {
                return 'Correct option must be A or B';
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
