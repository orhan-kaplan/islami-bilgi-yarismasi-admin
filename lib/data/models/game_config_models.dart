const String kGameConfigFileName = 'game_config.json';

int _asInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

double _asDouble(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  return fallback;
}

bool _asBool(Object? value, bool fallback) {
  if (value is bool) return value;
  return fallback;
}

String _asString(Object? value, String fallback) {
  if (value is String && value.isNotEmpty) return value;
  return fallback;
}

int? parseGameConfigHhMm(String raw) {
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

String formatGameConfigHhMm(int totalMinutes) {
  final wrapped = ((totalMinutes % 1440) + 1440) % 1440;
  final hour = wrapped ~/ 60;
  final minute = wrapped % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class ScoreClause {
  const ScoreClause({this.minAccuracy, this.minCorrect});

  final double? minAccuracy;
  final int? minCorrect;

  bool matches({required double accuracy, required int correct}) {
    if (minAccuracy != null && accuracy < minAccuracy!) return false;
    if (minCorrect != null && correct < minCorrect!) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        if (minAccuracy != null) 'min_accuracy': minAccuracy,
        if (minCorrect != null) 'min_correct': minCorrect,
      };

  static ScoreClause fromJson(Map<String, dynamic> json) {
    return ScoreClause(
      minAccuracy: json.containsKey('min_accuracy')
          ? _asDouble(json['min_accuracy'], 0)
          : null,
      minCorrect: json.containsKey('min_correct')
          ? _asInt(json['min_correct'], 0)
          : null,
    );
  }

  ScoreClause copyWith({double? minAccuracy, int? minCorrect}) {
    return ScoreClause(
      minAccuracy: minAccuracy ?? this.minAccuracy,
      minCorrect: minCorrect ?? this.minCorrect,
    );
  }
}

class LearnedBand {
  const LearnedBand({
    required this.key,
    required this.minPercent,
    this.exclusiveMin = false,
  });

  final String key;
  final double minPercent;
  final bool exclusiveMin;

  bool matches(double percentage) {
    return exclusiveMin ? percentage > minPercent : percentage >= minPercent;
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'min_percent': minPercent,
        if (exclusiveMin) 'exclusive_min': true,
      };

  static LearnedBand fromJson(Map<String, dynamic> json) {
    return LearnedBand(
      key: _asString(json['key'], '0'),
      minPercent: _asDouble(json['min_percent'], 0),
      exclusiveMin: _asBool(json['exclusive_min'], false),
    );
  }

  LearnedBand copyWith({
    String? key,
    double? minPercent,
    bool? exclusiveMin,
  }) {
    return LearnedBand(
      key: key ?? this.key,
      minPercent: minPercent ?? this.minPercent,
      exclusiveMin: exclusiveMin ?? this.exclusiveMin,
    );
  }
}

class TimeSlotConfig {
  const TimeSlotConfig({
    required this.key,
    required this.startMinutes,
    required this.endMinutes,
    required this.label,
  });

  final String key;
  final int startMinutes;
  final int endMinutes;
  final String label;

  bool contains(int minutes) {
    if (endMinutes > startMinutes) {
      return minutes >= startMinutes && minutes < endMinutes;
    }
    return minutes >= startMinutes || minutes < endMinutes;
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'start': formatGameConfigHhMm(startMinutes),
        'end': formatGameConfigHhMm(endMinutes),
        'label': label,
      };

  static TimeSlotConfig? tryFromJson(Map<String, dynamic> json) {
    final start = parseGameConfigHhMm(_asString(json['start'], ''));
    final end = parseGameConfigHhMm(_asString(json['end'], ''));
    if (start == null || end == null) return null;
    return TimeSlotConfig(
      key: _asString(json['key'], ''),
      startMinutes: start,
      endMinutes: end,
      label: _asString(json['label'], ''),
    );
  }

  TimeSlotConfig copyWith({
    String? key,
    int? startMinutes,
    int? endMinutes,
    String? label,
  }) {
    return TimeSlotConfig(
      key: key ?? this.key,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      label: label ?? this.label,
    );
  }
}

class QuizGameConfig {
  const QuizGameConfig({
    required this.lives,
    required this.pointsPerCorrect,
    required this.routingPriority,
    required this.speedDemonMaxSecondsPerQuestion,
    required this.speedDemonMinAccuracy,
    required this.perfectMinAccuracy,
    required this.oneWrongCount,
    required this.twoWrongCount,
    required this.goodMinAccuracy,
  });

  final int lives;
  final int pointsPerCorrect;
  final List<String> routingPriority;
  final int speedDemonMaxSecondsPerQuestion;
  final double speedDemonMinAccuracy;
  final double perfectMinAccuracy;
  final int oneWrongCount;
  final int twoWrongCount;
  final double goodMinAccuracy;

  static const defaults = QuizGameConfig(
    lives: 3,
    pointsPerCorrect: 10,
    routingPriority: [
      'speed_demon',
      'perfect',
      'one_wrong',
      'two_wrong',
      'good',
      'moderate',
    ],
    speedDemonMaxSecondsPerQuestion: 10,
    speedDemonMinAccuracy: 0.9,
    perfectMinAccuracy: 1.0,
    oneWrongCount: 1,
    twoWrongCount: 2,
    goodMinAccuracy: 0.7,
  );

  Map<String, dynamic> toJson() => {
        'lives': lives,
        'points_per_correct': pointsPerCorrect,
        'routing_priority': routingPriority,
        'speed_demon': {
          'max_seconds_per_question': speedDemonMaxSecondsPerQuestion,
          'min_accuracy': speedDemonMinAccuracy,
        },
        'perfect': {'min_accuracy': perfectMinAccuracy},
        'one_wrong': {'wrong_count': oneWrongCount},
        'two_wrong': {'wrong_count': twoWrongCount},
        'good': {'min_accuracy': goodMinAccuracy},
      };

  static QuizGameConfig fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    final speedDemon = json['speed_demon'] as Map<String, dynamic>? ?? {};
    final perfect = json['perfect'] as Map<String, dynamic>? ?? {};
    final oneWrong = json['one_wrong'] as Map<String, dynamic>? ?? {};
    final twoWrong = json['two_wrong'] as Map<String, dynamic>? ?? {};
    final good = json['good'] as Map<String, dynamic>? ?? {};
    final priority = json['routing_priority'];
    return QuizGameConfig(
      lives: _asInt(json['lives'], defaults.lives),
      pointsPerCorrect:
          _asInt(json['points_per_correct'], defaults.pointsPerCorrect),
      routingPriority: priority is List && priority.isNotEmpty
          ? priority.map((e) => e.toString()).toList()
          : defaults.routingPriority,
      speedDemonMaxSecondsPerQuestion: _asInt(
        speedDemon['max_seconds_per_question'],
        defaults.speedDemonMaxSecondsPerQuestion,
      ),
      speedDemonMinAccuracy: _asDouble(
        speedDemon['min_accuracy'],
        defaults.speedDemonMinAccuracy,
      ),
      perfectMinAccuracy:
          _asDouble(perfect['min_accuracy'], defaults.perfectMinAccuracy),
      oneWrongCount: _asInt(oneWrong['wrong_count'], defaults.oneWrongCount),
      twoWrongCount: _asInt(twoWrong['wrong_count'], defaults.twoWrongCount),
      goodMinAccuracy:
          _asDouble(good['min_accuracy'], defaults.goodMinAccuracy),
    );
  }

  QuizGameConfig copyWith({
    int? lives,
    int? pointsPerCorrect,
    List<String>? routingPriority,
    int? speedDemonMaxSecondsPerQuestion,
    double? speedDemonMinAccuracy,
    double? perfectMinAccuracy,
    int? oneWrongCount,
    int? twoWrongCount,
    double? goodMinAccuracy,
  }) {
    return QuizGameConfig(
      lives: lives ?? this.lives,
      pointsPerCorrect: pointsPerCorrect ?? this.pointsPerCorrect,
      routingPriority: routingPriority ?? this.routingPriority,
      speedDemonMaxSecondsPerQuestion: speedDemonMaxSecondsPerQuestion ??
          this.speedDemonMaxSecondsPerQuestion,
      speedDemonMinAccuracy:
          speedDemonMinAccuracy ?? this.speedDemonMinAccuracy,
      perfectMinAccuracy: perfectMinAccuracy ?? this.perfectMinAccuracy,
      oneWrongCount: oneWrongCount ?? this.oneWrongCount,
      twoWrongCount: twoWrongCount ?? this.twoWrongCount,
      goodMinAccuracy: goodMinAccuracy ?? this.goodMinAccuracy,
    );
  }
}

class SpeedQuizGameConfig {
  const SpeedQuizGameConfig({
    required this.durationSeconds,
    required this.comboMinCombo,
    required this.comboMinAccuracy,
    required this.highScoreAny,
    required this.timeExpiredOnTimeout,
    required this.timeExpiredMaxAccuracy,
    required this.moderateMinAccuracy,
  });

  final int durationSeconds;
  final int comboMinCombo;
  final double comboMinAccuracy;
  final List<ScoreClause> highScoreAny;
  final bool timeExpiredOnTimeout;
  final double timeExpiredMaxAccuracy;
  final double moderateMinAccuracy;

  static const defaults = SpeedQuizGameConfig(
    durationSeconds: 60,
    comboMinCombo: 10,
    comboMinAccuracy: 0.8,
    highScoreAny: [
      ScoreClause(minAccuracy: 0.85, minCorrect: 12),
      ScoreClause(minCorrect: 15, minAccuracy: 0.8),
    ],
    timeExpiredOnTimeout: true,
    timeExpiredMaxAccuracy: 0.5,
    moderateMinAccuracy: 0.6,
  );

  Map<String, dynamic> toJson() => {
        'duration_seconds': durationSeconds,
        'combo_master': {
          'min_combo': comboMinCombo,
          'min_accuracy': comboMinAccuracy,
        },
        'high_score': {
          'any': highScoreAny.map((c) => c.toJson()).toList(),
        },
        'time_expired': {
          'on_timeout': timeExpiredOnTimeout,
          'max_accuracy': timeExpiredMaxAccuracy,
        },
        'moderate': {'min_accuracy': moderateMinAccuracy},
      };

  static SpeedQuizGameConfig fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    final combo = json['combo_master'] as Map<String, dynamic>? ?? {};
    final high = json['high_score'] as Map<String, dynamic>? ?? {};
    final expired = json['time_expired'] as Map<String, dynamic>? ?? {};
    final moderate = json['moderate'] as Map<String, dynamic>? ?? {};
    final anyRaw = high['any'];
    final clauses = <ScoreClause>[];
    if (anyRaw is List) {
      for (final item in anyRaw) {
        if (item is Map<String, dynamic>) {
          clauses.add(ScoreClause.fromJson(item));
        }
      }
    }
    return SpeedQuizGameConfig(
      durationSeconds:
          _asInt(json['duration_seconds'], defaults.durationSeconds),
      comboMinCombo: _asInt(combo['min_combo'], defaults.comboMinCombo),
      comboMinAccuracy:
          _asDouble(combo['min_accuracy'], defaults.comboMinAccuracy),
      highScoreAny: clauses.isNotEmpty ? clauses : defaults.highScoreAny,
      timeExpiredOnTimeout:
          _asBool(expired['on_timeout'], defaults.timeExpiredOnTimeout),
      timeExpiredMaxAccuracy: _asDouble(
        expired['max_accuracy'],
        defaults.timeExpiredMaxAccuracy,
      ),
      moderateMinAccuracy: _asDouble(
        moderate['min_accuracy'],
        defaults.moderateMinAccuracy,
      ),
    );
  }

  SpeedQuizGameConfig copyWith({
    int? durationSeconds,
    int? comboMinCombo,
    double? comboMinAccuracy,
    List<ScoreClause>? highScoreAny,
    bool? timeExpiredOnTimeout,
    double? timeExpiredMaxAccuracy,
    double? moderateMinAccuracy,
  }) {
    return SpeedQuizGameConfig(
      durationSeconds: durationSeconds ?? this.durationSeconds,
      comboMinCombo: comboMinCombo ?? this.comboMinCombo,
      comboMinAccuracy: comboMinAccuracy ?? this.comboMinAccuracy,
      highScoreAny: highScoreAny ?? this.highScoreAny,
      timeExpiredOnTimeout: timeExpiredOnTimeout ?? this.timeExpiredOnTimeout,
      timeExpiredMaxAccuracy:
          timeExpiredMaxAccuracy ?? this.timeExpiredMaxAccuracy,
      moderateMinAccuracy: moderateMinAccuracy ?? this.moderateMinAccuracy,
    );
  }
}

