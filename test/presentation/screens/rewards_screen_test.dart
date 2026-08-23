import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/rewards/rewards_screen.dart';

/// Thumbnail URL'ine her `build`'de `DateTime.now()` cache-buster'ı ekleniyordu:
/// ekran her yeniden çizildiğinde (ekleme, silme, undo, herhangi bir
/// ContentState değişimi) URL değişip görseller baştan indiriliyor ve liste
/// gözle görülür şekilde titriyordu.
void main() {
  const book = BookModel(
    id: 1,
    title: 'Kitap',
    description: '',
    assetImage: 'assets/images/book_1.png',
    bookOrder: 1,
    seriesId: 1,
    contentFile: 'book_1.json',
  );
  const reward = RewardModel(
    title: 'Mekke Rozeti',
    description: 'Açıklama',
    assetImage: 'assets/images/rewards/badge.png',
    unlockBookId: 1,
  );

  String thumbnailUrl(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image).first);
    return (image.image as NetworkImage).url;
  }

  testWidgets('reward thumbnail URL stays identical across rebuilds',
      (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isServerConnectedProvider.overrideWithValue(true),
          contentStateProvider.overrideWith(
            (ref) => ContentNotifier(
              const ContentState(
                series: [],
                books: [book],
                contentFiles: {},
                rewards: [reward],
                hadiths: [],
              ),
            ),
          ),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(home: RewardsScreen());
          },
        ),
      ),
    );
    await tester.pump();

    final firstUrl = thumbnailUrl(tester);
    expect(firstUrl, contains('images/rewards/badge.png'));

    // Gerçek duvar saatini ilerlet: cache-buster build başına hesaplanıyorsa
    // ikinci URL farklı bir `t` taşır.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );

    // Alakasız bir ContentState mutasyonu ekranı yeniden çizdirir.
    container.read(contentStateProvider.notifier).addHadith(
          const HadithModel(text: 'Hadis', source: 'Kaynak'),
        );
    await tester.pump();

    expect(
      thumbnailUrl(tester),
      firstUrl,
      reason: 'aynı görsel için URL rebuild başına değişmemeli',
    );
  });

  testWidgets('thumbnail URL is refreshed when the reward image path changes',
      (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isServerConnectedProvider.overrideWithValue(true),
          contentStateProvider.overrideWith(
            (ref) => ContentNotifier(
              const ContentState(
                series: [],
                books: [book],
                contentFiles: {},
                rewards: [reward],
                hadiths: [],
              ),
            ),
          ),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(home: RewardsScreen());
          },
        ),
      ),
    );
    await tester.pump();
    final firstUrl = thumbnailUrl(tester);

    container.read(contentStateProvider.notifier).updateReward(
          0,
          const RewardModel(
            title: 'Mekke Rozeti',
            description: 'Açıklama',
            assetImage: 'assets/images/rewards/badge_v2.png',
            unlockBookId: 1,
          ),
        );
    await tester.pump();

    final secondUrl = thumbnailUrl(tester);
    expect(secondUrl, contains('images/rewards/badge_v2.png'));
    expect(secondUrl, isNot(firstUrl));
  });
}
