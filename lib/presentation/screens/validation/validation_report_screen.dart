import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/content_validator.dart';
import '../../providers/validation_providers.dart';

/// Screen displaying the full validation report.
///
/// Shows errors and warnings in distinct sections (errors first),
/// with total counts in the header. Each issue displays a severity icon,
/// source file, JSON path, and description.
class ValidationReportScreen extends ConsumerWidget {
  const ValidationReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errors = ref.watch(validationErrorsProvider);
    final warnings = ref.watch(validationWarningsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation Report'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
            child: Row(
              children: [
                _CountChip(
                  icon: Icons.error,
                  color: Theme.of(context).colorScheme.error,
                  label: '${errors.length} Errors',
                ),
                const SizedBox(width: 12),
                _CountChip(
                  icon: Icons.warning,
                  color: Colors.orange,
                  label: '${warnings.length} Warnings',
                ),
              ],
            ),
          ),
        ),
      ),
      body: (errors.isEmpty && warnings.isEmpty)
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No validation issues found!',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (errors.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Errors (${errors.length})',
                    color: Theme.of(context).colorScheme.error,
                  ),
                  ...errors.map((issue) => _IssueTile(issue: issue)),
                  const SizedBox(height: 24),
                ],
                if (warnings.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Warnings (${warnings.length})',
                    color: Colors.orange,
                  ),
                  ...warnings.map((issue) => _IssueTile(issue: issue)),
                ],
              ],
            ),
    );
  }
}

/// Chip showing a count with an icon.
class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label),
    );
  }
}

/// Section header for errors or warnings.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.color,
  });

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// A single validation issue tile.
class _IssueTile extends StatelessWidget {
  const _IssueTile({required this.issue});

  final ValidationIssue issue;

  @override
  Widget build(BuildContext context) {
    final isError = issue.severity == ValidationSeverity.error;
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Colors.orange;
    final icon = isError ? Icons.error : Icons.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(issue.message),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'File: ${issue.sourceFile}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Path: ${issue.jsonPath}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
