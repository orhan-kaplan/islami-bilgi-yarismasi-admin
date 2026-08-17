import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/content_state.dart';
import '../../data/services/asset_server_client.dart';
import '../../data/services/content_file_mapping.dart';
import '../../data/services/json_serializer.dart';
import '../../data/services/save_gating.dart';
import 'asset_server_providers.dart';
import 'auto_load_providers.dart';
import 'connectivity_providers.dart';
import 'content_providers.dart';
import 'history_providers.dart';
import 'validation_providers.dart';

// =============================================================================
// Save Status
// =============================================================================

/// Status of the auto-save system.
enum SaveStatus { idle, saving, saved, error }

// =============================================================================
// AutoSaveController
// =============================================================================

/// Lifecycle-aware controller that manages debounced auto-save.
///
/// Listens to [contentStateProvider] changes, diffs against previous state to
/// determine affected files, debounces per-file (2s), then serializes and saves
/// each changed file to the asset server.
///
/// The controller:
/// 1. Only starts listening AFTER [autoLoadCompleteProvider] is true
/// 2. Only saves when [isServerConnectedProvider] is true
/// 3. On content change: determines which files changed using [getChangedFiles]
/// 4. For each changed file: starts/resets a 2-second debounce timer
/// 5. When timer fires: serializes the relevant data and PUTs to server
/// 6. Tracks save status: idle → saving → saved (or error)
/// 7. [flushPendingSaves]: cancels all timers and immediately saves all pending
/// 8. On successful save: merges that file's slice into [savedBaselineProvider]
class AutoSaveController extends StateNotifier<SaveStatus> {
  AutoSaveController(this._ref) : super(SaveStatus.idle) {
    _init();
  }

  final Ref _ref;
  final Map<String, Timer> _debounceTimers = {};
  final Set<String> _pendingFiles = {};
  final JsonSerializer _serializer = JsonSerializer();

  static const Duration _debounceDuration = Duration(seconds: 2);

  /// Initializes the controller by waiting for auto-load to complete,
  /// then starts listening to content state changes.
  void _init() {
    // If auto-load is already complete, start listening immediately
    final autoLoadComplete = _ref.read(autoLoadCompleteProvider);
    if (autoLoadComplete) {
      _startListening();
      return;
    }

    // Otherwise, wait for auto-load to complete
    _ref.listen<bool>(autoLoadCompleteProvider, (previous, next) {
      if (next == true && previous != true) {
        _startListening();
      }
    });
  }

  /// Starts listening to content state changes.
  void _startListening() {
    _ref.listen<ContentState>(contentStateProvider, (previous, next) {
      if (previous == null) return;
      _onContentChanged(previous, next);
    });
  }

  /// Determines which files changed and schedules debounced saves.
  void _onContentChanged(ContentState previous, ContentState current) {
    // Don't schedule saves if server is not connected
    if (!_ref.read(isServerConnectedProvider)) return;

    final changedFiles = getChangedFiles(previous, current);

    for (final filePath in changedFiles) {
      _pendingFiles.add(filePath);
      // Cancel existing timer for this file and start a new one
      _debounceTimers[filePath]?.cancel();
      _debounceTimers[filePath] = Timer(_debounceDuration, () {
        _saveFile(filePath);
      });
    }
  }

