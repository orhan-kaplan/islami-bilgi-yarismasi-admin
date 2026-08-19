import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/history_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/hadiths/hadiths_screen.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/rewards/rewards_screen.dart';

/// Hadis ve ödül mutasyonları undo/redo yığınına hiç girmiyordu: silme geri
/// alınamıyor, sonraki undo'lar ise yanlış anı restore ediyordu (silinen kayıt
/// alakasız bir undo'da geri gelirken o sırada yapılan başka değişiklikler
/// kayboluyordu).
void main() {
  const hadith = HadithModel(text: 'Hadis metni', source: 'Buhârî');
  const reward = RewardModel(
    title: 'Mekke Rozeti',
    description: 'Açıklama',
    assetImage: 'assets/images/rewards/badge.png',
    unlockBookId: 1,
  );
  const book = BookModel(
    id: 1,
    title: 'Kitap',
    description: '',
    assetImage: 'assets/images/book_1.png',
    bookOrder: 1,
    seriesId: 1,
    contentFile: 'book_1.json',
  );

  ProviderContainer? container;

  Future<ProviderContainer> pump(WidgetTester tester, Widget screen,
      ContentState initial) async {
    final scope = ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(false),
        contentStateProvider.overrideWith((ref) => ContentNotifier(initial)),
      ],
      child: MaterialApp(home: screen),
    );
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(MaterialApp));
    container = ProviderScope.containerOf(element);
    return container!;
  }

  /// Silme artık onay ister — tek yanlış tıkla kayıt gitmemeli.
  Future<void> confirmDelete(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
  }

  Future<void> cancelDelete(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
  }

  ContentState stateWith({
    List<HadithModel> hadiths = const [],
    List<RewardModel> rewards = const [],
    List<BookModel> books = const [],
  }) =>
      ContentState(
        series: const [],
        books: books,
        contentFiles: const {},
        rewards: rewards,
        hadiths: hadiths,
      );

  group('Hadiths', () {
    testWidgets('silme undo yığınına girer ve geri alınabilir',
        (tester) async {
      final c = await pump(
          tester, const HadithsScreen(), stateWith(hadiths: [hadith]));

      await confirmDelete(tester, 'Delete hadith');

      expect(c.read(contentStateProvider).hadiths, isEmpty);
      expect(c.read(canUndoProvider), isTrue,
          reason: 'silme geri alınabilir olmalı');

      final restored =
          c.read(historyProvider.notifier).undo(c.read(contentStateProvider));
      expect(restored!.hadiths, [hadith]);
    });

    testWidgets('onay iptal edilince silinmez', (tester) async {
      final c = await pump(
          tester, const HadithsScreen(), stateWith(hadiths: [hadith]));

      await cancelDelete(tester, 'Delete hadith');

      expect(c.read(contentStateProvider).hadiths, [hadith]);
      expect(c.read(canUndoProvider), isFalse,
          reason: 'iptal edilen silme geçmişe girmemeli');
    });

    testWidgets('ekleme undo yığınına girer', (tester) async {
      final c = await pump(tester, const HadithsScreen(), stateWith());

      await tester.tap(find.widgetWithText(FilledButton, 'Add Hadith'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Yeni hadis');
      await tester.enterText(find.byType(TextFormField).at(1), 'Müslim');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(c.read(contentStateProvider).hadiths.length, 1);
      expect(c.read(canUndoProvider), isTrue);
    });

    testWidgets('güncelleme undo yığınına girer', (tester) async {
      final c = await pump(
          tester, const HadithsScreen(), stateWith(hadiths: [hadith]));

      await tester.tap(find.byTooltip('Edit hadith'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Değişti');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(c.read(contentStateProvider).hadiths.first.text, 'Değişti');
      expect(c.read(canUndoProvider), isTrue);
    });
  });

  group('Rewards', () {
    testWidgets('silme undo yığınına girer ve geri alınabilir',
        (tester) async {
      final c = await pump(tester, const RewardsScreen(),
          stateWith(rewards: [reward], books: [book]));

      await confirmDelete(tester, 'Delete reward');

      expect(c.read(contentStateProvider).rewards, isEmpty);
      expect(c.read(canUndoProvider), isTrue,
          reason: 'silme geri alınabilir olmalı');

      final restored =
          c.read(historyProvider.notifier).undo(c.read(contentStateProvider));
      expect(restored!.rewards, [reward]);
    });

    testWidgets('onay iptal edilince silinmez', (tester) async {
      final c = await pump(tester, const RewardsScreen(),
          stateWith(rewards: [reward], books: [book]));

      await cancelDelete(tester, 'Delete reward');

      expect(c.read(contentStateProvider).rewards, [reward]);
      expect(c.read(canUndoProvider), isFalse,
          reason: 'iptal edilen silme geçmişe girmemeli');
    });

    testWidgets('güncelleme undo yığınına girer', (tester) async {
      final c = await pump(tester, const RewardsScreen(),
          stateWith(rewards: [reward], books: [book]));

      await tester.tap(find.byTooltip('Edit reward'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Yeni başlık');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(c.read(contentStateProvider).rewards.first.title, 'Yeni başlık');
      expect(c.read(canUndoProvider), isTrue);
    });
  });
}
