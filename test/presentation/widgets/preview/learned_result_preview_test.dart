import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/learned_result_preview.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/preview_tokens.dart';
import 'package:lottie/lottie.dart';

void main() {
  /// Wraps [LearnedQuizResultPreview] in a minimal [MaterialApp] for testing.
  Widget createTestWidget({
    required FeedbackMessageModel message,
    String? subcategory,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 500,
          height: 900,
          child: LearnedQuizResultPreview(
            message: message,
            subcategory: subcategory,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Validates: Gereksinimler 4.4, 4.5
  // Her yüzdelik dilim için vurgu rengi doğrulaması
  // ══════════════════════════════════════════════════════════════════════════

  group('LearnedQuizResultPreview — Vurgu rengi doğrulaması', () {
    const baseMessage = FeedbackMessageModel(
      title: 'Tebrikler!',
      message: 'Harika bir performans.',
      emoji: '🎉',
    );

    testWidgets('100% → gold accent color (learnedFeedbackGold)',
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        message: baseMessage,
        subcategory: '100',
      ));

      // Title should use gold accent color
      final titleFinder = find.text('Tebrikler!');
      expect(titleFinder, findsOneWidget);
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.color, PreviewTokens.learnedFeedbackGold);

      // Percentage text should show %100 in gold
      final percentFinder = find.text('%100');
      expect(percentFinder, findsOneWidget);
      final percentWidget = tester.widget<Text>(percentFinder);
      expect(percentWidget.style?.color, PreviewTokens.learnedFeedbackGold);
      expect(percentWidget.style?.fontSize, 48);
      expect(percentWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('75% → green accent color (learnedFeedbackGreen)',
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        message: baseMessage,
        subcategory: '75',
      ));

      final titleWidget = tester.widget<Text>(find.text('Tebrikler!'));
      expect(titleWidget.style?.color, PreviewTokens.learnedFeedbackGreen);

      final percentFinder = find.text('%75');
      expect(percentFinder, findsOneWidget);
      final percentWidget = tester.widget<Text>(percentFinder);
      expect(percentWidget.style?.color, PreviewTokens.learnedFeedbackGreen);
    });

    testWidgets('50% → blue accent color (learnedFeedbackBlue)',
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        message: baseMessage,
        subcategory: '50',
      ));

      final titleWidget = tester.widget<Text>(find.text('Tebrikler!'));
      expect(titleWidget.style?.color, PreviewTokens.learnedFeedbackBlue);

      final percentFinder = find.text('%50');
      expect(percentFinder, findsOneWidget);
      final percentWidget = tester.widget<Text>(percentFinder);
      expect(percentWidget.style?.color, PreviewTokens.learnedFeedbackBlue);
    });

    testWidgets('25% → orange accent color (learnedFeedbackOrange)',
        (tester) async {
      await tester.pumpWidget(createTestWidget(
        message: baseMessage,
        subcategory: '25',
      ));

      final titleWidget = tester.widget<Text>(find.text('Tebrikler!'));
      expect(titleWidget.style?.color, PreviewTokens.learnedFeedbackOrange);

      final percentFinder = find.text('%25');
      expect(percentFinder, findsOneWidget);
      final percentWidget = tester.widget<Text>(percentFinder);
      expect(percentWidget.style?.color, PreviewTokens.learnedFeedbackOrange);
    });

    testWidgets('0% → red accent color (learnedFeedbackRed)', (tester) async {
      await tester.pumpWidget(createTestWidget(
        message: baseMessage,
        subcategory: '0',
      ));

      final titleWidget = tester.widget<Text>(find.text('Tebrikler!'));
      expect(titleWidget.style?.color, PreviewTokens.learnedFeedbackRed);

      final percentFinder = find.text('%0');
      expect(percentFinder, findsOneWidget);
      final percentWidget = tester.widget<Text>(percentFinder);
      expect(percentWidget.style?.color, PreviewTokens.learnedFeedbackRed);
    });

    testWidgets('unknown subcategory defaults to 50% → blue', (tester) async {
      await tester.pumpWidget(createTestWidget(
        message: baseMessage,
        subcategory: 'unknown',
      ));

      final titleWidget = tester.widget<Text>(find.text('Tebrikler!'));
      expect(titleWidget.style?.color, PreviewTokens.learnedFeedbackBlue);

      // Default percentage is 50
      final percentFinder = find.text('%50');
      expect(percentFinder, findsOneWidget);
    });

    testWidgets('null subcategory defaults to 50% → blue', (tester) async {
      await tester.pumpWidget(createTestWidget(
        message: baseMessage,
        subcategory: null,
      ));

      final titleWidget = tester.widget<Text>(find.text('Tebrikler!'));
      expect(titleWidget.style?.color, PreviewTokens.learnedFeedbackBlue);

      final percentFinder = find.text('%50');
      expect(percentFinder, findsOneWidget);
    });

    testWidgets('stat boxes use accent color for values', (tester) async {
      await tester.pumpWidget(createTestWidget(
        message: baseMessage,
        subcategory: '100',
      ));

      // Stat box values should use the accent color
      final statValue = find.text('10');
      expect(statValue, findsOneWidget);
      final statWidget = tester.widget<Text>(statValue);
      expect(statWidget.style?.color, PreviewTokens.learnedFeedbackGold);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Validates: Gereksinim 4.7
  // shouldRepeat davranışı testi
  // ══════════════════════════════════════════════════════════════════════════

  group('LearnedQuizResultPreview — shouldRepeat davranışı', () {
    testWidgets('Lottie repeats when shouldRepeat is true', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Harika!',
        message: 'Devam et.',
        emoji: '🎉',
        lottieAsset: 'feedback/learned_success.json',
        shouldRepeat: true,
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: '100',
      ));

      // Lottie widget should be present
      final lottieFinder = find.byType(Lottie);
      expect(lottieFinder, findsOneWidget);

      // Verify the Lottie widget has repeat enabled
      final lottieWidget = tester.widget<Lottie>(lottieFinder);
      expect(lottieWidget.repeat, isTrue);
    });

    testWidgets('Lottie does not repeat when shouldRepeat is false',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'İyi!',
        message: 'Fena değil.',
        emoji: '👍',
        lottieAsset: 'feedback/learned_ok.json',
        shouldRepeat: false,
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: '50',
      ));

      final lottieFinder = find.byType(Lottie);
      expect(lottieFinder, findsOneWidget);

      final lottieWidget = tester.widget<Lottie>(lottieFinder);
      expect(lottieWidget.repeat, isFalse);
    });

    testWidgets('shows emoji placeholder when no lottieAsset', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Test',
        message: 'Test mesaj',
        emoji: '📚',
        shouldRepeat: true,
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: '75',
      ));

      // No Lottie widget, emoji placeholder instead
      expect(find.byType(Lottie), findsNothing);
      expect(find.text('📚'), findsOneWidget);
    });

    testWidgets('shows default emoji when emoji is empty and no lottieAsset',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Test',
        message: 'Test mesaj',
        emoji: '',
        shouldRepeat: false,
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: '50',
      ));

      // Default emoji placeholder
      expect(find.text('📚'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Validates: Gereksinim 8.3
  // Boş alan placeholder gösterimi testi
  // ══════════════════════════════════════════════════════════════════════════

  group('LearnedQuizResultPreview — Boş alan placeholder gösterimi', () {
    testWidgets('shows title placeholder when title is empty', (tester) async {
      const message = FeedbackMessageModel(
        title: '',
        message: 'Mesaj var.',
        emoji: '📝',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: '75',
      ));

      final placeholderFinder = find.text('(Başlık girilmemiş)');
      expect(placeholderFinder, findsOneWidget);

      final placeholderWidget = tester.widget<Text>(placeholderFinder);
      expect(placeholderWidget.style?.fontStyle, FontStyle.italic);
      expect(placeholderWidget.style?.color, const Color(0x80FFFFFF));
      expect(placeholderWidget.style?.fontFamily, 'PlayfairDisplay');
      expect(placeholderWidget.style?.fontSize, 32);
      expect(placeholderWidget.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('shows message placeholder when message is empty',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Başlık var',
        message: '',
        emoji: '📝',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: '50',
      ));

      final placeholderFinder = find.text('(Mesaj girilmemiş)');
      expect(placeholderFinder, findsOneWidget);

      final placeholderWidget = tester.widget<Text>(placeholderFinder);
      expect(placeholderWidget.style?.fontStyle, FontStyle.italic);
      expect(placeholderWidget.style?.color, const Color(0x80FFFFFF));
      expect(placeholderWidget.style?.fontFamily, 'Nunito');
      expect(placeholderWidget.style?.fontSize, 16);
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
        subcategory: '25',
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
        subcategory: '100',
      ));

      expect(find.text('(Başlık girilmemiş)'), findsNothing);
      expect(find.text('(Mesaj girilmemiş)'), findsNothing);
      expect(find.text('Gerçek Başlık'), findsOneWidget);
      expect(find.text('Gerçek Mesaj'), findsOneWidget);
    });

    testWidgets('title uses accent color when not empty', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Başarılı!',
        message: 'Devam et.',
        emoji: '🎉',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: '100',
      ));

      final titleWidget = tester.widget<Text>(find.text('Başarılı!'));
      expect(titleWidget.style?.color, PreviewTokens.learnedFeedbackGold);
      expect(titleWidget.style?.fontStyle, isNot(FontStyle.italic));
    });

    testWidgets('subtitle uses textSecondary color when not empty',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Başlık',
        message: 'Alt başlık mesajı',
        emoji: '📚',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        subcategory: '75',
      ));

      final subtitleWidget = tester.widget<Text>(find.text('Alt başlık mesajı'));
      expect(subtitleWidget.style?.color, PreviewTokens.textSecondary);
      expect(subtitleWidget.style?.fontFamily, 'Nunito');
      expect(subtitleWidget.style?.fontSize, 16);
    });
  });
}
