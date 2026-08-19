// AppShortcuts `dart:js_interop` ile browser keydown dinliyor — VM'de
// pump edilemez.
@TestOn('chrome')
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/search_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/router/app_router.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/shortcuts/shortcuts_help_dialog.dart';

/// `onFocusSearch` "Task 5'te bağlanacak" yorumuyla boş bırakılmıştı. Boş
/// callback yine de olayı tüketiyor (`consumesKey` varsayılan true) ve browser
/// handler'ı Ctrl+F'in tarayıcı davranışını da kesiyordu: kısayol ne arama
/// alanını odaklıyor ne de tarayıcının bul çubuğunu açıyordu.
void main() {
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    late ProviderContainer container;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        assetServerClientProvider.overrideWithValue(
          AssetServerClient(
            baseUrl: 'http://localhost:8080',
            client: MockClient((_) async => http.Response('down', 500)),
          ),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return MaterialApp.router(routerConfig: ref.watch(routerProvider));
        },
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> teardownScope(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl+F explorer\'daki arama alanını odaklar', (tester) async {
    final container = await pumpApp(tester);

    await tester.tap(find.text('Explorer'));
    await tester.pumpAndSettle();

    final focusNode = container.read(searchFocusNodeProvider);
    expect(focusNode.hasFocus, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue,
        reason: 'Ctrl+F arama alanına odaklanmalı');

    await teardownScope(tester);
  });

  testWidgets('yardım dialogu Ctrl+S\'i sunucuya kayıt olarak da anlatır',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ShortcutsHelpDialog()),
    ));
    await tester.pumpAndSettle();

    final exportOnly = find.text('Export ZIP');
    expect(exportOnly, findsOneWidget,
        reason: 'Ctrl+S artık yalnızca export demiyor; Ctrl+E hâlâ export');
    expect(find.textContaining('Save'), findsWidgets,
        reason: 'sunucu bağlıyken Ctrl+S kaydediyor, dialog bunu söylemeli');
  });
}
