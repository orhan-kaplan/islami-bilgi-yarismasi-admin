import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/question_model.dart';
import '../../../data/services/bulk_importer.dart';

/// Shows the bulk add dialog and returns the list of valid questions
/// if confirmed, or null if cancelled.
Future<List<QuestionModel>?> showBulkAddDialog(BuildContext context) {
  return showDialog<List<QuestionModel>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const BulkAddDialog(),
  );
}

/// A dialog widget for bulk-adding questions via pasted text input.
///
/// Supports JSON array and line-based formats. Shows a preview table
/// with valid/invalid indicators before confirming.
class BulkAddDialog extends StatefulWidget {
  const BulkAddDialog({super.key});

  @override
  State<BulkAddDialog> createState() => _BulkAddDialogState();
}

class _BulkAddDialogState extends State<BulkAddDialog> {
  final _controller = TextEditingController();
  final _importer = BulkImporter();
  BulkImportResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parseInput() {
    final text = _controller.text;
    if (text.trim().isEmpty) {
      setState(() {
        _result = const BulkImportResult(
          errors: [
            BulkImportError(questionIndex: 0, reason: 'Input is empty'),
          ],
        );
      });
      return;
    }
    setState(() {
      _result = _importer.parse(text);
    });
  }

  void _confirm() {
    if (_result != null && _result!.hasValidQuestions) {
      Navigator.of(context).pop(_result!.validQuestions);
    }
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _result?.validQuestions.length ?? 0;
    final errorCount = _result?.errors.length ?? 0;
    final hasPreview = _result != null;

    // Sabit 700x500 içerik küçük pencerede taşıyordu: dialog'un kendi inset
    // padding'i ve başlık/aksiyon satırları da yer kaplıyor.
    final viewport = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: const Text('Bulk Add Questions'),
      content: SizedBox(
        width: math.min(700, math.max(280, viewport.width - 120)),
        height: math.min(500, math.max(240, viewport.height - 200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste questions in JSON array format or line-based format '
              '(separated by blank lines).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: hasPreview ? 1 : 2,
              child: TextFormField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText:
                      'Paste questions here...\n\n'
                      'JSON format: [{...}, {...}]\n\n'
                      'Line format:\n'
                      'question_text\n'
                      'option_a\n'
                      'option_b\n'
                      'option_c\n'
                      'option_d\n'
                      'correct_option (A/B/C/D)\n'
                      'explanation (optional)\n'
                      'type (optional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _parseInput,
                icon: const Icon(Icons.preview, size: 18),
                label: const Text('Preview'),
              ),
            ),
            if (hasPreview) ...[
              const SizedBox(height: 12),
              _buildPreviewSection(validCount, errorCount),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              (hasPreview && validCount > 0) ? _confirm : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildPreviewSection(int validCount, int errorCount) {
    return Expanded(
      flex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary row
          _buildSummaryRow(validCount, errorCount),
          const SizedBox(height: 8),
          // Preview table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildPreviewList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(int validCount, int errorCount) {
    final children = <Widget>[];

    if (validCount > 0) {
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 4),
            Text(
              '$validCount valid',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (errorCount > 0) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 16));
      }
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 16),
            const SizedBox(width: 4),
            Text(
              '$errorCount invalid',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Show message about what confirming will do
    if (validCount > 0 && errorCount > 0) {
      children.add(const SizedBox(width: 16));
      children.add(
        Flexible(
          child: Text(
            'Confirming will add $validCount valid question${validCount == 1 ? '' : 's'} '
            'and skip $errorCount invalid one${errorCount == 1 ? '' : 's'}.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade800,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    } else if (validCount == 0 && errorCount > 0) {
      children.add(const SizedBox(width: 16));
      children.add(
        Flexible(
          child: Text(
            'No valid questions to add.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Row(children: children);
  }

  Widget _buildPreviewList() {
    final result = _result!;
    final items = <_PreviewItem>[];

    // Add valid questions
    for (var i = 0; i < result.validQuestions.length; i++) {
      items.add(_PreviewItem(
        question: result.validQuestions[i],
        isValid: true,
      ));
    }

    // Add invalid entries
    for (final error in result.errors) {
      items.add(_PreviewItem(
        error: error,
        isValid: false,
      ));
    }

    // Sort by original index for consistent display
    items.sort((a, b) {
      final indexA = a.isValid
          ? result.validQuestions.indexOf(a.question!)
          : a.error!.questionIndex;
      final indexB = b.isValid
          ? result.validQuestions.indexOf(b.question!)
          : b.error!.questionIndex;
      // Valid questions don't have a direct index from the original input,
      // so we use a combined approach
      return indexA.compareTo(indexB);
    });

    if (items.isEmpty) {
      return const Center(
        child: Text('No questions parsed.'),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildPreviewRow(item, index);
      },
    );
  }

  Widget _buildPreviewRow(_PreviewItem item, int index) {
    if (item.isValid) {
      final question = item.question!;
      return ListTile(
        dense: true,
        leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
        title: Text(
          question.questionText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          'Type: ${question.type} | Answer: ${question.correctOption}',
          style: const TextStyle(fontSize: 11),
        ),
      );
    } else {
      final error = item.error!;
      return ListTile(
        dense: true,
        leading: const Icon(Icons.error, color: Colors.red, size: 20),
        title: Text(
          'Question #${error.questionIndex + 1}',
          style: const TextStyle(fontSize: 13, color: Colors.red),
        ),
        subtitle: Text(
          error.reason,
          style: const TextStyle(fontSize: 11, color: Colors.red),
        ),
      );
    }
  }
}

/// Internal model for preview list items.
class _PreviewItem {
  final QuestionModel? question;
  final BulkImportError? error;
  final bool isValid;

  _PreviewItem({
    this.question,
    this.error,
    required this.isValid,
  });
}
