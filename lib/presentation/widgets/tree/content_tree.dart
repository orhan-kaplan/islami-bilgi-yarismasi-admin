import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book_model.dart';
import '../../../data/models/level_model.dart';
import '../../../data/models/series_model.dart';
import '../../../data/services/search_engine.dart';
import '../../providers/connectivity_providers.dart';
import '../../providers/content_providers.dart';
import '../../providers/history_providers.dart';
import '../../providers/search_providers.dart';
import '../../screens/explorer/content_explorer_screen.dart';

// =============================================================================
// Selection helpers
// =============================================================================

bool _isSeriesSelected(SelectedItem? item, int seriesId) =>
    item is SelectedSeries && item.seriesId == seriesId;

bool _isBookSelected(SelectedItem? item, int bookId) =>
    item is SelectedBook && item.bookId == bookId;

bool _isLevelSelected(SelectedItem? item, String contentFile, int levelId) =>
    item is SelectedLevel &&
    item.contentFile == contentFile &&
    item.levelId == levelId;

bool _isQuestionSelected(
  SelectedItem? item,
  String contentFile,
  int levelId,
  int questionIndex,
) =>
    item is SelectedQuestion &&
    item.contentFile == contentFile &&
    item.levelId == levelId &&
    item.questionIndex == questionIndex;

/// Background for the node currently open in the edit panel. Seçili düğüm
/// hiçbir şekilde işaretlenmiyordu; hangi kaydın düzenlendiği görünmüyordu.
Color? _selectionColor(BuildContext context, bool isSelected) => isSelected
    ? Theme.of(context).colorScheme.secondaryContainer
    : null;

Color? _matchColor(BuildContext context, bool isMatching) => isMatching
    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
    : null;

/// Expandable tree showing Series → Books → Levels → Questions hierarchy.
///
/// Uses [ExpansionTile] for each level of nesting. Items are sorted by their
/// respective order fields. On item tap, calls [onItemSelected]; the node
/// matching [selectedItem] is highlighted.
///
/// When a search is active (searchResultProvider is non-null), the tree filters
/// to show only visible items and highlights matching ones. Drag-and-drop
/// reordering is disabled during search, but the add buttons stay available.
///
/// When search is NOT active, drag handles are shown for series, books, and
/// levels, allowing reordering via drag-and-drop.
class ContentTree extends ConsumerWidget {
  const ContentTree({
    super.key,
    required this.onItemSelected,
    this.selectedItem,
  });

  /// Callback invoked when a tree item is tapped.
  final void Function(SelectedItem item) onItemSelected;

  /// The item currently open in the edit panel, highlighted in the tree.
  final SelectedItem? selectedItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesList = ref.watch(allSeriesProvider);
    final searchResult = ref.watch(searchResultProvider);

    // Filter series when search is active
    final displayedSeries = searchResult != null
        ? seriesList
            .where((s) => searchResult.visibleSeriesIds.contains(s.id))
            .toList()
        : seriesList;

    return Column(
      children: [
        // "Add Series" içerik boşken de, arama açıkken de erişilebilir
        // olmalı: tek giriş noktası buydu ve her iki durumda da kayboluyordu.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onItemSelected(CreateSeries()),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Series'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildBody(context, ref, seriesList, displayedSeries,
              searchResult),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<SeriesModel> seriesList,
    List<SeriesModel> displayedSeries,
    SearchResult? searchResult,
  ) {
    if (seriesList.isEmpty) {
      final isConnected = ref.watch(isServerConnectedProvider);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            isConnected
                ? 'No content yet. Use "Add Series" to create the first one.'
                : 'No content loaded. Start the asset server, or import a ZIP.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (searchResult != null && displayedSeries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No results found.'),
        ),
      );
    }

    // When search is NOT active, use ReorderableListView for drag-and-drop
    if (searchResult == null) {
      return _ReorderableSeriesTree(
        seriesList: displayedSeries,
        onItemSelected: onItemSelected,
        selectedItem: selectedItem,
      );
    }

    // When search IS active, show filtered tree without drag-and-drop
    return ListView.builder(
      itemCount: displayedSeries.length,
      itemBuilder: (context, index) {
        final series = displayedSeries[index];
        return _SeriesTile(
          series: series,
          onItemSelected: onItemSelected,
          selectedItem: selectedItem,
          searchResult: searchResult,
          reorderable: false,
          index: index,
        );
      },
    );
  }
}

// =============================================================================
// Reorderable Series Tree (top-level)
// =============================================================================

