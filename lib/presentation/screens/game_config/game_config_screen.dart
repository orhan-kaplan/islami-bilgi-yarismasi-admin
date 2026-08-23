import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/game_config_models.dart';
import '../../../data/services/game_config_validator.dart';
import '../../providers/connectivity_providers.dart';
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
    final isConnected = ref.watch(isServerConnectedProvider);
    // Bağlantı yokken auto-save sessizce atlıyor; bekleyen değişikliğin
    // yeniden hesaplanması için state'i izlemek gerekiyor.
    ref.watch(gameConfigProvider);
    final hasPendingChange =
        ref.read(gameConfigAutoSaveProvider.notifier).hasPendingChange;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Config'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _SaveStatusChip(
                status: saveStatus,
                isConnected: isConnected,
                hasPendingChange: hasPendingChange,
              ),
            ),
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
                const Text('Could not load game settings.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(gameConfigLoadProvider.notifier).performLoad(force: true),
                  child: const Text('Retry'),
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
  const _SaveStatusChip({
    required this.status,
    required this.isConnected,
    required this.hasPendingChange,
  });

  final GameConfigSaveStatus status;
  final bool isConnected;
  final bool hasPendingChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Bağlantı kopunca yazma sessizce atlanıyor ama chip son "Kaydedildi"de
    // donuyordu; kullanıcı çevrimdışı düzenlemeye devam edip kaydedildiğini
    // sanıyordu.
    if (!isConnected) {
      return Chip(
        label: Text(hasPendingChange ? 'Offline — not saved' : 'Offline'),
        visualDensity: VisualDensity.compact,
        backgroundColor: (hasPendingChange ? scheme.error : scheme.outline)
            .withValues(alpha: 0.15),
      );
    }

    final (label, color) = switch (status) {
      GameConfigSaveStatus.idle => ('Idle', Colors.grey),
      GameConfigSaveStatus.saving => ('Saving', Colors.blue),
      GameConfigSaveStatus.saved => ('Saved', Colors.green),
      GameConfigSaveStatus.error => ('Save failed', Colors.red),
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
          // Banner esnek olmayan bir Column çocuğuydu: birkaç alan bozulunca
          // kısa pencerede formu ezip taşıyordu. Sabit renk yerine tema
          // token'ları — koyu temada açık pembe zemin okunmuyordu.
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saving is blocked — fix these errors:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 132),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: errors
                            .map((e) => Text(
                                  '• $e',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
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
              label: 'Lives',
              value: state.quiz.lives,
              onChanged: (v) => notifier.importContent(
                state.copyWith(quiz: state.quiz.copyWith(lives: v)),
              ),
            ),
            _IntField(
              label: 'Points per correct answer',
              value: state.quiz.pointsPerCorrect,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  quiz: state.quiz.copyWith(pointsPerCorrect: v),
                ),
              ),
            ),
            _IntField(
              label: 'Speed demon — max seconds per question',
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
              label: 'Speed demon — min accuracy (0–1)',
              value: state.quiz.speedDemonMinAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  quiz: state.quiz.copyWith(speedDemonMinAccuracy: v),
                ),
              ),
            ),
            _DoubleField(
              label: 'Perfect — min accuracy (0–1)',
              value: state.quiz.perfectMinAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  quiz: state.quiz.copyWith(perfectMinAccuracy: v),
                ),
              ),
            ),
            _IntField(
              label: 'One wrong — wrong count',
              value: state.quiz.oneWrongCount,
              onChanged: (v) => notifier.importContent(
                state.copyWith(quiz: state.quiz.copyWith(oneWrongCount: v)),
              ),
            ),
            _IntField(
              label: 'Two wrong — wrong count',
              value: state.quiz.twoWrongCount,
              onChanged: (v) => notifier.importContent(
                state.copyWith(quiz: state.quiz.copyWith(twoWrongCount: v)),
              ),
            ),
            _DoubleField(
              label: 'Good — min accuracy (0–1)',
              value: state.quiz.goodMinAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  quiz: state.quiz.copyWith(goodMinAccuracy: v),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Routing order (failure excluded; drag to reorder)',
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
          title: 'Speed Quiz',
          children: [
            _IntField(
              label: 'Duration (seconds)',
              value: state.speedQuiz.durationSeconds,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz: state.speedQuiz.copyWith(durationSeconds: v),
                ),
              ),
            ),
            _IntField(
              label: 'Combo master — min combo',
              value: state.speedQuiz.comboMinCombo,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz: state.speedQuiz.copyWith(comboMinCombo: v),
                ),
              ),
            ),
            _DoubleField(
              label: 'Combo master — min accuracy (0–1)',
              value: state.speedQuiz.comboMinAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz: state.speedQuiz.copyWith(comboMinAccuracy: v),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Time expired — triggered by timeout'),
              value: state.speedQuiz.timeExpiredOnTimeout,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz: state.speedQuiz.copyWith(timeExpiredOnTimeout: v),
                ),
              ),
            ),
            _DoubleField(
              label: 'Time expired — max accuracy (0–1)',
              value: state.speedQuiz.timeExpiredMaxAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz:
                      state.speedQuiz.copyWith(timeExpiredMaxAccuracy: v),
                ),
              ),
            ),
            _DoubleField(
              label: 'Moderate — min accuracy (0–1)',
              value: state.speedQuiz.moderateMinAccuracy,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  speedQuiz: state.speedQuiz.copyWith(moderateMinAccuracy: v),
                ),
              ),
            ),
            const Text(
              'High score — any clause (OR of AND)',
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
          title: 'Learned bands',
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
          title: 'Daily goal / Comeback',
          children: [
            _IntField(
              label: 'Comeback min days',
              value: state.comebackMinDays,
              onChanged: (v) => notifier.importContent(
                state.copyWith(comebackMinDays: v),
              ),
            ),
            _IntField(
              label: 'Daily goal — levels',
              value: state.dailyGoal.targetLevels,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  dailyGoal: state.dailyGoal.copyWith(targetLevels: v),
                ),
              ),
            ),
            _IntField(
              label: 'Daily goal — questions',
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
          title: 'Time slots (dashboard heading)',
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
          title: 'Lottie (short paths; the app adds the assets/lottie/ prefix)',
          children: [
            _StringField(
              label: 'Confetti',
              value: state.lottie.confetti,
              onChanged: (v) => notifier.importContent(
                state.copyWith(lottie: state.lottie.copyWith(confetti: v)),
              ),
            ),
            _StringField(
              label: 'Book finish',
              value: state.lottie.bookFinish,
              onChanged: (v) => notifier.importContent(
                state.copyWith(lottie: state.lottie.copyWith(bookFinish: v)),
              ),
            ),
            _StringField(
              label: 'Level complete',
              value: state.lottie.levelComplete,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  lottie: state.lottie.copyWith(levelComplete: v),
                ),
              ),
            ),
            _StringField(
              label: 'Learned fallback',
              value: state.lottie.learnedFallback,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  lottie: state.lottie.copyWith(learnedFallback: v),
                ),
              ),
            ),
            _StringField(
              label: 'Quiz loading',
              value: state.lottie.quizLoading,
              onChanged: (v) => notifier.importContent(
                state.copyWith(lottie: state.lottie.copyWith(quizLoading: v)),
              ),
            ),
            _StringField(
              label: 'Quiz fail',
              value: state.lottie.quizFail,
              onChanged: (v) => notifier.importContent(
                state.copyWith(lottie: state.lottie.copyWith(quizFail: v)),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Copy',
          children: [
            _StringField(
              label: 'Dashboard greeting',
              value: state.copy.dashboardGreeting,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(dashboardGreeting: v),
                ),
              ),
            ),
            _StringField(
              label: 'Onboarding greeting',
              value: state.copy.onboardingGreeting,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(onboardingGreeting: v),
                ),
              ),
            ),
            _StringField(
              label: 'Onboarding subtitle',
              value: state.copy.onboardingSubtitle,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(onboardingSubtitle: v),
                ),
              ),
            ),
            _StringField(
              label: 'Onboarding body',
              value: state.copy.onboardingBody,
              maxLines: 3,
              onChanged: (v) => notifier.importContent(
                state.copyWith(copy: state.copy.copyWith(onboardingBody: v)),
              ),
            ),
            _StringField(
              label: 'Name prompt',
              value: state.copy.onboardingNamePrompt,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(onboardingNamePrompt: v),
                ),
              ),
            ),
            _StringField(
              label: 'Name hint',
              value: state.copy.onboardingNameHint,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(onboardingNameHint: v),
                ),
              ),
            ),
            _StringField(
              label: 'Default display name (not a title)',
              value: state.copy.defaultName,
              onChanged: (v) => notifier.importContent(
                state.copyWith(copy: state.copy.copyWith(defaultName: v)),
              ),
            ),
            _StringField(
              label: 'Empty name warning',
              value: state.copy.onboardingEmptyNameHint,
              onChanged: (v) => notifier.importContent(
                state.copyWith(
                  copy: state.copy.copyWith(onboardingEmptyNameHint: v),
                ),
              ),
            ),
            _StringField(
              label: 'Start button',
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

const String _emptyValueError = 'Enter a value — the saved value is unchanged.';
const String _wholeNumberError =
    'Whole number expected — the saved value is unchanged.';
const String _numberError = 'Number expected — the saved value is unchanged.';
const String _clockError =
    'Use HH:mm between 00:00 and 23:59 — the saved value is unchanged.';

/// Parse edilemeyen giriş sessizce yutuluyordu: alan yeni metni gösteriyor,
/// state eski değerinde kalıyor ve kullanıcıya hiçbir şey söylenmiyordu.
/// [onChanged] girişi kabul ederse `null`, etmezse gösterilecek hatayı döner.
class _ValidatedField extends StatefulWidget {
  const _ValidatedField({
    required this.label,
    required this.initialText,
    required this.onChanged,
    this.keyboardType,
  });

  final String label;
  final String initialText;
  final String? Function(String raw) onChanged;
  final TextInputType? keyboardType;

  @override
  State<_ValidatedField> createState() => _ValidatedFieldState();
}

class _ValidatedFieldState extends State<_ValidatedField> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: widget.initialText,
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _error,
          errorMaxLines: 3,
        ),
        keyboardType: widget.keyboardType,
        onChanged: (raw) {
          final error = widget.onChanged(raw);
          if (error != _error) setState(() => _error = error);
        },
      ),
    );
  }
}

