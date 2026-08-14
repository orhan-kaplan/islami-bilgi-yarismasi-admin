import 'package:flutter_test/flutter_test.dart';
import 'package:islami_bilgi_yarismasi_admin/data/models/game_config_models.dart';
import 'package:islami_bilgi_yarismasi_admin/data/services/game_config_validator.dart';

void main() {
  group('validateGameConfigData', () {
    test('defaults are valid', () {
      expect(validateGameConfigData(GameConfigState.defaults), isEmpty);
    });

    test('rejects non-positive lives', () {
      final state = GameConfigState.defaults.copyWith(
        quiz: GameConfigState.defaults.quiz.copyWith(lives: 0),
      );
      expect(
        validateGameConfigData(state),
        contains(contains('quiz.lives')),
      );
    });

    test('rejects routing_priority that is not a permutation', () {
      final state = GameConfigState.defaults.copyWith(
        quiz: GameConfigState.defaults.quiz.copyWith(
          routingPriority: ['perfect', 'moderate'],
        ),
      );
      expect(
        validateGameConfigData(state),
        contains(contains('routing_priority')),
      );
    });

    test('rejects missing learned band key', () {
      final bands = GameConfigState.defaults.learnedBands
          .where((b) => b.key != '25')
          .toList();
      final state = GameConfigState.defaults.copyWith(learnedBands: bands);
      expect(
        validateGameConfigData(state),
        contains(contains('learned_bands is missing required key "25"')),
      );
    });

    test('rejects lottie path with assets/ prefix', () {
      final state = GameConfigState.defaults.copyWith(
        lottie: GameConfigState.defaults.lottie.copyWith(
          confetti: 'assets/lottie/Confetti.json',
        ),
      );
      expect(
        validateGameConfigData(state),
        contains(contains('lottie.confetti')),
      );
    });

    test('rejects accuracy outside 0–1', () {
      final state = GameConfigState.defaults.copyWith(
        quiz: GameConfigState.defaults.quiz.copyWith(goodMinAccuracy: 1.5),
      );
      expect(
        validateGameConfigData(state),
        contains(contains('good.min_accuracy')),
      );
    });
  });
}