/// Top-level reorderable list of series with drag handles.
/// Used when search is NOT active.
class _ReorderableSeriesTree extends ConsumerWidget {
  const _ReorderableSeriesTree({
    required this.seriesList,
    required this.onItemSelected,
    required this.selectedItem,
  });

  final List<SeriesModel> seriesList;
  final void Function(SelectedItem item) onItemSelected;
  final SelectedItem? selectedItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: seriesList.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex == newIndex) return;
        if (newIndex > oldIndex) newIndex--;
        if (oldIndex == newIndex) return;

        // Push history state BEFORE reorder
        final currentState = ref.read(contentStateProvider);
        ref.read(historyProvider.notifier).pushState(currentState);

        // Build new order
        final ids = seriesList.map((s) => s.id).toList();
        final movedId = ids.removeAt(oldIndex);
        ids.insert(newIndex, movedId);

        ref.read(contentStateProvider.notifier).reorderSeries(ids);
      },
      itemBuilder: (context, index) {
        final series = seriesList[index];
        return _SeriesTile(
          key: ValueKey('reorderable_series_${series.id}'),
          series: series,
          onItemSelected: onItemSelected,
          selectedItem: selectedItem,
          searchResult: null,
          reorderable: true,
          index: index,
        );
      },
    );
  }
}

/// A single series node in the tree.
class _SeriesTile extends ConsumerWidget {
  const _SeriesTile({
    super.key,
    required this.series,
    required this.onItemSelected,
    required this.selectedItem,
    this.searchResult,
    required this.reorderable,
    required this.index,
  });

  final SeriesModel series;
  final void Function(SelectedItem item) onItemSelected;
  final SelectedItem? selectedItem;
  final SearchResult? searchResult;
  final bool reorderable;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksForSeriesProvider(series.id));

    // Filter books when search is active
    final displayedBooks = searchResult != null
        ? books
            .where((b) => searchResult!.visibleBookIds.contains(b.id))
            .toList()
        : books;

    final isMatching = searchResult != null &&
        searchResult!.matchingSeriesIds.contains(series.id);
    final isSelected = _isSeriesSelected(selectedItem, series.id);

    // Auto-expand when search is active and this series has visible children
    final shouldExpand = searchResult != null;

    return ExpansionTile(
      key: searchResult != null
          ? ValueKey('series_${series.id}_expanded')
          : ValueKey('series_${series.id}'),
      initiallyExpanded: shouldExpand,
      leading: reorderable
          ? ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            )
          : Text(
              series.iconEmoji,
              style: const TextStyle(fontSize: 20),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: 'Add Book',
            onPressed: () => onItemSelected(CreateBook(seriesId: series.id)),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
      title: GestureDetector(
        onTap: () => onItemSelected(SelectedSeries(seriesId: series.id)),
        child: Row(
          children: [
            if (reorderable)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  series.iconEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            Expanded(
              child: Text(
                series.name,
                style: isMatching
                    ? TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: _selectionColor(context, isSelected) ??
          _matchColor(context, isMatching),
      collapsedBackgroundColor: _selectionColor(context, isSelected),
      children: reorderable
          ? [
              _ReorderableBookTree(
                seriesId: series.id,
                books: displayedBooks,
                onItemSelected: onItemSelected,
                selectedItem: selectedItem,
              ),
            ]
          : displayedBooks.map((book) {
              return _BookTile(
                book: book,
                onItemSelected: onItemSelected,
                selectedItem: selectedItem,
                searchResult: searchResult,
                reorderable: false,
                index: 0,
              );
            }).toList(),
    );
  }
}

// =============================================================================
// Reorderable Book Tree (within a series)
// =============================================================================

/// Reorderable list of books within a series.
/// Used when search is NOT active.
class _ReorderableBookTree extends ConsumerWidget {
  const _ReorderableBookTree({
    required this.seriesId,
    required this.books,
    required this.onItemSelected,
    required this.selectedItem,
  });

  final int seriesId;
  final List<BookModel> books;
  final void Function(SelectedItem item) onItemSelected;
  final SelectedItem? selectedItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (books.isEmpty) {
      return const SizedBox.shrink();
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: books.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex == newIndex) return;
        if (newIndex > oldIndex) newIndex--;
        if (oldIndex == newIndex) return;

        // Push history state BEFORE reorder
        final currentState = ref.read(contentStateProvider);
        ref.read(historyProvider.notifier).pushState(currentState);

        // Build new order
        final ids = books.map((b) => b.id).toList();
        final movedId = ids.removeAt(oldIndex);
        ids.insert(newIndex, movedId);

        ref.read(contentStateProvider.notifier).reorderBooks(seriesId, ids);
      },
      itemBuilder: (context, index) {
        final book = books[index];
        return _BookTile(
          key: ValueKey('reorderable_book_${book.id}'),
          book: book,
          onItemSelected: onItemSelected,
          selectedItem: selectedItem,
          searchResult: null,
          reorderable: true,
          index: index,
        );
      },
    );
  }
}

