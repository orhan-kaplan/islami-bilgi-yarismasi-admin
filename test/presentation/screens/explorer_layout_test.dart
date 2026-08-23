import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/series_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/history_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/explorer/content_explorer_screen.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/explorer/edit_panel.dart';

/// Explorer layout kusurları:
/// - tree (200-600) + sabit 300px JSON paneli dar pencerede EditPanel'i birkaç
///   piksele indiriyordu (form padding'i tek başına 32px),
/// - Bulk Add dialog'u sabit 700x500 içerikle küçük pencerede taşıyordu ve
///   onaydan sonra hiçbir geri bildirim vermiyordu,
/// - JSON paneli create seçimlerinde "Item not found" diyordu ve uzun satırlar
///   yatay olarak erişilemiyordu.
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
    assetImage:
        'assets/images/book_7/very_long_unbroken_level_cover_file_name_for_horizontal_overflow_check.webp',
    questions: [],
  );

  ContentState state() => const ContentState(
        series: [series],
        books: [book],
        contentFiles: {
          'book_7.json': [level]
        },
        rewards: [],
        hadiths: [],
      );

  Future<ProviderContainer> pumpExplorer(
    WidgetTester tester, {
    required Size surface,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(false),
        contentStateProvider.overrideWith((ref) => ContentNotifier(state())),
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

  Future<void> selectLevel(WidgetTester tester) async {
    // Sorgu tam başlık olmasın: find.text arama kutusuyla çakışmasın.
    await search(tester, 'Böl');
    await tester.tap(find.text('Bölüm'));
    await tester.pumpAndSettle();
  }

  Future<void> toggleJsonPreview(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Toggle JSON Preview'));
    await tester.pumpAndSettle();
  }

  group('panel genişlikleri', () {
    testWidgets('dar pencerede JSON paneli açıkken form paneli ezilmez',
        (tester) async {
      await pumpExplorer(tester, surface: const Size(700, 700));
      await toggleJsonPreview(tester);

      final editWidth = tester.getSize(find.byType(EditPanel)).width;
      expect(editWidth, greaterThanOrEqualTo(300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('çok dar pencerede bile form paneli kullanılabilir kalır',
        (tester) async {
      await pumpExplorer(tester, surface: const Size(640, 700));
      await toggleJsonPreview(tester);

      expect(tester.getSize(find.byType(EditPanel)).width, greaterThan(200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('geniş pencerede tercih edilen genişlikler korunur',
        (tester) async {
      await pumpExplorer(tester, surface: const Size(1600, 800));
      await toggleJsonPreview(tester);

      expect(tester.getSize(find.byType(EditPanel)).width, greaterThan(900));
    });
  });

  group('Bulk Add dialog', () {
    testWidgets('küçük pencerede taşmaz', (tester) async {
      await pumpExplorer(tester, surface: const Size(620, 520));
      await selectLevel(tester);

      await tester.tap(find.text('Bulk Add Questions'));
      await tester.pumpAndSettle();

      expect(find.text('Preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onaydan sonra kaç soru eklendiğini bildirir', (tester) async {
      final container =
          await pumpExplorer(tester, surface: const Size(1400, 900));
      await selectLevel(tester);

      await tester.tap(find.text('Bulk Add Questions'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'Soru bir\nŞık A\nŞık B\nŞık C\nŞık D\nA\n'
        '\n'
        'Soru iki\nŞık A\nŞık B\nŞık C\nŞık D\nB\n',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(
        container.read(contentStateProvider).contentFiles['book_7.json']!.single
            .questions
            .length,
        2,
      );
      expect(find.textContaining('2 questions added'), findsOneWidget);
    });
  });

  group('JSON preview paneli', () {
    testWidgets('create seçiminde "not found" demez', (tester) async {
      await pumpExplorer(tester, surface: const Size(1400, 900));
      await toggleJsonPreview(tester);

      await tester.tap(find.text('Add Series'));
      await tester.pumpAndSettle();

      expect(find.text('Item not found'), findsNothing);
      expect(find.textContaining('Not saved yet'), findsOneWidget);
    });

    testWidgets('uzun satırlar yatay kaydırılabilir', (tester) async {
      await pumpExplorer(tester, surface: const Size(1400, 900));
      await toggleJsonPreview(tester);
      await selectLevel(tester);

      final horizontal = find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(horizontal, findsOneWidget);

      final position = tester.state<ScrollableState>(
        find.descendant(of: horizontal, matching: find.byType(Scrollable)).first,
      ).position;
      // Uzun asset yolu panelden taşıyor; taşan kısım erişilebilir olmalı.
      expect(position.maxScrollExtent, greaterThan(0));

      final before = tester.getTopLeft(find.byType(SelectableText));
      position.jumpTo(100);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byType(SelectableText)).dx,
          lessThan(before.dx));
    });
  });

  group('araç çubuğu dili', () {
    testWidgets('değişiklik günlüğü İngilizce etiketlenir', (tester) async {
      final container =
          await pumpExplorer(tester, surface: const Size(1400, 900));
      // Dirty göstergesi ancak kaydedilmiş bir baseline varken çıkar.
      container.read(savedBaselineProvider.notifier).state =
          container.read(contentStateProvider);
      await selectLevel(tester);

      // Bir düzenleme yap ki dirty göstergesi ve buton görünsün.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Yeni bölüm',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Update Level'));
      await tester.pumpAndSettle();

      expect(find.text('Değişiklikler'), findsNothing);
      expect(find.text('Changes'), findsOneWidget);

      await tester.tap(find.text('Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Kapat'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Close'), findsOneWidget);
    });
  });
}
