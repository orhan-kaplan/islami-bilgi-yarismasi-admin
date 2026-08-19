import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/book_form.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/inline_image_picker.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/level_form.dart';

/// Görsel seçici, edit modunda `_formKey.validate()` çağırmadan modelin
/// tamamını ContentState'e yeniden yazıyordu. Zorunlu bir alan o an boşsa boş
/// string diske gidiyor (ContentValidator ERROR → dosyanın kaydı bloklanıyor),
/// boş bir sayı alanı ise `int.parse('')` ile FormatException fırlatıyordu —
/// exception picker'ın catch'ine düşüp "Upload failed" diye raporlanıyor,
/// seçilen path sessizce kayboluyordu.
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
    description: 'Kitap açıklaması',
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
    title: 'Birinci bölüm',
    unlockScore: 0,
    questions: [],
  );

  ContentState baseState() => const ContentState(
        series: [series],
        books: [book],
        contentFiles: {'book_7.json': [level]},
        rewards: [],
        hadiths: [],
      );

  Future<ProviderContainer> pump(WidgetTester tester, Widget form) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(false),
        contentStateProvider.overrideWith((ref) => ContentNotifier(baseState())),
      ],
      child: MaterialApp(home: Scaffold(body: form)),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  Finder fieldFor(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextFormField),
      );

  /// Picker'ın başarılı yükleme sonrası yaptığı çağrıyı taklit eder —
  /// file_picker veya HTTP'ye girmeden aynı kod yolunu tetikler.
  Future<void> pickImage(WidgetTester tester, String appPath) async {
    final picker = tester.widget<InlineImagePicker>(
      find.byType(InlineImagePicker),
    );
    picker.onPathChanged(appPath);
    await tester.pumpAndSettle();
  }

  group('LevelForm', () {
    testWidgets('boş Title varken görsel seçimi ContentState\'e yazmaz',
        (tester) async {
      final c = await pump(
        tester,
        const LevelForm(contentFile: 'book_7.json', level: level),
      );

      await tester.enterText(fieldFor('Title *'), '');
      await pickImage(tester, 'assets/images/book_7/level_1.webp');

      final stored = c.read(contentStateProvider).contentFiles['book_7.json']!;
      expect(stored.single.title, 'Birinci bölüm',
          reason: 'boş title diske gitmemeli');
      expect(stored.single.assetImage, isNull,
          reason: 'geçersiz formdan hiçbir alan commit edilmemeli');
    });

    testWidgets('boş Unlock Score varken görsel seçimi patlamaz',
        (tester) async {
      final c = await pump(
        tester,
        const LevelForm(contentFile: 'book_7.json', level: level),
      );

      await tester.enterText(fieldFor('Unlock Score'), '');
      await pickImage(tester, 'assets/images/book_7/level_1.webp');

      expect(tester.takeException(), isNull,
          reason: 'int.parse(\'\') FormatException fırlatmamalı');
      final stored = c.read(contentStateProvider).contentFiles['book_7.json']!;
      expect(stored.single.unlockScore, 0);
    });

    testWidgets('form geçerliyken görsel seçimi commit edilir', (tester) async {
      final c = await pump(
        tester,
        const LevelForm(contentFile: 'book_7.json', level: level),
      );

      await pickImage(tester, 'assets/images/book_7/level_1.webp');

      final stored = c.read(contentStateProvider).contentFiles['book_7.json']!;
      expect(stored.single.assetImage, 'assets/images/book_7/level_1.webp');
      expect(stored.single.title, 'Birinci bölüm');
    });
  });

  group('BookForm', () {
    testWidgets('boş Description varken görsel seçimi ContentState\'e yazmaz',
        (tester) async {
      final c = await pump(tester, const BookForm(book: book));

      await tester.enterText(fieldFor('Description *'), '');
      await pickImage(tester, 'assets/images/book_7/book_7_v2.webp');

      final stored = c.read(contentStateProvider).books.single;
      expect(stored.description, 'Kitap açıklaması');
      expect(stored.assetImage, 'assets/images/book_7/book_7.webp');
    });

    testWidgets('form geçerliyken görsel seçimi commit edilir', (tester) async {
      final c = await pump(tester, const BookForm(book: book));

      await pickImage(tester, 'assets/images/book_7/book_7_v2.webp');

      expect(c.read(contentStateProvider).books.single.assetImage,
          'assets/images/book_7/book_7_v2.webp');
    });
  });
}
