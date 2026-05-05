import 'package:flutter/material.dart';

import '../../../data/services/content_validator.dart';

/// A small widget that shows a red error badge (dot or count) on tree nodes
/// that have validation errors.
///
/// Takes a list of [ValidationIssue] and shows a red dot if any errors exist
/// for that item.
class ValidationBadge extends StatelessWidget {
  const ValidationBadge({super.key, required this.issues});

  /// The validation issues associated with this tree node.
  final List<ValidationIssue> issues;

  @override
  Widget build(BuildContext context) {
    final errorCount = issues
        .where((issue) => issue.severity == ValidationSeverity.error)
        .length;

    if (errorCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      constraints: const BoxConstraints(
        minWidth: 18,
        minHeight: 18,
      ),
      child: Text(
        errorCount > 9 ? '9+' : '$errorCount',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
