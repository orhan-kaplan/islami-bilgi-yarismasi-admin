import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/game_config_models.dart';

void main() {
  group('parseGameConfigHhMm / formatGameConfigHhMm', () {
    test('parses valid HH:mm and rejects out-of-range', () {
      expect(parseGameConfigHhMm('00:00'), 0);
      expect(parseGameConfigHhMm('04:30'), 270);
      expect(parseGameConfigHhMm('23:59'), 1439);
      expect(parseGameConfigHhMm('24:00'), isNull);
      expect(parseGameConfigHhMm('12:60'), isNull);
      expect(parseGameConfigHhMm('7:00'), 420);
      expect(parseGameConfigHhMm('abc'), isNull);
    });

    test('formats minutes with wrap-around', () {
      expect(formatGameConfigHhMm(0), '00:00');
      expect(formatGameConfigHhMm(270), '04:30');
      expect(formatGameConfigHhMm(1440), '00:00');
      expect(formatGameConfigHhMm(-1), '23:59');
    });
  });

  group('ScoreClause', () {
    test('AND of present fields; empty clause always matches', () {
      const both = ScoreClause(minAccuracy: 0.8, minCorrect: 15);
      expect(both.matches(accuracy: 0.8, correct: 15), isTrue);
      expect(both.matches(accuracy: 0.79, correct: 20), isFalse);
      expect(both.matches(accuracy: 1.0, correct: 14), isFalse);
      expect(const ScoreClause().matches(accuracy: 0, correct: 0), isTrue);
    });

    test('fromJson treats missing keys as unconstrained', () {
      final onlyCorrect = ScoreClause.fromJson({'min_correct': 12});
      expect(onlyCorrect.minAccuracy, isNull);
      expect(onlyCorrect.matches(accuracy: 0.1, correct: 12), isTrue);
    });
  });

  group('LearnedBand', () {
    test('exclusive_min: 25 is 0 < pct, not >= 25', () {
      final band25 = GameConfigState.defaults.learnedBands
          .firstWhere((b) => b.key == '25');
      expect(band25.exclusiveMin, isTrue);
      expect(band25.matches(0), isFalse);
      expect(band25.matches(1), isTrue);
      expect(band25.matches(49), isTrue);
    });

    test('inclusive bands use >=', () {
      final band50 = GameConfigState.defaults.learnedBands
          .firstWhere((b) => b.key == '50');
      expect(band50.matches(49.9), isFalse);
      expect(band50.matches(50), isTrue);
    });
  });

  group('TimeSlotConfig', () {
    test('night wraps midnight', () {
      final night = GameConfigState.defaults.timeSlots
          .firstWhere((s) => s.key == 'night');
      expect(night.contains(1380), isTrue);
      expect(night.contains(0), isTrue);
      expect(night.contains(119), isTrue);
      expect(night.contains(120), isFalse);
    });

    test('tryFromJson drops invalid times', () {
      expect(
        TimeSlotConfig.tryFromJson({
          'key': 'bad',
          'start': '25:00',
          'end': '01:00',
          'label': 'X',
        }),
        isNull,
      );
    });
  });

  group('GameConfigState.fromJson', () {
    test('empty map keeps defaults', () {
      final state = GameConfigState.fromJson({});
      expect(state.toJson(), GameConfigState.defaults.toJson());
    });

    test('parses overlays and falls back per-field', () {
      final state = GameConfigState.fromJson({
        'quiz': {
          'lives': 4,
          'points_per_correct': 15.9,
          'routing_priority': <Object>[],
        },
        'comeback': {'min_days': 7},
        'daily_goal': {'target_levels': 2, 'target_questions': 20},
        'copy': {'default_name': ''},
      });

      expect(state.quiz.lives, 4);
      expect(state.quiz.pointsPerCorrect, 15);
      expect(
        state.quiz.routingPriority,
        QuizGameConfig.defaults.routingPriority,
      );
      expect(state.comebackMinDays, 7);
      expect(state.dailyGoal.targetLevels, 2);
      expect(state.copy.defaultName, CopyGameConfig.defaults.defaultName);
    });

    test('toJson / fromJson roundtrip preserves defaults', () {
      final roundtrip = GameConfigState.fromJson(GameConfigState.defaults.toJson());
      expect(roundtrip.toJson(), GameConfigState.defaults.toJson());
    });

    test('empty learned_bands and time_slots fall back to defaults', () {
      final state = GameConfigState.fromJson({
        'learned_bands': <Object>[],
        'time_slots': <Object>[],
      });
      expect(state.learnedBands.map((b) => b.key), ['100', '75', '50', '25', '0']);
      expect(state.timeSlots, hasLength(7));
    });

    test('invalid time slots are dropped; remaining slots are kept', () {
      final state = GameConfigState.fromJson({
        'time_slots': [
          {
            'key': 'night',
            'start': '23:00',
            'end': '02:00',
            'label': 'Özel Gece',
          },
          {'key': 'bad', 'start': '25:99', 'end': '01:00', 'label': 'Yok'},
          {'key': '', 'start': '08:00', 'end': '09:00', 'label': 'Boş'},
        ],
      });
      expect(state.timeSlots, hasLength(1));
      expect(state.timeSlots.single.label, 'Özel Gece');
    });

    test('lottie getters prefix assets/lottie/', () {
      expect(
        GameConfigState.defaults.lottie.confettiAsset,
        'assets/lottie/Confetti.json',
      );
    });

    test('default_name is the user display name', () {
      expect(GameConfigState.defaults.copy.defaultName, 'İlim Yolcusu');
    });

    test('empty high_score.any keeps default clauses', () {
      final speed = SpeedQuizGameConfig.fromJson({
        'high_score': {'any': <Object>[]},
      });
      expect(speed.highScoreAny, SpeedQuizGameConfig.defaults.highScoreAny);
    });
  });
}
