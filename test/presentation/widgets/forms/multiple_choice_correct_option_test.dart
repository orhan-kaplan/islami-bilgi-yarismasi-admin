import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/multiple_choice_form.dart';

/// Option C/D zorunlu değil ama `correct_option` dropdown'u onları kısıtsız
/// kabul ediyordu: boş bir şıkkı doğru cevap yapan soru kaydedilebiliyor,
/// ContentValidator 10.18 ERROR üretiyor ve o content dosyasının tamamının
/// auto-save'i bloklanıyordu. Form, kaydı en baştan reddetmeli.
void main() {
  Future<QuestionModel?> pumpAndSave(
    WidgetTester tester, {
    required String optionC,
    required String optionD,
    required String correctOption,
  }) async {
    QuestionModel? saved;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MultipleChoiceForm(
            onSave: (q) => saved = q,
          ),
        ),
      ),
    ));

    Finder fieldFor(String label) => find.ancestor(
          of: find.text(label),
          matching: find.byType(TextFormField),
        );

    await tester.enterText(fieldFor('Question Text *'), 'Soru metni');
    await tester.enterText(fieldFor('Option A *'), 'A şıkkı');
    await tester.enterText(fieldFor('Option B *'), 'B şıkkı');
    if (optionC.isNotEmpty) {
      await tester.enterText(fieldFor('Option C'), optionC);
    }
    if (optionD.isNotEmpty) {
      await tester.enterText(fieldFor('Option D'), optionD);
    }

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(correctOption).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save Question'));
    await tester.pumpAndSettle();

    return saved;
  }

  testWidgets('boş option_c doğru cevap seçilince kaydı reddeder',
      (tester) async {
    final saved = await pumpAndSave(
      tester,
      optionC: '',
      optionD: '',
      correctOption: 'C',
    );

    expect(saved, isNull,
        reason: 'boş şıkka işaret eden correct_option kaydedilmemeli');
    expect(
      find.textContaining('empty'),
      findsOneWidget,
      reason: 'kullanıcı neden kaydedemediğini görmeli',
    );
  });

  testWidgets('boş option_d doğru cevap seçilince kaydı reddeder',
      (tester) async {
    final saved = await pumpAndSave(
      tester,
      optionC: 'C şıkkı',
      optionD: '',
      correctOption: 'D',
    );

    expect(saved, isNull);
  });

  testWidgets('dolu option_c doğru cevap seçilince kaydeder', (tester) async {
    final saved = await pumpAndSave(
      tester,
      optionC: 'C şıkkı',
      optionD: '',
      correctOption: 'C',
    );

    expect(saved, isNotNull);
    expect(saved!.correctOption, 'C');
    expect(saved.optionC, 'C şıkkı');
  });

  testWidgets('varsayılan A ile kayıt bozulmadan çalışır', (tester) async {
    final saved = await pumpAndSave(
      tester,
      optionC: '',
      optionD: '',
      correctOption: 'A',
    );

    expect(saved, isNotNull);
    expect(saved!.correctOption, 'A');
    expect(saved.type, 'multiple_choice');
  });
}
