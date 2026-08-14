import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/content_state.dart';
import '../../../data/services/file_download_web.dart';
import '../../../data/services/zip_exporter.dart';
import '../../../data/services/zip_importer.dart';
import '../../providers/auto_load_providers.dart';
import '../../providers/content_providers.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/feedback_content_providers.dart';
import '../../providers/game_config_providers.dart';
import '../../providers/history_providers.dart';
import '../../providers/validation_providers.dart';

/// Dashboard screen displaying aggregate content counts, health score,
/// and action buttons for validation, import, and export.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoLoadStatus = ref.watch(autoLoadProvider);
    final counts = ref.watch(totalCountsProvider);
    final healthScore = ref.watch(healthScoreProvider);
    final errors = ref.watch(validationErrorsProvider);
    final isEmpty = _isContentEmpty(counts);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto-load loading indicator
            if (autoLoadStatus == AutoLoadStatus.loading)
              _buildAutoLoadingBanner(context),

            // Auto-load failure banner
            if (autoLoadStatus == AutoLoadStatus.failed)
              _buildAutoLoadFailedBanner(context, ref),

            // Aggregate count cards
            _buildCountCards(counts),
            const SizedBox(height: 32),

            // Empty state prompt
            if (isEmpty) _buildEmptyStatePrompt(context, ref),

            // Health score section
            if (!isEmpty) ...[
              _buildHealthScore(context, healthScore),
              const SizedBox(height: 32),
            ],

            // Action buttons (always visible — includes ZIP import)
            _buildActionButtons(context, ref, isEmpty),
            const SizedBox(height: 32),

            // Critical issues summary (when health < 100%)
            if (!isEmpty && healthScore < 100.0) _buildCriticalIssues(errors),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoLoadingBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Loading content from asset server...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.blue.shade800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoLoadFailedBanner(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.orange.shade700, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asset server unavailable',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Could not load content from the server. '
                          'Start the server or import a ZIP archive instead.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(autoLoadProvider.notifier).performAutoLoad();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Server start command
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.terminal, color: Colors.grey.shade400, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        'cd islami-bilgi-yarismasi/server && dart run bin/server.dart',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Colors.green.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isContentEmpty(Map<String, int> counts) {
    return (counts['series'] ?? 0) == 0 &&
        (counts['books'] ?? 0) == 0 &&
        (counts['levels'] ?? 0) == 0 &&
        (counts['questions'] ?? 0) == 0;
  }

  Widget _buildEmptyStatePrompt(BuildContext context, WidgetRef ref) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No content loaded',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Import a ZIP archive or individual JSON files to get started.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.blue.shade700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: () => _handleImport(context, ref),
              icon: const Icon(Icons.file_upload),
              label: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountCards(Map<String, int> counts) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _CountCard(
          label: 'Series',
          count: counts['series'] ?? 0,
          icon: Icons.category,
        ),
        _CountCard(
          label: 'Books',
          count: counts['books'] ?? 0,
          icon: Icons.book,
        ),
        _CountCard(
          label: 'Levels',
          count: counts['levels'] ?? 0,
          icon: Icons.layers,
        ),
        _CountCard(
          label: 'Questions',
          count: counts['questions'] ?? 0,
          icon: Icons.quiz,
        ),
      ],
    );
  }

  Widget _buildHealthScore(BuildContext context, double score) {
    final color = score >= 80
        ? Colors.green
        : score >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score / 100.0,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Center(
                    child: Text(
                      '${score.toInt()}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Score',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  score >= 100
                      ? 'All validation checks passing'
                      : 'Some issues need attention',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, bool isEmpty) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () => context.go('/validation'),
          icon: const Icon(Icons.verified),
          label: const Text('Validate All'),
        ),
        FilledButton.tonalIcon(
          onPressed: isEmpty ? null : () => _handleExport(context, ref),
          icon: const Icon(Icons.file_download),
          label: const Text('Export ZIP'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _handleImport(context, ref),
          icon: const Icon(Icons.file_upload),
          label: const Text('Import'),
        ),
      ],
    );
  }

  Widget _buildCriticalIssues(List<dynamic> errors) {
    final displayErrors = errors.take(5).toList();

    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Critical Issues (${errors.length} total)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...displayErrors.map(
              (error) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${error.sourceFile}: ${error.message}',
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (errors.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '... and ${errors.length - 5} more',
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    // Determine if we have a ZIP file or individual JSON files
    final zipFiles =
        result.files.where((f) => f.extension?.toLowerCase() == 'zip');
    final jsonFiles =
        result.files.where((f) => f.extension?.toLowerCase() == 'json');

    final importer = ZipImporter();
    ContentState? importedState;
    List<ImportIssue> issues = [];

    if (zipFiles.isNotEmpty) {
      // Import from the first ZIP file
      final zipFile = zipFiles.first;
      if (zipFile.bytes == null) return;
      final bundle = importer.importAll(zipFile.bytes!);
      importedState = bundle.content;
      issues = bundle.issues;
      if (bundle.feedback != null) {
        ref.read(feedbackContentProvider.notifier).importContent(bundle.feedback!);
      }
      if (bundle.gameConfig != null) {
        ref.read(gameConfigProvider.notifier).importContent(bundle.gameConfig!);
      }
    } else if (jsonFiles.isNotEmpty) {
      // Import individual JSON files
      final Map<String, Uint8List> fileMap = {};
      for (final file in jsonFiles) {
        if (file.bytes != null && file.name.isNotEmpty) {
          fileMap[file.name] = file.bytes!;
        }
      }
      if (fileMap.isEmpty) return;
      final (state, fileIssues) = importer.importFiles(fileMap);
      importedState = state;
      issues = fileIssues;
      final extras = importer.parseExtras(fileMap);
      issues = [...issues, ...extras.issues];
      if (extras.feedback != null) {
        ref.read(feedbackContentProvider.notifier).importContent(extras.feedback!);
      }
      if (extras.gameConfig != null) {
        ref.read(gameConfigProvider.notifier).importContent(extras.gameConfig!);
      }
    } else {
      return;
    }

    ref.read(contentStateProvider.notifier).importContent(importedState);
    ref.read(savedBaselineProvider.notifier).state = importedState;
    ref.read(historyProvider.notifier).clear();

    if (!context.mounted) return;

    if (issues.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Issues'),
          content: SizedBox(
            width: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: issues.length,
              itemBuilder: (_, index) {
                final issue = issues[index];
                return ListTile(
                  leading: Icon(
                    issue.severity == ImportIssueSeverity.error
                        ? Icons.error
                        : Icons.warning,
                    color: issue.severity == ImportIssueSeverity.error
                        ? Colors.red
                        : Colors.orange,
                  ),
                  title: Text(issue.fileName),
                  subtitle: Text(issue.message),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content imported successfully')),
      );
    }
  }

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    final state = ref.read(contentStateProvider);
    final exporter = ZipExporter();

    try {
      final zipBytes = exporter.exportZip(
        state,
        feedback: ref.read(feedbackContentProvider),
        gameConfig: ref.read(gameConfigProvider),
      );

      // Trigger browser download
      downloadFile(zipBytes, 'content_export.zip');

      ref.read(savedBaselineProvider.notifier).state = state;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export successful — download started')),
      );
    } on ValidationBlockedExportException catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export Blocked'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Export is blocked due to validation errors:',
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: e.errors.length,
                    itemBuilder: (_, index) {
                      final error = e.errors[index];
                      return ListTile(
                        leading: const Icon(Icons.error, color: Colors.red),
                        title: Text(error.sourceFile),
                        subtitle: Text(error.message),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

/// A card widget displaying a count with an icon and label.
class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
