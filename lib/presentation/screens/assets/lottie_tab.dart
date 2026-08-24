import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../data/services/asset_reference_detector.dart';
import '../../../data/services/asset_server_client.dart';
import '../../providers/asset_providers.dart';
import '../../providers/asset_server_providers.dart';
import '../../providers/connectivity_providers.dart';
import '../../providers/feedback_content_providers.dart';
import '../../providers/game_config_providers.dart';
import '../../../core/constants/asset_server_config.dart';
import 'asset_error_view.dart';

/// Lottie tab for the Assets screen.
///
/// Displays Lottie animation files in two groups: root-level files from
/// `lottie/` and feedback subfolder files from `lottie/feedback/`.
/// Each card shows a live animation preview. Clicking a card opens a larger
/// preview dialog with Replace/Delete actions.
class LottieTab extends ConsumerStatefulWidget {
  const LottieTab({super.key});

  @override
  ConsumerState<LottieTab> createState() => _LottieTabState();
}

class _LottieTabState extends ConsumerState<LottieTab>
    with AutomaticKeepAliveClientMixin {
  int _cacheBuster = DateTime.now().millisecondsSinceEpoch;

  @override
  bool get wantKeepAlive => true;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _invalidateAndRefresh() {
    ref.invalidate(assetListProvider);
    setState(() {
      _cacheBuster = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final rootAsync = ref.watch(assetListProvider('lottie'));
    final feedbackAsync = ref.watch(assetListProvider('lottie/feedback'));
    final isConnected = ref.watch(isServerConnectedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Text(
                'Lottie Animations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              OfflineTooltip(
                isConnected: isConnected,
                child: FilledButton.icon(
                  onPressed:
                      isConnected ? () => _addNewLottie('lottie') : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Lottie'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Root Level section
                _buildSection(
                  context,
                  title: 'Root Level',
                  subtitle: 'lottie/',
                  asyncValue: rootAsync,
                  directory: 'lottie',
                  isConnected: isConnected,
                ),
                const SizedBox(height: 24),
                // Feedback section
                _buildSection(
                  context,
                  title: 'Feedback',
                  subtitle: 'lottie/feedback/',
                  asyncValue: feedbackAsync,
                  directory: 'lottie/feedback',
                  isConnected: isConnected,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required AsyncValue<List<FileEntry>> asyncValue,
    required String directory,
    required bool isConnected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const Spacer(),
            if (directory == 'lottie/feedback')
              OfflineTooltip(
                isConnected: isConnected,
                child: TextButton.icon(
                  onPressed:
                      isConnected ? () => _addNewLottie(directory) : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add to Feedback'),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        asyncValue.when(
          data: (entries) {
            final files =
                entries.where((e) => e.type == 'file').toList();
            if (files.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No Lottie files found')),
              );
            }
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: files.map((entry) {
                return _LottieCard(
                  entry: entry,
                  cacheBuster: _cacheBuster,
                  onTap: () => _showPreviewDialog(entry),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: AssetErrorView(
              error: error,
              onRetry: () => ref.invalidate(assetListProvider),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPreviewDialog(FileEntry entry) async {
    if (!mounted) return;
    final url =
        AssetServerConfig.fileUrl(entry.path, cacheBuster: _cacheBuster);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.name),
        content: SizedBox(
          width: 400,
          height: 400,
          child: Lottie.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.error_outline, size: 64),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _replaceLottie(entry);
            },
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Replace'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteLottie(entry);
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewLottie(String directory) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null || file.name.isEmpty) return;

    // Validate Lottie structure
    final validationError = _validateLottieStructure(file.bytes!);
    if (validationError != null) {
      if (!mounted) return;
      await _showValidationErrorDialog(validationError);
      return;
    }

    final client = ref.read(assetServerClientProvider);
    final apiPath = '$directory/${file.name}';

    try {
      await client.createFile(apiPath, file.bytes!);
      if (mounted) {
        _invalidateAndRefresh();
        _showMessage('Added ${file.name}');
      }
    } catch (e) {
      _showMessage(assetErrorMessage(e));
    }
  }

  Future<void> _replaceLottie(FileEntry entry) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    // Validate Lottie structure
    final validationError = _validateLottieStructure(file.bytes!);
    if (validationError != null) {
      if (!mounted) return;
      await _showValidationErrorDialog(validationError);
      return;
    }

    final client = ref.read(assetServerClientProvider);

    try {
      await client.putFile(entry.path, file.bytes!);
      if (mounted) {
        _invalidateAndRefresh();
        _showMessage('Replaced ${entry.name}');
      }
    } catch (e) {
      _showMessage(assetErrorMessage(e));
    }
  }

  Future<void> _deleteLottie(FileEntry entry) async {
    if (!mounted) return;

    // Feedback mesajları ve game_config slotları bu dosyayı adıyla çağırıyor;
    // silinirse uygulama çalışırken eksik animasyonla patlar.
    final references = AssetReferenceDetector.findLottieReferences(
      ref.read(feedbackContentProvider),
      ref.read(gameConfigProvider),
      entry.path,
    );
    if (references.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${entry.name} is referenced by the following items:'),
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

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lottie Animation'),
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
        _showMessage('Deleted ${entry.name}');
      }
    } catch (e) {
      _showMessage(assetErrorMessage(e));
    }
  }

  /// Validates that the given bytes represent a valid Lottie JSON structure.
  ///
  /// Returns `null` if valid, or an error message describing missing fields.
  String? _validateLottieStructure(List<int> bytes) {
    try {
      final content = utf8.decode(bytes);
      final json = jsonDecode(content);
      if (json is! Map<String, dynamic>) {
        return 'File is not a valid JSON object.';
      }

      final missingFields = <String>[];
      if (!json.containsKey('v')) missingFields.add('v (version)');
      if (!json.containsKey('layers')) missingFields.add('layers');
      if (!json.containsKey('w')) missingFields.add('w (width)');
      if (!json.containsKey('h')) missingFields.add('h (height)');

      if (missingFields.isNotEmpty) {
        return 'Invalid Lottie file. Missing required fields:\n'
            '${missingFields.map((f) => '• $f').join('\n')}';
      }

      return null;
    } on FormatException {
      return 'File is not valid JSON.';
    } catch (e) {
      return 'Failed to parse file: $e';
    }
  }

  Future<void> _showValidationErrorDialog(String error) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Lottie File'),
        content: Text(error),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Card widget displaying a Lottie animation preview with filename.
class _LottieCard extends StatelessWidget {
  const _LottieCard({
    required this.entry,
    required this.cacheBuster,
    required this.onTap,
  });

  final FileEntry entry;
  final int cacheBuster;
  final VoidCallback onTap;

  String get _animationUrl =>
      AssetServerConfig.fileUrl(entry.path, cacheBuster: cacheBuster);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 200,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Lottie.network(
                    _animationUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(
                      child: Icon(Icons.animation_outlined, size: 48),
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  entry.name,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
