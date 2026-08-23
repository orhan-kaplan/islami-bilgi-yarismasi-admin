import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/explorer/content_explorer_screen.dart';

/// Create formu kayıttan sonra create modunda kalıyordu: aynı ID / aynı sıra
/// ile ikinci kez "Create" demek kaydı bir kez daha ekliyordu ve soru
/// formunda hiçbir geri bildirim yoktu. Kayıttan sonra panel yeni kaydın
/// edit moduna geçmeli.
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

  const level = LevelModel(
    id: 1,
    bookId: 7,
    categoryName: 'Mekke',
    levelOrder: 1,
    title: 'Bölüm',
    unlockScore: 0,
    questions: [],
  );

  Future<ProviderContainer> pumpExplorer(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(false),
        contentStateProvider.overrideWith(
          (ref) => ContentNotifier(const ContentState(
            series: [series],
            books: [book],
            contentFiles: {
              'book_7.json': [level]
            },
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

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), value);
    await tester.pumpAndSettle();
  }

  testWidgets('soru kaydedilince panel edit moduna geçer, ikinci Save '
      'ikinci soruyu eklemez', (tester) async {
    final container = await pumpExplorer(tester);
    await search(tester, 'Bölüm');

    await tester.tap(find.byTooltip('Add Question'));
    await tester.pumpAndSettle();
    expect(find.text('New Question'), findsOneWidget);

    await fill(tester, 'Question Text *', 'Yeni soru');
    await fill(tester, 'Option A *', 'Şık A');
    await fill(tester, 'Option B *', 'Şık B');

    await tester.tap(find.widgetWithText(FilledButton, 'Save Question'));
    await tester.pumpAndSettle();

    List<LevelModel> levels() =>
        container.read(contentStateProvider).contentFiles['book_7.json']!;

    expect(levels().single.questions.length, 1);
    expect(find.text('Question created'), findsOneWidget);
    expect(find.text('Edit Question'), findsOneWidget);
    expect(find.text('New Question'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Save Question'));
    await tester.pumpAndSettle();

    expect(levels().single.questions.length, 1);
  });

  testWidgets('seri kaydedilince panel edit moduna geçer, ikinci Create '
      'ikinci seriyi eklemez', (tester) async {
    final container = await pumpExplorer(tester);

    await tester.tap(find.text('Add Series'));
    await tester.pumpAndSettle();
    expect(find.text('New Series'), findsOneWidget);

    await fill(tester, 'Name *', 'İkinci seri');
    await fill(tester, 'Icon Emoji *', '📘');

    await tester.tap(find.widgetWithText(FilledButton, 'Create Series'));
    await tester.pumpAndSettle();

    expect(container.read(contentStateProvider).series.length, 2);
    expect(find.text('Edit Series'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Update Series'));
    await tester.pumpAndSettle();

    expect(container.read(contentStateProvider).series.length, 2);
  });

  testWidgets('level kaydedilince panel edit moduna geçer, ikinci Create '
      'ikinci level\'ı eklemez', (tester) async {
    final container = await pumpExplorer(tester);
    await search(tester, 'Kitap');

    await tester.tap(find.byTooltip('Add Level'));
    await tester.pumpAndSettle();
    expect(find.text('New Level'), findsOneWidget);

    await fill(tester, 'Category Name *', 'Medine');
    await fill(tester, 'Title *', 'İkinci bölüm');

    await tester.tap(find.widgetWithText(FilledButton, 'Create Level'));
    await tester.pumpAndSettle();

    List<LevelModel> levels() =>
        container.read(contentStateProvider).contentFiles['book_7.json']!;

    expect(levels().length, 2);
    expect(find.text('Edit Level'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Update Level'));
    await tester.pumpAndSettle();

    expect(levels().length, 2);
  });
}
