import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/feedback_models.dart';
import '../../../data/models/game_config_models.dart';
import '../../providers/feedback_content_providers.dart';
import '../../providers/game_config_providers.dart';
import '../../widgets/feedback_card.dart';
import '../../widgets/title_card.dart';

/// Screen for managing feedback content across all categories.
///
/// Contains a [TabBar] with 7 tabs (with message count badges):
/// Quiz, Speed Quiz, Time, Comeback, Streak, Titles, Learned.
/// Each tab displays collapsible sections with drag & drop reordering.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// Maps tab index to category key used in the provider.
  static const _categoryKeys = [
    'quiz',
    'speed_quiz',
    'time',
    'comeback',
    'streak',
    'titles',
    'learned',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loadStatus = ref.watch(feedbackLoadProvider);
    final feedbackState = ref.watch(feedbackContentProvider);
    final gameConfig = ref.watch(gameConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Mesaj ara...',
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.titleMedium,
              )
            : const Text('Feedback'),
        actions: [
          if (loadStatus == FeedbackLoadStatus.loaded)
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              tooltip: _isSearching ? 'Aramayı kapat' : 'Mesaj ara',
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
            ),
        ],
        bottom: _isSearching
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: _buildTabs(feedbackState),
              ),
      ),
      body: _isSearching && _searchQuery.isNotEmpty
          ? _buildSearchResults(feedbackState, gameConfig)
          : _buildBody(loadStatus, feedbackState, gameConfig),
      floatingActionButton: _isSearching ? null : _buildFab(loadStatus),
    );
  }

  /// Builds search results across all categories.
  Widget _buildSearchResults(
    FeedbackContentState state,
    GameConfigState gameConfig,
  ) {
    final results = <_SearchResult>[];

    void searchInMap(Map<String, List<FeedbackMessageModel>> map, String category, Map<String, _SubcategoryMeta> meta) {
      for (final entry in map.entries) {
        final subcategory = entry.key;
        final label = meta[subcategory]?.label ?? subcategory;
        for (var i = 0; i < entry.value.length; i++) {
          final msg = entry.value[i];
          if (_matchesSearch(msg)) {
            results.add(_SearchResult(
              message: msg,
              index: i,
              category: category,
              subcategory: subcategory,
              sectionLabel: label,
            ));
          }
        }
      }
    }

    searchInMap(state.quiz, 'quiz', _quizMetaFrom(gameConfig));
    searchInMap(state.speedQuiz, 'speed_quiz', _speedQuizMetaFrom(gameConfig));
    searchInMap(state.time, 'time', _timeMetaFrom(gameConfig));
    searchInMap(state.streak, 'streak', _streakMetaFrom(state));
    searchInMap(state.learned, 'learned', _learnedMetaFrom(gameConfig));

    // Comeback (flat)
    for (var i = 0; i < state.comeback.length; i++) {
      if (_matchesSearch(state.comeback[i])) {
        results.add(_SearchResult(
          message: state.comeback[i],
          index: i,
          category: 'comeback',
          subcategory: null,
          sectionLabel: 'Geri Dönüş',
        ));
      }
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              '"$_searchQuery" için sonuç bulunamadı.',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length + 1, // +1 for result count header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${results.length} sonuç bulundu',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          );
        }
        final result = results[index - 1];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show which category/section this result belongs to
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                result.sectionLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            FeedbackCard(
              message: result.message,
              index: result.index,
              category: result.category,
              subcategory: result.subcategory,
              onDelete: () => _confirmDeleteMessage(context, ref, result.category, result.subcategory, result.index),
            ),
          ],
        );
      },
    );
  }

  bool _matchesSearch(FeedbackMessageModel msg) {
    return msg.title.toLowerCase().contains(_searchQuery) ||
        msg.message.toLowerCase().contains(_searchQuery) ||
        msg.emoji.contains(_searchQuery);
  }

  /// Builds tabs with message count badges.
  List<Widget> _buildTabs(FeedbackContentState state) {
    int _countMessages(Map<String, List<FeedbackMessageModel>> map) {
      return map.values.fold(0, (sum, list) => sum + list.length);
    }

    final counts = [
      _countMessages(state.quiz),
      _countMessages(state.speedQuiz),
      _countMessages(state.time),
      state.comeback.length,
      _countMessages(state.streak),
      state.titles.length,
      _countMessages(state.learned),
    ];

    const labels = ['Quiz', 'Speed Quiz', 'Time', 'Comeback', 'Streak', 'Titles', 'Learned'];

    return List.generate(7, (i) {
      final count = counts[i];
      return Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labels[i]),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildBody(
    FeedbackLoadStatus loadStatus,
    FeedbackContentState state,
    GameConfigState gameConfig,
  ) {
    switch (loadStatus) {
      case FeedbackLoadStatus.idle:
      case FeedbackLoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case FeedbackLoadStatus.failed:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Feedback verisi yüklenemedi.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.read(feedbackLoadProvider.notifier).performLoad(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        );
      case FeedbackLoadStatus.empty:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 48),
              const SizedBox(height: 16),
              const Text('Henüz feedback verisi yok.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _createInitialData,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('İlk Veriyi Oluştur'),
              ),
            ],
          ),
        );
      case FeedbackLoadStatus.loaded:
        return TabBarView(
          controller: _tabController,
          children: [
            _SubcategoryMessageGrid(messageMap: state.quiz, category: 'quiz', subcategoryMeta: _quizMetaFrom(gameConfig)),
            _SubcategoryMessageGrid(messageMap: state.speedQuiz, category: 'speed_quiz', subcategoryMeta: _speedQuizMetaFrom(gameConfig)),
            _SubcategoryMessageGrid(messageMap: state.time, category: 'time', subcategoryMeta: _timeMetaFrom(gameConfig)),
            _ComebackTab(state: state, minDays: gameConfig.comebackMinDays),
            _SubcategoryMessageGrid(messageMap: state.streak, category: 'streak', subcategoryMeta: _streakMetaFrom(state)),
            _TitlesTab(state: state),
            _SubcategoryMessageGrid(messageMap: state.learned, category: 'learned', subcategoryMeta: _learnedMetaFrom(gameConfig)),
          ],
        );
    }
  }

  Widget? _buildFab(FeedbackLoadStatus loadStatus) {
    if (loadStatus != FeedbackLoadStatus.loaded) return null;
    final category = _categoryKeys[_tabController.index];
    if (category == 'titles') {
      return FloatingActionButton.extended(
        onPressed: _addTitle,
        icon: const Icon(Icons.add),
        label: const Text('Ünvan Ekle'),
      );
    }
    if (category == 'comeback') {
      return FloatingActionButton.extended(
        onPressed: () => _addMessage(category),
        icon: const Icon(Icons.add),
        label: const Text('Mesaj Ekle'),
      );
    }
    return null;
  }

  void _addMessage(String category) {
    final notifier = ref.read(feedbackContentProvider.notifier);
    const newMessage = FeedbackMessageModel(title: '', message: '', emoji: '📝');
    if (category == 'comeback') {
      notifier.addMessage(category, null, newMessage);
    } else {
      final state = ref.read(feedbackContentProvider);
      final map = _getMessageMap(state, category);
      if (map.isNotEmpty) {
        notifier.addMessage(category, map.keys.first, newMessage);
      }
    }
  }

  void _addTitle() {
    final notifier = ref.read(feedbackContentProvider.notifier);
    final state = ref.read(feedbackContentProvider);
    final existingValues = state.titles.map((t) => t.requiredBooks).toSet();
    var nextValue = 0;
    while (existingValues.contains(nextValue)) {
      nextValue++;
    }
    notifier.addTitle(PlayerTitleModel(title: '', icon: '🌟', requiredBooks: nextValue, profileImage: ''));
  }

  void _createInitialData() {
    final notifier = ref.read(feedbackContentProvider.notifier);
    const msg = FeedbackMessageModel(title: 'Yeni Mesaj', message: 'Mesaj içeriği', emoji: '📝');
    notifier.importContent(FeedbackContentState(
      quiz: {for (final k in ['speed_demon', 'perfect', 'one_wrong', 'two_wrong', 'good', 'moderate', 'failure']) k: [msg]},
      speedQuiz: {for (final k in ['combo_master', 'high_score', 'time_expired', 'moderate', 'low']) k: [msg]},
      time: {for (final k in ['seher', 'morning', 'noon', 'afternoon', 'evening', 'night', 'teheccud']) k: [msg]},
      comeback: [msg],
      streak: {for (final k in ['3', '7', '30']) k: [msg]},
      titles: [const PlayerTitleModel(title: 'İlim Yolcusu', icon: '🌱', requiredBooks: 0, profileImage: '')],
      learned: {for (final k in ['100', '75', '50', '25', '0']) k: [msg]},
    ));
  }

  Map<String, List<FeedbackMessageModel>> _getMessageMap(FeedbackContentState state, String category) {
    switch (category) {
      case 'quiz': return state.quiz;
      case 'speed_quiz': return state.speedQuiz;
      case 'time': return state.time;
      case 'streak': return state.streak;
      case 'learned': return state.learned;
      default: return {};
    }
  }
}

