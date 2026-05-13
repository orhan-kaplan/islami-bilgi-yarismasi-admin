import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/dashboard_preview.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/feedback_preview_dialog.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/learned_result_preview.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/phone_mockup_frame.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/quiz_result_preview.dart';

void main() {
  const testMessage = FeedbackMessageModel(
    title: 'Tebrikler!',
    message: 'Harika bir performans gösterdin.',
    emoji: '🏆',
  );

  /// Mock HTTP client that returns 200 for health check.
  late http.Client mockHttpClient;

  setUp(() {
    mockHttpClient = http_testing.MockClient((request) async {
      if (request.url.path == '/api/health') {
        return http.Response('OK', 200);
      }
      return http.Response('Not Found', 404);
    });
  });

  tearDown(() {
    mockHttpClient.close();
  });

  /// Helper to build a test app with a button that opens the preview dialog.
  Widget createTestApp({
    FeedbackMessageModel message = testMessage,
    String category = 'quiz',
    String? subcategory,
    http.Client? httpClient,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showFeedbackPreviewDialog(
                context,
                message: message,
                category: category,
                subcategory: subcategory,
                httpClient: httpClient ?? mockHttpClient,
              ),
              child: const Text('Önizleme'),
            ),
          ),
        ),
      ),
    );
  }

  group('FeedbackPreviewDialog — Dialog açılış/kapanış akışı', () {
    testWidgets('dialog opens when showFeedbackPreviewDialog is called',
        (tester) async {
      await tester.pumpWidget(createTestApp());

      expect(find.byType(FeedbackPreviewDialog), findsNothing);

      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      expect(find.byType(FeedbackPreviewDialog), findsOneWidget);
    });

    testWidgets('dialog contains PhoneMockupFrame', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      expect(find.byType(PhoneMockupFrame), findsOneWidget);
    });

    testWidgets('dialog closes on "×" button tap', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      expect(find.byType(FeedbackPreviewDialog), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(FeedbackPreviewDialog), findsNothing);
    });

    testWidgets('dialog closes on barrier tap (outside dialog)',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      expect(find.byType(FeedbackPreviewDialog), findsOneWidget);

      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();

      expect(find.byType(FeedbackPreviewDialog), findsNothing);
    });

    testWidgets('dialog shows "Cihazda Test Et" button', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      expect(find.text('Cihazda Test Et'), findsOneWidget);
    });
  });

  group('FeedbackPreviewDialog — Otomatik ekran bağlamı seçimi', () {
    testWidgets('quiz category → QuizResultPreview gösterilir',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        category: 'quiz',
        subcategory: 'perfect',
      ));
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      expect(find.byType(QuizResultPreview), findsOneWidget);
      expect(find.byType(DashboardPreview), findsNothing);
      expect(find.byType(LearnedQuizResultPreview), findsNothing);
    });

    testWidgets('speed_quiz category → QuizResultPreview gösterilir',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        category: 'speed_quiz',
        subcategory: 'perfect',
      ));
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      expect(find.byType(QuizResultPreview), findsOneWidget);
      expect(find.byType(DashboardPreview), findsNothing);
      expect(find.byType(LearnedQuizResultPreview), findsNothing);
    });

    testWidgets('time category → DashboardPreview gösterilir',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        category: 'time',
        subcategory: 'morning',
      ));
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardPreview), findsOneWidget);
      expect(find.byType(QuizResultPreview), findsNothing);
      expect(find.byType(LearnedQuizResultPreview), findsNothing);
    });

    testWidgets('comeback category → DashboardPreview gösterilir',
        (tester) async {
      await tester.pumpWidget(createTestApp(category: 'comeback'));
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardPreview), findsOneWidget);
      expect(find.byType(QuizResultPreview), findsNothing);
      expect(find.byType(LearnedQuizResultPreview), findsNothing);
    });

    testWidgets('streak category → DashboardPreview gösterilir',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        category: 'streak',
        subcategory: '7',
      ));
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardPreview), findsOneWidget);
      expect(find.byType(QuizResultPreview), findsNothing);
      expect(find.byType(LearnedQuizResultPreview), findsNothing);
    });

    testWidgets('learned category → LearnedQuizResultPreview gösterilir',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        category: 'learned',
        subcategory: '75',
      ));
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      expect(find.byType(LearnedQuizResultPreview), findsOneWidget);
      expect(find.byType(QuizResultPreview), findsNothing);
      expect(find.byType(DashboardPreview), findsNothing);
    });
  });
}
