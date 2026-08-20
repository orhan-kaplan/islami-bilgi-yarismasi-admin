import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/device_preview_service.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/feedback_preview_dialog.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/widgets/preview/preview_helpers.dart';

void main() {
  // ===========================================================================
  // DevicePreviewService unit tests
  // ===========================================================================
  group('DevicePreviewService', () {
    const testMessage = FeedbackMessageModel(
      title: 'Tebrikler!',
      message: 'Harika bir performans gösterdin.',
      emoji: '🏆',
      lottieAsset: 'feedback/masallah.json',
      shouldRepeat: true,
    );

    test('returns PreviewResultSuccess when server responds with 200',
        () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:8080/api/preview');
        expect(request.method, 'POST');
        expect(request.headers['Content-Type'], 'application/json');

        // Payload alan-alan eşlemesi property testte (device_preview_properties_test.dart,
        // Property 4) 100 rastgele girdiyle zaten doğrulanıyor.
        return http.Response('{"status": "ok"}', 200);
      });

      final service = DevicePreviewService(client: mockClient);

      final result = await service.sendPreview(
        message: testMessage,
        screenContext: PreviewContext.quizResult,
        category: 'quiz',
        subcategory: 'perfect',
      );

      expect(result, isA<PreviewResultSuccess>());
      service.dispose();
    });

    test('returns PreviewResultConnectionError on timeout', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Connection timed out');
      });

      final service = DevicePreviewService(client: mockClient);

      final result = await service.sendPreview(
        message: testMessage,
        screenContext: PreviewContext.dashboard,
        category: 'time',
        subcategory: 'morning',
      );

      expect(result, isA<PreviewResultConnectionError>());
      service.dispose();
    });

    test('returns PreviewResultConnectionError on connection error', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final service = DevicePreviewService(client: mockClient);

      final result = await service.sendPreview(
        message: testMessage,
        screenContext: PreviewContext.learnedResult,
        category: 'learned',
        subcategory: '75',
      );

      expect(result, isA<PreviewResultConnectionError>());
      service.dispose();
    });

    test('returns PreviewResultServerError with message on 400 response',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'Missing required fields: title, screenContext',
          }),
          400,
        );
      });

      final service = DevicePreviewService(client: mockClient);

      final result = await service.sendPreview(
        message: testMessage,
        screenContext: PreviewContext.quizResult,
        category: 'quiz',
      );

      expect(result, isA<PreviewResultServerError>());
      final serverError = result as PreviewResultServerError;
      expect(
        serverError.message,
        'Missing required fields: title, screenContext',
      );
      service.dispose();
    });

    test('returns PreviewResultServerError with message on 500 response',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Internal server error'}),
          500,
        );
      });

      final service = DevicePreviewService(client: mockClient);

      final result = await service.sendPreview(
        message: testMessage,
        screenContext: PreviewContext.dashboard,
        category: 'streak',
        subcategory: '7',
      );

      expect(result, isA<PreviewResultServerError>());
      final serverError = result as PreviewResultServerError;
      expect(serverError.message, 'Internal server error');
      service.dispose();
    });

    test(
        'returns PreviewResultServerError with fallback message on non-JSON error body',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response('Something went wrong', 502);
      });

      final service = DevicePreviewService(client: mockClient);

      final result = await service.sendPreview(
        message: testMessage,
        screenContext: PreviewContext.quizResult,
        category: 'quiz',
      );

      expect(result, isA<PreviewResultServerError>());
      final serverError = result as PreviewResultServerError;
      expect(serverError.message, 'Sunucu hatası (502)');
      service.dispose();
    });
  });

  // ===========================================================================
  // Button integration widget tests
  // ===========================================================================
  group('FeedbackPreviewDialog — Cihazda Test Et button integration', () {
    const testMessage = FeedbackMessageModel(
      title: 'Test Mesajı',
      message: 'Bu bir test mesajıdır.',
      emoji: '🎯',
    );

    /// Creates a mock client that handles both health check and preview endpoints.
    MockClient createMockClient({
      bool healthConnected = true,
      int previewStatusCode = 200,
      String? previewErrorMessage,
      bool previewTimeout = false,
    }) {
      return MockClient((request) async {
        if (request.url.path == '/api/health') {
          if (!healthConnected) {
            throw http.ClientException('Connection refused');
          }
          return http.Response('OK', 200);
        }
        if (request.url.path == '/api/preview') {
          if (previewTimeout) {
            throw TimeoutException('Connection timed out');
          }
          if (previewStatusCode == 200) {
            return http.Response('{"status": "ok"}', 200);
          }
          final body = previewErrorMessage != null
              ? jsonEncode({'error': previewErrorMessage})
              : 'Error';
          return http.Response(body, previewStatusCode);
        }
        return http.Response('Not Found', 404);
      });
    }

    /// Helper to build a test app with a button that opens the preview dialog.
    Widget createTestApp({required http.Client httpClient}) {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showFeedbackPreviewDialog(
                  context,
                  message: testMessage,
                  category: 'quiz',
                  subcategory: 'perfect',
                  httpClient: httpClient,
                ),
                child: const Text('Önizleme'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('button is disabled when asset server is not connected',
        (tester) async {
      // Use a large surface to ensure the button is visible
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockClient = createMockClient(healthConnected: false);

      await tester.pumpWidget(createTestApp(httpClient: mockClient));
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      // Find the "Cihazda Test Et" button
      final buttonFinder = find.widgetWithText(FilledButton, 'Cihazda Test Et');
      expect(buttonFinder, findsOneWidget);

      // Button should be disabled (onPressed is null)
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('button shows loading indicator while sending preview',
        (tester) async {
      // Use a large surface to ensure the button is visible
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Use a completer to control when the response arrives
      final completer = Completer<http.Response>();
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/health') {
          return http.Response('OK', 200);
        }
        if (request.url.path == '/api/preview') {
          return completer.future;
        }
        return http.Response('Not Found', 404);
      });

      await tester.pumpWidget(createTestApp(httpClient: mockClient));
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      // Scroll to make the button visible and tap it
      final buttonFinder = find.widgetWithText(FilledButton, 'Cihazda Test Et');
      await tester.ensureVisible(buttonFinder);
      await tester.pumpAndSettle();

      // Button should be enabled (server is connected)
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNotNull);

      // Tap the "Cihazda Test Et" button
      await tester.tap(buttonFinder);
      await tester.pump();

      // Loading indicator should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the request
      completer.complete(http.Response('{"status": "ok"}', 200));
      await tester.pumpAndSettle();

      // Loading indicator should be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows success SnackBar on successful send', (tester) async {
      // Use a large surface to ensure the button is visible
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockClient = createMockClient(
        healthConnected: true,
        previewStatusCode: 200,
      );

      await tester.pumpWidget(createTestApp(httpClient: mockClient));
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      // Scroll to make the button visible and tap it
      final buttonFinder = find.widgetWithText(FilledButton, 'Cihazda Test Et');
      await tester.ensureVisible(buttonFinder);
      await tester.pumpAndSettle();
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Success SnackBar should be shown
      expect(find.text('Preview isteği gönderildi'), findsOneWidget);
    });

    testWidgets('shows error SnackBar on connection error', (tester) async {
      // Use a large surface to ensure the button is visible
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockClient = createMockClient(
        healthConnected: true,
        previewTimeout: true,
      );

      await tester.pumpWidget(createTestApp(httpClient: mockClient));
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();

      // Scroll to make the button visible and tap it
      final buttonFinder = find.widgetWithText(FilledButton, 'Cihazda Test Et');
      await tester.ensureVisible(buttonFinder);
      await tester.pumpAndSettle();
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Error SnackBar should be shown
      expect(
        find.text(
          'Asset sunucusuna bağlanılamadı. Sunucunun çalıştığından emin olun.',
        ),
        findsOneWidget,
      );
    });
  });
}