// =============================================================================
// Subcategory Metadata
// =============================================================================

class _SubcategoryMeta {
  final String label;
  final String condition;
  const _SubcategoryMeta(this.label, this.condition);
}

String _pct(double accuracy) => '${(accuracy * 100).round()}';

Map<String, _SubcategoryMeta> _quizMetaFrom(GameConfigState cfg) {
  final q = cfg.quiz;
  return {
    'speed_demon': _SubcategoryMeta(
      'Hız Canavarı',
      'Soru başına ${q.speedDemonMaxSecondsPerQuestion} saniyeden kısa sürede ve %${_pct(q.speedDemonMinAccuracy)} üzeri doğrulukla bitiren kullanıcıya gösterilir.',
    ),
    'perfect': _SubcategoryMeta(
      'Mükemmel Başarı',
      'Doğruluk ≥ %${_pct(q.perfectMinAccuracy)}.',
    ),
    'one_wrong': _SubcategoryMeta(
      'Tek Yanlış',
      'Yanlış soru sayısı = ${q.oneWrongCount}.',
    ),
    'two_wrong': _SubcategoryMeta(
      'İki Yanlış',
      'Yanlış soru sayısı = ${q.twoWrongCount}.',
    ),
    'good': _SubcategoryMeta(
      'İyi Performans',
      'Doğruluk ≥ %${_pct(q.goodMinAccuracy)} (üst bantlara girmeyen). 3 canla genelde latent kalır.',
    ),
    'moderate': _SubcategoryMeta(
      'Orta Performans',
      'Önceki bantlara girmeyen başarılı sonuçlar (fallback).',
    ),
    'failure': _SubcategoryMeta(
      'Başarısız (Can Bitti)',
      '${q.lives} can bitince gösterilir. Routing dışı.',
    ),
  };
}

