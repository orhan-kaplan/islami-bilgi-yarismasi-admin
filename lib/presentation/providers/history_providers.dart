import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/content_state.dart';
import 'content_providers.dart';

// =============================================================================
// History State
// =============================================================================

/// Immutable state holding undo and redo stacks of ContentState snapshots.
class HistoryState {
  final List<ContentState> undoStack;
  final List<ContentState> redoStack;

  const HistoryState({
    this.undoStack = const [],
    this.redoStack = const [],
  });

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  HistoryState copyWith({
    List<ContentState>? undoStack,
    List<ContentState>? redoStack,
  }) {
    return HistoryState(
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }
}

// =============================================================================
// History Notifier
// =============================================================================

/// Manages undo/redo stacks of ContentState snapshots.
///
/// Call [pushState] BEFORE applying a change to ContentNotifier.
/// This pushes the current state onto the undo stack and clears the redo stack.
class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier() : super(const HistoryState());

  /// Maximum number of entries in the undo stack.
  static const int maxHistory = 50;

  /// Pushes [currentState] onto the undo stack and clears the redo stack.
  /// If the undo stack exceeds [maxHistory], the oldest entry is discarded.
  void pushState(ContentState currentState) {
    final newUndoStack = [...state.undoStack, currentState];
    // Enforce max history limit — discard oldest entries.
    final trimmed = newUndoStack.length > maxHistory
        ? newUndoStack.sublist(newUndoStack.length - maxHistory)
        : newUndoStack;
    state = HistoryState(
      undoStack: trimmed,
      redoStack: const [],
    );
  }

  /// Restores the previous state from the undo stack.
  ///
  /// Pushes [currentState] onto the redo stack and returns the restored state.
  /// No-op if the undo stack is empty.
  ContentState? undo(ContentState currentState) {
    if (!state.canUndo) return null;
    final newUndoStack = List<ContentState>.from(state.undoStack);
    final restored = newUndoStack.removeLast();
    state = HistoryState(
      undoStack: newUndoStack,
      redoStack: [...state.redoStack, currentState],
    );
    return restored;
  }

  /// Restores the next state from the redo stack.
  ///
  /// Pushes [currentState] onto the undo stack and returns the restored state.
  /// No-op if the redo stack is empty.
  ContentState? redo(ContentState currentState) {
    if (!state.canRedo) return null;
    final newRedoStack = List<ContentState>.from(state.redoStack);
    final restored = newRedoStack.removeLast();
    state = HistoryState(
      undoStack: [...state.undoStack, currentState],
      redoStack: newRedoStack,
    );
    return restored;
  }

  /// Clears both undo and redo stacks (called on import).
  void clear() {
    state = const HistoryState();
  }
}

// =============================================================================
// Providers
// =============================================================================

/// Provider for the history notifier managing undo/redo stacks.
final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>(
  (ref) => HistoryNotifier(),
);

/// Whether undo is available.
final canUndoProvider = Provider<bool>((ref) {
  return ref.watch(historyProvider).canUndo;
});

/// Whether redo is available.
final canRedoProvider = Provider<bool>((ref) {
  return ref.watch(historyProvider).canRedo;
});

/// Holds the last imported/exported ContentState for dirty comparison.
final savedBaselineProvider = StateProvider<ContentState?>((ref) => null);

/// Whether the current content state differs from the saved baseline.
///
/// Returns `false` if no baseline has been set (e.g. empty/fresh state).
final isDirtyProvider = Provider<bool>((ref) {
  final baseline = ref.watch(savedBaselineProvider);
  final current = ref.watch(contentStateProvider);
  if (baseline == null) return false;
  return current != baseline;
});

/// Whether the JSON preview panel is visible in the Content Explorer.
final jsonPreviewVisibleProvider = StateProvider<bool>((ref) => false);
