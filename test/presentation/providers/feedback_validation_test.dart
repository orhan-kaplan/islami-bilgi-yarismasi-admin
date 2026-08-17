import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';

/// Helper to create a minimal valid FeedbackContentState with all required subcategories.
FeedbackContentState _createValidState() {
  const msg = FeedbackMessageModel(
    title: 'Test',
    message: 'Test message',
    emoji: '⭐',
    lottieAsset: null,
    shouldRepeat: true,
  );

  return const FeedbackContentState(
    quiz: {
      'speed_demon': [msg],
      'perfect': [msg],
      'one_wrong': [msg],
      'two_wrong': [msg],
      'good': [msg],
      'moderate': [msg],
      'failure': [msg],
    },
    speedQuiz: {
      'combo_master': [msg],
      'high_score': [msg],
      'time_expired': [msg],
      'moderate': [msg],
      'low': [msg],
    },
    time: {
      'seher': [msg],
      'morning': [msg],
      'noon': [msg],
      'afternoon': [msg],
      'evening': [msg],
      'night': [msg],
      'teheccud': [msg],
    },
    comeback: [msg],
    streak: {
      '3': [msg],
      '7': [msg],
      '30': [msg],
    },
    titles: [
      PlayerTitleModel(
        title: 'İlim Yolcusu',
        icon: '🌱',
        requiredBooks: 0,
        profileImage: 'images/seed/profile_icon_seed.webp',
      ),
    ],
    learned: {
      '100': [msg],
      '75': [msg],
      '50': [msg],
      '25': [msg],
      '0': [msg],
    },
  );
}

