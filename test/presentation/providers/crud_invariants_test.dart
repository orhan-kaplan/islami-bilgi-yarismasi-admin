import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/save_gating.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';

SeriesModel _series(int id, int sortOrder) => SeriesModel(
      id: id,
      name: 'Series $id',
      sortOrder: sortOrder,
      isLocked: false,
      iconEmoji: '📚',
    );

BookModel _book({
  required int id,
  required int seriesId,
  required int bookOrder,
}) =>
    BookModel(
      id: id,
      title: 'Book $id',
      description: 'Desc',
      assetImage: 'assets/images/book_$id.png',
      bookOrder: bookOrder,
      seriesId: seriesId,
      contentFile: 'book_$id.json',
    );

LevelModel _level({required int id, required int bookId, int levelOrder = 1}) =>
    LevelModel(
      id: id,
      bookId: bookId,
      categoryName: 'Cat',
      levelOrder: levelOrder,
      title: 'Level $id',
      unlockScore: 0,
      questions: const [],
    );

ContentNotifier _notifier(ContentState state) => ContentNotifier(state);

List<int> _seriesOrders(ContentNotifier notifier) =>
    (List<SeriesModel>.from(notifier.state.series)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
        .map((s) => s.sortOrder)
        .toList();

List<int> _bookOrders(ContentNotifier notifier, int seriesId) =>
    (notifier.state.books.where((b) => b.seriesId == seriesId).toList()
          ..sort((a, b) => a.bookOrder.compareTo(b.bookOrder)))
        .map((b) => b.bookOrder)
        .toList();

void main() {
  group('deleteSeries compact sort_order (B1)', () {
    test(
        'deleting a middle empty series renumbers the rest so series.json '
        'save is not blocked', () {
      final notifier = _notifier(ContentState(
        series: [_series(1, 1), _series(2, 2), _series(3, 3)],
        books: const [],
        contentFiles: const {},
        rewards: const [],
        hadiths: const [],
      ));

      expect(notifier.deleteSeries(2), isTrue);
      expect(
        notifier.state.series.map((s) => s.id).toList(),
        [1, 3],
      );
      expect(_seriesOrders(notifier), [1, 2]);

      final issues = ContentValidator().validateAll(notifier.state);
      expect(
        isSaveAllowedForFile('data/series.json', issues),
        isTrue,
        reason: 'a sort_order gap after deleting series 2 must not block save',
      );
    });
  });

  group('deleteBook compact book_order (B2)', () {
    test(
        'deleting a middle empty book renumbers the rest so books.json '
        'save is not blocked', () {
      final notifier = _notifier(ContentState(
        series: [_series(1, 1)],
        books: [
          _book(id: 1, seriesId: 1, bookOrder: 1),
          _book(id: 2, seriesId: 1, bookOrder: 2),
          _book(id: 3, seriesId: 1, bookOrder: 3),
        ],
        contentFiles: const {
          'book_1.json': [],
          'book_2.json': [],
          'book_3.json': [],
        },
        rewards: const [],
        hadiths: const [],
      ));

      expect(notifier.deleteBook(2), isTrue);
      expect(
        notifier.state.books.map((b) => b.id).toList(),
        [1, 3],
      );
      expect(_bookOrders(notifier, 1), [1, 2]);
      expect(
        notifier.state.books.firstWhere((b) => b.id == 3).bookOrder,
        2,
      );

      final issues = ContentValidator().validateAll(notifier.state);
      expect(
        isSaveAllowedForFile('data/books.json', issues),
        isTrue,
        reason: 'a book_order gap after deleting book 2 must not block save',
      );
    });

    test('compacting one series does not rewrite another series book_order',
        () {
      final notifier = _notifier(ContentState(
        series: [_series(1, 1), _series(2, 2)],
        books: [
          _book(id: 1, seriesId: 1, bookOrder: 1),
          _book(id: 2, seriesId: 1, bookOrder: 2),
          _book(id: 10, seriesId: 2, bookOrder: 1),
        ],
        contentFiles: const {
          'book_1.json': [],
          'book_2.json': [],
          'book_10.json': [],
        },
        rewards: const [],
        hadiths: const [],
      ));

      expect(notifier.deleteBook(1), isTrue);
      expect(
        notifier.state.books.firstWhere((b) => b.id == 10).bookOrder,
        1,
      );
      expect(_bookOrders(notifier, 1), [1]);
    });
  });

  group('updateBook rebalances book_order on series change (B3)', () {
    test(
        'moving a book to another series appends it and compacts both series '
        'so books.json save is not blocked', () {
      final notifier = _notifier(ContentState(
        series: [_series(1, 1), _series(2, 2)],
        books: [
          _book(id: 1, seriesId: 1, bookOrder: 1),
          _book(id: 2, seriesId: 1, bookOrder: 2),
          _book(id: 3, seriesId: 1, bookOrder: 3),
          _book(id: 10, seriesId: 2, bookOrder: 1),
        ],
        contentFiles: const {
          'book_1.json': [],
          'book_2.json': [],
          'book_3.json': [],
          'book_10.json': [],
        },
        rewards: const [],
        hadiths: const [],
      ));

      notifier.updateBook(
        _book(id: 2, seriesId: 2, bookOrder: 2),
      );

      final moved = notifier.state.books.firstWhere((b) => b.id == 2);
      expect(moved.seriesId, 2);
      expect(moved.bookOrder, 2, reason: 'moved book is appended in dest');
      expect(_bookOrders(notifier, 1), [1, 2]);
      expect(
        notifier.state.books.firstWhere((b) => b.id == 3).bookOrder,
        2,
      );
      expect(_bookOrders(notifier, 2), [1, 2]);

      final issues = ContentValidator().validateAll(notifier.state);
      expect(
        isSaveAllowedForFile('data/books.json', issues),
        isTrue,
        reason: 'series move must not leave a book_order gap or collision',
      );
    });

    test('title-only updateBook leaves book_order and seriesId unchanged', () {
      final original = _book(id: 2, seriesId: 1, bookOrder: 2);
      final notifier = _notifier(ContentState(
        series: [_series(1, 1)],
        books: [
          _book(id: 1, seriesId: 1, bookOrder: 1),
          original,
        ],
        contentFiles: const {
          'book_1.json': [],
          'book_2.json': [],
        },
        rewards: const [],
        hadiths: const [],
      ));

      notifier.updateBook(original.copyWith(title: 'Renamed'));

      final updated = notifier.state.books.firstWhere((b) => b.id == 2);
      expect(updated.title, 'Renamed');
      expect(updated.seriesId, 1);
      expect(updated.bookOrder, 2);
    });
  });

  group('add* rejects duplicate IDs (B4)', () {
    test('addSeries with an existing id does not append a second series', () {
      final notifier = ContentNotifier();
      notifier.addSeries(_series(1, 1).copyWith(name: 'First'));
      notifier.addSeries(_series(1, 2).copyWith(name: 'Second'));

      expect(notifier.state.series, hasLength(1));
      expect(notifier.state.series.single.name, 'First');
      expect(notifier.state.series.single.sortOrder, 1);
    });

    test('addBook with an existing id does not append or touch contentFiles',
        () {
      final notifier = ContentNotifier();
      notifier.addBook(_book(id: 1, seriesId: 1, bookOrder: 1));
      notifier.addLevel(
        'book_1.json',
        _level(id: 10, bookId: 1),
      );

      notifier.addBook(
        _book(id: 1, seriesId: 1, bookOrder: 2).copyWith(
          title: 'Duplicate',
          contentFile: 'book_dup.json',
        ),
      );

      expect(notifier.state.books, hasLength(1));
      expect(notifier.state.books.single.title, 'Book 1');
      expect(notifier.state.contentFiles.containsKey('book_dup.json'), isFalse);
      expect(
        notifier.state.contentFiles['book_1.json']!.single.id,
        10,
      );
    });

    test('addLevel with an id already used in another file is ignored', () {
      final notifier = ContentNotifier();
      notifier.addBook(_book(id: 1, seriesId: 1, bookOrder: 1));
      notifier.addBook(_book(id: 2, seriesId: 1, bookOrder: 2));
      notifier.addLevel('book_1.json', _level(id: 5, bookId: 1));
      notifier.addLevel(
        'book_2.json',
        _level(id: 5, bookId: 2, levelOrder: 1),
      );

      expect(notifier.state.contentFiles['book_1.json']!.single.id, 5);
      expect(notifier.state.contentFiles['book_2.json'], isEmpty);
    });

    test('addLevel with a fresh global id still appends', () {
      final notifier = ContentNotifier();
      notifier.addBook(_book(id: 1, seriesId: 1, bookOrder: 1));
      notifier.addLevel('book_1.json', _level(id: 5, bookId: 1));
      notifier.addLevel(
        'book_1.json',
        _level(id: 6, bookId: 1, levelOrder: 2),
      );

      expect(
        notifier.state.contentFiles['book_1.json']!.map((l) => l.id).toList(),
        [5, 6],
      );
    });
  });
}
