import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/admin_theme.dart';
import 'presentation/providers/auto_load_providers.dart';
import 'presentation/providers/auto_save_providers.dart';
import 'presentation/providers/connectivity_providers.dart';
import 'presentation/providers/feedback_auto_save_providers.dart';
import 'presentation/providers/game_config_auto_save_providers.dart';
import 'presentation/router/app_router.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AdminApp(),
    ),
  );
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Eagerly initialize connectivity, auto-load, and auto-save.
    // Auto-save notifiers are lazy: without a watch they never subscribe
    // to content changes, so edits would stay in memory until Ctrl/Cmd+S.
    ref.watch(serverConnectivityProvider);
    ref.watch(autoLoadProvider);
    ref.watch(autoSaveControllerProvider);
    ref.watch(feedbackAutoSaveProvider);
    ref.watch(gameConfigAutoSaveProvider);

    return MaterialApp.router(
      title: 'İlim Yolculuğu Admin',
      theme: adminTheme,
      darkTheme: adminDarkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
