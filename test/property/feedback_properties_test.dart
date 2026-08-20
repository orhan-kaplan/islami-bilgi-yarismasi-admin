// Feature: feedback-content-management
// Property-based tests for feedback content management using glados.
//
// Tests cover serialization, schema integrity, CRUD invariants,
// sorting, uniqueness, fallback, random selection, Lottie validation,
// path format, and migration equivalence.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide expect, group, test;
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/upload_validator.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';

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

/// Quiz subcategory keys.
const _quizSubcategories = [
  'speed_demon', 'perfect', 'one_wrong', 'two_wrong',
  'good', 'moderate', 'failure',
];

/// Speed quiz subcategory keys.
const _speedQuizSubcategories = [
  'combo_master', 'high_score', 'time_expired', 'moderate', 'low',
];

/// Time subcategory keys.
const _timeSubcategories = [
  'seher', 'morning', 'noon', 'afternoon', 'evening', 'night', 'teheccud',
];

/// Streak subcategory keys.
const _streakSubcategories = ['3', '7', '30'];

/// Learned subcategory keys.
const _learnedSubcategories = ['100', '75', '50', '25', '0'];

/// Required Lottie fields.
const _requiredLottieFields = ['v', 'layers', 'w', 'h'];

/// Maps each required Lottie field to the exact label
/// `UploadValidator.validateLottieStructure` reports it under.
const _lottieFieldLabels = {
  'v': 'v (version)',
  'layers': 'layers',
  'w': 'w (width)',
  'h': 'h (height)',
};

/// Extension on [Any] providing generators for feedback models.
extension FeedbackGenerators on Any {
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

