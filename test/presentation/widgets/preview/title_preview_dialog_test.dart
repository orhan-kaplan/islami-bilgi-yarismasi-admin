import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/title_preview_dialog.dart';

void main() {
  // Rozet Row'u mainAxisSize.min ile intrinsic genişlik istiyor; uzun bir
  // ünvan, Expanded'ın verdiği sınırlı genişliği aşıp yatay RenderFlex
  // overflow'a yol açabiliyordu.
  const longTitle = PlayerTitleModel(
    title: 'Kur\'an-ı Kerim\'i Tamamıyla Ezbere Bilen Seçkin Hafız Adayı',
    icon: '🌟',
    requiredBooks: 3,
    profileImage: '',
  );

  Widget createTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showTitlePreviewDialog(
                context,
                title: longTitle,
              ),
              child: const Text('Önizle'),
            ),
          ),
        ),
      ),
    );
  }

  group('TitlePreviewDialog — rozet metninde taşma koruması', () {
    testWidgets('long title text does not overflow the rank chip',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Bug varken burada rozet Row'u yatay RenderFlex overflow fırlatır.
      expect(tester.takeException(), isNull);

      final chipTextFinder = find.text(longTitle.title).last;
      final chipTextWidget = tester.widget<Text>(chipTextFinder);

      expect(chipTextWidget.overflow, TextOverflow.ellipsis);
      expect(chipTextWidget.maxLines, 1);
    });
  });
}
