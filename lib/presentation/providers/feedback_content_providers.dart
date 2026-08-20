import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/feedback_models.dart';
import '../../data/services/asset_server_client.dart';
import '../../data/services/feedback_validator.dart';
import 'asset_server_providers.dart';
import 'connectivity_providers.dart';

/// StateNotifier managing all feedback content state with CRUD operations
/// for messages and titles, deletion guards, and sorted title maintenance.
class FeedbackContentNotifier extends StateNotifier<FeedbackContentState> {
  FeedbackContentNotifier([FeedbackContentState? initialState])
      : super(initialState ?? FeedbackContentState.empty());

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Replaces the entire state with a new imported state.
  void importContent(FeedbackContentState newState) {
    state = newState;
  }

  // ---------------------------------------------------------------------------
  // Server Loading
  // ---------------------------------------------------------------------------

  /// Loads feedback content from the asset server by reading `data/feedback.json`.
  ///
  /// On success, replaces the current state with the parsed content.
  /// On file-not-found (404), sets state to [FeedbackContentState.empty()].
  /// Throws on other errors (network, parse) so callers can handle them.
  Future<void> loadFromServer(AssetServerClient client) async {
    try {
      final jsonString = await client.getFileAsString('data/feedback.json');
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final loadedState = FeedbackContentState.fromJson(jsonMap);
      if (mounted) {
        state = loadedState;
      }
    } on AssetServerException catch (e) {
      if (e.statusCode == 404) {
        // File not found — set empty state so UI can show "create initial data" option
        if (mounted) {
          state = FeedbackContentState.empty();
        }
      } else {
        rethrow;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Message CRUD
  // ---------------------------------------------------------------------------

  /// Adds a message to the specified category/subcategory list.
  ///
  /// [category] is one of: "quiz", "speed_quiz", "time", "comeback", "streak", "learned"
  /// [subcategory] is the nested key (e.g., "speed_demon", "seher") or null for flat categories.
  void addMessage(
    String category,
    String? subcategory,
    FeedbackMessageModel message,
  ) {
    switch (category) {
      case 'comeback':
        state = state.copyWith(comeback: [...state.comeback, message]);
        break;
      default:
        final map = _getMessageMap(category);
        if (map == null) return;
        final key = subcategory ?? '';
        final currentList = map[key] ?? [];
        final updatedMap = Map<String, List<FeedbackMessageModel>>.from(map);
        updatedMap[key] = [...currentList, message];
        _setMessageMap(category, updatedMap);
        break;
    }
  }

  /// Replaces the message at [index] in the specified category/subcategory list.
  void updateMessage(
    String category,
    String? subcategory,
    int index,
    FeedbackMessageModel message,
  ) {
    switch (category) {
      case 'comeback':
        final newList = List<FeedbackMessageModel>.from(state.comeback);
        if (index >= 0 && index < newList.length) {
          newList[index] = message;
          state = state.copyWith(comeback: newList);
        }
        break;
      default:
        final map = _getMessageMap(category);
        if (map == null) return;
        final key = subcategory ?? '';
        final currentList = map[key];
        if (currentList == null) return;
        if (index < 0 || index >= currentList.length) return;
        final newList = List<FeedbackMessageModel>.from(currentList);
        newList[index] = message;
        final updatedMap = Map<String, List<FeedbackMessageModel>>.from(map);
        updatedMap[key] = newList;
        _setMessageMap(category, updatedMap);
        break;
    }
  }

  /// Removes the message at [index] without minimum-count check.
  /// Used when cancelling a newly created (empty) message.
  void removeMessage(String category, String? subcategory, int index) {
    switch (category) {
      case 'comeback':
        final newList = List<FeedbackMessageModel>.from(state.comeback);
        if (index < 0 || index >= newList.length) return;
        newList.removeAt(index);
        state = state.copyWith(comeback: newList);
        break;
      default:
        final map = _getMessageMap(category);
        if (map == null) return;
        final key = subcategory ?? '';
        final currentList = map[key];
        if (currentList == null) return;
        if (index < 0 || index >= currentList.length) return;
        final newList = List<FeedbackMessageModel>.from(currentList);
        newList.removeAt(index);
        final updatedMap = Map<String, List<FeedbackMessageModel>>.from(map);
        updatedMap[key] = newList;
        _setMessageMap(category, updatedMap);
        break;
    }
  }

  /// Removes the message at [index] from the specified category/subcategory list.
  ///
  /// Returns `false` if the list has only 1 item (deletion rejected to maintain
  /// at least one message per category). Returns `true` on successful deletion.
  bool deleteMessage(
    String category,
    String? subcategory,
    int index,
  ) {
    switch (category) {
      case 'comeback':
        if (state.comeback.length <= 1) return false;
        final newList = List<FeedbackMessageModel>.from(state.comeback);
        if (index < 0 || index >= newList.length) return false;
        newList.removeAt(index);
        state = state.copyWith(comeback: newList);
        return true;
      default:
        final map = _getMessageMap(category);
        if (map == null) return false;
        final key = subcategory ?? '';
        final currentList = map[key];
        if (currentList == null) return false;
        if (currentList.length <= 1) return false;
        if (index < 0 || index >= currentList.length) return false;
        final newList = List<FeedbackMessageModel>.from(currentList);
        newList.removeAt(index);
        final updatedMap = Map<String, List<FeedbackMessageModel>>.from(map);
        updatedMap[key] = newList;
        _setMessageMap(category, updatedMap);
        return true;
    }
  }

  // ---------------------------------------------------------------------------
  // Message Reordering
  // ---------------------------------------------------------------------------

  /// Reorders a message within a subcategory list from [oldIndex] to [newIndex].
  void reorderMessage(String category, String? subcategory, int oldIndex, int newIndex) {
    switch (category) {
      case 'comeback':
        final newList = List<FeedbackMessageModel>.from(state.comeback);
        if (oldIndex < 0 || oldIndex >= newList.length) return;
        if (newIndex < 0 || newIndex >= newList.length) return;
        final item = newList.removeAt(oldIndex);
        newList.insert(newIndex, item);
        state = state.copyWith(comeback: newList);
        break;
      default:
        final map = _getMessageMap(category);
        if (map == null) return;
        final key = subcategory ?? '';
        final currentList = map[key];
        if (currentList == null) return;
        if (oldIndex < 0 || oldIndex >= currentList.length) return;
        if (newIndex < 0 || newIndex >= currentList.length) return;
        final newList = List<FeedbackMessageModel>.from(currentList);
        final item = newList.removeAt(oldIndex);
        newList.insert(newIndex, item);
        final updatedMap = Map<String, List<FeedbackMessageModel>>.from(map);
        updatedMap[key] = newList;
        _setMessageMap(category, updatedMap);
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Title CRUD
  // ---------------------------------------------------------------------------

  /// Adds a title if its [title.requiredBooks] value is unique among existing titles.
  ///
  /// Returns `false` if a title with the same `required_books` already exists
  /// (addition rejected). Returns `true` on successful addition.
  /// Titles are re-sorted by `required_books` after insertion.
  bool addTitle(PlayerTitleModel title) {
    final duplicate =
        state.titles.any((t) => t.requiredBooks == title.requiredBooks);
    if (duplicate) return false;
    final newTitles = [...state.titles, title];
    newTitles.sort((a, b) => a.requiredBooks.compareTo(b.requiredBooks));
    state = state.copyWith(titles: newTitles);
    return true;
  }

  /// Updates the title at [index] with a new [title] value.
  /// Titles are re-sorted by `required_books` after update.
  void updateTitle(int index, PlayerTitleModel title) {
    final newTitles = List<PlayerTitleModel>.from(state.titles);
    if (index < 0 || index >= newTitles.length) return;
    newTitles[index] = title;
    newTitles.sort((a, b) => a.requiredBooks.compareTo(b.requiredBooks));
    state = state.copyWith(titles: newTitles);
  }

  /// Removes the title at [index].
  ///
  /// Returns `false` if the list has only 1 item (deletion rejected to maintain
  /// at least one title). Returns `true` on successful deletion.
  bool deleteTitle(int index) {
    if (state.titles.length <= 1) return false;
    final newTitles = List<PlayerTitleModel>.from(state.titles);
    if (index < 0 || index >= newTitles.length) return false;
    newTitles.removeAt(index);
    state = state.copyWith(titles: newTitles);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Returns the message map for the given category, or null if invalid.
  Map<String, List<FeedbackMessageModel>>? _getMessageMap(String category) {
    switch (category) {
      case 'quiz':
        return state.quiz;
      case 'speed_quiz':
        return state.speedQuiz;
      case 'time':
        return state.time;
      case 'streak':
        return state.streak;
      case 'learned':
        return state.learned;
      default:
        return null;
    }
  }

  /// Sets the message map for the given category on the state.
  void _setMessageMap(
    String category,
    Map<String, List<FeedbackMessageModel>> updatedMap,
  ) {
    switch (category) {
      case 'quiz':
        state = state.copyWith(quiz: updatedMap);
        break;
      case 'speed_quiz':
        state = state.copyWith(speedQuiz: updatedMap);
        break;
      case 'time':
        state = state.copyWith(time: updatedMap);
        break;
      case 'streak':
        state = state.copyWith(streak: updatedMap);
        break;
      case 'learned':
        state = state.copyWith(learned: updatedMap);
        break;
    }
  }
}

// =============================================================================
// Schema Validation
// =============================================================================

/// Validates a [FeedbackContentState] for schema correctness.
///
/// Checks:
/// - All required top-level categories are present and non-empty
/// - Each category has the correct subcategories with at least one message each
/// - All `lottie_asset` paths (if set) are lottie-relative (not `assets/...`)
/// - Optionally verifies lottie file existence via [client] if provided
///
/// Returns a list of validation error messages. An empty list means the data is valid.
Future<List<String>> validateFeedbackData(
  FeedbackContentState state, {
  AssetServerClient? client,
}) async {
  final errors = validateFeedbackSchema(state);

  if (client != null) {
    await _validateLottieFilesExist(state, client, errors);
  }

  return errors;
}

/// Validates that lottie files referenced in the state exist on the asset server.
Future<void> _validateLottieFilesExist(
  FeedbackContentState state,
  AssetServerClient client,
  List<String> errors,
) async {
  final lottiePaths = <String>{};

  void collectPaths(List<FeedbackMessageModel> messages) {
    for (final msg in messages) {
      if (msg.lottieAsset != null && msg.lottieAsset!.isNotEmpty) {
        lottiePaths.add(msg.lottieAsset!);
      }
    }
  }

  // Collect all unique lottie paths
  for (final list in state.quiz.values) {
    collectPaths(list);
  }
  for (final list in state.speedQuiz.values) {
    collectPaths(list);
  }
  for (final list in state.time.values) {
    collectPaths(list);
  }
  collectPaths(state.comeback);
  for (final list in state.streak.values) {
    collectPaths(list);
  }
  for (final list in state.learned.values) {
    collectPaths(list);
  }

  // Check each unique path exists on the server
  for (final path in lottiePaths) {
    try {
      // lottie_asset is relative to assets/lottie/ (feedback/file.json or trophy_2.json)
      await client.getFile('lottie/$path');
    } on AssetServerException catch (e) {
      if (e.statusCode == 404) {
        errors.add('Lottie file not found on server: lottie/$path');
      }
    } catch (e) {
      errors.add('Error checking lottie file "lottie/$path": $e');
    }
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Core mutable state provider for all feedback content.
final feedbackContentProvider =
    StateNotifierProvider<FeedbackContentNotifier, FeedbackContentState>(
  (ref) => FeedbackContentNotifier(),
);

// =============================================================================
// Feedback Load Status
// =============================================================================

/// Status of the feedback data loading from the asset server.
enum FeedbackLoadStatus { idle, loading, loaded, empty, failed }

/// Manages loading feedback content from the asset server.
///
/// Triggered when server connectivity becomes [ServerConnectivity.connected].
/// On success, populates [feedbackContentProvider] with parsed data.
/// On file-not-found (404), sets status to [FeedbackLoadStatus.empty] so the UI
/// can show a "create initial data" option.
class FeedbackLoadNotifier extends StateNotifier<FeedbackLoadStatus> {
  FeedbackLoadNotifier(this._ref) : super(FeedbackLoadStatus.idle) {
    _listenForConnection();
  }

  final Ref _ref;
  bool _hasLoadedOnce = false;

  /// Listens for the first time server connectivity becomes connected.
  void _listenForConnection() {
    final currentConnectivity = _ref.read(serverConnectivityProvider);
    if (currentConnectivity == ServerConnectivity.connected && !_hasLoadedOnce) {
      _performLoad();
      return;
    }

    _ref.listen<ServerConnectivity>(
      serverConnectivityProvider,
      (previous, next) {
        if (next == ServerConnectivity.connected && !_hasLoadedOnce) {
          _performLoad();
        }
      },
    );
  }

  /// Performs the feedback data load from the asset server.
  ///
  /// [force] is the Retry / Reload button. Without it, in-memory ZIP content
  /// is kept so the first `connected` fetch cannot wipe it.
  Future<void> performLoad({bool force = false}) async {
    await _performLoad(force: force);
  }

  Future<void> _performLoad({bool force = false}) async {
    if (state == FeedbackLoadStatus.loading) return;

    if (!force) {
      final current = _ref.read(feedbackContentProvider);
      if (current != FeedbackContentState.empty()) {
        _hasLoadedOnce = true;
        if (mounted) {
          state = FeedbackLoadStatus.loaded;
        }
        return;
      }
    }

    state = FeedbackLoadStatus.loading;

    try {
      final client = _ref.read(assetServerClientProvider);
      final notifier = _ref.read(feedbackContentProvider.notifier);

      await notifier.loadFromServer(client);

      _hasLoadedOnce = true;

      if (mounted) {
        // Check if the loaded state is empty (file not found case)
        final loadedState = _ref.read(feedbackContentProvider);
        if (loadedState == FeedbackContentState.empty()) {
          state = FeedbackLoadStatus.empty;
        } else {
          state = FeedbackLoadStatus.loaded;
        }
      }
    } on AssetServerException {
      if (mounted) {
        state = FeedbackLoadStatus.failed;
      }
    } catch (_) {
      if (mounted) {
        state = FeedbackLoadStatus.failed;
      }
    }
  }

  /// Sunucuda `feedback.json` yokken kullanıcı ilk veriyi oluşturduğunda
  /// çağrılır: status [FeedbackLoadStatus.empty]'de kalırsa ekran boş-durum
  /// placeholder'ını göstermeye devam eder ve sekmeler hiç açılmaz.
  void markLoaded() {
    if (!mounted) return;
    _hasLoadedOnce = true;
    state = FeedbackLoadStatus.loaded;
  }

  /// Whether the feedback data has been loaded successfully at least once.
  bool get hasLoadedOnce => _hasLoadedOnce;
}

/// Provider for the feedback load notifier that manages loading from the asset server.
final feedbackLoadProvider =
    StateNotifierProvider<FeedbackLoadNotifier, FeedbackLoadStatus>(
  (ref) => FeedbackLoadNotifier(ref),
);

/// Whether feedback data needs initial creation (file not found on server).
final feedbackNeedsInitialDataProvider = Provider<bool>((ref) {
  return ref.watch(feedbackLoadProvider) == FeedbackLoadStatus.empty;
});
