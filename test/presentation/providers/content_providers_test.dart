import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';

void main() {
  late ContentNotifier notifier;

  setUp(() {
    notifier = ContentNotifier();
  });

  group('importContent', () {
    test('replaces entire state', () {
      final newState = ContentState(
        series: [
          const SeriesModel(
            id: 1,
            name: 'Test Series',
            sortOrder: 1,
            isLocked: false,
            iconEmoji: '📚',
          ),
        ],
        books: const [],
        contentFiles: const {},
        rewards: const [],
        hadiths: const [],
      );

      notifier.importContent(newState);

      expect(notifier.state, equals(newState));
      expect(notifier.state.series.length, 1);
      expect(notifier.state.series.first.name, 'Test Series');
    });
  });

  group('Series CRUD', () {
    test('addSeries adds to list', () {
      const series = SeriesModel(
        id: 1,
        name: 'Series 1',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '🕌',
      );

      notifier.addSeries(series);

      expect(notifier.state.series.length, 1);
      expect(notifier.state.series.first, series);
    });

    test('updateSeries replaces by ID', () {
      const series = SeriesModel(
        id: 1,
        name: 'Original',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '🕌',
      );
      notifier.addSeries(series);

      final updated = series.copyWith(name: 'Updated');
      notifier.updateSeries(updated);

      expect(notifier.state.series.first.name, 'Updated');
    });

    test('deleteSeries removes when no books', () {
      const series = SeriesModel(
        id: 1,
        name: 'Series 1',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '🕌',
      );
      notifier.addSeries(series);

      final result = notifier.deleteSeries(1);

      expect(result, true);
      expect(notifier.state.series, isEmpty);
    });

    test('deleteSeries blocks when series has books', () {
      const series = SeriesModel(
        id: 1,
        name: 'Series 1',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '🕌',
      );
      const book = BookModel(
        id: 1,
        title: 'Book 1',
        description: 'Desc',
        assetImage: 'assets/img.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );
      notifier.addSeries(series);
      notifier.addBook(book);

      final result = notifier.deleteSeries(1);

      expect(result, false);
      expect(notifier.state.series.length, 1);
    });
  });

  group('Book CRUD', () {
    test('addBook adds to list', () {
      const book = BookModel(
        id: 1,
        title: 'Book 1',
        description: 'Desc',
        assetImage: 'assets/img.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );

      notifier.addBook(book);

      expect(notifier.state.books.length, 1);
      expect(notifier.state.books.first, book);
      expect(notifier.state.contentFiles.containsKey('book_1.json'), isTrue);
      expect(notifier.state.contentFiles['book_1.json'], isEmpty);
    });

    test('updateBook replaces by ID', () {
      const book = BookModel(
        id: 1,
        title: 'Original',
        description: 'Desc',
        assetImage: 'assets/img.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );
      notifier.addBook(book);

      final updated = book.copyWith(title: 'Updated');
      notifier.updateBook(updated);

      expect(notifier.state.books.first.title, 'Updated');
    });

    test('deleteBook removes when no levels in contentFiles', () {
      const book = BookModel(
        id: 1,
        title: 'Book 1',
        description: 'Desc',
        assetImage: 'assets/img.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );
      notifier.addBook(book);

      final result = notifier.deleteBook(1);

      expect(result, true);
      expect(notifier.state.books, isEmpty);
      expect(notifier.state.contentFiles.containsKey('book_1.json'), isFalse);
    });

    test('deleteBook blocks when book has levels in contentFiles', () {
      const book = BookModel(
        id: 1,
        title: 'Book 1',
        description: 'Desc',
        assetImage: 'assets/img.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );
      const level = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Cat',
        levelOrder: 1,
        title: 'Level 1',
        unlockScore: 0,
        questions: [],
      );
      notifier.addBook(book);
      notifier.addLevel('book_1.json', level);

      final result = notifier.deleteBook(1);

      expect(result, false);
      expect(notifier.state.books.length, 1);
    });
  });

  group('Level CRUD', () {
    test('addLevel adds to content file level list', () {
      const level = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Category',
        levelOrder: 1,
        title: 'Level 1',
        unlockScore: 0,
        questions: [],
      );

      notifier.addLevel('book_1.json', level);

      expect(notifier.state.contentFiles['book_1.json']?.length, 1);
      expect(notifier.state.contentFiles['book_1.json']?.first, level);
    });

    test('updateLevel replaces by ID within content file', () {
      const level = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Original',
        levelOrder: 1,
        title: 'Level 1',
        unlockScore: 0,
        questions: [],
      );
      notifier.addLevel('book_1.json', level);

      final updated = level.copyWith(categoryName: 'Updated');
      notifier.updateLevel('book_1.json', updated);

      expect(
        notifier.state.contentFiles['book_1.json']?.first.categoryName,
        'Updated',
      );
    });

    test('deleteLevel removes level and all its questions', () {
      const question = QuestionModel(
        questionText: 'Q?',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
      );
      const level = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Cat',
        levelOrder: 1,
        title: 'Level 1',
        unlockScore: 0,
        questions: [question, question],
      );
      notifier.addLevel('book_1.json', level);

      notifier.deleteLevel('book_1.json', 1);

      expect(notifier.state.contentFiles['book_1.json'], isEmpty);
    });
  });

  group('Question CRUD', () {
    late LevelModel level;

    setUp(() {
      level = const LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Cat',
        levelOrder: 1,
        title: 'Level 1',
        unlockScore: 0,
        questions: [],
      );
      notifier.addLevel('book_1.json', level);
    });

    test('addQuestion adds to level question list', () {
      const question = QuestionModel(
        questionText: 'What is 1+1?',
        optionA: '2',
        optionB: '3',
        optionC: '4',
        optionD: '5',
        correctOption: 'A',
      );

      notifier.addQuestion('book_1.json', 1, question);

      final questions =
          notifier.state.contentFiles['book_1.json']!.first.questions;
      expect(questions.length, 1);
      expect(questions.first.questionText, 'What is 1+1?');
    });

    test('updateQuestion replaces at index', () {
      const question = QuestionModel(
        questionText: 'Original',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
      );
      notifier.addQuestion('book_1.json', 1, question);

      const updated = QuestionModel(
        questionText: 'Updated',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'B',
      );
      notifier.updateQuestion('book_1.json', 1, 0, updated);

      final questions =
          notifier.state.contentFiles['book_1.json']!.first.questions;
      expect(questions.first.questionText, 'Updated');
      expect(questions.first.correctOption, 'B');
    });

    test('deleteQuestion removes at index', () {
      const q1 = QuestionModel(
        questionText: 'Q1',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
      );
      const q2 = QuestionModel(
        questionText: 'Q2',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'B',
      );
      notifier.addQuestion('book_1.json', 1, q1);
      notifier.addQuestion('book_1.json', 1, q2);

      notifier.deleteQuestion('book_1.json', 1, 0);

      final questions =
          notifier.state.contentFiles['book_1.json']!.first.questions;
      expect(questions.length, 1);
      expect(questions.first.questionText, 'Q2');
    });
  });

  group('Reorder', () {
    test('reorderSeries assigns sequential sort_order values', () {
      const s1 = SeriesModel(
        id: 1,
        name: 'S1',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      );
      const s2 = SeriesModel(
        id: 2,
        name: 'S2',
        sortOrder: 2,
        isLocked: false,
        iconEmoji: '📗',
      );
      const s3 = SeriesModel(
        id: 3,
        name: 'S3',
        sortOrder: 3,
        isLocked: false,
        iconEmoji: '📘',
      );
      notifier.addSeries(s1);
      notifier.addSeries(s2);
      notifier.addSeries(s3);

      // Reverse order
      notifier.reorderSeries([3, 1, 2]);

      final series = notifier.state.series;
      expect(series.length, 3);
      expect(series[0].id, 3);
      expect(series[0].sortOrder, 1);
      expect(series[1].id, 1);
      expect(series[1].sortOrder, 2);
      expect(series[2].id, 2);
      expect(series[2].sortOrder, 3);
    });

    test('reorderBooks assigns sequential book_order values within series', () {
      const b1 = BookModel(
        id: 1,
        title: 'B1',
        description: 'D',
        assetImage: 'assets/b1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );
      const b2 = BookModel(
        id: 2,
        title: 'B2',
        description: 'D',
        assetImage: 'assets/b2.png',
        bookOrder: 2,
        seriesId: 1,
        contentFile: 'book_2.json',
      );
      const b3 = BookModel(
        id: 3,
        title: 'B3',
        description: 'D',
        assetImage: 'assets/b3.png',
        bookOrder: 1,
        seriesId: 2,
        contentFile: 'book_3.json',
      );
      notifier.addBook(b1);
      notifier.addBook(b2);
      notifier.addBook(b3);

      // Reverse books in series 1
      notifier.reorderBooks(1, [2, 1]);

      final books = notifier.state.books;
      final series1Books = books.where((b) => b.seriesId == 1).toList();
      expect(series1Books.firstWhere((b) => b.id == 2).bookOrder, 1);
      expect(series1Books.firstWhere((b) => b.id == 1).bookOrder, 2);
      // Series 2 book unchanged
      expect(books.firstWhere((b) => b.id == 3).bookOrder, 1);
    });

    test('reorderLevels assigns sequential level_order values', () {
      const l1 = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'C1',
        levelOrder: 1,
        title: 'L1',
        unlockScore: 0,
        questions: [],
      );
      const l2 = LevelModel(
        id: 2,
        bookId: 1,
        categoryName: 'C2',
        levelOrder: 2,
        title: 'L2',
        unlockScore: 0,
        questions: [],
      );
      notifier.addLevel('book_1.json', l1);
      notifier.addLevel('book_1.json', l2);

      // Reverse order
      notifier.reorderLevels('book_1.json', [2, 1]);

      final levels = notifier.state.contentFiles['book_1.json']!;
      expect(levels[0].id, 2);
      expect(levels[0].levelOrder, 1);
      expect(levels[1].id, 1);
      expect(levels[1].levelOrder, 2);
    });
  });

  group('Auto-ID generation', () {
    test('nextSeriesId returns 1 when empty', () {
      expect(notifier.nextSeriesId, 1);
    });

    test('nextSeriesId returns max + 1', () {
      notifier.addSeries(const SeriesModel(
        id: 5,
        name: 'S5',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      ));
      notifier.addSeries(const SeriesModel(
        id: 3,
        name: 'S3',
        sortOrder: 2,
        isLocked: false,
        iconEmoji: '📗',
      ));

      expect(notifier.nextSeriesId, 6);
    });

    test('nextBookId returns 1 when empty', () {
      expect(notifier.nextBookId, 1);
    });

    test('nextBookId returns max + 1', () {
      notifier.addBook(const BookModel(
        id: 10,
        title: 'B10',
        description: 'D',
        assetImage: 'assets/b.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_10.json',
      ));
      notifier.addBook(const BookModel(
        id: 7,
        title: 'B7',
        description: 'D',
        assetImage: 'assets/b.png',
        bookOrder: 2,
        seriesId: 1,
        contentFile: 'book_7.json',
      ));

      expect(notifier.nextBookId, 11);
    });

    test('nextLevelId returns 1 when empty', () {
      expect(notifier.nextLevelId, 1);
    });

    test('nextLevelId returns max across ALL content files + 1', () {
      notifier.addLevel(
        'book_1.json',
        const LevelModel(
          id: 5,
          bookId: 1,
          categoryName: 'C',
          levelOrder: 1,
          title: 'L5',
          unlockScore: 0,
          questions: [],
        ),
      );
      notifier.addLevel(
        'book_2.json',
        const LevelModel(
          id: 12,
          bookId: 2,
          categoryName: 'C',
          levelOrder: 1,
          title: 'L12',
          unlockScore: 0,
          questions: [],
        ),
      );
      notifier.addLevel(
        'book_1.json',
        const LevelModel(
          id: 3,
          bookId: 1,
          categoryName: 'C',
          levelOrder: 2,
          title: 'L3',
          unlockScore: 0,
          questions: [],
        ),
      );

      expect(notifier.nextLevelId, 13);
    });
  });

  group('Deletion guards - state unchanged', () {
    test('deleteSeries with books returns false, state unchanged', () {
      const series = SeriesModel(
        id: 1,
        name: 'S1',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
      );
      const book = BookModel(
        id: 1,
        title: 'B1',
        description: 'D',
        assetImage: 'assets/b.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );
      notifier.addSeries(series);
      notifier.addBook(book);

      final stateBefore = notifier.state;
      final result = notifier.deleteSeries(1);

      expect(result, false);
      expect(notifier.state, equals(stateBefore));
    });

    test('deleteBook with levels returns false, state unchanged', () {
      const book = BookModel(
        id: 1,
        title: 'B1',
        description: 'D',
        assetImage: 'assets/b.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );
      const level = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'C',
        levelOrder: 1,
        title: 'L1',
        unlockScore: 0,
        questions: [],
      );
      notifier.addBook(book);
      notifier.addLevel('book_1.json', level);

      final stateBefore = notifier.state;
      final result = notifier.deleteBook(1);

      expect(result, false);
      expect(notifier.state, equals(stateBefore));
    });
  });

  group('Reward CRUD', () {
    test('addReward adds to list', () {
      const reward = RewardModel(
        title: 'Reward 1',
        description: 'Desc',
        assetImage: 'assets/r.png',
        unlockBookId: 1,
      );

      notifier.addReward(reward);

      expect(notifier.state.rewards.length, 1);
      expect(notifier.state.rewards.first, reward);
    });

    test('updateReward replaces at index', () {
      const reward = RewardModel(
        title: 'Original',
        description: 'Desc',
        assetImage: 'assets/r.png',
        unlockBookId: 1,
      );
      notifier.addReward(reward);

      final updated = reward.copyWith(title: 'Updated');
      notifier.updateReward(0, updated);

      expect(notifier.state.rewards.first.title, 'Updated');
    });

    test('deleteReward removes at index', () {
      const r1 = RewardModel(
        title: 'R1',
        description: 'D1',
        assetImage: 'assets/r1.png',
        unlockBookId: 1,
      );
      const r2 = RewardModel(
        title: 'R2',
        description: 'D2',
        assetImage: 'assets/r2.png',
        unlockBookId: 2,
      );
      notifier.addReward(r1);
      notifier.addReward(r2);

      notifier.deleteReward(0);

      expect(notifier.state.rewards.length, 1);
      expect(notifier.state.rewards.first.title, 'R2');
    });
  });

  group('Hadith CRUD', () {
    test('addHadith adds to list', () {
      const hadith = HadithModel(
        text: 'Hadith text',
        source: 'Bukhari',
      );

      notifier.addHadith(hadith);

      expect(notifier.state.hadiths.length, 1);
      expect(notifier.state.hadiths.first, hadith);
    });

    test('updateHadith replaces at index', () {
      const hadith = HadithModel(
        text: 'Original',
        source: 'Bukhari',
      );
      notifier.addHadith(hadith);

      final updated = hadith.copyWith(text: 'Updated');
      notifier.updateHadith(0, updated);

      expect(notifier.state.hadiths.first.text, 'Updated');
    });

    test('deleteHadith removes at index', () {
      const h1 = HadithModel(text: 'H1', source: 'S1');
      const h2 = HadithModel(text: 'H2', source: 'S2');
      notifier.addHadith(h1);
      notifier.addHadith(h2);

      notifier.deleteHadith(0);

      expect(notifier.state.hadiths.length, 1);
      expect(notifier.state.hadiths.first.text, 'H2');
    });
  });
}
