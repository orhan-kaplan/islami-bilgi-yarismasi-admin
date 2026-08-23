import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/content_state.dart';
import '../../../data/models/feedback_models.dart';
import '../../../data/models/game_config_models.dart';
import '../../../data/services/file_download_web.dart';
import '../../../data/services/zip_exporter.dart';
import '../../../data/services/zip_importer.dart';
import '../../providers/auto_load_providers.dart';
import '../../providers/auto_save_providers.dart';
import '../../providers/connectivity_providers.dart';
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
    final warnings = ref.watch(validationWarningsProvider);
    // Hadis ve ödüller de içeriktir: yalnız quiz dilimlerine bakmak, hadis
    // dolu bir oturumu "boş" gösterip export'u kilitliyordu.
    final hasContent = ref.watch(contentStateProvider).hasAnyContent;
    final isLoading = autoLoadStatus == AutoLoadStatus.loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto-load loading indicator
            if (isLoading) _buildAutoLoadingBanner(context),

            // Auto-load failure banner
            if (autoLoadStatus == AutoLoadStatus.failed)
              _buildAutoLoadFailedBanner(context, ref),

            // Aggregate count cards
            _buildCountCards(counts),
            const SizedBox(height: 32),

            // Empty state prompt — yükleme sürerken "içerik yok" demek yanlış.
            if (!hasContent && !isLoading) _buildEmptyStatePrompt(context, ref),

            // Health score section
            if (hasContent) ...[
              _buildHealthScore(context, healthScore, errors.length,
                  warnings.length),
              const SizedBox(height: 32),
            ],

            // Action buttons (always visible — includes ZIP import)
            _buildActionButtons(
              context,
              ref,
              hasContent: hasContent,
              isLoading: isLoading,
            ),
            const SizedBox(height: 32),

            // Critical issues summary — yalnızca gerçekten error varken.
            if (hasContent && errors.isNotEmpty)
              _buildCriticalIssues(context, errors),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoLoadingBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        color: scheme.secondaryContainer,
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
                        color: scheme.onSecondaryContainer,
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
    final scheme = Theme.of(context).colorScheme;
    final failure = ref.watch(autoLoadErrorProvider);
    // Health cevap verdiyse sunucu ayakta demektir; "sunucuyu başlat" demek
    // kullanıcıyı bozuk dosyadan uzağa yolluyordu.
    final serverReachable = failure?.serverReachable ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        color: scheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    serverReachable ? Icons.report_problem : Icons.cloud_off,
                    color: scheme.onTertiaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serverReachable
                              ? 'Content could not be loaded'
                              : 'Asset server unavailable',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onTertiaryContainer,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          serverReachable
                              ? 'The asset server answered, but one of the '
                                  'content files could not be read. Fix the '
                                  'file below, then retry.'
                              : 'Could not load content from the server. '
                                  'Start the server or import a ZIP archive '
                                  'instead.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onTertiaryContainer,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (ref.read(contentStateProvider).hasAnyContent) {
                        final proceed = await _confirmReloadFromServer(context);
                        if (!proceed) return;
                      }
                      ref
                          .read(autoLoadProvider.notifier)
                          .performAutoLoad(force: true);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
              if (failure != null) ...[
                const SizedBox(height: 12),
                _buildMonospaceBlock(context, failure.message,
                    icon: Icons.error_outline),
              ],
              if (!serverReachable) ...[
                const SizedBox(height: 12),
                _buildMonospaceBlock(
                  context,
                  'cd islami-bilgi-yarismasi/server && dart run bin/server.dart',
                  icon: Icons.terminal,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonospaceBlock(BuildContext context, String text,
      {required IconData icon}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.onInverseSurface, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: scheme.onInverseSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStatePrompt(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                color: scheme.onSecondaryContainer, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No content loaded',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSecondaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Import a ZIP archive or individual JSON files to get started.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
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

  Widget _buildHealthScore(
    BuildContext context,
    double score,
    int errorCount,
    int warningCount,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final color = score >= 80
        ? scheme.primary
        : score >= 50
            ? scheme.tertiary
            : scheme.error;

    // Skoru düşüren warning'ler hiçbir yerde görünmüyordu; "some issues"
    // demek yerine kaç error / kaç warning olduğunu yaz.
    final parts = <String>[
      if (errorCount > 0) '$errorCount ${errorCount == 1 ? 'error' : 'errors'}',
      if (warningCount > 0)
        '$warningCount ${warningCount == 1 ? 'warning' : 'warnings'}',
    ];
    final summary = parts.isEmpty
        ? 'All validation checks passing'
        : '${parts.join(' · ')} need attention';

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
                    backgroundColor: scheme.surfaceContainerHighest,
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
            // Expanded olmadan dar pencerede satır taşıyordu.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health Score',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref, {
    required bool hasContent,
    required bool isLoading,
  }) {
    final canExport = hasContent && !isLoading;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.icon(
          onPressed: () => context.go('/validation'),
          icon: const Icon(Icons.verified),
          label: const Text('Validate All'),
        ),
        Tooltip(
          message: canExport
              ? 'Download every content file as a ZIP archive'
              : isLoading
                  ? 'Wait for the asset server load to finish'
                  : 'Nothing to export yet — import content first',
          child: FilledButton.tonalIcon(
            onPressed: canExport ? () => _handleExport(context, ref) : null,
            icon: const Icon(Icons.file_download),
            label: const Text('Export ZIP'),
          ),
        ),
        FilledButton.tonalIcon(
          // Yükleme sürerken import etmek, biten auto-load ile yarışıyor.
          onPressed: isLoading ? null : () => _handleImport(context, ref),
          icon: const Icon(Icons.file_upload),
          label: const Text('Import'),
        ),
      ],
    );
  }

  Widget _buildCriticalIssues(BuildContext context, List<dynamic> errors) {
    final scheme = Theme.of(context).colorScheme;
    final displayErrors = errors.take(5).toList();

    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Critical Issues (${errors.length} total)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Hataya gitmenin yolu yoktu; satır tıklanınca rapora götür.
            ...displayErrors.map(
              (error) => InkWell(
                onTap: () => context.go('/validation'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 8, color: scheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${error.sourceFile}: ${error.message}',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (errors.length > 5)
              InkWell(
                onTap: () => context.go('/validation'),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '... and ${errors.length - 5} more',
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontStyle: FontStyle.italic,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Seçim akışında hiçbir şey olmadığında sessiz kalmamak için.
  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleImport(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
      allowMultiple: true,
      withData: true,
    );

    // Kullanıcı iptal etti — söylenecek bir şey yok.
    if (result == null || result.files.isEmpty) return;

    final zipFiles =
        result.files.where((f) => f.extension?.toLowerCase() == 'zip').toList();
    final jsonFiles =
        result.files.where((f) => f.extension?.toLowerCase() == 'json').toList();

    if (zipFiles.isEmpty && jsonFiles.isEmpty) {
      if (!context.mounted) return;
      _notify(
        context,
        'Unsupported file type: ${result.files.map((f) => f.name).join(', ')} '
        '— select a .zip archive or .json files.',
      );
      return;
    }

    final importer = ZipImporter();
    ContentState? importedState;
    List<ImportIssue> issues = [];
    Set<String> providedFiles = {};
    FeedbackContentState? importedFeedback;
    GameConfigState? importedGameConfig;
    // Seçilip kullanılmayan dosyalar sessizce düşüyordu.
    final ignoredFiles = <String>[];

    if (zipFiles.isNotEmpty) {
      // Import from the first ZIP file
      final zipFile = zipFiles.first;
      if (zipFile.bytes == null) {
        if (!context.mounted) return;
        _notify(
          context,
          'Could not read ${zipFile.name} — nothing was imported.',
        );
        return;
      }
      ignoredFiles.addAll(
        [...zipFiles.skip(1), ...jsonFiles].map((f) => f.name),
      );
      final bundle = importer.importAll(zipFile.bytes!);
      importedState = bundle.content;
      issues = bundle.issues;
      providedFiles = bundle.providedFiles;
      importedFeedback = bundle.feedback;
      importedGameConfig = bundle.gameConfig;
    } else {
      // Import individual JSON files
      final Map<String, Uint8List> fileMap = {};
      for (final file in jsonFiles) {
        if (file.bytes != null && file.name.isNotEmpty) {
          fileMap[file.name] = file.bytes!;
        } else {
          ignoredFiles.add(file.name);
        }
      }
      if (fileMap.isEmpty) {
        if (!context.mounted) return;
        _notify(
          context,
          'Could not read ${jsonFiles.map((f) => f.name).join(', ')} '
          '— nothing was imported.',
        );
        return;
      }
      final (state, fileIssues) = importer.importFiles(fileMap);
      importedState = state;
      issues = fileIssues;
      providedFiles = fileMap.keys.toSet();
      final extras = importer.parseExtras(fileMap);
      issues = [...issues, ...extras.issues];
      importedFeedback = extras.feedback;
      importedGameConfig = extras.gameConfig;
    }

    if (ignoredFiles.isNotEmpty) {
      issues = [
        ...issues,
        for (final name in ignoredFiles)
          ImportIssue(
            fileName: name,
            message: zipFiles.isNotEmpty
                ? 'Ignored — only the first ZIP archive '
                    '(${zipFiles.first.name}) was imported.'
                : 'Ignored — the file could not be read.',
            severity: ImportIssueSeverity.warning,
          ),
      ];
    }

    // ERROR seviyesindeki sorunlar import'u bloklar — aksi halde yarım parse
    // edilmiş (boş) bir state uygulanıyor ve auto-save onu diske yazıyordu.
    // WARNING bloklamaz.
    if (hasBlockingErrors(issues)) {
      if (!context.mounted) return;
      _showImportIssues(context, issues, blocked: true);
      return;
    }

    // Import mevcut state'i ezer ve undo yığınını da temizler — kaydedilmemiş
    // değişiklik varken bu geri alınamaz, o yüzden önce onay iste.
    if (ref.read(hasUnsavedWorkProvider)) {
      if (!context.mounted) return;
      final proceed = await _confirmOverwrite(context);
      if (!proceed) return;
    }

    // Yalnızca gerçekten gelen dosyaların dilimlerini uygula; verilmeyenler
    // mevcut state'ten korunur.
    final mergedState = mergeImportedSlices(
      ref.read(contentStateProvider),
      importedState,
      providedFiles,
    );

    // Auto-save only subscribes after a loaded session. Mark first so the
    // import itself is queued instead of sitting only in memory.
    if (ref.read(autoLoadProvider) != AutoLoadStatus.loaded) {
      ref.read(autoLoadProvider.notifier).markSessionLoaded();
    }

    if (importedFeedback != null) {
      ref.read(feedbackLoadProvider.notifier).markLoaded();
      ref.read(feedbackContentProvider.notifier).importContent(importedFeedback);
    }
    if (importedGameConfig != null) {
      ref.read(gameConfigLoadProvider.notifier).markLoaded();
      ref.read(gameConfigProvider.notifier).importContent(importedGameConfig);
    }

    ref.read(contentStateProvider.notifier).importContent(mergedState);
    if (!ref.read(isServerConnectedProvider)) {
      ref.read(savedBaselineProvider.notifier).state = mergedState;
    }
    ref.read(historyProvider.notifier).clear();
    ref.read(autoSaveControllerProvider.notifier).queueAllFiles();

    if (!context.mounted) return;

    // Onay sorulmayan (temiz) akışta bile ne olduğu söylenmeli: hangi dosyalar
    // değişti ve undo yığını silindi.
    final summary = _importSummary(providedFiles);
    if (issues.isNotEmpty) {
      _showImportIssues(context, issues, summary: summary);
    } else {
      _notify(context, summary);
    }
  }

  String _importSummary(Set<String> providedFiles) {
    final names = providedFiles.toList()..sort();
    final label = names.isEmpty
        ? 'no files'
        : names.length <= 3
            ? names.join(', ')
            : '${names.length} files';
    return 'Imported $label — undo history cleared';
  }

  /// Kaydedilmemiş değişiklikler üzerine yazmadan önce onay ister.
  Future<bool> _confirmOverwrite(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Unsaved Changes?'),
        content: const Text(
          'You have unsaved changes. Importing replaces them with the '
          'selected files and clears the undo history — this cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  /// Retry after a failed auto-load would otherwise replace ZIP work.
  Future<bool> _confirmReloadFromServer(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reload from Server?'),
        content: const Text(
          'This browser already has content. Reloading replaces it with '
          'the files on the asset server and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reload'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  /// Import sorunlarını listeler. [blocked] true ise hiçbir değişiklik
  /// uygulanmamıştır ve başlık bunu söyler.
  void _showImportIssues(
    BuildContext context,
    List<ImportIssue> issues, {
    bool blocked = false,
    String? summary,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(blocked ? 'Import Blocked' : 'Import Issues'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (blocked) ...[
                const Text(
                  'Nothing was imported — the existing content is unchanged.',
                ),
                const SizedBox(height: 12),
              ] else if (summary != null) ...[
                Text(summary),
                const SizedBox(height: 12),
              ],
              Flexible(
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
                            ? Theme.of(ctx).colorScheme.error
                            : Theme.of(ctx).colorScheme.tertiary,
                      ),
                      title: Text(issue.fileName),
                      subtitle: Text(issue.message),
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

  Future<void> _handleExport(BuildContext context, WidgetRef ref) async {
    final state = ref.read(contentStateProvider);
    final exporter = ref.read(zipExporterProvider);

    try {
      final zipBytes = exporter.exportZip(
        state,
        feedback: ref.read(feedbackContentProvider),
        gameConfig: ref.read(gameConfigProvider),
      );

      // Trigger browser download
      downloadFile(zipBytes, 'content_export.zip');

      // ZIP indirmesi sunucuya yazmaz. Bağlıyken baseline'ı ilerletmek,
      // diskteki dosyalar eskiyken dirty göstergesini ve çıkış uyarısını
      // susturuyordu.
      if (!ref.read(isServerConnectedProvider)) {
        ref.read(savedBaselineProvider.notifier).state = state;
      }

      if (!context.mounted) return;
      _notify(context, 'Export successful — download started');
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
                        leading: Icon(Icons.error,
                            color: Theme.of(ctx).colorScheme.error),
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
    } catch (e) {
      // Validation dışı hatalar sessizce yutuluyordu: kullanıcı indirme
      // başlamadığını hiçbir yerden anlayamıyordu.
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export Failed'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('The ZIP archive could not be created:'),
                const SizedBox(height: 12),
                SelectableText('$e'),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: scheme.primary),
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
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
