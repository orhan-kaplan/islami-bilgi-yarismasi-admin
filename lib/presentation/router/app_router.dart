import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/file_download_web.dart';
import '../../data/services/zip_exporter.dart';
import '../providers/content_providers.dart';
import '../providers/history_providers.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/explorer/content_explorer_screen.dart';
import '../screens/hadiths/hadiths_screen.dart';
import '../screens/rewards/rewards_screen.dart';
import '../screens/validation/validation_report_screen.dart';
import '../widgets/shared/beforeunload_guard.dart';
import '../widgets/shortcuts/app_shortcuts.dart';
import '../widgets/shortcuts/shortcuts_help_dialog.dart';

// ---------------------------------------------------------------------------
// App Shell — wraps all screens with a NavigationRail on the left.
// ---------------------------------------------------------------------------

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDirty = ref.watch(isDirtyProvider);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            labelType: NavigationRailLabelType.all,
            trailing: isDirty
                ? Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Tooltip(
                          message: 'Unsaved changes',
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
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
                icon: Icon(Icons.verified_outlined),
                selectedIcon: Icon(Icons.verified),
                label: Text('Validation'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: navigationShell),
        ],
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
                    final contentState = ref.read(contentStateProvider);
                    final exporter = ZipExporter();
                    try {
                      final zipBytes = exporter.exportZip(contentState);
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Export is blocked due to validation errors:',
                                ),
                                const SizedBox(height: 12),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxHeight: 300),
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
                  },
                  onFocusSearch: () {
                    // Will be wired to searchFocusNodeProvider in Task 5
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
