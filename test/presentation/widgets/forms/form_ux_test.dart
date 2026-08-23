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
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/book_form.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/inline_image_picker.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/level_form.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/matching_form.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/question_form.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/shared/confirm_dialog.dart';

/// Form kusurları:
/// - BookForm'un zorunlu görsel hatası yalnızca snackbar'daydı (kaydırılmış
///   uzun formda hangi alanın eksik olduğu görünmüyordu),
/// - soru tipini değiştirmek yazılmış içeriği uyarısız siliyordu,
/// - sunucu kapalıyken görsel seçicinin neden ölü olduğu yazmıyordu,
/// - ConfirmDialog'un Delete butonu yıkıcı görünmüyordu,
/// - matching alanlarına yazılan `|` değeri kaydedip açınca bozuyordu,
/// - admin UI'da Türkçe metinler kalmıştı.
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

  const existingQuestion = QuestionModel(
    questionText: 'Tekrar eden soru',
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
    questions: [existingQuestion],
  );

  ContentState baseState() => const ContentState(
        series: [series],
        books: [book],
        contentFiles: {
          'book_7.json': [level]
        },
        rewards: [],
        hadiths: [],
      );

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child, {
    bool connected = false,
  }) async {
    // Formların tamamı görünür olsun: kaydırma davranışı bu dosyanın konusu
    // değil, tıklamaların hedefi ıskalamaması önemli.
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(connected),
        contentStateProvider.overrideWith((ref) => ContentNotifier(baseState())),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  group('BookForm zorunlu görsel', () {
    testWidgets('görsel seçilmeden kaydedilince hata alanın yanında görünür',
        (tester) async {
      await pump(tester, const BookForm(seriesId: 1));

      expect(find.byKey(const Key('book_asset_image_error')), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Yeni kitap',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description *'),
        'Yeni açıklama',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create Book'));
      await tester.pumpAndSettle();

      final error = find.byKey(const Key('book_asset_image_error'));
      expect(error, findsOneWidget);
      // Snackbar kaybolduktan sonra da yerinde durmalı.
      await tester.pump(const Duration(seconds: 6));
      expect(error, findsOneWidget);
    });
  });

  group('soru tipi değişimi', () {
    testWidgets('yazılmış içerik varken uyarısız sıfırlanmaz', (tester) async {
      await pump(
        tester,
        QuestionForm(onSave: (_) {}),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question Text *'),
        'Kaybolmaması gereken metin',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('True / False').last);
      await tester.pumpAndSettle();

      // Onay istenmeli; iptal edilirse tip ve metin korunmalı.
      expect(find.widgetWithText(FilledButton, 'Change type'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Option A *'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Kaybolmaması gereken metin'),
        findsOneWidget,
      );
    });

    testWidgets('onaylanırsa tip değişir', (tester) async {
      await pump(tester, QuestionForm(onSave: (_) {}));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question Text *'),
        'Bir metin',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('True / False').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Change type'));
      await tester.pumpAndSettle();

      expect(find.text('Options (auto-filled)'), findsOneWidget);
    });

    testWidgets('boş formda onay istenmez', (tester) async {
      await pump(tester, QuestionForm(onSave: (_) {}));

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('True / False').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Change type'), findsNothing);
      expect(find.text('Options (auto-filled)'), findsOneWidget);
    });
  });

  group('görsel seçici offline', () {
    testWidgets('sunucu kapalıyken nedeni tooltip ile söylenir',
        (tester) async {
      await pump(
        tester,
        const InlineImagePicker(
          currentAppPath: null,
          defaultDirectory: 'images/book_7/',
          onPathChanged: _noop,
        ),
      );

      expect(
        find.byTooltip('Asset server is offline — image upload unavailable.'),
        findsOneWidget,
      );
    });
  });

  group('ConfirmDialog', () {
    testWidgets('yıkıcı onay butonu error rengindedir', (tester) async {
      final theme = ThemeData.light();
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => ConfirmDialog.show(
                  context: context,
                  title: 'Delete Series',
                  message: 'Are you sure?',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );
      expect(
        button.style?.backgroundColor?.resolve(<WidgetState>{}),
        theme.colorScheme.error,
      );
    });

    testWidgets('yıkıcı olmayan onay butonu error rengine boyanmaz',
        (tester) async {
      final theme = ThemeData.light();
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => ConfirmDialog.show(
                  context: context,
                  title: 'Apply',
                  message: 'Are you sure?',
                  confirmLabel: 'Apply',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Apply'),
      );
      expect(
        button.style?.backgroundColor?.resolve(<WidgetState>{}),
        isNot(theme.colorScheme.error),
      );
    });
  });

  group('matching ayırıcısı', () {
    testWidgets('alanlara | yazılamaz', (tester) async {
      QuestionModel? saved;
      await pump(
        tester,
        MatchingForm(onSave: (q) => saved = q),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question Text *'),
        'Eşleştir',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pair A - Left'),
        'Sol|Kaçak',
      );
      await tester.pumpAndSettle();

      expect(find.text('Sol|Kaçak'), findsNothing);
      expect(find.text('SolKaçak'), findsOneWidget);

      for (final label in [
        'Pair A - Right',
        'Pair B - Left',
        'Pair B - Right',
        'Pair C - Left',
        'Pair C - Right',
        'Pair D - Left',
        'Pair D - Right',
      ]) {
        await tester.enterText(
          find.widgetWithText(TextFormField, label),
          'x',
        );
      }
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save Question'));
      await tester.pumpAndSettle();

      // Sol taraf tek parça kalmalı: '|' yalnız ayırıcı olarak var.
      expect(saved!.optionA.split('|').length, 2);
      expect(saved!.optionA.split('|').first.trim(), 'SolKaçak');
    });
  });

  group('admin UI dili', () {
    testWidgets('sıra alanının yardım metni İngilizcedir', (tester) async {
      await pump(
        tester,
        const LevelForm(contentFile: 'book_7.json', level: level),
      );

      expect(find.text('Drag-drop ile ayarlanır'), findsNothing);
      expect(find.text('Set via drag & drop'), findsOneWidget);
    });

    testWidgets('duplicate uyarısı İngilizcedir', (tester) async {
      await pump(
        tester,
        QuestionForm(onSave: (_) {}),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Question Text *'),
        'Tekrar eden soru',
      );
      await tester.pumpAndSettle();

      expect(find.text('Bu soru başka bir yerde de mevcut:'), findsNothing);
      expect(
        find.text('This question already exists elsewhere:'),
        findsOneWidget,
      );
    });
  });
}

void _noop(String _) {}
