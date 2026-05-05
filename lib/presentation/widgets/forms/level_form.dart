import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/level_model.dart';
import '../../providers/content_providers.dart';
import '../../providers/history_providers.dart';
import '../shared/confirm_dialog.dart';

/// Form for creating or editing a [LevelModel].
///
/// When [level] is null, the form is in "create" mode with auto-ID suggestion.
/// When [level] is provided, the form is in "edit" mode.
class LevelForm extends ConsumerStatefulWidget {
  const LevelForm({
    super.key,
    required this.contentFile,
    this.level,
  });

  /// The content file this level belongs to.
  final String contentFile;

  /// The level to edit, or null to create a new one.
  final LevelModel? level;

  @override
  ConsumerState<LevelForm> createState() => _LevelFormState();
}

class _LevelFormState extends ConsumerState<LevelForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idController;
  late final TextEditingController _categoryNameController;
  late final TextEditingController _levelOrderController;
  late final TextEditingController _titleController;
  late final TextEditingController _unlockScoreController;
  late final TextEditingController _assetImageController;

  bool get _isEditing => widget.level != null;

  @override
  void initState() {
    super.initState();
    final level = widget.level;
    final notifier = ref.read(contentStateProvider.notifier);

    _idController = TextEditingController(
      text: level != null ? level.id.toString() : notifier.nextLevelId.toString(),
    );
    _categoryNameController = TextEditingController(
      text: level?.categoryName ?? '',
    );
    _levelOrderController = TextEditingController(
      text: level?.levelOrder.toString() ?? '1',
    );
    _titleController = TextEditingController(text: level?.title ?? '');
    _unlockScoreController = TextEditingController(
      text: level?.unlockScore.toString() ?? '0',
    );
    _assetImageController = TextEditingController(
      text: level?.assetImage ?? '',
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _categoryNameController.dispose();
    _levelOrderController.dispose();
    _titleController.dispose();
    _unlockScoreController.dispose();
    _assetImageController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Push current state to history before applying the change.
    ref.read(historyProvider.notifier).pushState(ref.read(contentStateProvider));

    final notifier = ref.read(contentStateProvider.notifier);
    final level = LevelModel(
      id: int.parse(_idController.text),
      bookId: widget.level?.bookId ?? 0,
      categoryName: _categoryNameController.text.trim(),
      levelOrder: int.parse(_levelOrderController.text),
      title: _titleController.text.trim(),
      unlockScore: int.parse(_unlockScoreController.text),
      assetImage: _assetImageController.text.trim().isEmpty
          ? null
          : _assetImageController.text.trim(),
      questions: widget.level?.questions ?? [],
    );

    if (_isEditing) {
      notifier.updateLevel(widget.contentFile, level);
    } else {
      notifier.addLevel(widget.contentFile, level);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Level updated' : 'Level created')),
    );
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete Level',
      message:
          'Are you sure you want to delete this level? All questions within it will be removed.',
      confirmLabel: 'Delete',
    );

    if (confirmed && mounted) {
      // Push current state to history before applying the delete.
      ref.read(historyProvider.notifier).pushState(ref.read(contentStateProvider));

      final notifier = ref.read(contentStateProvider.notifier);
      notifier.deleteLevel(widget.contentFile, widget.level!.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Level deleted')),
      );
    }
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Level' : 'New Level',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: 'Delete level (cascades to questions)',
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'ID',
                helperText: 'Auto-generated, but editable',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !_isEditing,
              validator: (value) {
                if (value == null || value.isEmpty) return 'ID is required';
                final id = int.tryParse(value);
                if (id == null || id <= 0) return 'ID must be a positive integer';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryNameController,
              decoration: const InputDecoration(
                labelText: 'Category Name *',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Category name must not be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _levelOrderController,
              decoration: const InputDecoration(
                labelText: 'Level Order',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Level order is required';
                final order = int.tryParse(value);
                if (order == null || order <= 0) {
                  return 'Level order must be a positive integer';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title must not be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _unlockScoreController,
              decoration: const InputDecoration(
                labelText: 'Unlock Score',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) return 'Unlock score is required';
                if (int.tryParse(value) == null) return 'Must be a number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _assetImageController,
              decoration: const InputDecoration(
                labelText: 'Asset Image (optional)',
                helperText: 'Leave empty if not needed',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Update Level' : 'Create Level'),
            ),
          ],
        ),
      ),
    );
  }
}