Map<String, _SubcategoryMeta> _speedQuizMetaFrom(GameConfigState cfg) {
  final s = cfg.speedQuiz;
  final clauses = s.highScoreAny
      .map((c) {
        final parts = <String>[];
        if (c.minAccuracy != null) parts.add('doğruluk ≥ %${_pct(c.minAccuracy!)}');
        if (c.minCorrect != null) parts.add('en az ${c.minCorrect} doğru');
        return parts.join(' ve ');
      })
      .join(', veya ');
  return {
    'combo_master': _SubcategoryMeta(
      'Kombo Ustası',
      'Kombo ≥ ${s.comboMinCombo} ve doğruluk ≥ %${_pct(s.comboMinAccuracy)}.',
    ),
    'high_score': _SubcategoryMeta(
      'Yüksek Skor',
      clauses.isEmpty ? 'Yüksek skor bantları.' : clauses,
    ),
    'time_expired': _SubcategoryMeta(
      'Süre Doldu / Düşük',
      '${s.timeExpiredOnTimeout ? 'Süre bitince veya ' : ''}doğruluk < %${_pct(s.timeExpiredMaxAccuracy)}.',
    ),
    'moderate': _SubcategoryMeta(
      'Orta Performans',
      'Doğruluk ≥ %${_pct(s.moderateMinAccuracy)} (üst bantlara girmeyen). Mesajda {correctAnswers} kullanılabilir.',
    ),
    'low': const _SubcategoryMeta(
      'Düşük Performans',
      'Yukarıdaki bantlara girmeyen kalan sonuçlar.',
    ),
  };
}

