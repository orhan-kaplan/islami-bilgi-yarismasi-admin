import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/question_model.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/forms/multiple_choice_form.dart';

/// Option C/D zorunlu değil ama `correct_option` dropdown'u onları kısıtsız
/// kabul ediyordu: boş bir şıkkı doğru cevap yapan soru kaydedilebiliyor,
/// ContentValidator 10.18 ERROR üretiyor ve o content dosyasının tamamının
/// auto-save'i bloklanıyordu. Form kaydı reddediyor; ama ret yalnızca Save'e
/// basınca ve dropdown'ın altında görünüyordu — menü hâlâ seçilemeyecek bir
/// şıkkı normal seçenek gibi listeliyordu.
void main() {
  Finder fieldFor(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextFormField),
      );

  Future<QuestionModel?> pumpForm(
    WidgetTester tester, {
    QuestionModel? question,
    void Function(QuestionModel)? onSaved,
  }) async {
    QuestionModel? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MultipleChoiceForm(
            question: question,
            onSave: (q) {
              saved = q;
              onSaved?.call(q);
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return saved;
  }

  DropdownMenuItem<String> itemFor(WidgetTester tester, String value) {
    final dropdown =
        tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
    return dropdown.items!.firstWhere((item) => item.value == value);
  }

  Future<QuestionModel?> fillAndSave(
    WidgetTester tester, {
    required String optionC,
    required String optionD,
    required String correctOption,
  }) async {
    QuestionModel? saved;
    await pumpForm(tester, onSaved: (q) => saved = q);

    await tester.enterText(fieldFor('Question Text *'), 'Soru metni');
    await tester.enterText(fieldFor('Option A *'), 'A şıkkı');
    await tester.enterText(fieldFor('Option B *'), 'B şıkkı');
    if (optionC.isNotEmpty) {
      await tester.enterText(fieldFor('Option C'), optionC);
    }
    if (optionD.isNotEmpty) {
      await tester.enterText(fieldFor('Option D'), optionD);
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(correctOption).last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save Question'));
    await tester.pumpAndSettle();

    return saved;
  }

  testWidgets('boş şık doğru cevap menüsünde seçilemez', (tester) async {
    await pumpForm(tester);

    expect(itemFor(tester, 'C').enabled, isFalse);
    expect(itemFor(tester, 'D').enabled, isFalse);
    expect(itemFor(tester, 'A').enabled, isTrue);
    // Neden seçilemediği menüde okunabilmeli.
    expect((itemFor(tester, 'C').child as Text).data, 'C (empty)');
  });

  testWidgets('şık doldurulunca doğru cevap olarak seçilebilir hale gelir',
      (tester) async {
    await pumpForm(tester);

    expect(itemFor(tester, 'C').enabled, isFalse);

    await tester.enterText(fieldFor('Option C'), 'C şıkkı');
    await tester.pumpAndSettle();

    expect(itemFor(tester, 'C').enabled, isTrue);
    expect((itemFor(tester, 'C').child as Text).data, 'C');
  });

  testWidgets('boş şıkka işaret eden mevcut kayıt Save ile geçemez',
      (tester) async {
    // Diskten gelmiş bozuk kayıt: correct_option C ama option_c boş.
    QuestionModel? saved;
    await pumpForm(
      tester,
      question: const QuestionModel(
        questionText: 'Soru metni',
        optionA: 'A şıkkı',
        optionB: 'B şıkkı',
        optionC: '',
        optionD: '',
        correctOption: 'C',
        type: 'multiple_choice',
      ),
      onSaved: (q) => saved = q,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save Question'));
    await tester.pumpAndSettle();

    expect(saved, isNull,
        reason: 'boş şıkka işaret eden correct_option kaydedilmemeli');
    expect(
      find.textContaining('empty'),
      findsWidgets,
      reason: 'kullanıcı neden kaydedemediğini görmeli',
    );
  });

  testWidgets('dolu option_c doğru cevap seçilince kaydeder', (tester) async {
    final saved = await fillAndSave(
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
    final saved = await fillAndSave(
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
