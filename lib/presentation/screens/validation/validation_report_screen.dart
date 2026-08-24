import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../data/services/content_validator.dart';
import '../../providers/connectivity_providers.dart';
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

    // Asset varlık kontrolü bağlantı yokken sessizce boş dönüyor, hata
    // verdiğinde de yutuluyordu; rapor hiç yapılmamış bir kontrolü "temiz"
    // diye göstermemeli.
    final isConnected = ref.watch(isServerConnectedProvider);
    final assetCheck = ref.watch(missingAssetValidationProvider);
    final assetChecksSkipped = !isConnected || assetCheck.hasError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-run asset checks',
            // Eksik asset uyarısı, dosya yüklendikten sonra da duruyordu:
            // bu provider içerik değişmeden yeniden çalışmıyor.
            onPressed: () => ref.invalidate(missingAssetValidationProvider),
          ),
          const SizedBox(width: 8),
        ],
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
                  color: context.adminColors.warning,
                  label: '${warnings.length} Warnings',
                ),
              ],
            ),
          ),
        ),
      ),
      body: (errors.isEmpty && warnings.isEmpty)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: assetChecksSkipped
                    ? const _SkippedAssetChecksNotice(standalone: true)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 64,
                            color: context.adminColors.success,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No validation issues found!',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (assetChecksSkipped) ...[
                  const _SkippedAssetChecksNotice(),
                  const SizedBox(height: 16),
                ],
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
                    color: context.adminColors.warning,
                  ),
                  ...warnings.map((issue) => _IssueTile(issue: issue)),
                ],
              ],
            ),
    );
  }
}

/// Banner telling the user that the asset existence check did not run.
class _SkippedAssetChecksNotice extends StatelessWidget {
  const _SkippedAssetChecksNotice({this.standalone = false});

  /// Boş rapor ortasında tek başına mı duruyor.
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final color = context.adminColors.warning;
    final text = Text(
      'Asset checks skipped — the asset server could not be reached, so '
      'missing images are not included in this report.',
      textAlign: standalone ? TextAlign.center : TextAlign.start,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
    );

    if (standalone) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: color),
          const SizedBox(height: 16),
          text,
        ],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_outlined, color: color),
            const SizedBox(width: 12),
            Expanded(child: text),
          ],
        ),
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
        : context.adminColors.warning;
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
        // Yol elle okunup Explorer'a taşınıyordu; satırdan alınabilmeli.
        trailing: IconButton(
          icon: const Icon(Icons.copy_outlined, size: 18),
          tooltip: 'Copy path',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: issue.jsonPath));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Path copied')),
            );
          },
        ),
        isThreeLine: true,
      ),
    );
  }
}
