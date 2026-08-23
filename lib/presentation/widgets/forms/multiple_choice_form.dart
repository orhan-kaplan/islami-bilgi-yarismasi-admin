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
    // Boş bir şık doğru cevap menüsünde seçilemez; doldurulur doldurulmaz
    // seçilebilir hale gelmeli.
    _optionCController.addListener(_refreshOptionAvailability);
    _optionDController.addListener(_refreshOptionAvailability);
  }

  void _refreshOptionAvailability() {
    if (mounted) setState(() {});
  }

  void _notifyQuestionTextChanged() {
    widget.onQuestionTextChanged?.call(_questionTextController.text);
  }

  @override
  void dispose() {
    _questionTextController.removeListener(_notifyQuestionTextChanged);
    _optionCController.removeListener(_refreshOptionAvailability);
    _optionDController.removeListener(_refreshOptionAvailability);
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

  /// Boş bir şık doğru cevap olamaz (ContentValidator 10.18 ERROR üretir ve
  /// content dosyasının kaydını bloklar) — menüde de seçilebilir görünmemeli.
  /// A ve B zaten zorunlu alanlar; kısıt yalnızca opsiyonel C/D için geçerli.
  DropdownMenuItem<String> _optionItem(
    String value,
    TextEditingController controller, {
    required bool optional,
  }) {
    final isEmpty = optional && controller.text.trim().isEmpty;
    return DropdownMenuItem(
      value: value,
      enabled: !isEmpty,
      child: Text(
        isEmpty ? '$value (empty)' : value,
        style: isEmpty
            ? TextStyle(color: Theme.of(context).disabledColor)
            : null,
      ),
    );
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
            items: [
              _optionItem('A', _optionAController, optional: false),
              _optionItem('B', _optionBController, optional: false),
              _optionItem('C', _optionCController, optional: true),
              _optionItem('D', _optionDController, optional: true),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _correctOption = value);
            },
            validator: (value) {
              if (value == null || !['A', 'B', 'C', 'D'].contains(value)) {
                return 'Correct option must be A, B, C, or D';
              }
              // Option C/D zorunlu değil; boş bir şıkkı doğru cevap yapmak
              // ContentValidator'da ERROR üretip content dosyasının tamamının
              // kaydını bloklar. Formda durdur.
              final target = {
                'A': _optionAController,
                'B': _optionBController,
                'C': _optionCController,
                'D': _optionDController,
              }[value]!;
              if (target.text.trim().isEmpty) {
                return 'Option $value is empty — pick an option that has text';
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
