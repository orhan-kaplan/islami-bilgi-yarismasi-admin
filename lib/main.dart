import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/admin_theme.dart';
import 'presentation/providers/auto_load_providers.dart';
import 'presentation/providers/connectivity_providers.dart';
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

    // Eagerly initialize connectivity and auto-load providers
    // so they start polling/loading immediately on app start.
    ref.watch(serverConnectivityProvider);
    ref.watch(autoLoadProvider);

    return MaterialApp.router(
      title: 'İlim Yolculuğu Admin',
      theme: adminTheme,
      darkTheme: adminDarkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
