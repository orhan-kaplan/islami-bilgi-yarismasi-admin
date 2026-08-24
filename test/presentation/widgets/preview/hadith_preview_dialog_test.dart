import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/hadith_preview_dialog.dart';

void main() {
  const longHadith = HadithModel(
    text:
        'İlim öğrenmek her Müslüman erkek ve kadına farz kılınmıştır; ilim '
        'Çin\'de dahi olsa gidip aranmalıdır ve beşikten mezara kadar bu '
        'yolculuk hiç durmadan devam etmelidir.',
    source: 'İbn Mace',
  );

  Widget createTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showHadithPreviewDialog(
                context,
                hadith: longHadith,
              ),
              child: const Text('Önizle'),
            ),
          ),
        ),
      ),
    );
  }

  group('HadithPreviewDialog — mobil ile satır sınırı tutarlılığı', () {
    testWidgets(
        'hadith text is capped at maxLines: 3, matching the mobile dashboard card',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final hadithTextFinder = find.text(longHadith.text);
      expect(hadithTextFinder, findsOneWidget);

      final hadithTextWidget = tester.widget<Text>(hadithTextFinder);

      // Mobildeki dashboard_hadith.dart aynı kartı maxLines: 3 ile kırpıyor.
      // Admin önizlemesi 5 satır gösterirse, editör mobilde kesilecek bir
      // metni "tam sığıyor" sanarak onaylayabilir — bu test o sapmayı kilitler.
      expect(hadithTextWidget.maxLines, 3);
      expect(hadithTextWidget.overflow, TextOverflow.ellipsis);
    });
  });
}
