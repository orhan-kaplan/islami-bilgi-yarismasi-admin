import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../data/services/asset_server_client.dart';
import '../providers/asset_server_providers.dart';
import '../../core/constants/asset_server_config.dart';

/// Shows a dialog for selecting or uploading a Lottie animation file.
///
/// Lists existing files from `lottie/feedback/` directory via the asset server,
/// displays them as a grid of live Lottie previews, and allows uploading new
/// Lottie JSON files.
///
/// Returns the selected path in short format (e.g., `feedback/filename.json`)
/// or `null` if the dialog is cancelled.
Future<String?> showLottiePickerDialog(BuildContext context) {
  return showDialog<String?>(
    context: context,
    // Barrier'a kazara tıklamak dialogu kapatıyordu; yükleme sürerken bu,
    // dosyanın sunucuya yazılıp mesaja hiç bağlanmaması ve kullanıcıya hiçbir
    // şey söylenmemesi demekti.
    barrierDismissible: false,
    builder: (context) => const _LottiePickerDialog(),
  );
}

class _LottiePickerDialog extends ConsumerStatefulWidget {
  const _LottiePickerDialog();

  @override
  ConsumerState<_LottiePickerDialog> createState() =>
      _LottiePickerDialogState();
}

class _LottiePickerDialogState extends ConsumerState<_LottiePickerDialog> {
  List<FileEntry>? _files;
  bool _isLoading = true;
  String? _error;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(assetServerClientProvider);
      final entries = await client.listDirectory('lottie/feedback');
      // Filter to only .json files
      final jsonFiles =
          entries.where((e) => e.type == 'file' && e.name.endsWith('.json')).toList();
      if (mounted) {
        setState(() {
          _files = jsonFiles;
          _isLoading = false;
        });
      }
    } on AssetServerException catch (e) {
      // `_files = []` atanınca grid "dosya yok" boş durumunu gösteriyor,
      // kullanıcı hatayı görmüyordu. Hata artık kendi durumu olarak sunulur.
      if (mounted) {
        setState(() {
          _error = 'Could not load Lottie files — server error: ${e.message}';
          _isLoading = false;
          _files = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load Lottie files: $e';
          _isLoading = false;
          _files = null;
        });
      }
    }
  }

  Future<void> _uploadNew() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        _showError('The file could not be read.');
      }
      return;
    }

    // Validate Lottie structure
    final validationError = _validateLottieBytes(bytes);
    if (validationError != null) {
      if (mounted) {
        _showError(validationError);
      }
      return;
    }

    // Upload to server
    final fileName = file.name;
    // Dosya seçici açıkken dialog kapanmış olabilir.
    if (!mounted) return;
    setState(() {
      _isUploading = true;
    });

    try {
      final client = ref.read(assetServerClientProvider);
      await client.putFile('lottie/feedback/$fileName', bytes);

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        // Return the short path for the newly uploaded file
        Navigator.of(context).pop('feedback/$fileName');
      }
    } on AssetServerException catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        _showError('Upload failed: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        _showError('Upload failed: $e');
      }
    }
  }

  /// Validates that the given bytes represent a valid Lottie JSON file.
  ///
  /// Checks for required fields: `v` (version), `layers`, `w` (width), `h` (height).
  /// Returns an error message string if validation fails, or `null` if valid.
  String? _validateLottieBytes(Uint8List bytes) {
    try {
      final content = utf8.decode(bytes);
      final json = jsonDecode(content);
      if (json is! Map<String, dynamic>) {
        return 'Invalid Lottie file: the JSON root must be an object.';
      }

      final missingFields = <String>[];
      if (!json.containsKey('v')) missingFields.add('v');
      if (!json.containsKey('layers')) missingFields.add('layers');
      if (!json.containsKey('w')) missingFields.add('w');
      if (!json.containsKey('h')) missingFields.add('h');

      if (missingFields.isNotEmpty) {
        return 'Invalid Lottie file: missing fields: '
            '${missingFields.join(', ')}';
      }

      return null;
    } on FormatException {
      return 'Invalid file: malformed JSON.';
    } catch (e) {
      return 'The file could not be validated: $e';
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _selectFile(FileEntry file) {
    // Return short format path: feedback/filename.json
    Navigator.of(context).pop('feedback/${file.name}');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select a Lottie animation'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            // Upload button row
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isUploading ? null : _uploadNew,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(_isUploading ? 'Uploading…' : 'Upload new'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Grid of existing files
            Expanded(
              child: _buildFileGrid(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildFileGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _error;
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadFiles,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final files = _files;
    if (files == null || files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.animation_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              'No Lottie files yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload a new file to get started',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _LottieFileCard(
          file: file,
          onTap: () => _selectFile(file),
        );
      },
    );
  }
}

/// A card showing a single Lottie file preview in the picker grid.
class _LottieFileCard extends StatelessWidget {
  const _LottieFileCard({
    required this.file,
    required this.onTap,
  });

  final FileEntry file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = AssetServerConfig.fileUrl('lottie/feedback/${file.name}');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(7)),
                child: Lottie.network(
                  url,
                  fit: BoxFit.contain,
                  repeat: true,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 28,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                file.name,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
