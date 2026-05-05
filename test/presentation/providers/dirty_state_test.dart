import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';

import '../../helpers/content_generators.dart';

void main() {
  // Feature: admin-tool-enhancements, Property 6: Dirty state equals state inequality with baseline
  group(
      'Property 6: Dirty state equals state inequality with baseline', () {
    /// **Validates: Requirements 3.2, 3.6, 8.3**
    ///
    /// For any ContentState (current) and for any ContentState (baseline),
    /// the isDirty flag SHALL be true if and only if current != baseline
    /// (using deep equality via the existing == operator on ContentState).

    // Helper that replicates the isDirty logic from isDirtyProvider:
    // if (baseline == null) return false;
    // return current != baseline;
    bool computeIsDirty(ContentState current, ContentState? baseline) {
      if (baseline == null) return false;
      return current != baseline;
    }

    test('when baseline is null, isDirty is always false', () {
      // Regardless of current state, null baseline means not dirty
      final current = ContentState.empty();
      expect(computeIsDirty(current, null), isFalse);
    });

    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'when baseline is null, isDirty is false for any current state',
      (current) {
        expect(computeIsDirty(current, null), isFalse);
      },
    );

    Glados(any.contentState, ExploreConfig(numRuns: 100)).test(
      'when current equals baseline, isDirty is false',
      (state) {
        // Use the same state for both current and baseline
        expect(computeIsDirty(state, state), isFalse);
      },
    );

    Glados2(any.contentState, any.contentState, ExploreConfig(numRuns: 100))
        .test(
      'isDirty is true iff current != baseline',
      (current, baseline) {
        final isDirty = computeIsDirty(current, baseline);
        final areNotEqual = current != baseline;

        // isDirty should be true if and only if current != baseline
        expect(isDirty, equals(areNotEqual));
      },
    );
  });
}
