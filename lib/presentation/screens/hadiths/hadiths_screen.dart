import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/hadith_model.dart';
import '../../providers/content_providers.dart';
import '../../widgets/preview/hadith_preview_dialog.dart';

/// Screen displaying all hadiths with CRUD operations.
///
/// Shows the total hadith count in the AppBar and lists each hadith
/// with its text and source.
class HadithsScreen extends ConsumerWidget {
  const HadithsScreen({super.key});

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    int index,
    HadithModel hadith,
  ) {
    final textController = TextEditingController(text: hadith.text);
    final sourceController = TextEditingController(text: hadith.source);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Hadith'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: 'Hadith Text',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sourceController,
                  decoration: const InputDecoration(
                    labelText: 'Source',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final newText = textController.text.trim();
                final newSource = sourceController.text.trim();
                if (newText.isEmpty || newSource.isEmpty) return;

                final notifier = ref.read(contentStateProvider.notifier);
                notifier.updateHadith(
                  index,
                  HadithModel(text: newText, source: newSource),
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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
            onPressed: () {
              final notifier = ref.read(contentStateProvider.notifier);
              notifier.addHadith(
                const HadithModel(
                  text: 'New hadith text',
                  source: 'Source',
                ),
              );
            },
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
                          onPressed: () {
                            final notifier =
                                ref.read(contentStateProvider.notifier);
                            notifier.deleteHadith(index);
                          },
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
