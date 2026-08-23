import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/feedback_card.dart';

void main() {
  /// Creates a minimal state for the provider override.
  FeedbackContentState createMinimalState() {
    const msg = FeedbackMessageModel(
      title: 'Test',
      message: 'Test mesajı',
      emoji: '📝',
    );
    return const FeedbackContentState(
      quiz: {
        'perfect': [msg],
      },
      speedQuiz: {},
      time: {},
      comeback: [msg],
      streak: {},
      titles: [],
      learned: {},
    );
  }

  /// Wraps a [FeedbackCard] in a [MaterialApp] with [ProviderScope].
  Widget createTestWidget(FeedbackMessageModel message, {
    String category = 'comeback',
    String? subcategory,
    int index = 0,
    VoidCallback? onDelete,
  }) {
    return ProviderScope(
      overrides: [
        feedbackContentProvider.overrideWith(
          (ref) => FeedbackContentNotifier(createMinimalState()),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeedbackCard(
              message: message,
              index: index,
              category: category,
              subcategory: subcategory,
              onDelete: onDelete,
            ),
          ),
        ),
      ),
    );
  }

  group('FeedbackCard', () {
    testWidgets('displays title, message, and emoji', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Harika İş!',
        message: 'Çok güzel bir performans gösterdin.',
        emoji: '🌟',
      );

      await tester.pumpWidget(createTestWidget(message));
      await tester.pumpAndSettle();

      expect(find.text('Harika İş!'), findsOneWidget);
      expect(find.text('Çok güzel bir performans gösterdin.'), findsOneWidget);
      expect(find.textContaining('🌟'), findsWidgets);
    });

    testWidgets('shows edit and delete buttons', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Test',
        message: 'Mesaj',
        emoji: '📝',
      );

      await tester.pumpWidget(createTestWidget(message));
      await tester.pumpAndSettle();

      // Find edit button by icon
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      // Find delete button by icon
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('shows placeholder when no Lottie assigned', (tester) async {
      const message = FeedbackMessageModel(
        title: 'No Lottie',
        message: 'Bu mesajda lottie yok.',
        emoji: '📝',
        lottieAsset: null,
      );

      await tester.pumpWidget(createTestWidget(message));
      await tester.pumpAndSettle();

      // When no lottie and emoji is present, the emoji is shown as placeholder
      // The placeholder container should exist (64x64 container)
      expect(find.text('📝'), findsWidgets);
    });

    testWidgets('shows placeholder icon when no Lottie and empty emoji',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'No Lottie No Emoji',
        message: 'Boş mesaj.',
        emoji: '',
        lottieAsset: null,
      );

      await tester.pumpWidget(createTestWidget(message));
      await tester.pumpAndSettle();

      // When no lottie and no emoji, shows animation_outlined icon
      expect(find.byIcon(Icons.animation_outlined), findsOneWidget);
    });

    testWidgets('shows Lottie path text when lottieAsset is set',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'With Lottie',
        message: 'Bu mesajda lottie var.',
        emoji: '🎉',
        lottieAsset: 'feedback/celebration.json',
      );

      await tester.pumpWidget(createTestWidget(message));
      await tester.pumpAndSettle();

      // Should show the lottie path in metadata
      expect(
          find.textContaining('feedback/celebration.json'), findsOneWidget);
    });

    testWidgets('delete button calls onDelete callback', (tester) async {
      var deleteCalled = false;
      const message = FeedbackMessageModel(
        title: 'Delete Test',
        message: 'Silinecek mesaj.',
        emoji: '🗑️',
      );

      await tester.pumpWidget(createTestWidget(
        message,
        onDelete: () => deleteCalled = true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(deleteCalled, true);
    });

    testWidgets('edit button enters edit mode', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Edit Test',
        message: 'Düzenlenecek mesaj.',
        emoji: '✏️',
      );

      await tester.pumpWidget(createTestWidget(message));
      await tester.pumpAndSettle();

      // Tap edit button
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // In edit mode, should show text fields with labels
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Emoji:'), findsOneWidget);
      // Should show save and cancel buttons
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // Admin arayüzü İngilizce (CLAUDE.md); Türkçe kopya kalmamalı.
      for (final turkish in ['Başlık', 'Mesaj', 'Kaydet', 'İptal']) {
        expect(find.text(turkish), findsNothing,
            reason: '$turkish Türkçe kaldı');
      }
    });

    testWidgets('shows repeat icon based on shouldRepeat', (tester) async {
      const messageRepeat = FeedbackMessageModel(
        title: 'Repeat',
        message: 'Tekrarlı.',
        emoji: '🔄',
        shouldRepeat: true,
      );

      await tester.pumpWidget(createTestWidget(messageRepeat));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.repeat), findsOneWidget);
    });

    testWidgets('shows repeat_one icon when shouldRepeat is false',
        (tester) async {
      const messageNoRepeat = FeedbackMessageModel(
        title: 'No Repeat',
        message: 'Tekrarsız.',
        emoji: '1️⃣',
        shouldRepeat: false,
      );

      await tester.pumpWidget(createTestWidget(messageNoRepeat));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.repeat_one), findsOneWidget);
    });
  });

  /// ID1 — kart başka bir mesaja bağlanınca açık düzenleme o mesaja ait
  /// değildir: silme / sürükleme index'leri kaydırdığında Kaydet yanlış kaydın
  /// üzerine yazıyordu.
  group('FeedbackCard rebound to a different message', () {
    testWidgets('closes the open edit form instead of keeping stale text',
        (tester) async {
      final hostKey = GlobalKey<_SwappableMessageHostState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackContentProvider.overrideWith(
              (ref) => FeedbackContentNotifier(createMinimalState()),
            ),
          ],
          child: MaterialApp(
            home: _SwappableMessageHost(
              key: hostKey,
              initial: const FeedbackMessageModel(
                title: 'Alpha',
                message: 'Alpha mesajı',
                emoji: '🅰️',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'STALE EDIT',
      );
      await tester.pump();
      expect(find.text('STALE EDIT'), findsOneWidget);

      hostKey.currentState!.swap(
        const FeedbackMessageModel(
          title: 'Beta',
          message: 'Beta mesajı',
          emoji: '🅱️',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilledButton, 'Save'),
        findsNothing,
        reason: 'yanlış kayda yazabilecek düzenleme formu açık kalmamalı',
      );
      expect(find.text('STALE EDIT'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('a stale edit cannot be written over the new message',
        (tester) async {
      late ProviderContainer container;
      final hostKey = GlobalKey<_SwappableMessageHostState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackContentProvider.overrideWith(
              (ref) => FeedbackContentNotifier(createMinimalState()),
            ),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: _SwappableMessageHost(
                  key: hostKey,
                  initial: const FeedbackMessageModel(
                    title: 'Alpha',
                    message: 'Alpha mesajı',
                    emoji: '🅰️',
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'STALE EDIT',
      );
      hostKey.currentState!.swap(
        const FeedbackMessageModel(
          title: 'Beta',
          message: 'Beta mesajı',
          emoji: '🅱️',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
      expect(
        container.read(feedbackContentProvider).comeback.single.title,
        'Test',
        reason: 'bayat düzenleme hiçbir kaydı kirletmemeli',
      );
    });
  });

  /// ID3 — düzenleme modundaki Lottie değişikliği anında state'e yazılıyordu;
  /// "İptal" değişikliği geri almıyor, kullanıcıya iptal ettiğini söyleyip
  /// dosyaya yeni değeri yazıyordu.
  group('Lottie edits inside edit mode respect Save / Cancel', () {
    const withLottie = FeedbackMessageModel(
      title: 'Lottie Test',
      message: 'Lottie mesajı',
      emoji: '🎬',
      lottieAsset: 'feedback/celebration.json',
    );

    FeedbackContentState stateWithLottie() => const FeedbackContentState(
          quiz: {},
          speedQuiz: {},
          time: {},
          comeback: [withLottie],
          streak: {},
          titles: [],
          learned: {},
        );

    Future<ProviderContainer> pumpCard(WidgetTester tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackContentProvider.overrideWith(
              (ref) => FeedbackContentNotifier(stateWithLottie()),
            ),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: FeedbackCard(
                      message: withLottie,
                      index: 0,
                      category: 'comeback',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('Cancel keeps the original Lottie', (tester) async {
      final container = await pumpCard(tester);

      await tester.tap(find.byTooltip('Remove Lottie'));
      await tester.pumpAndSettle();
      expect(find.text('No Lottie assigned'), findsOneWidget,
          reason: 'kaldırma düzenleme formunda görünmeli');

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(
        container.read(feedbackContentProvider).comeback.single.lottieAsset,
        'feedback/celebration.json',
        reason: 'İptal Lottie kaldırmasını geri almalı',
      );
    });

    testWidgets('Save applies the staged Lottie removal', (tester) async {
      final container = await pumpCard(tester);

      await tester.tap(find.byTooltip('Remove Lottie'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        container.read(feedbackContentProvider).comeback.single.lottieAsset,
        isNull,
      );
    });

    testWidgets('removal is not written to state before Save', (tester) async {
      final container = await pumpCard(tester);

      await tester.tap(find.byTooltip('Remove Lottie'));
      await tester.pumpAndSettle();

      expect(
        container.read(feedbackContentProvider).comeback.single.lottieAsset,
        'feedback/celebration.json',
        reason: 'kaydedilmeden state kirlenmemeli',
      );
    });
  });
}

/// Aynı slottaki kartı dışarıdan başka bir mesaja bağlar — silme ve sürükleme
/// gerçek ekranda tam olarak bunu yapıyor.
class _SwappableMessageHost extends StatefulWidget {
  const _SwappableMessageHost({super.key, required this.initial});

  final FeedbackMessageModel initial;

  @override
  State<_SwappableMessageHost> createState() => _SwappableMessageHostState();
}

class _SwappableMessageHostState extends State<_SwappableMessageHost> {
  late FeedbackMessageModel _message = widget.initial;

  void swap(FeedbackMessageModel next) => setState(() => _message = next);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: FeedbackCard(
          message: _message,
          index: 0,
          category: 'comeback',
        ),
      ),
    );
  }
}
