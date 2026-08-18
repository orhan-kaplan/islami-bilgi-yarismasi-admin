import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';

/// `Object.hashAll(contentFiles.entries)` her çağrıda yeni MapEntry nesneleri
/// ürettiği ve MapEntry `hashCode` override etmediği için hash kararsızdı:
/// aynı instance iki çağrıda farklı değer veriyordu.
void main() {
  const level = LevelModel(
    id: 1,
    bookId: 1,
    categoryName: 'c',
    levelOrder: 1,
    title: 'L1',
    unlockScore: 0,
    questions: [],
  );

  test('aynı instance için hashCode kararlıdır', () {
    const state = ContentState(
      series: [],
      books: [],
      contentFiles: {
        'book_1.json': [level],
      },
      rewards: [],
      hadiths: [],
    );

    expect(state.hashCode, state.hashCode);
  });

  test('eşit iki state aynı hashCode üretir', () {
    const levels = [level];
    const a = ContentState(
      series: [],
      books: [],
      contentFiles: {'book_1.json': levels},
      rewards: [],
      hadiths: [],
    );
    const b = ContentState(
      series: [],
      books: [],
      contentFiles: {'book_1.json': levels},
      rewards: [],
      hadiths: [],
    );

    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('anahtar sırası hashCode\'u değiştirmez', () {
    const levels = [level];
    const other = <LevelModel>[];
    // Sabit map literal'leri canonicalize edilip aynı instance'a düşeceği için
    // haritalar çalışma zamanında kuruluyor.
    final mapA = <String, List<LevelModel>>{
      'book_1.json': levels,
      'book_2.json': other,
    };
    final mapB = <String, List<LevelModel>>{
      'book_2.json': other,
      'book_1.json': levels,
    };
    final a = ContentState(
      series: const [],
      books: const [],
      contentFiles: mapA,
      rewards: const [],
      hadiths: const [],
    );
    final b = ContentState(
      series: const [],
      books: const [],
      contentFiles: mapB,
      rewards: const [],
      hadiths: const [],
    );

    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });

  test('farklı content dosyaları farklı hashCode verir', () {
    final withLevel = <String, List<LevelModel>>{
      'book_1.json': const [level],
    };
    final empty = <String, List<LevelModel>>{
      'book_1.json': const <LevelModel>[],
    };
    final a = ContentState(
      series: const [],
      books: const [],
      contentFiles: withLevel,
      rewards: const [],
      hadiths: const [],
    );
    final b = ContentState(
      series: const [],
      books: const [],
      contentFiles: empty,
      rewards: const [],
      hadiths: const [],
    );

    expect(a.hashCode, isNot(b.hashCode));
  });
}
