import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/admin_theme.dart';
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

    return MaterialApp.router(
      title: 'İlim Yolculuğu Admin',
      theme: adminTheme,
      darkTheme: adminDarkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
