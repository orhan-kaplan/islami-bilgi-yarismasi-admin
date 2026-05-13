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
    return FeedbackContentState(
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
      expect(find.text('Başlık'), findsOneWidget);
      expect(find.text('Mesaj'), findsOneWidget);
      expect(find.text('Emoji:'), findsOneWidget);
      // Should show save and cancel buttons
      expect(find.text('Kaydet'), findsOneWidget);
      expect(find.text('İptal'), findsOneWidget);
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
}
