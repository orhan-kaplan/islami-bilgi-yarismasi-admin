import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/history_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/book_form.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/series_form.dart';

/// `deleteSeries` ve `deleteBook` guard'lı ve testli olmalarına rağmen hiçbir
/// UI'dan çağrılmıyordu: yanlış eklenen bir seriyi/kitabı silmenin tek yolu
/// ZIP export → elle düzenle → import idi.
void main() {
  const series = SeriesModel(
    id: 1,
    name: 'Seri',
    sortOrder: 1,
    isLocked: false,
    iconEmoji: '📗',
  );

  const book = BookModel(
    id: 7,
    title: 'Kitap',
    description: 'Açıklama',
    assetImage: 'assets/images/book_7/book_7.webp',
    bookOrder: 1,
    seriesId: 1,
    contentFile: 'book_7.json',
  );

  const level = LevelModel(
    id: 1,
    bookId: 7,
    categoryName: 'Mekke',
    levelOrder: 1,
    title: 'Bölüm',
    unlockScore: 0,
    questions: [],
  );

  const reward = RewardModel(
    title: 'Rozet',
    description: 'Açıklama',
    assetImage: 'assets/images/rewards/badge.webp',
    unlockBookId: 7,
  );

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget form,
    ContentState initial,
  ) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(false),
        contentStateProvider.overrideWith((ref) => ContentNotifier(initial)),
      ],
      child: MaterialApp(home: Scaffold(body: form)),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  ContentState stateWith({
    List<SeriesModel> series = const [],
    List<BookModel> books = const [],
    Map<String, List<LevelModel>> contentFiles = const {},
    List<RewardModel> rewards = const [],
  }) =>
      ContentState(
        series: series,
        books: books,
        contentFiles: contentFiles,
        rewards: rewards,
        hadiths: const [],
      );

  Future<void> confirmDelete(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
  }

  group('SeriesForm', () {
    testWidgets('kitapsız seri onaydan sonra silinir', (tester) async {
      final c = await pump(
        tester,
        const SeriesForm(series: series),
        stateWith(series: const [series]),
      );

      await confirmDelete(tester, 'Delete series');

      expect(c.read(contentStateProvider).series, isEmpty);
      expect(c.read(canUndoProvider), isTrue,
          reason: 'silme geri alınabilir olmalı');
    });

    testWidgets('onay iptal edilince silinmez', (tester) async {
      final c = await pump(
        tester,
        const SeriesForm(series: series),
        stateWith(series: const [series]),
      );

      await tester.tap(find.byTooltip('Delete series'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(c.read(contentStateProvider).series, [series]);
    });

    testWidgets('kitabı olan seri silinmez, onay bile sorulmaz',
        (tester) async {
      final c = await pump(
        tester,
        const SeriesForm(series: series),
        stateWith(series: const [series], books: const [book]),
      );

      await tester.tap(find.byTooltip('Delete series'));
      await tester.pumpAndSettle();

      // Sonucu baştan belli olan yıkıcı işlem için onay istenmemeli.
      expect(find.byType(AlertDialog), findsNothing,
          reason: 'engellenmiş silme için onay dialogu açılmamalı');
      expect(c.read(contentStateProvider).series, [series]);
      expect(find.textContaining('book'), findsWidgets,
          reason: 'engelin nedeni kullanıcıya söylenmeli');
      expect(c.read(canUndoProvider), isFalse,
          reason: 'engellenen silme undo yığınını kirletmemeli');
    });

    testWidgets('create modunda silme butonu yok', (tester) async {
      await pump(tester, const SeriesForm(), stateWith());

      expect(find.byTooltip('Delete series'), findsNothing);
    });
  });

  group('BookForm', () {
    testWidgets('boş kitap onaydan sonra silinir', (tester) async {
      final c = await pump(
        tester,
        const BookForm(book: book),
        stateWith(
          series: const [series],
          books: const [book],
          contentFiles: const {'book_7.json': []},
        ),
      );

      await confirmDelete(tester, 'Delete book');

      expect(c.read(contentStateProvider).books, isEmpty);
      expect(c.read(canUndoProvider), isTrue);
    });

    testWidgets('level içeren kitap silinmez, onay bile sorulmaz',
        (tester) async {
      final c = await pump(
        tester,
        const BookForm(book: book),
        stateWith(
          series: const [series],
          books: const [book],
          contentFiles: const {
            'book_7.json': [level]
          },
        ),
      );

      await tester.tap(find.byTooltip('Delete book'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing,
          reason: 'engellenmiş silme için onay dialogu açılmamalı');
      expect(c.read(contentStateProvider).books, [book]);
      expect(find.textContaining('level'), findsWidgets,
          reason: 'engelin nedeni kullanıcıya söylenmeli');
      expect(c.read(canUndoProvider), isFalse);
    });

    testWidgets('ödül referansı olan kitap silinmez, onay bile sorulmaz',
        (tester) async {
      final c = await pump(
        tester,
        const BookForm(book: book),
        stateWith(
          series: const [series],
          books: const [book],
          contentFiles: const {'book_7.json': []},
          rewards: const [reward],
        ),
      );

      await tester.tap(find.byTooltip('Delete book'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(c.read(contentStateProvider).books, [book]);
      expect(c.read(canUndoProvider), isFalse);
    });

    testWidgets('create modunda silme butonu yok', (tester) async {
      await pump(
        tester,
        const BookForm(seriesId: 1),
        stateWith(series: const [series]),
      );

      expect(find.byTooltip('Delete book'), findsNothing);
    });
  });
}
