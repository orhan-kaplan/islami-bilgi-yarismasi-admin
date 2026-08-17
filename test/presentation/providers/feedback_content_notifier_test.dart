import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';
import 'package:islami_bilgi_yarismasi_admin/presentation/providers/feedback_content_providers.dart';

void main() {
  late FeedbackContentNotifier notifier;

  /// Creates a minimal valid state with at least one message per category.
  FeedbackContentState createMinimalState() {
    const msg = FeedbackMessageModel(
      title: 'Test',
      message: 'Test mesajı',
      emoji: '📝',
    );
    const title = PlayerTitleModel(
      title: 'İlim Yolcusu',
      icon: '🌱',
      requiredBooks: 0,
      profileImage: 'images/seed/default.webp',
    );

    return const FeedbackContentState(
      quiz: {
        'perfect': [msg],
        'failure': [msg],
      },
      speedQuiz: {
        'combo_master': [msg],
      },
      time: {
        'seher': [msg],
      },
      comeback: [msg],
      streak: {
        '3': [msg],
      },
      titles: [title],
      learned: {
        '100': [msg],
      },
    );
  }

  /// Creates a state with multiple messages for testing deletion.
  FeedbackContentState createStateWithMultipleMessages() {
    const msg1 = FeedbackMessageModel(
      title: 'Mesaj 1',
      message: 'Birinci mesaj',
      emoji: '📝',
    );
    const msg2 = FeedbackMessageModel(
      title: 'Mesaj 2',
      message: 'İkinci mesaj',
      emoji: '🎉',
    );
    const title1 = PlayerTitleModel(
      title: 'İlim Yolcusu',
      icon: '🌱',
      requiredBooks: 0,
      profileImage: 'img1.webp',
    );
    const title2 = PlayerTitleModel(
      title: 'Hafız Adayı',
      icon: '📖',
      requiredBooks: 3,
      profileImage: 'img2.webp',
    );

    return const FeedbackContentState(
      quiz: {
        'perfect': [msg1, msg2],
        'failure': [msg1, msg2],
      },
      speedQuiz: {
        'combo_master': [msg1, msg2],
      },
      time: {
        'seher': [msg1, msg2],
      },
      comeback: [msg1, msg2],
      streak: {
        '3': [msg1, msg2],
      },
      titles: [title1, title2],
      learned: {
        '100': [msg1, msg2],
      },
    );
  }

  setUp(() {
    notifier = FeedbackContentNotifier(createMinimalState());
  });

  group('FeedbackContentNotifier - Message CRUD', () {
    test('addMessage increases list size for map-based category', () {
      const newMsg = FeedbackMessageModel(
        title: 'Yeni Mesaj',
        message: 'Yeni içerik',
        emoji: '✨',
      );

      final beforeCount = notifier.state.quiz['perfect']!.length;
      notifier.addMessage('quiz', 'perfect', newMsg);
      final afterCount = notifier.state.quiz['perfect']!.length;

      expect(afterCount, beforeCount + 1);
      expect(notifier.state.quiz['perfect']!.last, newMsg);
    });

    test('addMessage increases list size for comeback (flat category)', () {
      const newMsg = FeedbackMessageModel(
        title: 'Hoş geldin!',
        message: 'Seni tekrar görmek güzel.',
        emoji: '👋',
      );

      final beforeCount = notifier.state.comeback.length;
      notifier.addMessage('comeback', null, newMsg);
      final afterCount = notifier.state.comeback.length;

      expect(afterCount, beforeCount + 1);
      expect(notifier.state.comeback.last, newMsg);
    });

    test('deleteMessage with >1 items succeeds', () {
      notifier = FeedbackContentNotifier(createStateWithMultipleMessages());

      final beforeCount = notifier.state.quiz['perfect']!.length;
      final result = notifier.deleteMessage('quiz', 'perfect', 0);

      expect(result, true);
      expect(notifier.state.quiz['perfect']!.length, beforeCount - 1);
    });

    test('deleteMessage with 1 item fails (deletion guard)', () {
      // State has exactly 1 message in quiz.perfect
      final result = notifier.deleteMessage('quiz', 'perfect', 0);

      expect(result, false);
      expect(notifier.state.quiz['perfect']!.length, 1);
    });

    test('deleteMessage for comeback with >1 items succeeds', () {
      notifier = FeedbackContentNotifier(createStateWithMultipleMessages());

      final beforeCount = notifier.state.comeback.length;
      final result = notifier.deleteMessage('comeback', null, 0);

      expect(result, true);
      expect(notifier.state.comeback.length, beforeCount - 1);
    });

    test('deleteMessage for comeback with 1 item fails', () {
      final result = notifier.deleteMessage('comeback', null, 0);

      expect(result, false);
      expect(notifier.state.comeback.length, 1);
    });

    test('updateMessage replaces message at index', () {
      const updatedMsg = FeedbackMessageModel(
        title: 'Güncellenmiş',
        message: 'Yeni mesaj içeriği',
        emoji: '🔄',
      );

      notifier.updateMessage('quiz', 'perfect', 0, updatedMsg);

      expect(notifier.state.quiz['perfect']![0], updatedMsg);
    });
  });

  group('FeedbackContentNotifier - Title CRUD', () {
    test('addTitle with unique required_books succeeds', () {
      const newTitle = PlayerTitleModel(
        title: 'Hafız Adayı',
        icon: '📖',
        requiredBooks: 5,
        profileImage: 'img.webp',
      );

      final beforeCount = notifier.state.titles.length;
      final result = notifier.addTitle(newTitle);

      expect(result, true);
      expect(notifier.state.titles.length, beforeCount + 1);
    });

    test('addTitle with duplicate required_books fails', () {
      const duplicateTitle = PlayerTitleModel(
        title: 'Duplicate',
        icon: '❌',
        requiredBooks: 0, // Same as existing title
        profileImage: 'img.webp',
      );

      final beforeCount = notifier.state.titles.length;
      final result = notifier.addTitle(duplicateTitle);

      expect(result, false);
      expect(notifier.state.titles.length, beforeCount);
    });

    test('updateTitle re-sorts by required_books', () {
      // Add multiple titles first
      const title2 = PlayerTitleModel(
        title: 'Orta',
        icon: '📚',
        requiredBooks: 5,
        profileImage: 'img2.webp',
      );
      const title3 = PlayerTitleModel(
        title: 'İleri',
        icon: '🏆',
        requiredBooks: 10,
        profileImage: 'img3.webp',
      );
      notifier.addTitle(title2);
      notifier.addTitle(title3);

      // Update the last title to have requiredBooks = 1 (should move to second position)
      const updatedTitle = PlayerTitleModel(
        title: 'Güncellendi',
        icon: '🔄',
        requiredBooks: 1,
        profileImage: 'img_updated.webp',
      );
      notifier.updateTitle(2, updatedTitle); // Update the title at index 2

      // Verify sorted order
      final titles = notifier.state.titles;
      for (var i = 0; i < titles.length - 1; i++) {
        expect(titles[i].requiredBooks <= titles[i + 1].requiredBooks, true,
            reason:
                'Titles should be sorted by requiredBooks: ${titles.map((t) => t.requiredBooks).toList()}');
      }
    });

    test('deleteTitle with >1 items succeeds', () {
      notifier = FeedbackContentNotifier(createStateWithMultipleMessages());

      final beforeCount = notifier.state.titles.length;
      final result = notifier.deleteTitle(0);

      expect(result, true);
      expect(notifier.state.titles.length, beforeCount - 1);
    });

    test('deleteTitle with 1 item fails (deletion guard)', () {
      // State has exactly 1 title
      final result = notifier.deleteTitle(0);

      expect(result, false);
      expect(notifier.state.titles.length, 1);
    });
  });
}
