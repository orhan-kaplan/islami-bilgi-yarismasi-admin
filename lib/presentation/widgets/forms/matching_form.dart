import 'package:flutter/material.dart';

import '../../../data/models/question_model.dart';

/// Form for creating/editing a matching question.
///
/// Provides four pair inputs (left | right for each option).
/// Auto-inserts the `|` separator when building the option values.
/// correct_option is always "A".
class MatchingForm extends StatefulWidget {
  const MatchingForm({
    super.key,
    this.question,
    required this.onSave,
  });

  /// The question to edit, or null to create a new one.
  final QuestionModel? question;

  /// Callback when the form is saved with a valid question.
  final ValueChanged<QuestionModel> onSave;

  @override
  State<MatchingForm> createState() => _MatchingFormState();
}

class _MatchingFormState extends State<MatchingForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _questionTextController;
  late final TextEditingController _explanationController;

  // Left and right parts for each pair
  late final TextEditingController _leftAController;
  late final TextEditingController _rightAController;
  late final TextEditingController _leftBController;
  late final TextEditingController _rightBController;
  late final TextEditingController _leftCController;
  late final TextEditingController _rightCController;
  late final TextEditingController _leftDController;
  late final TextEditingController _rightDController;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    _questionTextController = TextEditingController(text: q?.questionText ?? '');
    _explanationController = TextEditingController(text: q?.explanation ?? '');

    // Parse existing options by splitting on '|'
    final partsA = _splitOption(q?.optionA);
    final partsB = _splitOption(q?.optionB);
    final partsC = _splitOption(q?.optionC);
    final partsD = _splitOption(q?.optionD);

    _leftAController = TextEditingController(text: partsA.$1);
    _rightAController = TextEditingController(text: partsA.$2);
    _leftBController = TextEditingController(text: partsB.$1);
    _rightBController = TextEditingController(text: partsB.$2);
    _leftCController = TextEditingController(text: partsC.$1);
    _rightCController = TextEditingController(text: partsC.$2);
    _leftDController = TextEditingController(text: partsD.$1);
    _rightDController = TextEditingController(text: partsD.$2);
  }

  (String, String) _splitOption(String? option) {
    if (option == null || option.isEmpty) return ('', '');
    final parts = option.split('|');
    if (parts.length >= 2) {
      return (parts[0].trim(), parts.sublist(1).join('|').trim());
    }
    return (option, '');
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    _explanationController.dispose();
    _leftAController.dispose();
    _rightAController.dispose();
    _leftBController.dispose();
    _rightBController.dispose();
    _leftCController.dispose();
    _rightCController.dispose();
    _leftDController.dispose();
    _rightDController.dispose();
    super.dispose();
  }

  String _buildOption(TextEditingController left, TextEditingController right) {
    return '${left.text.trim()} | ${right.text.trim()}';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final question = QuestionModel(
      questionText: _questionTextController.text.trim(),
      optionA: _buildOption(_leftAController, _rightAController),
      optionB: _buildOption(_leftBController, _rightBController),
      optionC: _buildOption(_leftCController, _rightCController),
      optionD: _buildOption(_leftDController, _rightDController),
      correctOption: 'A',
      explanation: _explanationController.text.trim().isEmpty
          ? null
          : _explanationController.text.trim(),
      type: 'matching',
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
            'Matching Pairs',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _buildPairRow('Pair A', _leftAController, _rightAController, required: true),
          const SizedBox(height: 8),
          _buildPairRow('Pair B', _leftBController, _rightBController, required: true),
          const SizedBox(height: 8),
          _buildPairRow('Pair C', _leftCController, _rightCController, required: true),
          const SizedBox(height: 8),
          _buildPairRow('Pair D', _leftDController, _rightDController, required: true),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Correct option is always "A" for matching questions.',
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

  Widget _buildPairRow(
    String label,
    TextEditingController leftController,
    TextEditingController rightController, {
    bool required = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: leftController,
            decoration: InputDecoration(
              labelText: '$label - Left',
              isDense: true,
            ),
            validator: required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  }
                : null,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('|'),
        ),
        Expanded(
          child: TextFormField(
            controller: rightController,
            decoration: InputDecoration(
              labelText: '$label - Right',
              isDense: true,
            ),
            validator: required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
