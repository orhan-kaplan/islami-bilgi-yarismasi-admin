import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/hadith_model.dart';
import '../../providers/content_providers.dart';

/// Form for creating or editing a [HadithModel].
///
/// Fields: text, source.
class HadithForm extends ConsumerStatefulWidget {
  const HadithForm({
    super.key,
    this.hadith,
    this.hadithIndex,
  });

  /// The hadith to edit, or null to create a new one.
  final HadithModel? hadith;

  /// The index of the hadith in the list (for updates).
  final int? hadithIndex;

  @override
  ConsumerState<HadithForm> createState() => _HadithFormState();
}

class _HadithFormState extends ConsumerState<HadithForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _textController;
  late final TextEditingController _sourceController;

  bool get _isEditing => widget.hadith != null;

  @override
  void initState() {
    super.initState();
    final hadith = widget.hadith;
    _textController = TextEditingController(text: hadith?.text ?? '');
    _sourceController = TextEditingController(text: hadith?.source ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(contentStateProvider.notifier);
    final hadith = HadithModel(
      text: _textController.text.trim(),
      source: _sourceController.text.trim(),
    );

    if (_isEditing && widget.hadithIndex != null) {
      notifier.updateHadith(widget.hadithIndex!, hadith);
    } else {
      notifier.addHadith(hadith);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Hadith updated' : 'Hadith created')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Hadith' : 'New Hadith',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Text *',
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Text must not be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sourceController,
              decoration: const InputDecoration(
                labelText: 'Source *',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Source must not be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Update Hadith' : 'Create Hadith'),
            ),
          ],
        ),
      ),
    );
  }
}
