import '../models/game_config_models.dart';
import 'feedback_validator.dart' show isValidLottieShortPath;

const kRequiredQuizRoutingKeys = [
  'speed_demon',
  'perfect',
  'one_wrong',
  'two_wrong',
  'good',
  'moderate',
];

const kRequiredLearnedBandKeys = ['100', '75', '50', '25', '0'];

const kRequiredTimeSlotKeys = [
  'seher',
  'morning',
  'noon',
  'afternoon',
  'evening',
  'night',
  'teheccud',
];

bool _isPositiveInt(int value) => value > 0;

bool _isAccuracy(double value) => value >= 0 && value <= 1;

List<String> validateGameConfigData(GameConfigState state) {
  final errors = <String>[];
  final quiz = state.quiz;

  if (!_isPositiveInt(quiz.lives)) {
    errors.add('quiz.lives must be a positive integer');
  }
  if (!_isPositiveInt(quiz.pointsPerCorrect)) {
    errors.add('quiz.points_per_correct must be a positive integer');
  }
  if (!_isPositiveInt(quiz.speedDemonMaxSecondsPerQuestion)) {
    errors.add('quiz.speed_demon.max_seconds_per_question must be a positive integer');
  }
  if (!_isAccuracy(quiz.speedDemonMinAccuracy)) {
    errors.add('quiz.speed_demon.min_accuracy must be between 0 and 1');
  }
  if (!_isAccuracy(quiz.perfectMinAccuracy)) {
    errors.add('quiz.perfect.min_accuracy must be between 0 and 1');
  }
  if (!_isPositiveInt(quiz.oneWrongCount)) {
    errors.add('quiz.one_wrong.wrong_count must be a positive integer');
  }
  if (!_isPositiveInt(quiz.twoWrongCount)) {
    errors.add('quiz.two_wrong.wrong_count must be a positive integer');
  }
  if (!_isAccuracy(quiz.goodMinAccuracy)) {
    errors.add('quiz.good.min_accuracy must be between 0 and 1');
  }

  final priority = quiz.routingPriority;
  final required = kRequiredQuizRoutingKeys.toSet();
  final actual = priority.toSet();
  if (priority.length != actual.length) {
    errors.add('quiz.routing_priority must not contain duplicates');
  }
  if (actual.length != required.length || !actual.containsAll(required)) {
    errors.add(
      'quiz.routing_priority must be a permutation of '
      '${kRequiredQuizRoutingKeys.join(', ')} (failure is not routed here)',
    );
  }

  final speed = state.speedQuiz;
  if (!_isPositiveInt(speed.durationSeconds)) {
    errors.add('speed_quiz.duration_seconds must be a positive integer');
  }
  if (!_isPositiveInt(speed.comboMinCombo)) {
    errors.add('speed_quiz.combo_master.min_combo must be a positive integer');
  }
  if (!_isAccuracy(speed.comboMinAccuracy)) {
    errors.add('speed_quiz.combo_master.min_accuracy must be between 0 and 1');
  }
  if (!_isAccuracy(speed.timeExpiredMaxAccuracy)) {
    errors.add('speed_quiz.time_expired.max_accuracy must be between 0 and 1');
  }
  if (!_isAccuracy(speed.moderateMinAccuracy)) {
    errors.add('speed_quiz.moderate.min_accuracy must be between 0 and 1');
  }
  if (speed.highScoreAny.isEmpty) {
    errors.add('speed_quiz.high_score.any must have at least one clause');
  }
  for (var i = 0; i < speed.highScoreAny.length; i++) {
    final clause = speed.highScoreAny[i];
    if (clause.minAccuracy == null && clause.minCorrect == null) {
      errors.add(
        'speed_quiz.high_score.any[$i] needs min_accuracy and/or min_correct',
      );
    }
    if (clause.minAccuracy != null && !_isAccuracy(clause.minAccuracy!)) {
      errors.add(
        'speed_quiz.high_score.any[$i].min_accuracy must be between 0 and 1',
      );
    }
    if (clause.minCorrect != null && clause.minCorrect! < 0) {
      errors.add(
        'speed_quiz.high_score.any[$i].min_correct must be >= 0',
      );
    }
  }

  final bandKeys = state.learnedBands.map((b) => b.key).toList();
  final bandSet = bandKeys.toSet();
  if (bandKeys.length != bandSet.length) {
    errors.add('learned_bands keys must be unique');
  }
  for (final key in kRequiredLearnedBandKeys) {
    if (!bandSet.contains(key)) {
      errors.add('learned_bands is missing required key "$key"');
    }
  }
  for (final band in state.learnedBands) {
    if (band.minPercent < 0 || band.minPercent > 100) {
      errors.add(
        'learned_bands[${band.key}].min_percent must be between 0 and 100',
      );
    }
  }

  if (!_isPositiveInt(state.comebackMinDays)) {
    errors.add('comeback.min_days must be a positive integer');
  }
  if (!_isPositiveInt(state.dailyGoal.targetLevels)) {
    errors.add('daily_goal.target_levels must be a positive integer');
  }
  if (!_isPositiveInt(state.dailyGoal.targetQuestions)) {
    errors.add('daily_goal.target_questions must be a positive integer');
  }

  final slotKeys = state.timeSlots.map((s) => s.key).toList();
  final slotSet = slotKeys.toSet();
  if (slotKeys.length != slotSet.length) {
    errors.add('time_slots keys must be unique');
  }
  for (final key in kRequiredTimeSlotKeys) {
    if (!slotSet.contains(key)) {
      errors.add('time_slots is missing required key "$key"');
    }
  }
  for (final extra in slotSet.difference(kRequiredTimeSlotKeys.toSet())) {
    errors.add('time_slots has unknown key "$extra"');
  }
  for (final slot in state.timeSlots) {
    if (slot.label.trim().isEmpty) {
      errors.add('time_slots[${slot.key}].label must not be empty');
    }
    if (slot.startMinutes == slot.endMinutes) {
      errors.add('time_slots[${slot.key}] start and end must differ');
    }
  }

  void checkLottie(String field, String value) {
    if (value.trim().isEmpty) {
      errors.add('lottie.$field must not be empty');
    } else if (!isValidLottieShortPath(value)) {
      errors.add(
        'lottie.$field "$value" must be a short path (not assets/...)',
      );
    }
  }

  checkLottie('confetti', state.lottie.confetti);
  checkLottie('book_finish', state.lottie.bookFinish);
  checkLottie('level_complete', state.lottie.levelComplete);
  checkLottie('learned_fallback', state.lottie.learnedFallback);
  checkLottie('quiz_loading', state.lottie.quizLoading);
  checkLottie('quiz_fail', state.lottie.quizFail);

  void checkCopy(String field, String value) {
    if (value.trim().isEmpty) {
      errors.add('copy.$field must not be empty');
    }
  }

  checkCopy('dashboard_greeting', state.copy.dashboardGreeting);
  checkCopy('onboarding_greeting', state.copy.onboardingGreeting);
  checkCopy('onboarding_subtitle', state.copy.onboardingSubtitle);
  checkCopy('onboarding_body', state.copy.onboardingBody);
  checkCopy('onboarding_name_prompt', state.copy.onboardingNamePrompt);
  checkCopy('onboarding_name_hint', state.copy.onboardingNameHint);
  checkCopy('default_name', state.copy.defaultName);
  checkCopy('onboarding_empty_name_hint', state.copy.onboardingEmptyNameHint);
  checkCopy('onboarding_start_button', state.copy.onboardingStartButton);

  return errors;
}
