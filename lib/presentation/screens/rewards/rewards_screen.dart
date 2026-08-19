import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/reward_model.dart';
import '../../../data/services/asset_path_utils.dart';
import '../../providers/connectivity_providers.dart';
import '../../providers/content_providers.dart';
import '../../providers/history_providers.dart';
import '../../widgets/forms/inline_image_picker.dart';
import '../../widgets/shared/confirm_dialog.dart';
import '../../widgets/preview/reward_preview_dialog.dart';
import '../../../core/constants/asset_server_config.dart';

/// Screen displaying all rewards with image previews and CRUD operations.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contentStateProvider);
    final rewards = state.rewards;
    final books = state.books;
    final isConnected = ref.watch(isServerConnectedProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Rewards (${rewards.length})'),
        actions: [
          FilledButton.icon(
            onPressed: () => _showAddRewardDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Reward'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: rewards.isEmpty
          ? const Center(
              child: Text(
                'No rewards loaded. Import content to see rewards here.',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rewards.length,
              itemBuilder: (context, index) {
                final reward = rewards[index];
                final associatedBook = books
                    .where((b) => b.id == reward.unlockBookId)
                    .firstOrNull;
                final bookTitle = associatedBook?.title ??
                    'Unknown (ID: ${reward.unlockBookId})';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reward image thumbnail
                        _RewardImage(
                          assetImage: reward.assetImage,
                          isConnected: isConnected,
                        ),
                        const SizedBox(width: 16),
                        // Reward details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reward.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reward.description,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Book: $bookTitle',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit reward',
                              onPressed: () => _showEditRewardDialog(
                                context,
                                ref,
                                index,
                                reward,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined),
                              tooltip: 'Preview',
                              onPressed: () => showRewardPreviewDialog(
                                context,
                                reward: reward,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Theme.of(context).colorScheme.error,
                              tooltip: 'Delete reward',
                              onPressed: () =>
                                  _confirmDelete(context, ref, index, reward),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// Tek tıkla silme, yanlış tıklamada ödülü diske yazılacak şekilde
  /// kaldırıyordu; repodaki diğer bütün silmeler gibi burada da onay gerekiyor.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int index,
    RewardModel reward,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete Reward',
      message: 'Are you sure you want to delete "${reward.title}"?',
      confirmLabel: 'Delete',
    );

    if (!confirmed) return;

    ref.read(historyProvider.notifier).pushState(
          ref.read(contentStateProvider),
        );
    ref.read(contentStateProvider.notifier).deleteReward(index);
  }

  void _showAddRewardDialog(BuildContext context, WidgetRef ref) {
    final books = ref.read(contentStateProvider).books;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _RewardFormDialog(
        books: books,
        onSave: (reward) {
          ref.read(historyProvider.notifier).pushState(
                ref.read(contentStateProvider),
              );
          ref.read(contentStateProvider.notifier).addReward(reward);
        },
      ),
    );
  }

  void _showEditRewardDialog(
    BuildContext context,
    WidgetRef ref,
    int index,
    RewardModel reward,
  ) {
    final books = ref.read(contentStateProvider).books;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _RewardFormDialog(
        reward: reward,
        books: books,
        onSave: (updated) {
          ref.read(historyProvider.notifier).pushState(
                ref.read(contentStateProvider),
              );
          ref.read(contentStateProvider.notifier).updateReward(index, updated);
        },
      ),
    );
  }
}

/// Displays the reward image thumbnail from the asset server.
class _RewardImage extends StatelessWidget {
  const _RewardImage({
    required this.assetImage,
    required this.isConnected,
  });

  final String assetImage;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    if (!isConnected || assetImage.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: const Center(
          child: Icon(Icons.emoji_events, size: 32),
        ),
      );
    }

    final apiPath = AssetPathUtils.appPathToApiPath(assetImage);
    final url =
        AssetServerConfig.fileUrl(apiPath, cacheBuster: AssetServerConfig.now);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.errorContainer,
          ),
          child: const Center(
            child: Icon(Icons.broken_image_outlined, size: 32),
          ),
        ),
      ),
    );
  }
}

/// Dialog form for creating or editing a reward.
class _RewardFormDialog extends ConsumerStatefulWidget {
  const _RewardFormDialog({
    this.reward,
    required this.books,
    required this.onSave,
  });

  final RewardModel? reward;
  final List<dynamic> books;
  final ValueChanged<RewardModel> onSave;

  @override
  ConsumerState<_RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends ConsumerState<_RewardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _assetImage;
  late int? _selectedBookId;

  bool get _isEditing => widget.reward != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.reward?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.reward?.description ?? '');
    _assetImage = widget.reward?.assetImage ?? '';
    _selectedBookId = widget.reward?.unlockBookId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_assetImage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asset image is required')),
      );
      return;
    }

    final reward = RewardModel(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      assetImage: _assetImage,
      unlockBookId: _selectedBookId!,
    );

    widget.onSave(reward);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Reward' : 'New Reward'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InlineImagePicker(
                      currentAppPath:
                          _assetImage.isEmpty ? null : _assetImage,
                      defaultDirectory: 'images/rewards/',
                      targetFileName: _selectedBookId != null
                          ? 'book_${_selectedBookId}_reward'
                          : null,
                      onPathChanged: (newPath) {
                        setState(() => _assetImage = newPath);
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _assetImage.isEmpty
                            ? 'No image selected'
                            : _assetImage.split('/').last,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _selectedBookId,
                  decoration: const InputDecoration(
                    labelText: 'Unlock Book *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.books
                      .map((b) => DropdownMenuItem(
                            value: (b as dynamic).id as int,
                            child: Text((b as dynamic).title as String),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedBookId = value),
                  validator: (value) {
                    if (value == null) return 'Book must be selected';
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
          child: Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
