import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/reward_model.dart';
import '../../providers/content_providers.dart';

/// Form for creating or editing a [RewardModel].
///
/// Fields: title, description, asset_image, unlock_book_id (dropdown of available books).
class RewardForm extends ConsumerStatefulWidget {
  const RewardForm({
    super.key,
    this.reward,
    this.rewardIndex,
  });

  /// The reward to edit, or null to create a new one.
  final RewardModel? reward;

  /// The index of the reward in the list (for updates).
  final int? rewardIndex;

  @override
  ConsumerState<RewardForm> createState() => _RewardFormState();
}

class _RewardFormState extends ConsumerState<RewardForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _assetImageController;
  late int? _selectedBookId;

  bool get _isEditing => widget.reward != null;

  @override
  void initState() {
    super.initState();
    final reward = widget.reward;
    _titleController = TextEditingController(text: reward?.title ?? '');
    _descriptionController = TextEditingController(
      text: reward?.description ?? '',
    );
    _assetImageController = TextEditingController(
      text: reward?.assetImage ?? '',
    );
    _selectedBookId = reward?.unlockBookId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _assetImageController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(contentStateProvider.notifier);
    final reward = RewardModel(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      assetImage: _assetImageController.text.trim(),
      unlockBookId: _selectedBookId!,
    );

    if (_isEditing && widget.rewardIndex != null) {
      notifier.updateReward(widget.rewardIndex!, reward);
    } else {
      notifier.addReward(reward);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? 'Reward updated' : 'Reward created')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentStateProvider);
    final allBooks = state.books;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Reward' : 'New Reward',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
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
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Description must not be empty';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _assetImageController,
              decoration: const InputDecoration(
                labelText: 'Asset Image *',
                helperText: 'Must start with "assets/"',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Asset image must not be empty';
                }
                if (!value.trim().startsWith('assets/')) {
                  return 'Asset image must start with "assets/"';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedBookId,
              decoration: const InputDecoration(
                labelText: 'Unlock Book *',
              ),
              items: allBooks
                  .map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(b.title),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedBookId = value),
              validator: (value) {
                if (value == null) return 'Book must be selected';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isEditing ? 'Update Reward' : 'Create Reward'),
            ),
          ],
        ),
      ),
    );
  }
}
