import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/reward_preview_dialog.dart';

void main() {
  // Uzun başlık + açıklama: hem "Koleksiyon" hem "Kazanım" sekmesindeki kart
  // sabit 693px'lik PhoneMockupFrame'i aşabilecek şekilde kurgulandı.
  const longReward = RewardModel(
    title: 'Kur\'an-ı Kerim\'in İlk Üç Cüzünü Başarıyla Tamamlayan Hafız Adayı',
    description:
        'Bu ünvanı kazanmak için Kur\'an-ı Kerim\'in ilk üç cüzünü baştan '
        'sona eksiksiz bir şekilde ezberlemen ve ilgili tüm quizlerden '
        'başarıyla geçmen gerekiyor. Bu gerçekten büyük bir başarı!',
    assetImage: 'images/rewards/placeholder.png',
    unlockBookId: 1,
  );

  Widget createTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showRewardPreviewDialog(
                context,
                reward: longReward,
              ),
              child: const Text('Önizle'),
            ),
          ),
        ),
      ),
    );
  }

  group('RewardPreviewDialog — sabit çerçevede taşma koruması', () {
    testWidgets(
        'long title and description do not overflow the fixed frame on either tab',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Koleksiyon sekmesi (varsayılan, index 0).
      expect(tester.takeException(), isNull);

      // Kazanım sekmesine geç (index 1).
      await tester.tap(find.text('Kazanım'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
