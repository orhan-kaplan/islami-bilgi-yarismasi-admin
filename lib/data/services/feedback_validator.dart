import '../models/feedback_models.dart';
import 'asset_server_client.dart';

/// Expected subcategory keys for each feedback category.
const _requiredQuizSubcategories = [
  'speed_demon',
  'perfect',
  'one_wrong',
  'two_wrong',
  'good',
  'moderate',
  'failure',
];

const _requiredSpeedQuizSubcategories = [
  'combo_master',
  'high_score',
  'time_expired',
  'moderate',
  'low',
];

const _requiredTimeSubcategories = [
  'seher',
  'morning',
  'noon',
  'afternoon',
  'evening',
  'night',
  'teheccud',
];

const _requiredStreakSubcategories = ['3', '7', '30'];

const _requiredLearnedSubcategories = ['100', '75', '50', '25', '0'];

/// Validates a [FeedbackContentState] against the expected schema.
///
/// Checks:
/// - All required top-level categories are present and non-empty
/// - Each category has the correct subcategories
/// - Each subcategory has at least one message
/// - Lottie asset paths start with "feedback/" if set
/// - Optionally verifies lottie files exist on the asset server
///
/// Returns a list of error messages. An empty list means the data is valid.
///
/// Requirements: 9.1, 9.2, 9.3
Future<List<String>> validateFeedbackData(
  FeedbackContentState state, {
  AssetServerClient? client,
}) async {
  final errors = <String>[];

  // --- Top-level category presence checks ---
  _validateMapCategory(
    map: state.quiz,
    categoryName: 'quiz',
    requiredKeys: _requiredQuizSubcategories,
    errors: errors,
  );

  _validateMapCategory(
    map: state.speedQuiz,
    categoryName: 'speed_quiz',
    requiredKeys: _requiredSpeedQuizSubcategories,
    errors: errors,
  );

  _validateMapCategory(
    map: state.time,
    categoryName: 'time',
    requiredKeys: _requiredTimeSubcategories,
    errors: errors,
  );

  // Comeback is a flat list
  if (state.comeback.isEmpty) {
    errors.add('Category "comeback" must have at least one message');
  }

  _validateMapCategory(
    map: state.streak,
    categoryName: 'streak',
    requiredKeys: _requiredStreakSubcategories,
    errors: errors,
  );

  // Titles
  if (state.titles.isEmpty) {
    errors.add('Category "titles" must have at least one title');
  }

  _validateMapCategory(
    map: state.learned,
    categoryName: 'learned',
    requiredKeys: _requiredLearnedSubcategories,
    errors: errors,
  );

  // --- Lottie asset path format checks ---
  _validateLottiePaths(state, errors);

  // --- Optional: Lottie file existence checks via asset server ---
  if (client != null) {
    await _validateLottieFilesExist(state, client, errors);
  }

  return errors;
}

/// Validates a map-based category has all required subcategory keys,
/// each with at least one message.
void _validateMapCategory({
  required Map<String, List<FeedbackMessageModel>> map,
  required String categoryName,
  required List<String> requiredKeys,
  required List<String> errors,
}) {
  if (map.isEmpty) {
    errors.add('Category "$categoryName" is missing or empty');
    return;
  }

  for (final key in requiredKeys) {
    if (!map.containsKey(key)) {
      errors.add(
        'Category "$categoryName" is missing required subcategory "$key"',
      );
    } else if (map[key]!.isEmpty) {
      errors.add(
        'Category "$categoryName" subcategory "$key" must have at least one message',
      );
    }
  }
}

/// Validates that all lottie_asset paths (if set) start with "feedback/".
void _validateLottiePaths(
  FeedbackContentState state,
  List<String> errors,
) {
  void checkMessages(
    List<FeedbackMessageModel> messages,
    String location,
  ) {
    for (var i = 0; i < messages.length; i++) {
      final asset = messages[i].lottieAsset;
      if (asset != null && asset.isNotEmpty && !asset.startsWith('feedback/')) {
        errors.add(
          'Invalid lottie_asset path at $location[$i]: '
          '"$asset" must start with "feedback/"',
        );
      }
    }
  }

  // Quiz subcategories
  for (final entry in state.quiz.entries) {
    checkMessages(entry.value, 'quiz.${entry.key}');
  }

  // Speed quiz subcategories
  for (final entry in state.speedQuiz.entries) {
    checkMessages(entry.value, 'speed_quiz.${entry.key}');
  }

  // Time subcategories
  for (final entry in state.time.entries) {
    checkMessages(entry.value, 'time.${entry.key}');
  }

  // Comeback
  checkMessages(state.comeback, 'comeback');

  // Streak subcategories
  for (final entry in state.streak.entries) {
    checkMessages(entry.value, 'streak.${entry.key}');
  }

  // Learned subcategories
  for (final entry in state.learned.entries) {
    checkMessages(entry.value, 'learned.${entry.key}');
  }
}

/// Checks that lottie_asset files actually exist on the asset server
/// in the `lottie/feedback/` directory.
Future<void> _validateLottieFilesExist(
  FeedbackContentState state,
  AssetServerClient client,
  List<String> errors,
) async {
  // Collect all unique lottie paths
  final lottiePaths = <String>{};

  void collectPaths(List<FeedbackMessageModel> messages) {
    for (final msg in messages) {
      if (msg.lottieAsset != null && msg.lottieAsset!.isNotEmpty) {
        lottiePaths.add(msg.lottieAsset!);
      }
    }
  }

  for (final list in state.quiz.values) {
    collectPaths(list);
  }
  for (final list in state.speedQuiz.values) {
    collectPaths(list);
  }
  for (final list in state.time.values) {
    collectPaths(list);
  }
  collectPaths(state.comeback);
  for (final list in state.streak.values) {
    collectPaths(list);
  }
  for (final list in state.learned.values) {
    collectPaths(list);
  }

  // Check each unique path exists on the server
  for (final path in lottiePaths) {
    // Path in state is "feedback/filename.json"
    // Asset server API path is "lottie/feedback/filename.json"
    final serverPath = 'lottie/$path';
    try {
      await client.getFile(serverPath);
    } on AssetServerException catch (e) {
      if (e.statusCode == 404) {
        errors.add(
          'Lottie file not found on server: "$serverPath"',
        );
      } else {
        errors.add(
          'Error checking lottie file "$serverPath": ${e.message}',
        );
      }
    } catch (e) {
      errors.add(
        'Error checking lottie file "$serverPath": $e',
      );
    }
  }
}
