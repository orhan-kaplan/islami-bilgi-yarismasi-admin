import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/save_gating.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';

/// Aradaki bir level silinince `level_order` boşluk bırakıyordu; validator bunu
/// ERROR sayıyor ve `isSaveAllowedForFile` o content dosyasının auto-save'ini
/// bloklayarak silmeyi diske hiç yazmıyordu.
void main() {
  LevelModel level(int id, int order) => LevelModel(
        id: id,
        bookId: 1,
        categoryName: 'c',
        levelOrder: order,
        title: 'L$id',
        unlockScore: 0,
        questions: const [],
      );

  const book = BookModel(
    id: 1,
    title: 'Kitap',
    description: 'Açıklama',
    assetImage: 'assets/images/book_1.png',
    bookOrder: 1,
    seriesId: 1,
    contentFile: 'book_1.json',
  );
  const series = SeriesModel(
    id: 1,
    name: 'Seri',
    sortOrder: 1,
    isLocked: false,
    iconEmoji: '📚',
  );

  ContentNotifier notifierWithLevels() => ContentNotifier(ContentState(
        series: const [series],
        books: const [book],
        contentFiles: {
          'book_1.json': [level(1, 1), level(2, 2), level(3, 3)],
        },
        rewards: const [],
        hadiths: const [],
      ));

  test('ortadaki level silinince kalanlar 1..N yeniden numaralanır', () {
    final notifier = notifierWithLevels();

    notifier.deleteLevel('book_1.json', 2);

    final levels = notifier.state.contentFiles['book_1.json']!;
    expect(levels.map((l) => l.id).toList(), [1, 3]);
    expect(levels.map((l) => l.levelOrder).toList(), [1, 2]);
  });

  test('silme sonrası content dosyasının kaydı bloklanmaz', () {
    final notifier = notifierWithLevels();

    notifier.deleteLevel('book_1.json', 2);

    final issues = ContentValidator().validateAll(notifier.state);
    final orderErrors = issues.where(
      (i) =>
          i.severity == ValidationSeverity.error &&
          i.sourceFile == 'content/book_1.json' &&
          i.message.contains('level_order'),
    );
    expect(orderErrors, isEmpty);
    expect(
      isSaveAllowedForFile('data/content/book_1.json', issues),
      isTrue,
      reason: 'silme diske yazılabilmeli',
    );
  });

  test('son level silinince kalanların sırası bozulmaz', () {
    final notifier = notifierWithLevels();

    notifier.deleteLevel('book_1.json', 3);

    final levels = notifier.state.contentFiles['book_1.json']!;
    expect(levels.map((l) => l.levelOrder).toList(), [1, 2]);
  });

  test('tek level silinince liste boşalır', () {
    final notifier = ContentNotifier(ContentState(
      series: const [],
      books: const [],
      contentFiles: {
        'book_1.json': [level(1, 1)],
      },
      rewards: const [],
      hadiths: const [],
    ));

    notifier.deleteLevel('book_1.json', 1);

    expect(notifier.state.contentFiles['book_1.json'], isEmpty);
  });
}