/// A single book node in the tree.
class _BookTile extends ConsumerWidget {
  const _BookTile({
    super.key,
    required this.book,
    required this.onItemSelected,
    required this.selectedItem,
    this.searchResult,
    required this.reorderable,
    required this.index,
  });

  final BookModel book;
  final void Function(SelectedItem item) onItemSelected;
  final SelectedItem? selectedItem;
  final SearchResult? searchResult;
  final bool reorderable;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(levelsForBookProvider(book.contentFile));

    // Filter levels when search is active
    final displayedLevels = searchResult != null
        ? levels
            .where((l) => searchResult!.visibleLevelIds.contains(l.id))
            .toList()
        : levels;

    final isMatching = searchResult != null &&
        searchResult!.matchingBookIds.contains(book.id);
    final isSelected = _isBookSelected(selectedItem, book.id);

    // Auto-expand when search is active and this book has visible children
    final shouldExpand = searchResult != null;

    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: ExpansionTile(
        key: searchResult != null
            ? ValueKey('book_${book.id}_expanded')
            : ValueKey('book_${book.id}'),
        initiallyExpanded: shouldExpand,
        leading: reorderable
            ? ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              )
            : const Icon(Icons.book_outlined, size: 18),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Add Level',
              onPressed: () => onItemSelected(
                CreateLevel(contentFile: book.contentFile, bookId: book.id),
              ),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        title: GestureDetector(
          onTap: () => onItemSelected(SelectedBook(bookId: book.id)),
          child: Row(
            children: [
              if (reorderable)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.book_outlined, size: 18),
                ),
              Expanded(
                child: Text(
                  book.title,
                  style: isMatching
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: _selectionColor(context, isSelected) ??
            _matchColor(context, isMatching),
        collapsedBackgroundColor: _selectionColor(context, isSelected),
        children: reorderable
            ? [
                _ReorderableLevelTree(
                  contentFile: book.contentFile,
                  levels: displayedLevels,
                  onItemSelected: onItemSelected,
                  selectedItem: selectedItem,
                ),
              ]
            : displayedLevels.map((level) {
                return _LevelTile(
                  level: level,
                  contentFile: book.contentFile,
                  onItemSelected: onItemSelected,
                  selectedItem: selectedItem,
                  searchResult: searchResult,
                );
              }).toList(),
      ),
    );
  }
}

// =============================================================================
// Reorderable Level Tree (within a book)
// =============================================================================

/// Reorderable list of levels within a book.
/// Used when search is NOT active.
class _ReorderableLevelTree extends ConsumerWidget {
  const _ReorderableLevelTree({
    required this.contentFile,
    required this.levels,
    required this.onItemSelected,
    required this.selectedItem,
  });

  final String contentFile;
  final List<LevelModel> levels;
  final void Function(SelectedItem item) onItemSelected;
  final SelectedItem? selectedItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (levels.isEmpty) {
      return const SizedBox.shrink();
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: levels.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex == newIndex) return;
        if (newIndex > oldIndex) newIndex--;
        if (oldIndex == newIndex) return;

        // Push history state BEFORE reorder
        final currentState = ref.read(contentStateProvider);
        ref.read(historyProvider.notifier).pushState(currentState);

        // Build new order
        final ids = levels.map((l) => l.id).toList();
        final movedId = ids.removeAt(oldIndex);
        ids.insert(newIndex, movedId);

        ref.read(contentStateProvider.notifier).reorderLevels(contentFile, ids);
      },
      itemBuilder: (context, index) {
        final level = levels[index];
        return _ReorderableLevelTile(
          key: ValueKey('reorderable_level_${level.id}'),
          level: level,
          contentFile: contentFile,
          index: index,
          onItemSelected: onItemSelected,
          selectedItem: selectedItem,
        );
      },
    );
  }
}