class DailyGoalGameConfig {
  const DailyGoalGameConfig({
    required this.targetLevels,
    required this.targetQuestions,
  });

  final int targetLevels;
  final int targetQuestions;

  static const defaults = DailyGoalGameConfig(
    targetLevels: 3,
    targetQuestions: 30,
  );

  Map<String, dynamic> toJson() => {
        'target_levels': targetLevels,
        'target_questions': targetQuestions,
      };

  static DailyGoalGameConfig fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return DailyGoalGameConfig(
      targetLevels: _asInt(json['target_levels'], defaults.targetLevels),
      targetQuestions:
          _asInt(json['target_questions'], defaults.targetQuestions),
    );
  }

  DailyGoalGameConfig copyWith({int? targetLevels, int? targetQuestions}) {
    return DailyGoalGameConfig(
      targetLevels: targetLevels ?? this.targetLevels,
      targetQuestions: targetQuestions ?? this.targetQuestions,
    );
  }
}

class LottieGameConfig {
  const LottieGameConfig({
    required this.confetti,
    required this.bookFinish,
    required this.levelComplete,
    required this.learnedFallback,
    required this.quizLoading,
    required this.quizFail,
  });

  final String confetti;
  final String bookFinish;
  final String levelComplete;
  final String learnedFallback;
  final String quizLoading;
  final String quizFail;