Map<String, _SubcategoryMeta> _timeMetaFrom(GameConfigState cfg) {
  return {
    for (final slot in cfg.timeSlots)
      slot.key: _SubcategoryMeta(
        slot.label,
        '${formatGameConfigHhMm(slot.startMinutes)}–${formatGameConfigHhMm(slot.endMinutes)}',
      ),
  };
}

Map<String, _SubcategoryMeta> _streakMetaFrom(FeedbackContentState state) {
  final keys = state.streak.keys.toList()
    ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
  return {
    for (final k in keys)
      k: _SubcategoryMeta(
        '$k gün serisi',
        '$k gün üst üste uygulamaya giren kullanıcıya gösterilir. (streak ≥ $k)',
      ),
  };
}

Map<String, _SubcategoryMeta> _learnedMetaFrom(GameConfigState cfg) {
  return {
    for (final band in cfg.learnedBands)
      band.key: _SubcategoryMeta(
        band.key,
        band.exclusiveMin
            ? 'doğruluk > ${band.minPercent.round()}%'
            : 'doğruluk ≥ ${band.minPercent.round()}%',
      ),
  };
}

// =============================================================================
// Comeback Tab (flat list)
// =============================================================================

class _ComebackTab extends ConsumerWidget {
  const _ComebackTab({required this.state, required this.minDays});
  final FeedbackContentState state;
  final int minDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = state.comeback;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          label: 'Geri Dönüş Mesajları',
          condition: '$minDays gün boyunca uygulamaya girmemiş kullanıcıya gösterilir. (son giriş ≥ $minDays gün önce)',
          messageCount: messages.length,
        ),
        if (messages.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 32), child: Center(child: Text('Bu kategoride henüz mesaj yok.')))
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: messages.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              ref.read(feedbackContentProvider.notifier).reorderMessage('comeback', null, oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              return ReorderableDragStartListener(
                key: ValueKey('comeback_$index'),
                index: index,
                child: FeedbackCard(
                  message: messages[index],
                  index: index,
                  category: 'comeback',
                  subcategory: null,
                  onDelete: () => _confirmDeleteMessage(context, ref, 'comeback', null, index),
                ),
              );
            },
          ),
      ],
    );
  }
}

// =============================================================================
// Titles Tab
// =============================================================================

class _TitlesTab extends ConsumerWidget {
  const _TitlesTab({required this.state});
  final FeedbackContentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles = state.titles;
    if (titles.isEmpty) {
      return const Center(child: Text('Henüz ünvan eklenmemiş.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: titles.length,
      itemBuilder: (context, index) => TitleCard(
        title: titles[index],
        index: index,
        onDelete: () => _confirmDeleteTitle(context, ref, index),
      ),
    );
  }
}

// =============================================================================
// Subcategory Message Grid — Collapsible + Drag & Drop
// =============================================================================

class _SubcategoryMessageGrid extends ConsumerStatefulWidget {
  const _SubcategoryMessageGrid({
    required this.messageMap,
    required this.category,
    required this.subcategoryMeta,
  });

  final Map<String, List<FeedbackMessageModel>> messageMap;
  final String category;
  final Map<String, _SubcategoryMeta> subcategoryMeta;

