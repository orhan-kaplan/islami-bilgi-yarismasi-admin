// Feature: feedback-preview-system
// Property-based tests for PreviewHelpers using glados.
//
// Tests cover category → default context mapping invariants.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/preview_helpers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/preview_tokens.dart';

// =============================================================================
// Generators
// =============================================================================

/// All valid feedback categories that have defined mappings.
const _validCategories = [
  'quiz',
  'speed_quiz',
  'time',
  'comeback',
  'streak',
  'learned',
];

/// Categories that map to quizResult context.
const _quizCategories = ['quiz', 'speed_quiz'];

/// Categories that map to dashboard context.
const _dashboardCategories = ['time', 'comeback', 'streak'];

/// Categories that map to learnedResult context.
const _learnedCategories = ['learned'];

/// Characters for generating arbitrary strings (including Turkish chars).
const _arbitraryChars =
    'abcçdefgğhıijklmnoöprsştuüvyzABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ0123456789_- ';

/// Extension on [Any] providing generators for preview helper tests.
extension PreviewHelperGenerators on Any {
  /// Generates a valid category string from the known set.
  Generator<String> get validCategory => simple(
        generate: (random, size) =>
            _validCategories[random.nextInt(_validCategories.length)],
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates an arbitrary string that is NOT one of the valid categories.
  /// This tests the fallback/default behavior.
  Generator<String> get unknownCategory => simple(
        generate: (random, size) {
          String result;
          do {
            final length = random.nextInt(size.clamp(1, 30)) + 1;
            final buffer = StringBuffer();
            for (var i = 0; i < length; i++) {
              buffer.write(
                  _arbitraryChars[random.nextInt(_arbitraryChars.length)]);
            }
            result = buffer.toString().trim();
            if (result.isEmpty) result = 'unknown_category';
          } while (_validCategories.contains(result));
          return result;
        },
        shrink: (input) sync* {
          if (input.length > 1) {
            final shorter = input.substring(0, input.length ~/ 2);
            if (!_validCategories.contains(shorter) && shorter.isNotEmpty) {
              yield shorter;
            }
          }
        },
      );

  /// Generates any category string — either valid or unknown.
  Generator<String> get anyCategory => simple(
        generate: (random, size) {
          // 70% chance of valid category, 30% chance of unknown
          if (random.nextInt(10) < 7) {
            return _validCategories[random.nextInt(_validCategories.length)];
          }
          final length = random.nextInt(size.clamp(1, 20)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            buffer.write(
                _arbitraryChars[random.nextInt(_arbitraryChars.length)]);
          }
          final result = buffer.toString().trim();
          return result.isEmpty ? 'xyz_unknown' : result;
        },
        shrink: (input) sync* {
          if (input.length > 1) yield input.substring(0, input.length ~/ 2);
        },
      );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ===========================================================================
  // Feature: feedback-preview-system, Property 1: Kategori → Varsayılan Bağlam Eşlemesi
  // ===========================================================================
  group(
    'Feature: feedback-preview-system, Property 1: Kategori → Varsayılan Bağlam Eşlemesi',
    () {
      /// **Validates: Requirements 1.3**

      Glados(any.anyCategory, ExploreConfig(numRuns: 100)).test(
        'defaultContextForCategory always returns a valid PreviewContext',
        (category) {
          final result = defaultContextForCategory(category);

          // Result must be one of the valid PreviewContext enum values
          expect(
            PreviewContext.values.contains(result),
            isTrue,
            reason:
                'defaultContextForCategory("$category") should return a valid PreviewContext, got: $result',
          );
        },
      );

      Glados(any.validCategory, ExploreConfig(numRuns: 100)).test(
        'valid categories map to their correct PreviewContext',
        (category) {
          final result = defaultContextForCategory(category);

          if (_quizCategories.contains(category)) {
            expect(
              result,
              equals(PreviewContext.quizResult),
              reason:
                  'Category "$category" should map to PreviewContext.quizResult',
            );
          } else if (_dashboardCategories.contains(category)) {
            expect(
              result,
              equals(PreviewContext.dashboard),
              reason:
                  'Category "$category" should map to PreviewContext.dashboard',
            );
          } else if (_learnedCategories.contains(category)) {
            expect(
              result,
              equals(PreviewContext.learnedResult),
              reason:
                  'Category "$category" should map to PreviewContext.learnedResult',
            );
          }
        },
      );

      Glados(any.unknownCategory, ExploreConfig(numRuns: 100)).test(
        'unknown categories fall back to PreviewContext.quizResult',
        (category) {
          final result = defaultContextForCategory(category);

          expect(
            result,
            equals(PreviewContext.quizResult),
            reason:
                'Unknown category "$category" should fall back to PreviewContext.quizResult',
          );
        },
      );
    },
  );

  // ===========================================================================
  // Feature: feedback-preview-system, Property 2: Learned Alt Kategori → Yüzde ve Vurgu Rengi Eşlemesi
  // ===========================================================================
  group(
    'Feature: feedback-preview-system, Property 2: Learned Alt Kategori → Yüzde ve Vurgu Rengi Eşlemesi',
    () {
      /// **Validates: Requirements 4.4, 4.5**

      /// The 5 valid accent colors that accentColorForPercentage can return.
      final validAccentColors = <Color>{
        PreviewTokens.learnedFeedbackGold,
        PreviewTokens.learnedFeedbackGreen,
        PreviewTokens.learnedFeedbackBlue,
        PreviewTokens.learnedFeedbackOrange,
        PreviewTokens.learnedFeedbackRed,
      };

      Glados(any.intInRange(0, 101), ExploreConfig(numRuns: 100)).test(
        'accentColorForPercentage always returns one of the 5 defined colors for 0-100',
        (percentage) {
          final result = accentColorForPercentage(percentage);

          expect(
            validAccentColors.contains(result),
            isTrue,
            reason:
                'accentColorForPercentage($percentage) returned $result which is not one of the 5 defined accent colors',
          );
        },
      );

      Glados(any.intInRange(100, 201), ExploreConfig(numRuns: 50)).test(
        'percentages >= 100 always return gold',
        (percentage) {
          final result = accentColorForPercentage(percentage);

          expect(
            result,
            equals(PreviewTokens.learnedFeedbackGold),
            reason:
                'accentColorForPercentage($percentage) should return gold for percentage >= 100',
          );
        },
      );

      Glados(any.intInRange(75, 100), ExploreConfig(numRuns: 50)).test(
        'percentages in [75, 99] always return green',
        (percentage) {
          final result = accentColorForPercentage(percentage);

          expect(
            result,
            equals(PreviewTokens.learnedFeedbackGreen),
            reason:
                'accentColorForPercentage($percentage) should return green for percentage in [75, 99]',
          );
        },
      );

      Glados(any.intInRange(50, 75), ExploreConfig(numRuns: 50)).test(
        'percentages in [50, 74] always return blue',
        (percentage) {
          final result = accentColorForPercentage(percentage);

          expect(
            result,
            equals(PreviewTokens.learnedFeedbackBlue),
            reason:
                'accentColorForPercentage($percentage) should return blue for percentage in [50, 74]',
          );
        },
      );

      Glados(any.intInRange(1, 50), ExploreConfig(numRuns: 50)).test(
        'percentages in [1, 49] always return orange',
        (percentage) {
          final result = accentColorForPercentage(percentage);

          expect(
            result,
            equals(PreviewTokens.learnedFeedbackOrange),
            reason:
                'accentColorForPercentage($percentage) should return orange for percentage in [1, 49]',
          );
        },
      );

      Glados(any.intInRange(-50, 1), ExploreConfig(numRuns: 50)).test(
        'percentages <= 0 always return red',
        (percentage) {
          final result = accentColorForPercentage(percentage);

          expect(
            result,
            equals(PreviewTokens.learnedFeedbackRed),
            reason:
                'accentColorForPercentage($percentage) should return red for percentage <= 0',
          );
        },
      );

      Glados(any.intInRange(0, 101), ExploreConfig(numRuns: 100)).test(
        'threshold boundaries are consistent — higher percentage never maps to lower-tier color',
        (percentage) {
          // For any two percentages where a > b, the color tier of a should be >= tier of b
          final color = accentColorForPercentage(percentage);
          final colorAbove = accentColorForPercentage(percentage + 1);

          final tierOf = <Color, int>{
            PreviewTokens.learnedFeedbackRed: 0,
            PreviewTokens.learnedFeedbackOrange: 1,
            PreviewTokens.learnedFeedbackBlue: 2,
            PreviewTokens.learnedFeedbackGreen: 3,
            PreviewTokens.learnedFeedbackGold: 4,
          };

          expect(
            tierOf[colorAbove]! >= tierOf[color]!,
            isTrue,
            reason:
                'accentColorForPercentage(${percentage + 1}) tier should be >= accentColorForPercentage($percentage) tier. '
                'Got tier ${tierOf[colorAbove]} for ${percentage + 1} vs tier ${tierOf[color]} for $percentage',
          );
        },
      );
    },
  );
}