  String get confettiAsset => 'assets/lottie/$confetti';
  String get bookFinishAsset => 'assets/lottie/$bookFinish';
  String get levelCompleteAsset => 'assets/lottie/$levelComplete';
  String get learnedFallbackAsset => 'assets/lottie/$learnedFallback';
  String get quizLoadingAsset => 'assets/lottie/$quizLoading';
  String get quizFailAsset => 'assets/lottie/$quizFail';

  static const defaults = LottieGameConfig(
    confetti: 'Confetti.json',
    bookFinish: 'book_finish.json',
    levelComplete: 'trophy.json',
    learnedFallback: 'trophy_2.json',
    quizLoading: 'loading_book.json',
    quizFail: 'wrong.json',
  );

  Map<String, dynamic> toJson() => {
        'confetti': confetti,
        'book_finish': bookFinish,
        'level_complete': levelComplete,
        'learned_fallback': learnedFallback,
        'quiz_loading': quizLoading,
        'quiz_fail': quizFail,
      };

  static LottieGameConfig fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return LottieGameConfig(
      confetti: _asString(json['confetti'], defaults.confetti),
      bookFinish: _asString(json['book_finish'], defaults.bookFinish),
      levelComplete: _asString(json['level_complete'], defaults.levelComplete),
      learnedFallback:
          _asString(json['learned_fallback'], defaults.learnedFallback),
      quizLoading: _asString(json['quiz_loading'], defaults.quizLoading),
      quizFail: _asString(json['quiz_fail'], defaults.quizFail),
    );
  }

  LottieGameConfig copyWith({
    String? confetti,
    String? bookFinish,
    String? levelComplete,
    String? learnedFallback,
    String? quizLoading,
    String? quizFail,
  }) {
    return LottieGameConfig(
      confetti: confetti ?? this.confetti,
      bookFinish: bookFinish ?? this.bookFinish,
      levelComplete: levelComplete ?? this.levelComplete,
      learnedFallback: learnedFallback ?? this.learnedFallback,
      quizLoading: quizLoading ?? this.quizLoading,
      quizFail: quizFail ?? this.quizFail,
    );
  }
}

