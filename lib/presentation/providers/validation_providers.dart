import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/content_validator.dart';
import 'content_providers.dart';

/// Derived provider that runs all validation checks on the current content state.
/// Returns the full list of issues (both errors and warnings).
final validationResultsProvider = Provider<List<ValidationIssue>>((ref) {
  final state = ref.watch(contentStateProvider);
  return ContentValidator().validateAll(state);
});

/// Derived provider that filters only error-level issues.
final validationErrorsProvider = Provider<List<ValidationIssue>>((ref) {
  final results = ref.watch(validationResultsProvider);
  return results
      .where((issue) => issue.severity == ValidationSeverity.error)
      .toList();
});

/// Derived provider that filters only warning-level issues.
final validationWarningsProvider = Provider<List<ValidationIssue>>((ref) {
  final results = ref.watch(validationResultsProvider);
  return results
      .where((issue) => issue.severity == ValidationSeverity.warning)
      .toList();
});

/// Derived provider that computes a health score (0–100) based on validation issues.
///
/// Returns 100.0 if no errors and no warnings.
/// Otherwise: max(0, 100 - (errorCount * 10 + warningCount * 2)), capped at 0–100.
final healthScoreProvider = Provider<double>((ref) {
  final results = ref.watch(validationResultsProvider);

  final errorCount =
      results.where((i) => i.severity == ValidationSeverity.error).length;
  final warningCount =
      results.where((i) => i.severity == ValidationSeverity.warning).length;

  if (errorCount == 0 && warningCount == 0) return 100.0;

  final score = 100 - (errorCount * 10 + warningCount * 2);
  return max(0, score).toDouble().clamp(0.0, 100.0);
});
