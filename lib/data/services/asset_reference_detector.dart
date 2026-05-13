import '../models/content_state.dart';
import 'asset_path_utils.dart';

/// The type of content item that references an asset.
enum AssetReferenceType { book, level, reward }

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
