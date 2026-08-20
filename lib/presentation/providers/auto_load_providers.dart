import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/content_state.dart';
import '../../data/services/json_parser.dart';
import 'asset_server_providers.dart';
import 'connectivity_providers.dart';
import 'content_providers.dart';
import 'history_providers.dart';

// =============================================================================
// Auto-Load Status
// =============================================================================

/// Status of the auto-load sequence.
enum AutoLoadStatus { idle, loading, loaded, failed }

// =============================================================================
// Auto-Load Notifier
// =============================================================================

/// Manages the startup auto-load sequence that fetches all JSON data files
/// from the asset server and populates ContentState.
///
/// The auto-load is triggered when server connectivity becomes [ServerConnectivity.connected]
/// for the first time. It performs the following sequence:
/// 1. Check health
/// 2. List `data/` directory
/// 3. Fetch `data/series.json`, `data/books.json`, `data/rewards.json`, `data/hadiths.json`
/// 4. List `data/content/`
/// 5. Fetch every `.json` file under `data/content/`
/// 6. Parse and populate ContentState
/// 7. Set saved baseline and clear undo/redo history
class AutoLoadNotifier extends StateNotifier<AutoLoadStatus> {
  AutoLoadNotifier(this._ref) : super(AutoLoadStatus.idle) {
    _listenForConnection();
  }

  final Ref _ref;
  bool _hasLoadedOnce = false;
  bool _loadedFromServer = false;

  /// Whether the auto-load has completed successfully at least once.
  bool get hasLoadedOnce => _hasLoadedOnce;

  /// Whether the in-memory session came from GET, not a ZIP / local keep.
  ///
  /// First connect after a ZIP import must not look like a cold start: the
  /// reconnect dialog uses this to offer Save vs Reload.
  bool get loadedFromServer => _loadedFromServer;

  /// Listens for the first time server connectivity becomes connected.
  void _listenForConnection() {
    // Check current state immediately
    final currentConnectivity = _ref.read(serverConnectivityProvider);
    if (currentConnectivity == ServerConnectivity.connected && !_hasLoadedOnce) {
      _performAutoLoad();
      return;
    }

    // Listen for future changes
    _ref.listen<ServerConnectivity>(
      serverConnectivityProvider,
      (previous, next) {
        if (next == ServerConnectivity.connected && !_hasLoadedOnce) {
          _performAutoLoad();
        }
      },
    );
  }

  /// Performs the full auto-load sequence.
  ///
  /// [force] is for Retry / "Reload from Server". Without it, an in-memory
  /// ZIP or locally created tree is left alone so the first `connected`
  /// transition cannot wipe the fallback session.
  Future<void> performAutoLoad({bool force = false}) async {
    await _performAutoLoad(force: force);
  }

  /// Marks the session as loaded without fetching (ZIP import / keep-local).
  ///
  /// Enables auto-save and hides the failed banner. Does not claim the
  /// bytes on disk match memory — [loadedFromServer] stays false.
  void markSessionLoaded() {
    _hasLoadedOnce = true;
    if (mounted) {
      state = AutoLoadStatus.loaded;
    }
  }

  /// After a successful flush of local work onto the server.
  void markSyncedToServer() {
    _hasLoadedOnce = true;
    _loadedFromServer = true;
    if (mounted && state != AutoLoadStatus.loading) {
      state = AutoLoadStatus.loaded;
    }
  }

  Future<void> _performAutoLoad({bool force = false}) async {
    if (state == AutoLoadStatus.loading) return;

    if (!force && _ref.read(contentStateProvider).hasAnyContent) {
      _hasLoadedOnce = true;
      if (mounted) {
        state = AutoLoadStatus.loaded;
      }
      return;
    }

    state = AutoLoadStatus.loading;

    try {
      final client = _ref.read(assetServerClientProvider);
      final parser = JsonParser();

      // 1. Check health
      await client.health();

      // 2. Fetch core data files
      final seriesJson = await client.getFileAsString('data/series.json');
      final booksJson = await client.getFileAsString('data/books.json');
      final rewardsJson = await client.getFileAsString('data/rewards.json');
      final hadithsJson = await client.getFileAsString('data/hadiths.json');

      // 3. Parse core data
      final series = parser.parseSeries(seriesJson);
      final books = parser.parseBooks(booksJson);
      final rewards = parser.parseRewards(rewardsJson);
      final hadiths = parser.parseHadiths(hadithsJson);

      // 4. List content directory and fetch all content files
      final contentEntries = await client.listDirectory('data/content');
      final contentFiles = <String, dynamic>{};

      for (final entry in contentEntries) {
        if (entry.type == 'file' && entry.name.endsWith('.json')) {
          final contentJson =
              await client.getFileAsString('data/content/${entry.name}');
          final levels = parser.parseContentFile(contentJson);
          contentFiles[entry.name] = levels;
        }
      }

      // 5. Construct ContentState
      final loadedState = ContentState(
        series: series,
        books: books,
        contentFiles: Map.from(contentFiles),
        rewards: rewards,
        hadiths: hadiths,
      );

      // 6. Populate ContentState
      _ref.read(contentStateProvider.notifier).importContent(loadedState);

      // 7. Set saved baseline
      _ref.read(savedBaselineProvider.notifier).state = loadedState;

      // 8. Clear undo/redo history
      _ref.read(historyProvider.notifier).clear();

      _hasLoadedOnce = true;
      _loadedFromServer = true;

      if (mounted) {
        state = AutoLoadStatus.loaded;
      }
    } catch (e) {
      if (mounted) {
        state = AutoLoadStatus.failed;
      }
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provider for the auto-load notifier that manages startup data loading.
final autoLoadProvider =
    StateNotifierProvider<AutoLoadNotifier, AutoLoadStatus>(
  (ref) => AutoLoadNotifier(ref),
);

/// Convenience provider exposing just the auto-load status.
final autoLoadStatusProvider = Provider<AutoLoadStatus>((ref) {
  return ref.watch(autoLoadProvider);
});

/// Whether auto-load has completed successfully (used to gate auto-save).
final autoLoadCompleteProvider = Provider<bool>((ref) {
  return ref.watch(autoLoadProvider) == AutoLoadStatus.loaded;
});
