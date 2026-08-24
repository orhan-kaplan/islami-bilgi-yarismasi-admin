import '../models/content_state.dart';
import '../models/feedback_models.dart';
import '../models/game_config_models.dart';
import 'asset_path_utils.dart';

/// The type of content item that references an asset.
enum AssetReferenceType { book, level, reward, feedback, gameConfig }

/// Represents a content item that references a specific asset path.
class AssetReference {
  final AssetReferenceType type;
  final String name;
  final String id;

  const AssetReference({
    required this.type,
    required this.name,
    required this.id,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AssetReference &&
        other.type == type &&
        other.name == name &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, name, id);

  @override
  String toString() =>
      'AssetReference(type: $type, name: $name, id: $id)';
}

/// Utility that scans [ContentState] for asset_image references.
///
/// Used by delete operations to determine whether an asset is in use
/// before allowing deletion.
class AssetReferenceDetector {
  /// Normalizes a query path to App_Path format for consistent comparison.
  ///
  /// Accepts both App_Path (`assets/images/...`) and API_Path (`images/...`)
  /// formats and normalizes to App_Path.
  static String _normalizeToAppPath(String path) {
    if (AssetPathUtils.isValidAppPath(path)) {
      return path;
    }
    return AssetPathUtils.apiPathToAppPath(path);
  }

  /// Finds all content items that reference the given [assetPath].
  ///
  /// The [assetPath] can be in either App_Path or API_Path format.
  /// Returns a list of [AssetReference] describing each referencing item.
  static List<AssetReference> findReferences(
    ContentState state,
    String assetPath,
  ) {
    final normalizedPath = _normalizeToAppPath(assetPath);
    final references = <AssetReference>[];

    // Check books
    for (final book in state.books) {
      if (book.assetImage == normalizedPath) {
        references.add(AssetReference(
          type: AssetReferenceType.book,
          name: book.title,
          id: book.id.toString(),
        ));
      }
    }

    // Check levels across all content files
    for (final entry in state.contentFiles.entries) {
      for (final level in entry.value) {
        if (level.assetImage == normalizedPath) {
          references.add(AssetReference(
            type: AssetReferenceType.level,
            name: level.title,
            id: '${level.bookId}_${level.id}',
          ));
        }
      }
    }

    // Check rewards
    for (final reward in state.rewards) {
      if (reward.assetImage == normalizedPath) {
        references.add(AssetReference(
          type: AssetReferenceType.reward,
          name: reward.title,
          id: reward.unlockBookId.toString(),
        ));
      }
    }

    return references;
  }

  /// Returns true if any content item references the given [assetPath].
  ///
  /// The [assetPath] can be in either App_Path or API_Path format.
  static bool isReferenced(ContentState state, String assetPath) {
    final normalizedPath = _normalizeToAppPath(assetPath);

    // Check books
    for (final book in state.books) {
      if (book.assetImage == normalizedPath) return true;
    }

    // Check levels
    for (final levels in state.contentFiles.values) {
      for (final level in levels) {
        if (level.assetImage == normalizedPath) return true;
      }
    }

    // Check rewards
    for (final reward in state.rewards) {
      if (reward.assetImage == normalizedPath) return true;
    }

    return false;
  }

  /// Finds everything that still uses the Lottie file at [apiPath]
  /// (e.g. `lottie/feedback/masallah.json`).
  ///
  /// Lottie dosyaları `asset_image` alanlarında değil, feedback mesajlarının
  /// `lottie_asset` alanında ve `game_config.json`'ın lottie slotlarında
  /// duruyor; ikisi de assets kökünün `lottie/` klasörüne göreli.
  static List<AssetReference> findLottieReferences(
    FeedbackContentState feedback,
    GameConfigState gameConfig,
    String apiPath,
  ) {
    const prefix = 'lottie/';
    final relative =
        apiPath.startsWith(prefix) ? apiPath.substring(prefix.length) : apiPath;
    final references = <AssetReference>[];

    void checkMessages(List<FeedbackMessageModel> messages) {
      for (final message in messages) {
        if (message.lottieAsset == relative) {
          references.add(AssetReference(
            type: AssetReferenceType.feedback,
            name: message.title,
            id: message.title,
          ));
        }
      }
    }

    for (final list in feedback.quiz.values) {
      checkMessages(list);
    }
    for (final list in feedback.speedQuiz.values) {
      checkMessages(list);
    }
    for (final list in feedback.time.values) {
      checkMessages(list);
    }
    checkMessages(feedback.comeback);
    for (final list in feedback.streak.values) {
      checkMessages(list);
    }
    for (final list in feedback.learned.values) {
      checkMessages(list);
    }

    final slots = <String, String>{
      'confetti': gameConfig.lottie.confetti,
      'book_finish': gameConfig.lottie.bookFinish,
      'level_complete': gameConfig.lottie.levelComplete,
      'learned_fallback': gameConfig.lottie.learnedFallback,
      'quiz_loading': gameConfig.lottie.quizLoading,
      'quiz_fail': gameConfig.lottie.quizFail,
    };
    for (final slot in slots.entries) {
      if (slot.value == relative) {
        references.add(AssetReference(
          type: AssetReferenceType.gameConfig,
          name: slot.key,
          id: slot.key,
        ));
      }
    }

    return references;
  }

  /// Returns all asset paths referenced by any content item in the state.
  ///
  /// Returned paths are in App_Path format (starting with `assets/`).
  static Set<String> getAllReferencedPaths(ContentState state) {
    final paths = <String>{};

    // Collect from books
    for (final book in state.books) {
      if (book.assetImage.isNotEmpty) {
        paths.add(book.assetImage);
      }
    }

    // Collect from levels
    for (final levels in state.contentFiles.values) {
      for (final level in levels) {
        if (level.assetImage != null && level.assetImage!.isNotEmpty) {
          paths.add(level.assetImage!);
        }
      }
    }

    // Collect from rewards
    for (final reward in state.rewards) {
      if (reward.assetImage.isNotEmpty) {
        paths.add(reward.assetImage);
      }
    }

    return paths;
  }
}
