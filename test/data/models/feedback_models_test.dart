import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/feedback_models.dart';

void main() {
  group('FeedbackMessageModel', () {
    test('fromJson parses all fields correctly with Türkçe text', () {
      final json = {
        'title': 'Müthiş Performans!',
        'message': 'Çok güzel bir başarı gösterdin, tebrikler!',
        'emoji': '🌟',
        'lottie_asset': 'feedback/masallah.json',
        'should_repeat': false,
      };

      final model = FeedbackMessageModel.fromJson(json);

      expect(model.title, 'Müthiş Performans!');
      expect(model.message, 'Çok güzel bir başarı gösterdin, tebrikler!');
      expect(model.emoji, '🌟');
      expect(model.lottieAsset, 'feedback/masallah.json');
      expect(model.shouldRepeat, false);
    });

    test('fromJson handles Türkçe special characters (ş, ç, ğ, ı, ö, ü)', () {
      final json = {
        'title': 'Başarılı öğrenci',
        'message': 'Güçlü bir çalışmayla ışığını gösterdin',
        'emoji': '✨',
        'lottie_asset': null,
        'should_repeat': true,
      };

      final model = FeedbackMessageModel.fromJson(json);

      expect(model.title, 'Başarılı öğrenci');
      expect(model.message, 'Güçlü bir çalışmayla ışığını gösterdin');
    });

    test('fromJson defaults shouldRepeat to true when missing', () {
      final json = {
        'title': 'Test',
        'message': 'Mesaj',
        'emoji': '📝',
      };

      final model = FeedbackMessageModel.fromJson(json);

      expect(model.shouldRepeat, true);
    });

    test('fromJson handles null lottieAsset', () {
      final json = {
        'title': 'Test',
        'message': 'Mesaj',
        'emoji': '📝',
        'lottie_asset': null,
        'should_repeat': true,
      };

      final model = FeedbackMessageModel.fromJson(json);

      expect(model.lottieAsset, isNull);
    });

    test('toJson produces snake_case keys', () {
      const model = FeedbackMessageModel(
        title: 'Harika İş!',
        message: 'Süper bir performans gösterdin.',
        emoji: '🎉',
        lottieAsset: 'feedback/tebrikler.json',
        shouldRepeat: false,
      );

      final json = model.toJson();

      expect(json['title'], 'Harika İş!');
      expect(json['message'], 'Süper bir performans gösterdin.');
      expect(json['emoji'], '🎉');
      expect(json['lottie_asset'], 'feedback/tebrikler.json');
      expect(json['should_repeat'], false);
    });

    test('toJson includes null lottieAsset', () {
      const model = FeedbackMessageModel(
        title: 'Test',
        message: 'Mesaj',
        emoji: '📝',
      );

      final json = model.toJson();

      expect(json.containsKey('lottie_asset'), true);
      expect(json['lottie_asset'], isNull);
    });

    test('round-trip fromJson/toJson preserves data with Türkçe', () {
      final original = {
        'title': 'Öğrenme Şampiyonu',
        'message': 'İlim yolculuğunda büyük adımlar atıyorsun!',
        'emoji': '🏆',
        'lottie_asset': 'feedback/sampiyon.json',
        'should_repeat': true,
      };

      final model = FeedbackMessageModel.fromJson(original);
      final result = model.toJson();

      expect(result, original);
    });

    test('copyWith creates modified copy', () {
      const model = FeedbackMessageModel(
        title: 'Orijinal',
        message: 'Orijinal mesaj',
        emoji: '📝',
        lottieAsset: 'feedback/test.json',
        shouldRepeat: true,
      );

      final updated = model.copyWith(
        title: 'Güncellenmiş',
        shouldRepeat: false,
      );

      expect(updated.title, 'Güncellenmiş');
      expect(updated.message, 'Orijinal mesaj');
      expect(updated.emoji, '📝');
      expect(updated.lottieAsset, 'feedback/test.json');
      expect(updated.shouldRepeat, false);
    });

    test('copyWith preserves lottieAsset when not specified', () {
      const model = FeedbackMessageModel(
        title: 'Test',
        message: 'Mesaj',
        emoji: '📝',
        lottieAsset: 'feedback/anim.json',
        shouldRepeat: true,
      );

      final updated = model.copyWith(title: 'Yeni');

      expect(updated.lottieAsset, 'feedback/anim.json');
    });

    test('equality works correctly', () {
      const a = FeedbackMessageModel(
        title: 'Test',
        message: 'Mesaj',
        emoji: '📝',
        lottieAsset: 'feedback/test.json',
        shouldRepeat: true,
      );
      const b = FeedbackMessageModel(
        title: 'Test',
        message: 'Mesaj',
        emoji: '📝',
        lottieAsset: 'feedback/test.json',
        shouldRepeat: true,
      );
      const c = FeedbackMessageModel(
        title: 'Farklı',
        message: 'Mesaj',
        emoji: '📝',
        lottieAsset: 'feedback/test.json',
        shouldRepeat: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('PlayerTitleModel', () {
    test('fromJson parses all fields correctly with Türkçe text', () {
      final json = {
        'title': 'İlim Yolcusu',
        'icon': '🌱',
        'required_books': 0,
        'profile_image': 'images/seed/profile_icon_seed.webp',
      };

      final model = PlayerTitleModel.fromJson(json);

      expect(model.title, 'İlim Yolcusu');
      expect(model.icon, '🌱');
      expect(model.requiredBooks, 0);
      expect(model.profileImage, 'images/seed/profile_icon_seed.webp');
    });

    test('fromJson handles Türkçe special characters (ş, ç, ğ, ı, ö, ü)', () {
      final json = {
        'title': 'Müçtehid Öğrenci',
        'icon': '📖',
        'required_books': 3,
        'profile_image': 'images/seed/scholar.webp',
      };

      final model = PlayerTitleModel.fromJson(json);

      expect(model.title, 'Müçtehid Öğrenci');
      expect(model.icon, '📖');
    });

    test('toJson produces snake_case keys', () {
      const model = PlayerTitleModel(
        title: 'Hafız Adayı',
        icon: '🕌',
        requiredBooks: 5,
        profileImage: 'images/seed/hafiz.webp',
      );

      final json = model.toJson();

      expect(json['title'], 'Hafız Adayı');
      expect(json['icon'], '🕌');
      expect(json['required_books'], 5);
      expect(json['profile_image'], 'images/seed/hafiz.webp');
    });

    test('round-trip fromJson/toJson preserves data with Türkçe', () {
      final original = {
        'title': 'Âlim-i Rabbânî',
        'icon': '👑',
        'required_books': 10,
        'profile_image': 'images/seed/alim.webp',
      };

      final model = PlayerTitleModel.fromJson(original);
      final result = model.toJson();

      expect(result, original);
    });

    test('copyWith creates modified copy', () {
      const model = PlayerTitleModel(
        title: 'Orijinal',
        icon: '🌱',
        requiredBooks: 0,
        profileImage: 'images/seed/default.webp',
      );

      final updated = model.copyWith(
        title: 'Güncellenmiş',
        requiredBooks: 3,
      );

      expect(updated.title, 'Güncellenmiş');
      expect(updated.icon, '🌱');
      expect(updated.requiredBooks, 3);
      expect(updated.profileImage, 'images/seed/default.webp');
    });

    test('equality works correctly', () {
      const a = PlayerTitleModel(
        title: 'Test',
        icon: '🌟',
        requiredBooks: 1,
        profileImage: 'img.webp',
      );
      const b = PlayerTitleModel(
        title: 'Test',
        icon: '🌟',
        requiredBooks: 1,
        profileImage: 'img.webp',
      );
      const c = PlayerTitleModel(
        title: 'Test',
        icon: '🌟',
        requiredBooks: 2,
        profileImage: 'img.webp',
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('FeedbackContentState', () {
    test('empty() creates state with empty collections', () {
      final state = FeedbackContentState.empty();

      expect(state.quiz, isEmpty);
      expect(state.speedQuiz, isEmpty);
      expect(state.time, isEmpty);
      expect(state.comeback, isEmpty);
      expect(state.streak, isEmpty);
      expect(state.titles, isEmpty);
      expect(state.learned, isEmpty);
    });

    test('copyWith creates modified copy', () {
      final state = FeedbackContentState.empty();
      const msg = FeedbackMessageModel(
        title: 'Test',
        message: 'Mesaj',
        emoji: '📝',
      );

      final updated = state.copyWith(comeback: [msg]);

      expect(updated.comeback, hasLength(1));
      expect(updated.comeback[0].title, 'Test');
      expect(updated.quiz, isEmpty);
    });
  });
}
