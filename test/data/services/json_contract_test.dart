import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/reward_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/json_serializer.dart';

/// Serializer çıktısının anahtar sözleşmesini bağlayan testler.
///
/// Bu araç, mobil uygulamanın `assets/data/` içeriğini yazar; uygulamanın
/// `DatabaseSeeder`'ı da o anahtarları okur. İki repo arasında paylaşılan bir
/// şema paketi yok, dolayısıyla buradaki bir yeniden adlandırma uygulamada
/// sessiz veri kaybına yol açar.
///
/// Aşağıdaki anahtar kümeleri, mobil taraftaki
/// `test/data/local/content_contract_test.dart` ile birebir aynı olmalıdır.
/// Biri değişirse diğeri de değişmek zorunda — bu testler o eşleşmeyi zorlar.
void main() {
  final serializer = JsonSerializer();

  /// Serialize edilmiş JSON'un ilk kaydını çözer.
  Map<String, dynamic> firstRecord(String json) =>
      (jsonDecode(json) as List).first as Map<String, dynamic>;

  group('series.json sözleşmesi', () {
    test('seeder tarafından okunan anahtarları üretir', () {
      const model = SeriesModel(
        id: 1,
        name: 'Siyer',
        sortOrder: 1,
        isLocked: false,
        iconEmoji: '📖',
        description: 'Açıklama',
      );

      final record = firstRecord(serializer.serializeSeries([model]));

      expect(
        record.keys.toSet(),
        containsAll({'id', 'name', 'sort_order', 'is_locked', 'icon_emoji'}),
      );
      // Tip sözleşmesi: seeder bunları doğrudan Drift sütunlarına yazar.
      expect(record['id'], isA<int>());
      expect(record['is_locked'], isA<bool>());
      expect(record['sort_order'], isA<int>());
    });
  });

  group('books.json sözleşmesi', () {
    test('seeder tarafından okunan anahtarları üretir', () {
      const model = BookModel(
        id: 1,
        title: 'Mekke Dönemi',
        description: 'Açıklama',
        assetImage: 'assets/images/book_1.png',
        bookOrder: 1,
        seriesId: 1,
        contentFile: 'book_1.json',
      );

      final record = firstRecord(serializer.serializeBooks([model]));

      expect(
        record.keys.toSet(),
        containsAll({
          'id',
          'title',
          'description',
          'asset_image',
          'book_order',
          'series_id',
          'content_file',
        }),
      );
    });
  });

  group('content/*.json sözleşmesi', () {
    const question = QuestionModel(
      questionText: 'Soru?',
      optionA: 'A',
      optionB: 'B',
      optionC: 'C',
      optionD: 'D',
      correctOption: 'A',
      type: 'multiple_choice',
      explanation: 'Çünkü A',
    );

    const level = LevelModel(
      id: 1,
      bookId: 1,
      categoryName: 'Mekke',
      levelOrder: 1,
      title: 'Bölüm 1',
      unlockScore: 0,
      assetImage: 'assets/images/level.webp',
      questions: [question],
    );

    test('kök nesne "levels" anahtarı taşır', () {
      final decoded = jsonDecode(serializer.serializeContentFile([level]))
          as Map<String, dynamic>;

      expect(decoded.keys, contains('levels'));
      expect(decoded['levels'], isA<List>());
    });

    test('level anahtarları seeder ile örtüşür', () {
      final decoded = jsonDecode(serializer.serializeContentFile([level]))
          as Map<String, dynamic>;
      final record = (decoded['levels'] as List).first as Map<String, dynamic>;

      expect(
        record.keys.toSet(),
        containsAll({
          'id',
          'book_id',
          'category_name',
          'level_order',
          'title',
          'unlock_score',
          'asset_image',
          'questions',
        }),
      );
    });

    test('soru anahtarları seeder ile örtüşür', () {
      final decoded = jsonDecode(serializer.serializeContentFile([level]))
          as Map<String, dynamic>;
      final levelRecord =
          (decoded['levels'] as List).first as Map<String, dynamic>;
      final record =
          (levelRecord['questions'] as List).first as Map<String, dynamic>;

      expect(
        record.keys.toSet(),
        containsAll({
          'question_text',
          'option_a',
          'option_b',
          'option_c',
          'option_d',
          'correct_option',
        }),
      );
    });

    test('true_false sorularında option_c ve option_d boş string kalır', () {
      const trueFalse = QuestionModel(
        questionText: 'Doğru mu?',
        optionA: 'Doğru',
        optionB: 'Yanlış',
        optionC: '',
        optionD: '',
        correctOption: 'A',
        type: 'true_false',
        explanation: '',
      );

      final decoded = jsonDecode(
        serializer.serializeContentFile([
          const LevelModel(
            id: 1,
            bookId: 1,
            categoryName: 'Mekke',
            levelOrder: 1,
            title: 'Bölüm 1',
            unlockScore: 0,
            assetImage: 'x.webp',
            questions: [trueFalse],
          ),
        ]),
      ) as Map<String, dynamic>;

      final levelRecord =
          (decoded['levels'] as List).first as Map<String, dynamic>;
      final record =
          (levelRecord['questions'] as List).first as Map<String, dynamic>;

      // Seeder null değil boş string bekliyor — null'a dönerse şık render'ı bozulur.
      expect(record['option_c'], '');
      expect(record['option_d'], '');
      expect(record['option_c'], isNot(isNull));
    });
  });

  group('rewards.json sözleşmesi', () {
    test('seeder tarafından okunan anahtarları üretir', () {
      const model = RewardModel(
        title: 'Mekke Rozeti',
        description: 'Açıklama',
        assetImage: 'assets/images/rewards/badge.png',
        unlockBookId: 1,
      );

      final record = firstRecord(serializer.serializeRewards([model]));

      expect(
        record.keys.toSet(),
        containsAll({
          'title',
          'description',
          'asset_image',
          'unlock_book_id',
        }),
      );
      expect(record['unlock_book_id'], isA<int>());
    });
  });

  group('hadiths.json sözleşmesi', () {
    test('metin ve kaynak anahtarlarını üretir', () {
      const model = HadithModel(text: 'Hadis metni', source: 'Buhari');

      final record = firstRecord(serializer.serializeHadiths([model]));

      expect(record.keys.toSet(), containsAll({'text', 'source'}));
    });
  });

  group('round-trip', () {
    test('serialize → parse anahtarları korur', () {
      const model = BookModel(
        id: 7,
        title: 'Kitap',
        description: 'Açıklama',
        assetImage: 'x.png',
        bookOrder: 3,
        seriesId: 2,
        contentFile: 'book_7.json',
      );

      final record = firstRecord(serializer.serializeBooks([model]));
      final restored = BookModel.fromJson(record);

      expect(restored.id, model.id);
      expect(restored.title, model.title);
      expect(restored.bookOrder, model.bookOrder);
      expect(restored.seriesId, model.seriesId);
      expect(restored.contentFile, model.contentFile);
    });
  });
}