/// A reorderable level item with drag handle and expandable questions list
/// (used in normal mode).
class _ReorderableLevelTile extends StatelessWidget {
  const _ReorderableLevelTile({
    super.key,
    required this.level,
    required this.contentFile,
    required this.index,
    required this.onItemSelected,
    required this.selectedItem,
  });

  final LevelModel level;
  final String contentFile;
  final int index;
  final void Function(SelectedItem item) onItemSelected;
  final SelectedItem? selectedItem;

  @override
  Widget build(BuildContext context) {
    final isSelected = _isLevelSelected(selectedItem, contentFile, level.id);

    return ExpansionTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: 'Add Question',
            onPressed: () => onItemSelected(
              CreateQuestion(contentFile: contentFile, levelId: level.id),
            ),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
      // Tıklama alanı yalnızca başlık metni kadardı: kısa başlıklı bir
      // level'da metnin sağına tıklamak seçmek yerine açıp kapatıyordu.
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onItemSelected(
          SelectedLevel(contentFile: contentFile, levelId: level.id),
        ),
        child: Row(
          children: [Expanded(child: Text(level.title))],
        ),
      ),
      subtitle: Text(
        '${level.questions.length} questions',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      backgroundColor: _selectionColor(context, isSelected),
      collapsedBackgroundColor: _selectionColor(context, isSelected),
      children: List.generate(level.questions.length, (qi) {
        final question = level.questions[qi];

        return ListTile(
          contentPadding: const EdgeInsets.only(left: 48.0),
          leading: const Icon(Icons.quiz_outlined, size: 16),
          selected: _isQuestionSelected(selectedItem, contentFile, level.id, qi),
          selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
          title: Text(
            question.questionText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          onTap: () => onItemSelected(
            SelectedQuestion(
              contentFile: contentFile,
              levelId: level.id,
              questionIndex: qi,
            ),
          ),
        );
      }),
    );
  }
}

/// A single level node in the tree (used in search mode).
class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.contentFile,
    required this.onItemSelected,
    required this.selectedItem,
    this.searchResult,
  });

  final LevelModel level;
  final String contentFile;
  final void Function(SelectedItem item) onItemSelected;
  final SelectedItem? selectedItem;
  final SearchResult? searchResult;

  @override
  Widget build(BuildContext context) {
    final isMatching = searchResult != null &&
        searchResult!.matchingLevelIds.contains(level.id);
    final isSelected = _isLevelSelected(selectedItem, contentFile, level.id);

    // Auto-expand when search is active AND this level has matching questions
    final hasMatchingQuestions = searchResult != null &&
        level.questions.asMap().entries.any(
              (e) => searchResult!.matchingQuestionIndices
                  .contains(level.id * 1000 + e.key),
            );
    final shouldExpand = searchResult != null && hasMatchingQuestions;

    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: ExpansionTile(
        key: searchResult != null
            ? ValueKey('level_${level.id}_expanded')
            : ValueKey('level_${level.id}'),
        initiallyExpanded: shouldExpand,
        leading: const Icon(Icons.layers_outlined, size: 18),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Add Question',
              onPressed: () => onItemSelected(
                CreateQuestion(contentFile: contentFile, levelId: level.id),
              ),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onItemSelected(
            SelectedLevel(contentFile: contentFile, levelId: level.id),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  level.title,
                  style: isMatching
                      ? TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: _selectionColor(context, isSelected) ??
            _matchColor(context, isMatching),
        collapsedBackgroundColor: _selectionColor(context, isSelected),
        children: List.generate(level.questions.length, (qi) {
          final question = level.questions[qi];

          final isQuestionMatching = searchResult != null &&
              searchResult!.matchingQuestionIndices
                  .contains(level.id * 1000 + qi);

          // When search is active, only show matching questions
          if (searchResult != null && !isQuestionMatching) {
            return const SizedBox.shrink();
          }

          return ListTile(
            contentPadding: const EdgeInsets.only(left: 48.0),
            leading: const Icon(Icons.quiz_outlined, size: 16),
            selected:
                _isQuestionSelected(selectedItem, contentFile, level.id, qi),
            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
            title: Text(
              question.questionText,
              style: isQuestionMatching
                  ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize:
                          Theme.of(context).textTheme.bodySmall?.fontSize,
                    )
                  : Theme.of(context).textTheme.bodySmall,
            ),
            tileColor: _matchColor(context, isQuestionMatching),
            onTap: () => onItemSelected(
              SelectedQuestion(
                contentFile: contentFile,
                levelId: level.id,
                questionIndex: qi,
              ),
            ),
          );
        }),
      ),
    );
  }
}
