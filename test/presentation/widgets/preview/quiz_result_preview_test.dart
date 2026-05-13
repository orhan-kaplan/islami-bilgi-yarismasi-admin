import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/preview_tokens.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/quiz_result_preview.dart';
import 'package:lottie/lottie.dart';

void main() {
  /// Wraps [QuizResultPreview] in a minimal [MaterialApp] for testing.
  Widget createTestWidget({
    required FeedbackMessageModel message,
    String? subcategory,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 500,
          height: 900,
          child: QuizResultPreview(
            message: message,
            subcategory: subcategory,
          ),
        ),
      ),
    );
  }

  group('QuizResultPreview — Başarılı durum render doğrulaması', () {
    testWidgets('renders title in white for success category', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Tebrikler!',
        message: 'Harika bir performans gösterdin.',
        emoji: '🏆',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      final titleFinder = find.text('Tebrikler!');
      expect(titleFinder, findsOneWidget);

      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.color, Colors.white);
      expect(titleWidget.style?.fontFamily, 'PlayfairDisplay');
      expect(titleWidget.style?.fontSize, 28);
      expect(titleWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('renders message text with correct style', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Tebrikler!',
        message: 'Harika bir performans gösterdin.',
        emoji: '🏆',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      final messageFinder = find.text('Harika bir performans gösterdin.');
      expect(messageFinder, findsOneWidget);

      final messageWidget = tester.widget<Text>(messageFinder);
      expect(messageWidget.style?.fontFamily, 'Nunito');
      expect(messageWidget.style?.fontSize, 14);
      expect(messageWidget.style?.color, const Color(0xFFB0B0B0));
      expect(messageWidget.style?.height, 1.4);
    });

    testWidgets('shows only Devam Et button for success', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Tebrikler!',
        message: 'Harika!',
        emoji: '🏆',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      expect(find.text('Devam Et'), findsOneWidget);
      expect(find.text('Tekrar Dene'), findsNothing);
    });

    testWidgets('shows emoji placeholder when no lottieAsset', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Tebrikler!',
        message: 'Harika!',
        emoji: '🎉',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      // Should show the emoji as placeholder
      expect(find.text('🎉'), findsOneWidget);
    });
  });

  group('QuizResultPreview — Başarısız durum render doğrulaması', () {
    testWidgets('renders title in gold color for failure category',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Üzülme!',
        message: 'Bir dahaki sefere daha iyi olacak.',
        emoji: '😔',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'failure',
      ));

      final titleFinder = find.text('Üzülme!');
      expect(titleFinder, findsOneWidget);

      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.color, PreviewTokens.goldStart);
      expect(titleWidget.style?.fontFamily, 'PlayfairDisplay');
      expect(titleWidget.style?.fontSize, 28);
      expect(titleWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('shows both Tekrar Dene and Devam Et buttons for failure',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Üzülme!',
        message: 'Tekrar dene.',
        emoji: '😔',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'failure',
      ));

      expect(find.text('Tekrar Dene'), findsOneWidget);
      expect(find.text('Devam Et'), findsOneWidget);
    });
  });

  group('QuizResultPreview — Boş alan placeholder gösterimi', () {
    testWidgets('shows placeholder when title is empty', (tester) async {
      const message = FeedbackMessageModel(
        title: '',
        message: 'Mesaj var.',
        emoji: '📝',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      final placeholderFinder = find.text('(Başlık girilmemiş)');
      expect(placeholderFinder, findsOneWidget);

      final placeholderWidget = tester.widget<Text>(placeholderFinder);
      expect(placeholderWidget.style?.fontStyle, FontStyle.italic);
      expect(placeholderWidget.style?.color, const Color(0x80FFFFFF));
    });

    testWidgets('shows placeholder when message is empty', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Başlık var',
        message: '',
        emoji: '📝',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      final placeholderFinder = find.text('(Mesaj girilmemiş)');
      expect(placeholderFinder, findsOneWidget);

      final placeholderWidget = tester.widget<Text>(placeholderFinder);
      expect(placeholderWidget.style?.fontStyle, FontStyle.italic);
      expect(placeholderWidget.style?.color, const Color(0x80FFFFFF));
    });

    testWidgets('shows both placeholders when title and message are empty',
        (tester) async {
      const message = FeedbackMessageModel(
        title: '',
        message: '',
        emoji: '📝',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      expect(find.text('(Başlık girilmemiş)'), findsOneWidget);
      expect(find.text('(Mesaj girilmemiş)'), findsOneWidget);
    });

    testWidgets('does NOT show placeholders when fields are filled',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Gerçek Başlık',
        message: 'Gerçek Mesaj',
        emoji: '🏆',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      expect(find.text('(Başlık girilmemiş)'), findsNothing);
      expect(find.text('(Mesaj girilmemiş)'), findsNothing);
      expect(find.text('Gerçek Başlık'), findsOneWidget);
      expect(find.text('Gerçek Mesaj'), findsOneWidget);
    });
  });

  group('QuizResultPreview — Lottie hata durumu fallback davranışı', () {
    testWidgets('renders Lottie.network when lottieAsset is provided',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Tebrikler!',
        message: 'Harika!',
        emoji: '🎉',
        lottieAsset: 'feedback/masallah.json',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      // Lottie widget should be present
      expect(find.byType(Lottie), findsOneWidget);
    });

    testWidgets(
        'shows error fallback with emoji and red filename on Lottie error',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Tebrikler!',
        message: 'Harika!',
        emoji: '🎉',
        lottieAsset: 'feedback/masallah.json',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      // Pump to allow Lottie.network to attempt loading and fail
      // Since there's no real server, the error builder should trigger
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // After error, should show emoji placeholder
      expect(find.text('🎉'), findsOneWidget);

      // Should show filename in red
      final filenameFinder = find.text('feedback/masallah.json');
      expect(filenameFinder, findsOneWidget);

      final filenameWidget = tester.widget<Text>(filenameFinder);
      expect(filenameWidget.style?.color, Colors.red);
      expect(filenameWidget.style?.fontSize, 10);
    });

    testWidgets('shows warning emoji when emoji field is empty on Lottie error',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Test',
        message: 'Test mesaj',
        emoji: '',
        lottieAsset: 'feedback/test.json',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // When emoji is empty, should show ⚠️ as fallback
      expect(find.text('⚠️'), findsOneWidget);
    });

    testWidgets('shows default trophy emoji when no lottieAsset and emoji empty',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Test',
        message: 'Test mesaj',
        emoji: '',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: 'perfect',
      ));

      // Default trophy emoji when no lottie and empty emoji
      expect(find.text('🏆'), findsOneWidget);
    });
  });
}