  @override
  ConsumerState<_SubcategoryMessageGrid> createState() => _SubcategoryMessageGridState();
}

class _SubcategoryMessageGridState extends ConsumerState<_SubcategoryMessageGrid> {
  /// Tracks which sections are expanded. All start expanded.
  late final Map<String, bool> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {for (final key in widget.subcategoryMeta.keys) key: true};
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messageMap.isEmpty) {
      return const Center(child: Text('Bu kategoride henüz mesaj yok.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.subcategoryMeta.length,
      itemBuilder: (context, sectionIndex) {
        final key = widget.subcategoryMeta.keys.elementAt(sectionIndex);
        final meta = widget.subcategoryMeta[key]!;
        final messages = widget.messageMap[key] ?? [];
        final isExpanded = _expanded[key] ?? true;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collapsible section header
            InkWell(
              onTap: () => setState(() => _expanded[key] = !isExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
                ),
                child: Row(
                  children: [
                    // Expand/collapse icon
                    Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(meta.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.rule_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  meta.condition,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Message count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${messages.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add button
                    IconButton.filled(
                      onPressed: () {
                        const newMessage = FeedbackMessageModel(title: '', message: '', emoji: '📝');
                        ref.read(feedbackContentProvider.notifier).addMessage(widget.category, key, newMessage);
                      },
                      icon: const Icon(Icons.add, size: 20),
                      tooltip: '${meta.label} kategorisine mesaj ekle',
                      style: IconButton.styleFrom(minimumSize: const Size(32, 32), padding: const EdgeInsets.all(4)),
                    ),
                  ],
                ),
              ),
            ),
            // Collapsible content with drag & drop
            if (isExpanded) ...[
              if (messages.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16, left: 8),
                  child: Text('Bu alt kategoride mesaj yok.', style: TextStyle(color: Colors.grey)),
                )
              else
                _ReorderableMessageList(
                  messages: messages,
                  category: widget.category,
                  subcategory: key,
                ),
            ],
            const Divider(),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Reorderable Message List (Drag & Drop)
// =============================================================================

class _ReorderableMessageList extends ConsumerWidget {
  const _ReorderableMessageList({
    required this.messages,
    required this.category,
    required this.subcategory,
  });

  final List<FeedbackMessageModel> messages;
  final String category;
  final String subcategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: messages.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final notifier = ref.read(feedbackContentProvider.notifier);
        notifier.reorderMessage(category, subcategory, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        return ReorderableDragStartListener(
          key: ValueKey('${category}_${subcategory}_$index'),
          index: index,
          child: FeedbackCard(
            message: messages[index],
            index: index,
            category: category,
            subcategory: subcategory,
            onDelete: () => _confirmDeleteMessage(context, ref, category, subcategory, index),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Shared Section Header Widget
// =============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.condition,
    required this.messageCount,
  });

  final String label;
  final String condition;
  final int messageCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.rule_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(condition, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Text('$messageCount mesaj', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Delete Confirmation Helpers
// =============================================================================

Future<void> _confirmDeleteMessage(BuildContext context, WidgetRef ref, String category, String? subcategory, int index) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Silme Onayı'),
      content: const Text('Bu mesajı silmek istediğinize emin misiniz?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('İptal')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sil')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final success = ref.read(feedbackContentProvider.notifier).deleteMessage(category, subcategory, index);
  if (!success && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Her kategoride en az bir mesaj kalmalıdır.'), behavior: SnackBarBehavior.floating));
  }
}

Future<void> _confirmDeleteTitle(BuildContext context, WidgetRef ref, int index) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Silme Onayı'),
      content: const Text('Bu ünvanı silmek istediğinize emin misiniz?'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('İptal')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sil')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final success = ref.read(feedbackContentProvider.notifier).deleteTitle(index);
  if (!success && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az bir ünvan kalmalıdır.'), behavior: SnackBarBehavior.floating));
  }
}

// =============================================================================
// Search Result Model
// =============================================================================

class _SearchResult {
  final FeedbackMessageModel message;
  final int index;
  final String category;
  final String? subcategory;
  final String sectionLabel;

  const _SearchResult({
    required this.message,
    required this.index,
    required this.category,
    required this.subcategory,
    required this.sectionLabel,
  });
}