String? _acceptInt(String raw, ValueChanged<int> onParsed) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return _emptyValueError;
  final parsed = int.tryParse(trimmed);
  if (parsed == null) return _wholeNumberError;
  onParsed(parsed);
  return null;
}

String? _acceptDouble(String raw, ValueChanged<double> onParsed) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return _emptyValueError;
  final parsed = double.tryParse(trimmed);
  if (parsed == null) return _numberError;
  onParsed(parsed);
  return null;
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
    return _ValidatedField(
      label: label,
      initialText: '$value',
      keyboardType: TextInputType.number,
      onChanged: (raw) => _acceptInt(raw, onChanged),
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
    return _ValidatedField(
      label: label,
      initialText: '$value',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (raw) => _acceptDouble(raw, onChanged),
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
            child: _ValidatedField(
              label: 'Clause ${index + 1} min accuracy',
              initialText: clause.minAccuracy?.toString() ?? '',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (raw) {
                // Boş = "bu koşul yok"; geçersiz metin sessizce boşa
                // düşmemeli.
                final trimmed = raw.trim();
                if (trimmed.isEmpty) {
                  onChanged(ScoreClause(minCorrect: clause.minCorrect));
                  return null;
                }
                final parsed = double.tryParse(trimmed);
                if (parsed == null) return _numberError;
                onChanged(ScoreClause(
                  minAccuracy: parsed,
                  minCorrect: clause.minCorrect,
                ));
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ValidatedField(
              label: 'Clause ${index + 1} min correct',
              initialText: clause.minCorrect?.toString() ?? '',
              keyboardType: TextInputType.number,
              onChanged: (raw) {
                final trimmed = raw.trim();
                if (trimmed.isEmpty) {
                  onChanged(ScoreClause(minAccuracy: clause.minAccuracy));
                  return null;
                }
                final parsed = int.tryParse(trimmed);
                if (parsed == null) return _wholeNumberError;
                onChanged(ScoreClause(
                  minAccuracy: clause.minAccuracy,
                  minCorrect: parsed,
                ));
                return null;
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
            child: _ValidatedField(
              label: 'min_percent',
              initialText: '${band.minPercent}',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (raw) => _acceptDouble(
                raw,
                (parsed) => onChanged(band.copyWith(minPercent: parsed)),
              ),
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
                child: _ValidatedField(
                  label: 'Start (HH:mm)',
                  initialText: formatGameConfigHhMm(slot.startMinutes),
                  onChanged: (raw) {
                    final parsed = parseGameConfigHhMm(raw.trim());
                    if (parsed == null) return _clockError;
                    onChanged(slot.copyWith(startMinutes: parsed));
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ValidatedField(
                  label: 'End (HH:mm)',
                  initialText: formatGameConfigHhMm(slot.endMinutes),
                  onChanged: (raw) {
                    final parsed = parseGameConfigHhMm(raw.trim());
                    if (parsed == null) return _clockError;
                    onChanged(slot.copyWith(endMinutes: parsed));
                    return null;
                  },
                ),
              ),
            ],
          ),
          TextFormField(
            initialValue: slot.label,
            decoration: const InputDecoration(labelText: 'Label'),
            onChanged: (v) => onChanged(slot.copyWith(label: v)),
          ),
        ],
      ),
    );
  }
}
