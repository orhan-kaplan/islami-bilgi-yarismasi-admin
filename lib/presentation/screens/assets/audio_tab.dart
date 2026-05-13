import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../data/services/asset_server_client.dart';
import '../../providers/asset_providers.dart';
import '../../providers/asset_server_providers.dart';

/// Audio tab for the Assets screen.
///
/// Displays a list of audio files from the `audio/` directory with
/// filename, play/pause button, Replace, and Delete buttons.
class AudioTab extends ConsumerStatefulWidget {
  const AudioTab({super.key});

  @override
  ConsumerState<AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends ConsumerState<AudioTab> {
  static const _allowedExtensions = ['mp3', 'wav', 'm4a', 'ogg'];

  /// Currently playing audio file path (null if nothing is playing).
  String? _playingPath;

  /// The HTML audio element used for browser playback.
  web.HTMLAudioElement? _audioElement;

  @override
  void dispose() {
    _stopAudio();
    super.dispose();
  }

  void _stopAudio() {
    _audioElement?.pause();
    _audioElement = null;
    _playingPath = null;
  }

  void _playAudio(FileEntry entry) {
    // Stop any currently playing audio
    _audioElement?.pause();

    final url = 'http://localhost:8080/api/files/${entry.path}';
    final audio = web.HTMLAudioElement()..src = url;

    audio.onEnded.listen((_) {
      if (mounted) {
        setState(() {
          _playingPath = null;
          _audioElement = null;
        });
      }
    });

    audio.play();
    setState(() {
      _playingPath = entry.path;
      _audioElement = audio;
    });
  }

  void _pauseAudio() {
    _audioElement?.pause();
    setState(() {
      _playingPath = null;
      _audioElement = null;
    });
  }

  void _invalidateList() {
    ref.invalidate(assetListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(assetListProvider('audio'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Text(
                'Audio Files',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _addNewAudio,
                icon: const Icon(Icons.add),
                label: const Text('Add New Audio'),
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
                  child: Text('No audio files found'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: files.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = files[index];
                  final isPlaying = _playingPath == entry.path;
                  return _AudioRow(
                    entry: entry,
                    isPlaying: isPlaying,
                    onPlay: () => _playAudio(entry),
                    onPause: _pauseAudio,
                    onReplace: () => _replaceAudio(entry),
                    onDelete: () => _deleteAudio(entry),
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

  Future<void> _addNewAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null || file.name.isEmpty) return;

    final client = ref.read(assetServerClientProvider);
    final apiPath = 'audio/${file.name}';

    try {
      await client.createFile(apiPath, file.bytes!);
      if (mounted) {
        _invalidateList();
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

  Future<void> _replaceAudio(FileEntry entry) async {
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
        // Stop playback if replacing the currently playing file
        if (_playingPath == entry.path) {
          _stopAudio();
          setState(() {});
        }
        _invalidateList();
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

  Future<void> _deleteAudio(FileEntry entry) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Audio'),
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
      // Stop playback if deleting the currently playing file
      if (_playingPath == entry.path) {
        _stopAudio();
        setState(() {});
      }
      await client.deleteFile(entry.path);
      if (mounted) {
        _invalidateList();
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

/// A single row in the audio file list.
class _AudioRow extends StatelessWidget {
  const _AudioRow({
    required this.entry,
    required this.isPlaying,
    required this.onPlay,
    required this.onPause,
    required this.onReplace,
    required this.onDelete,
  });

  final FileEntry entry;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  String get _formattedSize {
    final bytes = entry.size;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
          size: 36,
          color: isPlaying
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        tooltip: isPlaying ? 'Pause' : 'Play',
        onPressed: isPlaying ? onPause : onPlay,
      ),
      title: Text(entry.name),
      subtitle: Text(_formattedSize),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Replace',
            onPressed: onReplace,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
