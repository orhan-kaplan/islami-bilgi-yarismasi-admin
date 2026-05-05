import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/json_parser.dart';

void main() {
  late JsonParser parser;

  setUp(() {
    parser = JsonParser();
  });

  group('parseSeries', () {
    test('parses valid series JSON array', () {
      const jsonString = '''
[
  {
    "id": 1,
    "name": "Siyer-i Nebi",
    "sort_order": 1,
    "is_locked": false,
    "icon_emoji": "🕌",
    "description": "Peygamber Efendimiz Hz. Muhammed (s.a.v)'in hayatı"
  },
  {
    "id": 2,
    "name": "Kısas-ı Enbiya",
    "sort_order": 2,
    "is_locked": false,
    "icon_emoji": "📖",
    "description": "Peygamberler tarihi ve kıssaları"
  }
]
''';

      final result = parser.parseSeries(jsonString);

      expect(result.length, 2);
      expect(result[0].id, 1);
      expect(result[0].name, 'Siyer-i Nebi');
      expect(result[0].sortOrder, 1);
      expect(result[0].isLocked, false);
      expect(result[0].iconEmoji, '🕌');
      expect(result[0].description,
          "Peygamber Efendimiz Hz. Muhammed (s.a.v)'in hayatı");
      expect(result[1].id, 2);
      expect(result[1].name, 'Kısas-ı Enbiya');
    });

    test('parses actual series data from main app', () {
      const jsonString = '''
[
  {
    "id": 1,
    "name": "Siyer-i Nebi",
    "sort_order": 1,
    "is_locked": false,
    "icon_emoji": "🕌",
    "description": "Peygamber Efendimiz Hz. Muhammed (s.a.v)'in hayatı"
  },
  {
    "id": 2,
    "name": "Kısas-ı Enbiya",
    "sort_order": 2,
    "is_locked": false,
    "icon_emoji": "📖",
    "description": "Peygamberler tarihi ve kıssaları"
  },
  {
    "id": 3,
    "name": "Hulefa-i Raşidin",
    "sort_order": 3,
    "is_locked": true,
    "icon_emoji": "👑",
    "description": "Dört büyük halife dönemi"
  },
  {
    "id": 4,
    "name": "İslami İlimler",
    "sort_order": 4,
    "is_locked": true,
    "icon_emoji": "🎓",
    "description": "Temel İslami bilgiler ve ilimler"
  }
]
''';

      final result = parser.parseSeries(jsonString);

      expect(result.length, 4);
      expect(result[2].name, 'Hulefa-i Raşidin');
      expect(result[2].isLocked, true);
      expect(result[3].iconEmoji, '🎓');
    });

    test('parses series with null description', () {
      const jsonString = '''
[
  {
    "id": 1,
    "name": "Test",
    "sort_order": 1,
    "is_locked": false,
    "icon_emoji": "📚"
  }
]
''';

      final result = parser.parseSeries(jsonString);

      expect(result.length, 1);
      expect(result[0].description, isNull);
    });

    test('parses empty series array', () {
      const jsonString = '[]';

      final result = parser.parseSeries(jsonString);

      expect(result, isEmpty);
    });

    test('throws FormatException on invalid JSON', () {
      const jsonString = '{invalid json}';

      expect(
        () => parser.parseSeries(jsonString),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when JSON is not an array', () {
      const jsonString = '{"id": 1}';

      expect(
        () => parser.parseSeries(jsonString),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('expected a JSON array'),
        )),
      );
    });
  });

  group('parseBooks', () {
    test('parses valid books JSON array', () {
      const jsonString = '''
[
  {
    "id": 1,
    "title": "Mekke Dönemi",
    "description": "İslam güneşinin doğuşu ve ilk mücadeleler.",
    "asset_image": "assets/images/book_1/book_1.png",
    "book_order": 1,
    "series_id": 1,
    "content_file": "book_1.json"
  },
  {
    "id": 2,
    "title": "Medine Dönemi",
    "description": "Hicret, devletleşme ve büyük savaşlar.",
    "asset_image": "assets/images/book_2/book_2.png",
    "book_order": 2,
    "series_id": 1,
    "content_file": "book_2.json"
  }
]
''';

      final result = parser.parseBooks(jsonString);

      expect(result.length, 2);
      expect(result[0].id, 1);
      expect(result[0].title, 'Mekke Dönemi');
      expect(result[0].description,
          'İslam güneşinin doğuşu ve ilk mücadeleler.');
      expect(result[0].assetImage, 'assets/images/book_1/book_1.png');
      expect(result[0].bookOrder, 1);
      expect(result[0].seriesId, 1);
      expect(result[0].contentFile, 'book_1.json');
      expect(result[1].title, 'Medine Dönemi');
    });

    test('parses actual books data from main app', () {
      const jsonString = '''
[
  {
    "id": 1,
    "title": "Mekke Dönemi",
    "description": "İslam güneşinin doğuşu ve ilk mücadeleler.",
    "asset_image": "assets/images/book_1/book_1.png",
    "book_order": 1,
    "series_id": 1,
    "content_file": "book_1.json"
  },
  {
    "id": 2,
    "title": "Medine Dönemi",
    "description": "Hicret, devletleşme ve büyük savaşlar.",
    "asset_image": "assets/images/book_2/book_2.png",
    "book_order": 2,
    "series_id": 1,
    "content_file": "book_2.json"
  },
  {
    "id": 3,
    "title": "Bedir Savaşı",
    "description": "İslam'ın ilk büyük zaferi ve dönüm noktası.",
    "asset_image": "assets/images/book_3/book_3.png",
    "book_order": 3,
    "series_id": 1,
    "content_file": "book_3.json"
  }
]
''';

      final result = parser.parseBooks(jsonString);

      expect(result.length, 3);
      expect(result[2].title, 'Bedir Savaşı');
      expect(result[2].contentFile, 'book_3.json');
    });

    test('throws FormatException on invalid JSON', () {
      const jsonString = 'not json at all';

      expect(
        () => parser.parseBooks(jsonString),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when JSON is not an array', () {
      const jsonString = '{"books": []}';

      expect(
        () => parser.parseBooks(jsonString),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('expected a JSON array'),
        )),
      );
    });
  });

  group('parseContentFile', () {
    test('parses valid content file with nested levels structure', () {
      const jsonString = '''
{
  "levels": [
    {
      "id": 1,
      "book_id": 1,
      "category_name": "Siyer-i Nebi",
      "level_order": 1,
      "title": "Doğuş ve Çocukluk",
      "unlock_score": 0,
      "asset_image": "assets/images/book_1/level_1.webp",
      "questions": [
        {
          "question_text": "Peygamberimiz (s.a.v) nerede doğmuştur?",
          "option_a": "Mekke",
          "option_b": "Medine",
          "option_c": "Taif",
          "option_d": "Şam",
          "correct_option": "A",
          "explanation": "Peygamberimiz (s.a.v) 571 yılında Mekke'de doğmuştur.",
          "type": "multiple_choice"
        }
      ]
    }
  ]
}
''';

      final result = parser.parseContentFile(jsonString);

      expect(result.length, 1);
      expect(result[0].id, 1);
      expect(result[0].bookId, 1);
      expect(result[0].categoryName, 'Siyer-i Nebi');
      expect(result[0].levelOrder, 1);
      expect(result[0].title, 'Doğuş ve Çocukluk');
      expect(result[0].unlockScore, 0);
      expect(result[0].assetImage, 'assets/images/book_1/level_1.webp');
      expect(result[0].questions.length, 1);
      expect(result[0].questions[0].questionText,
          'Peygamberimiz (s.a.v) nerede doğmuştur?');
      expect(result[0].questions[0].correctOption, 'A');
      expect(result[0].questions[0].type, 'multiple_choice');
    });

    test('parses content file with all question types', () {
      const jsonString = '''
{
  "levels": [
    {
      "id": 1,
      "book_id": 1,
      "category_name": "Siyer-i Nebi",
      "level_order": 1,
      "title": "Doğuş ve Çocukluk",
      "unlock_score": 0,
      "asset_image": "assets/images/book_1/level_1.webp",
      "questions": [
        {
          "question_text": "Peygamberimiz (s.a.v) nerede doğmuştur?",
          "option_a": "Mekke",
          "option_b": "Medine",
          "option_c": "Taif",
          "option_d": "Şam",
          "correct_option": "A",
          "explanation": "Peygamberimiz (s.a.v) 571 yılında Mekke'de doğmuştur.",
          "type": "multiple_choice"
        },
        {
          "question_text": "Peygamberimizin (s.a.v) süt annesinin adı Halime'dir.",
          "option_a": "Doğru",
          "option_b": "Yanlış",
          "option_c": "",
          "option_d": "",
          "correct_option": "A",
          "explanation": "Evet, Peygamberimizin süt annesi Halime'dir.",
          "type": "true_false"
        },
        {
          "question_text": "Aşağıdaki olayları ve yaşları eşleştiriniz.",
          "option_a": "Doğumu | 571",
          "option_b": "Annesinin Vefatı | 6 Yaş",
          "option_c": "Dedesinin Vefatı | 8 Yaş",
          "option_d": "Evliliği | 25 Yaş",
          "correct_option": "A",
          "explanation": "Doğumu 571, Annesinin vefatı 6 yaşında.",
          "type": "matching"
        },
        {
          "question_text": "Peygamberimizin soy ağacını sıralayınız.",
          "option_a": "Hz. İbrahim",
          "option_b": "Hz. İsmail",
          "option_c": "Adnan",
          "option_d": "Hz. Muhammed (s.a.v)",
          "correct_option": "A",
          "explanation": "Soyu Hz. İbrahim'e dayanır.",
          "type": "sorting"
        }
      ]
    }
  ]
}
''';

      final result = parser.parseContentFile(jsonString);

      expect(result[0].questions.length, 4);
      expect(result[0].questions[0].type, 'multiple_choice');
      expect(result[0].questions[1].type, 'true_false');
      expect(result[0].questions[1].optionA, 'Doğru');
      expect(result[0].questions[1].optionB, 'Yanlış');
      expect(result[0].questions[1].optionC, '');
      expect(result[0].questions[1].optionD, '');
      expect(result[0].questions[2].type, 'matching');
      expect(result[0].questions[2].optionA, contains('|'));
      expect(result[0].questions[3].type, 'sorting');
    });

    test('parses content file with level having null asset_image', () {
      const jsonString = '''
{
  "levels": [
    {
      "id": 1,
      "book_id": 1,
      "category_name": "Test",
      "level_order": 1,
      "title": "Test Level",
      "unlock_score": 0,
      "asset_image": null,
      "questions": []
    }
  ]
}
''';

      final result = parser.parseContentFile(jsonString);

      expect(result[0].assetImage, isNull);
    });

    test('parses content file with empty levels array', () {
      const jsonString = '{"levels": []}';

      final result = parser.parseContentFile(jsonString);

      expect(result, isEmpty);
    });

    test('throws FormatException on invalid JSON', () {
      const jsonString = '{levels: invalid}';

      expect(
        () => parser.parseContentFile(jsonString),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when JSON is a plain array', () {
      const jsonString = '[{"id": 1}]';

      expect(
        () => parser.parseContentFile(jsonString),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('expected a JSON object'),
        )),
      );
    });

    test('throws FormatException when levels key is missing', () {
      const jsonString = '{"data": []}';

      expect(
        () => parser.parseContentFile(jsonString),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('missing or invalid "levels" key'),
        )),
      );
    });
  });

  group('parseRewards', () {
    test('parses valid rewards JSON array', () {
      const jsonString = '''
[
  {
    "title": "İlim Talebesi",
    "description": "Tebrikler! Mekke Dönemi kitabını başarıyla tamamladın.",
    "asset_image": "assets/images/rewards/book_1_reward.webp",
    "unlock_book_id": 1
  },
  {
    "title": "Sabır Kahramanı",
    "description": "Muazzam! Medine Dönemi kitabını bitirdin.",
    "asset_image": "assets/images/rewards/book_2_reward.webp",
    "unlock_book_id": 2
  }
]
''';

      final result = parser.parseRewards(jsonString);

      expect(result.length, 2);
      expect(result[0].title, 'İlim Talebesi');
      expect(result[0].description,
          'Tebrikler! Mekke Dönemi kitabını başarıyla tamamladın.');
      expect(
          result[0].assetImage, 'assets/images/rewards/book_1_reward.webp');
      expect(result[0].unlockBookId, 1);
      expect(result[1].title, 'Sabır Kahramanı');
    });

    test('parses actual rewards data from main app', () {
      const jsonString = '''
[
  {
    "title": "İlim Talebesi",
    "description": "Tebrikler! Mekke Dönemi kitabını başarıyla tamamladın.",
    "asset_image": "assets/images/rewards/book_1_reward.webp",
    "unlock_book_id": 1
  },
  {
    "title": "Sabır Kahramanı",
    "description": "Muazzam! Medine Dönemi kitabını bitirdin.",
    "asset_image": "assets/images/rewards/book_2_reward.webp",
    "unlock_book_id": 2
  },
  {
    "title": "Bedir Aslanı",
    "description": "Bedir Savaşı bölümünü bitirerek büyük bir zafer kazandın.",
    "asset_image": "assets/images/rewards/book_3_reward.webp",
    "unlock_book_id": 3
  }
]
''';

      final result = parser.parseRewards(jsonString);

      expect(result.length, 3);
      expect(result[2].title, 'Bedir Aslanı');
      expect(result[2].unlockBookId, 3);
    });

    test('throws FormatException on invalid JSON', () {
      expect(
        () => parser.parseRewards('{{bad}}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when JSON is not an array', () {
      const jsonString = '{"rewards": []}';

      expect(
        () => parser.parseRewards(jsonString),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('expected a JSON array'),
        )),
      );
    });
  });

  group('parseHadiths', () {
    test('parses valid hadiths JSON array', () {
      const jsonString = '''
[
  {
    "text": "Kolaylaştırınız, zorlaştırmayınız; müjdeleyiniz, nefret ettirmeyiniz.",
    "source": "Buhari, İlim, 11"
  },
  {
    "text": "Ameller niyetlere göredir.",
    "source": "Buhari, Bed'ü'l-Vahy, 1"
  }
]
''';

      final result = parser.parseHadiths(jsonString);

      expect(result.length, 2);
      expect(result[0].text,
          'Kolaylaştırınız, zorlaştırmayınız; müjdeleyiniz, nefret ettirmeyiniz.');
      expect(result[0].source, 'Buhari, İlim, 11');
      expect(result[1].text, 'Ameller niyetlere göredir.');
    });

    test('parses actual hadiths data from main app', () {
      const jsonString = '''
[
  {
    "text": "Kolaylaştırınız, zorlaştırmayınız; müjdeleyiniz, nefret ettirmeyiniz.",
    "source": "Buhari, İlim, 11"
  },
  {
    "text": "Ameller niyetlere göredir.",
    "source": "Buhari, Bed'ü'l-Vahy, 1"
  },
  {
    "text": "Sizin en hayırlınız, Kur'an'ı öğrenen ve öğretendir.",
    "source": "Buhari, Fezailü'l-Kur'an, 21"
  },
  {
    "text": "Temizlik imanın yarısıdır.",
    "source": "Müslim, Taharet, 1"
  },
  {
    "text": "Güzel söz sadakadır.",
    "source": "Buhari, Edeb, 34"
  },
  {
    "text": "İki günü eşit olan ziyandadır.",
    "source": "Hadis-i Şerif"
  },
  {
    "text": "Müslüman, elinden ve dilinden diğer Müslümanların emin olduğu kimsedir.",
    "source": "Buhari, İman, 4"
  },
  {
    "text": "İlim Çin'de de olsa gidip alınız.",
    "source": "Beyhaki, Şuabü'l-Iman"
  },
  {
    "text": "Komşusu açken tok yatan bizden değildir.",
    "source": "İbn Ebi Şeybe, Musannef"
  }
]
''';

      final result = parser.parseHadiths(jsonString);

      expect(result.length, 9);
      expect(result[7].text, 'İlim Çin\'de de olsa gidip alınız.');
      expect(result[7].source, 'Beyhaki, Şuabü\'l-Iman');
    });

    test('parses empty hadiths array', () {
      const jsonString = '[]';

      final result = parser.parseHadiths(jsonString);

      expect(result, isEmpty);
    });

    test('throws FormatException on invalid JSON', () {
      expect(
        () => parser.parseHadiths('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when JSON is not an array', () {
      const jsonString = '{"hadiths": []}';

      expect(
        () => parser.parseHadiths(jsonString),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('expected a JSON array'),
        )),
      );
    });
  });

  group('FormatException messages', () {
    test('series parse error includes descriptive message', () {
      try {
        parser.parseSeries('{bad json');
        fail('Expected FormatException');
      } on FormatException catch (e) {
        expect(e.message, contains('series'));
      }
    });

    test('books parse error includes descriptive message', () {
      try {
        parser.parseBooks('{bad json');
        fail('Expected FormatException');
      } on FormatException catch (e) {
        expect(e.message, contains('books'));
      }
    });

    test('content file parse error includes descriptive message', () {
      try {
        parser.parseContentFile('{bad json');
        fail('Expected FormatException');
      } on FormatException catch (e) {
        expect(e.message, contains('content file'));
      }
    });

    test('rewards parse error includes descriptive message', () {
      try {
        parser.parseRewards('{bad json');
        fail('Expected FormatException');
      } on FormatException catch (e) {
        expect(e.message, contains('rewards'));
      }
    });

    test('hadiths parse error includes descriptive message', () {
      try {
        parser.parseHadiths('{bad json');
        fail('Expected FormatException');
      } on FormatException catch (e) {
        expect(e.message, contains('hadiths'));
      }
    });
  });

  group('round-trip with toJson', () {
    test('series round-trip preserves data', () {
      const jsonString = '''
[
  {
    "id": 1,
    "name": "Siyer-i Nebi",
    "sort_order": 1,
    "is_locked": false,
    "icon_emoji": "🕌",
    "description": "Peygamber Efendimiz Hz. Muhammed (s.a.v)'in hayatı"
  }
]
''';

      final parsed = parser.parseSeries(jsonString);
      final reEncoded = json.encode(parsed.map((s) => s.toJson()).toList());
      final reParsed = parser.parseSeries(reEncoded);

      expect(reParsed[0], parsed[0]);
    });

    test('content file round-trip preserves nested structure', () {
      const jsonString = '''
{
  "levels": [
    {
      "id": 1,
      "book_id": 1,
      "category_name": "Siyer-i Nebi",
      "level_order": 1,
      "title": "Doğuş ve Çocukluk",
      "unlock_score": 0,
      "asset_image": "assets/images/book_1/level_1.webp",
      "questions": [
        {
          "question_text": "Peygamberimiz (s.a.v) nerede doğmuştur?",
          "option_a": "Mekke",
          "option_b": "Medine",
          "option_c": "Taif",
          "option_d": "Şam",
          "correct_option": "A",
          "explanation": "571 yılında Mekke'de doğmuştur.",
          "type": "multiple_choice"
        }
      ]
    }
  ]
}
''';

      final parsed = parser.parseContentFile(jsonString);
      final reEncoded = json.encode({
        'levels': parsed.map((l) => l.toJson()).toList(),
      });
      final reParsed = parser.parseContentFile(reEncoded);

      expect(reParsed.length, parsed.length);
      expect(reParsed[0].id, parsed[0].id);
      expect(reParsed[0].questions.length, parsed[0].questions.length);
      expect(reParsed[0].questions[0], parsed[0].questions[0]);
    });
  });
}
