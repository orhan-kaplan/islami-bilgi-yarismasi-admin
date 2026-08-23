import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/hadith_model.dart';
import '../../providers/content_providers.dart';
import '../../providers/history_providers.dart';
import '../../widgets/preview/hadith_preview_dialog.dart';
import '../../widgets/shared/confirm_dialog.dart';

/// Screen displaying all hadiths with CRUD operations.
///
/// Shows the total hadith count in the AppBar and lists each hadith
/// with its text and source.
class HadithsScreen extends ConsumerWidget {
  const HadithsScreen({super.key});

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _HadithFormDialog(
        onSave: (hadith) {
          ref.read(historyProvider.notifier).pushState(
                ref.read(contentStateProvider),
              );
          ref.read(contentStateProvider.notifier).addHadith(hadith);
        },
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    int index,
    HadithModel hadith,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _HadithFormDialog(
        hadith: hadith,
        onSave: (updated) {
          ref.read(historyProvider.notifier).pushState(
                ref.read(contentStateProvider),
              );
          ref.read(contentStateProvider.notifier).updateHadith(index, updated);
        },
      ),
    );
  }

  /// Tek tıkla silme, yanlış tıklamada hadisi diske yazılacak şekilde
  /// kaldırıyordu; repodaki diğer bütün silmeler gibi burada da onay gerekiyor.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete Hadith',
      message: 'Are you sure you want to delete this hadith?',
      confirmLabel: 'Delete',
    );

    if (!confirmed) return;

    ref.read(historyProvider.notifier).pushState(
          ref.read(contentStateProvider),
        );
    ref.read(contentStateProvider.notifier).deleteHadith(index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contentStateProvider);
    final hadiths = state.hadiths;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hadiths (${hadiths.length})'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showAddDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Hadith'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: hadiths.isEmpty
          ? const Center(
              child: Text(
                'No hadiths loaded. Import content to see hadiths here.',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: hadiths.length,
              itemBuilder: (context, index) {
                final hadith = hadiths[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      hadith.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Source: ${hadith.source}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined),
                          tooltip: 'Preview',
                          onPressed: () => showHadithPreviewDialog(
                            context,
                            hadith: hadith,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit hadith',
                          onPressed: () => _showEditDialog(
                            context,
                            ref,
                            index,
                            hadith,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Theme.of(context).colorScheme.error,
                          tooltip: 'Delete hadith',
                          onPressed: () => _confirmDelete(context, ref, index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Dialog for creating or editing a hadith (text + source).
class _HadithFormDialog extends StatefulWidget {
  const _HadithFormDialog({
    this.hadith,
    required this.onSave,
  });

  final HadithModel? hadith;
  final ValueChanged<HadithModel> onSave;

  @override
  State<_HadithFormDialog> createState() => _HadithFormDialogState();
}

class _HadithFormDialogState extends State<_HadithFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textController;
  late final TextEditingController _sourceController;

  bool get _isEditing => widget.hadith != null;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.hadith?.text ?? '');
    _sourceController =
        TextEditingController(text: widget.hadith?.source ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSave(
      HadithModel(
        text: _textController.text.trim(),
        source: _sourceController.text.trim(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Hadith' : 'Add Hadith'),
      // Kısa pencerede (veya klavye açıkken) 4 satırlık metin alanı, kaynak ve
      // validasyon hataları dialogu taşırıyor, Save erişilemez kalıyordu.
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: 'Hadith',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Hadith text is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _sourceController,
                  decoration: const InputDecoration(
                    labelText: 'Source',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Source is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
