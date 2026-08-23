import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:islami_bilgi_yarismasi_admin/data/services/asset_server_client.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/asset_server_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/lottie_picker_dialog.dart';

void main() {
  /// Listeleme isteğine verilen yanıtı test başına belirler.
  AssetServerClient clientThatReturns(http.Response Function() respond) {
    return AssetServerClient(
      baseUrl: 'http://localhost:8080',
      client: http_testing.MockClient((request) async => respond()),
    );
  }

  Future<void> openPicker(WidgetTester tester, AssetServerClient client) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [assetServerClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showLottiePickerDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// ID15 — sunucu hatasında `_files` boş listeye çekiliyordu: kullanıcı hem
  /// kırpılmış bir hata satırı hem de "dosya yok" boş durumu görüyor, hangisinin
  /// doğru olduğunu anlayamıyor ve yeniden deneyemiyordu.
  group('server failure is shown as a failure', () {
    testWidgets('does not claim the folder is empty', (tester) async {
      await openPicker(
        tester,
        clientThatReturns(() => http.Response('boom', 500)),
      );

      expect(
        find.text('No Lottie files yet'),
        findsNothing,
        reason: 'sunucu hatası "dosya yok" gibi sunulmamalı',
      );
      expect(find.textContaining('Could not load'), findsOneWidget);
    });

    testWidgets('offers a retry that reloads the list', (tester) async {
      var shouldFail = true;
      await openPicker(
        tester,
        clientThatReturns(
          () => shouldFail
              ? http.Response('boom', 500)
              : http.Response(
                  jsonEncode([
                    {
                      'name': 'celebration.json',
                      'path': 'lottie/feedback/celebration.json',
                      'size': 12,
                      'type': 'file',
                    }
                  ]),
                  200,
                ),
        ),
      );

      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

      shouldFail = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(find.text('celebration.json'), findsOneWidget);
      expect(find.textContaining('Could not load'), findsNothing);
    });

    testWidgets('an empty folder still shows the empty state', (tester) async {
      await openPicker(
        tester,
        clientThatReturns(() => http.Response('[]', 200)),
      );

      expect(find.text('No Lottie files yet'), findsOneWidget);
      expect(find.textContaining('Could not load'), findsNothing);
    });
  });

  /// ID16 — dialog barrier'a tıklanınca kapanıyordu; yükleme sırasında bu,
  /// dosyanın sunucuya yazılıp mesaja hiç bağlanmaması ve kullanıcının bunu
  /// hiç öğrenmemesi demekti.
  testWidgets('tapping outside does not dismiss the picker', (tester) async {
    await openPicker(
      tester,
      clientThatReturns(() => http.Response('[]', 200)),
    );
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: 'picker yalnız Cancel / seçim ile kapanmalı',
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  /// ID23 — admin arayüzü İngilizce.
  testWidgets('picker chrome is English', (tester) async {
    await openPicker(
      tester,
      clientThatReturns(() => http.Response('[]', 200)),
    );

    expect(find.text('Select a Lottie animation'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Upload new'), findsOneWidget);
    for (final turkish in [
      'Lottie Animasyonu Seç',
      'Yeni Yükle',
      'İptal',
      'Henüz Lottie dosyası yok',
    ]) {
      expect(find.text(turkish), findsNothing, reason: '$turkish Türkçe kaldı');
    }
  });
}
