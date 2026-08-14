import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/game_config_models.dart';
import '../../../data/services/game_config_validator.dart';
import '../../providers/game_config_auto_save_providers.dart';
import '../../providers/game_config_providers.dart';

class GameConfigScreen extends ConsumerWidget {
  const GameConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadStatus = ref.watch(gameConfigLoadProvider);
    final saveStatus = ref.watch(gameConfigAutoSaveProvider);
    final state = ref.watch(gameConfigProvider);
    final errors = validateGameConfigData(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyun'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _SaveStatusChip(status: saveStatus)),
          ),
        ],
      ),
      body: switch (loadStatus) {
        GameConfigLoadStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        GameConfigLoadStatus.failed => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Oyun ayarları yüklenemedi.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(gameConfigLoadProvider.notifier).performLoad(),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        GameConfigLoadStatus.idle ||
        GameConfigLoadStatus.loaded =>
          _GameConfigForm(state: state, errors: errors),
      },
    );
  }
}

class _SaveStatusChip extends StatelessWidget {
  const _SaveStatusChip({required this.status});

  final GameConfigSaveStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      GameConfigSaveStatus.idle => ('Hazır', Colors.grey),
      GameConfigSaveStatus.saving => ('Kaydediliyor', Colors.blue),
      GameConfigSaveStatus.saved => ('Kaydedildi', Colors.green),
      GameConfigSaveStatus.error => ('Kayıt hatası', Colors.red),
    };
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.15),
    );
  }
}

class _GameConfigForm extends ConsumerWidget {
  const _GameConfigForm({required this.state, required this.errors});