class CopyGameConfig {
  const CopyGameConfig({
    required this.dashboardGreeting,
    required this.onboardingGreeting,
    required this.onboardingSubtitle,
    required this.onboardingBody,
    required this.onboardingNamePrompt,
    required this.onboardingNameHint,
    required this.defaultName,
    required this.onboardingEmptyNameHint,
    required this.onboardingStartButton,
  });

  final String dashboardGreeting;
  final String onboardingGreeting;
  final String onboardingSubtitle;
  final String onboardingBody;
  final String onboardingNamePrompt;
  final String onboardingNameHint;
  final String defaultName;
  final String onboardingEmptyNameHint;
  final String onboardingStartButton;

  static const defaults = CopyGameConfig(
    dashboardGreeting: 'Esselamü Aleyküm,',
    onboardingGreeting: 'Es-selamü Aleyküm',
    onboardingSubtitle: "İlim Yolculuğu'na Hoş Geldin",
    onboardingBody:
        "Siyer-i Nebi'yi öğrenmek, Efendimiz'in (s.a.v)\nizinden gitmek için ilk adımı attın.",
    onboardingNamePrompt: 'Sana nasıl hitap edelim?',
    onboardingNameHint: 'Adın veya Takma Adın...',
    defaultName: 'İlim Yolcusu',
    onboardingEmptyNameHint:
        "Boş bırakırsan 'İlim Yolcusu' olarak kaydedeceğiz",
    onboardingStartButton: 'Bismillah de ve Başla',
  );

