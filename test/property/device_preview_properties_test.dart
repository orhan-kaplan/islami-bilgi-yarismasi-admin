// Feature: device-preview-integration
// Property-based test for DevicePreviewService payload serialization integrity.
//
// Validates that for any random FeedbackMessageModel + PreviewContext + category
// combinations, the generated JSON payload contains all fields with correct values.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/device_preview_service.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/preview_helpers.dart';

// =============================================================================
// Generators
// =============================================================================

/// Turkish characters including special chars and common letters.
const _turkishChars =
    'abcçdefgğhıijklmnoöprsştuüvyzABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ ';

/// Emoji pool for generating realistic feedback content.
const _emojiPool = [
  '⚡', '🚀', '🌟', '✨', '🧠', '🎯', '👏', '🎉', '🚶', '🏔️',
  '👍', '📚', '💫', '🤲', '🌅', '💪', '🏋️', '☕', '🍂', '🕊️',
  '💎', '🏃‍♂️', '🌙', '🦉', '🕯️', '👋', '🤗', '🏆', '⭐', '🔥',
  '🌱', '🎓', '🐢', '🌪️',
];

/// Lottie file names for generating realistic paths.
const _lottieNames = [
  'lightning.json',
  'masallah.json',
  'harika_is.json',
  'hafiza_kuvveti.json',
  'direkten_dondu.json',
  'tebrikler.json',
  'gayet_iyisin.json',
  'fena_degil.json',
  'pes_etmek_yok.json',
  'imtihan_dunyasi.json',
];

/// Valid feedback categories.
const _validCategories = [
  'quiz',
  'speed_quiz',
  'time',
  'comeback',
  'streak',
  'learned',
];

/// Valid subcategories per category (nullable).
const _subcategoriesByCategory = <String, List<String>>{
  'quiz': ['speed_demon', 'perfect', 'one_wrong', 'two_wrong', 'good', 'moderate', 'failure'],
  'speed_quiz': ['combo_master', 'high_score', 'time_expired', 'moderate', 'low'],
  'time': ['seher', 'morning', 'noon', 'afternoon', 'evening', 'night', 'teheccud'],
  'comeback': [],
  'streak': ['3', '7', '30'],
  'learned': ['100', '75', '50', '25', '0'],
};

/// Extension on [Any] providing generators for device preview tests.
extension DevicePreviewGenerators on Any {
  /// Generates a non-empty Turkish string with special characters.
  Generator<String> get turkishString => simple(
        generate: (random, size) {
          final length = random.nextInt(size.clamp(1, 50)) + 1;
          final buffer = StringBuffer();
          for (var i = 0; i < length; i++) {
            buffer.write(_turkishChars[random.nextInt(_turkishChars.length)]);
          }
          final result = buffer.toString().trim();
          if (result.isEmpty) return 'Merhaba';
          return result;
        },
        shrink: (input) sync* {
          if (input.length > 1) yield input.substring(0, input.length ~/ 2);
        },
      );

  /// Generates an emoji from the pool.
  Generator<String> get emojiGen => simple(
        generate: (random, size) =>
            _emojiPool[random.nextInt(_emojiPool.length)],
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a nullable lottie asset path in short format (feedback/xxx.json).
  Generator<String?> get lottiePath => simple(
        generate: (random, size) {
          if (random.nextInt(3) == 0) return null; // 1/3 chance of null
          return 'feedback/${_lottieNames[random.nextInt(_lottieNames.length)]}';
        },
        shrink: (input) sync* {
          if (input != null) yield null;
        },
      );

  /// Generates a [FeedbackMessageModel].
  Generator<FeedbackMessageModel> get feedbackMessage => combine5(
        turkishString,
        turkishString,
        emojiGen,
        lottiePath,
        any.bool,
        (String title, String message, String emoji, String? lottie,
                bool shouldRepeat) =>
            FeedbackMessageModel(
          title: title,
          message: message,
          emoji: emoji,
          lottieAsset: lottie,
          shouldRepeat: shouldRepeat,
        ),
      );

  /// Generates a [PreviewContext] enum value.
  Generator<PreviewContext> get previewContext => simple(
        generate: (random, size) =>
            PreviewContext.values[random.nextInt(PreviewContext.values.length)],
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a valid category string.
  Generator<String> get category => simple(
        generate: (random, size) =>
            _validCategories[random.nextInt(_validCategories.length)],
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a nullable subcategory based on a category.
  Generator<String?> get subcategory => simple(
        generate: (random, size) {
          // 1/3 chance of null subcategory
          if (random.nextInt(3) == 0) return null;
          // Pick a random category and get a subcategory from it
          final cat =
              _validCategories[random.nextInt(_validCategories.length)];
          final subs = _subcategoriesByCategory[cat]!;
          if (subs.isEmpty) return null;
          return subs[random.nextInt(subs.length)];
        },
        shrink: (input) sync* {
          if (input != null) yield null;
        },
      );
}

// =============================================================================
// Composite input for property test
// =============================================================================

/// Holds all inputs needed for a single preview payload test iteration.
class PreviewInput {
  final FeedbackMessageModel message;
  final PreviewContext context;
  final String category;
  final String? subcategory;

  const PreviewInput({
    required this.message,
    required this.context,
    required this.category,
    required this.subcategory,
  });

  @override
  String toString() =>
      'PreviewInput(message: $message, context: $context, '
      'category: $category, subcategory: $subcategory)';
}

extension PreviewInputGenerator on Any {
  /// Generates a [PreviewInput] combining all four random components.
  Generator<PreviewInput> get previewInput => combine4(
        feedbackMessage,
        previewContext,
        category,
        subcategory,
        (FeedbackMessageModel msg, PreviewContext ctx, String cat,
                String? sub) =>
            PreviewInput(
          message: msg,
          context: ctx,
          category: cat,
          subcategory: sub,
        ),
      );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  // ===========================================================================
  // Property 4: Preview Payload Serileştirme Bütünlüğü
  // ===========================================================================
  group(
    'Feature: device-preview-integration, Property 4: Preview Payload Serileştirme Bütünlüğü',
    () {
      /// **Validates: Requirements 1.1, 2.2**

      Glados(any.previewInput, ExploreConfig(numRuns: 100)).test(
        'generated JSON payload contains all fields with correct values',
        (input) async {
          final message = input.message;
          final context = input.context;
          final category = input.category;
          final subcategory = input.subcategory;

          // Capture the request body sent by DevicePreviewService
          late Map<String, dynamic> capturedPayload;
          final mockClient = MockClient((request) async {
            capturedPayload =
                jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{"status": "ok"}', 200);
          });

          final service = DevicePreviewService(client: mockClient);

          await service.sendPreview(
            message: message,
            screenContext: context,
            category: category,
            subcategory: subcategory,
          );

          // Verify all fields match the input values
          expect(capturedPayload['title'], equals(message.title),
              reason: 'title should match');
          expect(capturedPayload['message'], equals(message.message),
              reason: 'message should match');
          expect(capturedPayload['emoji'], equals(message.emoji),
              reason: 'emoji should match');
          expect(capturedPayload['lottieAsset'], equals(message.lottieAsset),
              reason: 'lottieAsset should match');
          expect(capturedPayload['shouldRepeat'], equals(message.shouldRepeat),
              reason: 'shouldRepeat should match');
          expect(capturedPayload['screenContext'], equals(context.name),
              reason: 'screenContext should match enum name');
          expect(capturedPayload['category'], equals(category),
              reason: 'category should match');
          expect(capturedPayload['subcategory'], equals(subcategory),
              reason: 'subcategory should match');

          service.dispose();
        },
      );
    },
  );
}
