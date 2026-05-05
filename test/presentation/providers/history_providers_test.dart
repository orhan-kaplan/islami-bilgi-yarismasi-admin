import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group;
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/history_providers.dart';

import '../../helpers/content_generators.dart';

void main() {
  // Feature: admin-tool-enhancements, Property 3: Undo restores previous state and pushes current to redo
  group('Property 3: Undo restores previous state and pushes current to redo',
      () {
    /// **Validates: Requirements 2.2**
    ///
    /// For any HistoryState with a non-empty undo stack and for any current
    /// ContentState, triggering undo SHALL set the current state to the top of
    /// the undo stack, remove that entry from the undo stack, and push the
    /// previous current state onto the redo stack.
    Glados2(any.contentState, any.contentState, ExploreConfig(numRuns: 100))
        .test(
      'undo restores previous state from undo stack and pushes current to redo',
      (previousState, currentState) {
        // 1. Create a HistoryNotifier
        final notifier = HistoryNotifier();

        // 2. Push previousState onto the undo stack
        notifier.pushState(previousState);

        // Verify precondition: undo stack has previousState at the top
        expect(notifier.state.undoStack.length, equals(1));
        expect(notifier.state.undoStack.last, equals(previousState));
        expect(notifier.state.redoStack, isEmpty);

        // 3. Call undo(currentState)
        final restored = notifier.undo(currentState);

        // 4. Verify the returned state equals previousState
        expect(restored, equals(previousState));

        // 5. Verify currentState was pushed to the redo stack
        expect(notifier.state.redoStack.length, equals(1));
        expect(notifier.state.redoStack.last, equals(currentState));

        // 6. Verify the undo stack is now empty
        expect(notifier.state.undoStack, isEmpty);
      },
    );
  });

  // Feature: admin-tool-enhancements, Property 4: Redo restores next state and pushes current to undo
  group('Property 4: Redo restores next state and pushes current to undo', () {
    /// **Validates: Requirements 2.3**
    ///
    /// For any HistoryState with a non-empty redo stack and for any current
    /// ContentState, triggering redo SHALL set the current state to the top of
    /// the redo stack, remove that entry from the redo stack, and push the
    /// previous current state onto the undo stack.
    Glados2(any.contentState, any.contentState, ExploreConfig(numRuns: 100))
        .test(
      'redo restores next state from redo stack and pushes current to undo',
      (stateOnRedoStack, currentBeforeRedo) {
        // 1. Create a HistoryNotifier
        final notifier = HistoryNotifier();

        // 2. Set up a non-empty redo stack:
        //    Push stateOnRedoStack onto undo stack, then undo to move it to redo.
        //    After pushState(stateOnRedoStack): undo=[stateOnRedoStack], redo=[]
        //    After undo(stateOnRedoStack): undo=[], redo=[stateOnRedoStack]
        //    (undo pops stateOnRedoStack from undo, returns it, pushes the
        //     argument stateOnRedoStack onto redo)
        notifier.pushState(stateOnRedoStack);
        // Now undo stack = [stateOnRedoStack], redo stack = []
        // Call undo with a dummy current — we use stateOnRedoStack itself
        // so that redo stack ends up with [stateOnRedoStack]
        notifier.undo(stateOnRedoStack);
        // After undo: undo=[], redo=[stateOnRedoStack]

        // Verify precondition: redo stack has stateOnRedoStack
        expect(notifier.state.redoStack.length, equals(1));
        expect(notifier.state.redoStack.last, equals(stateOnRedoStack));
        expect(notifier.state.undoStack, isEmpty);

        // 3. Call redo(currentBeforeRedo)
        final restored = notifier.redo(currentBeforeRedo);

        // 4. Verify the returned state equals stateOnRedoStack (top of redo stack)
        expect(restored, equals(stateOnRedoStack));

        // 5. Verify currentBeforeRedo was pushed to the undo stack
        expect(notifier.state.undoStack.length, equals(1));
        expect(notifier.state.undoStack.last, equals(currentBeforeRedo));

        // 6. Verify the redo stack is now empty
        expect(notifier.state.redoStack, isEmpty);
      },
    );
  });

  // Feature: admin-tool-enhancements, Property 2: Committed operation pushes previous state and clears redo
  group(
      'Property 2: Committed operation pushes previous state and clears redo',
      () {
    /// **Validates: Requirements 2.1, 2.4**
    ///
    /// For any ContentState and for any committed edit operation (add, update,
    /// delete, reorder, bulk add), the History_Manager SHALL push the
    /// pre-operation state onto the undo stack AND clear the redo stack entirely.
    Glados2(any.contentState, any.contentState, ExploreConfig(numRuns: 100))
        .test(
      'pushState adds to undo stack and clears redo stack',
      (initialState, newState) {
        // 1. Create a HistoryNotifier
        final notifier = HistoryNotifier();

        // 2. Set up a non-empty redo stack:
        //    Push initialState onto undo, then undo to populate redo.
        notifier.pushState(initialState);
        // undo stack = [initialState], redo stack = []
        notifier.undo(initialState);
        // undo stack = [], redo stack = [initialState]

        // Verify precondition: redo stack is non-empty
        expect(notifier.state.redoStack, isNotEmpty);
        expect(notifier.state.redoStack.length, equals(1));

        // 3. Call pushState(newState) — simulating a committed operation
        notifier.pushState(newState);

        // 4. Verify newState was added to the undo stack
        expect(notifier.state.undoStack, isNotEmpty);
        expect(notifier.state.undoStack.last, equals(newState));

        // 5. Verify the redo stack is now empty (cleared)
        expect(notifier.state.redoStack, isEmpty);
      },
    );
  });

  // Feature: admin-tool-enhancements, Property 5: Undo stack is bounded at 50 entries
  group('Property 5: Undo stack is bounded at 50 entries', () {
    /// **Validates: Requirements 2.5, 2.6**
    ///
    /// For any sequence of N committed operations (where N > 50), the undo
    /// stack length SHALL never exceed 50, and the oldest entries SHALL be
    /// discarded first (FIFO eviction from the bottom).
    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'pushing >50 states keeps stack at 50 and discards oldest',
      (baseState) {
        final notifier = HistoryNotifier();
        const totalPushes = 55;

        // Create 55 distinct states by varying the series list
        final states = List.generate(totalPushes, (i) {
          return baseState.copyWith(
            series: [
              ...baseState.series,
              SeriesModel(
                id: 9000 + i,
                name: 'Generated_$i',
                sortOrder: i + 1,
                isLocked: false,
                iconEmoji: '📖',
              ),
            ],
          );
        });

        // Push all 55 states
        for (final state in states) {
          notifier.pushState(state);
        }

        // 1. Verify the undo stack never exceeds 50
        expect(notifier.state.undoStack.length, equals(50));

        // 2. Verify the oldest entries were discarded (first 5 pushed states gone)
        // The first 5 states (indices 0-4) should NOT be in the stack
        for (var i = 0; i < 5; i++) {
          expect(notifier.state.undoStack.contains(states[i]), isFalse,
              reason: 'State at index $i should have been evicted');
        }

        // 3. Verify the most recent 50 states are preserved (indices 5-54)
        for (var i = 5; i < totalPushes; i++) {
          expect(
            notifier.state.undoStack[i - 5],
            equals(states[i]),
            reason: 'State at index $i should be at stack position ${i - 5}',
          );
        }
      },
    );
  });
}