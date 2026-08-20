import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/file_download_web.dart';
import '../../data/services/zip_exporter.dart';
import '../providers/auto_load_providers.dart';
import '../providers/auto_save_providers.dart';
import '../providers/connectivity_providers.dart';
import '../providers/content_providers.dart';
import '../providers/feedback_auto_save_providers.dart';
import '../providers/feedback_content_providers.dart';
import '../providers/game_config_auto_save_providers.dart';
import '../providers/game_config_providers.dart';
import '../providers/history_providers.dart';
import '../providers/search_providers.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/explorer/content_explorer_screen.dart';
import '../screens/assets/assets_screen.dart';
import '../screens/feedback/feedback_screen.dart';
import '../screens/game_config/game_config_screen.dart';
import '../screens/hadiths/hadiths_screen.dart';
import '../screens/rewards/rewards_screen.dart';
import '../screens/validation/validation_report_screen.dart';
import '../widgets/shared/beforeunload_guard.dart';
import '../widgets/shortcuts/app_shortcuts.dart';
import '../widgets/shortcuts/shortcuts_help_dialog.dart';

// ---------------------------------------------------------------------------
// App Shell — wraps all screens with a NavigationRail on the left.
// ---------------------------------------------------------------------------

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
  }

  /// Shows a dialog when the server reconnects and there are unsaved changes,
  /// letting the user choose to save to server, reload from server, or dismiss.
  void _showReconnectionDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Server Reconnected'),
          content: const Text(
            'The asset server is back online and you have unsaved changes. '
            'What would you like to do?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Dismiss'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref.read(autoLoadProvider.notifier).performAutoLoad(force: true);
                ref.read(feedbackLoadProvider.notifier).performLoad(force: true);
                ref.read(gameConfigLoadProvider.notifier).performLoad(force: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reloading content from server...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Reload from Server'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                ref
                    .read(autoSaveControllerProvider.notifier)
                    .flushPendingSaves(allFiles: true);
                ref
                    .read(feedbackAutoSaveProvider.notifier)
                    .flushPendingSave(force: true);
                ref
                    .read(gameConfigAutoSaveProvider.notifier)
                    .flushPendingSave(force: true);
                ref.read(autoLoadProvider.notifier).markSyncedToServer();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Saving changes to server...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Save to Server'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDirty = ref.watch(hasUnsavedWorkProvider);
    final connectivity = ref.watch(serverConnectivityProvider);
    final isConnected = connectivity == ServerConnectivity.connected;
    // Kayıt hatası hiçbir yerde görünmüyordu: validasyon nedeniyle bloklanan
    // ya da sunucunun reddettiği bir yazım sessizce kayboluyordu.
    final hasSaveError = ref.watch(hasSaveErrorProvider);

    // Listen for connectivity state changes and show snackbar notifications.
    ref.listen<ServerConnectivity>(serverConnectivityProvider, (previous, next) {
      if (previous == null) return;
      if (previous == next) return;

      if (next == ServerConnectivity.connected &&
          previous == ServerConnectivity.disconnected) {
        // Reconnected — check for unsaved changes
        final hasLocalWork = ref.read(hasUnsavedWorkProvider) ||
            ref.read(hasUnsyncedLocalSessionProvider);
        if (hasLocalWork) {
          _showReconnectionDialog(context, ref);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Asset server connected'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Disconnected
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Asset server disconnected'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: (index) {
              widget.navigationShell.goBranch(
                index,
                initialLocation: index == widget.navigationShell.currentIndex,
              );
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: _ConnectivityIndicator(isConnected: isConnected),
            ),
            trailing: (isDirty || hasSaveError)
                ? Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Tooltip(
                          message: hasSaveError
                              ? 'Save failed — changes are still only in this '
                                  'browser. Check the Validation screen.'
                              : 'Unsaved changes',
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color:
                                  hasSaveError ? Colors.red : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_tree_outlined),
                selectedIcon: Icon(Icons.account_tree),
                label: Text('Explorer'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: Text('Rewards'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: Text('Hadiths'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.image_outlined),
                selectedIcon: Icon(Icons.image),
                label: Text('Assets'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.feedback_outlined),
                selectedIcon: Icon(Icons.feedback),
                label: Text('Feedback'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sports_esports_outlined),
                selectedIcon: Icon(Icons.sports_esports),
                label: Text('Oyun'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified_outlined),
                selectedIcon: Icon(Icons.verified),
                label: Text('Validation'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connectivity Indicator — green/red dot showing server status.
// ---------------------------------------------------------------------------

class _ConnectivityIndicator extends StatelessWidget {
  const _ConnectivityIndicator({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    if (isConnected) {
      return Tooltip(
        message: 'Asset server connected',
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Server disconnected. ZIP import/export available as fallback.',
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Router Provider
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Consumer(
            builder: (context, ref, _) {
              return BeforeUnloadGuard(
                child: AppShortcuts(
                  onUndo: () {
                    final current = ref.read(contentStateProvider);
                    final restored =
                        ref.read(historyProvider.notifier).undo(current);
                    if (restored != null) {
                      ref
                          .read(contentStateProvider.notifier)
                          .importContent(restored);
                    }
                  },
                  onRedo: () {
                    final current = ref.read(contentStateProvider);
                    final restored =
                        ref.read(historyProvider.notifier).redo(current);
                    if (restored != null) {
                      ref
                          .read(contentStateProvider.notifier)
                          .importContent(restored);
                    }
                  },
                  onExport: () {
                    final isConnected =
                        ref.read(isServerConnectedProvider);

                    if (isConnected) {
                      // Connected: flush pending saves to server
                      ref
                          .read(autoSaveControllerProvider.notifier)
                          .flushPendingSaves(allFiles: true);
                      ref
                          .read(feedbackAutoSaveProvider.notifier)
                          .flushPendingSave(force: true);
                      ref
                          .read(gameConfigAutoSaveProvider.notifier)
                          .flushPendingSave(force: true);
                      ref.read(autoLoadProvider.notifier).markSyncedToServer();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Saving...'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else {
                      // Disconnected: ZIP export (existing behavior)
                      final contentState = ref.read(contentStateProvider);
                      final exporter = ZipExporter();
                      try {
                        final zipBytes = exporter.exportZip(
                          contentState,
                          feedback: ref.read(feedbackContentProvider),
                          gameConfig: ref.read(gameConfigProvider),
                        );
                        downloadFile(zipBytes, 'content_export.zip');
                        ref.read(savedBaselineProvider.notifier).state =
                            contentState;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Export successful — download started'),
                          ),
                        );
                      } on ValidationBlockedExportException catch (e) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Export Blocked'),
                            content: SizedBox(
                              width: 400,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Export is blocked due to validation errors:',
                                  ),
                                  const SizedBox(height: 12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        maxHeight: 300),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: e.errors.length,
                                      itemBuilder: (_, index) {
                                        final error = e.errors[index];
                                        return ListTile(
                                          leading: const Icon(Icons.error,
                                              color: Colors.red),
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
                  },
                  onFocusSearch: () {
                    ref.read(searchFocusNodeProvider).requestFocus();
                  },
                  onShowHelp: () => showShortcutsHelpDialog(context),
                  child: AppShell(navigationShell: navigationShell),
                ),
              );
            },
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explorer',
                builder: (context, state) => const ContentExplorerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rewards',
                builder: (context, state) => const RewardsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hadiths',
                builder: (context, state) => const HadithsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/assets',
                builder: (context, state) => const AssetsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feedback',
                builder: (context, state) => const FeedbackScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/game-config',
                builder: (context, state) => const GameConfigScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/validation',
                builder: (context, state) => const ValidationReportScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
