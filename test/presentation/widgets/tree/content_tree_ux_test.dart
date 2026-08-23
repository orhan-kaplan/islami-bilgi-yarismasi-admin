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
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/tree/content_tree.dart';

/// Ağacın kullanılabilirlik kusurları:
/// - içerik boşken "Add Series" hiç render edilmiyordu (ilk seri açılamıyordu),
/// - seçili düğüm hiçbir şekilde işaretlenmiyordu,
/// - level satırında tıklama alanı yalnızca başlık metni kadardı,
/// - arama açılınca bütün ekleme butonları kayboluyordu,
/// - boş durum mesajı sunucuya bağlıyken de ZIP import'u işaret ediyordu.
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

  const question = QuestionModel(
    questionText: 'Birinci soru',
    optionA: 'A',
    optionB: 'B',
    optionC: '',
    optionD: '',
    correctOption: 'A',
    type: 'true_false',
  );

  const level = LevelModel(
    id: 1,
    bookId: 7,
    categoryName: 'Mekke',
    levelOrder: 1,
    title: 'Bölüm',
    unlockScore: 0,
    questions: [question],
  );

  ContentState fullState() => const ContentState(
        series: [series],
        books: [book],
        contentFiles: {
          'book_7.json': [level]
        },
        rewards: [],
        hadiths: [],
      );

  ContentState emptyState() => const ContentState(
        series: [],
        books: [],
        contentFiles: {},
        rewards: [],
        hadiths: [],
      );

  /// Ağacı tek başına basar; seçim callback'i son seçilen öğeyi yakalar.
  Future<List<SelectedItem>> pumpTree(
    WidgetTester tester, {
    required ContentState state,
    bool connected = true,
    SelectedItem? selectedItem,
  }) async {
    final selections = <SelectedItem>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(connected),
        contentStateProvider.overrideWith((ref) => ContentNotifier(state)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: ContentTree(
              selectedItem: selectedItem,
              onItemSelected: selections.add,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return selections;
  }

  /// Explorer'ı bütün olarak basar — arama kutusu ve seçim durumu birlikte.
  Future<void> pumpExplorer(WidgetTester tester, ContentState state) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(true),
        contentStateProvider.overrideWith((ref) => ContentNotifier(state)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ContentExplorerScreen()),
      ),
    ));
    await tester.pumpAndSettle();
  }

  ExpansionTile tileWithTitle(WidgetTester tester, String title) {
    return tester.widget<ExpansionTile>(
      find.ancestor(
        of: find.text(title),
        matching: find.byType(ExpansionTile),
      ).first,
    );
  }

  group('boş içerik', () {
    testWidgets('seri yokken Add Series butonu yine de vardır', (tester) async {
      final selections = await pumpTree(tester, state: emptyState());

      expect(find.text('Add Series'), findsOneWidget);

      await tester.tap(find.text('Add Series'));
      await tester.pumpAndSettle();

      expect(selections.single, isA<CreateSeries>());
    });

    testWidgets('sunucuya bağlıyken ZIP mesajı gösterilmez', (tester) async {
      await pumpTree(tester, state: emptyState(), connected: true);

      expect(find.textContaining('ZIP'), findsNothing);
    });

    testWidgets('sunucu kapalıyken ZIP mesajı gösterilir', (tester) async {
      await pumpTree(tester, state: emptyState(), connected: false);

      expect(find.textContaining('ZIP'), findsOneWidget);
    });
  });

  group('seçim vurgusu', () {
    testWidgets('seçili seri işaretlenir, seçili olmayan işaretlenmez',
        (tester) async {
      await pumpTree(
        tester,
        state: fullState(),
        selectedItem: SelectedSeries(seriesId: 1),
      );

      expect(tileWithTitle(tester, 'Seri').collapsedBackgroundColor, isNotNull);

      await pumpTree(
        tester,
        state: fullState(),
        selectedItem: SelectedBook(bookId: 7),
      );

      expect(tileWithTitle(tester, 'Seri').collapsedBackgroundColor, isNull);
    });

    testWidgets('seçili soru ListTile.selected ile işaretlenir',
        (tester) async {
      await pumpExplorer(tester, fullState());
      await tester.enterText(find.byType(TextField).first, 'Birinci');
      await tester.pumpAndSettle();

      ListTile questionTile() => tester.widget<ListTile>(
            find.ancestor(
              of: find.text('Birinci soru'),
              matching: find.byType(ListTile),
            ),
          );

      expect(questionTile().selected, isFalse);

      await tester.tap(find.text('Birinci soru'));
      await tester.pumpAndSettle();

      expect(questionTile().selected, isTrue);
    });
  });

  group('level satırı tıklama alanı', () {
    testWidgets('arama modunda başlığın sağındaki boşluk da seçer',
        (tester) async {
      await pumpExplorer(tester, fullState());
      // Arama metni tam başlık olmasın: find.text tek eşleşsin.
      await tester.enterText(find.byType(TextField).first, 'Böl');
      await tester.pumpAndSettle();

      final titleRect = tester.getRect(find.text('Bölüm'));
      // Tıklanabilir başlık alanı satır boyunca uzamalı, metin genişliği
      // kadar değil.
      expect(titleRect.width, greaterThan(80));

      await tester.tapAt(
        Offset(titleRect.right - 8, titleRect.center.dy),
      );
      await tester.pumpAndSettle();

      // Seçim gerçekleştiyse sağ panelde level formu açılır.
      expect(find.text('Edit Level'), findsOneWidget);
    });

    testWidgets('normal modda başlığın sağındaki boşluk da seçer',
        (tester) async {
      await pumpExplorer(tester, fullState());

      // Seri ve kitabı chevron üzerinden aç (başlık artık seçim yapıyor).
      await tester.tap(find.byIcon(Icons.expand_more).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.expand_more).at(1));
      await tester.pumpAndSettle();

      final titleRect = tester.getRect(find.text('Bölüm'));
      expect(titleRect.width, greaterThan(80));

      await tester.tapAt(
        Offset(titleRect.right - 8, titleRect.center.dy),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Level'), findsOneWidget);
    });
  });

  group('arama modunda ekleme', () {
    testWidgets('Add Series ve Add Book arama açıkken de görünür',
        (tester) async {
      await pumpExplorer(tester, fullState());
      await tester.enterText(find.byType(TextField).first, 'Seri');
      await tester.pumpAndSettle();

      expect(find.text('Add Series'), findsOneWidget);
      expect(find.byTooltip('Add Book'), findsOneWidget);

      await tester.tap(find.byTooltip('Add Book'));
      await tester.pumpAndSettle();

      expect(find.text('New Book'), findsOneWidget);
    });

    testWidgets('Add Level ve Add Question arama açıkken de görünür',
        (tester) async {
      await pumpExplorer(tester, fullState());
      await tester.enterText(find.byType(TextField).first, 'Birinci soru');
      await tester.pumpAndSettle();

      expect(find.byTooltip('Add Level'), findsOneWidget);
      expect(find.byTooltip('Add Question'), findsOneWidget);

      await tester.tap(find.byTooltip('Add Question'));
      await tester.pumpAndSettle();

      expect(find.text('New Question'), findsOneWidget);
    });
  });
}