  final GameConfigState state;
  final List<String> errors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameConfigProvider.notifier);

    return Column(
      children: [
        if (errors.isNotEmpty)
          Material(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kayıt bloklandı — hataları düzeltin:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...errors.map((e) => Text('• $e')),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
        _Section(
          title: 'Quiz',
          children: [
            _IntField(
              label: 'Can (lives)',
              value: state.quiz.lives,
              onChanged: (v) => notifier.importContent(
                state.copyWith(quiz: state.quiz.copyWith(lives: v)),
              ),
            ),
            _IntField(
              label: 'Doğru cevap puanı',
              value: state.quiz.pointsPerCorrect,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  quiz: state.quiz.copyWith(pointsPerCorrect: v),
                ),
              ),
            ),
            _IntField(
              label: 'Hız canavarı — soru başı max saniye',
              value: state.quiz.speedDemonMaxSecondsPerQuestion,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  quiz: state.quiz.copyWith(
                    speedDemonMaxSecondsPerQuestion: v,
                  ),
                ),
              ),
            ),
            _DoubleField(
              label: 'Hız canavarı — min doğruluk (0–1)',
              value: state.quiz.speedDemonMinAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  quiz: state.quiz.copyWith(speedDemonMinAccuracy: v),
                ),
              ),
            ),
            _DoubleField(
              label: 'Mükemmel — min doğruluk (0–1)',
              value: state.quiz.perfectMinAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  quiz: state.quiz.copyWith(perfectMinAccuracy: v),
                ),
              ),
            ),
            _IntField(
              label: 'Tek yanlış — yanlış sayısı',
              value: state.quiz.oneWrongCount,
              onChanged: (v) => notifier.importContent(
                state.copyWith(quiz: state.quiz.copyWith(oneWrongCount: v)),
              ),
            ),
            _IntField(
              label: 'İki yanlış — yanlış sayısı',
              value: state.quiz.twoWrongCount,
              onChanged: (v) => notifier.importContent(
                state.copyWith(quiz: state.quiz.copyWith(twoWrongCount: v)),
              ),
            ),
            _DoubleField(
              label: 'İyi performans — min doğruluk (0–1)',
              value: state.quiz.goodMinAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  quiz: state.quiz.copyWith(goodMinAccuracy: v),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Yönlendirme sırası (failure hariç; sürükleyerek değiştir)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                final list = [...state.quiz.routingPriority];
                if (newIndex > oldIndex) newIndex--;
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
                notifier.importContent(
                  state.copyWith(
                    quiz: state.quiz.copyWith(routingPriority: list),
                  ),
                );
              },
              children: [
                for (final key in state.quiz.routingPriority)
                  ListTile(
                    key: ValueKey(key),
                    title: Text(key),
                    leading: const Icon(Icons.drag_handle),
                  ),
              ],
            ),
          ],
        ),
        _Section(
          title: 'Hızlı Quiz',
          children: [
            _IntField(
              label: 'Süre (saniye)',
              value: state.speedQuiz.durationSeconds,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz: state.speedQuiz.copyWith(durationSeconds: v),
                ),
              ),
            ),
            _IntField(
              label: 'Kombo ustası — min kombo',
              value: state.speedQuiz.comboMinCombo,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz: state.speedQuiz.copyWith(comboMinCombo: v),
                ),
              ),
            ),
            _DoubleField(
              label: 'Kombo ustası — min doğruluk (0–1)',
              value: state.speedQuiz.comboMinAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz: state.speedQuiz.copyWith(comboMinAccuracy: v),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Süre doldu — timeout tetikler'),
              value: state.speedQuiz.timeExpiredOnTimeout,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz: state.speedQuiz.copyWith(timeExpiredOnTimeout: v),
                ),
              ),
            ),
            _DoubleField(
              label: 'Süre doldu — max doğruluk (0–1)',
              value: state.speedQuiz.timeExpiredMaxAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz:
                      state.speedQuiz.copyWith(timeExpiredMaxAccuracy: v),
                ),
              ),
            ),
            _DoubleField(
              label: 'Orta — min doğruluk (0–1)',
              value: state.speedQuiz.moderateMinAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz: state.speedQuiz.copyWith(moderateMinAccuracy: v),
                ),
              ),
            ),
            const Text(
              'Yüksek skor — herhangi biri (OR of AND)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            for (var i = 0; i < state.speedQuiz.highScoreAny.length; i++)
              _HighScoreClauseRow(
                index: i,
                clause: state.speedQuiz.highScoreAny[i],
                onChanged: (clause) {
                  final next = [...state.speedQuiz.highScoreAny];
                  next[i] = clause;
                  notifier.importContent(
                    state.copyWith(
                      speedQuiz: state.speedQuiz.copyWith(highScoreAny: next),
                    ),
                  );
                },
              ),
          ],
        ),
        _Section(
          title: 'Öğrenilen bilgi bantları',
          children: [
            for (var i = 0; i < state.learnedBands.length; i++)
              _LearnedBandRow(
                band: state.learnedBands[i],
                onChanged: (band) {
                  final next = [...state.learnedBands];
                  next[i] = band;
                  notifier.importContent(state.copyWith(learnedBands: next));
                },
              ),
          ],
        ),
        _Section(
          title: 'Günlük hedef / Geri dönüş',
          children: [
            _IntField(
              label: 'Geri dönüş min gün',
              value: state.comebackMinDays,
              onChanged: (v) => notifier.importContent(
                state.copyWith(comebackMinDays: v),
              ),
            ),
            _IntField(
              label: 'Günlük hedef — level',
              value: state.dailyGoal.targetLevels,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  dailyGoal: state.dailyGoal.copyWith(targetLevels: v),
                ),
              ),
            ),
            _IntField(
              label: 'Günlük hedef — soru',
              value: state.dailyGoal.targetQuestions,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  dailyGoal: state.dailyGoal.copyWith(targetQuestions: v),
                ),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Saat dilimleri (dashboard başlığı)',
          children: [
            for (var i = 0; i < state.timeSlots.length; i++)
              _TimeSlotRow(
                slot: state.timeSlots[i],
                onChanged: (slot) {
                  final next = [...state.timeSlots];
                  next[i] = slot;
                  notifier.importContent(state.copyWith(timeSlots: next));
                },
              ),
          ],
        ),
        _Section(
          title: 'Lottie (kısa yol, assets/lottie/ öneki uygulamada eklenir)',
          children: [
            _StringField(
              label: 'Confetti',
              value: state.lottie.confetti,
              onChanged: (v) => notifier.importContent(
                state.copyWith(lottie: state.lottie.copyWith(confetti: v)),
              ),
            ),
            _StringField(
              label: 'Kitap bitiş',
              value: state.lottie.bookFinish,
              onChanged: (v) => notifier.importContent(
                state.copyWith(lottie: state.lottie.copyWith(bookFinish: v)),
              ),
            ),
            _StringField(
              label: 'Level tamamlandı',
              value: state.lottie.levelComplete,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  lottie: state.lottie.copyWith(levelComplete: v),
                ),
              ),
            ),
            _StringField(
              label: 'Öğrenilen fallback',
              value: state.lottie.learnedFallback,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  lottie: state.lottie.copyWith(learnedFallback: v),
                ),
              ),
            ),
            _StringField(
              label: 'Quiz yükleme',
              value: state.lottie.quizLoading,
              onChanged: (v) => notifier.importContent(
                state.copyWith(lottie: state.lottie.copyWith(quizLoading: v)),
              ),
            ),
            _StringField(
              label: 'Quiz başarısız',
              value: state.lottie.quizFail,
              onChanged: (v) => notifier.importContent(
                state.copyWith(lottie: state.lottie.copyWith(quizFail: v)),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Metinler',
          children: [
            _StringField(
              label: 'Dashboard selamlama',
              value: state.copy.dashboardGreeting,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(dashboardGreeting: v),
                ),
              ),
            ),
            _StringField(
              label: 'Onboarding selamlama',
              value: state.copy.onboardingGreeting,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(onboardingGreeting: v),
                ),
              ),
            ),
            _StringField(
              label: 'Onboarding alt başlık',
              value: state.copy.onboardingSubtitle,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(onboardingSubtitle: v),
                ),
              ),
            ),
            _StringField(
              label: 'Onboarding gövde',
              value: state.copy.onboardingBody,
              maxLines: 3,
              onChanged: (v) => notifier.importContent(
                state.copyWith(copy: state.copy.copyWith(onboardingBody: v)),
              ),
            ),
            _StringField(
              label: 'İsim sorusu',
              value: state.copy.onboardingNamePrompt,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(onboardingNamePrompt: v),
                ),
              ),
            ),
            _StringField(
              label: 'İsim ipucu',
              value: state.copy.onboardingNameHint,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(onboardingNameHint: v),
                ),
              ),
            ),
            _StringField(
              label: 'Varsayılan görünen ad (ünvan değil)',
              value: state.copy.defaultName,
              onChanged: (v) => notifier.importContent(
                state.copyWith(copy: state.copy.copyWith(defaultName: v)),
              ),
            ),
            _StringField(
              label: 'Boş isim uyarısı',
              value: state.copy.onboardingEmptyNameHint,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(onboardingEmptyNameHint: v),
                ),
              ),
            ),
            _StringField(
              label: 'Başla butonu',
              value: state.copy.onboardingStartButton,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(onboardingStartButton: v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: '$value',
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        onChanged: (raw) {
          final parsed = int.tryParse(raw);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }
}

class _DoubleField extends StatelessWidget {
  const _DoubleField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: '$value',
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (raw) {
          final parsed = double.tryParse(raw);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }
}

class _StringField extends StatelessWidget {
  const _StringField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }
}

