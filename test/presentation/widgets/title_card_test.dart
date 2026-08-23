import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/title_card.dart';

/// Aynı konumdaki kartı dışarıdan başka bir ünvana bağlayan bir harness.
/// `updateTitle` listeyi `required_books`'a göre yeniden sıraladığı ve silme
/// index'leri kaydırdığı için bu, gerçekte sürekli olan bir durum.
class _SwappableTitleHost extends StatefulWidget {
  const _SwappableTitleHost({
    super.key,
    required this.initial,
    required this.width,
  });

  final PlayerTitleModel initial;
  final double width;

  @override
  State<_SwappableTitleHost> createState() => _SwappableTitleHostState();
}

class _SwappableTitleHostState extends State<_SwappableTitleHost> {
  late PlayerTitleModel _title = widget.initial;

  void swap(PlayerTitleModel next) => setState(() => _title = next);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: widget.width,
          child: TitleCard(title: _title, index: 0),
        ),
      ),
    );
  }
}

void main() {
  const alpha = PlayerTitleModel(
    title: 'İlim Yolcusu',
    icon: '🌱',
    requiredBooks: 0,
    profileImage: '',
  );
  const beta = PlayerTitleModel(
    title: 'Talebe',
    icon: '📗',
    requiredBooks: 3,
    profileImage: '',
  );

  FeedbackContentState stateWith(List<PlayerTitleModel> titles) {
    return FeedbackContentState(
      quiz: const {},
      speedQuiz: const {},
      time: const {},
      comeback: const [],
      streak: const {},
      titles: titles,
      learned: const {},
    );
  }

  Widget host({
    required FeedbackContentState state,
    required Widget child,
    void Function(ProviderContainer)? onContainer,
  }) {
    return ProviderScope(
      overrides: [
        feedbackContentProvider.overrideWith(
          (ref) => FeedbackContentNotifier(state),
        ),
      ],
      child: Builder(
        builder: (context) {
          onContainer?.call(ProviderScope.containerOf(context));
          return MaterialApp(home: child);
        },
      ),
    );
  }

  /// ID1 — kart başka bir kayda bağlanınca açık düzenleme o kayda ait değildir.
  group('TitleCard rebound to a different title', () {
    testWidgets('closes the open edit form instead of keeping stale text',
        (tester) async {
      final hostKey = GlobalKey<_SwappableTitleHostState>();
      await tester.pumpWidget(
        host(
          state: stateWith(const [alpha, beta]),
          child: _SwappableTitleHost(
            key: hostKey,
            initial: alpha,
            width: 520,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edit title'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title name'),
        'STALE EDIT',
      );
      await tester.pump();
      expect(find.text('STALE EDIT'), findsOneWidget);

      // Üstteki bir ünvan silindi / sıra değişti: aynı slot artık başka kayıt.
      hostKey.currentState!.swap(beta);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilledButton, 'Save'),
        findsNothing,
        reason: 'yanlış kayda yazabilecek düzenleme formu açık kalmamalı',
      );
      expect(find.text('STALE EDIT'), findsNothing);
      expect(find.text('Talebe'), findsOneWidget);
    });

    testWidgets('a stale edit can no longer be saved over the new title',
        (tester) async {
      late ProviderContainer container;
      final hostKey = GlobalKey<_SwappableTitleHostState>();
      await tester.pumpWidget(
        host(
          state: stateWith(const [alpha, beta]),
          onContainer: (c) => container = c,
          child: _SwappableTitleHost(
            key: hostKey,
            initial: alpha,
            width: 520,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Edit title'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title name'),
        'STALE EDIT',
      );
      hostKey.currentState!.swap(beta);
      await tester.pumpAndSettle();

      // Save butonu yoksa tıklanamaz; state hiç kirlenmemeli.
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(
        container.read(feedbackContentProvider).titles.map((t) => t.title),
        ['İlim Yolcusu', 'Talebe'],
      );
    });
  });

  /// ID4a — "Ünvan Ekle" boş bir kayıt yaratıyordu ama kart düzenleme modunda
  /// açılmıyordu; kullanıcı hiçbir şey olmamış sanıp bırakınca boş ünvan diske
  /// yazılıyordu.
  group('TitleCard for a freshly added empty title', () {
    testWidgets('opens directly in edit mode', (tester) async {
      await tester.pumpWidget(
        host(
          state: stateWith(const [
            alpha,
            PlayerTitleModel(
              title: '',
              icon: '🌟',
              requiredBooks: 5,
              profileImage: '',
            ),
          ]),
          child: const Scaffold(
            body: SizedBox(
              width: 520,
              child: TitleCard(
                title: PlayerTitleModel(
                  title: '',
                  icon: '🌟',
                  requiredBooks: 5,
                  profileImage: '',
                ),
                index: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Title name'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      expect(find.text('(Untitled)'), findsNothing);
    });

    testWidgets('Cancel removes the empty title from the list',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        host(
          state: stateWith(const [
            alpha,
            PlayerTitleModel(
              title: '',
              icon: '🌟',
              requiredBooks: 5,
              profileImage: '',
            ),
          ]),
          onContainer: (c) => container = c,
          child: const Scaffold(
            body: SizedBox(
              width: 520,
              child: TitleCard(
                title: PlayerTitleModel(
                  title: '',
                  icon: '🌟',
                  requiredBooks: 5,
                  profileImage: '',
                ),
                index: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(
        container.read(feedbackContentProvider).titles,
        [alpha],
        reason: 'iptal edilen boş ünvan listede kalmamalı',
      );
    });

    testWidgets('an existing named title still opens in display mode',
        (tester) async {
      await tester.pumpWidget(
        host(
          state: stateWith(const [alpha]),
          child: const Scaffold(
            body: SizedBox(
              width: 520,
              child: TitleCard(title: alpha, index: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(find.text('İlim Yolcusu'), findsOneWidget);
    });
  });

  /// ID19 — duplicate uyarısı tek satıra kırpılıyordu, kullanıcı hangi değerin
  /// çakıştığını okuyamıyordu.
  testWidgets('duplicate required-books error is not clipped to one line',
      (tester) async {
    await tester.pumpWidget(
      host(
        state: stateWith(const [alpha, beta]),
        child: const Scaffold(
          body: SizedBox(
            width: 340,
            child: TitleCard(title: alpha, index: 0),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit title'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Required books'),
      '3', // beta ile çakışıyor
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final errorFinder = find.textContaining('already used by another title');
    expect(errorFinder, findsOneWidget);

    final paragraph = tester.renderObject<RenderParagraph>(errorFinder);
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'hata mesajı kesilmemeli, sarmalanmalı',
    );
    final lineBoxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: paragraph.text.toPlainText().length),
    );
    expect(lineBoxes.length, greaterThan(1),
        reason: 'dar kartta mesaj gerçekten birden fazla satıra sığıyor olmalı');
  });

  /// ID23 — admin arayüzü İngilizce (CLAUDE.md kuralı, app_shell_test ile aynı).
  testWidgets('TitleCard chrome is English', (tester) async {
    await tester.pumpWidget(
      host(
        state: stateWith(const [alpha, beta]),
        child: const Scaffold(
          body: SizedBox(
            width: 520,
            child: TitleCard(title: alpha, index: 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Required books:'), findsOneWidget);
    for (final turkish in ['Gerekli Kitap: 0', 'Düzenle', 'Önizleme', 'Sil']) {
      expect(find.text(turkish), findsNothing, reason: '$turkish Türkçe kaldı');
    }

    await tester.tap(find.byTooltip('Edit title'));
    await tester.pumpAndSettle();

    for (final label in [
      'Title name',
      'Icon / emoji',
      'Required books',
      'Profile image path',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final turkish in [
      'Ünvan Adı',
      'İkon / Emoji',
      'Gerekli Kitap Sayısı',
      'Profil Görseli Yolu',
      'Kaydet',
      'İptal',
    ]) {
      expect(find.text(turkish), findsNothing, reason: '$turkish Türkçe kaldı');
    }
  });
}
