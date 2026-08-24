import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/asset_server_client.dart';
import '../../../data/services/audio_playback.dart';
import '../../providers/asset_providers.dart';
import '../../providers/asset_server_providers.dart';
import '../../providers/connectivity_providers.dart';
import '../../../core/constants/asset_server_config.dart';
import 'asset_error_view.dart';

/// Audio tab for the Assets screen.
///
/// Displays a list of audio files from the `audio/` directory with
/// filename, play/pause button, Replace, and Delete buttons.
class AudioTab extends ConsumerStatefulWidget {
  const AudioTab({super.key});

  @override
  ConsumerState<AudioTab> createState() => _AudioTabState();
}

class _AudioTabState extends ConsumerState<AudioTab>
    with AutomaticKeepAliveClientMixin {
  static const _allowedExtensions = ['mp3', 'wav', 'm4a', 'ogg'];

  /// Currently playing audio file path (null if nothing is playing).
  String? _playingPath;

  /// Duraklatılmış dosya — tekrar Play'e basınca baştan değil kaldığı
  /// yerden devam etmesi için tutuluyor.
  String? _pausedPath;

  /// `dispose` sırasında `ref` okunamıyor; oynatıcıya baştan tutunuyoruz.
  late final AudioPlayback _player;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _player = ref.read(audioPlaybackProvider);
  }

  @override
  void dispose() {
    _player.stop();
    super.dispose();
  }

  void _resetPlayback() {
    _player.stop();
    _playingPath = null;
    _pausedPath = null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _playAudio(FileEntry entry) {
    if (_pausedPath == entry.path) {
      _player.resume();
      setState(() {
        _playingPath = entry.path;
        _pausedPath = null;
      });
      return;
    }

    _player.play(
      AssetServerConfig.fileUrl(entry.path),
      onEnded: () {
        if (!mounted) return;
        setState(() {
          _playingPath = null;
          _pausedPath = null;
        });
      },
      // Oynatma başarısız olduğunda buton kalıcı olarak Pause'da kalıyordu.
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _playingPath = null;
          _pausedPath = null;
        });
        _showMessage('Could not play ${entry.name}.');
      },
    );

    setState(() {
      _playingPath = entry.path;
      _pausedPath = null;
    });
  }

  void _pauseAudio() {
    _player.pause();
    setState(() {
      _pausedPath = _playingPath;
      _playingPath = null;
    });
  }

  void _invalidateList() {
    ref.invalidate(assetListProvider);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filesAsync = ref.watch(assetListProvider('audio'));
    final isConnected = ref.watch(isServerConnectedProvider);

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
              OfflineTooltip(
                isConnected: isConnected,
                child: FilledButton.icon(
                  onPressed: isConnected ? _addNewAudio : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Audio'),
                ),
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
            error: (error, _) => AssetErrorView(
              error: error,
              onRetry: () => ref.invalidate(assetListProvider),
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
        _showMessage('Added ${file.name}');
      }
    } catch (e) {
      _showMessage(assetErrorMessage(e));
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
        if (_playingPath == entry.path || _pausedPath == entry.path) {
          setState(_resetPlayback);
        }
        _invalidateList();
        _showMessage('Replaced ${entry.name}');
      }
    } catch (e) {
      _showMessage(assetErrorMessage(e));
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
      if (_playingPath == entry.path || _pausedPath == entry.path) {
        setState(_resetPlayback);
      }
      await client.deleteFile(entry.path);
      if (mounted) {
        _invalidateList();
        _showMessage('Deleted ${entry.name}');
      }
    } catch (e) {
      _showMessage(assetErrorMessage(e));
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