class _HighScoreClauseRow extends StatelessWidget {
  const _HighScoreClauseRow({
    required this.index,
    required this.clause,
    required this.onChanged,
  });

  final int index;
  final ScoreClause clause;
  final ValueChanged<ScoreClause> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: clause.minAccuracy?.toString() ?? '',
              decoration: InputDecoration(
                labelText: 'Clause ${index + 1} min doğruluk',
              ),
              onChanged: (raw) {
                onChanged(
                  ScoreClause(
                    minAccuracy: double.tryParse(raw),
                    minCorrect: clause.minCorrect,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: clause.minCorrect?.toString() ?? '',
              decoration: InputDecoration(
                labelText: 'Clause ${index + 1} min doğru',
              ),
              onChanged: (raw) {
                onChanged(
                  ScoreClause(
                    minAccuracy: clause.minAccuracy,
                    minCorrect: int.tryParse(raw),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnedBandRow extends StatelessWidget {
  const _LearnedBandRow({required this.band, required this.onChanged});

  final LearnedBand band;
  final ValueChanged<LearnedBand> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(band.key)),
          Expanded(
            child: TextFormField(
              initialValue: '${band.minPercent}',
              decoration: const InputDecoration(labelText: 'min_percent'),
              onChanged: (raw) {
                final parsed = double.tryParse(raw);
                if (parsed != null) {
                  onChanged(band.copyWith(minPercent: parsed));
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('exclusive_min'),
            selected: band.exclusiveMin,
            onSelected: (v) => onChanged(band.copyWith(exclusiveMin: v)),
          ),
        ],
      ),
    );
  }
}

class _TimeSlotRow extends StatelessWidget {
  const _TimeSlotRow({required this.slot, required this.onChanged});

  final TimeSlotConfig slot;
  final ValueChanged<TimeSlotConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(slot.key, style: const TextStyle(fontWeight: FontWeight.w600)),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: formatGameConfigHhMm(slot.startMinutes),
                  decoration: const InputDecoration(labelText: 'Başlangıç (HH:mm)'),
                  onChanged: (raw) {
                    final parsed = parseGameConfigHhMm(raw);
                    if (parsed != null) {
                      onChanged(slot.copyWith(startMinutes: parsed));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: formatGameConfigHhMm(slot.endMinutes),
                  decoration: const InputDecoration(labelText: 'Bitiş (HH:mm)'),
                  onChanged: (raw) {
                    final parsed = parseGameConfigHhMm(raw);
                    if (parsed != null) {
                      onChanged(slot.copyWith(endMinutes: parsed));
                    }
                  },
                ),
              ),
            ],
          ),
          TextFormField(
            initialValue: slot.label,
            decoration: const InputDecoration(labelText: 'Etiket'),
            onChanged: (v) => onChanged(slot.copyWith(label: v)),
          ),
        ],
      ),
    );
  }
}
