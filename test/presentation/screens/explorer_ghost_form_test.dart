import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/explorer/content_explorer_screen.dart';

/// Seçili kayıt formun dışından kaybolduğunda (undo, sunucudan yeniden
/// yükleme) EditPanel aynı ValueKey'i koruyor, form State'i yaşamaya devam
/// ediyordu: başlık "New Series"e dönüyor ama alanlar silinen kaydın eski
/// değerleriyle dolu kalıyordu — "Create Series" kaydı aynı ID ile geri
/// ekliyordu. Silme butonu yolu düzeltilmişti, bu yol değil.
void main() {
  const series = SeriesModel(
    id: 1,
    name: 'Silinecek seri',
    sortOrder: 1,
    isLocked: false,
    iconEmoji: '📗',
  );

  const book = BookModel(
    id: 7,
    title: 'Kitap',
    description: 'Açıklama',
    assetImage: 'assets/images/book_7/book_7.webp',
    bookOrder: 1,
    seriesId: 1,
    contentFile: 'book_7.json',
  );

  const questionOne = QuestionModel(
    questionText: 'Birinci soru',
    optionA: 'A',
    optionB: 'B',
    optionC: '',
    optionD: '',
    correctOption: 'A',
    type: 'true_false',
  );

  const questionTwo = QuestionModel(
    questionText: 'İkinci soru',
    optionA: 'A',
    optionB: 'B',
    optionC: '',
    optionD: '',
    correctOption: 'B',
    type: 'true_false',
  );

  const level = LevelModel(
    id: 1,
    bookId: 7,
    categoryName: 'Mekke',
    levelOrder: 1,
    title: 'Bölüm',
    unlockScore: 0,
    questions: [questionOne, questionTwo],
  );

  Future<ProviderContainer> pumpExplorer(
    WidgetTester tester,
    ContentState state,
  ) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(false),
        contentStateProvider.overrideWith((ref) => ContentNotifier(state)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ContentExplorerScreen()),
      ),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pumpAndSettle();
  }

  testWidgets('seçili seri dışarıdan silinince form create moduna düşmez',
      (tester) async {
    final container = await pumpExplorer(
      tester,
      const ContentState(
        series: [series],
        books: [],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      ),
    );

    await search(tester, 'Silinecek');
    await tester.tap(find.text('Silinecek seri'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Series'), findsOneWidget);

    // Undo / sunucudan yeniden yükleme ile aynı etki: kayıt state'ten gider.
    container.read(contentStateProvider.notifier).deleteSeries(1);
    await tester.pumpAndSettle();

    expect(find.text('New Series'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Create Series'), findsNothing);
    // Silinen kaydın adı formda hayalet olarak durmamalı.
    expect(find.widgetWithText(TextFormField, 'Silinecek seri'), findsNothing);
    expect(container.read(contentStateProvider).series, isEmpty);
  });

  testWidgets('seçili soru dışarıdan silinince form create moduna düşmez',
      (tester) async {
    final container = await pumpExplorer(
      tester,
      const ContentState(
        series: [series],
        books: [book],
        contentFiles: {
          'book_7.json': [level]
        },
        rewards: [],
        hadiths: [],
      ),
    );

    await search(tester, 'İkinci');
    await tester.tap(find.text('İkinci soru'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Question'), findsOneWidget);

    // Başka bir soru silinince seçili index aralık dışına düşer.
    container
        .read(contentStateProvider.notifier)
        .deleteQuestion('book_7.json', 1, 0);
    await tester.pumpAndSettle();

    expect(find.text('New Question'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Save Question'), findsNothing);
    expect(
      container.read(contentStateProvider).contentFiles['book_7.json']!.single
          .questions
          .length,
      1,
    );
  });
}
