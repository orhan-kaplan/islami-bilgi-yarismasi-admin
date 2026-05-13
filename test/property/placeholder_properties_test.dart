// Feature: feedback-preview-system, Property 3: Boş Alan Placeholder Gösterimi
//
// Property-based tests verifying that empty title/message fields always show
// placeholder text, and non-empty fields never show placeholder text.
//
// **Validates: Requirements 8.3**
//
// Since QuizResultPreview is a widget, we use glados generators to produce
// random FeedbackMessageModel instances and verify placeholder behavior
// within testWidgets calls.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/quiz_result_preview.dart';

// =============================================================================
// Generators
// =============================================================================

/// Characters for generating arbitrary non-empty strings.
const _arbitraryChars =
    'abcçdefgğhıijklmnoöprsştuüvyzABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ0123456789 ';

/// Emoji characters for the emoji field.
const _emojis = ['🎉', '🏆', '⭐', '👋', '🔥', '📚', '💪', '😊', '🌟', '✨'];

/// Generates a random non-empty string.
String _randomNonEmptyString(Random random, {int maxLength = 30}) {
  final length = random.nextInt(maxLength) + 1;
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(_arbitraryChars[random.nextInt(_arbitraryChars.length)]);
  }
  return buffer.toString();
}

/// Generates a random emoji.
String _randomEmoji(Random random) => _emojis[random.nextInt(_emojis.length)];

/// Generates a random FeedbackMessageModel with the given title/message emptiness.
FeedbackMessageModel _generateModel(
  Random random, {
  required bool emptyTitle,
  required bool emptyMessage,
}) {
  return FeedbackMessageModel(
    title: emptyTitle ? '' : _randomNonEmptyString(random),
    message: emptyMessage ? '' : _randomNonEmptyString(random),
    emoji: _randomEmoji(random),
  );
}

extension PlaceholderGenerators on Any {
  /// Generates a FeedbackMessageModel with an empty title and non-empty message.
  Generator<FeedbackMessageModel> get modelWithEmptyTitle => simple(
        generate: (random, size) => _generateModel(
          random,
          emptyTitle: true,
          emptyMessage: false,
        ),
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a FeedbackMessageModel with a non-empty title and empty message.
  Generator<FeedbackMessageModel> get modelWithEmptyMessage => simple(
        generate: (random, size) => _generateModel(
          random,
          emptyTitle: false,
          emptyMessage: true,
        ),
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a FeedbackMessageModel with both title and message empty.
  Generator<FeedbackMessageModel> get modelWithBothEmpty => simple(
        generate: (random, size) => FeedbackMessageModel(
          title: '',
          message: '',
          emoji: _randomEmoji(random),
        ),
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a FeedbackMessageModel with both title and message non-empty.
  Generator<FeedbackMessageModel> get modelWithBothFilled => simple(
        generate: (random, size) => _generateModel(
          random,
          emptyTitle: false,
          emptyMessage: false,
        ),
        shrink: (input) => const Iterable.empty(),
      );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ===========================================================================
  // Feature: feedback-preview-system, Property 3: Boş Alan Placeholder Gösterimi
  // ===========================================================================
  group(
    'Feature: feedback-preview-system, Property 3: Boş Alan Placeholder Gösterimi',
    () {
      /// **Validates: Requirements 8.3**

      const numRuns = 100;
      final random = Random(42); // Fixed seed for reproducibility

      // Generate test data upfront
      final emptyTitleModels = List.generate(
        numRuns,
        (_) => _generateModel(random, emptyTitle: true, emptyMessage: false),
      );
      final emptyMessageModels = List.generate(
        numRuns,
        (_) => _generateModel(random, emptyTitle: false, emptyMessage: true),
      );
      final bothEmptyModels = List.generate(
        numRuns,
        (_) => FeedbackMessageModel(
          title: '',
          message: '',
          emoji: _randomEmoji(random),
        ),
      );
      final bothFilledModels = List.generate(
        numRuns,
        (_) => _generateModel(random, emptyTitle: false, emptyMessage: false),
      );

      testWidgets(
        'empty title always shows title placeholder, never shows message placeholder',
        (tester) async {
          for (final model in emptyTitleModels) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 320,
                    height: 693,
                    child: QuizResultPreview(
                      message: model,
                      subcategory: 'perfect',
                    ),
                  ),
                ),
              ),
            );

            // Title placeholder should be shown
            expect(
              find.text('(Başlık girilmemiş)'),
              findsOneWidget,
              reason:
                  'Empty title should show "(Başlık girilmemiş)" placeholder. '
                  'Model: $model',
            );

            // Message placeholder should NOT be shown (message is non-empty)
            expect(
              find.text('(Mesaj girilmemiş)'),
              findsNothing,
              reason:
                  'Non-empty message should NOT show "(Mesaj girilmemiş)" placeholder. '
                  'Model: $model',
            );
          }
        },
      );

      testWidgets(
        'empty message always shows message placeholder, never shows title placeholder',
        (tester) async {
          for (final model in emptyMessageModels) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 320,
                    height: 693,
                    child: QuizResultPreview(
                      message: model,
                      subcategory: 'perfect',
                    ),
                  ),
                ),
              ),
            );

            // Message placeholder should be shown
            expect(
              find.text('(Mesaj girilmemiş)'),
              findsOneWidget,
              reason:
                  'Empty message should show "(Mesaj girilmemiş)" placeholder. '
                  'Model: $model',
            );

            // Title placeholder should NOT be shown (title is non-empty)
            expect(
              find.text('(Başlık girilmemiş)'),
              findsNothing,
              reason:
                  'Non-empty title should NOT show "(Başlık girilmemiş)" placeholder. '
                  'Model: $model',
            );
          }
        },
      );

      testWidgets(
        'both empty fields always show both placeholders',
        (tester) async {
          for (final model in bothEmptyModels) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 320,
                    height: 693,
                    child: QuizResultPreview(
                      message: model,
                      subcategory: 'perfect',
                    ),
                  ),
                ),
              ),
            );

            // Both placeholders should be shown
            expect(
              find.text('(Başlık girilmemiş)'),
              findsOneWidget,
              reason:
                  'Empty title should show "(Başlık girilmemiş)" placeholder. '
                  'Model: $model',
            );
            expect(
              find.text('(Mesaj girilmemiş)'),
              findsOneWidget,
              reason:
                  'Empty message should show "(Mesaj girilmemiş)" placeholder. '
                  'Model: $model',
            );
          }
        },
      );

      testWidgets(
        'non-empty fields never show any placeholder',
        (tester) async {
          for (final model in bothFilledModels) {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 320,
                    height: 693,
                    child: QuizResultPreview(
                      message: model,
                      subcategory: 'perfect',
                    ),
                  ),
                ),
              ),
            );

            // No placeholders should be shown
            expect(
              find.text('(Başlık girilmemiş)'),
              findsNothing,
              reason:
                  'Non-empty title should NOT show "(Başlık girilmemiş)" placeholder. '
                  'Model: $model',
            );
            expect(
              find.text('(Mesaj girilmemiş)'),
              findsNothing,
              reason:
                  'Non-empty message should NOT show "(Mesaj girilmemiş)" placeholder. '
                  'Model: $model',
            );
          }
        },
      );
    },
  );
}
