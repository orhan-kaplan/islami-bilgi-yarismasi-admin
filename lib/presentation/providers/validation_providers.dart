import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/content_state.dart';
import '../../data/services/asset_path_utils.dart';
import '../../data/services/asset_server_client.dart';
import '../../data/services/asset_reference_detector.dart';
import '../../data/services/content_validator.dart';
import 'asset_server_providers.dart';
import 'connectivity_providers.dart';
import 'content_providers.dart';

/// Derived provider that runs all validation checks on the current content state.
/// Returns the full list of issues (both errors and warnings).
final validationResultsProvider = Provider<List<ValidationIssue>>((ref) {
  final state = ref.watch(contentStateProvider);
  return ContentValidator().validateAll(state);
});

/// Async provider that checks asset_image paths against the server's file system.
///
/// Only runs when the server is connected. Lists image directories once to build
/// an existence index, then compares all referenced asset paths against it.
/// Returns a list of [ValidationIssue] for missing assets (severity: warning).
final missingAssetValidationProvider =
    FutureProvider<List<ValidationIssue>>((ref) async {
  final isConnected = ref.watch(isServerConnectedProvider);
  if (!isConnected) return [];

  final state = ref.watch(contentStateProvider);
  final client = ref.read(assetServerClientProvider);

  // Get all referenced asset paths from content
  final referencedPaths = AssetReferenceDetector.getAllReferencedPaths(state);
  if (referencedPaths.isEmpty) return [];

  // Determine which directories need to be listed.
  // Convert App_Paths to API_Paths and extract unique parent directories.
  final directoriesToList = <String>{};
  for (final appPath in referencedPaths) {
    final apiPath = AssetPathUtils.appPathToApiPath(appPath);
    final lastSlash = apiPath.lastIndexOf('/');
    if (lastSlash > 0) {
      directoriesToList.add(apiPath.substring(0, lastSlash));
    }
  }

  // Build existence index by listing each directory once
  final existingFiles = <String>{};
  // Directories we could not read at all. A 404 means the directory is gone,
  // so everything inside it really is missing; any other failure only means
  // "could not check" and must not be reported as a missing asset — it would
  // turn one transient server error into a warning per reference and sink the
  // health score.
  final uncheckedDirectories = <String>{};
  for (final dir in directoriesToList) {
    try {
      final entries = await client.listDirectory(dir);
      for (final entry in entries) {
        // entry.path is in API_Path format
        existingFiles.add(AssetPathUtils.apiPathToAppPath(entry.path));
      }
    } on AssetServerException catch (e) {
      if (e.statusCode != 404) uncheckedDirectories.add(dir);
    } catch (_) {
      uncheckedDirectories.add(dir);
    }
  }

  // Compare referenced paths against existing files
  final issues = <ValidationIssue>[];
  for (final appPath in referencedPaths) {
    if (uncheckedDirectories.contains(_parentDirectory(appPath))) continue;
    if (!existingFiles.contains(appPath)) {
      // Determine source file for this reference
      final sourceFile = _findSourceFileForAsset(state, appPath);
      issues.add(ValidationIssue(
        severity: ValidationSeverity.warning,
        sourceFile: sourceFile,
        jsonPath: 'asset_image',
        message: 'Asset not found: $appPath',
      ));
    }
  }

  return issues;
});

/// The API_Path directory holding [appPath], matching how the listing index
/// above is keyed.
String? _parentDirectory(String appPath) {
  final apiPath = AssetPathUtils.appPathToApiPath(appPath);
  final lastSlash = apiPath.lastIndexOf('/');
  return lastSlash > 0 ? apiPath.substring(0, lastSlash) : null;
}

/// Finds the source file that references the given asset path.
String _findSourceFileForAsset(
    ContentState state, String assetPath) {
  // Check books
  for (final book in state.books) {
    if (book.assetImage == assetPath) {
      return 'books.json';
    }
  }

  // Check levels
  for (final entry in state.contentFiles.entries) {
    for (final level in entry.value) {
      if (level.assetImage == assetPath) {
        return 'content/${entry.key}';
      }
    }
  }

  // Check rewards
  for (final reward in state.rewards) {
    if (reward.assetImage == assetPath) {
      return 'rewards.json';
    }
  }

  return 'unknown';
}

/// Combined provider that merges synchronous validation results with
/// async missing asset validation results.
///
/// Returns all issues from both sources. If the async provider is still
/// loading or errored, only synchronous results are returned.
final allValidationResultsProvider = Provider<List<ValidationIssue>>((ref) {
  final syncResults = ref.watch(validationResultsProvider);
  final asyncResults = ref.watch(missingAssetValidationProvider);

  // The asset check re-runs on every content mutation. Dropping its findings
  // while it reloads makes the health score jump on every edit, so keep the
  // last answer until a new one arrives.
  return asyncResults.when(
    skipLoadingOnReload: true,
    data: (missingAssetIssues) => [...syncResults, ...missingAssetIssues],
    loading: () => syncResults,
    error: (_, _) => syncResults,
  );
});

/// Derived provider that filters only error-level issues.
final validationErrorsProvider = Provider<List<ValidationIssue>>((ref) {
  final results = ref.watch(allValidationResultsProvider);
  return results
      .where((issue) => issue.severity == ValidationSeverity.error)
      .toList();
});

/// Derived provider that filters only warning-level issues.
final validationWarningsProvider = Provider<List<ValidationIssue>>((ref) {
  final results = ref.watch(allValidationResultsProvider);
  return results
      .where((issue) => issue.severity == ValidationSeverity.warning)
      .toList();
});

/// Derived provider that computes a health score (0–100) based on validation issues.
///
/// Returns 100.0 if no errors and no warnings.
/// Otherwise: max(0, 100 - (errorCount * 10 + warningCount * 2)), capped at 0–100.
final healthScoreProvider = Provider<double>((ref) {
  final results = ref.watch(allValidationResultsProvider);

  final errorCount =
      results.where((i) => i.severity == ValidationSeverity.error).length;
  final warningCount =
      results.where((i) => i.severity == ValidationSeverity.warning).length;

  if (errorCount == 0 && warningCount == 0) return 100.0;

  final score = 100 - (errorCount * 10 + warningCount * 2);
  return max(0, score).toDouble().clamp(0.0, 100.0);
});
