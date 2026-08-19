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

/// İki ayrı sorun aynı kökten geliyordu: silme sonrası `_selectedItem`
/// hiçbir zaman temizlenmiyordu. Level silinince EditPanel aynı ValueKey'i
/// koruyup State'i yeniden kullanıyor, panel silinen level'ın eski
/// değerleriyle dolu bir "New Level" formuna dönüşüyordu — "Create Level"
/// eski level_order ile geri ekleyip content dosyasının kaydını bloklardı.
/// Soru silmenin ise hiç UI'ı yoktu (`deleteQuestion` çağrılmıyordu).
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

  Future<ProviderContainer> pumpExplorer(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(false),
        contentStateProvider.overrideWith(
          (ref) => ContentNotifier(const ContentState(
            series: [series],
            books: [book],
            contentFiles: {'book_7.json': [level]},
            rewards: [],
            hadiths: [],
          )),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ContentExplorerScreen()),
      ),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  /// Arama modunda ağaç kendiliğinden açılır — ExpansionTile tıklamalarına
  /// girmeden hedef düğüme ulaşmanın en dayanıklı yolu.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pumpAndSettle();
  }

  Future<void> confirmDelete(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
  }

  testWidgets('level silinince seçim temizlenir ve form geri gelmez',
      (tester) async {
    final c = await pumpExplorer(tester);

    await search(tester, 'Bölüm');
    await tester.tap(find.text('Bölüm').last);
    await tester.pumpAndSettle();
    expect(find.text('Edit Level'), findsOneWidget);

    await confirmDelete(tester, 'Delete level (cascades to questions)');

    expect(c.read(contentStateProvider).contentFiles['book_7.json'], isEmpty);
    expect(find.text('Select an item to edit'), findsOneWidget,
        reason: 'silinen level\'ın formu panelde kalmamalı');
    expect(find.text('New Level'), findsNothing,
        reason: 'silinen level dolu bir create formuna dönüşmemeli');
  });

  testWidgets('soru silme UI\'dan yapılabilir ve seçim temizlenir',
      (tester) async {
    final c = await pumpExplorer(tester);

    await search(tester, 'Birinci soru');
    await tester.tap(find.text('Birinci soru').last);
    await tester.pumpAndSettle();
    expect(find.text('Edit Question'), findsOneWidget);

    await confirmDelete(tester, 'Delete question');

    final questions =
        c.read(contentStateProvider).contentFiles['book_7.json']!.single.questions;
    expect(questions, [questionTwo],
        reason: 'yalnızca seçili soru silinmeli');
    expect(find.text('Select an item to edit'), findsOneWidget);
  });

  testWidgets('yeni soru formunda silme butonu yok', (tester) async {
    await pumpExplorer(tester);

    await search(tester, 'Bölüm');
    await tester.tap(find.text('Bölüm').last);
    await tester.pumpAndSettle();

    expect(find.text('Edit Level'), findsOneWidget);
    expect(find.byTooltip('Delete question'), findsNothing);
  });
}
