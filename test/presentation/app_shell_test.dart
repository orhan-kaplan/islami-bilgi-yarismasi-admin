// AppShell (NavigationRail + connectivity/unsaved indicators) `dart:js_interop`
// ile browser event'leri dinleyen AppShortcuts/BeforeUnloadGuard içinde kurulu
// — VM'de pump edilemez.
@TestOn('chrome')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/auto_save_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/router/app_router.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        assetServerClientProvider.overrideWithValue(
          AssetServerClient(
            baseUrl: 'http://localhost:8080',
            client: MockClient((_) async => http.Response('down', 500)),
          ),
        ),
        ...extraOverrides,
      ],
      child: Consumer(
        builder: (context, ref, _) {
          return MaterialApp.router(routerConfig: ref.watch(routerProvider));
        },
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> teardownScope(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  /// Admin UI İngilizce olmalı (CLAUDE.md kuralı); "Oyun" mobil Türkçe kopyanın
  /// nav rail'e sızmış hâliydi.
  testWidgets('NavigationRail sekmeleri İngilizce gösterir, "Oyun" değil',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('Oyun'), findsNothing,
        reason: 'Admin UI\'da Türkçe etiket olmamalı');
    expect(find.text('Game'), findsOneWidget,
        reason: 'game-config sekmesi İngilizce etiketle gösterilmeli');

    await teardownScope(tester);
  });

  /// hasSaveErrorProvider hem validasyon bloklarını hem sunucunun reddettiği
  /// yazımları kapsıyor (bkz. auto_save_providers.dart yorumu), ama tooltip
  /// yalnızca "Check the Validation screen" diyordu — sunucu/bağlantı kaynaklı
  /// bir hatada kullanıcı yanlış yere yönlendiriliyordu.
  testWidgets(
      'kayıt hatası tooltip\'i Validation dışında bağlantı/sunucu olasılığını '
      'da belirtir',
      (tester) async {
    await pumpApp(
      tester,
      extraOverrides: [hasSaveErrorProvider.overrideWithValue(true)],
    );

    final tooltipFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Tooltip &&
          (widget.message?.startsWith('Save failed') ?? false),
    );
    expect(tooltipFinder, findsOneWidget);

    final tooltip = tester.widget<Tooltip>(tooltipFinder);
    expect(tooltip.message, contains('connection'),
        reason: 'Sunucu kaynaklı bir kayıt hatası Validation ekranında hiç '
            'görünmeyebilir; tooltip bunu da işaret etmeli');
    expect(
      tooltip.message,
      isNot(equals(
        'Save failed — changes are still only in this browser. '
        'Check the Validation screen.',
      )),
      reason: 'eski metin yalnızca Validation\'a işaret ediyordu',
    );

    await teardownScope(tester);
  });
}
