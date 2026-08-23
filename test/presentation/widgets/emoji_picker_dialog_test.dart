import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/emoji_picker_dialog.dart';

/// ID23 — admin arayüzü İngilizce (CLAUDE.md; `app_shell_test` aynı kuralı
/// NavigationRail için zaten kilitliyor).
void main() {
  Future<String?> open(WidgetTester tester, {String? current}) async {
    String? selected;
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  opened = true;
                  selected =
                      await showEmojiPickerDialog(context, currentEmoji: current);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    return selected;
  }

  testWidgets('emoji picker chrome is English', (tester) async {
    await open(tester, current: '🌟');

    expect(find.text('Select an emoji'), findsOneWidget);
    expect(find.text('Current: 🌟'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.text('Success & celebration'), findsOneWidget);

    for (final turkish in [
      'Emoji Seç',
      'Mevcut: 🌟',
      'İptal',
      'Başarı & Kutlama',
      'Dini & Manevi',
      'Eğitim & Bilgi',
      'Duygular & İfadeler',
      'Doğa & Zaman',
      'Semboller',
    ]) {
      expect(find.text(turkish), findsNothing, reason: '$turkish Türkçe kaldı');
    }
  });

  testWidgets('tapping an emoji still closes the dialog with that emoji',
      (tester) async {
    await open(tester);

    await tester.tap(find.text('🏆'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
