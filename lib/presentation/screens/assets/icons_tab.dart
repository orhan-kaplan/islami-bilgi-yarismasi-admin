import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/asset_server_client.dart';
import '../../providers/asset_providers.dart';
import '../../providers/asset_server_providers.dart';
import '../../../core/constants/asset_server_config.dart';

/// Icons tab for the Assets screen.
///
/// Displays a grid of icon files from the `icons/` directory with image
/// previews, filenames, and Replace/Delete action buttons.
class IconsTab extends ConsumerStatefulWidget {
  const IconsTab({super.key});

  @override
  ConsumerState<IconsTab> createState() => _IconsTabState();
}

class _IconsTabState extends ConsumerState<IconsTab> {
  int _cacheBuster = DateTime.now().millisecondsSinceEpoch;

  static const _allowedExtensions = ['png', 'jpg', 'jpeg', 'webp', 'ico'];

  void _invalidateAndRefresh() {
    ref.invalidate(assetListProvider);
    setState(() {
      _cacheBuster = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(assetListProvider('icons'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                'Icons',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addNewIcon,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add New Icon'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filesAsync.when(
            data: (entries) {
              final files =
                  entries.where((e) => e.type == 'file').toList();
              if (files.isEmpty) {
                return const Center(
                  child: Text('No icons found'),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  return _IconCard(
                    entry: files[index],
                    cacheBuster: _cacheBuster,
                    onReplace: () => _replaceIcon(files[index]),
                    onDelete: () => _deleteIcon(files[index]),
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text('Error: $error'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addNewIcon() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null || file.name.isEmpty) return;

    final client = ref.read(assetServerClientProvider);
    final apiPath = 'icons/${file.name}';

    try {
      await client.createFile(apiPath, file.bytes!);
      if (mounted) {
        _invalidateAndRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${file.name}')),
        );
      }
    } on AssetServerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }

  Future<void> _replaceIcon(FileEntry entry) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    final client = ref.read(assetServerClientProvider);

    try {
      await client.putFile(entry.path, file.bytes!);
      if (mounted) {
        _invalidateAndRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Replaced ${entry.name}')),
        );
      }
    } on AssetServerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }

  Future<void> _deleteIcon(FileEntry entry) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Icon'),
        content: Text('Are you sure you want to delete ${entry.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final client = ref.read(assetServerClientProvider);
    try {
      await client.deleteFile(entry.path);
      if (mounted) {
        _invalidateAndRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${entry.name}')),
        );
      }
    } on AssetServerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    }
  }
}

/// Card widget displaying an icon thumbnail with filename and actions.
class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.entry,
    required this.cacheBuster,
    required this.onReplace,
    required this.onDelete,
  });

  final FileEntry entry;
  final int cacheBuster;
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  String get _thumbnailUrl =>
      AssetServerConfig.fileUrl(entry.path, cacheBuster: cacheBuster);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Image.network(
              _thumbnailUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 48),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              entry.name,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  tooltip: 'Replace',
                  onPressed: onReplace,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
