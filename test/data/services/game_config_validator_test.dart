import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/game_config_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/game_config_validator.dart';

void main() {
  group('validateGameConfigData', () {
    test('defaults are valid', () {
      expect(validateGameConfigData(GameConfigState.defaults), isEmpty);
    });

    test('routing_priority permutation is valid; incomplete or duplicate is not',
        () {
      final permuted = GameConfigState.defaults.copyWith(
        quiz: GameConfigState.defaults.quiz.copyWith(
          routingPriority: [
            'perfect',
            'speed_demon',
            'one_wrong',
            'two_wrong',
            'good',
            'moderate',
          ],
        ),
      );
      expect(validateGameConfigData(permuted), isEmpty);

      final incomplete = GameConfigState.defaults.copyWith(
        quiz: GameConfigState.defaults.quiz.copyWith(
          routingPriority: ['perfect', 'moderate'],
        ),
      );
      expect(
        validateGameConfigData(incomplete),
        contains(contains('routing_priority')),
      );

      final duplicates = GameConfigState.defaults.copyWith(
        quiz: GameConfigState.defaults.quiz.copyWith(
          routingPriority: [
            'speed_demon',
            'perfect',
            'one_wrong',
            'two_wrong',
            'good',
            'speed_demon',
          ],
        ),
      );
      expect(
        validateGameConfigData(duplicates),
        contains(contains('must not contain duplicates')),
      );
    });

    test('rejects non-positive quiz / speed / daily / comeback integers', () {
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(
            quiz: GameConfigState.defaults.quiz.copyWith(lives: 0),
          ),
        ),
        contains(contains('quiz.lives')),
      );
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(
            quiz: GameConfigState.defaults.quiz.copyWith(pointsPerCorrect: -1),
          ),
        ),
        contains(contains('points_per_correct')),
      );
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(
            speedQuiz:
                GameConfigState.defaults.speedQuiz.copyWith(durationSeconds: 0),
          ),
        ),
        contains(contains('duration_seconds')),
      );
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(comebackMinDays: 0),
        ),
        contains(contains('comeback.min_days')),
      );
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(
            dailyGoal: const DailyGoalGameConfig(
              targetLevels: 0,
              targetQuestions: 30,
            ),
          ),
        ),
        contains(contains('target_levels')),
      );
    });

    test('rejects accuracy outside 0–1', () {
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(
            quiz: GameConfigState.defaults.quiz.copyWith(goodMinAccuracy: 1.5),
          ),
        ),
        contains(contains('good.min_accuracy')),
      );
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(
            speedQuiz: GameConfigState.defaults.speedQuiz
                .copyWith(comboMinAccuracy: -0.1),
          ),
        ),
        contains(contains('combo_master.min_accuracy')),
      );
    });

    test('high_score.any needs at least one constrained clause', () {
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(
            speedQuiz: GameConfigState.defaults.speedQuiz
                .copyWith(highScoreAny: const []),
          ),
        ),
        contains(contains('high_score.any must have at least one clause')),
      );
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(
            speedQuiz: GameConfigState.defaults.speedQuiz.copyWith(
              highScoreAny: const [ScoreClause()],
            ),
          ),
        ),
        contains(contains('needs min_accuracy and/or min_correct')),
      );
    });

    test('learned_bands require 100/75/50/25/0; extras are allowed', () {
      final missing25 = GameConfigState.defaults.copyWith(
        learnedBands: GameConfigState.defaults.learnedBands
            .where((b) => b.key != '25')
            .toList(),
      );
      expect(
        validateGameConfigData(missing25),
        contains(contains('learned_bands is missing required key "25"')),
      );

      final withExtra = GameConfigState.defaults.copyWith(
        learnedBands: [
          ...GameConfigState.defaults.learnedBands,
          const LearnedBand(key: '90', minPercent: 90),
        ],
      );
      expect(validateGameConfigData(withExtra), isEmpty);

      final duplicateKeys = GameConfigState.defaults.copyWith(
        learnedBands: [
          ...GameConfigState.defaults.learnedBands,
          const LearnedBand(key: '100', minPercent: 100),
        ],
      );
      expect(
        validateGameConfigData(duplicateKeys),
        contains(contains('learned_bands keys must be unique')),
      );
    });

    test('time_slots require the seven keys; unknown keys and empty labels fail',
        () {
      final missingNight = GameConfigState.defaults.copyWith(
        timeSlots: GameConfigState.defaults.timeSlots
            .where((s) => s.key != 'night')
            .toList(),
      );
      expect(
        validateGameConfigData(missingNight),
        contains(contains('time_slots is missing required key "night"')),
      );

      final unknown = GameConfigState.defaults.copyWith(
        timeSlots: [
          ...GameConfigState.defaults.timeSlots,
          const TimeSlotConfig(
            key: 'dawn',
            startMinutes: 0,
            endMinutes: 60,
            label: 'X',
          ),
        ],
      );
      expect(
        validateGameConfigData(unknown),
        contains(contains('time_slots has unknown key "dawn"')),
      );

      final emptyLabel = GameConfigState.defaults.copyWith(
        timeSlots: [
          for (final slot in GameConfigState.defaults.timeSlots)
            slot.key == 'seher' ? slot.copyWith(label: '  ') : slot,
        ],
      );
      expect(
        validateGameConfigData(emptyLabel),
        contains(contains('time_slots[seher].label must not be empty')),
      );

      final sameStartEnd = GameConfigState.defaults.copyWith(
        timeSlots: [
          for (final slot in GameConfigState.defaults.timeSlots)
            slot.key == 'noon'
                ? slot.copyWith(startMinutes: 600, endMinutes: 600)
                : slot,
        ],
      );
      expect(
        validateGameConfigData(sameStartEnd),
        contains(contains('start and end must differ')),
      );
    });

    test('night wrap (end < start) is valid', () {
      expect(validateGameConfigData(GameConfigState.defaults), isEmpty);
      final night = GameConfigState.defaults.timeSlots
          .firstWhere((s) => s.key == 'night');
      expect(night.endMinutes < night.startMinutes, isTrue);
    });

    test('rejects lottie path with assets/ prefix or empty value', () {
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(
            lottie: GameConfigState.defaults.lottie.copyWith(
              confetti: 'assets/lottie/Confetti.json',
            ),
          ),
        ),
        contains(contains('lottie.confetti')),
      );
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(
            lottie: GameConfigState.defaults.lottie.copyWith(quizFail: ''),
          ),
        ),
        contains(contains('lottie.quiz_fail must not be empty')),
      );
    });

    test('rejects empty copy fields including default_name', () {
      expect(
        validateGameConfigData(
          GameConfigState.defaults.copyWith(
            copy: GameConfigState.defaults.copy.copyWith(defaultName: '  '),
          ),
        ),
        contains(contains('copy.default_name must not be empty')),
      );
    });
  });
}
