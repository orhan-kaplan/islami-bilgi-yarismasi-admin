import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/screens/feedback/feedback_screen.dart';

void main() {
  /// Creates a loaded FeedbackContentState with minimal data for all categories.
  FeedbackContentState createLoadedState() {
    const msg = FeedbackMessageModel(
      title: 'Test Mesajı',
      message: 'Bu bir test mesajıdır.',
      emoji: '📝',
    );
    const title = PlayerTitleModel(
      title: 'İlim Yolcusu',
      icon: '🌱',
      requiredBooks: 0,
      profileImage: 'images/seed/default.webp',
    );

    return FeedbackContentState(
      quiz: {
        'speed_demon': [msg],
        'perfect': [msg],
        'one_wrong': [msg],
        'two_wrong': [msg],
        'good': [msg],
        'moderate': [msg],
        'failure': [msg],
      },
      speedQuiz: {
        'combo_master': [msg],
        'high_score': [msg],
        'time_expired': [msg],
        'moderate': [msg],
        'low': [msg],
      },
      time: {
        'seher': [msg],
        'morning': [msg],
        'noon': [msg],
        'afternoon': [msg],
        'evening': [msg],
        'night': [msg],
        'teheccud': [msg],
      },
      comeback: [msg],
      streak: {
        '3': [msg],
        '7': [msg],
        '30': [msg],
      },
      titles: [title],
      learned: {
        '100': [msg],
        '75': [msg],
        '50': [msg],
        '25': [msg],
        '0': [msg],
      },
    );
  }

  /// Wraps [FeedbackScreen] in a [MaterialApp] with [ProviderScope] overrides.
  Widget createTestWidget(FeedbackContentState state) {
    return ProviderScope(
      overrides: [
        feedbackContentProvider.overrideWith(
          (ref) => FeedbackContentNotifier(state),
        ),
        feedbackLoadProvider.overrideWith(
          (ref) => _MockFeedbackLoadNotifier(ref),
        ),
      ],
      child: const MaterialApp(
        home: FeedbackScreen(),
      ),
    );
  }

  group('FeedbackScreen', () {
    testWidgets('renders 7 tabs', (tester) async {
      await tester.pumpWidget(createTestWidget(createLoadedState()));
      await tester.pumpAndSettle();

      expect(find.text('Quiz'), findsOneWidget);
      expect(find.text('Speed Quiz'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('Comeback'), findsOneWidget);
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('Titles'), findsOneWidget);
      expect(find.text('Learned'), findsOneWidget);
    });

    testWidgets('tab switching shows correct category content - Comeback tab',
        (tester) async {
      final state = createLoadedState().copyWith(
        comeback: [
          const FeedbackMessageModel(
            title: 'Hoş Geldin!',
            message: 'Seni tekrar görmek güzel.',
            emoji: '👋',
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(state));
      await tester.pumpAndSettle();

      // Tap on Comeback tab
      await tester.tap(find.text('Comeback'));
      await tester.pumpAndSettle();

      // Should show the comeback message
      expect(find.text('Hoş Geldin!'), findsOneWidget);
    });

    testWidgets('tab switching shows correct category content - Titles tab',
        (tester) async {
      final state = createLoadedState().copyWith(
        titles: [
          const PlayerTitleModel(
            title: 'İlim Yolcusu',
            icon: '🌱',
            requiredBooks: 0,
            profileImage: 'img.webp',
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(state));
      await tester.pumpAndSettle();

      // Titles tab may be off-screen in scrollable TabBar, ensure it's visible
      await tester.ensureVisible(find.text('Titles'));
      await tester.pumpAndSettle();

      // Tap on Titles tab
      await tester.tap(find.text('Titles'));
      await tester.pumpAndSettle();

      // Should show the title
      expect(find.text('İlim Yolcusu'), findsOneWidget);
    });

    testWidgets('shows loading indicator when status is loading',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackContentProvider.overrideWith(
              (ref) => FeedbackContentNotifier(FeedbackContentState.empty()),
            ),
            feedbackLoadProvider.overrideWith(
              (ref) => _MockFeedbackLoadNotifier(ref, FeedbackLoadStatus.loading),
            ),
          ],
          child: const MaterialApp(
            home: FeedbackScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows FAB with "Mesaj Ekle" text on Comeback tab', (tester) async {
      await tester.pumpWidget(createTestWidget(createLoadedState()));
      await tester.pumpAndSettle();

      // Navigate to Comeback tab which has a FAB
      await tester.tap(find.text('Comeback'));
      await tester.pumpAndSettle();

      expect(find.text('Mesaj Ekle'), findsOneWidget);
    });
  });
}

/// A mock FeedbackLoadNotifier that immediately sets the status to loaded.
class _MockFeedbackLoadNotifier extends FeedbackLoadNotifier {
  _MockFeedbackLoadNotifier(super.ref, [FeedbackLoadStatus? initialStatus]) {
    if (initialStatus != null) {
      state = initialStatus;
    } else {
      state = FeedbackLoadStatus.loaded;
    }
  }

  @override
  Future<void> performLoad() async {
    // No-op for tests
  }
}
