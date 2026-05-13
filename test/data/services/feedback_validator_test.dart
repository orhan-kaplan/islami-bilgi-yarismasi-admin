import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/feedback_validator.dart';

/// Helper to create a valid FeedbackContentState with all required subcategories.
FeedbackContentState _validState() {
  const msg = FeedbackMessageModel(
    title: 'Test',
    message: 'Test message',
    emoji: '🎉',
  );

  return FeedbackContentState(
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
      const PlayerTitleModel(
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
      final errors = await validateFeedbackData(_validState());
      expect(errors, isEmpty);
    });

    test('reports error when quiz category is empty', () async {
      final state = _validState().copyWith(quiz: {});
      final errors = await validateFeedbackData(state);
      expect(errors, contains(contains('quiz')));
      expect(errors, contains(contains('missing or empty')));
    });

    test('reports error when quiz is missing a subcategory', () async {
      final state = _validState();
      final quiz = Map<String, List<FeedbackMessageModel>>.from(state.quiz);
      quiz.remove('speed_demon');
      final modified = state.copyWith(quiz: quiz);

      final errors = await validateFeedbackData(modified);
      expect(
        errors,
        contains(contains('missing required subcategory "speed_demon"')),
      );
    });

    test('reports error when a subcategory has empty message list', () async {
      final state = _validState();
      final quiz = Map<String, List<FeedbackMessageModel>>.from(state.quiz);
      quiz['perfect'] = [];
      final modified = state.copyWith(quiz: quiz);

      final errors = await validateFeedbackData(modified);
      expect(
        errors,
        contains(contains('subcategory "perfect" must have at least one message')),
      );
    });

    test('reports error when speed_quiz is missing subcategories', () async {
      final state = _validState().copyWith(speedQuiz: {});
      final errors = await validateFeedbackData(state);
      expect(errors, contains(contains('speed_quiz')));
    });

    test('reports error when time is missing subcategories', () async {
      final state = _validState();
      final time = Map<String, List<FeedbackMessageModel>>.from(state.time);
      time.remove('teheccud');
      final modified = state.copyWith(time: time);

      final errors = await validateFeedbackData(modified);
      expect(
        errors,
        contains(contains('missing required subcategory "teheccud"')),
      );
    });

    test('reports error when comeback is empty', () async {
      final state = _validState().copyWith(comeback: []);
      final errors = await validateFeedbackData(state);
      expect(errors, contains(contains('comeback')));
    });

    test('reports error when streak is missing subcategories', () async {
      final state = _validState();
      final streak =
          Map<String, List<FeedbackMessageModel>>.from(state.streak);
      streak.remove('30');
      final modified = state.copyWith(streak: streak);

      final errors = await validateFeedbackData(modified);
      expect(
        errors,
        contains(contains('missing required subcategory "30"')),
      );
    });

    test('reports error when titles is empty', () async {
      final state = _validState().copyWith(titles: []);
      final errors = await validateFeedbackData(state);
      expect(errors, contains(contains('titles')));
    });

    test('reports error when learned is missing subcategories', () async {
      final state = _validState();
      final learned =
          Map<String, List<FeedbackMessageModel>>.from(state.learned);
      learned.remove('0');
      final modified = state.copyWith(learned: learned);

      final errors = await validateFeedbackData(modified);
      expect(
        errors,
        contains(contains('missing required subcategory "0"')),
      );
    });

    test('reports error for lottie_asset not starting with "feedback/"',
        () async {
      const badMsg = FeedbackMessageModel(
        title: 'Test',
        message: 'Test',
        emoji: '🎉',
        lottieAsset: 'wrong/path.json',
      );
      final state = _validState();
      final quiz = Map<String, List<FeedbackMessageModel>>.from(state.quiz);
      quiz['perfect'] = [badMsg];
      final modified = state.copyWith(quiz: quiz);

      final errors = await validateFeedbackData(modified);
      expect(errors, contains(contains('must start with "feedback/"')));
    });

    test('accepts valid lottie_asset path starting with "feedback/"',
        () async {
      const goodMsg = FeedbackMessageModel(
        title: 'Test',
        message: 'Test',
        emoji: '🎉',
        lottieAsset: 'feedback/masallah.json',
      );
      final state = _validState();
      final quiz = Map<String, List<FeedbackMessageModel>>.from(state.quiz);
      quiz['perfect'] = [goodMsg];
      final modified = state.copyWith(quiz: quiz);

      final errors = await validateFeedbackData(modified);
      expect(errors, isEmpty);
    });

    test('accepts null lottie_asset without error', () async {
      // The default _validState() already has null lottieAsset
      final errors = await validateFeedbackData(_validState());
      expect(errors, isEmpty);
    });

    test('reports multiple errors for completely empty state', () async {
      final state = FeedbackContentState.empty();
      final errors = await validateFeedbackData(state);
      // Should have errors for all categories
      expect(errors.length, greaterThanOrEqualTo(7));
    });
  });
}