  /// Saves a single file to the server.
  ///
  /// Before saving, checks for ERROR-level validation issues for the target
  /// file. If errors exist, the save is blocked and the file remains pending.
  Future<void> _saveFile(String apiPath) async {
    _debounceTimers.remove(apiPath);

    // Double-check connectivity before saving
    if (!_ref.read(isServerConnectedProvider)) return;

    // Check validation: block save if ERROR-level issues exist for this file
    final validationIssues = _ref.read(validationResultsProvider);
    if (!isSaveAllowedForFile(apiPath, validationIssues)) {
      // Keep the file in pending so it can be retried later
      _pendingFiles.add(apiPath);
      if (mounted) {
        state = SaveStatus.error;
      }
      return;
    }

    _pendingFiles.remove(apiPath);

    if (mounted) {
      state = SaveStatus.saving;
    }

    try {
      final client = _ref.read(assetServerClientProvider);
      final contentState = _ref.read(contentStateProvider);

      if (await _writeFile(client, apiPath, contentState)) {
        _mergeSavedFileIntoBaseline(apiPath, contentState);
      }

      if (mounted) {
        state = SaveStatus.saved;
        // Reset to idle after a brief delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && state == SaveStatus.saved) {
            state = SaveStatus.idle;
          }
        });
      }
    } catch (_) {
      // Keep the file pending so a later flush can retry it. Dropping it here
      // would strand the edit in browser memory with no way to re-save.
      _pendingFiles.add(apiPath);
      if (mounted) {
        state = SaveStatus.error;
      }
    }
  }

  /// Writes one file to the server; returns whether it was handled.
  ///
  /// A content file that is no longer in [contentState] belongs to a deleted
  /// book, so it is deleted from the server rather than written — otherwise it
  /// stays on disk, ships inside the app bundle, and reappears on the next
  /// auto-load.
  Future<bool> _writeFile(
    AssetServerClient client,
    String apiPath,
    ContentState contentState,
  ) async {
    final bytes = _serializeForPath(apiPath, contentState);
    if (bytes != null) {
      await client.putFile(apiPath, bytes);
      return true;
    }

    if (_isRemovedContentFile(apiPath, contentState)) {
      try {
        await client.deleteFile(apiPath);
      } on AssetServerException catch (e) {
        // Already absent on the server — that is the state we wanted.
        if (e.statusCode != 404) rethrow;
      }
      return true;
    }

    return false;
  }

  /// Whether [apiPath] points at a content file that the state no longer has.
  bool _isRemovedContentFile(String apiPath, ContentState contentState) {
    const contentPrefix = 'data/content/';
    if (!apiPath.startsWith(contentPrefix)) return false;
    final key = apiPath.substring(contentPrefix.length);
    return key.isNotEmpty && !contentState.contentFiles.containsKey(key);
  }

  /// Merges only the saved file's slice into the dirty-state baseline.
  ///
  /// Skips the update when no baseline exists yet (auto-load has not
  /// completed). Does not replace the entire baseline with [savedState],
  /// which would hide unsaved changes in other files.
  void _mergeSavedFileIntoBaseline(String apiPath, ContentState savedState) {
    final baseline = _ref.read(savedBaselineProvider);
    if (baseline == null) return;
    _ref.read(savedBaselineProvider.notifier).state =
        mergeSavedFileIntoBaseline(baseline, savedState, apiPath);
  }

  /// Serializes the appropriate content for the given API path.
  Uint8List? _serializeForPath(String apiPath, ContentState contentState) {
    String? jsonString;

    if (apiPath == 'data/series.json') {
      jsonString = _serializer.serializeSeries(contentState.series);
    } else if (apiPath == 'data/books.json') {
      jsonString = _serializer.serializeBooks(contentState.books);
    } else if (apiPath == 'data/rewards.json') {
      jsonString = _serializer.serializeRewards(contentState.rewards);
    } else if (apiPath == 'data/hadiths.json') {
      jsonString = _serializer.serializeHadiths(contentState.hadiths);
    } else if (apiPath.startsWith('data/content/')) {
      final key = apiPath.replaceFirst('data/content/', '');
      final levels = contentState.contentFiles[key];
      if (levels != null) {
        jsonString = _serializer.serializeContentFile(levels);
      }
    }

    if (jsonString == null) return null;
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Flushes all pending debounced saves immediately.
  ///
  /// Called by Ctrl/Cmd+S to force-save all pending changes without
  /// waiting for debounce timers to expire.
  ///
  /// Files with ERROR-level validation issues are skipped and remain pending.
  Future<void> flushPendingSaves() async {
    // Cancel all timers
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    // Collect all pending files and clear the set
    final filesToSave = Set<String>.from(_pendingFiles);
    _pendingFiles.clear();

    if (filesToSave.isEmpty) return;

    // Don't save if server is not connected
    if (!_ref.read(isServerConnectedProvider)) return;

    // Filter out files that have ERROR-level validation issues
    final validationIssues = _ref.read(validationResultsProvider);
    final blockedFiles = <String>{};
    for (final apiPath in filesToSave) {
      if (!isSaveAllowedForFile(apiPath, validationIssues)) {
        blockedFiles.add(apiPath);
      }
    }

    // Keep blocked files in pending for later retry
    _pendingFiles.addAll(blockedFiles);
    final allowedFiles = filesToSave.difference(blockedFiles);

    if (allowedFiles.isEmpty) {
      if (blockedFiles.isNotEmpty && mounted) {
        state = SaveStatus.error;
      }
      return;
    }

    if (mounted) {
      state = SaveStatus.saving;
    }

    final client = _ref.read(assetServerClientProvider);
    final contentState = _ref.read(contentStateProvider);
    final failedFiles = <String>{};

    for (final apiPath in allowedFiles) {
      try {
        if (await _writeFile(client, apiPath, contentState)) {
          _mergeSavedFileIntoBaseline(apiPath, contentState);
        }
      } catch (_) {
        // One rejected file must not cancel the rest of the batch.
        failedFiles.add(apiPath);
      }
    }

    // Failed writes stay pending so the next flush retries them.
    _pendingFiles.addAll(failedFiles);

    if (!mounted) return;

    if (failedFiles.isNotEmpty) {
      state = SaveStatus.error;
      return;
    }

    state = SaveStatus.saved;
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && state == SaveStatus.saved) {
        state = SaveStatus.idle;
      }
    });
  }

  @override
  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _pendingFiles.clear();
    super.dispose();
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provider for the auto-save controller that manages debounced saves.
final autoSaveControllerProvider =
    StateNotifierProvider<AutoSaveController, SaveStatus>(
  (ref) => AutoSaveController(ref),
);

/// Convenience provider exposing just the save status.
final saveStatusProvider = Provider<SaveStatus>((ref) {
  return ref.watch(autoSaveControllerProvider);
});
