import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/asset_path_utils.dart';
import '../../../data/services/asset_server_client.dart';
import '../../providers/asset_server_providers.dart';
import '../../providers/connectivity_providers.dart';

/// A compact, reusable inline image picker widget for embedding in form rows.
///
/// Displays a thumbnail from the asset server when connected and a path is set,
/// a placeholder icon when no path is set, or the path as text when disconnected.
///
/// On click (when connected): opens a file picker, validates the extension,
/// uploads to the server, and calls [onPathChanged] with the new App_Path.
class InlineImagePicker extends ConsumerStatefulWidget {
  const InlineImagePicker({
    super.key,
    required this.currentAppPath,
    required this.defaultDirectory,
    required this.onPathChanged,
    this.targetFileName,
    this.allowedExtensions = const ['png', 'jpg', 'jpeg', 'webp', 'gif'],
  });

  /// The current App_Path for the image (e.g. `assets/images/book_1/cover.webp`).
  /// If null, a placeholder is shown.
  final String? currentAppPath;

  /// The default API directory for new uploads (e.g. `images/rewards/`).
  /// Used when [currentAppPath] is null and a new file is picked.
  final String defaultDirectory;

  /// Callback invoked with the new App_Path after a successful upload.
  final ValueChanged<String> onPathChanged;

  /// If set, the uploaded file will be renamed to this name (with .webp extension).
  /// Example: `book_1` → file saved as `book_1.webp` regardless of original name.
  /// This enforces naming standards.
  final String? targetFileName;

  /// Allowed file extensions for the file picker (without dots).
  final List<String> allowedExtensions;

  @override
  ConsumerState<InlineImagePicker> createState() => _InlineImagePickerState();
}

class _InlineImagePickerState extends ConsumerState<InlineImagePicker> {
  int _cacheBuster = DateTime.now().millisecondsSinceEpoch;
  bool _isUploading = false;

  String? get _thumbnailUrl {
    final appPath = widget.currentAppPath;
    if (appPath == null || appPath.isEmpty) return null;
    final apiPath = AssetPathUtils.appPathToApiPath(appPath);
    return 'http://localhost:8080/api/files/$apiPath?t=$_cacheBuster';
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(isServerConnectedProvider);

    // When disconnected: show path as text only
    if (!isConnected) {
      return _buildDisconnectedView();
    }

    // When connected: show thumbnail or placeholder, clickable
    return InkWell(
      onTap: _isUploading ? null : _pickAndUpload,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        child: _isUploading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildDisconnectedView() {
    final path = widget.currentAppPath;
    if (path == null || path.isEmpty) {
      return const SizedBox(
        width: 80,
        height: 80,
        child: Center(
          child: Icon(Icons.cloud_off, size: 24, color: Colors.grey),
        ),
      );
    }
    return SizedBox(
      width: 80,
      height: 80,
      child: Tooltip(
        message: path,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              path.split('/').last,
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final url = _thumbnailUrl;
    if (url == null) {
      // No path set — show placeholder
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 28,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              'Pick',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    // Show thumbnail from server
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null || file.name.isEmpty) return;

    // Validate extension client-side
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';
    if (!widget.allowedExtensions
        .map((e) => e.toLowerCase())
        .contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid file type: .$ext. '
            'Allowed: ${widget.allowedExtensions.join(", ")}',
          ),
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final client = ref.read(assetServerClientProvider);
      String apiPath;

      if (widget.currentAppPath != null &&
          widget.currentAppPath!.isNotEmpty) {
        // Overwrite at the same path
        apiPath = AssetPathUtils.appPathToApiPath(widget.currentAppPath!);
        await client.putFile(apiPath, file.bytes!);
      } else {
        // New file: use targetFileName if set, otherwise sanitize original name
        final String fileName;
        if (widget.targetFileName != null) {
          // Enforce naming standard: use target name + .webp extension
          fileName = '${widget.targetFileName}.webp';
        } else {
          fileName = AssetPathUtils.sanitizeFilename(file.name);
        }
        final dir = widget.defaultDirectory.endsWith('/')
            ? widget.defaultDirectory
            : '${widget.defaultDirectory}/';
        apiPath = '$dir$fileName';

        try {
          await client.createFile(apiPath, file.bytes!);
        } on AssetServerException catch (e) {
          if (e.statusCode == 409) {
            // File already exists — overwrite silently for standard names
            if (widget.targetFileName != null) {
              await client.putFile(apiPath, file.bytes!);
            } else {
              // Prompt user for non-standard names
              if (!mounted) return;
              final action = await _showConflictDialog(fileName);
              if (action == _ConflictAction.overwrite) {
                await client.putFile(apiPath, file.bytes!);
              } else if (action == _ConflictAction.rename) {
                final baseName = fileName.contains('.')
                    ? fileName.substring(0, fileName.lastIndexOf('.'))
                    : fileName;
                final extension = fileName.contains('.')
                    ? fileName.substring(fileName.lastIndexOf('.'))
                    : '';
                final timestamp = DateTime.now().millisecondsSinceEpoch;
                final newName = '${baseName}_$timestamp$extension';
                apiPath = '$dir$newName';
                await client.createFile(apiPath, file.bytes!);
              } else {
                setState(() => _isUploading = false);
                return;
              }
            }
          } else {
            rethrow;
          }
        }
      }

      // Success — update cache buster and notify parent
      final newAppPath = AssetPathUtils.apiPathToAppPath(apiPath);
      setState(() {
        _cacheBuster = DateTime.now().millisecondsSinceEpoch;
        _isUploading = false;
      });
      widget.onPathChanged(newAppPath);
    } on AssetServerException catch (e) {
      setState(() => _isUploading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload error: ${e.message}')),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<_ConflictAction?> _showConflictDialog(String filename) {
    return showDialog<_ConflictAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File Already Exists'),
        content: Text(
          'A file named "$filename" already exists in this directory. '
          'What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_ConflictAction.rename),
            child: const Text('Rename'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_ConflictAction.overwrite),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
  }
}

enum _ConflictAction { overwrite, rename }
