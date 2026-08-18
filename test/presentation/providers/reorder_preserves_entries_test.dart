import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';

/// Reorder, `newOrder` listesinde adı geçmeyen kayıtları yok saymamalı.
///
/// Eksik ID'li bir çağrı `deleteSeries`'in "kitabı olan seri silinemez"
/// guard'ını atlatan bir silme yoluna dönüşüyordu. Üç reorder metodu da
/// aynı girdide aynı şekilde davranmalı: kayıt korunur, sıra 1..N kalır.
void main() {
  SeriesModel series(int id, int order) => SeriesModel(
        id: id,
        name: 'S$id',
        sortOrder: order,
        isLocked: false,
        iconEmoji: '📚',
      );

  BookModel book(int id, int seriesId, int order) => BookModel(
        id: id,
        title: 'B$id',
        description: '',
        assetImage: 'assets/images/b$id.png',
        bookOrder: order,
        seriesId: seriesId,
        contentFile: 'book_$id.json',
      );

  LevelModel level(int id, int order) => LevelModel(
        id: id,
        bookId: 1,
        categoryName: 'c',
        levelOrder: order,
        title: 'L$id',
        unlockScore: 0,
        questions: const [],
      );

  group('reorderSeries', () {
    test('newOrder dışında kalan seriyi silmez', () {
      final notifier = ContentNotifier(ContentState(
        series: [series(1, 1), series(2, 2), series(3, 3)],
        books: const [],
        contentFiles: const {},
        rewards: const [],
        hadiths: const [],
      ));

      notifier.reorderSeries([2, 1]);

      expect(
        notifier.state.series.map((s) => s.id).toSet(),
        {1, 2, 3},
        reason: 'newOrder\'da geçmeyen seri 3 durmalı',
      );
    });

    test('eksik girdi sonrası sort_order 1..N ardışık kalır', () {
      final notifier = ContentNotifier(ContentState(
        series: [series(1, 1), series(2, 2), series(3, 3)],
        books: const [],
        contentFiles: const {},
        rewards: const [],
        hadiths: const [],
      ));

      notifier.reorderSeries([3, 1]);

      final orders = notifier.state.series.map((s) => s.sortOrder).toList()
        ..sort();
      expect(orders, [1, 2, 3]);
      // Listelenenler öne geçer, kalanlar arkaya eklenir.
      final byId = {for (final s in notifier.state.series) s.id: s.sortOrder};
      expect(byId[3], 1);
      expect(byId[1], 2);
      expect(byId[2], 3);
    });
  });

  group('reorderLevels', () {
    test('newOrder dışında kalan level\'ı silmez', () {
      final notifier = ContentNotifier(ContentState(
        series: const [],
        books: const [],
        contentFiles: {
          'book_1.json': [level(1, 1), level(2, 2), level(3, 3)],
        },
        rewards: const [],
        hadiths: const [],
      ));

      notifier.reorderLevels('book_1.json', [3, 2]);

      final levels = notifier.state.contentFiles['book_1.json']!;
      expect(levels.map((l) => l.id).toSet(), {1, 2, 3});
      final orders = levels.map((l) => l.levelOrder).toList()..sort();
      expect(orders, [1, 2, 3]);
    });
  });

  group('reorderBooks', () {
    test('newOrder dışında kalan kitap çakışan book_order üretmez', () {
      final notifier = ContentNotifier(ContentState(
        series: const [],
        books: [book(1, 1, 1), book(2, 1, 2), book(3, 1, 3)],
        contentFiles: const {},
        rewards: const [],
        hadiths: const [],
      ));

      // 3 ve 2 öne alınınca listede geçmeyen kitap 1 eski sırasını (1)
      // koruyor ve yeni atanan 1 ile çakışıyordu.
      notifier.reorderBooks(1, [3, 2]);

      final orders = notifier.state.books.map((b) => b.bookOrder).toList()
        ..sort();
      expect(
        orders,
        [1, 2, 3],
        reason: 'kitap 3 eski sırasını koruyunca çakışma oluşuyordu',
      );
      expect(notifier.state.books.length, 3);
    });

    test('başka serinin kitaplarına dokunmaz', () {
      final notifier = ContentNotifier(ContentState(
        series: const [],
        books: [book(1, 1, 1), book(2, 1, 2), book(9, 2, 1)],
        contentFiles: const {},
        rewards: const [],
        hadiths: const [],
      ));

      notifier.reorderBooks(1, [2, 1]);

      final other = notifier.state.books.firstWhere((b) => b.id == 9);
      expect(other.bookOrder, 1);
      expect(other.seriesId, 2);
    });
  });
}
