import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/search_providers.dart';
import '../../widgets/tree/content_tree.dart';
import 'content_explorer_screen.dart';

/// Left panel of the Content Explorer that wraps the content tree widget.
class TreePanel extends ConsumerStatefulWidget {
  const TreePanel({
    super.key,
    required this.onItemSelected,
    this.selectedItem,
  });

  /// Callback invoked when a tree item is tapped.
  final void Function(SelectedItem item) onItemSelected;

  /// The item currently open in the edit panel, highlighted in the tree.
  final SelectedItem? selectedItem;

  @override
  ConsumerState<TreePanel> createState() => _TreePanelState();
}

class _TreePanelState extends ConsumerState<TreePanel> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryProvider);
    final focusNode = ref.watch(searchFocusNodeProvider);

    // Keep controller in sync when provider is cleared externally (e.g. via
    // keyboard shortcut or programmatic reset).
    if (_searchController.text != searchQuery) {
      _searchController.text = searchQuery;
      _searchController.selection = TextSelection.collapsed(
        offset: searchQuery.length,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Content',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
        ),
        const SizedBox(height: 8.0),
        const Divider(height: 1),
        Expanded(
          child: ContentTree(
            onItemSelected: widget.onItemSelected,
            selectedItem: widget.selectedItem,
          ),
        ),
      ],
    );
  }
}