  Map<String, dynamic> toJson() => {
        'dashboard_greeting': dashboardGreeting,
        'onboarding_greeting': onboardingGreeting,
        'onboarding_subtitle': onboardingSubtitle,
        'onboarding_body': onboardingBody,
        'onboarding_name_prompt': onboardingNamePrompt,
        'onboarding_name_hint': onboardingNameHint,
        'default_name': defaultName,
        'onboarding_empty_name_hint': onboardingEmptyNameHint,
        'onboarding_start_button': onboardingStartButton,
      };

  static CopyGameConfig fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return CopyGameConfig(
      dashboardGreeting:
          _asString(json['dashboard_greeting'], defaults.dashboardGreeting),
      onboardingGreeting:
          _asString(json['onboarding_greeting'], defaults.onboardingGreeting),
      onboardingSubtitle:
          _asString(json['onboarding_subtitle'], defaults.onboardingSubtitle),
      onboardingBody:
          _asString(json['onboarding_body'], defaults.onboardingBody),
      onboardingNamePrompt: _asString(
        json['onboarding_name_prompt'],
        defaults.onboardingNamePrompt,
      ),
      onboardingNameHint:
          _asString(json['onboarding_name_hint'], defaults.onboardingNameHint),
      defaultName: _asString(json['default_name'], defaults.defaultName),
      onboardingEmptyNameHint: _asString(
        json['onboarding_empty_name_hint'],
        defaults.onboardingEmptyNameHint,
      ),
      onboardingStartButton: _asString(
        json['onboarding_start_button'],
        defaults.onboardingStartButton,
      ),
    );
  }

  CopyGameConfig copyWith({
    String? dashboardGreeting,
    String? onboardingGreeting,
    String? onboardingSubtitle,
    String? onboardingBody,
    String? onboardingNamePrompt,
    String? onboardingNameHint,
    String? defaultName,
    String? onboardingEmptyNameHint,
    String? onboardingStartButton,
  }) {
    return CopyGameConfig(
      dashboardGreeting: dashboardGreeting ?? this.dashboardGreeting,
      onboardingGreeting: onboardingGreeting ?? this.onboardingGreeting,
      onboardingSubtitle: onboardingSubtitle ?? this.onboardingSubtitle,
      onboardingBody: onboardingBody ?? this.onboardingBody,
      onboardingNamePrompt: onboardingNamePrompt ?? this.onboardingNamePrompt,
      onboardingNameHint: onboardingNameHint ?? this.onboardingNameHint,
      defaultName: defaultName ?? this.defaultName,
      onboardingEmptyNameHint:
          onboardingEmptyNameHint ?? this.onboardingEmptyNameHint,
      onboardingStartButton:
          onboardingStartButton ?? this.onboardingStartButton,
    );
  }
}

/// Editable game / copy / feedback-routing config (`data/game_config.json`).
/// Missing JSON keeps [defaults]. Not part of ContentState.
class GameConfigState {
  const GameConfigState({
    required this.quiz,
    required this.speedQuiz,
    required this.learnedBands,
    required this.comebackMinDays,
    required this.dailyGoal,
    required this.timeSlots,
    required this.lottie,
    required this.copy,
  });

  final QuizGameConfig quiz;
  final SpeedQuizGameConfig speedQuiz;
  final List<LearnedBand> learnedBands;
  final int comebackMinDays;
  final DailyGoalGameConfig dailyGoal;
  final List<TimeSlotConfig> timeSlots;
  final LottieGameConfig lottie;
  final CopyGameConfig copy;

