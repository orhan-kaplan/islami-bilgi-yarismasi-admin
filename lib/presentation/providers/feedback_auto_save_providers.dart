import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/feedback_models.dart';
import 'asset_server_providers.dart';
import 'connectivity_providers.dart';
import 'feedback_content_providers.dart';

// =============================================================================
// Feedback Save Status
// =============================================================================

/// Status of the feedback auto-save system.
enum FeedbackSaveStatus { idle, saving, saved, error }

// =============================================================================
// FeedbackAutoSaveController
// =============================================================================

/// Lifecycle-aware controller that manages debounced auto-save for feedback content.
///
/// Listens to [feedbackContentProvider] state changes, debounces for 2 seconds,
/// then serializes and saves `data/feedback.json` to the asset server.
///
/// The controller:
/// 1. Only starts listening AFTER [feedbackLoadProvider] is loaded or empty
/// 2. Only saves when [isServerConnectedProvider] is true
/// 3. On state change: starts/resets a 2-second debounce timer
/// 4. When timer fires: validates data, then serializes and PUTs to server
/// 5. Blocks save if validation fails (errors exist)
/// 6. Tracks save status: idle → saving → saved (or error)
class FeedbackAutoSaveController extends StateNotifier<FeedbackSaveStatus> {
  FeedbackAutoSaveController(this._ref) : super(FeedbackSaveStatus.idle) {
    _init();
  }

  final Ref _ref;
  Timer? _debounceTimer;
  bool _hasPendingChange = false;

  bool get hasPendingChange => _hasPendingChange;

  static const Duration _debounceDuration = Duration(seconds: 2);

  /// Initializes the controller by waiting for feedback load to complete,
  /// then starts listening to feedback content state changes.
  void _init() {
    if (_isReady(_ref.read(feedbackLoadProvider))) {
      _startListening();
      return;
    }

    // Wait for feedback load to complete
    _ref.listen<FeedbackLoadStatus>(feedbackLoadProvider, (previous, next) {
      if (_isReady(next) && !_isReady(previous)) {
        _startListening();
      }
    });
  }

  /// Sunucudan okuma bittiğinde auto-save dinlemeye başlayabilir.
  ///
  /// [FeedbackLoadStatus.empty] de hazır sayılır: `feedback.json` sunucuda
  /// yokken kullanıcının oluşturduğu ilk veri aksi halde hiç kaydedilmiyordu.
  bool _isReady(FeedbackLoadStatus? status) =>
      status == FeedbackLoadStatus.loaded || status == FeedbackLoadStatus.empty;

  /// Starts listening to feedback content state changes.
  void _startListening() {
    _ref.listen<FeedbackContentState>(feedbackContentProvider,
        (previous, next) {
      if (previous == null) return;
      _onContentChanged();
    });
  }

  /// Schedules a debounced save when content changes.
  ///
  /// Bağlantı yokken de işaretlenir; yazma [_saveFile] içinde yine bağlantıya
  /// bakar. Aksi halde bağlantı kopukken yapılan düzenleme hiç kuyruğa
  /// girmiyor, yeniden bağlanınca da kaydedilmiyordu.
  void _onContentChanged() {
    _hasPendingChange = true;
    // Cancel existing timer and start a new one
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _saveFile();
    });
  }

  /// Saves feedback.json to the server.
  ///
  /// Before saving, runs validation. If errors exist, the save is blocked.
  Future<void> _saveFile() async {
    _debounceTimer = null;

    // Double-check connectivity before saving
    if (!_ref.read(isServerConnectedProvider)) return;

    final contentState = _ref.read(feedbackContentProvider);

    // Validate before saving — block save if validation fails
    final errors = await validateFeedbackData(contentState);
    if (errors.isNotEmpty) {
      _hasPendingChange = true;
      if (mounted) {
        state = FeedbackSaveStatus.error;
      }
      return;
    }

    _hasPendingChange = false;

    if (mounted) {
      state = FeedbackSaveStatus.saving;
    }

    try {
      final client = _ref.read(assetServerClientProvider);
      final jsonString =
          const JsonEncoder.withIndent('  ').convert(contentState.toJson());
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      await client.putFile('data/feedback.json', bytes);

      if (mounted) {
        state = FeedbackSaveStatus.saved;
        // Reset to idle after a brief delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && state == FeedbackSaveStatus.saved) {
            state = FeedbackSaveStatus.idle;
          }
        });
      }
    } catch (_) {
      // Yazım başarısız oldu: değişikliği kuyrukta tut, yoksa sonraki flush
      // "pending yok" diye hemen döner ve düzenleme tarayıcı belleğinde kalır.
      _hasPendingChange = true;
      if (mounted) {
        state = FeedbackSaveStatus.error;
      }
    }
  }

  /// Flushes any pending debounced save immediately.
  ///
  /// Called by Ctrl/Cmd+S to force-save pending changes without
  /// waiting for the debounce timer to expire.
  /// [force] writes even when no debounce flag is set (reconnect Save after
  /// a ZIP import that auto-save never observed).
  Future<void> flushPendingSave({bool force = false}) async {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    if (!force && !_hasPendingChange) return;

    // Don't save if server is not connected
    if (!_ref.read(isServerConnectedProvider)) return;

    await _saveFile();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _hasPendingChange = false;
    super.dispose();
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provider for the feedback auto-save controller that manages debounced saves.
final feedbackAutoSaveProvider =
    StateNotifierProvider<FeedbackAutoSaveController, FeedbackSaveStatus>(
  (ref) => FeedbackAutoSaveController(ref),
);

/// Convenience provider exposing just the feedback save status.
final feedbackSaveStatusProvider = Provider<FeedbackSaveStatus>((ref) {
  return ref.watch(feedbackAutoSaveProvider);
});
