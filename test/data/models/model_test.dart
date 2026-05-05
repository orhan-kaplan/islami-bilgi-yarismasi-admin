import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';

void main() {
  group('SeriesModel', () {
    test('fromJson parses snake_case keys correctly', () {
      final json = {
        'id': 1,
        'name': 'Siyer-i Nebi',
        'sort_order': 1,
        'is_locked': false,
        'icon_emoji': '🕌',
        'description':
            "Peygamber Efendimiz Hz. Muhammed (s.a.v)'in hayatı",
      };

      final model = SeriesModel.fromJson(json);

      expect(model.id, 1);
      expect(model.name, 'Siyer-i Nebi');
      expect(model.sortOrder, 1);
      expect(model.isLocked, false);
      expect(model.iconEmoji, '🕌');
      expect(model.description,
          "Peygamber Efendimiz Hz. Muhammed (s.a.v)'in hayatı");
    });

    test('fromJson handles null description', () {
      final json = {
        'id': 5,
        'name': 'Test',
        'sort_order': 5,
        'is_locked': true,
        'icon_emoji': '📚',
        'description': null,
      };

      final model = SeriesModel.fromJson(json);
      expect(model.description, isNull);
    });

    test('toJson produces snake_case keys', () {
      const model = SeriesModel(
        id: 2,
        name: 'Kısas-ı Enbiya',
        sortOrder: 2,
        isLocked: false,
        iconEmoji: '📖',
        description: 'Peygamberler tarihi ve kıssaları',
      );

      final json = model.toJson();

      expect(json['id'], 2);
      expect(json['name'], 'Kısas-ı Enbiya');
      expect(json['sort_order'], 2);
      expect(json['is_locked'], false);
      expect(json['icon_emoji'], '📖');
      expect(json['description'], 'Peygamberler tarihi ve kıssaları');
    });

    test('round-trip fromJson/toJson preserves data', () {
      final original = {
        'id': 3,
        'name': 'Hulefa-i Raşidin',
        'sort_order': 3,
        'is_locked': true,
        'icon_emoji': '👑',
        'description': 'Dört büyük halife dönemi',
      };

      final model = SeriesModel.fromJson(original);
      final result = model.toJson();

      expect(result, original);
    });

    test('copyWith creates modified copy', () {
      const model = SeriesModel(
        id: 1,
        name: 'Original',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '🕌',
        description: 'Desc',
      );

      final updated = model.copyWith(name: 'Updated', isLocked: true);

      expect(updated.id, 1);
      expect(updated.name, 'Updated');
      expect(updated.isLocked, true);
      expect(updated.sortOrder, 1);
      expect(updated.iconEmoji, '🕌');
      expect(updated.description, 'Desc');
    });

    test('copyWith can set description to null', () {
      const model = SeriesModel(
        id: 1,
        name: 'Test',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
        description: 'Has description',
      );

      final updated = model.copyWith(description: () => null);
      expect(updated.description, isNull);
    });

    test('equality based on all fields', () {
      const a = SeriesModel(
        id: 1,
        name: 'Test',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
        description: 'Desc',
      );
      const b = SeriesModel(
        id: 1,
        name: 'Test',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
        description: 'Desc',
      );
      const c = SeriesModel(
        id: 2,
        name: 'Test',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
        description: 'Desc',
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('BookModel', () {
    test('fromJson parses snake_case keys correctly', () {
      final json = {
        'id': 1,
        'title': 'Mekke Dönemi',
        'description': 'İslam güneşinin doğuşu ve ilk mücadeleler.',
        'asset_image': 'assets/images/book_1/book_1.png',
        'book_order': 1,
        'series_id': 1,
        'content_file': 'book_1.json',
      };

      final model = BookModel.fromJson(json);

      expect(model.id, 1);
      expect(model.title, 'Mekke Dönemi');
      expect(model.description,
          'İslam güneşinin doğuşu ve ilk mücadeleler.');
      expect(model.assetImage, 'assets/images/book_1/book_1.png');
      expect(model.bookOrder, 1);
      expect(model.seriesId, 1);
      expect(model.contentFile, 'book_1.json');
    });

    test('toJson produces snake_case keys', () {
      const model = BookModel(
        id: 2,
        title: 'Medine Dönemi',
        description: 'Hicret, devletleşme ve büyük savaşlar.',
        assetImage: 'assets/images/book_2/book_2.png',
        bookOrder: 2,
        seriesId: 1,
        contentFile: 'book_2.json',
      );

      final json = model.toJson();

      expect(json['id'], 2);
      expect(json['title'], 'Medine Dönemi');
      expect(json['description'],
          'Hicret, devletleşme ve büyük savaşlar.');
      expect(json['asset_image'], 'assets/images/book_2/book_2.png');
      expect(json['book_order'], 2);
      expect(json['series_id'], 1);
      expect(json['content_file'], 'book_2.json');
    });

    test('round-trip fromJson/toJson preserves data', () {
      final original = {
        'id': 3,
        'title': 'Bedir Savaşı',
        'description': "İslam'ın ilk büyük zaferi ve dönüm noktası.",
        'asset_image': 'assets/images/book_3/book_3.png',
        'book_order': 3,
        'series_id': 1,
        'content_file': 'book_3.json',
      };

      final model = BookModel.fromJson(original);
      final result = model.toJson();

      expect(result, original);
    });

    test('copyWith creates modified copy', () {
      const model = BookModel(
        id: 1,
        title: 'Original',
        description: 'Desc',
        assetImage: 'assets/images/book_1/book_1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );

      final updated = model.copyWith(
        title: 'Updated',
        bookOrder: 5,
        seriesId: 2,
      );

      expect(updated.id, 1);
      expect(updated.title, 'Updated');
      expect(updated.description, 'Desc');
      expect(updated.bookOrder, 5);
      expect(updated.seriesId, 2);
      expect(updated.contentFile, 'book_1.json');
    });

    test('equality based on all fields', () {
      const a = BookModel(
        id: 1,
        title: 'Test',
        description: 'Desc',
        assetImage: 'assets/img.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );
      const b = BookModel(
        id: 1,
        title: 'Test',
        description: 'Desc',
        assetImage: 'assets/img.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );
      const c = BookModel(
        id: 1,
        title: 'Different',
        description: 'Desc',
        assetImage: 'assets/img.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('QuestionModel', () {
    test('fromJson parses multiple_choice question correctly', () {
      final json = {
        'question_text': 'Peygamberimiz (s.a.v) nerede doğmuştur?',
        'option_a': 'Mekke',
        'option_b': 'Medine',
        'option_c': 'Taif',
        'option_d': 'Şam',
        'correct_option': 'A',
        'explanation':
            'Peygamberimiz (s.a.v) 571 yılında Mekke\'de doğmuştur.',
        'type': 'multiple_choice',
      };

      final model = QuestionModel.fromJson(json);

      expect(model.questionText,
          'Peygamberimiz (s.a.v) nerede doğmuştur?');
      expect(model.optionA, 'Mekke');
      expect(model.optionB, 'Medine');
      expect(model.optionC, 'Taif');
      expect(model.optionD, 'Şam');
      expect(model.correctOption, 'A');
      expect(model.explanation,
          'Peygamberimiz (s.a.v) 571 yılında Mekke\'de doğmuştur.');
      expect(model.type, 'multiple_choice');
    });

    test('fromJson parses true_false question correctly', () {
      final json = {
        'question_text':
            "Peygamberimizin (s.a.v) süt annesinin adı Halime'dir.",
        'option_a': 'Doğru',
        'option_b': 'Yanlış',
        'option_c': '',
        'option_d': '',
        'correct_option': 'A',
        'explanation': "Evet, Peygamberimizin süt annesi Halime'dir.",
        'type': 'true_false',
      };

      final model = QuestionModel.fromJson(json);

      expect(model.type, 'true_false');
      expect(model.optionA, 'Doğru');
      expect(model.optionB, 'Yanlış');
      expect(model.optionC, '');
      expect(model.optionD, '');
      expect(model.correctOption, 'A');
    });

    test('fromJson parses matching question correctly', () {
      final json = {
        'question_text':
            'Aşağıdaki olayları ve yaşları eşleştiriniz.',
        'option_a': 'Doğumu | 571',
        'option_b': 'Annesinin Vefatı | 6 Yaş',
        'option_c': 'Dedesinin Vefatı | 8 Yaş',
        'option_d': 'Evliliği | 25 Yaş',
        'correct_option': 'A',
        'explanation':
            'Doğumu 571, Annesinin vefatı 6 yaşında, Dedesinin vefatı 8 yaşında, Evliliği 25 yaşında gerçekleşmiştir.',
        'type': 'matching',
      };

      final model = QuestionModel.fromJson(json);

      expect(model.type, 'matching');
      expect(model.optionA, contains('|'));
      expect(model.optionB, contains('|'));
      expect(model.optionC, contains('|'));
      expect(model.optionD, contains('|'));
    });

    test('fromJson parses sorting question correctly', () {
      final json = {
        'question_text':
            'Peygamberimizin soy ağacını geçmişten günümüze sıralayınız.',
        'option_a': 'Hz. İbrahim',
        'option_b': 'Hz. İsmail',
        'option_c': 'Adnan',
        'option_d': 'Hz. Muhammed (s.a.v)',
        'correct_option': 'A',
        'explanation':
            "Soyu Hz. İbrahim'in oğlu Hz. İsmail'e ve onun torunlarından Adnan'a dayanır.",
        'type': 'sorting',
      };

      final model = QuestionModel.fromJson(json);

      expect(model.type, 'sorting');
      expect(model.correctOption, 'A');
      expect(model.optionA, 'Hz. İbrahim');
      expect(model.optionD, 'Hz. Muhammed (s.a.v)');
    });

    test('fromJson defaults type to multiple_choice when missing', () {
      final json = {
        'question_text': 'Test sorusu?',
        'option_a': 'A',
        'option_b': 'B',
        'option_c': 'C',
        'option_d': 'D',
        'correct_option': 'A',
        'explanation': null,
      };

      final model = QuestionModel.fromJson(json);
      expect(model.type, 'multiple_choice');
      expect(model.explanation, isNull);
    });

    test('toJson produces snake_case keys', () {
      const model = QuestionModel(
        questionText: 'Peygamberimiz (s.a.v) nerede doğmuştur?',
        optionA: 'Mekke',
        optionB: 'Medine',
        optionC: 'Taif',
        optionD: 'Şam',
        correctOption: 'A',
        explanation: 'Mekke\'de doğmuştur.',
        type: 'multiple_choice',
      );

      final json = model.toJson();

      expect(json['question_text'],
          'Peygamberimiz (s.a.v) nerede doğmuştur?');
      expect(json['option_a'], 'Mekke');
      expect(json['option_b'], 'Medine');
      expect(json['option_c'], 'Taif');
      expect(json['option_d'], 'Şam');
      expect(json['correct_option'], 'A');
      expect(json['explanation'], 'Mekke\'de doğmuştur.');
      expect(json['type'], 'multiple_choice');
    });

    test('round-trip fromJson/toJson preserves data', () {
      final original = {
        'question_text':
            "Peygamberimizin (s.a.v) süt annesinin adı Halime'dir.",
        'option_a': 'Doğru',
        'option_b': 'Yanlış',
        'option_c': '',
        'option_d': '',
        'correct_option': 'A',
        'explanation': "Evet, Peygamberimizin süt annesi Halime'dir.",
        'type': 'true_false',
      };

      final model = QuestionModel.fromJson(original);
      final result = model.toJson();

      expect(result, original);
    });

    test('copyWith creates modified copy', () {
      const model = QuestionModel(
        questionText: 'Original?',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
        explanation: 'Açıklama',
        type: 'multiple_choice',
      );

      final updated = model.copyWith(
        questionText: 'Updated?',
        correctOption: 'B',
        type: 'true_false',
      );

      expect(updated.questionText, 'Updated?');
      expect(updated.correctOption, 'B');
      expect(updated.type, 'true_false');
      expect(updated.optionA, 'A');
      expect(updated.explanation, 'Açıklama');
    });

    test('copyWith can set explanation to null', () {
      const model = QuestionModel(
        questionText: 'Test?',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
        explanation: 'Has explanation',
      );

      final updated = model.copyWith(explanation: () => null);
      expect(updated.explanation, isNull);
    });

    test('equality based on all fields', () {
      const a = QuestionModel(
        questionText: 'Test?',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
        explanation: 'Exp',
        type: 'multiple_choice',
      );
      const b = QuestionModel(
        questionText: 'Test?',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
        explanation: 'Exp',
        type: 'multiple_choice',
      );
      const c = QuestionModel(
        questionText: 'Different?',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
        explanation: 'Exp',
        type: 'multiple_choice',
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('LevelModel', () {
    // Reusable question fixtures based on actual book_1.json data
    final multipleChoiceJson = {
      'question_text': 'Peygamberimiz (s.a.v) nerede doğmuştur?',
      'option_a': 'Mekke',
      'option_b': 'Medine',
      'option_c': 'Taif',
      'option_d': 'Şam',
      'correct_option': 'A',
      'explanation':
          'Peygamberimiz (s.a.v) 571 yılında Mekke\'de doğmuştur.',
      'type': 'multiple_choice',
    };

    final trueFalseJson = {
      'question_text':
          "Peygamberimizin (s.a.v) süt annesinin adı Halime'dir.",
      'option_a': 'Doğru',
      'option_b': 'Yanlış',
      'option_c': '',
      'option_d': '',
      'correct_option': 'A',
      'explanation': "Evet, Peygamberimizin süt annesi Halime'dir.",
      'type': 'true_false',
    };

    final matchingJson = {
      'question_text':
          'Aşağıdaki olayları ve yaşları eşleştiriniz.',
      'option_a': 'Doğumu | 571',
      'option_b': 'Annesinin Vefatı | 6 Yaş',
      'option_c': 'Dedesinin Vefatı | 8 Yaş',
      'option_d': 'Evliliği | 25 Yaş',
      'correct_option': 'A',
      'explanation':
          'Doğumu 571, Annesinin vefatı 6 yaşında, Dedesinin vefatı 8 yaşında, Evliliği 25 yaşında gerçekleşmiştir.',
      'type': 'matching',
    };

    final sortingJson = {
      'question_text':
          'Peygamberimizin soy ağacını geçmişten günümüze sıralayınız.',
      'option_a': 'Hz. İbrahim',
      'option_b': 'Hz. İsmail',
      'option_c': 'Adnan',
      'option_d': 'Hz. Muhammed (s.a.v)',
      'correct_option': 'A',
      'explanation':
          "Soyu Hz. İbrahim'in oğlu Hz. İsmail'e ve onun torunlarından Adnan'a dayanır.",
      'type': 'sorting',
    };

    test('fromJson parses level with nested questions', () {
      final json = {
        'id': 1,
        'book_id': 1,
        'category_name': 'Siyer-i Nebi',
        'level_order': 1,
        'title': 'Doğuş ve Çocukluk',
        'unlock_score': 0,
        'asset_image': 'assets/images/book_1/level_1.webp',
        'questions': [
          multipleChoiceJson,
          trueFalseJson,
          matchingJson,
          sortingJson,
        ],
      };

      final model = LevelModel.fromJson(json);

      expect(model.id, 1);
      expect(model.bookId, 1);
      expect(model.categoryName, 'Siyer-i Nebi');
      expect(model.levelOrder, 1);
      expect(model.title, 'Doğuş ve Çocukluk');
      expect(model.unlockScore, 0);
      expect(model.assetImage, 'assets/images/book_1/level_1.webp');
      expect(model.questions, hasLength(4));
      expect(model.questions[0].type, 'multiple_choice');
      expect(model.questions[1].type, 'true_false');
      expect(model.questions[2].type, 'matching');
      expect(model.questions[3].type, 'sorting');
    });

    test('fromJson handles null asset_image', () {
      final json = {
        'id': 5,
        'book_id': 1,
        'category_name': 'Test',
        'level_order': 5,
        'title': 'Test Level',
        'unlock_score': 100,
        'asset_image': null,
        'questions': <Map<String, dynamic>>[],
      };

      final model = LevelModel.fromJson(json);
      expect(model.assetImage, isNull);
      expect(model.questions, isEmpty);
    });

    test('toJson produces snake_case keys with nested questions', () {
      const question = QuestionModel(
        questionText: 'Test sorusu?',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
        explanation: 'Açıklama',
        type: 'multiple_choice',
      );

      const model = LevelModel(
        id: 2,
        bookId: 1,
        categoryName: 'Siyer-i Nebi',
        levelOrder: 2,
        title: 'Gençlik Yılları ve Evlilik',
        unlockScore: 50,
        assetImage: 'assets/images/book_1/level_2.webp',
        questions: [question],
      );

      final json = model.toJson();

      expect(json['id'], 2);
      expect(json['book_id'], 1);
      expect(json['category_name'], 'Siyer-i Nebi');
      expect(json['level_order'], 2);
      expect(json['title'], 'Gençlik Yılları ve Evlilik');
      expect(json['unlock_score'], 50);
      expect(json['asset_image'], 'assets/images/book_1/level_2.webp');
      expect(json['questions'], isList);
      expect((json['questions'] as List), hasLength(1));
      expect(
          (json['questions'] as List)[0]['question_text'], 'Test sorusu?');
    });

    test('round-trip fromJson/toJson preserves data', () {
      final original = {
        'id': 1,
        'book_id': 1,
        'category_name': 'Siyer-i Nebi',
        'level_order': 1,
        'title': 'Doğuş ve Çocukluk',
        'unlock_score': 0,
        'asset_image': 'assets/images/book_1/level_1.webp',
        'questions': [
          multipleChoiceJson,
          trueFalseJson,
          matchingJson,
          sortingJson,
        ],
      };

      final model = LevelModel.fromJson(original);
      final result = model.toJson();

      expect(result, original);
    });

    test('copyWith creates modified copy', () {
      const model = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Original',
        levelOrder: 1,
        title: 'Original Title',
        unlockScore: 0,
        assetImage: 'assets/images/book_1/level_1.webp',
        questions: [],
      );

      final updated = model.copyWith(
        title: 'Updated Title',
        unlockScore: 100,
        categoryName: 'Updated Category',
      );

      expect(updated.id, 1);
      expect(updated.bookId, 1);
      expect(updated.title, 'Updated Title');
      expect(updated.unlockScore, 100);
      expect(updated.categoryName, 'Updated Category');
      expect(updated.levelOrder, 1);
      expect(updated.assetImage, 'assets/images/book_1/level_1.webp');
      expect(updated.questions, isEmpty);
    });

    test('copyWith can set assetImage to null', () {
      const model = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Test',
        levelOrder: 1,
        title: 'Test',
        unlockScore: 0,
        assetImage: 'assets/images/book_1/level_1.webp',
        questions: [],
      );

      final updated = model.copyWith(assetImage: () => null);
      expect(updated.assetImage, isNull);
    });

    test('copyWith can replace questions list', () {
      const original = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Test',
        levelOrder: 1,
        title: 'Test',
        unlockScore: 0,
        questions: [],
      );

      const newQuestion = QuestionModel(
        questionText: 'New question?',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'B',
      );

      final updated = original.copyWith(questions: [newQuestion]);
      expect(updated.questions, hasLength(1));
      expect(updated.questions[0].questionText, 'New question?');
    });

    test('equality based on all fields including questions', () {
      const question = QuestionModel(
        questionText: 'Test?',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
      );

      const a = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Test',
        levelOrder: 1,
        title: 'Test',
        unlockScore: 0,
        assetImage: 'assets/img.webp',
        questions: [question],
      );
      const b = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Test',
        levelOrder: 1,
        title: 'Test',
        unlockScore: 0,
        assetImage: 'assets/img.webp',
        questions: [question],
      );
      const c = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Test',
        levelOrder: 1,
        title: 'Different',
        unlockScore: 0,
        assetImage: 'assets/img.webp',
        questions: [question],
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('equality detects different questions lists', () {
      const questionA = QuestionModel(
        questionText: 'Question A?',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
      );
      const questionB = QuestionModel(
        questionText: 'Question B?',
        optionA: 'A',
        optionB: 'B',
        optionC: 'C',
        optionD: 'D',
        correctOption: 'A',
      );

      const levelWithA = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Test',
        levelOrder: 1,
        title: 'Test',
        unlockScore: 0,
        questions: [questionA],
      );
      const levelWithB = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Test',
        levelOrder: 1,
        title: 'Test',
        unlockScore: 0,
        questions: [questionB],
      );

      expect(levelWithA, isNot(equals(levelWithB)));
    });

    test('nested question parsing preserves all four question types', () {
      final json = {
        'id': 1,
        'book_id': 1,
        'category_name': 'Siyer-i Nebi',
        'level_order': 1,
        'title': 'Doğuş ve Çocukluk',
        'unlock_score': 0,
        'asset_image': 'assets/images/book_1/level_1.webp',
        'questions': [
          multipleChoiceJson,
          trueFalseJson,
          matchingJson,
          sortingJson,
        ],
      };

      final model = LevelModel.fromJson(json);

      // Verify multiple_choice
      final mc = model.questions[0];
      expect(mc.type, 'multiple_choice');
      expect(mc.questionText,
          'Peygamberimiz (s.a.v) nerede doğmuştur?');
      expect(mc.optionA, 'Mekke');
      expect(mc.correctOption, 'A');

      // Verify true_false
      final tf = model.questions[1];
      expect(tf.type, 'true_false');
      expect(tf.optionA, 'Doğru');
      expect(tf.optionB, 'Yanlış');
      expect(tf.optionC, '');
      expect(tf.optionD, '');

      // Verify matching
      final m = model.questions[2];
      expect(m.type, 'matching');
      expect(m.optionA, contains('|'));
      expect(m.optionB, contains('|'));

      // Verify sorting
      final s = model.questions[3];
      expect(s.type, 'sorting');
      expect(s.correctOption, 'A');
      expect(s.optionA, 'Hz. İbrahim');
    });
  });

  group('RewardModel', () {
    test('fromJson parses snake_case keys correctly', () {
      final json = {
        'title': 'İlim Talebesi',
        'description':
            'Tebrikler! Mekke Dönemi kitabını başarıyla tamamladın.',
        'asset_image': 'assets/images/rewards/book_1_reward.webp',
        'unlock_book_id': 1,
      };

      final model = RewardModel.fromJson(json);

      expect(model.title, 'İlim Talebesi');
      expect(model.description,
          'Tebrikler! Mekke Dönemi kitabını başarıyla tamamladın.');
      expect(
          model.assetImage, 'assets/images/rewards/book_1_reward.webp');
      expect(model.unlockBookId, 1);
    });

    test('toJson produces snake_case keys', () {
      const model = RewardModel(
        title: 'Sabır Kahramanı',
        description: 'Muazzam! Medine Dönemi kitabını bitirdin.',
        assetImage: 'assets/images/rewards/book_2_reward.webp',
        unlockBookId: 2,
      );

      final json = model.toJson();

      expect(json['title'], 'Sabır Kahramanı');
      expect(json['description'],
          'Muazzam! Medine Dönemi kitabını bitirdin.');
      expect(json['asset_image'],
          'assets/images/rewards/book_2_reward.webp');
      expect(json['unlock_book_id'], 2);
    });

    test('round-trip fromJson/toJson preserves data', () {
      final original = {
        'title': 'Bedir Aslanı',
        'description':
            'Bedir Savaşı bölümünü bitirerek büyük bir zafer kazandın.',
        'asset_image': 'assets/images/rewards/book_3_reward.webp',
        'unlock_book_id': 3,
      };

      final model = RewardModel.fromJson(original);
      final result = model.toJson();

      expect(result, original);
    });

    test('copyWith creates modified copy', () {
      const model = RewardModel(
        title: 'Original',
        description: 'Desc',
        assetImage: 'assets/images/rewards/book_1_reward.webp',
        unlockBookId: 1,
      );

      final updated = model.copyWith(
        title: 'Updated',
        unlockBookId: 5,
      );

      expect(updated.title, 'Updated');
      expect(updated.description, 'Desc');
      expect(updated.assetImage,
          'assets/images/rewards/book_1_reward.webp');
      expect(updated.unlockBookId, 5);
    });

    test('equality based on all fields', () {
      const a = RewardModel(
        title: 'Test',
        description: 'Desc',
        assetImage: 'assets/img.webp',
        unlockBookId: 1,
      );
      const b = RewardModel(
        title: 'Test',
        description: 'Desc',
        assetImage: 'assets/img.webp',
        unlockBookId: 1,
      );
      const c = RewardModel(
        title: 'Different',
        description: 'Desc',
        assetImage: 'assets/img.webp',
        unlockBookId: 1,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('HadithModel', () {
    test('fromJson parses keys correctly', () {
      final json = {
        'text': 'İlim öğrenmek her Müslümana farzdır.',
        'source': 'İbn Mâce',
      };

      final model = HadithModel.fromJson(json);

      expect(model.text, 'İlim öğrenmek her Müslümana farzdır.');
      expect(model.source, 'İbn Mâce');
    });

    test('toJson produces correct keys', () {
      const model = HadithModel(
        text: 'Ameller niyetlere göredir.',
        source: "Buhari, Bed'ü'l-Vahy, 1",
      );

      final json = model.toJson();

      expect(json['text'], 'Ameller niyetlere göredir.');
      expect(json['source'], "Buhari, Bed'ü'l-Vahy, 1");
    });

    test('round-trip fromJson/toJson preserves data', () {
      final original = {
        'text': 'Güzel söz sadakadır.',
        'source': 'Buhari, Edeb, 34',
      };

      final model = HadithModel.fromJson(original);
      final result = model.toJson();

      expect(result, original);
    });

    test('copyWith creates modified copy', () {
      const model = HadithModel(
        text: 'Original text',
        source: 'Original source',
      );

      final updated = model.copyWith(text: 'Updated text');

      expect(updated.text, 'Updated text');
      expect(updated.source, 'Original source');
    });

    test('equality based on all fields', () {
      const a = HadithModel(
        text: 'Test text',
        source: 'Test source',
      );
      const b = HadithModel(
        text: 'Test text',
        source: 'Test source',
      );
      const c = HadithModel(
        text: 'Different text',
        source: 'Test source',
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('ContentState', () {
    test('empty factory creates state with empty collections', () {
      final state = ContentState.empty();

      expect(state.series, isEmpty);
      expect(state.books, isEmpty);
      expect(state.contentFiles, isEmpty);
      expect(state.rewards, isEmpty);
      expect(state.hadiths, isEmpty);
    });

    test('copyWith creates modified copy', () {
      final state = ContentState.empty();

      const series = [
        SeriesModel(
          id: 1,
          name: 'Siyer-i Nebi',
          sortOrder: 1,
          isLocked: false,
          iconEmoji: '🕌',
        ),
      ];
      const books = [
        BookModel(
          id: 1,
          title: 'Mekke Dönemi',
          description: 'Desc',
          assetImage: 'assets/images/book_1/book_1.png',
          bookOrder: 1,
          seriesId: 1,
          contentFile: 'book_1.json',
        ),
      ];
      const rewards = [
        RewardModel(
          title: 'İlim Talebesi',
          description: 'Tebrikler!',
          assetImage: 'assets/images/rewards/book_1_reward.webp',
          unlockBookId: 1,
        ),
      ];
      const hadiths = [
        HadithModel(
          text: 'Ameller niyetlere göredir.',
          source: "Buhari, Bed'ü'l-Vahy, 1",
        ),
      ];

      final updated = state.copyWith(
        series: series,
        books: books,
        rewards: rewards,
        hadiths: hadiths,
      );

      expect(updated.series, hasLength(1));
      expect(updated.series[0].name, 'Siyer-i Nebi');
      expect(updated.books, hasLength(1));
      expect(updated.books[0].title, 'Mekke Dönemi');
      expect(updated.contentFiles, isEmpty);
      expect(updated.rewards, hasLength(1));
      expect(updated.rewards[0].title, 'İlim Talebesi');
      expect(updated.hadiths, hasLength(1));
      expect(updated.hadiths[0].text, 'Ameller niyetlere göredir.');
    });

    test('copyWith can replace contentFiles', () {
      final state = ContentState.empty();

      const level = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Siyer-i Nebi',
        levelOrder: 1,
        title: 'Doğuş ve Çocukluk',
        unlockScore: 0,
        questions: [],
      );

      final updated = state.copyWith(
        contentFiles: {
          'book_1.json': [level],
        },
      );

      expect(updated.contentFiles, hasLength(1));
      expect(updated.contentFiles['book_1.json'], hasLength(1));
      expect(updated.contentFiles['book_1.json']![0].title,
          'Doğuş ve Çocukluk');
    });

    test('equality based on all fields', () {
      const series = [
        SeriesModel(
          id: 1,
          name: 'Test',
          sortOrder: 1,
          isLocked: false,
          iconEmoji: '📖',
        ),
      ];
      const hadiths = [
        HadithModel(text: 'Text', source: 'Source'),
      ];

      final a = ContentState(
        series: series,
        books: const [],
        contentFiles: const {},
        rewards: const [],
        hadiths: hadiths,
      );
      final b = ContentState(
        series: series,
        books: const [],
        contentFiles: const {},
        rewards: const [],
        hadiths: hadiths,
      );
      final c = ContentState.empty();

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('equality detects different contentFiles maps', () {
      const level = LevelModel(
        id: 1,
        bookId: 1,
        categoryName: 'Test',
        levelOrder: 1,
        title: 'Level 1',
        unlockScore: 0,
        questions: [],
      );

      final a = ContentState(
        series: const [],
        books: const [],
        contentFiles: const {
          'book_1.json': [level],
        },
        rewards: const [],
        hadiths: const [],
      );
      final b = ContentState(
        series: const [],
        books: const [],
        contentFiles: const {},
        rewards: const [],
        hadiths: const [],
      );

      expect(a, isNot(equals(b)));
    });
  });
}
