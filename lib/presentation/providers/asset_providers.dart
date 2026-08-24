import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/asset_server_client.dart';
import '../../data/services/audio_playback.dart';
import 'asset_server_providers.dart';

/// Provider that lists directory contents from the asset server.
///
/// Takes an API_Path (e.g., 'images', 'audio') and returns the list of
/// [FileEntry] items in that directory.
final assetListProvider =
    FutureProvider.family<List<FileEntry>, String>((ref, path) async {
  final client = ref.watch(assetServerClientProvider);
  return client.listDirectory(path);
});

/// Ses önizlemesini çalan oynatıcı.
///
/// Testler oynatma durumunu gerçek tarayıcı sesi olmadan doğrulayabilsin
/// diye provider üzerinden veriliyor.
final audioPlaybackProvider = Provider<AudioPlayback>(
  (ref) => WebAudioPlayback(),
);