  static const defaults = GameConfigState(
    quiz: QuizGameConfig.defaults,
    speedQuiz: SpeedQuizGameConfig.defaults,
    learnedBands: [
      LearnedBand(key: '100', minPercent: 100),
      LearnedBand(key: '75', minPercent: 75),
      LearnedBand(key: '50', minPercent: 50),
      LearnedBand(key: '25', minPercent: 0, exclusiveMin: true),
      LearnedBand(key: '0', minPercent: 0),
    ],
    comebackMinDays: 3,
    dailyGoal: DailyGoalGameConfig.defaults,
    timeSlots: [
      TimeSlotConfig(
        key: 'seher',
        startMinutes: 270,
        endMinutes: 420,
        label: 'Seher Bülbülü',
      ),
      TimeSlotConfig(
        key: 'morning',
        startMinutes: 420,
        endMinutes: 660,
        label: 'Sabah Seyyahı',
      ),
      TimeSlotConfig(
        key: 'noon',
        startMinutes: 660,
        endMinutes: 840,
        label: 'Vakit Sarrafı',
      ),
      TimeSlotConfig(
        key: 'afternoon',
        startMinutes: 840,
        endMinutes: 1140,
        label: 'Gündüz Süvarisi',
      ),
      TimeSlotConfig(
        key: 'evening',
        startMinutes: 1140,
        endMinutes: 1380,
        label: 'Huzur Yolcusu',
      ),
      TimeSlotConfig(
        key: 'night',
        startMinutes: 1380,
        endMinutes: 120,
        label: 'Gece Kuşu',
      ),
      TimeSlotConfig(
        key: 'teheccud',
        startMinutes: 120,
        endMinutes: 270,
        label: 'Teheccüd Ehli',
      ),
    ],
    lottie: LottieGameConfig.defaults,
    copy: CopyGameConfig.defaults,
  );

  Map<String, dynamic> toJson() => {
        'quiz': quiz.toJson(),
        'speed_quiz': speedQuiz.toJson(),
        'learned_bands': learnedBands.map((b) => b.toJson()).toList(),
        'comeback': {'min_days': comebackMinDays},
        'daily_goal': dailyGoal.toJson(),
        'time_slots': timeSlots.map((s) => s.toJson()).toList(),
        'lottie': lottie.toJson(),
        'copy': copy.toJson(),
      };

  static GameConfigState fromJson(Map<String, dynamic> json) {
    final bandsRaw = json['learned_bands'];
    final bands = <LearnedBand>[];
    if (bandsRaw is List) {
      for (final item in bandsRaw) {
        if (item is Map<String, dynamic>) {
          bands.add(LearnedBand.fromJson(item));
        }
      }
    }
    final slotsRaw = json['time_slots'];
    final slots = <TimeSlotConfig>[];
    if (slotsRaw is List) {
      for (final item in slotsRaw) {
        if (item is Map<String, dynamic>) {
          final slot = TimeSlotConfig.tryFromJson(item);
          if (slot != null && slot.key.isNotEmpty) slots.add(slot);
        }
      }
    }
    final comeback = json['comeback'] as Map<String, dynamic>?;
    return GameConfigState(
      quiz: QuizGameConfig.fromJson(json['quiz'] as Map<String, dynamic>?),
      speedQuiz: SpeedQuizGameConfig.fromJson(
        json['speed_quiz'] as Map<String, dynamic>?,
      ),
      learnedBands: bands.isNotEmpty ? bands : defaults.learnedBands,
      comebackMinDays: _asInt(comeback?['min_days'], defaults.comebackMinDays),
      dailyGoal: DailyGoalGameConfig.fromJson(
        json['daily_goal'] as Map<String, dynamic>?,
      ),
      timeSlots: slots.isNotEmpty ? slots : defaults.timeSlots,
      lottie: LottieGameConfig.fromJson(json['lottie'] as Map<String, dynamic>?),
      copy: CopyGameConfig.fromJson(json['copy'] as Map<String, dynamic>?),
    );
  }

  GameConfigState copyWith({
    QuizGameConfig? quiz,
    SpeedQuizGameConfig? speedQuiz,
    List<LearnedBand>? learnedBands,
    int? comebackMinDays,
    DailyGoalGameConfig? dailyGoal,
    List<TimeSlotConfig>? timeSlots,
    LottieGameConfig? lottie,
    CopyGameConfig? copy,
  }) {
    return GameConfigState(
      quiz: quiz ?? this.quiz,
      speedQuiz: speedQuiz ?? this.speedQuiz,
      learnedBands: learnedBands ?? this.learnedBands,
      comebackMinDays: comebackMinDays ?? this.comebackMinDays,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      timeSlots: timeSlots ?? this.timeSlots,
      lottie: lottie ?? this.lottie,
      copy: copy ?? this.copy,
    );
  }
}