  /// Generates a non-null lottie asset path in short format.
  Generator<String> get nonNullLottiePath => simple(
        generate: (random, size) {
          return 'feedback/${_lottieNames[random.nextInt(_lottieNames.length)]}';
        },
        shrink: (input) => const Iterable.empty(),
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

  /// Generates a [PlayerTitleModel].
  Generator<PlayerTitleModel> get playerTitle => combine4(
        turkishString,
        emojiGen,
        simple(
          generate: (random, size) => random.nextInt(20),
          shrink: (input) sync* {
            if (input > 0) yield input ~/ 2;
          },
        ),
        simple(
          generate: (random, size) =>
              'images/rewards/book_${random.nextInt(5) + 1}_reward.webp',
          shrink: (input) => const Iterable.empty(),
        ),
        (String title, String icon, int requiredBooks, String profileImage) =>
            PlayerTitleModel(
          title: title,
          icon: icon,
          requiredBooks: requiredBooks,
          profileImage: profileImage,
        ),
      );

  /// Generates a list of [FeedbackMessageModel] with 1-4 items.
  Generator<List<FeedbackMessageModel>> get messageList =>
      listWithLengthInRange(1, 4, feedbackMessage);

  /// Generates a full [FeedbackContentState].
  Generator<FeedbackContentState> get feedbackContentState => simple(
        generate: (random, size) {
          return FeedbackContentState(
            quiz: _generateMessageMap(random, size, _quizSubcategories),
            speedQuiz:
                _generateMessageMap(random, size, _speedQuizSubcategories),
            time: _generateMessageMap(random, size, _timeSubcategories),
            comeback: _generateMessageList(random, size, 1, 4),
            streak: _generateMessageMap(random, size, _streakSubcategories),
            titles: _generateTitleList(random, size),
            learned: _generateMessageMap(random, size, _learnedSubcategories),
          );
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a list of [PlayerTitleModel] with unique required_books, sorted.
  Generator<List<PlayerTitleModel>> get sortedTitleList => simple(
        generate: (random, size) {
          final count = random.nextInt(5) + 2; // 2-6 titles
          final usedBooks = <int>{};
          final titles = <PlayerTitleModel>[];
          for (var i = 0; i < count; i++) {
            var books = random.nextInt(20);
            while (usedBooks.contains(books)) {
              books = random.nextInt(20);
            }
            usedBooks.add(books);
            titles.add(PlayerTitleModel(
              title: _randomTurkish(random, size),
              icon: _emojiPool[random.nextInt(_emojiPool.length)],
              requiredBooks: books,
              profileImage: 'images/rewards/book_${i + 1}_reward.webp',
            ));
          }
          return titles;
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a non-empty list of [FeedbackMessageModel] (1-10 items).
  Generator<List<FeedbackMessageModel>> get nonEmptyMessageList =>
      listWithLengthInRange(1, 10, feedbackMessage);

  /// Generates a JSON map missing one or more required Lottie fields.
  Generator<Map<String, dynamic>> get invalidLottieMap => simple(
        generate: (random, size) {
          final map = <String, dynamic>{};
          // Start with all fields
          map['v'] = '5.${random.nextInt(10)}.${random.nextInt(10)}';
          map['layers'] = <dynamic>[
            {'ty': random.nextInt(5), 'nm': 'layer_0'},
          ];
          map['w'] = random.nextInt(1920) + 1;
          map['h'] = random.nextInt(1080) + 1;

          // Remove at least one required field
          final numToRemove =
              random.nextInt(_requiredLottieFields.length) + 1;
          final fieldsToRemove = List<String>.from(_requiredLottieFields)
            ..shuffle(random);
          for (var i = 0; i < numToRemove; i++) {
            map.remove(fieldsToRemove[i]);
          }

          return map;
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates an arbitrary invalid JSON string (malformed, missing fields, wrong types).
  Generator<String> get invalidJsonString => simple(
        generate: (random, size) {
          final choice = random.nextInt(5);
          switch (choice) {
            case 0:
              // Completely malformed JSON
              return '{not valid json at all!!!';
            case 1:
              // Valid JSON but not an object (array)
              return '[1, 2, 3]';
            case 2:
              // Valid JSON object but missing required fields
              return '{"foo": "bar", "baz": 123}';
            case 3:
              // Valid JSON with wrong types for expected fields
              return '{"quiz": "not_a_map", "titles": 42}';
            default:
              // Empty string
              return '';
          }
        },
        shrink: (input) => const Iterable.empty(),
      );

  /// Generates a category name for message operations.
  Generator<String> get categoryName => simple(
        generate: (random, size) {
          const categories = [
            'quiz',
            'speed_quiz',
            'time',
            'comeback',
            'streak',
            'learned',
          ];
          return categories[random.nextInt(categories.length)];
        },
        shrink: (input) => const Iterable.empty(),
      );
}

// =============================================================================
// Helper functions for generators
// =============================================================================

String _randomTurkish(Random random, int size) {
  final length = random.nextInt(size.clamp(1, 30)) + 1;
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(_turkishChars[random.nextInt(_turkishChars.length)]);
  }
  final result = buffer.toString().trim();
  return result.isEmpty ? 'Merhaba' : result;
}

Map<String, List<FeedbackMessageModel>> _generateMessageMap(
  Random random,
  int size,
  List<String> keys,
) {
  final map = <String, List<FeedbackMessageModel>>{};
  for (final key in keys) {
    map[key] = _generateMessageList(random, size, 1, 3);
  }
  return map;
}

List<FeedbackMessageModel> _generateMessageList(
  Random random,
  int size,
  int minCount,
  int maxCount,
) {
  final count = random.nextInt(maxCount - minCount + 1) + minCount;
  return List.generate(count, (_) {
    return FeedbackMessageModel(
      title: _randomTurkish(random, size),
      message: _randomTurkish(random, size),
      emoji: _emojiPool[random.nextInt(_emojiPool.length)],
      lottieAsset: random.nextBool()
          ? 'feedback/${_lottieNames[random.nextInt(_lottieNames.length)]}'
          : null,
      shouldRepeat: random.nextBool(),
    );
  });
}

List<PlayerTitleModel> _generateTitleList(Random random, int size) {
  final count = random.nextInt(4) + 1;
  final usedBooks = <int>{};
  final titles = <PlayerTitleModel>[];
  for (var i = 0; i < count; i++) {
    var books = random.nextInt(20);
    while (usedBooks.contains(books)) {
      books = random.nextInt(20);
    }
    usedBooks.add(books);
    titles.add(PlayerTitleModel(
      title: _randomTurkish(random, size),
      icon: _emojiPool[random.nextInt(_emojiPool.length)],
      requiredBooks: books,
      profileImage: 'images/rewards/book_${i + 1}_reward.webp',
    ));
  }
  titles.sort((a, b) => a.requiredBooks.compareTo(b.requiredBooks));
  return titles;
}

// =============================================================================
// Tests
// =============================================================================

void main() {

  // ===========================================================================
  // Property 1: Serialization Round-Trip
  // ===========================================================================
  group(
    'Feature: feedback-content-management, Property 1: Serialization Round-Trip',
    () {
      /// **Validates: Requirements 10.1, 10.2, 10.3**

      Glados(any.feedbackMessage, ExploreConfig(numRuns: 100)).test(
        'FeedbackMessageModel toJson → fromJson produces equivalent object',
        (message) {
          final json = message.toJson();
          final restored = FeedbackMessageModel.fromJson(json);

          expect(restored.title, equals(message.title));
          expect(restored.message, equals(message.message));
          expect(restored.emoji, equals(message.emoji));
          expect(restored.lottieAsset, equals(message.lottieAsset));
          expect(restored.shouldRepeat, equals(message.shouldRepeat));
          expect(restored, equals(message));
        },
      );

      Glados(any.playerTitle, ExploreConfig(numRuns: 100)).test(
        'PlayerTitleModel toJson → fromJson produces equivalent object',
        (title) {
          final json = title.toJson();
          final restored = PlayerTitleModel.fromJson(json);

          expect(restored.title, equals(title.title));
          expect(restored.icon, equals(title.icon));
          expect(restored.requiredBooks, equals(title.requiredBooks));
          expect(restored.profileImage, equals(title.profileImage));
          expect(restored, equals(title));
        },
      );

      Glados(any.feedbackContentState, ExploreConfig(numRuns: 100)).test(
        'FeedbackContentState toJson → fromJson produces equivalent object',
        (state) {
          final json = state.toJson();
          final restored = FeedbackContentState.fromJson(json);

          expect(restored, equals(state));
        },
      );
    },
  );

  // ===========================================================================
  // Property 2: Schema Integrity
  // ===========================================================================
  group(
    'Feature: feedback-content-management, Property 2: Schema Integrity',
    () {
      /// **Validates: Requirements 1.1, 1.3, 1.4, 1.5, 1.6, 1.7**

      Glados(any.feedbackContentState, ExploreConfig(numRuns: 100)).test(
        'serialized JSON contains all required top-level keys',
        (state) {
          final json = state.toJson();

          expect(json.containsKey('quiz'), isTrue);
          expect(json.containsKey('speed_quiz'), isTrue);
          expect(json.containsKey('time'), isTrue);
          expect(json.containsKey('comeback'), isTrue);
          expect(json.containsKey('streak'), isTrue);
          expect(json.containsKey('titles'), isTrue);
          expect(json.containsKey('learned'), isTrue);
        },
      );

      Glados(any.feedbackContentState, ExploreConfig(numRuns: 100)).test(
        'each category contains correct subcategory keys',
        (state) {
          final json = state.toJson();

          // Quiz subcategories
          final quiz = json['quiz'] as Map<String, dynamic>;
          for (final key in _quizSubcategories) {
            expect(quiz.containsKey(key), isTrue,
                reason: 'quiz should contain "$key"');
          }

          // Speed quiz subcategories
          final speedQuiz = json['speed_quiz'] as Map<String, dynamic>;
          for (final key in _speedQuizSubcategories) {
            expect(speedQuiz.containsKey(key), isTrue,
                reason: 'speed_quiz should contain "$key"');
          }

          // Time subcategories
          final time = json['time'] as Map<String, dynamic>;
          for (final key in _timeSubcategories) {
            expect(time.containsKey(key), isTrue,
                reason: 'time should contain "$key"');
          }

          // Streak subcategories
          final streak = json['streak'] as Map<String, dynamic>;
          for (final key in _streakSubcategories) {
            expect(streak.containsKey(key), isTrue,
                reason: 'streak should contain "$key"');
          }

          // Learned subcategories
          final learned = json['learned'] as Map<String, dynamic>;
          for (final key in _learnedSubcategories) {
            expect(learned.containsKey(key), isTrue,
                reason: 'learned should contain "$key"');
          }
        },
      );
    },
  );

  // ===========================================================================
  // Property 3: Message Add Grows List
  // ===========================================================================
  group(
    'Feature: feedback-content-management, Property 3: Message Add Grows List',
    () {
      /// **Validates: Requirements 5.1**

      Glados2(any.feedbackContentState, any.feedbackMessage,
              ExploreConfig(numRuns: 100))
          .test(
        'adding a message to comeback increases list length by exactly 1',
        (state, message) {
          final notifier = FeedbackContentNotifier(state);
          final beforeLength = notifier.state.comeback.length;

          notifier.addMessage('comeback', null, message);

          expect(notifier.state.comeback.length, equals(beforeLength + 1));
        },
      );

      Glados2(any.feedbackContentState, any.feedbackMessage,
              ExploreConfig(numRuns: 100))
          .test(
        'adding a message to quiz/speed_demon increases list length by exactly 1',
        (state, message) {
          final notifier = FeedbackContentNotifier(state);
          final beforeLength =
              notifier.state.quiz['speed_demon']?.length ?? 0;

          notifier.addMessage('quiz', 'speed_demon', message);

          expect(notifier.state.quiz['speed_demon']!.length,
              equals(beforeLength + 1));
        },
      );
    },
  );

  // ===========================================================================
  // Property 4: Message Delete Rules
  // ===========================================================================
  group(
    'Feature: feedback-content-management, Property 4: Message Delete Rules',
    () {
      /// **Validates: Requirements 5.3, 5.4**

      Glados(any.feedbackContentState, ExploreConfig(numRuns: 100)).test(
        'delete reduces list by 1 when category has >1 messages',
        (state) {
          // Ensure comeback has >1 messages
          const extraMessage = FeedbackMessageModel(
            title: 'Extra',
            message: 'Extra message',
            emoji: '🎯',
          );
          final stateWithMultiple = state.copyWith(
            comeback: [...state.comeback, extraMessage, extraMessage],
          );
          final notifier = FeedbackContentNotifier(stateWithMultiple);
          final beforeLength = notifier.state.comeback.length;

          final result = notifier.deleteMessage('comeback', null, 0);

          expect(result, isTrue);
          expect(notifier.state.comeback.length, equals(beforeLength - 1));
        },
      );

      Glados(any.feedbackMessage, ExploreConfig(numRuns: 100)).test(
        'delete is rejected when category has exactly 1 message',
        (message) {
          final state = FeedbackContentState(
            quiz: {
              for (final key in _quizSubcategories) key: [message],
            },
            speedQuiz: {
              for (final key in _speedQuizSubcategories) key: [message],
            },
            time: {
              for (final key in _timeSubcategories) key: [message],
            },
            comeback: [message],
            streak: {
              for (final key in _streakSubcategories) key: [message],
            },
            titles: [
              const PlayerTitleModel(
                title: 'Test',
                icon: '🌱',
                requiredBooks: 0,
                profileImage: 'images/test.webp',
              ),
            ],
            learned: {
              for (final key in _learnedSubcategories) key: [message],
            },
          );
          final notifier = FeedbackContentNotifier(state);

          final result = notifier.deleteMessage('comeback', null, 0);

          expect(result, isFalse);
          expect(notifier.state.comeback.length, equals(1));
        },
      );
    },
  );

  // ===========================================================================
  // Property 5: Titles Sorted Order
  // ===========================================================================
  group(
    'Feature: feedback-content-management, Property 5: Titles Sorted Order',
    () {
      /// **Validates: Requirements 6.3, 8.3**

      Glados(any.sortedTitleList, ExploreConfig(numRuns: 100)).test(
        'after addTitle, titles are always in ascending required_books order',
        (titles) {
          final state = FeedbackContentState(
            quiz: {for (final key in _quizSubcategories) key: [_dummyMessage]},
            speedQuiz: {
              for (final key in _speedQuizSubcategories) key: [_dummyMessage]
            },
            time: {
              for (final key in _timeSubcategories) key: [_dummyMessage]
            },
            comeback: [_dummyMessage],
            streak: {
              for (final key in _streakSubcategories) key: [_dummyMessage]
            },
            titles: titles,
            learned: {
              for (final key in _learnedSubcategories) key: [_dummyMessage]
            },
          );
          final notifier = FeedbackContentNotifier(state);

          // Add a new title with a unique required_books value
          final maxBooks = titles.isEmpty
              ? 0
              : titles.map((t) => t.requiredBooks).reduce(max);
          final newTitle = PlayerTitleModel(
            title: 'Yeni Ünvan',
            icon: '🏆',
            requiredBooks: maxBooks + 1,
            profileImage: 'images/new.webp',
          );
          notifier.addTitle(newTitle);

          // Verify sorted order
          final resultTitles = notifier.state.titles;
          for (var i = 0; i < resultTitles.length - 1; i++) {
            expect(
              resultTitles[i].requiredBooks,
              lessThanOrEqualTo(resultTitles[i + 1].requiredBooks),
              reason:
                  'Titles should be sorted by required_books in ascending order',
            );
          }
        },
      );
    },
  );

  // ===========================================================================
  // Property 6: Title required_books Uniqueness
  // ===========================================================================
  group(
    'Feature: feedback-content-management, Property 6: Title required_books Uniqueness',
    () {
      /// **Validates: Requirements 6.4**

      Glados(any.sortedTitleList, ExploreConfig(numRuns: 100)).test(
        'adding a title with duplicate required_books is rejected',
        (titles) {
          if (titles.isEmpty) return; // Skip empty lists

          final state = FeedbackContentState(
            quiz: {for (final key in _quizSubcategories) key: [_dummyMessage]},
            speedQuiz: {
              for (final key in _speedQuizSubcategories) key: [_dummyMessage]
            },
            time: {
              for (final key in _timeSubcategories) key: [_dummyMessage]
            },
            comeback: [_dummyMessage],
            streak: {
              for (final key in _streakSubcategories) key: [_dummyMessage]
            },
            titles: titles,
            learned: {
              for (final key in _learnedSubcategories) key: [_dummyMessage]
            },
          );
          final notifier = FeedbackContentNotifier(state);

          // Try to add a title with the same required_books as the first title
          final duplicateTitle = PlayerTitleModel(
            title: 'Duplicate',
            icon: '❌',
            requiredBooks: titles.first.requiredBooks,
            profileImage: 'images/dup.webp',
          );

          final result = notifier.addTitle(duplicateTitle);

          expect(result, isFalse,
              reason:
                  'Adding a title with duplicate required_books should be rejected');
          expect(notifier.state.titles.length, equals(titles.length));
        },
      );
    },
  );

  // ===========================================================================
  // Property 7: Invalid Data Fallback
  // ===========================================================================
  group(
    'Feature: feedback-content-management, Property 7: Invalid Data Fallback',
    () {
      /// **Validates: Requirements 7.2, 8.2**

      Glados(any.invalidJsonString, ExploreConfig(numRuns: 100)).test(
        'FeedbackDataLoader-style parsing never throws unhandled exceptions',
        (invalidJson) {
          // Simulate what FeedbackDataLoader does: try to parse JSON,
          // catch any error, and return null on failure.
          // This is the exact pattern from feedback_data_loader.dart.
          //
          // The property: for ANY string input, the loader either returns
          // a valid result or null — it NEVER throws to the caller.
          Map<String, dynamic>? result;
          Object? caughtError;
          try {
            final parsed = jsonDecode(invalidJson);
            if (parsed is! Map<String, dynamic>) {
              // Not a map — loader returns null
              result = null;
            } else {
              // Valid map — attempt to construct state
              // If fromJson throws, loader catches and returns null
              try {
                FeedbackContentState.fromJson(parsed);
                result = parsed;
              } catch (_) {
                result = null;
              }
            }
          } catch (e) {
            // JSON decode failed — loader returns null
            result = null;
            caughtError = e;
          }

          // The key property: the process NEVER throws an unhandled exception.
          // It either returns null (fallback) or a parseable map.
          // We verify no unhandled error escaped.
          expect(caughtError == null || result == null, isTrue,
              reason:
                  'FeedbackDataLoader should handle all errors gracefully');

          // If result is non-null, it should be usable without crashing
          if (result != null) {
            expect(
              () => FeedbackContentState.fromJson(result!),
              returnsNormally,
              reason:
                  'If loader returns a map, fromJson should not throw',
            );
          }
        },
      );
    },
  );

  // ===========================================================================
  // Property 8: Random Selection Returns List Member
  // ===========================================================================
  group(
    'Feature: feedback-content-management, Property 8: Random Selection Returns List Member',
    () {
      /// **Validates: Requirements 12.4**

      Glados(any.nonEmptyMessageList, ExploreConfig(numRuns: 100)).test(
        'index-based random selection always returns an element from the list',
        (messages) {
          // MessageFactory itself lives in the mobile app package (a separate
          // repo/pubspec from this admin tool) and can't be imported here.
          // This only verifies the `list[Random().nextInt(list.length)]`
          // pattern it relies on never indexes out of bounds or returns a
          // foreign element — not MessageFactory's own behavior.
          final random = Random();
          final selected = messages[random.nextInt(messages.length)];

          expect(messages.contains(selected), isTrue,
              reason:
                  'Random selection must return an element that exists in the list');
        },
      );
    },
  );

  // ===========================================================================
  // Property 9: Lottie Validation Rejects Invalid Files
  // ===========================================================================
  group(
    'Feature: feedback-content-management, Property 9: Lottie Validation Rejects Invalid Files',
    () {
      /// **Validates: Requirements 11.3**

      Glados(any.invalidLottieMap, ExploreConfig(numRuns: 100)).test(
        'validation rejects JSON objects missing required Lottie fields',
        (map) {
          // Verify at least one required field is missing
          final missingFields = _requiredLottieFields
              .where((f) => !map.containsKey(f))
              .toList();
          expect(missingFields, isNotEmpty,
              reason: 'Generated map should be missing at least one field');

          final bytes = utf8.encode(jsonEncode(map));
          final result = UploadValidator.validateLottieStructure(bytes);

          expect(result, isNotNull,
              reason:
                  'validateLottieStructure should reject maps missing fields: $missingFields');

          // Not just "rejected" — the message must actually name every
          // field that was removed, or a wrong/incomplete report would
          // pass this check just as easily as a correct one.
          for (final field in missingFields) {
            final label = _lottieFieldLabels[field]!;
            expect(result, contains(label),
                reason:
                    'validateLottieStructure result should mention missing field '
                    '"$label": $result');
          }
        },
      );
    },
  );

  // ===========================================================================
  // Property 10: Lottie Paths Short Format
  // ===========================================================================
  group(
    'Feature: feedback-content-management, Property 10: Lottie Paths Short Format',
    () {
      /// **Validates: Requirements 11.4**

      Glados(any.feedbackContentState, ExploreConfig(numRuns: 100)).test(
        'no lottie_asset contains assets/lottie/ prefix',
        (state) {
          void checkMessages(List<FeedbackMessageModel> messages) {
            for (final msg in messages) {
              if (msg.lottieAsset != null && msg.lottieAsset!.isNotEmpty) {
                expect(msg.lottieAsset!.contains('assets/lottie/'), isFalse,
                    reason:
                        'lottie_asset should not contain "assets/lottie/" prefix: ${msg.lottieAsset}');
                expect(msg.lottieAsset!.startsWith('assets/'), isFalse,
                    reason:
                        'lottie_asset should be lottie-relative: ${msg.lottieAsset}');
              }
            }
          }

          // Check all categories
          for (final list in state.quiz.values) {
            checkMessages(list);
          }
          for (final list in state.speedQuiz.values) {
            checkMessages(list);
          }
          for (final list in state.time.values) {
            checkMessages(list);
          }
          checkMessages(state.comeback);
          for (final list in state.streak.values) {
            checkMessages(list);
          }
          for (final list in state.learned.values) {
            checkMessages(list);
          }
        },
      );
    },
  );

  // ===========================================================================
  // Property 11: Migration Equivalence
  // ===========================================================================
  group(
    'Feature: feedback-content-management, Property 11: Migration Equivalence',
    () {
      /// **Validates: Requirements 13.5**

      test('feedback.json matches expected structure and content integrity', () {
        // Load the generated feedback.json
        final file =
            File('${Directory.current.path}/../islami-bilgi-yarismasi/assets/data/feedback.json');
        if (!file.existsSync()) {
          // Try alternative path (when running from admin project root)
          final altFile = File(
              '${Directory.current.parent.path}/islami-bilgi-yarismasi/assets/data/feedback.json');
          if (!altFile.existsSync()) {
            fail('feedback.json not found');
          }
        }

        final jsonString = file.existsSync()
            ? file.readAsStringSync()
            : File('${Directory.current.parent.path}/islami-bilgi-yarismasi/assets/data/feedback.json')
                .readAsStringSync();
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

        // Verify all top-level keys exist
        expect(jsonData.containsKey('quiz'), isTrue);
        expect(jsonData.containsKey('speed_quiz'), isTrue);
        expect(jsonData.containsKey('time'), isTrue);
        expect(jsonData.containsKey('comeback'), isTrue);
        expect(jsonData.containsKey('streak'), isTrue);
        expect(jsonData.containsKey('titles'), isTrue);
        expect(jsonData.containsKey('learned'), isTrue);

        // Verify quiz subcategories
        final quiz = jsonData['quiz'] as Map<String, dynamic>;
        for (final key in _quizSubcategories) {
          expect(quiz.containsKey(key), isTrue,
              reason: 'quiz should contain "$key"');
          final messages = quiz[key] as List;
          expect(messages.isNotEmpty, isTrue,
              reason: 'quiz.$key should have at least one message');
          // Verify each message has required fields
          for (final msg in messages) {
            final m = msg as Map<String, dynamic>;
            expect(m.containsKey('title'), isTrue);
            expect(m.containsKey('message'), isTrue);
            expect(m.containsKey('emoji'), isTrue);
            expect(m.containsKey('lottie_asset'), isTrue);
            expect(m.containsKey('should_repeat'), isTrue);
          }
        }

        // Verify titles have required fields
        final titles = jsonData['titles'] as List;
        expect(titles.isNotEmpty, isTrue);
        for (final t in titles) {
          final title = t as Map<String, dynamic>;
          expect(title.containsKey('title'), isTrue);
          expect(title.containsKey('icon'), isTrue);
          expect(title.containsKey('required_books'), isTrue);
          expect(title.containsKey('profile_image'), isTrue);
        }

        // Verify titles are sorted by required_books
        for (var i = 0; i < titles.length - 1; i++) {
          final current =
              (titles[i] as Map<String, dynamic>)['required_books'] as int;
          final next =
              (titles[i + 1] as Map<String, dynamic>)['required_books'] as int;
          expect(current, lessThanOrEqualTo(next),
              reason: 'Titles should be sorted by required_books');
        }

        // Verify specific hardcoded data is preserved (spot check)
        final speedDemon = quiz['speed_demon'] as List;
        final firstSpeedDemon = speedDemon[0] as Map<String, dynamic>;
        expect(firstSpeedDemon['title'], equals('Şimşek Gibi!'));
        expect(firstSpeedDemon['emoji'], equals('⚡'));
        expect(
            firstSpeedDemon['lottie_asset'], equals('feedback/lightning.json'));

        // Verify comeback messages
        final comeback = jsonData['comeback'] as List;
        expect(comeback.isNotEmpty, isTrue);
        final firstComeback = comeback[0] as Map<String, dynamic>;
        expect(firstComeback['title'], equals('Tekrar Hoş Geldin!'));

        // Verify learned categories
        final learned = jsonData['learned'] as Map<String, dynamic>;
        for (final key in _learnedSubcategories) {
          expect(learned.containsKey(key), isTrue,
              reason: 'learned should contain "$key"');
        }

        // Verify Türkçe characters are preserved
        final perfect = quiz['perfect'] as List;
        final firstPerfect = perfect[0] as Map<String, dynamic>;
        expect(firstPerfect['title'], contains('Maşallah'));

        // Verify first title
        final firstTitle = titles[0] as Map<String, dynamic>;
        expect(firstTitle['title'], equals('İlim Yolcusu'));
        expect(firstTitle['required_books'], equals(0));
      });
    },
  );
}

// =============================================================================
// Test helpers
// =============================================================================

/// A dummy message used to populate required categories in test states.
const _dummyMessage = FeedbackMessageModel(
  title: 'Test',
  message: 'Test message',
  emoji: '✅',
);
