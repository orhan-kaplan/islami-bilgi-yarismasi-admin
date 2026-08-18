import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/book_form.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/series_form.dart';

/// Create formlarında sıra alanı sabit `1` ile açılıyordu; alanlar disabled
/// olduğu için ikinci seri/kitap oluşturulur oluşturulmaz ardışıklık kuralı
/// kırılıyor ve `series.json` / `books.json` kayıt-bloklu hale geliyordu.
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

  Future<void> pumpForm(
    WidgetTester tester,
    Widget form, {
    List<SeriesModel> seriesList = const [],
    List<BookModel> books = const [],
  }) async {
    final initial = ContentState(
      series: seriesList,
      books: books,
      contentFiles: const {},
      rewards: const [],
      hadiths: const [],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(false),
        contentStateProvider.overrideWith((ref) => ContentNotifier(initial)),
      ],
      child: MaterialApp(home: Scaffold(body: form)),
    ));
    await tester.pumpAndSettle();
  }

  void expectOrderField(String label, String value) {
    final field = find.ancestor(
      of: find.text(label),
      matching: find.byType(TextFormField),
    );
    expect(find.descendant(of: field, matching: find.text(value)),
        findsOneWidget);
  }

  testWidgets('yeni seri, mevcut seri sayısının bir fazlasıyla açılır',
      (tester) async {
    await pumpForm(tester, const SeriesForm(),
        seriesList: [series(1, 1), series(2, 2)]);

    expectOrderField('Sort Order', '3');
  });

  testWidgets('ilk seri sıra 1 ile açılır', (tester) async {
    await pumpForm(tester, const SeriesForm());

    expectOrderField('Sort Order', '1');
  });

  testWidgets('yeni kitap, serideki kitap sayısının bir fazlasıyla açılır',
      (tester) async {
    await pumpForm(
      tester,
      const BookForm(seriesId: 1),
      seriesList: [series(1, 1)],
      books: [book(1, 1, 1)],
    );

    expectOrderField('Book Order', '2');
  });

  testWidgets('başka serinin kitapları sırayı etkilemez', (tester) async {
    await pumpForm(
      tester,
      const BookForm(seriesId: 2),
      seriesList: [series(1, 1), series(2, 2)],
      books: [book(1, 1, 1), book(2, 1, 2)],
    );

    expectOrderField('Book Order', '1');
  });
}
