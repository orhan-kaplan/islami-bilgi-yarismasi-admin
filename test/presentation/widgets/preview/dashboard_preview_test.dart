import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/dashboard_preview.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/preview_tokens.dart';

void main() {
  /// Wraps [DashboardPreview] in a minimal [MaterialApp] for testing.
  Widget createTestWidget({
    required FeedbackMessageModel message,
    required String category,
    String? subcategory,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 900,
          child: DashboardPreview(
            message: message,
            category: category,
            subcategory: subcategory,
          ),
        ),
      ),
    );
  }

  group('DashboardPreview — time kategorisi render doğrulaması', () {
    /// Validates: Gereksinimler 3.3
    testWidgets('renders greeting text "Esselamü Aleyküm,"', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Seher Bülbülü',
        message: '',
        emoji: '🌅',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'time',
      ));

      final greetingFinder = find.text('Esselamü Aleyküm,');
      expect(greetingFinder, findsOneWidget);

      final greetingWidget = tester.widget<Text>(greetingFinder);
      expect(greetingWidget.style?.fontFamily, 'Nunito');
      expect(greetingWidget.style?.fontSize, 13);
      expect(greetingWidget.style?.fontWeight, FontWeight.w500);
      expect(greetingWidget.style?.letterSpacing, 0.2);
    });

    testWidgets('renders title + " Ahmet" for time category', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Seher Bülbülü',
        message: '',
        emoji: '🌅',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'time',
      ));

      final titleFinder = find.text('Seher Bülbülü Ahmet');
      expect(titleFinder, findsOneWidget);

      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.fontFamily, 'Nunito');
      expect(titleWidget.style?.fontSize, 20);
      expect(titleWidget.style?.fontWeight, FontWeight.w800);
      expect(titleWidget.style?.color, Colors.white);
    });

    testWidgets('renders profile avatar with gold border', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Seher Bülbülü',
        message: '',
        emoji: '🌅',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'time',
      ));

      // Find the 68x68 avatar container with gold border
      final avatarContainer = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          if (decoration.shape == BoxShape.circle && decoration.border != null) {
            final border = decoration.border as Border;
            return border.top.color == PreviewTokens.goldStart &&
                border.top.width == 3;
          }
        }
        return false;
      });
      expect(avatarContainer, findsOneWidget);

      // Verify the container is 68x68
      final box = tester.getSize(avatarContainer);
      expect(box.width, 68);
      expect(box.height, 68);
    });

    testWidgets('renders rank chip with gold gradient', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Seher Bülbülü',
        message: '',
        emoji: '🌅',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'time',
      ));

      // Find the rank chip text
      final chipFinder = find.text('🏅 Hafız Adayı');
      expect(chipFinder, findsOneWidget);

      final chipWidget = tester.widget<Text>(chipFinder);
      expect(chipWidget.style?.fontFamily, 'PlayfairDisplay');
      expect(chipWidget.style?.fontSize, 13);
      expect(chipWidget.style?.color, PreviewTokens.goldOnColor);
    });
  });

  group('DashboardPreview — comeback kategorisi render doğrulaması', () {
    /// Validates: Gereksinimler 3.4
    testWidgets('renders comeback dialog with dark green background',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Hoş Geldin!',
        message: 'Seni özledik, tekrar hoş geldin.',
        emoji: '👋',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'comeback',
      ));

      // Find the comeback dialog container with comebackBg color (#1B5E20)
      final dialogContainer = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final decoration = widget.decoration as BoxDecoration;
          return decoration.color == PreviewTokens.comebackBg &&
              decoration.borderRadius == BorderRadius.circular(24);
        }
        return false;
      });
      expect(dialogContainer, findsOneWidget);
    });

    testWidgets('renders emoji at 48px font size', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Hoş Geldin!',
        message: 'Seni özledik.',
        emoji: '👋',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'comeback',
      ));

      final emojiFinder = find.text('👋');
      expect(emojiFinder, findsOneWidget);

      final emojiWidget = tester.widget<Text>(emojiFinder);
      expect(emojiWidget.style?.fontSize, 48);
    });

    testWidgets('renders title with PlayfairDisplay 22px bold white',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Hoş Geldin!',
        message: 'Seni özledik.',
        emoji: '👋',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'comeback',
      ));

      final titleFinder = find.text('Hoş Geldin!');
      expect(titleFinder, findsOneWidget);

      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.style?.fontFamily, 'PlayfairDisplay');
      expect(titleWidget.style?.fontSize, 22);
      expect(titleWidget.style?.fontWeight, FontWeight.bold);
      expect(titleWidget.style?.color, Colors.white);
    });

    testWidgets('renders message with Nunito 16px', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Hoş Geldin!',
        message: 'Seni özledik, tekrar hoş geldin.',
        emoji: '👋',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'comeback',
      ));

      final messageFinder = find.text('Seni özledik, tekrar hoş geldin.');
      expect(messageFinder, findsOneWidget);

      final messageWidget = tester.widget<Text>(messageFinder);
      expect(messageWidget.style?.fontFamily, 'Nunito');
      expect(messageWidget.style?.fontSize, 16);
    });

    testWidgets('renders "DEVAM ET" button', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Hoş Geldin!',
        message: 'Seni özledik.',
        emoji: '👋',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'comeback',
      ));

      expect(find.text('DEVAM ET'), findsOneWidget);
    });

    testWidgets('uses default emoji when emoji field is empty', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Hoş Geldin!',
        message: 'Seni özledik.',
        emoji: '',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'comeback',
      ));

      // Default emoji is 👋 when empty
      final emojiFinder = find.text('👋');
      expect(emojiFinder, findsOneWidget);
    });
  });

  group('DashboardPreview — streak kategorisi render doğrulaması', () {
    /// Validates: Gereksinimler 3.5
    testWidgets('renders flame icon in streak card', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Harika Seri!',
        message: 'Devam et!',
        emoji: '🔥',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'streak',
        subcategory: '7',
      ));

      // Find the flame icon
      final flameIcon = find.byIcon(Icons.local_fire_department);
      expect(flameIcon, findsOneWidget);

      final iconWidget = tester.widget<Icon>(flameIcon);
      expect(iconWidget.color, Colors.orange);
      expect(iconWidget.size, 40);
    });

    testWidgets('renders streak number from subcategory', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Harika Seri!',
        message: 'Devam et!',
        emoji: '🔥',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'streak',
        subcategory: '14',
      ));

      final numberFinder = find.text('14');
      expect(numberFinder, findsOneWidget);

      final numberWidget = tester.widget<Text>(numberFinder);
      expect(numberWidget.style?.fontFamily, 'Nunito');
      expect(numberWidget.style?.fontSize, 36);
      expect(numberWidget.style?.fontWeight, FontWeight.bold);
      expect(numberWidget.style?.color, Colors.white);
    });

    testWidgets('renders "Gün Serisi" label', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Harika Seri!',
        message: 'Devam et!',
        emoji: '🔥',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'streak',
        subcategory: '7',
      ));

      expect(find.text('Gün Serisi'), findsOneWidget);
    });

    testWidgets('uses default "7" when subcategory is null', (tester) async {
      const message = FeedbackMessageModel(
        title: 'Harika Seri!',
        message: 'Devam et!',
        emoji: '🔥',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'streak',
      ));

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('renders streak message title and message when provided',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Harika Seri!',
        message: 'Devam et, çok iyi gidiyorsun!',
        emoji: '🔥',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'streak',
        subcategory: '7',
      ));

      expect(find.text('Harika Seri!'), findsOneWidget);
      expect(find.text('Devam et, çok iyi gidiyorsun!'), findsOneWidget);
    });
  });

  group('DashboardPreview — Boş alan placeholder gösterimi', () {
    /// Validates: Gereksinimler 8.3
    testWidgets(
        'shows placeholder "(Başlık girilmemiş)" for time category when title is empty',
        (tester) async {
      const message = FeedbackMessageModel(
        title: '',
        message: '',
        emoji: '🌅',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'time',
      ));

      // For time category, empty title shows placeholder in the title text
      final titleFinder = find.text('(Başlık girilmemiş) Ahmet');
      expect(titleFinder, findsOneWidget);
    });

    testWidgets(
        'shows italic placeholder for comeback title when empty',
        (tester) async {
      const message = FeedbackMessageModel(
        title: '',
        message: 'Mesaj var.',
        emoji: '👋',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'comeback',
      ));

      final placeholderFinder = find.text('(Başlık girilmemiş)');
      expect(placeholderFinder, findsOneWidget);

      final placeholderWidget = tester.widget<Text>(placeholderFinder);
      expect(placeholderWidget.style?.fontStyle, FontStyle.italic);
      expect(placeholderWidget.style?.color, const Color(0x80FFFFFF));
    });

    testWidgets(
        'shows italic placeholder for comeback message when empty',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Başlık var',
        message: '',
        emoji: '👋',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'comeback',
      ));

      final placeholderFinder = find.text('(Mesaj girilmemiş)');
      expect(placeholderFinder, findsOneWidget);

      final placeholderWidget = tester.widget<Text>(placeholderFinder);
      expect(placeholderWidget.style?.fontStyle, FontStyle.italic);
      expect(placeholderWidget.style?.color, const Color(0x80FFFFFF));
    });

    testWidgets(
        'shows both placeholders for comeback when title and message are empty',
        (tester) async {
      const message = FeedbackMessageModel(
        title: '',
        message: '',
        emoji: '👋',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'comeback',
      ));

      expect(find.text('(Başlık girilmemiş)'), findsOneWidget);
      expect(find.text('(Mesaj girilmemiş)'), findsOneWidget);
    });

    testWidgets(
        'does NOT show placeholders for comeback when fields are filled',
        (tester) async {
      const message = FeedbackMessageModel(
        title: 'Gerçek Başlık',
        message: 'Gerçek Mesaj',
        emoji: '👋',
      );

      await tester.pumpWidget(createTestWidget(
        message: message,
        category: 'comeback',
      ));

      expect(find.text('(Başlık girilmemiş)'), findsNothing);
      expect(find.text('(Mesaj girilmemiş)'), findsNothing);
      expect(find.text('Gerçek Başlık'), findsOneWidget);
      expect(find.text('Gerçek Mesaj'), findsOneWidget);
    });
  });
}
