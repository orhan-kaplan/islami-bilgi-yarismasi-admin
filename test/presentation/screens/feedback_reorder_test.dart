import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/feedback/feedback_screen.dart';

/// Kartın tamamı sürükleme tutamağıydı (`ReorderableDragStartListener` doğrudan
/// `FeedbackCard`'ı sarıyordu). Sonuç: düzenleme modunda metin seçmeye çalışmak
/// sıralamayı bozuyor, listeyi kartın üzerinden kaydırmak ise hiç mümkün
/// olmuyordu — üstelik feedback tarafında undo yok.
class _MockFeedbackLoadNotifier extends FeedbackLoadNotifier {
  _MockFeedbackLoadNotifier(super.ref) {
    state = FeedbackLoadStatus.loaded;
  }

  @override
  Future<void> performLoad({bool force = false}) async {}
}

void main() {
  FeedbackContentState stateWith(int count) {
    return FeedbackContentState(
      quiz: const {},
      speedQuiz: const {},
      time: const {},
      comeback: List.generate(
        count,
        (i) => FeedbackMessageModel(
          title: 'Mesaj $i',
          message: 'Geri dönüş mesajı $i',
          emoji: '👋',
        ),
      ),
      streak: const {},
      titles: const [],
      learned: const {},
    );
  }

  Future<ProviderContainer> pumpComeback(
    WidgetTester tester, {
    int count = 8,
  }) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedbackContentProvider.overrideWith(
            (ref) => FeedbackContentNotifier(stateWith(count)),
          ),
          feedbackLoadProvider.overrideWith(
            (ref) => _MockFeedbackLoadNotifier(ref),
          ),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(home: FeedbackScreen());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comeback'));
    await tester.pumpAndSettle();
    return container;
  }

  List<String> titlesOf(ProviderContainer c) =>
      c.read(feedbackContentProvider).comeback.map((m) => m.title).toList();

  /// İnsanın yaptığı gibi: bas, küçük adımlarla sürükle, bırak. Tek adımlık
  /// `tester.drag` immediate-multi-drag tanıyıcısını uyandırmıyor, bu yüzden
  /// regresyonu yakalamıyor.
  Future<void> dragWithoutLongPress(
    WidgetTester tester,
    Finder target,
    double dy,
  ) async {
    final gesture = await tester.startGesture(tester.getCenter(target));
    const steps = 8;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, dy / steps));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a drag over a card does not reorder messages', (tester) async {
    final container = await pumpComeback(tester);
    final before = titlesOf(container);

    await dragWithoutLongPress(tester, find.text('Mesaj 0'), 260);

    expect(
      titlesOf(container),
      before,
      reason: 'uzun basılmadan yapılan sürükleme sırayı değiştirmemeli',
    );
  });

  testWidgets('a drag over a card scrolls the list instead', (tester) async {
    await pumpComeback(tester);

    final firstCardTop = tester.getRect(find.text('Mesaj 0')).top;
    await dragWithoutLongPress(tester, find.text('Mesaj 0'), -200);

    expect(
      tester.getRect(find.text('Mesaj 0')).top,
      lessThan(firstCardTop - 100),
      reason: 'kartın üstünden liste kaydırılabilmeli',
    );
  });

  testWidgets('long press then drag still reorders', (tester) async {
    final container = await pumpComeback(tester);
    expect(titlesOf(container).first, 'Mesaj 0');

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Mesaj 0')));
    await tester.pump(const Duration(milliseconds: 700));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      titlesOf(container).first,
      'Mesaj 1',
      reason: 'uzun basıp sürükleme hâlâ sıralamayı değiştirebilmeli',
    );
  });
}
