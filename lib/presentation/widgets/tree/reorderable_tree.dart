import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book_model.dart';
import '../../../data/models/level_model.dart';
import '../../../data/models/series_model.dart';
import '../../providers/content_providers.dart';
import '../../providers/history_providers.dart';
import '../../screens/explorer/content_explorer_screen.dart';

// =============================================================================
// ReorderableSeriesList
// =============================================================================

/// Wraps series items in a [ReorderableListView] for drag-and-drop reordering.
///
/// Calls [contentNotifier.reorderSeries] on drop and pushes history state
/// before the reorder operation. Drag is restricted to sibling series items.
class ReorderableSeriesList extends ConsumerWidget {
  const ReorderableSeriesList({
    super.key,
    required this.seriesList,
    required this.onItemSelected,
  });

  /// The list of series to display (already sorted by sortOrder).
  final List<SeriesModel> seriesList;

  /// Callback invoked when a series item is tapped.
  final void Function(SelectedItem item) onItemSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (seriesList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No content loaded. Import a ZIP to get started.'),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: seriesList.length,
      onReorder: (oldIndex, newIndex) {
        // ReorderableListView adjusts newIndex when moving down
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
        return _ReorderableSeriesItem(
          key: ValueKey('reorderable_series_${series.id}'),
          series: series,
          index: index,
          onItemSelected: onItemSelected,
        );
      },
    );
  }
}

class _ReorderableSeriesItem extends StatelessWidget {
  const _ReorderableSeriesItem({
    super.key,
    required this.series,
    required this.index,
    required this.onItemSelected,
  });

  final SeriesModel series;
  final int index;
  final void Function(SelectedItem item) onItemSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      title: Text(series.name),
      trailing: Text(
        series.iconEmoji,
        style: const TextStyle(fontSize: 20),
      ),
      onTap: () => onItemSelected(SelectedSeries(seriesId: series.id)),
    );
  }
}

// =============================================================================
// ReorderableBookList
// =============================================================================

/// Wraps book items within a series in a [ReorderableListView] for
/// drag-and-drop reordering.
///
/// Calls [contentNotifier.reorderBooks] on drop and pushes history state
/// before the reorder operation. Drag is restricted to sibling books within
/// the same series.
class ReorderableBookList extends ConsumerWidget {
  const ReorderableBookList({
    super.key,
    required this.seriesId,
    required this.books,
    required this.onItemSelected,
  });

  /// The parent series ID for these books.
  final int seriesId;

  /// The list of books to display (already sorted by bookOrder).
  final List<BookModel> books;

  /// Callback invoked when a book item is tapped.
  final void Function(SelectedItem item) onItemSelected;

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
        return _ReorderableBookItem(
          key: ValueKey('reorderable_book_${book.id}'),
          book: book,
          index: index,
          onItemSelected: onItemSelected,
        );
      },
    );
  }
}

class _ReorderableBookItem extends StatelessWidget {
  const _ReorderableBookItem({
    super.key,
    required this.book,
    required this.index,
    required this.onItemSelected,
  });

  final BookModel book;
  final int index;
  final void Function(SelectedItem item) onItemSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      title: Text(book.title),
      subtitle: Text(book.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => onItemSelected(SelectedBook(bookId: book.id)),
    );
  }
}

// =============================================================================
// ReorderableLevelList
// =============================================================================

/// Wraps level items within a book in a [ReorderableListView] for
/// drag-and-drop reordering.
///
/// Calls [contentNotifier.reorderLevels] on drop and pushes history state
/// before the reorder operation. Drag is restricted to sibling levels within
/// the same book (identified by contentFile).
class ReorderableLevelList extends ConsumerWidget {
  const ReorderableLevelList({
    super.key,
    required this.contentFile,
    required this.levels,
    required this.onItemSelected,
  });

  /// The content file key identifying the parent book.
  final String contentFile;

  /// The list of levels to display (already sorted by levelOrder).
  final List<LevelModel> levels;

  /// Callback invoked when a level item is tapped.
  final void Function(SelectedItem item) onItemSelected;

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
        return _ReorderableLevelItem(
          key: ValueKey('reorderable_level_${level.id}'),
          level: level,
          contentFile: contentFile,
          index: index,
          onItemSelected: onItemSelected,
        );
      },
    );
  }
}

class _ReorderableLevelItem extends StatelessWidget {
  const _ReorderableLevelItem({
    super.key,
    required this.level,
    required this.contentFile,
    required this.index,
    required this.onItemSelected,
  });

  final LevelModel level;
  final String contentFile;
  final int index;
  final void Function(SelectedItem item) onItemSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_handle),
      ),
      title: Text(level.title),
      subtitle: Text(
        '${level.questions.length} questions',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => onItemSelected(
        SelectedLevel(contentFile: contentFile, levelId: level.id),
      ),
    );
  }
}