void main() {
  group('validateFeedbackData', () {
    test('returns empty list for valid state', () async {
      final state = _createValidState();
      final errors = await validateFeedbackData(state);
      expect(errors, isEmpty);
    });

    test('reports missing top-level categories for empty state', () async {
      final state = FeedbackContentState.empty();
      final errors = await validateFeedbackData(state);

      expect(errors, contains('Missing or empty top-level category: quiz'));
      expect(
          errors, contains('Missing or empty top-level category: speed_quiz'));
      expect(errors, contains('Missing or empty top-level category: time'));
      expect(
          errors, contains('Missing or empty top-level category: comeback'));
      expect(errors, contains('Missing or empty top-level category: streak'));
      expect(errors, contains('Missing or empty top-level category: titles'));
      expect(errors, contains('Missing or empty top-level category: learned'));
    });

    test('reports missing quiz subcategories', () async {
      final state = _createValidState().copyWith(quiz: {
        'speed_demon': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        // Missing: perfect, one_wrong, two_wrong, good, moderate, failure
      });

      final errors = await validateFeedbackData(state);

      expect(errors, contains('quiz: missing subcategory "perfect"'));
      expect(errors, contains('quiz: missing subcategory "one_wrong"'));
      expect(errors, contains('quiz: missing subcategory "two_wrong"'));
      expect(errors, contains('quiz: missing subcategory "good"'));
      expect(errors, contains('quiz: missing subcategory "moderate"'));
      expect(errors, contains('quiz: missing subcategory "failure"'));
    });

    test('reports missing speed_quiz subcategories', () async {
      final state = _createValidState().copyWith(speedQuiz: {
        'combo_master': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
      });

      final errors = await validateFeedbackData(state);

      expect(errors, contains('speed_quiz: missing subcategory "high_score"'));
      expect(
          errors, contains('speed_quiz: missing subcategory "time_expired"'));
      expect(errors, contains('speed_quiz: missing subcategory "moderate"'));
      expect(errors, contains('speed_quiz: missing subcategory "low"'));
    });

    test('reports missing time subcategories', () async {
      final state = _createValidState().copyWith(time: {
        'seher': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
      });

      final errors = await validateFeedbackData(state);

      expect(errors, contains('time: missing subcategory "morning"'));
      expect(errors, contains('time: missing subcategory "noon"'));
      expect(errors, contains('time: missing subcategory "afternoon"'));
      expect(errors, contains('time: missing subcategory "evening"'));
      expect(errors, contains('time: missing subcategory "night"'));
      expect(errors, contains('time: missing subcategory "teheccud"'));
    });

    test('accepts streak with only some positive-int keys', () async {
      final state = _createValidState().copyWith(streak: {
        '3': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
      });

      final errors = await validateFeedbackData(state);

      expect(errors, isEmpty);
    });

    test('reports invalid streak keys', () async {
      final state = _createValidState().copyWith(streak: {
        'abc': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
      });

      final errors = await validateFeedbackData(state);

      expect(errors, contains('streak: key "abc" must be a positive integer'));
    });

    test('reports missing learned subcategories', () async {
      final state = _createValidState().copyWith(learned: {
        '100': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
      });

      final errors = await validateFeedbackData(state);

      expect(errors, contains('learned: missing subcategory "75"'));
      expect(errors, contains('learned: missing subcategory "50"'));
      expect(errors, contains('learned: missing subcategory "25"'));
      expect(errors, contains('learned: missing subcategory "0"'));
    });

    test('reports empty subcategory lists', () async {
      final state = _createValidState().copyWith(quiz: {
        'speed_demon': [],
        'perfect': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'one_wrong': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'two_wrong': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'good': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'moderate': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'failure': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
      });

      final errors = await validateFeedbackData(state);

      expect(errors,
          contains('quiz: subcategory "speed_demon" has no messages'));
    });

    test('reports invalid lottie_asset paths that use an assets/ prefix',
        () async {
      final state = _createValidState().copyWith(quiz: {
        'speed_demon': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
            lottieAsset: 'assets/lottie/feedback/lightning.json',
          ),
        ],
        'perfect': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'one_wrong': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'two_wrong': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'good': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'moderate': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'failure': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
      });

      final errors = await validateFeedbackData(state);

      expect(
        errors,
        contains(
          'quiz.speed_demon[0]: lottie_asset "assets/lottie/feedback/lightning.json" must not start with "assets/" (use a lottie-relative path, e.g. feedback/foo.json)',
        ),
      );
    });

    test('accepts valid lottie_asset paths starting with feedback/', () async {
      final state = _createValidState().copyWith(quiz: {
        'speed_demon': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
            lottieAsset: 'feedback/lightning.json',
          ),
        ],
        'perfect': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'one_wrong': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'two_wrong': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'good': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'moderate': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'failure': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
      });

      final errors = await validateFeedbackData(state);

      // No lottie path errors
      expect(
        errors.where((e) => e.contains('lottie_asset')),
        isEmpty,
      );
    });

    test('checks lottie file existence on server when client provided',
        () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/files/lottie/feedback/lightning.json') {
          return http.Response('Not found', 404);
        }
        return http.Response('{}', 200);
      });

      final client = AssetServerClient(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final state = _createValidState().copyWith(quiz: {
        'speed_demon': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
            lottieAsset: 'feedback/lightning.json',
          ),
        ],
        'perfect': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'one_wrong': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'two_wrong': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'good': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'moderate': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'failure': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
      });

      final errors = await validateFeedbackData(state, client: client);

      expect(
        errors,
        contains(
            'Lottie file not found on server: lottie/feedback/lightning.json'),
      );
    });

    test('no lottie errors when file exists on server', () async {
      final mockClient = MockClient((request) async {
        // All files exist
        return http.Response('{"v": "5.0"}', 200);
      });

      final client = AssetServerClient(
        baseUrl: 'http://localhost:8080',
        client: mockClient,
      );

      final state = _createValidState().copyWith(quiz: {
        'speed_demon': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
            lottieAsset: 'feedback/lightning.json',
          ),
        ],
        'perfect': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'one_wrong': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'two_wrong': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'good': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'moderate': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
        'failure': [
          const FeedbackMessageModel(
            title: 'T',
            message: 'M',
            emoji: '⭐',
          ),
        ],
      });

      final errors = await validateFeedbackData(state, client: client);

      expect(
        errors.where((e) => e.contains('Lottie file not found')),
        isEmpty,
      );
    });

    test('validates comeback lottie paths that use an assets/ prefix', () async {
      final state = _createValidState().copyWith(comeback: [
        const FeedbackMessageModel(
          title: 'T',
          message: 'M',
          emoji: '⭐',
          lottieAsset: 'assets/lottie/wrong.json',
        ),
      ]);

      final errors = await validateFeedbackData(state);

      expect(
        errors,
        contains(
          'comeback[0]: lottie_asset "assets/lottie/wrong.json" must not start with "assets/" (use a lottie-relative path, e.g. feedback/foo.json)',
        ),
      );
    });

    test('null lottie_asset is not flagged', () async {
      final state = _createValidState();
      final errors = await validateFeedbackData(state);

      expect(
        errors.where((e) => e.contains('lottie_asset')),
        isEmpty,
      );
    });
  });
}
