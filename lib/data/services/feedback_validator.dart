import '../models/feedback_models.dart';

/// Short lottie path relative to `assets/lottie/`.
/// Accepts `feedback/foo.json` and root files like `trophy_2.json`.
/// Rejects App_Path prefixes (`assets/...`) and parent-directory traversal.
bool isValidLottieShortPath(String? asset) {
  if (asset == null || asset.isEmpty) return true;
  if (asset.startsWith('assets/')) return false;
  if (asset.startsWith('/')) return false;
  if (asset.contains('..')) return false;
  return true;
}

/// Required subcategories for each feedback category.
const Map<String, List<String>> kRequiredFeedbackSubcategories = {
  'quiz': [
    'speed_demon',
    'perfect',
    'one_wrong',
    'two_wrong',
    'good',
    'moderate',
    'failure',
  ],
  'speed_quiz': [
    'combo_master',
    'high_score',
    'time_expired',
    'moderate',
    'low',
  ],
  'time': [
    'seher',
    'morning',
    'noon',
    'afternoon',
    'evening',
    'night',
    'teheccud',
  ],
  'learned': ['100', '75', '50', '25', '0'],
};

/// Sync schema checks for `feedback.json` (ERROR-level).
///
/// Does not hit the asset server. Lottie *existence* stays in
/// [validateFeedbackData] so ZIP export can gate without HTTP.
List<String> validateFeedbackSchema(FeedbackContentState state) {
  final errors = <String>[];

  if (state.quiz.isEmpty) {
    errors.add('Missing or empty top-level category: quiz');
  }
  if (state.speedQuiz.isEmpty) {
    errors.add('Missing or empty top-level category: speed_quiz');
  }
  if (state.time.isEmpty) {
    errors.add('Missing or empty top-level category: time');
  }
  if (state.comeback.isEmpty) {
    errors.add('Missing or empty top-level category: comeback');
  }
  if (state.streak.isEmpty) {
    errors.add('Missing or empty top-level category: streak');
  }
  if (state.titles.isEmpty) {
    errors.add('Missing or empty top-level category: titles');
  }
  if (state.learned.isEmpty) {
    errors.add('Missing or empty top-level category: learned');
  }

  _validateSubcategories(state.quiz, 'quiz', errors);
  _validateSubcategories(state.speedQuiz, 'speed_quiz', errors);
  _validateSubcategories(state.time, 'time', errors);
  _validateStreakSubcategories(state.streak, errors);
  _validateSubcategories(state.learned, 'learned', errors);
  _validateLottiePaths(state, errors);

  return errors;
}

void _validateSubcategories(
  Map<String, List<FeedbackMessageModel>> map,
  String categoryName,
  List<String> errors,
) {
  final required = kRequiredFeedbackSubcategories[categoryName];
  if (required == null) return;

  for (final subcategory in required) {
    final list = map[subcategory];
    if (list == null) {
      errors.add('$categoryName: missing subcategory "$subcategory"');
    } else if (list.isEmpty) {
      errors.add('$categoryName: subcategory "$subcategory" has no messages');
    }
  }
}

void _validateStreakSubcategories(
  Map<String, List<FeedbackMessageModel>> map,
  List<String> errors,
) {
  for (final entry in map.entries) {
    final days = int.tryParse(entry.key);
    if (days == null || days <= 0) {
      errors.add('streak: key "${entry.key}" must be a positive integer');
    }
    if (entry.value.isEmpty) {
      errors.add('streak: subcategory "${entry.key}" has no messages');
    }
  }
}

void _validateLottiePaths(FeedbackContentState state, List<String> errors) {
  void checkMessages(List<FeedbackMessageModel> messages, String context) {
    for (var i = 0; i < messages.length; i++) {
      final asset = messages[i].lottieAsset;
      if (asset != null &&
          asset.isNotEmpty &&
          !isValidLottieShortPath(asset)) {
        errors.add(
            '$context[$i]: lottie_asset "$asset" must not start with "assets/" '
            '(use a lottie-relative path, e.g. feedback/foo.json)');
      }
    }
  }

  for (final entry in state.quiz.entries) {
    checkMessages(entry.value, 'quiz.${entry.key}');
  }
  for (final entry in state.speedQuiz.entries) {
    checkMessages(entry.value, 'speed_quiz.${entry.key}');
  }
  for (final entry in state.time.entries) {
    checkMessages(entry.value, 'time.${entry.key}');
  }
  for (final entry in state.streak.entries) {
    checkMessages(entry.value, 'streak.${entry.key}');
  }
  for (final entry in state.learned.entries) {
    checkMessages(entry.value, 'learned.${entry.key}');
  }
  checkMessages(state.comeback, 'comeback');
}
