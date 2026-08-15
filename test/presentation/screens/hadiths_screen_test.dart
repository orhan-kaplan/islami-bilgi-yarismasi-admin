import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/hadith_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/hadiths/hadiths_screen.dart';

void main() {
  group('HadithsScreen add dialog', () {
    testWidgets('Add Hadith opens a dialog with Hadith, Source, Cancel, Save',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HadithsScreen()),
        ),
      );

      await tester.tap(find.text('Add Hadith'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Hadith'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Source'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    });

    testWidgets('Save with empty fields does not add a hadith', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HadithsScreen()),
        ),
      );

      await tester.tap(find.text('Add Hadith'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Hadith text is required'), findsOneWidget);
      expect(find.text('Source is required'), findsOneWidget);
    });

    testWidgets('Save with filled fields adds the hadith and closes dialog',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(home: HadithsScreen());
            },
          ),
        ),
      );

      await tester.tap(find.text('Add Hadith'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Hadith'),
        'İlim öğrenmek her Müslümana farzdır.',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Source'),
        'İbn Mace, Mukaddime, 17',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      final hadiths = container.read(contentStateProvider).hadiths;
      expect(hadiths, hasLength(1));
      expect(
        hadiths.single,
        const HadithModel(
          text: 'İlim öğrenmek her Müslümana farzdır.',
          source: 'İbn Mace, Mukaddime, 17',
        ),
      );
    });

    testWidgets('Cancel closes the dialog without adding a hadith',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(home: HadithsScreen());
            },
          ),
        ),
      );

      await tester.tap(find.text('Add Hadith'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(contentStateProvider).hadiths, isEmpty);
    });
  });
}
