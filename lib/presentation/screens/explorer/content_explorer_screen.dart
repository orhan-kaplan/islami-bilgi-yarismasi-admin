import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/changelog_provider.dart';
import '../../providers/content_providers.dart';
import '../../providers/history_providers.dart';
import 'bulk_add_dialog.dart';
import 'edit_panel.dart';
import 'json_preview_panel.dart';
import 'tree_panel.dart';

// ---------------------------------------------------------------------------
// Selected item types for the Content Explorer master-detail layout.
// ---------------------------------------------------------------------------

/// Represents the currently selected item in the content tree.
sealed class SelectedItem {}

/// A series node is selected.
class SelectedSeries extends SelectedItem {
  final int seriesId;
  SelectedSeries({required this.seriesId});
}

/// A book node is selected.
class SelectedBook extends SelectedItem {
  final int bookId;
  SelectedBook({required this.bookId});
}

/// A level node is selected.
class SelectedLevel extends SelectedItem {
  final String contentFile;
  final int levelId;
  SelectedLevel({required this.contentFile, required this.levelId});
}

/// A question node is selected.
class SelectedQuestion extends SelectedItem {
  final String contentFile;
  final int levelId;
  final int questionIndex;
  SelectedQuestion({
    required this.contentFile,
    required this.levelId,
    required this.questionIndex,
  });
}

/// Triggers an empty SeriesForm in the edit panel (create mode).
class CreateSeries extends SelectedItem {}

/// Triggers an empty BookForm in the edit panel (create mode).
class CreateBook extends SelectedItem {
  final int seriesId;
  CreateBook({required this.seriesId});
}

/// Triggers an empty LevelForm in the edit panel (create mode).
class CreateLevel extends SelectedItem {
  final String contentFile;
  final int bookId;
  CreateLevel({required this.contentFile, required this.bookId});
}

/// Triggers an empty QuestionForm in the edit panel (create mode).
class CreateQuestion extends SelectedItem {
  final String contentFile;
  final int levelId;
  CreateQuestion({required this.contentFile, required this.levelId});
}

// ---------------------------------------------------------------------------
// Content Explorer Screen — master-detail layout.
// ---------------------------------------------------------------------------

/// Master-detail layout: left panel (tree, ~300px) + right panel (edit form).
class ContentExplorerScreen extends ConsumerStatefulWidget {
  const ContentExplorerScreen({super.key});

  @override
  ConsumerState<ContentExplorerScreen> createState() =>
      _ContentExplorerScreenState();
}

class _ContentExplorerScreenState extends ConsumerState<ContentExplorerScreen> {
  SelectedItem? _selectedItem;
  double _treeWidth = 300;

  static const double _minTreeWidth = 200;
  static const double _maxTreeWidth = 600;

  void _onItemSelected(SelectedItem item) {
    setState(() {
      _selectedItem = item;
    });
  }

  void _handleUndo() {
    final currentState = ref.read(contentStateProvider);
    final restored =
        ref.read(historyProvider.notifier).undo(currentState);
    if (restored != null) {
      ref.read(contentStateProvider.notifier).importContent(restored);
    }
  }

  void _handleRedo() {
    final currentState = ref.read(contentStateProvider);
    final restored =
        ref.read(historyProvider.notifier).redo(currentState);
    if (restored != null) {
      ref.read(contentStateProvider.notifier).importContent(restored);
    }
  }

  Future<void> _handleBulkAdd() async {
    final selected = _selectedItem;
    if (selected is! SelectedLevel) return;

    final questions = await showBulkAddDialog(context);
    if (questions == null || questions.isEmpty) return;

    // Push history state before adding questions
    final currentState = ref.read(contentStateProvider);
    ref.read(historyProvider.notifier).pushState(currentState);

    // Add each valid question to the selected level
    final contentNotifier = ref.read(contentStateProvider.notifier);
    for (final question in questions) {
      contentNotifier.addQuestion(
        selected.contentFile,
        selected.levelId,
        question,
      );
    }
  }

  void _showChangelogDialog(BuildContext context, WidgetRef ref) {
    final entries = ref.read(changelogProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Değişiklikler'),
        content: SizedBox(
          width: 400,
          child: entries.isEmpty
              ? const Text('Değişiklik yok')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final entry = entries[i];
                    final icon = switch (entry.type) {
                      ChangeType.added => Icons.add_circle_outline,
                      ChangeType.modified => Icons.edit_outlined,
                      ChangeType.removed => Icons.remove_circle_outline,
                    };
                    final color = switch (entry.type) {
                      ChangeType.added => Colors.green,
                      ChangeType.modified => Colors.orange,
                      ChangeType.removed => Colors.red,
                    };
                    return ListTile(
                      leading: Icon(icon, color: color, size: 20),
                      title: Text(entry.description),
                      subtitle: Text(
                        entry.file,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      dense: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUndo = ref.watch(canUndoProvider);
    final canRedo = ref.watch(canRedoProvider);
    final isDirty = ref.watch(isDirtyProvider);
    final jsonPreviewVisible = ref.watch(jsonPreviewVisibleProvider);

    return Column(
      children: [
        // Toolbar
        Material(
          elevation: 1,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo',
                  onPressed: canUndo ? _handleUndo : null,
                ),
                IconButton(
                  icon: const Icon(Icons.redo),
                  tooltip: 'Redo',
                  onPressed: canRedo ? _handleRedo : null,
                ),
                if (isDirty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                if (isDirty)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'Unsaved changes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                if (isDirty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextButton.icon(
                      onPressed: () => _showChangelogDialog(context, ref),
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Değişiklikler'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                const Spacer(),
                if (_selectedItem is SelectedLevel)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.icon(
                      onPressed: _handleBulkAdd,
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: const Text('Bulk Add Questions'),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.data_object,
                    color: jsonPreviewVisible
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  tooltip: 'Toggle JSON Preview',
                  onPressed: () {
                    ref.read(jsonPreviewVisibleProvider.notifier).state =
                        !jsonPreviewVisible;
                  },
                ),
              ],
            ),
          ),
        ),
        // Main content area
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: _treeWidth,
                child: TreePanel(onItemSelected: _onItemSelected),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _treeWidth = (_treeWidth + details.delta.dx)
                          .clamp(_minTreeWidth, _maxTreeWidth);
                    });
                  },
                  child: Container(
                    width: 6,
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              Expanded(
                child: EditPanel(selectedItem: _selectedItem),
              ),
              if (jsonPreviewVisible) ...[
                const VerticalDivider(thickness: 1, width: 1),
                SizedBox(
                  width: 300,
                  child: JsonPreviewPanel(selectedItem: _selectedItem),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
