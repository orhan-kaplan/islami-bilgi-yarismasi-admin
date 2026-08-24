import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/phone_mockup_frame.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/question_preview_dialog.dart';

void main() {
  // Uzun soru metni + matching tipinde 4 uzun çift + açıklama: toplam içerik
  // 693px'lik sabit PhoneMockupFrame yüksekliğini rahatça aşacak şekilde
  // kurgulandı (bkz. phone_mockup_frame.dart frameHeight).
  const longMatchingQuestion = QuestionModel(
    questionText:
        'Aşağıdaki peygamberler ile onlara verilen mucizeleri veya '
        'kitapları doğru şekilde eşleştiriniz. Her bir satırı dikkatlice '
        'okuyup karşılığını bulunuz.',
    optionA: 'Hz. Musa (a.s.) | Tevrat ve Asa Mucizesi ile Denizin Yarılması',
    optionB: 'Hz. İsa (a.s.) | İncil ve Ölüleri Diriltme Mucizesi',
    optionC: 'Hz. Davud (a.s.) | Zebur ve Demiri Yumuşatma Mucizesi',
    optionD: 'Hz. Muhammed (s.a.v.) | Kur\'an-ı Kerim ve Mirac Mucizesi',
    correctOption: 'A',
    explanation:
        'Her peygambere kavmine uygun, dönemin en etkili mucizesi ile '
        'birlikte gönderilmiş bir kitap veya sahife verilmiştir. Bu '
        'eşleştirmeler İslam inancının temel bilgilerindendir.',
    type: 'matching',
  );

  Widget createTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showQuestionPreviewDialog(
                context,
                question: longMatchingQuestion,
              ),
              child: const Text('Önizle'),
            ),
          ),
        ),
      ),
    );
  }

  group('QuestionPreviewDialog — sabit çerçevede taşma koruması', () {
    testWidgets(
        'long question + matching options does not overflow the fixed phone frame',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Bug varken burada RenderFlex overflow (Expanded + sınırsız satırlı
      // soru kartı sabit 693px'i aşınca) FlutterError fırlatır.
      expect(tester.takeException(), isNull);

      expect(
        find.descendant(
          of: find.byType(PhoneMockupFrame),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
        reason:
            'Çerçeve içeriği kaydırılabilir olmalı, aksi halde taşan kısım '
            'ClipRRect tarafından sessizce gizlenir.',
      );

      // Açıklama kutusu ilk pump'ta ekranda olmasa bile, kaydırılınca
      // görünür olmalı — içerik gerçekten erişilebilir mi diye kanıtlar.
      await tester.scrollUntilVisible(
        find.text(longMatchingQuestion.explanation!),
        200.0,
        scrollable: find.descendant(
          of: find.byType(PhoneMockupFrame),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text(longMatchingQuestion.explanation!), findsOneWidget);
    });
  });
}
