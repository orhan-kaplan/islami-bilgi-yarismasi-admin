import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/json_parser.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/json_serializer.dart';

void main() {
  late JsonSerializer serializer;
  late JsonParser parser;

  setUp(() {
    serializer = JsonSerializer();
    parser = JsonParser();
  });

  group('serializeSeries', () {
    test('serializes a list of series to JSON array string', () {
      final series = [
        const SeriesModel(
          id: 1,
          name: 'Siyer-i Nebi',
          sortOrder: 1,
          isLocked: false,
          iconEmoji: '🕌',
          description:
              "Peygamber Efendimiz Hz. Muhammed (s.a.v)'in hayatı",
        ),
        const SeriesModel(
          id: 2,
          name: 'Kısas-ı Enbiya',
          sortOrder: 2,
          isLocked: true,
          iconEmoji: '📖',
        ),
      ];

      final result = serializer.serializeSeries(series);
      final decoded = json.decode(result) as List;

      expect(decoded.length, 2);
      expect(decoded[0]['id'], 1);
      expect(decoded[0]['name'], 'Siyer-i Nebi');
      expect(decoded[0]['sort_order'], 1);
      expect(decoded[0]['is_locked'], false);
      expect(decoded[0]['icon_emoji'], '🕌');
      expect(decoded[1]['id'], 2);
      expect(decoded[1]['is_locked'], true);
      expect(decoded[1]['description'], isNull);
    });

    test('serializes empty series list', () {
      final result = serializer.serializeSeries([]);
      expect(result, '[]');
    });
  });

  group('serializeBooks', () {
    test('serializes a list of books to JSON array string', () {
      final books = [
        const BookModel(
          id: 1,
          title: 'Mekke Dönemi',
          description: 'İslam güneşinin doğuşu ve ilk mücadeleler.',
          assetImage: 'assets/images/book_1/book_1.png',
          bookOrder: 1,
          seriesId: 1,
          contentFile: 'book_1.json',
        ),
      ];

      final result = serializer.serializeBooks(books);
      final decoded = json.decode(result) as List;

      expect(decoded.length, 1);
      expect(decoded[0]['id'], 1);
      expect(decoded[0]['title'], 'Mekke Dönemi');
      expect(decoded[0]['asset_image'], 'assets/images/book_1/book_1.png');
      expect(decoded[0]['book_order'], 1);
      expect(decoded[0]['series_id'], 1);
      expect(decoded[0]['content_file'], 'book_1.json');
    });

    test('serializes empty books list', () {
      final result = serializer.serializeBooks([]);
      expect(result, '[]');
    });
  });

  group('serializeContentFile', () {
    test('produces {"levels": [...]} structure', () {
      final levels = [
        const LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'Siyer-i Nebi',
          levelOrder: 1,
          title: 'Doğuş ve Çocukluk',
          unlockScore: 0,
          assetImage: 'assets/images/book_1/level_1.webp',
          questions: [
            QuestionModel(
              questionText: 'Peygamberimiz (s.a.v) nerede doğmuştur?',
              optionA: 'Mekke',
              optionB: 'Medine',
              optionC: 'Taif',
              optionD: 'Şam',
              correctOption: 'A',
              explanation: '571 yılında Mekke\'de doğmuştur.',
              type: 'multiple_choice',
            ),
          ],
        ),
      ];

      final result = serializer.serializeContentFile(levels);
      final decoded = json.decode(result) as Map<String, dynamic>;

      expect(decoded.containsKey('levels'), isTrue);
      expect(decoded['levels'], isList);
      expect((decoded['levels'] as List).length, 1);
      expect(decoded['levels'][0]['id'], 1);
      expect(decoded['levels'][0]['book_id'], 1);
      expect(decoded['levels'][0]['questions'], isList);
      expect(decoded['levels'][0]['questions'][0]['question_text'],
          'Peygamberimiz (s.a.v) nerede doğmuştur?');
    });

    test('serializes empty levels list with levels wrapper', () {
      final result = serializer.serializeContentFile([]);
      final decoded = json.decode(result) as Map<String, dynamic>;

      expect(decoded.containsKey('levels'), isTrue);
      expect(decoded['levels'], isEmpty);
    });

    test('serializes levels with null asset_image', () {
      final levels = [
        const LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'Test',
          levelOrder: 1,
          title: 'Test Level',
          unlockScore: 0,
          questions: [],
        ),
      ];

      final result = serializer.serializeContentFile(levels);
      final decoded = json.decode(result) as Map<String, dynamic>;

      expect(decoded['levels'][0]['asset_image'], isNull);
    });
  });

  group('serializeRewards', () {
    test('serializes a list of rewards to JSON array string', () {
      final rewards = [
        const RewardModel(
          title: 'İlim Talebesi',
          description:
              'Tebrikler! Mekke Dönemi kitabını başarıyla tamamladın.',
          assetImage: 'assets/images/rewards/book_1_reward.webp',
          unlockBookId: 1,
        ),
      ];

      final result = serializer.serializeRewards(rewards);
      final decoded = json.decode(result) as List;

      expect(decoded.length, 1);
      expect(decoded[0]['title'], 'İlim Talebesi');
      expect(decoded[0]['asset_image'],
          'assets/images/rewards/book_1_reward.webp');
      expect(decoded[0]['unlock_book_id'], 1);
    });

    test('serializes empty rewards list', () {
      final result = serializer.serializeRewards([]);
      expect(result, '[]');
    });
  });

  group('serializeHadiths', () {
    test('serializes a list of hadiths to JSON array string', () {
      final hadiths = [
        const HadithModel(
          text:
              'Kolaylaştırınız, zorlaştırmayınız; müjdeleyiniz, nefret ettirmeyiniz.',
          source: 'Buhari, İlim, 11',
        ),
        const HadithModel(
          text: 'Ameller niyetlere göredir.',
          source: "Buhari, Bed'ü'l-Vahy, 1",
        ),
      ];

      final result = serializer.serializeHadiths(hadiths);
      final decoded = json.decode(result) as List;

      expect(decoded.length, 2);
      expect(decoded[0]['text'], contains('Kolaylaştırınız'));
      expect(decoded[0]['source'], 'Buhari, İlim, 11');
      expect(decoded[1]['source'], "Buhari, Bed'ü'l-Vahy, 1");
    });

    test('serializes empty hadiths list', () {
      final result = serializer.serializeHadiths([]);
      expect(result, '[]');
    });
  });

  group('pretty-printing with 2-space indent', () {
    test('series output is pretty-printed with 2-space indent', () {
      final series = [
        const SeriesModel(
          id: 1,
          name: 'Test',
          sortOrder: 1,
          isLocked: false,
          iconEmoji: '📚',
        ),
      ];

      final result = serializer.serializeSeries(series);

      // Verify 2-space indentation is present
      expect(result, contains('  '));
      expect(result, contains('\n'));
      // Verify it starts with array bracket and has indented content
      expect(result.trimLeft(), startsWith('['));
      expect(result, contains('  {\n'));
    });

    test('books output is pretty-printed with 2-space indent', () {
      final books = [
        const BookModel(
          id: 1,
          title: 'Test',
          description: 'Desc',
          assetImage: 'assets/test.png',
          bookOrder: 1,
          seriesId: 1,
          contentFile: 'book_1.json',
        ),
      ];

      final result = serializer.serializeBooks(books);

      expect(result, contains('  '));
      expect(result, contains('\n'));
    });

    test('content file output is pretty-printed with 2-space indent', () {
      final levels = [
        const LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'Test',
          levelOrder: 1,
          title: 'Test',
          unlockScore: 0,
          questions: [],
        ),
      ];

      final result = serializer.serializeContentFile(levels);

      expect(result, contains('  "levels"'));
      expect(result, contains('\n'));
    });

    test('rewards output is pretty-printed with 2-space indent', () {
      final rewards = [
        const RewardModel(
          title: 'Test',
          description: 'Desc',
          assetImage: 'assets/test.webp',
          unlockBookId: 1,
        ),
      ];

      final result = serializer.serializeRewards(rewards);

      expect(result, contains('  '));
      expect(result, contains('\n'));
    });

    test('hadiths output is pretty-printed with 2-space indent', () {
      final hadiths = [
        const HadithModel(text: 'Test', source: 'Source'),
      ];

      final result = serializer.serializeHadiths(hadiths);

      expect(result, contains('  '));
      expect(result, contains('\n'));
    });
  });

  group('snake_case keys', () {
    test('series output uses snake_case keys', () {
      final series = [
        const SeriesModel(
          id: 1,
          name: 'Test',
          sortOrder: 1,
          isLocked: false,
          iconEmoji: '📚',
          description: 'A description',
        ),
      ];

      final result = serializer.serializeSeries(series);

      expect(result, contains('"sort_order"'));
      expect(result, contains('"is_locked"'));
      expect(result, contains('"icon_emoji"'));
      expect(result, isNot(contains('"sortOrder"')));
      expect(result, isNot(contains('"isLocked"')));
      expect(result, isNot(contains('"iconEmoji"')));
    });

    test('books output uses snake_case keys', () {
      final books = [
        const BookModel(
          id: 1,
          title: 'Test',
          description: 'Desc',
          assetImage: 'assets/test.png',
          bookOrder: 1,
          seriesId: 1,
          contentFile: 'book_1.json',
        ),
      ];

      final result = serializer.serializeBooks(books);

      expect(result, contains('"asset_image"'));
      expect(result, contains('"book_order"'));
      expect(result, contains('"series_id"'));
      expect(result, contains('"content_file"'));
      expect(result, isNot(contains('"assetImage"')));
      expect(result, isNot(contains('"bookOrder"')));
      expect(result, isNot(contains('"seriesId"')));
      expect(result, isNot(contains('"contentFile"')));
    });

    test('content file output uses snake_case keys', () {
      final levels = [
        const LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'Test',
          levelOrder: 1,
          title: 'Test',
          unlockScore: 0,
          assetImage: 'assets/test.webp',
          questions: [
            QuestionModel(
              questionText: 'Question?',
              optionA: 'A',
              optionB: 'B',
              optionC: 'C',
              optionD: 'D',
              correctOption: 'A',
              explanation: 'Explanation',
              type: 'multiple_choice',
            ),
          ],
        ),
      ];

      final result = serializer.serializeContentFile(levels);

      expect(result, contains('"book_id"'));
      expect(result, contains('"category_name"'));
      expect(result, contains('"level_order"'));
      expect(result, contains('"unlock_score"'));
      expect(result, contains('"asset_image"'));
      expect(result, contains('"question_text"'));
      expect(result, contains('"option_a"'));
      expect(result, contains('"option_b"'));
      expect(result, contains('"option_c"'));
      expect(result, contains('"option_d"'));
      expect(result, contains('"correct_option"'));
      expect(result, isNot(contains('"bookId"')));
      expect(result, isNot(contains('"categoryName"')));
      expect(result, isNot(contains('"levelOrder"')));
      expect(result, isNot(contains('"questionText"')));
      expect(result, isNot(contains('"correctOption"')));
    });

    test('rewards output uses snake_case keys', () {
      final rewards = [
        const RewardModel(
          title: 'Test',
          description: 'Desc',
          assetImage: 'assets/test.webp',
          unlockBookId: 1,
        ),
      ];

      final result = serializer.serializeRewards(rewards);

      expect(result, contains('"asset_image"'));
      expect(result, contains('"unlock_book_id"'));
      expect(result, isNot(contains('"assetImage"')));
      expect(result, isNot(contains('"unlockBookId"')));
    });
  });

  group('round-trip with JsonParser', () {
    test('series round-trip: serialize → parse → compare', () {
      final original = [
        const SeriesModel(
          id: 1,
          name: 'Siyer-i Nebi',
          sortOrder: 1,
          isLocked: false,
          iconEmoji: '🕌',
          description:
              "Peygamber Efendimiz Hz. Muhammed (s.a.v)'in hayatı",
        ),
        const SeriesModel(
          id: 2,
          name: 'Kısas-ı Enbiya',
          sortOrder: 2,
          isLocked: true,
          iconEmoji: '📖',
        ),
      ];

      final serialized = serializer.serializeSeries(original);
      final parsed = parser.parseSeries(serialized);

      expect(parsed.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(parsed[i], original[i]);
      }
    });

    test('books round-trip: serialize → parse → compare', () {
      final original = [
        const BookModel(
          id: 1,
          title: 'Mekke Dönemi',
          description: 'İslam güneşinin doğuşu.',
          assetImage: 'assets/images/book_1/book_1.png',
          bookOrder: 1,
          seriesId: 1,
          contentFile: 'book_1.json',
        ),
        const BookModel(
          id: 2,
          title: 'Medine Dönemi',
          description: 'Hicret ve devletleşme.',
          assetImage: 'assets/images/book_2/book_2.png',
          bookOrder: 2,
          seriesId: 1,
          contentFile: 'book_2.json',
        ),
      ];

      final serialized = serializer.serializeBooks(original);
      final parsed = parser.parseBooks(serialized);

      expect(parsed.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(parsed[i], original[i]);
      }
    });

    test('content file round-trip: serialize → parse → compare', () {
      final original = [
        const LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'Siyer-i Nebi',
          levelOrder: 1,
          title: 'Doğuş ve Çocukluk',
          unlockScore: 0,
          assetImage: 'assets/images/book_1/level_1.webp',
          questions: [
            QuestionModel(
              questionText: 'Peygamberimiz (s.a.v) nerede doğmuştur?',
              optionA: 'Mekke',
              optionB: 'Medine',
              optionC: 'Taif',
              optionD: 'Şam',
              correctOption: 'A',
              explanation: '571 yılında Mekke\'de doğmuştur.',
              type: 'multiple_choice',
            ),
            QuestionModel(
              questionText: 'Süt annesinin adı Halime\'dir.',
              optionA: 'Doğru',
              optionB: 'Yanlış',
              optionC: '',
              optionD: '',
              correctOption: 'A',
              explanation: 'Evet, süt annesi Halime\'dir.',
              type: 'true_false',
            ),
          ],
        ),
      ];

      final serialized = serializer.serializeContentFile(original);
      final parsed = parser.parseContentFile(serialized);

      expect(parsed.length, original.length);
      expect(parsed[0], original[0]);
      expect(parsed[0].questions.length, original[0].questions.length);
      for (var i = 0; i < original[0].questions.length; i++) {
        expect(parsed[0].questions[i], original[0].questions[i]);
      }
    });

    test('rewards round-trip: serialize → parse → compare', () {
      final original = [
        const RewardModel(
          title: 'İlim Talebesi',
          description:
              'Tebrikler! Mekke Dönemi kitabını başarıyla tamamladın.',
          assetImage: 'assets/images/rewards/book_1_reward.webp',
          unlockBookId: 1,
        ),
        const RewardModel(
          title: 'Sabır Kahramanı',
          description: 'Muazzam! Medine Dönemi kitabını bitirdin.',
          assetImage: 'assets/images/rewards/book_2_reward.webp',
          unlockBookId: 2,
        ),
      ];

      final serialized = serializer.serializeRewards(original);
      final parsed = parser.parseRewards(serialized);

      expect(parsed.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(parsed[i], original[i]);
      }
    });

    test('hadiths round-trip: serialize → parse → compare', () {
      final original = [
        const HadithModel(
          text:
              'Kolaylaştırınız, zorlaştırmayınız; müjdeleyiniz, nefret ettirmeyiniz.',
          source: 'Buhari, İlim, 11',
        ),
        const HadithModel(
          text: 'Ameller niyetlere göredir.',
          source: "Buhari, Bed'ü'l-Vahy, 1",
        ),
      ];

      final serialized = serializer.serializeHadiths(original);
      final parsed = parser.parseHadiths(serialized);

      expect(parsed.length, original.length);
      for (var i = 0; i < original.length; i++) {
        expect(parsed[i], original[i]);
      }
    });
  });

  group('Turkish characters and emoji preservation', () {
    test('series preserves Turkish characters and emoji', () {
      final series = [
        const SeriesModel(
          id: 1,
          name: 'Türkçe Özel Karakterler: ğüşıöçĞÜŞİÖÇ',
          sortOrder: 1,
          isLocked: false,
          iconEmoji: '🕌🌙⭐',
          description: 'Açıklama: Şükür, güzel günler için çalışmak 🤲',
        ),
      ];

      final serialized = serializer.serializeSeries(series);
      final parsed = parser.parseSeries(serialized);

      expect(parsed[0].name, 'Türkçe Özel Karakterler: ğüşıöçĞÜŞİÖÇ');
      expect(parsed[0].iconEmoji, '🕌🌙⭐');
      expect(parsed[0].description,
          'Açıklama: Şükür, güzel günler için çalışmak 🤲');
    });

    test('content file preserves Turkish characters in questions', () {
      final levels = [
        const LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'İslâm Tarihi',
          levelOrder: 1,
          title: 'Peygamberimizin Çocukluğu',
          unlockScore: 0,
          questions: [
            QuestionModel(
              questionText:
                  'Peygamberimizin (s.a.v) süt annesinin adı nedir? 🤔',
              optionA: 'Halîme',
              optionB: 'Âmine',
              optionC: 'Hatîce',
              optionD: 'Fâtıma',
              correctOption: 'A',
              explanation: 'Süt annesi Halîme\'dir. 🕌',
              type: 'multiple_choice',
            ),
          ],
        ),
      ];

      final serialized = serializer.serializeContentFile(levels);
      final parsed = parser.parseContentFile(serialized);

      expect(parsed[0].categoryName, 'İslâm Tarihi');
      expect(parsed[0].title, 'Peygamberimizin Çocukluğu');
      expect(parsed[0].questions[0].questionText,
          contains('süt annesinin adı nedir? 🤔'));
      expect(parsed[0].questions[0].explanation, contains('🕌'));
    });

    test('hadiths preserve Turkish characters', () {
      final hadiths = [
        const HadithModel(
          text: 'İlim Çin\'de de olsa gidip alınız. 📖',
          source: 'Beyhakî, Şuabü\'l-Îmân',
        ),
      ];

      final serialized = serializer.serializeHadiths(hadiths);
      final parsed = parser.parseHadiths(serialized);

      expect(parsed[0].text, 'İlim Çin\'de de olsa gidip alınız. 📖');
      expect(parsed[0].source, 'Beyhakî, Şuabü\'l-Îmân');
    });
  });

  group('serializeContentFile structure', () {
    test('output is a JSON object, not an array', () {
      final result = serializer.serializeContentFile([]);
      final decoded = json.decode(result);

      expect(decoded, isA<Map<String, dynamic>>());
      expect(decoded, isNot(isA<List>()));
    });

    test('output has exactly one top-level key: "levels"', () {
      final levels = [
        const LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'Test',
          levelOrder: 1,
          title: 'Test',
          unlockScore: 0,
          questions: [],
        ),
      ];

      final result = serializer.serializeContentFile(levels);
      final decoded = json.decode(result) as Map<String, dynamic>;

      expect(decoded.keys.toList(), ['levels']);
    });

    test('nested questions are serialized within levels', () {
      final levels = [
        const LevelModel(
          id: 1,
          bookId: 1,
          categoryName: 'Cat',
          levelOrder: 1,
          title: 'Level 1',
          unlockScore: 0,
          questions: [
            QuestionModel(
              questionText: 'Q1',
              optionA: 'A',
              optionB: 'B',
              optionC: 'C',
              optionD: 'D',
              correctOption: 'A',
            ),
            QuestionModel(
              questionText: 'Q2',
              optionA: 'X',
              optionB: 'Y',
              optionC: 'Z',
              optionD: 'W',
              correctOption: 'B',
              explanation: 'Because Y',
              type: 'multiple_choice',
            ),
          ],
        ),
      ];

      final result = serializer.serializeContentFile(levels);
      final decoded = json.decode(result) as Map<String, dynamic>;
      final questions = decoded['levels'][0]['questions'] as List;

      expect(questions.length, 2);
      expect(questions[0]['question_text'], 'Q1');
      expect(questions[1]['question_text'], 'Q2');
      expect(questions[1]['explanation'], 'Because Y');
    });
  });
}
