import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/book_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/content_state.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/level_model.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/content_validator.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/connectivity_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/level_form.dart';

/// `LevelForm._save` `widget.bookId`'yi yok sayıp `0` yazıyordu: yeni her level
/// var olmayan bir kitaba bağlanıyor, `_validateLevelBookFK` ERROR üretiyor ve
/// content dosyası hiç kaydedilemiyordu. Sıra alanı da sabit `1` olduğu için
/// ikinci level ardışıklık kuralını kırıyordu.
void main() {
  const book = BookModel(
    id: 7,
    title: 'Kitap',
    description: '',
    assetImage: 'assets/images/book_7.png',
    bookOrder: 1,
    seriesId: 1,
    contentFile: 'book_7.json',
  );

  LevelModel level(int id, int order) => LevelModel(
        id: id,
        bookId: 7,
        categoryName: 'c',
        levelOrder: order,
        title: 'L$id',
        unlockScore: 0,
        questions: const [],
      );

  Future<ProviderContainer> pumpCreateForm(
    WidgetTester tester, {
    required List<LevelModel> existingLevels,
  }) async {
    final initial = ContentState(
      series: const [],
      books: const [book],
      contentFiles: {'book_7.json': existingLevels},
      rewards: const [],
      hadiths: const [],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        isServerConnectedProvider.overrideWithValue(false),
        contentStateProvider.overrideWith((ref) => ContentNotifier(initial)),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: LevelForm(contentFile: 'book_7.json', bookId: 7),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  Future<void> fillAndSave(WidgetTester tester) async {
    await tester.enterText(
      find.ancestor(
        of: find.text('Category Name *'),
        matching: find.byType(TextFormField),
      ),
      'Mekke',
    );
    await tester.enterText(
      find.ancestor(
        of: find.text('Title *'),
        matching: find.byType(TextFormField),
      ),
      'Bölüm 1',
    );
    final saveButton = find.widgetWithText(FilledButton, 'Create Level');
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  }

  testWidgets('yeni level ait olduğu kitabın ID\'sini alır', (tester) async {
    final c = await pumpCreateForm(tester, existingLevels: const []);

    await fillAndSave(tester);

    final levels = c.read(contentStateProvider).contentFiles['book_7.json']!;
    expect(levels, hasLength(1));
    expect(levels.single.bookId, 7, reason: 'book_id 0 kalmamalı');
  });

  testWidgets('yeni level FK hatası üretmez', (tester) async {
    final c = await pumpCreateForm(tester, existingLevels: const []);

    await fillAndSave(tester);

    final state = c.read(contentStateProvider);
    expect(state.contentFiles['book_7.json'], hasLength(1));

    final issues = ContentValidator().validateAll(state);
    final fkErrors = issues.where((i) =>
        i.severity == ValidationSeverity.error &&
        i.message.contains('non-existent book ID'));
    expect(fkErrors, isEmpty);
  });

  testWidgets('sıra alanı mevcut level sayısının bir fazlasıyla açılır',
      (tester) async {
    await pumpCreateForm(tester, existingLevels: [level(1, 1)]);

    final orderField = find.ancestor(
      of: find.text('Level Order'),
      matching: find.byType(TextFormField),
    );
    expect(find.descendant(of: orderField, matching: find.text('2')),
        findsOneWidget);
  });

  testWidgets('ilk level sıra 1 ile açılır', (tester) async {
    await pumpCreateForm(tester, existingLevels: const []);

    final orderField = find.ancestor(
      of: find.text('Level Order'),
      matching: find.byType(TextFormField),
    );
    expect(find.descendant(of: orderField, matching: find.text('1')),
        findsOneWidget);
  });
}
