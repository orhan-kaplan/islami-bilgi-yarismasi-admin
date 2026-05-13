import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/asset_path_utils.dart';
import '../../../data/services/asset_reference_detector.dart';
import '../../../data/services/asset_server_client.dart';
import '../../providers/asset_providers.dart';
import '../../providers/asset_server_providers.dart';
import '../../providers/content_providers.dart';

/// Natural sort comparison that handles numeric segments correctly.
/// e.g. "level_2" < "level_10" (instead of alphabetic "level_10" < "level_2")
int _naturalCompare(String a, String b) {
  final regExp = RegExp(r'(\d+)|(\D+)');
  final partsA = regExp.allMatches(a).toList();
  final partsB = regExp.allMatches(b).toList();

  for (var i = 0; i < partsA.length && i < partsB.length; i++) {
    final partA = partsA[i].group(0)!;
    final partB = partsB[i].group(0)!;

    final numA = int.tryParse(partA);
    final numB = int.tryParse(partB);

    int result;
    if (numA != null && numB != null) {
      result = numA.compareTo(numB);
    } else {
      result = partA.toLowerCase().compareTo(partB.toLowerCase());
    }

    if (result != 0) return result;
  }

  return partsA.length.compareTo(partsB.length);
}

/// Images tab for the Assets screen.
///
/// Displays a left sidebar with subdirectories under `images/` and a main
/// grid area showing image thumbnails with filename, size, and action buttons.
class ImagesTab extends ConsumerStatefulWidget {
  const ImagesTab({super.key});

  @override
  ConsumerState<ImagesTab> createState() => _ImagesTabState();
}

class _ImagesTabState extends ConsumerState<ImagesTab> {
  String? _selectedFolder;
  int _cacheBuster = DateTime.now().millisecondsSinceEpoch;

  void _invalidateAndRefresh(String path) {
    ref.invalidate(assetListProvider);
    setState(() {
      _cacheBuster = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(assetListProvider('images'));

    return Row(
      children: [
        // Left sidebar: folder list
        SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: FilledButton.icon(
                  onPressed: _createNewFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('New Folder'),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: foldersAsync.when(
                  data: (entries) {
                    final folders = entries
                        .where((e) => e.type == 'directory')
                        .toList()
                      ..sort((a, b) => _naturalCompare(a.name, b.name));
                    if (folders.isEmpty) {
                      return const Center(
                        child: Text('No folders found'),
                      );
                    }
                    return ListView.builder(
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        final isSelected =
                            _selectedFolder == folder.name;
                        return ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(folder.name),
                          selected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedFolder = folder.name;
                            });
                          },
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
          ),
        ),
        const VerticalDivider(width: 1),
        // Main area: image grid
        Expanded(
          child: _selectedFolder == null
              ? const Center(
                  child: Text('Select a folder from the sidebar'),
                )
              : _buildImageGrid(),
        ),
      ],
    );
  }

  Widget _buildImageGrid() {
    final path = 'images/$_selectedFolder';
    final filesAsync = ref.watch(assetListProvider(path));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                _selectedFolder!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addNewImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add New Image'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: filesAsync.when(
            data: (entries) {
              final files =
                  entries.where((e) => e.type == 'file').toList()
                    ..sort((a, b) => _naturalCompare(a.name, b.name));
              if (files.isEmpty) {
                return const Center(
                  child: Text('No images in this folder'),
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
                  return _ImageCard(
                    entry: files[index],
                    folder: _selectedFolder!,
                    cacheBuster: _cacheBuster,
                    onReplace: () => _replaceImage(files[index]),
                    onDelete: () => _deleteImage(files[index]),
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

  Future<void> _addNewImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null || file.name.isEmpty) return;

    final client = ref.read(assetServerClientProvider);
    final apiPath = 'images/$_selectedFolder/${file.name}';

    try {
      await client.createFile(apiPath, file.bytes!);
      if (mounted) {
        _invalidateAndRefresh('images/$_selectedFolder');
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

  Future<void> _replaceImage(FileEntry entry) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    final client = ref.read(assetServerClientProvider);
    final apiPath = entry.path;

    try {
      await client.putFile(apiPath, file.bytes!);
      if (mounted) {
        _invalidateAndRefresh('images/$_selectedFolder');
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

  Future<void> _deleteImage(FileEntry entry) async {
    // Check references first
    final contentState = ref.read(contentStateProvider);
    final appPath = AssetPathUtils.apiPathToAppPath(entry.path);
    final references =
        AssetReferenceDetector.findReferences(contentState, appPath);

    if (references.isNotEmpty) {
      // Block deletion — show references
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.name} is referenced by the following items:',
              ),
              const SizedBox(height: 8),
              ...references.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text('• ${r.type.name}: ${r.name}'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Confirm deletion for unreferenced files
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
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
        _invalidateAndRefresh('images/$_selectedFolder');
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

  Future<void> _createNewFolder() async {
    final nameController = TextEditingController();
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'e.g. book_4',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (folderName == null || folderName.trim().isEmpty) return;

    final sanitized =
        AssetPathUtils.sanitizeFilename(folderName.trim());
    final client = ref.read(assetServerClientProvider);

    try {
      await client.createFolder('images/$sanitized');
      if (mounted) {
        // Invalidate the images root listing to refresh sidebar
        ref.invalidate(assetListProvider);
        setState(() {
          _selectedFolder = sanitized;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created folder: $sanitized')),
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

/// Card widget displaying an image thumbnail with metadata and actions.
class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.entry,
    required this.folder,
    required this.cacheBuster,
    required this.onReplace,
    required this.onDelete,
  });

  final FileEntry entry;
  final String folder;
  final int cacheBuster;
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  String get _thumbnailUrl =>
      'http://localhost:8080/api/files/${entry.path}?t=$cacheBuster';

  String get _formattedSize {
    final bytes = entry.size;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

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
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image_outlined, size: 48),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formattedSize,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
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
