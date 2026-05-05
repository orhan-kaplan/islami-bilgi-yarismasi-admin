import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/reward_model.dart';
import '../../providers/content_providers.dart';

/// Screen displaying all rewards with CRUD operations.
///
/// Each reward shows its title, description, asset_image path, and the
/// associated book title (looked up from state.books by unlockBookId).
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(contentStateProvider);
    final rewards = state.rewards;
    final books = state.books;

    return Scaffold(
      appBar: AppBar(
        title: Text('Rewards (${rewards.length})'),
        actions: [
          FilledButton.icon(
            onPressed: () {
              final notifier = ref.read(contentStateProvider.notifier);
              notifier.addReward(
                RewardModel(
                  title: 'New Reward',
                  description: 'Reward description',
                  assetImage: 'assets/images/rewards/placeholder.webp',
                  unlockBookId: books.isNotEmpty ? books.first.id : 1,
                ),
              );
            },
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
                final bookTitle =
                    associatedBook?.title ?? 'Unknown (ID: ${reward.unlockBookId})';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.emoji_events),
                    ),
                    title: Text(reward.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reward.description),
                        const SizedBox(height: 4),
                        Text(
                          'Asset: ${reward.assetImage}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Book: $bookTitle',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Theme.of(context).colorScheme.error,
                      tooltip: 'Delete reward',
                      onPressed: () {
                        final notifier =
                            ref.read(contentStateProvider.notifier);
                        notifier.deleteReward(index);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
